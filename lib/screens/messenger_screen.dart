import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/rendering.dart' show ScrollDirection, RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart' show AppThemeNotifier, ThemeDef, NeonTextStyle;
import '../services/api_service.dart';
import '../services/prefs_service.dart';
import '../models/message.dart';
import '../models/channel.dart';
import '../widgets/admin_avatar_widget.dart';
import '../widgets/circular_avatar.dart';
import '../services/nav_bar_controller.dart';
import '../main.dart' show currentChatChannelId;
import 'user_profile_screen.dart';
import 'video_circle_recorder.dart';

class MessengerScreen extends StatefulWidget {
  final Channel channel;
  const MessengerScreen({super.key, required this.channel});

  @override
  State<MessengerScreen> createState() => _MessengerScreenState();
}

class _MessengerScreenState extends State<MessengerScreen>
    with SingleTickerProviderStateMixin {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<Message> _messages = [];
  Timer? _timer;
  bool _sending = false;
  int _lastId = 0;
  final Map<String, Uint8List> _mediaCache = {};
  final Map<String, Uint8List?> _avatarCache = {};
  final Set<String> _avatarLoading = {};
  String _deviceName = 'User';
  String? _adminSenderName;
  String? _adminAvatarEffect;
  String _myName = '';
  String? _dmDisplayName;
  String? _dmOtherUserName;
  Map<String, int> _readStatus = {};

  // Voice recording
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _videoMode = false;
  bool _recordingLocked = false;
  double _lockDragStartY = 0;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  // Edit / reply state
  Message? _editingMessage;
  Message? _replyingTo;

  // IDs shown without animation (history preload)
  final Set<int> _preloadedIds = {};

  // Upload progress (null = not uploading)
  double? _uploadProgress;

  // Online indicator for DM
  bool _dmIsOnline = false;
  Timer? _onlineTimer;

  // IDs currently animating out on delete
  final Set<int> _deletingIds = {};

  NavBarController? _navCtrl;
  late AnimationController _inputEntryCtrl;
  late Animation<Offset> _inputSlide;

  @override
  void initState() {
    super.initState();
    currentChatChannelId = widget.channel.id;
    _inputEntryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _inputSlide = Tween<Offset>(
      begin: const Offset(0, 1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _inputEntryCtrl, curve: Curves.easeOutBack));
    _loadDeviceName();
    _fetchAdminName();
    _loadLocalHistory().then((_) => _fetch());
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _fetch());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prefs = context.read<PrefsService>();
      final name = _resolveSenderName(prefs);
      setState(() => _myName = name);
      if (widget.channel.isDm) {
        _initDmUser(name);
        _pollOnline();
        _onlineTimer = Timer.periodic(const Duration(seconds: 30), (_) => _pollOnline());
      }
      if (!mounted) return;
      _navCtrl = context.read<NavBarController>();
      _navCtrl!.hide();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _inputEntryCtrl.forward();
      });
    });
  }

  @override
  void dispose() {
    currentChatChannelId = null;
    _navCtrl?.show();
    _timer?.cancel();
    _recordingTimer?.cancel();
    _onlineTimer?.cancel();
    _inputEntryCtrl.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _pollOnline() async {
    if (_dmOtherUserName == null || !mounted) return;
    final api = context.read<ApiService>();
    final online = await api.getUserOnline(_dmOtherUserName!);
    if (mounted) setState(() => _dmIsOnline = online);
  }

  Future<void> _fetchAdminName() async {
    try {
      final api = context.read<ApiService>();
      final profile = await api.getProfile(PrefsService.adminEmail);
      if (profile != null && mounted) {
        final name = profile['display_name'] as String?;
        final effect = profile['avatar_effect'] as String?;
        setState(() {
          if (name != null && name.isNotEmpty) _adminSenderName = name;
          _adminAvatarEffect = effect;
        });
      }
    } catch (_) {}
  }

  Future<void> _initDmUser(String myName) async {
    final body = widget.channel.id.substring(3); // "Ekkir~test1"
    final parts = body.contains('~') ? body.split('~') : [body];
    final myLower = myName.toLowerCase();
    final other = parts.firstWhere(
      (p) => p.toLowerCase() != myLower,
      orElse: () => parts.first,
    );
    if (mounted) setState(() => _dmOtherUserName = other);
    _loadAvatarForSender(other);
    try {
      final api = context.read<ApiService>();
      final profile = await api.getProfileByName(other);
      if (profile != null && mounted) {
        final dn = profile['display_name'] as String?;
        if (dn != null && dn.isNotEmpty) setState(() => _dmDisplayName = dn);
      }
    } catch (_) {}
  }

  Future<void> _loadDeviceName() async {
    try {
      final info = DeviceInfoPlugin();
      final android = await info.androidInfo;
      if (mounted) setState(() => _deviceName = 'Android ${android.model}');
    } catch (_) {}
  }

  String _resolveSenderName(PrefsService prefs) {
    if (prefs.profileName.isNotEmpty) return prefs.profileName;
    if (prefs.googleName.isNotEmpty) return prefs.googleName;
    return _deviceName;
  }

  Future<void> _loadAvatarForSender(String sender) async {
    if (_avatarCache.containsKey(sender) || _avatarLoading.contains(sender)) return;
    _avatarLoading.add(sender);
    final api = context.read<ApiService>();
    final bytes = await api.getAvatarByName(sender);
    if (mounted) {
      setState(() {
        _avatarCache[sender] = bytes != null ? Uint8List.fromList(bytes) : null;
        _avatarLoading.remove(sender);
      });
    }
  }

  Future<void> _fetch() async {
    final api = context.read<ApiService>();
    final result = await api.getMessages(widget.channel.id, _lastId);
    if (!mounted) return;
    final msgs = result.messages;
    final deleted = result.deleted;
    final newMsgs = msgs.where((m) => m.id > _lastId).toList();
    if (newMsgs.isEmpty && deleted.isEmpty) return;
    if (newMsgs.isNotEmpty) {
      _lastId = newMsgs.map((m) => m.id).reduce((a, b) => a > b ? a : b);
      final prefs = context.read<PrefsService>();
      await prefs.setLastReadId(widget.channel.id, _lastId);
      if (_myName.isNotEmpty) {
        await api.markRead(widget.channel.id, _myName, _lastId);
      }
    }
    final status = await api.getReadStatus(widget.channel.id);
    if (mounted && status.isNotEmpty) setState(() => _readStatus = status);
    setState(() {
      if (deleted.isNotEmpty) _messages.removeWhere((m) => deleted.contains(m.id));
      for (final m in newMsgs) {
        final idx = _messages.indexWhere((e) => e.id == m.id);
        if (idx >= 0) {
          _messages[idx] = m;
        } else {
          _messages.add(m);
        }
      }
    });
    for (final m in newMsgs) {
      _loadAvatarForSender(m.sender);
    }
    _saveLocalHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadedIds.addAll(newMsgs.map((m) => m.id));
      if (!_scrollCtrl.hasClients) return;
      final pos = _scrollCtrl.position;
      if (pos.userScrollDirection != ScrollDirection.idle) return;
      final isNearBottom = pos.maxScrollExtent - pos.pixels < 120;
      final hasSelfMsg = newMsgs.any((m) => m.sender == _myName);
      if (isNearBottom || hasSelfMsg) {
        _scrollCtrl.animateTo(
          pos.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<File> _localHistoryFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final safe = widget.channel.id.replaceAll(RegExp(r'[^\w]'), '_');
    return File('${dir.path}/chat_$safe.json');
  }

  Future<void> _saveLocalHistory() async {
    try {
      final file = await _localHistoryFile();
      final data = (_messages.length > 200 ? _messages.sublist(_messages.length - 200) : _messages)
          .map((m) => m.toJson())
          .toList();
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _loadLocalHistory() async {
    try {
      final file = await _localHistoryFile();
      if (!await file.exists()) return;
      final list = jsonDecode(await file.readAsString()) as List;
      final msgs = list.map((e) => Message.fromJson(e as Map<String, dynamic>)).toList();
      if (mounted) setState(() {
        _messages..clear()..addAll(msgs);
        _preloadedIds.addAll(msgs.map((m) => m.id));
      });
    } catch (_) {}
  }

  Future<void> _send() async {
    // Если запись заблокирована — отправить голосовое
    if (_isRecording && _recordingLocked) {
      setState(() => _recordingLocked = false);
      _stopVoiceRecording();
      return;
    }

    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    if (_editingMessage != null) {
      await _sendEdit(text);
      return;
    }

    final prefs = context.read<PrefsService>();
    final api = context.read<ApiService>();
    final sender = _resolveSenderName(prefs);
    final reply = _replyingTo;

    setState(() { _sending = true; _replyingTo = null; });
    _navCtrl?.updateMessengerBanners();
    _inputCtrl.clear();

    await api.sendMessage(
      channel: widget.channel.id,
      sender: sender,
      text: text,
      replyToId: reply?.id,
      replyToText: reply != null ? reply.text.substring(0, reply.text.length.clamp(0, 100)) : null,
    );
    if (mounted) setState(() => _sending = false);
    _fetch();
  }

  Future<void> _sendEdit(String text) async {
    final msg = _editingMessage!;
    final api = context.read<ApiService>();
    final prefs = context.read<PrefsService>();
    final sender = _resolveSenderName(prefs);
    setState(() { _editingMessage = null; _sending = true; });
    _navCtrl?.updateMessengerBanners();
    _inputCtrl.clear();
    final ok = await api.editMessage(widget.channel.id, msg.id, sender, text);
    if (ok && mounted) {
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == msg.id);
        if (idx >= 0) _messages[idx] = _messages[idx].copyWith(text: text, edited: true);
      });
      _saveLocalHistory();
    }
    if (mounted) setState(() => _sending = false);
  }

  // ── Голосовое сообщение ──────────────────────────────────────────────────────

  Future<void> _startVoiceRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission || !mounted) return;
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 44100, bitRate: 128000),
        path: path,
      );
      if (mounted) {
        setState(() => _isRecording = true);
        _navCtrl?.updateMessengerRecording(
            isRecording: true, locked: false, seconds: 0, videoMode: _videoMode);
        _startRecordingTimer();
      }
    } catch (_) {}
  }

  void _startRecordingTimer() {
    _recordingSeconds = 0;
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _recordingSeconds++);
        _navCtrl?.updateMessengerRecording(
            isRecording: true, locked: _recordingLocked, seconds: _recordingSeconds, videoMode: _videoMode);
      }
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    if (mounted) {
      setState(() { _recordingSeconds = 0; _recordingLocked = false; });
      _navCtrl?.updateMessengerRecording(isRecording: false);
    }
  }

  String _formatRecordDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  bool _isRead(Message m) {
    if (m.sender != _myName) return false;
    return _readStatus.entries.any((e) => e.key != _myName && e.value >= m.id);
  }

  Future<void> _stopVoiceRecording() async {
    if (!_isRecording) return;
    _stopRecordingTimer();
    try {
      final path = await _recorder.stop();
      if (mounted) setState(() => _isRecording = false);
      if (path == null || !mounted) return;

      final file = File(path);
      if (!await file.exists()) return;

      final prefs = context.read<PrefsService>();
      final api = context.read<ApiService>();
      final sender = _resolveSenderName(prefs);

      setState(() { _sending = true; _uploadProgress = 0.0; });
      _navCtrl?.setMessengerBusy(true);
      final mediaId = await api.uploadMedia(
        file,
        onProgress: (p) { if (mounted) setState(() => _uploadProgress = p); },
      );
      if (mounted) setState(() => _uploadProgress = null);
      if (mediaId != null && mounted) {
        await api.sendMessage(
          channel: widget.channel.id,
          sender: sender,
          text: '🎤 Голосовое',
          type: 'audio',
          mediaId: mediaId,
        );
      }
      if (mounted) {
        setState(() => _sending = false);
        _navCtrl?.setMessengerBusy(false);
      }
      _fetch();
    } catch (_) {
      if (mounted) setState(() => _isRecording = false);
    }
  }

  // ── Видео-кружок ─────────────────────────────────────────────────────────────

  Future<void> _sendVideoCircle() async {
    final path = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const VideoCircleRecorder()),
    );
    if (path == null || !mounted) return;

    final prefs = context.read<PrefsService>();
    final api = context.read<ApiService>();
    final sender = _resolveSenderName(prefs);

    setState(() { _sending = true; _uploadProgress = 0.0; });
    _navCtrl?.setMessengerBusy(true);
    final mediaId = await api.uploadMedia(
      File(path),
      onProgress: (p) { if (mounted) setState(() => _uploadProgress = p); },
    );
    if (mounted) setState(() => _uploadProgress = null);
    if (mediaId != null && mounted) {
      await api.sendMessage(
        channel: widget.channel.id,
        sender: sender,
        text: '🎥 Видео-кружок',
        type: 'video_circle',
        mediaId: mediaId,
      );
    }
    if (mounted) {
      setState(() => _sending = false);
      _navCtrl?.setMessengerBusy(false);
    }
    _fetch();
  }

  // ── Медиа ─────────────────────────────────────────────────────────────────────

  void _pickMedia() {
    final mediaNotifier = Provider.of<AppThemeNotifier>(context, listen: false);
    final t = mediaNotifier.current;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: t.cardBorder, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            ListTile(
              leading: Icon(Icons.image_outlined, color: mediaNotifier.accent),
              title: Text('Изображение', style: TextStyle(color: t.textPrimary)),
              onTap: () { Navigator.pop(ctx); _sendImage(); },
            ),
            ListTile(
              leading: Icon(Icons.attach_file, color: mediaNotifier.accent),
              title: Text('Файл', style: TextStyle(color: t.textPrimary)),
              onTap: () { Navigator.pop(ctx); _sendFile(); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1280);
    if (xfile == null || !mounted) return;

    final prefs = context.read<PrefsService>();
    final api = context.read<ApiService>();
    final sender = _resolveSenderName(prefs);

    setState(() { _sending = true; _uploadProgress = 0.0; });
    _navCtrl?.setMessengerBusy(true);
    final mediaId = await api.uploadMedia(
      File(xfile.path),
      onProgress: (p) { if (mounted) setState(() => _uploadProgress = p); },
    );
    if (mounted) setState(() => _uploadProgress = null);
    if (mediaId != null && mounted) {
      await api.sendMessage(
        channel: widget.channel.id,
        sender: sender,
        text: '[изображение]',
        type: 'image',
        mediaId: mediaId,
      );
    }
    if (mounted) {
      setState(() => _sending = false);
      _navCtrl?.setMessengerBusy(false);
    }
    _fetch();
  }

  Future<void> _sendFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any, allowMultiple: false, withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final picked = result.files.first;

    File? file;
    if (picked.path != null) {
      file = File(picked.path!);
    } else if (picked.bytes != null) {
      final tmp = File('${(await getTemporaryDirectory()).path}/${picked.name}');
      await tmp.writeAsBytes(picked.bytes!);
      file = tmp;
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть файл')));
      return;
    }

    final prefs = context.read<PrefsService>();
    final api = context.read<ApiService>();
    final sender = _resolveSenderName(prefs);

    setState(() { _sending = true; _uploadProgress = 0.0; });
    _navCtrl?.setMessengerBusy(true);
    final mediaId = await api.uploadMedia(
      file,
      onProgress: (p) { if (mounted) setState(() => _uploadProgress = p); },
    );
    if (mounted) setState(() => _uploadProgress = null);
    if (mediaId != null && mounted) {
      await api.sendMessage(
        channel: widget.channel.id,
        sender: sender,
        text: picked.name,
        type: 'file',
        mediaId: mediaId,
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка загрузки файла')));
    }
    if (mounted) {
      setState(() => _sending = false);
      _navCtrl?.setMessengerBusy(false);
    }
    _fetch();
  }

  Future<Uint8List?> _loadMedia(String mediaId) async {
    if (_mediaCache.containsKey(mediaId)) return _mediaCache[mediaId];
    // Check disk cache
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final cacheFile = File('${cacheDir.path}/media_$mediaId');
      if (await cacheFile.exists()) {
        final bytes = await cacheFile.readAsBytes();
        _mediaCache[mediaId] = bytes;
        return bytes;
      }
    } catch (_) {}
    // Download from server
    final api = context.read<ApiService>();
    final bytes = await api.downloadMedia(mediaId);
    if (bytes != null) {
      _mediaCache[mediaId] = Uint8List.fromList(bytes);
      try {
        final cacheDir = await getApplicationCacheDirectory();
        await File('${cacheDir.path}/media_$mediaId').writeAsBytes(bytes);
      } catch (_) {}
      return _mediaCache[mediaId];
    }
    return null;
  }

  static const _mediaChannel = MethodChannel('com.traffic.app/media');

  Future<void> _saveMedia(
      Uint8List bytes, String mediaId, String type, String text) async {
    try {
      final String fileName;
      final String mimeType;
      if (type == 'image') {
        fileName = 'EOS_$mediaId.jpg';
        mimeType = 'image/jpeg';
      } else {
        final name = text.replaceAll(RegExp(r'[/\\]'), '_');
        fileName = name.isNotEmpty ? name : 'EOS_$mediaId';
        mimeType = 'application/octet-stream';
      }
      await _mediaChannel.invokeMethod<String>('saveToDownloads', {
        'bytes': bytes,
        'fileName': fileName,
        'mimeType': mimeType,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Сохранено: $fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка сохранения')),
        );
      }
    }
  }

  Future<void> _deleteMessage(Message msg) async {
    final api = context.read<ApiService>();
    final ok = await api.deleteMessage(widget.channel.id, msg.id);
    if (ok && mounted) {
      if (msg.mediaId.isNotEmpty) api.deleteMedia(msg.mediaId);
      setState(() => _deletingIds.add(msg.id));
      await Future.delayed(const Duration(milliseconds: 320));
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == msg.id);
          _deletingIds.remove(msg.id);
        });
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить сообщение')),
      );
    }
  }

  void _showMessageMenu(Message msg, bool isMe, Offset globalPos) {
    final menuNotifier = Provider.of<AppThemeNotifier>(context, listen: false);
    final t = menuNotifier.current;
    final size = MediaQuery.of(context).size;
    final items = <PopupMenuEntry<String>>[
      PopupMenuItem<String>(
        value: 'reply',
        child: Row(children: [
          Icon(Icons.reply, color: menuNotifier.accent, size: 20),
          const SizedBox(width: 12),
          Text('Ответить', style: TextStyle(color: t.textPrimary)),
        ]),
      ),
      if (msg.type == 'text' && msg.text.isNotEmpty)
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(children: [
            Icon(Icons.copy, color: menuNotifier.accent, size: 20),
            const SizedBox(width: 12),
            Text('Копировать', style: TextStyle(color: t.textPrimary)),
          ]),
        ),
      if (isMe && msg.type == 'text')
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_outlined, color: menuNotifier.accent, size: 20),
            const SizedBox(width: 12),
            Text('Редактировать', style: TextStyle(color: t.textPrimary)),
          ]),
        ),
      if (isMe)
        PopupMenuItem<String>(
          value: 'delete',
          child: const Row(children: [
            Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
            SizedBox(width: 12),
            Text('Удалить', style: TextStyle(color: Colors.redAccent)),
          ]),
        ),
    ];
    showMenu<String>(
      context: context,
      color: t.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      position: RelativeRect.fromLTRB(
        globalPos.dx,
        globalPos.dy - 8,
        size.width - globalPos.dx,
        size.height - globalPos.dy,
      ),
      items: items,
    ).then((value) {
      if (!mounted) return;
      if (value == 'reply') {
        setState(() => _replyingTo = msg);
        final replyText = msg.text.length > 100 ? msg.text.substring(0, 100) : msg.text;
        _navCtrl?.updateMessengerBanners(
          replyText: replyText,
          replySender: msg.sender,
          onCancelReply: () {
            setState(() => _replyingTo = null);
            _navCtrl?.updateMessengerBanners();
          },
          isEditing: _editingMessage != null,
          onCancelEdit: _editingMessage != null
              ? () {
                  setState(() { _editingMessage = null; _inputCtrl.clear(); });
                  _navCtrl?.updateMessengerBanners();
                }
              : null,
        );
      } else if (value == 'copy') {
        Clipboard.setData(ClipboardData(text: msg.text));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Скопировано'), duration: Duration(seconds: 1)),
        );
      } else if (value == 'edit') {
        setState(() { _editingMessage = msg; _replyingTo = null; });
        _inputCtrl.text = msg.text;
        _inputCtrl.selection = TextSelection.collapsed(offset: msg.text.length);
        _navCtrl?.updateMessengerBanners(
          isEditing: true,
          onCancelEdit: () {
            setState(() { _editingMessage = null; _inputCtrl.clear(); });
            _navCtrl?.updateMessengerBanners();
          },
        );
      } else if (value == 'delete') {
        _deleteMessage(msg);
      }
    });
  }

  String _formatTime(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final notifier = Provider.of<AppThemeNotifier>(context);
    final t = notifier.current;
    final prefs = context.watch<PrefsService>();
    final myName = _resolveSenderName(prefs);
    final isMuted = prefs.isChannelMuted(widget.channel.id);
    final a = notifier.accent;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Фон ──
          Positioned.fill(child: _buildFullBg(t, prefs)),

          // ── Сообщения ──
          Positioned.fill(
            child: _messages.isEmpty
                ? Center(child: Text('Нет сообщений',
                    style: TextStyle(color: t.textSecondary)))
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: EdgeInsets.fromLTRB(
                      12,
                      MediaQuery.of(context).padding.top + 64,
                      12,
                      72 + MediaQuery.of(context).viewPadding.bottom,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) {
                      final msg = _messages[i];
                      final isMe = msg.sender == myName;
                      final showGlitch = _adminSenderName != null &&
                          msg.sender == _adminSenderName;
                      final isDeleting = _deletingIds.contains(msg.id);
                      return AnimatedOpacity(
                        key: ValueKey(msg.id),
                        opacity: isDeleting ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          constraints: isDeleting
                              ? const BoxConstraints(maxHeight: 0)
                              : const BoxConstraints(),
                          child: _AnimatedBubble(
                            animate: !_preloadedIds.contains(msg.id),
                            animType: prefs.chatAnimation,
                            child: _MessageBubble(
                              message: msg,
                              isMe: isMe,
                              isRead: _isRead(msg),
                              theme: t,
                              timeStr: _formatTime(msg.ts),
                              avatarBytes: _avatarCache[msg.sender],
                              showGlitch: showGlitch,
                              showAdminRing: showGlitch,
                              adminAvatarEffect: _adminAvatarEffect,
                              loadMedia: msg.hasMedia
                                  ? () => _loadMedia(msg.mediaId) : null,
                              onSaveMedia: msg.hasMedia
                                  ? (bytes) => _saveMedia(
                                      bytes, msg.mediaId, msg.type, msg.text)
                                  : null,
                              onLongPress: (offset) =>
                                  _showMessageMenu(msg, isMe, offset),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // ── Шапка (плавает, прозрачная снизу) ──
          Positioned(
            top: 0, left: 0, right: 0,
            child: _buildHeader(t, a, prefs, isMuted),
          ),

          // ── Поле ввода (плавает снизу, анимируется при входе) ──
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SlideTransition(
              position: _inputSlide,
              child: _ChatInputArea(
                t: t,
                a: a,
                a2: notifier.accent2,
                inputCtrl: _inputCtrl,
                sending: _sending,
                isRecording: _isRecording,
                recordingLocked: _recordingLocked,
                recordingSeconds: _recordingSeconds,
                videoMode: _videoMode,
                replyingTo: _replyingTo,
                editingMessage: _editingMessage,
                onSend: _send,
                onAttachImage: _sendImage,
                onAttachFile: _sendFile,
                onMicTap: () => setState(() => _videoMode = !_videoMode),
                onMicStart: (y) {
                  _lockDragStartY = y;
                  if (_videoMode) _sendVideoCircle();
                  else _startVoiceRecording();
                },
                onMicMove: (y) {
                  final dy = y - _lockDragStartY;
                  if (dy < -60 && !_recordingLocked && _isRecording) {
                    setState(() => _recordingLocked = true);
                    HapticFeedback.mediumImpact();
                  }
                },
                onMicEnd: () { if (!_recordingLocked) _stopVoiceRecording(); },
                onCancelReply: () => setState(() => _replyingTo = null),
                onCancelEdit: () =>
                    setState(() { _editingMessage = null; _inputCtrl.clear(); }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullBg(ThemeDef t, PrefsService prefs) {
    if (prefs.chatBgType > 0) return _buildChatBg(prefs);
    return Container(color: t.bg);
  }

  Widget _buildHeader(ThemeDef t, Color a, PrefsService prefs, bool isMuted) {
    return SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 14),
          child: Row(children: [
            _MsgCircle(icon: Icons.arrow_back,
                onTap: () => Navigator.pop(context), t: t, a: a),
            const SizedBox(width: 8),
            Expanded(child: _MsgPill(
              t: t, a: a,
              isDm: widget.channel.isDm,
              displayName: widget.channel.isDm
                  ? (_dmDisplayName ?? _dmOtherUserName ?? '...')
                  : widget.channel.displayName,
              avatarName: _dmDisplayName ?? _dmOtherUserName ?? '',
              avatarBytes: widget.channel.isDm
                  ? _avatarCache[_dmOtherUserName ?? '']
                  : null,
              isOnline: _dmIsOnline,
              onTap: widget.channel.isDm && _dmOtherUserName != null
                  ? () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => UserProfileScreen(
                            username: _dmOtherUserName!)))
                  : null,
            )),
            const SizedBox(width: 8),
            _MsgCircle(
              icon: isMuted
                  ? Icons.notifications_off_outlined
                  : Icons.notifications_outlined,
              iconColor: isMuted ? t.textSecondary : a,
              onTap: () {
                if (isMuted) prefs.unmuteChannel(widget.channel.id);
                else prefs.muteChannel(widget.channel.id);
              },
              t: t, a: a,
            ),
          ]),
        ),
    );
  }

  Widget _buildChatBg(PrefsService prefs) {
    switch (prefs.chatBgType) {
      case 1:
        return Container(color: Color(prefs.chatBgColor1));
      case 2:
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(prefs.chatBgColor1), Color(prefs.chatBgColor2)],
            ),
          ),
        );
      case 3:
        if (prefs.chatBgImage != null) {
          return Image.file(
            File(prefs.chatBgImage!),
            fit: BoxFit.cover, width: double.infinity, height: double.infinity,
          );
        }
        return const SizedBox.shrink();
      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Fullscreen photo viewer ───────────────────────────────────────────────────

class _FullscreenPhotoPage extends StatelessWidget {
  final Uint8List bytes;
  final Future<void> Function(Uint8List)? onSave;

  const _FullscreenPhotoPage({required this.bytes, this.onSave});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (onSave != null)
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Скачать',
              onPressed: () => onSave!.call(bytes),
            ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

// ── Audio message widget ──────────────────────────────────────────────────────

class _AudioMessageWidget extends StatefulWidget {
  final Uint8List bytes;
  final String durationHint;

  const _AudioMessageWidget({required this.bytes, required this.durationHint});

  @override
  State<_AudioMessageWidget> createState() => _AudioMessageWidgetState();
}

class _AudioMessageWidgetState extends State<_AudioMessageWidget> {
  final _player = AudioPlayer();
  bool _playing = false;
  bool _ready = false;
  bool _completed = false;
  Duration _pos = Duration.zero;
  Duration _total = Duration.zero;

  @override
  void initState() {
    super.initState();
    _prepare();
    _player.onPositionChanged.listen((d) {
      if (mounted) setState(() => _pos = d);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _total = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _playing = false; _pos = Duration.zero; _completed = true; });
    });
  }

  Future<void> _prepare() async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
      await file.writeAsBytes(widget.bytes);
      await _player.setSource(DeviceFileSource(file.path));
      if (mounted) setState(() => _ready = true);
    } catch (_) {}
  }

  Future<void> _toggle() async {
    if (!_ready) return;
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
    } else {
      if (_completed) {
        await _player.seek(Duration.zero);
        _completed = false;
      }
      await _player.resume();
      if (mounted) setState(() => _playing = true);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2,'0')}:${(d.inSeconds % 60).toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    final progress = _total.inMilliseconds > 0
        ? (_pos.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final label = _ready && _total > Duration.zero ? _fmt(_total) : widget.durationHint;

    return SizedBox(
      width: 220,
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 38, height: 38,
              decoration: const BoxDecoration(
                color: Colors.white24, shape: BoxShape.circle,
              ),
              child: Icon(
                _playing ? Icons.pause : Icons.play_arrow,
                color: Colors.white, size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: progress.toDouble(),
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white70),
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(2),
                ),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Video circle player ───────────────────────────────────────────────────────

class _VideoCirclePlayer extends StatefulWidget {
  final Uint8List bytes;
  const _VideoCirclePlayer({required this.bytes});

  @override
  State<_VideoCirclePlayer> createState() => _VideoCirclePlayerState();
}

class _VideoCirclePlayerState extends State<_VideoCirclePlayer> {
  VideoPlayerController? _ctrl;
  bool _initialized = false;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/vc_${DateTime.now().millisecondsSinceEpoch}.mp4');
      await file.writeAsBytes(widget.bytes);
      final ctrl = VideoPlayerController.file(
        file,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await ctrl.initialize();
      ctrl.setLooping(true);
      if (mounted) setState(() { _ctrl = ctrl; _initialized = true; });
    } catch (_) {}
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_ctrl == null) return;
    if (_playing) {
      _ctrl!.pause();
    } else {
      _ctrl!.play();
    }
    setState(() => _playing = !_playing);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: SizedBox(
        width: 180, height: 180,
        child: ClipOval(
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_initialized && _ctrl != null)
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _ctrl!.value.size.width,
                      height: _ctrl!.value.size.height,
                      child: VideoPlayer(_ctrl!),
                    ),
                  ),
                )
              else
                Container(color: Colors.black38),
              if (!_playing)
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Media message widget ──────────────────────────────────────────────────────

class _MediaMessageWidget extends StatefulWidget {
  final Future<Uint8List?> Function() loader;
  final Future<void> Function(Uint8List)? onSave;
  final String msgType;
  final String msgText;

  const _MediaMessageWidget({
    required this.loader,
    required this.msgType,
    required this.msgText,
    this.onSave,
  });

  @override
  State<_MediaMessageWidget> createState() => _MediaMessageWidgetState();
}

class _MediaMessageWidgetState extends State<_MediaMessageWidget> {
  late final Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  void _openFullscreen(BuildContext ctx, Uint8List bytes) {
    Navigator.push(ctx, MaterialPageRoute(
      builder: (_) => _FullscreenPhotoPage(bytes: bytes, onSave: widget.onSave),
    ));
  }

  void _showFileMenu(BuildContext ctx, Uint8List bytes) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: Theme.of(ctx).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.download_outlined),
          title: const Text('Скачать'),
          onTap: () {
            Navigator.pop(sheetCtx);
            widget.onSave?.call(bytes);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 200, height: 150,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (!snap.hasData || snap.data == null) {
          return const SizedBox(
            width: 200, height: 60,
            child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.white38)),
          );
        }

        if (widget.msgType == 'audio') {
          return _AudioMessageWidget(
            bytes: snap.data!,
            durationHint: widget.msgText,
          );
        }

        if (widget.msgType == 'video_circle') {
          return _VideoCirclePlayer(bytes: snap.data!);
        }

        if (widget.msgType == 'image') {
          return GestureDetector(
            onTap: () => _openFullscreen(ctx, snap.data!),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                snap.data!,
                width: 220,
                fit: BoxFit.fitWidth,
              ),
            ),
          );
        }
        // File card
        return GestureDetector(
          onTap: widget.onSave == null ? null : () => _showFileMenu(ctx, snap.data!),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insert_drive_file_outlined, color: Colors.white70, size: 28),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.msgText,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool isRead;
  final ThemeDef theme;
  final String timeStr;
  final Uint8List? avatarBytes;
  final bool showGlitch;
  final bool showAdminRing;
  final String? adminAvatarEffect;
  final Future<Uint8List?> Function()? loadMedia;
  final Future<void> Function(Uint8List)? onSaveMedia;
  final void Function(Offset)? onLongPress;

  const _MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.isRead,
    required this.theme,
    required this.timeStr,
    this.avatarBytes,
    this.showGlitch = false,
    this.showAdminRing = false,
    this.adminAvatarEffect,
    this.loadMedia,
    this.onSaveMedia,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<AppThemeNotifier>();
    final accent  = notifier.accent;
    final neon = theme.neonGlow;
    final isCircle = message.type == 'video_circle';
    final isImage = message.type == 'image' && loadMedia != null;
    final isGlass = theme.isLiquidGlass || theme.glassy;
    final bgColor = isGlass
        ? (isMe
            ? const Color(0xFF4488FF).withValues(alpha: 0.20)
            : Colors.white.withValues(alpha: 0.09))
        : (isMe ? accent.withValues(alpha: 0.85) : theme.surface);
    final textColor = isMe ? Colors.white : theme.textPrimary;

    final borderRadius = BorderRadius.only(
      topLeft:     const Radius.circular(14),
      topRight:    const Radius.circular(14),
      bottomLeft:  Radius.circular(isMe ? 14 : 2),
      bottomRight: Radius.circular(isMe ? 2 : 14),
    );

    final tsColor = isMe ? Colors.white60 : theme.textSecondary;

    Widget buildBubbleContent() {
      if (isImage) {
        return Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 6, right: 12, bottom: 2),
                child: Text(message.sender,
                  style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            if (message.replyToId != null && message.replyToText != null)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  border: Border(left: BorderSide(color: accent, width: 3)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(message.replyToText!,
                  style: TextStyle(color: theme.textSecondary, fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            _MediaMessageWidget(
              loader: loadMedia!,
              onSave: onSaveMedia,
              msgType: message.type,
              msgText: message.text,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, top: 2, bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.edited) ...[
                    Icon(Icons.edit, size: 10, color: tsColor),
                    const SizedBox(width: 3),
                    Text('изменено', style: TextStyle(color: tsColor, fontSize: 10)),
                    const SizedBox(width: 4),
                  ],
                  Text(timeStr, style: TextStyle(color: tsColor, fontSize: 11)),
                ],
              ),
            ),
          ],
        );
      }

      return Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Text(message.sender,
              style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          if (message.replyToId != null && message.replyToText != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                border: Border(left: BorderSide(color: accent, width: 3)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                message.replyToText!,
                style: TextStyle(color: theme.textSecondary, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (loadMedia != null)
            _MediaMessageWidget(
              loader: loadMedia!,
              onSave: onSaveMedia,
              msgType: message.type,
              msgText: message.text,
            )
          else
            Text(message.text, style: neon
                ? TextStyle(color: textColor, fontSize: context.read<PrefsService>().chatTextSize).withNeonGlow(accent)
                : TextStyle(color: textColor, fontSize: context.read<PrefsService>().chatTextSize)),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.edited) ...[
                Icon(Icons.edit, size: 10, color: tsColor),
                const SizedBox(width: 3),
                Text('изменено', style: TextStyle(color: tsColor, fontSize: 10)),
                const SizedBox(width: 4),
              ],
              Text(timeStr, style: TextStyle(color: tsColor, fontSize: 11)),
              if (isMe) ...[
                const SizedBox(width: 3),
                Icon(
                  isRead ? Icons.done_all : Icons.check,
                  size: 13,
                  color: isRead ? Colors.lightBlueAccent : Colors.white54,
                ),
              ],
            ],
          ),
        ],
      );
    }

    final bubble = GestureDetector(
      onLongPressStart: onLongPress == null ? null : (d) => onLongPress!(d.globalPosition),
      child: isCircle
          ? Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (loadMedia != null)
                  _MediaMessageWidget(
                    loader: loadMedia!,
                    onSave: onSaveMedia,
                    msgType: message.type,
                    msgText: message.text,
                  ),
                const SizedBox(height: 2),
                Text(timeStr,
                  style: TextStyle(
                    color: isMe ? Colors.white60 : theme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            )
          : ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              child: isImage
                  ? buildBubbleContent()
                  : isGlass
                      ? ClipRRect(
                          borderRadius: borderRadius,
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: borderRadius,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: isMe ? 0.20 : 0.10),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: buildBubbleContent(),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(color: bgColor, borderRadius: borderRadius),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: buildBubbleContent(),
                        ),
            ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserProfileScreen(
                    username: message.sender,
                    email: showAdminRing ? PrefsService.adminEmail : null,
                  ),
                ),
              ),
              child: AdminAvatarWidget(
                name: message.sender,
                bytes: avatarBytes,
                radius: 16,
                isAdminAvatar: showAdminRing,
                effectOverride: showAdminRing ? adminAvatarEffect : null,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(child: bubble),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final ThemeDef theme;
  final bool sending;
  final double? uploadProgress;
  final bool isRecording;
  final bool videoMode;
  final bool recordingLocked;
  final int recordingSeconds;
  final VoidCallback onSend;
  final VoidCallback onMedia;
  final VoidCallback onMicTap;
  final void Function(double startY) onMicStart;
  final void Function(double globalY) onMicMove;
  final VoidCallback onMicEnd;
  final Message? editingMessage;
  final Message? replyingTo;
  final VoidCallback? onCancelEdit;
  final VoidCallback? onCancelReply;
  final String Function(int) formatDuration;

  const _InputBar({
    required this.controller,
    required this.theme,
    required this.sending,
    this.uploadProgress,
    required this.isRecording,
    required this.videoMode,
    required this.recordingLocked,
    required this.recordingSeconds,
    required this.onSend,
    required this.onMedia,
    required this.onMicTap,
    required this.onMicStart,
    required this.onMicMove,
    required this.onMicEnd,
    this.editingMessage,
    this.replyingTo,
    this.onCancelEdit,
    this.onCancelReply,
    required this.formatDuration,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  double _lockIndicatorOffset = 0.0; // px, отрицательное = вверх

  @override
  Widget build(BuildContext context) {
    final w      = widget;
    final accent = context.read<AppThemeNotifier>().accent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (w.replyingTo != null)
          Container(
            color: accent.withValues(alpha: 0.10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Container(width: 3, height: 32, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(w.replyingTo!.sender, style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w600)),
                      Text(w.replyingTo!.text, style: TextStyle(color: w.theme.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(icon: Icon(Icons.close, size: 18, color: w.theme.textSecondary), onPressed: w.onCancelReply, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ],
            ),
          ),
        if (w.editingMessage != null)
          Container(
            color: accent.withValues(alpha: 0.10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.edit, size: 16, color: accent),
                const SizedBox(width: 8),
                Expanded(child: Text('Редактирование', style: TextStyle(color: accent, fontSize: 13))),
                IconButton(icon: Icon(Icons.close, size: 18, color: w.theme.textSecondary), onPressed: w.onCancelEdit, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ],
            ),
          ),
        Container(
          color: w.theme.nav,
          padding: EdgeInsets.only(
            left: 12, right: 8, top: 8,
            bottom: MediaQuery.of(context).padding.bottom + 8,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.attach_file, color: w.theme.textSecondary),
                    onPressed: w.sending ? null : w.onMedia,
                  ),
                  Expanded(
                    child: w.isRecording
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: w.theme.surface,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                const _PulsingDot(),
                                const SizedBox(width: 8),
                                Text(
                                  w.formatDuration(w.recordingSeconds),
                                  style: TextStyle(color: w.theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                                const Spacer(),
                                if (!w.recordingLocked)
                                  Text('↑ Закрепить', style: TextStyle(color: w.theme.textSecondary, fontSize: 12))
                                else
                                  const Icon(Icons.lock, color: Colors.redAccent, size: 16),
                              ],
                            ),
                          )
                        : TextField(
                            controller: w.controller,
                            style: TextStyle(color: w.theme.textPrimary),
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => w.onSend(),
                            decoration: InputDecoration(
                              hintText: 'Сообщение...',
                              hintStyle: TextStyle(color: w.theme.textSecondary),
                              filled: true,
                              fillColor: w.theme.surface,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 6),
                  // Mic / Video button
                  GestureDetector(
                    onTap: w.isRecording ? null : w.onMicTap,
                    onLongPressStart: w.sending ? null : (d) {
                      setState(() => _lockIndicatorOffset = 0);
                      w.onMicStart(d.globalPosition.dy);
                    },
                    onLongPressMoveUpdate: (d) {
                      final dy = d.offsetFromOrigin.dy;
                      setState(() => _lockIndicatorOffset = dy.clamp(-80.0, 0.0));
                      w.onMicMove(d.globalPosition.dy);
                    },
                    onLongPressEnd: w.sending ? null : (_) {
                      setState(() => _lockIndicatorOffset = 0);
                      w.onMicEnd();
                    },
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: w.isRecording
                            ? Colors.redAccent
                            : accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        w.isRecording
                            ? (w.recordingLocked ? Icons.lock : Icons.mic)
                            : (w.videoMode ? Icons.videocam : Icons.mic),
                        color: w.isRecording ? Colors.white : accent,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  w.uploadProgress != null
                      ? SizedBox(
                          width: 42, height: 42,
                          child: CircularProgressIndicator(
                            value: w.uploadProgress,
                            color: accent,
                            strokeWidth: 3,
                            backgroundColor: accent.withValues(alpha: 0.2),
                          ),
                        )
                      : w.sending
                          ? SizedBox(
                              width: 36, height: 36,
                              child: CircularProgressIndicator(color: accent, strokeWidth: 2),
                            )
                          : GestureDetector(
                              onTap: w.onSend,
                              child: Container(
                                width: 42, height: 42,
                                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                                child: const Icon(Icons.send, color: Colors.white, size: 20),
                              ),
                            ),
                ],
              ),
              // Lock indicator: плавающий замок над кнопкой микрофона при записи
              if (w.isRecording && !w.recordingLocked && _lockIndicatorOffset < -8)
                Positioned(
                  right: 6 + 42 + 6 + 19 - 9, // выровнять по центру mic кнопки
                  bottom: 38 + (-_lockIndicatorOffset).clamp(0.0, 80.0),
                  child: Icon(
                    Icons.lock_outline,
                    color: Colors.redAccent.withValues(alpha: 0.8),
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Pulsing recording dot ─────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 10, height: 10,
        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
      ),
    );
  }
}

// ── Animated bubble wrapper ───────────────────────────────────────────────────

class _AnimatedBubble extends StatefulWidget {
  final Widget child;
  final bool animate;
  final String animType;

  const _AnimatedBubble({
    super.key,
    required this.child,
    this.animate = true,
    this.animType = 'slide',
  });

  @override
  State<_AnimatedBubble> createState() => _AnimatedBubbleState();
}

class _AnimatedBubbleState extends State<_AnimatedBubble>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;
  Animation<double>? _anim;

  @override
  void initState() {
    super.initState();
    if (widget.animate && widget.animType != 'none'
        && widget.animType != 'glitch' && widget.animType != 'pixels') {
      final curve = widget.animType == 'bounce'
          ? const ElasticOutCurve(0.8)
          : Curves.easeOutCubic;
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 280),
      );
      _anim = CurvedAnimation(parent: _ctrl!, curve: curve);
      _ctrl!.forward();
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.animType == 'glitch') {
      return widget.animate ? _GlitchBubble(child: widget.child) : widget.child;
    }
    if (widget.animType == 'pixels') {
      return widget.animate ? _PixelAssembleBubble(child: widget.child) : widget.child;
    }
    if (_ctrl == null || _anim == null) return widget.child;
    switch (widget.animType) {
      case 'fade':
        return FadeTransition(opacity: _anim!, child: widget.child);
      case 'scale':
      case 'bounce':
        return ScaleTransition(scale: _anim!, child: widget.child);
      case 'slide':
      default:
        final slide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
            .animate(_anim!);
        final fade = CurvedAnimation(parent: _ctrl!, curve: Curves.easeOut);
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(position: slide, child: widget.child),
        );
    }
  }
}

// ── Глитч-анимация пузырька ──────────────────────────────────────────────────

class _GlitchBubble extends StatefulWidget {
  final Widget child;
  const _GlitchBubble({required this.child});
  @override
  State<_GlitchBubble> createState() => _GlitchBubbleState();
}

class _GlitchBubbleState extends State<_GlitchBubble> {
  final _key = GlobalKey();
  ui.Image? _img;
  List<double> _offsets = List.filled(10, 0.0);
  Timer? _t;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final rb = _key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (rb == null) return;
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final img = await rb.toImage(pixelRatio: dpr);
      if (!mounted) return;
      setState(() => _img = img);
      final end = DateTime.now().add(const Duration(milliseconds: 480));
      final rng = Random();
      _t = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (!mounted || DateTime.now().isAfter(end)) {
          timer.cancel();
          if (mounted) setState(() => _img = null);
          return;
        }
        setState(() => _offsets = List.generate(
          10, (i) => rng.nextDouble() > 0.65 ? (rng.nextDouble() - 0.5) * 28 : 0.0));
      });
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_img == null) {
      return RepaintBoundary(key: _key, child: widget.child);
    }
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return CustomPaint(
      painter: _GlitchPainter(_img!, _offsets, dpr),
      size: Size(_img!.width / dpr, _img!.height / dpr),
    );
  }
}

class _GlitchPainter extends CustomPainter {
  final ui.Image img;
  final List<double> offsets;
  final double dpr;
  _GlitchPainter(this.img, this.offsets, this.dpr);

  @override
  void paint(Canvas canvas, Size size) {
    final n = offsets.length;
    final sh = size.height / n;
    final srcH = img.height / n;
    for (int i = 0; i < n; i++) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, i * sh, size.width, sh));
      canvas.translate(offsets[i], 0);
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, i * srcH, img.width.toDouble(), srcH),
        Rect.fromLTWH(0, i * sh, size.width, sh),
        Paint(),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _GlitchPainter old) =>
      old.offsets != offsets || old.img != img;
}

// ── Пиксельная сборка пузырька ───────────────────────────────────────────────

class _PixelAssembleBubble extends StatefulWidget {
  final Widget child;
  const _PixelAssembleBubble({required this.child});
  @override
  State<_PixelAssembleBubble> createState() => _PixelAssembleBubbleState();
}

class _PixelAssembleBubbleState extends State<_PixelAssembleBubble>
    with SingleTickerProviderStateMixin {
  final _key = GlobalKey();
  ui.Image? _img;
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final rb = _key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (rb == null) return;
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final img = await rb.toImage(pixelRatio: dpr);
      if (!mounted) return;
      setState(() => _img = img);
      _ctrl.forward();
    });
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() => _img = null);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_img == null) {
      return RepaintBoundary(key: _key, child: widget.child);
    }
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => CustomPaint(
        painter: _PixelAssemblePainter(_img!, _anim.value, dpr),
        size: Size(_img!.width / dpr, _img!.height / dpr),
      ),
    );
  }
}

class _PixelAssemblePainter extends CustomPainter {
  final ui.Image img;
  final double progress;
  final double dpr;
  _PixelAssemblePainter(this.img, this.progress, this.dpr);

  @override
  void paint(Canvas canvas, Size size) {
    const bw = 7.0;
    const bh = 7.0;
    final cols = (size.width / bw).ceil();
    final rows = (size.height / bh).ceil();
    final rng = Random(42);
    final scaleX = img.width / size.width;
    final scaleY = img.height / size.height;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final tx = c * bw;
        final ty = r * bh;
        final sx = (rng.nextDouble() - 0.3) * size.width * 3;
        final sy = (rng.nextDouble() - 0.3) * size.height * 3;
        final x = ui.lerpDouble(sx, tx, progress)!;
        final y = ui.lerpDouble(sy, ty, progress)!;
        canvas.save();
        canvas.clipRect(Rect.fromLTWH(x, y, bw, bh));
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(tx * scaleX, ty * scaleY, bw * scaleX, bh * scaleY),
          Rect.fromLTWH(x, y, bw, bh),
          Paint(),
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PixelAssemblePainter old) =>
      old.progress != progress || old.img != img;
}

// ── Локальный input bar мессенджера ──────────────────────────────────────────

class _ChatInputArea extends StatefulWidget {
  final ThemeDef t;
  final Color a;
  final Color a2;
  final TextEditingController inputCtrl;
  final bool sending;
  final bool isRecording;
  final bool recordingLocked;
  final int recordingSeconds;
  final bool videoMode;
  final Message? replyingTo;
  final Message? editingMessage;
  final VoidCallback onSend;
  final VoidCallback onAttachImage;
  final VoidCallback onAttachFile;
  final VoidCallback onMicTap;
  final void Function(double) onMicStart;
  final void Function(double) onMicMove;
  final VoidCallback onMicEnd;
  final VoidCallback onCancelReply;
  final VoidCallback onCancelEdit;

  const _ChatInputArea({
    required this.t, required this.a, required this.a2,
    required this.inputCtrl, required this.sending,
    required this.isRecording, required this.recordingLocked,
    required this.recordingSeconds, required this.videoMode,
    required this.onSend, required this.onAttachImage, required this.onAttachFile, required this.onMicTap,
    required this.onMicStart, required this.onMicMove, required this.onMicEnd,
    required this.onCancelReply, required this.onCancelEdit,
    this.replyingTo, this.editingMessage,
  });

  @override
  State<_ChatInputArea> createState() => _ChatInputAreaState();
}

class _ChatInputAreaState extends State<_ChatInputArea> {
  static String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  final _attachKey = GlobalKey();
  OverlayEntry? _attachOverlay;
  bool _attachOpen = false;

  @override
  void dispose() {
    _closeAttach();
    super.dispose();
  }

  void _toggleAttach() {
    if (_attachOpen) {
      _closeAttach();
    } else {
      final box = _attachKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return;
      final pos = box.localToGlobal(Offset.zero);
      setState(() => _attachOpen = true);
      _attachOverlay = OverlayEntry(
        builder: (_) => _AttachMenuOverlay(
          anchor: pos,
          t: widget.t,
          onImage: () { _closeAttach(); widget.onAttachImage(); },
          onFile:  () { _closeAttach(); widget.onAttachFile();  },
          onClose: _closeAttach,
        ),
      );
      Overlay.of(context).insert(_attachOverlay!);
    }
  }

  void _closeAttach() {
    _attachOverlay?.remove();
    _attachOverlay = null;
    if (mounted) setState(() => _attachOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final a = widget.a;
    final a2 = widget.a2;
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    final isRecording = widget.isRecording;
    final locked = widget.recordingLocked;

    Widget? replyBanner;
    if (widget.replyingTo != null) {
      replyBanner = Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        decoration: BoxDecoration(
          color: a.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Row(children: [
          Container(width: 3, height: 28,
            decoration: BoxDecoration(color: a, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.replyingTo!.sender,
                style: TextStyle(color: a, fontSize: 12, fontWeight: FontWeight.w600)),
              Text(widget.replyingTo!.text,
                style: TextStyle(color: t.textSecondary, fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          )),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: t.textSecondary),
            onPressed: widget.onCancelReply,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ]),
      );
    }

    Widget? editBanner;
    if (widget.editingMessage != null) {
      editBanner = Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        decoration: BoxDecoration(
          color: a.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Row(children: [
          Icon(Icons.edit, size: 16, color: a),
          const SizedBox(width: 8),
          Expanded(child: Text('Редактирование', style: TextStyle(color: a, fontSize: 13))),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: t.textSecondary),
            onPressed: widget.onCancelEdit,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ]),
      );
    }

    final micIcon = isRecording
        ? (locked ? Icons.lock : Icons.mic)
        : (widget.videoMode ? Icons.videocam : Icons.mic);

    // Содержимое пилюли: текст + кружок микрофона справа
    final pillContent = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(width: 14),
        Expanded(
          child: isRecording
              ? Row(children: [
                  const _RecordingPulse(),
                  const SizedBox(width: 8),
                  Text(_fmt(widget.recordingSeconds),
                    style: TextStyle(color: t.textPrimary, fontSize: 14,
                      fontWeight: FontWeight.w500)),
                  const Spacer(),
                  if (!locked)
                    Text('↑ Закрепить', style: TextStyle(color: t.textSecondary, fontSize: 12))
                  else
                    const Icon(Icons.lock, color: Colors.redAccent, size: 16),
                ])
              : TextField(
                  controller: widget.inputCtrl,
                  style: TextStyle(color: t.textPrimary, fontSize: 13),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => widget.onSend(),
                  decoration: InputDecoration.collapsed(
                    hintText: 'Сообщение...',
                    hintStyle: TextStyle(color: t.textSecondary, fontSize: 13),
                  ),
                ),
        ),
        const SizedBox(width: 8),
        // Кружок микрофона внутри пилюли
        GestureDetector(
          onTap: isRecording ? null : widget.onMicTap,
          onLongPressStart: (d) => widget.onMicStart(d.globalPosition.dy),
          onLongPressMoveUpdate: (d) => widget.onMicMove(d.globalPosition.dy),
          onLongPressEnd: (_) => widget.onMicEnd(),
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isRecording
                  ? const Color(0xFFCC2222).withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.13),
              border: Border.all(
                color: isRecording
                    ? const Color(0xFFFF4444).withValues(alpha: 0.60)
                    : Colors.white.withValues(alpha: 0.22),
                width: 0.7,
              ),
            ),
            child: Center(child: Icon(micIcon,
              color: isRecording ? Colors.white : t.textSecondary, size: 16)),
          ),
        ),
        const SizedBox(width: 10),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (replyBanner != null) replyBanner,
        if (editBanner != null) editBanner,
        Padding(
          padding: EdgeInsets.fromLTRB(12, 6, 12, 10 + safeBottom),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Скрепка
              AnimatedRotation(
                turns: _attachOpen ? 0.125 : 0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: SizedBox(
                  key: _attachKey,
                  child: _buildGlassCircle(
                    icon: Icons.attach_file,
                    tint: const Color(0xFF9E9E9E),
                    onTap: _toggleAttach,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Стеклянная пилюля с текстом и микрофоном
              Expanded(child: _buildGlassPill(t, a, a2, pillContent)),
              const SizedBox(width: 8),
              // Отправка — голубой стеклянный кружок
              _buildGlassCircle(
                icon: Icons.send_rounded,
                tint: a,
                onTap: widget.sending ? null : widget.onSend,
                busy: widget.sending,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCircle({
    required IconData icon,
    required Color tint,
    required VoidCallback? onTap,
    bool busy = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [tint.withValues(alpha: 0.32), tint.withValues(alpha: 0.14)],
                ),
                border: Border.all(color: tint.withValues(alpha: 0.38), width: 0.8),
              ),
              child: Center(
                child: busy
                    ? SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: tint))
                    : Icon(icon, color: tint.withValues(alpha: 0.90), size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassPill(ThemeDef t, Color a, Color a2, Widget child) {
    if (t.isLiquidGlass || t.glassy) {
      return Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 20, offset: const Offset(0, 5))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.18),
                        Colors.white.withValues(alpha: 0.08),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(left: 0, top: 0, bottom: 0,
              child: Container(width: 8,
                decoration: const BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.centerLeft, end: Alignment.centerRight,
                  colors: [Color(0x4DFFFFFF), Colors.transparent])))),
            Positioned(right: 0, top: 0, bottom: 0,
              child: Container(width: 8,
                decoration: const BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.centerRight, end: Alignment.centerLeft,
                  colors: [Color(0x4DFFFFFF), Colors.transparent])))),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 0.8),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: child,
              ),
            ),
          ]),
        ),
      );
    } else if (t.neonGlow) {
      return Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: a2.withValues(alpha: 0.50)),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 20, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(color: t.nav.withValues(alpha: 0.90), child: child),
          ),
        ),
      );
    } else {
      return Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: t.cyberpunk ? a.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.08),
            width: t.cyberpunk ? 1.0 : 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: t.cyberpunk ? a.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.30),
              blurRadius: t.cyberpunk ? 20 : 24, offset: const Offset(0, 4)),
            if (t.cyberpunk) BoxShadow(color: a2.withValues(alpha: 0.12), blurRadius: 40),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: t.cyberpunk
                    ? Colors.black.withValues(alpha: 0.82)
                    : t.nav.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(32),
              ),
              child: child,
            ),
          ),
        ),
      );
    }
  }
}

class _RecordingPulse extends StatefulWidget {
  const _RecordingPulse();
  @override
  State<_RecordingPulse> createState() => _RecordingPulseState();
}

class _RecordingPulseState extends State<_RecordingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: _scale,
    child: Container(
      width: 10, height: 10,
      decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
    ),
  );
}

// ── Кастомная шапка мессенджера ──────────────────────────────────────────────

class _MsgCircle extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback? onTap;
  final ThemeDef t;
  final Color a;
  const _MsgCircle({required this.icon, required this.onTap,
    required this.t, required this.a, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final col = iconColor ?? a;
    final isGlass = t.isLiquidGlass || t.glassy;
    final inner = Center(child: Icon(icon, color: col, size: 20));
    if (isGlass) {
      return GestureDetector(
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.22),
                    Colors.white.withValues(alpha: 0.10),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.28), width: 0.8),
              ),
              child: inner,
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: t.nav.withValues(alpha: 0.95),
          border: Border.all(color: t.cardBorder, width: 0.8),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12, offset: const Offset(0, 3))],
        ),
        child: inner,
      ),
    );
  }
}

class _MsgPill extends StatelessWidget {
  final ThemeDef t;
  final Color a;
  final bool isDm;
  final String displayName;
  final String avatarName;
  final Uint8List? avatarBytes;
  final bool isOnline;
  final VoidCallback? onTap;
  const _MsgPill({required this.t, required this.a, required this.isDm,
    required this.displayName, required this.avatarName,
    this.avatarBytes, this.isOnline = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final avatarWidget = isDm
        ? Stack(clipBehavior: Clip.none, children: [
            CircularAvatar(name: avatarName, bytes: avatarBytes, radius: 18),
            if (isOnline) Positioned(right: 0, bottom: 0,
              child: Container(width: 10, height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF00C853), shape: BoxShape.circle))),
          ])
        : CircleAvatar(radius: 18, backgroundColor: a.withValues(alpha: 0.2),
            child: Icon(Icons.group, color: a, size: 18));

    final row = GestureDetector(
      onTap: onTap,
      child: SizedBox.expand(child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 14),
          avatarWidget,
          const SizedBox(width: 10),
          Expanded(child: Text(displayName,
            style: TextStyle(color: t.textPrimary,
              fontWeight: FontWeight.w600, fontSize: 15),
            overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 14),
        ],
      )),
    );

    final isGlass = t.isLiquidGlass || t.glassy;
    if (isGlass) {
      return Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 20, offset: const Offset(0, 5))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0.08),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25), width: 0.8),
                borderRadius: BorderRadius.circular(32),
              ),
              child: row,
            ),
          ),
        ),
      );
    }
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: t.nav.withValues(alpha: 0.95),
        border: Border.all(color: t.cardBorder, width: 0.8),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32), child: row),
    );
  }
}

// ── Оверлей меню прикрепления (Фото / Файл) ──────────────────────────────────

class _AttachMenuOverlay extends StatefulWidget {
  final Offset anchor;
  final ThemeDef t;
  final VoidCallback onImage;
  final VoidCallback onFile;
  final VoidCallback onClose;

  const _AttachMenuOverlay({
    required this.anchor,
    required this.t,
    required this.onImage,
    required this.onFile,
    required this.onClose,
  });

  @override
  State<_AttachMenuOverlay> createState() => _AttachMenuOverlayState();
}

class _AttachMenuOverlayState extends State<_AttachMenuOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _a1, _a2;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260))
      ..forward();
    _a1 = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic));
    _a2 = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.25, 1.0, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _item(Animation<double> anim, IconData icon, Color tint, String label,
      VoidCallback onTap) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, child) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - anim.value)),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: ClipOval(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          tint.withValues(alpha: 0.38),
                          tint.withValues(alpha: 0.16),
                        ],
                      ),
                      border: Border.all(
                          color: tint.withValues(alpha: 0.50), width: 0.9),
                    ),
                    child: Icon(icon, color: tint.withValues(alpha: 0.95), size: 20),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ax = widget.anchor.dx;
    final ay = widget.anchor.dy;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onClose,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
          ),
          // Фото — ближе к кнопке
          Positioned(
            top: ay - 104,
            left: ax,
            child: _item(_a1, Icons.image_rounded, const Color(0xFF66BB6A),
                'Фото', widget.onImage),
          ),
          // Файл — выше
          Positioned(
            top: ay - 160,
            left: ax,
            child: _item(_a2, Icons.insert_drive_file_rounded,
                const Color(0xFF9E9E9E), 'Файл', widget.onFile),
          ),
        ],
      ),
    );
  }
}
