import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/prefs_service.dart';
import '../models/message.dart';
import '../models/channel.dart';
import '../widgets/admin_avatar_widget.dart';
import '../widgets/circular_avatar.dart';
import '../main.dart' show currentChatChannelId;
import 'user_profile_screen.dart';
import 'video_circle_recorder.dart';

class MessengerScreen extends StatefulWidget {
  final Channel channel;
  const MessengerScreen({super.key, required this.channel});

  @override
  State<MessengerScreen> createState() => _MessengerScreenState();
}

class _MessengerScreenState extends State<MessengerScreen> {
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

  @override
  void initState() {
    super.initState();
    currentChatChannelId = widget.channel.id;
    _loadDeviceName();
    _fetchAdminName();
    _loadLocalHistory().then((_) => _fetch());
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _fetch());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prefs = context.read<PrefsService>();
      final name = _resolveSenderName(prefs);
      setState(() => _myName = name);
      if (widget.channel.isDm) _initDmUser(name);
    });
  }

  @override
  void dispose() {
    currentChatChannelId = null;
    _timer?.cancel();
    _recordingTimer?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _recorder.dispose();
    super.dispose();
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
    }
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
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
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
        _startRecordingTimer();
      }
    } catch (_) {}
  }

  void _startRecordingTimer() {
    _recordingSeconds = 0;
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordingSeconds++);
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    if (mounted) setState(() { _recordingSeconds = 0; _recordingLocked = false; });
  }

  String _formatRecordDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
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

      setState(() => _sending = true);
      final mediaId = await api.uploadMedia(file);
      if (mediaId != null && mounted) {
        await api.sendMessage(
          channel: widget.channel.id,
          sender: sender,
          text: '🎤 Голосовое',
          type: 'audio',
          mediaId: mediaId,
        );
      }
      if (mounted) setState(() => _sending = false);
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

    setState(() => _sending = true);
    final mediaId = await api.uploadMedia(File(path));
    if (mediaId != null && mounted) {
      await api.sendMessage(
        channel: widget.channel.id,
        sender: sender,
        text: '🎥 Видео-кружок',
        type: 'video_circle',
        mediaId: mediaId,
      );
    }
    if (mounted) setState(() => _sending = false);
    _fetch();
  }

  // ── Медиа ─────────────────────────────────────────────────────────────────────

  void _pickMedia() {
    final t = Provider.of<AppThemeNotifier>(context, listen: false).current;
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
              leading: Icon(Icons.image_outlined, color: t.accent),
              title: Text('Изображение', style: TextStyle(color: t.textPrimary)),
              onTap: () { Navigator.pop(ctx); _sendImage(); },
            ),
            ListTile(
              leading: Icon(Icons.attach_file, color: t.accent),
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

    setState(() => _sending = true);
    final mediaId = await api.uploadMedia(File(xfile.path));
    if (mediaId != null && mounted) {
      await api.sendMessage(
        channel: widget.channel.id,
        sender: sender,
        text: '[изображение]',
        type: 'image',
        mediaId: mediaId,
      );
    }
    if (mounted) setState(() => _sending = false);
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

    setState(() => _sending = true);
    final mediaId = await api.uploadMedia(file);
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
    if (mounted) setState(() => _sending = false);
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
      setState(() => _messages.removeWhere((m) => m.id == msg.id));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить сообщение')),
      );
    }
  }

  void _showMessageMenu(Message msg, bool isMe, Offset globalPos) {
    final t = Provider.of<AppThemeNotifier>(context, listen: false).current;
    final size = MediaQuery.of(context).size;
    final items = <PopupMenuEntry<String>>[
      PopupMenuItem<String>(
        value: 'reply',
        child: Row(children: [
          Icon(Icons.reply, color: t.accent, size: 20),
          const SizedBox(width: 12),
          Text('Ответить', style: TextStyle(color: t.textPrimary)),
        ]),
      ),
      if (msg.type == 'text' && msg.text.isNotEmpty)
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(children: [
            Icon(Icons.copy, color: t.accent, size: 20),
            const SizedBox(width: 12),
            Text('Копировать', style: TextStyle(color: t.textPrimary)),
          ]),
        ),
      if (isMe && msg.type == 'text')
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_outlined, color: t.accent, size: 20),
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
      } else if (value == 'copy') {
        Clipboard.setData(ClipboardData(text: msg.text));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Скопировано'), duration: Duration(seconds: 1)),
        );
      } else if (value == 'edit') {
        setState(() { _editingMessage = msg; _replyingTo = null; });
        _inputCtrl.text = msg.text;
        _inputCtrl.selection = TextSelection.collapsed(offset: msg.text.length);
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
    final t = Provider.of<AppThemeNotifier>(context).current;
    final prefs = context.watch<PrefsService>();
    final myName = _resolveSenderName(prefs);
    final isMuted = prefs.isChannelMuted(widget.channel.id);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.nav,
        title: GestureDetector(
          onTap: widget.channel.isDm && _dmOtherUserName != null
              ? () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => UserProfileScreen(username: _dmOtherUserName!)))
              : null,
          child: Row(
            children: [
              widget.channel.isDm
                  ? CircularAvatar(
                      name: _dmDisplayName ?? _dmOtherUserName ?? '',
                      bytes: _avatarCache[_dmOtherUserName ?? ''],
                      radius: 18)
                  : CircleAvatar(
                      radius: 18,
                      backgroundColor: t.accent.withValues(alpha: 0.2),
                      child: Icon(Icons.group, color: t.accent, size: 18),
                    ),
              const SizedBox(width: 10),
              Text(
                widget.channel.isDm
                    ? (_dmDisplayName ?? _dmOtherUserName ?? '...')
                    : widget.channel.displayName,
                style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        iconTheme: IconThemeData(color: t.textPrimary),
        actions: [
          IconButton(
            icon: Icon(isMuted ? Icons.notifications_off_outlined : Icons.notifications_outlined,
                color: isMuted ? t.textSecondary : t.accent),
            tooltip: isMuted ? 'Включить уведомления' : 'Выключить уведомления',
            onPressed: () {
              if (isMuted) {
                prefs.unmuteChannel(widget.channel.id);
              } else {
                prefs.muteChannel(widget.channel.id);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(child: Text('Нет сообщений', style: TextStyle(color: t.textSecondary)))
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) {
                      final msg = _messages[i];
                      final isMe = msg.sender == myName;
                      final showGlitch = _adminSenderName != null &&
                          msg.sender == _adminSenderName;
                      return _AnimatedBubble(
                        key: ValueKey(msg.id),
                        animate: !_preloadedIds.contains(msg.id),
                        child: _MessageBubble(
                          message: msg,
                          isMe: isMe,
                          theme: t,
                          timeStr: _formatTime(msg.ts),
                          avatarBytes: _avatarCache[msg.sender],
                          showGlitch: showGlitch,
                          showAdminRing: showGlitch,
                          adminAvatarEffect: _adminAvatarEffect,
                          loadMedia: msg.hasMedia ? () => _loadMedia(msg.mediaId) : null,
                          onSaveMedia: msg.hasMedia
                              ? (bytes) => _saveMedia(bytes, msg.mediaId, msg.type, msg.text)
                              : null,
                          onLongPress: (offset) => _showMessageMenu(msg, isMe, offset),
                        ),
                      );
                    },
                  ),
          ),
          _InputBar(
            controller: _inputCtrl,
            theme: t,
            sending: _sending,
            isRecording: _isRecording,
            videoMode: _videoMode,
            recordingLocked: _recordingLocked,
            recordingSeconds: _recordingSeconds,
            onSend: _send,
            onMedia: _pickMedia,
            onMicTap: () => setState(() => _videoMode = !_videoMode),
            onMicStart: (startY) {
              _lockDragStartY = startY;
              if (_videoMode) {
                _sendVideoCircle();
              } else {
                _startVoiceRecording();
              }
            },
            onMicMove: (globalY) {
              final dy = globalY - _lockDragStartY;
              if (dy < -60 && !_recordingLocked && _isRecording) {
                setState(() => _recordingLocked = true);
                HapticFeedback.mediumImpact();
              }
            },
            onMicEnd: () {
              if (!_recordingLocked) _stopVoiceRecording();
            },
            editingMessage: _editingMessage,
            replyingTo: _replyingTo,
            onCancelEdit: () => setState(() { _editingMessage = null; _inputCtrl.clear(); }),
            onCancelReply: () => setState(() => _replyingTo = null),
            formatDuration: _formatRecordDuration,
          ),
        ],
      ),
    );
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
              child: SizedBox(
                width: 200, height: 150,
                child: Image.memory(snap.data!, fit: BoxFit.cover, width: 200, height: 150),
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
    final isCircle = message.type == 'video_circle';
    final isImage = message.type == 'image' && loadMedia != null;
    final isGlass = theme.isLiquidGlass || theme.glassy;
    final bgColor = isGlass
        ? (isMe
            ? const Color(0xFF4488FF).withValues(alpha: 0.20)
            : Colors.white.withValues(alpha: 0.09))
        : (isMe ? theme.accent.withValues(alpha: 0.85) : theme.surface);
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
                  style: TextStyle(color: theme.accent, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            if (message.replyToId != null && message.replyToText != null)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  border: Border(left: BorderSide(color: theme.accent, width: 3)),
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
              style: TextStyle(color: theme.accent, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          if (message.replyToId != null && message.replyToText != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                border: Border(left: BorderSide(color: theme.accent, width: 3)),
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
            Text(message.text, style: TextStyle(color: textColor, fontSize: 15)),
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
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
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
    final w = widget;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (w.replyingTo != null)
          Container(
            color: w.theme.accent.withValues(alpha: 0.10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Container(width: 3, height: 32, color: w.theme.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(w.replyingTo!.sender, style: TextStyle(color: w.theme.accent, fontSize: 12, fontWeight: FontWeight.w600)),
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
            color: w.theme.accent.withValues(alpha: 0.10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.edit, size: 16, color: w.theme.accent),
                const SizedBox(width: 8),
                Expanded(child: Text('Редактирование', style: TextStyle(color: w.theme.accent, fontSize: 13))),
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
                            : w.theme.accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        w.isRecording
                            ? (w.recordingLocked ? Icons.lock : Icons.mic)
                            : (w.videoMode ? Icons.videocam : Icons.mic),
                        color: w.isRecording ? Colors.white : w.theme.accent,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  w.sending
                      ? SizedBox(
                          width: 36, height: 36,
                          child: CircularProgressIndicator(color: w.theme.accent, strokeWidth: 2),
                        )
                      : GestureDetector(
                          onTap: w.onSend,
                          child: Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(color: w.theme.accent, shape: BoxShape.circle),
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

  const _AnimatedBubble({super.key, required this.child, this.animate = true});

  @override
  State<_AnimatedBubble> createState() => _AnimatedBubbleState();
}

class _AnimatedBubbleState extends State<_AnimatedBubble>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;
  Animation<Offset>? _slide;
  Animation<double>? _fade;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
      );
      _slide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
          .animate(CurvedAnimation(parent: _ctrl!, curve: Curves.easeOutCubic));
      _fade = CurvedAnimation(parent: _ctrl!, curve: Curves.easeOut);
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
    if (_ctrl == null) return widget.child;
    return FadeTransition(
      opacity: _fade!,
      child: SlideTransition(position: _slide!, child: widget.child),
    );
  }
}
