import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/prefs_service.dart';
import '../models/message.dart';
import '../models/channel.dart';
import '../widgets/circular_avatar.dart';

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

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final api = context.read<ApiService>();
    final msgs = await api.getMessages(widget.channel.id, _lastId);
    if (msgs.isEmpty || !mounted) return;
    final newIds = msgs.where((m) => m.id > _lastId);
    if (newIds.isEmpty) return;
    _lastId = msgs.map((m) => m.id).reduce((a, b) => a > b ? a : b);
    setState(() => _messages.addAll(msgs));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    final prefs = context.read<PrefsService>();
    final api = context.read<ApiService>();
    final sender = prefs.profileName.isNotEmpty ? prefs.profileName
        : (prefs.googleName.isNotEmpty ? prefs.googleName : 'User');

    setState(() => _sending = true);
    _inputCtrl.clear();

    await api.sendMessage(channel: widget.channel.id, sender: sender, text: text);
    if (mounted) setState(() => _sending = false);
    _fetch();
  }

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1280);
    if (xfile == null || !mounted) return;

    final prefs = context.read<PrefsService>();
    final api = context.read<ApiService>();
    final sender = prefs.profileName.isNotEmpty ? prefs.profileName
        : (prefs.googleName.isNotEmpty ? prefs.googleName : 'User');

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

  Future<Uint8List?> _loadMedia(String mediaId) async {
    if (_mediaCache.containsKey(mediaId)) return _mediaCache[mediaId];
    final api = context.read<ApiService>();
    final bytes = await api.downloadMedia(mediaId);
    if (bytes != null) {
      _mediaCache[mediaId] = Uint8List.fromList(bytes);
      return _mediaCache[mediaId];
    }
    return null;
  }

  String _formatTime(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = Provider.of<AppThemeNotifier>(context).current;
    final prefs = context.read<PrefsService>();
    final myName = prefs.profileName.isNotEmpty ? prefs.profileName
        : (prefs.googleName.isNotEmpty ? prefs.googleName : 'User');

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.nav,
        title: Row(
          children: [
            widget.channel.isDm
                ? CircularAvatar(name: widget.channel.name, radius: 18)
                : CircleAvatar(
                    radius: 18,
                    backgroundColor: t.accent.withValues(alpha: 0.2),
                    child: Text(widget.channel.icon, style: const TextStyle(fontSize: 16)),
                  ),
            const SizedBox(width: 10),
            Text(widget.channel.name,
                style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        iconTheme: IconThemeData(color: t.textPrimary),
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
                      return _MessageBubble(
                        message: msg,
                        isMe: isMe,
                        theme: t,
                        timeStr: _formatTime(msg.ts),
                        loadMedia: msg.hasMedia ? () => _loadMedia(msg.mediaId) : null,
                      );
                    },
                  ),
          ),
          _InputBar(
            controller: _inputCtrl,
            theme: t,
            sending: _sending,
            onSend: _send,
            onMedia: _pickMedia,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final ThemeDef theme;
  final String timeStr;
  final Future<Uint8List?> Function()? loadMedia;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.theme,
    required this.timeStr,
    this.loadMedia,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isMe
        ? theme.accent.withValues(alpha: 0.85)
        : theme.surface;
    final textColor = isMe ? Colors.white : theme.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircularAvatar(name: message.sender, radius: 16),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(14),
                  topRight:    const Radius.circular(14),
                  bottomLeft:  Radius.circular(isMe ? 14 : 2),
                  bottomRight: Radius.circular(isMe ? 2 : 14),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Text(message.sender,
                      style: TextStyle(color: theme.accent, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  if (loadMedia != null)
                    FutureBuilder<Uint8List?>(
                      future: loadMedia!(),
                      builder: (ctx, snap) {
                        if (snap.hasData && snap.data != null) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(snap.data!, fit: BoxFit.cover, width: 200),
                          );
                        }
                        return const SizedBox(
                          width: 100, height: 60,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      },
                    )
                  else
                    Text(message.text, style: TextStyle(color: textColor, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(timeStr,
                    style: TextStyle(
                      color: isMe ? Colors.white60 : theme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final ThemeDef theme;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onMedia;

  const _InputBar({
    required this.controller,
    required this.theme,
    required this.sending,
    required this.onSend,
    required this.onMedia,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.nav,
      padding: EdgeInsets.only(
        left: 12, right: 8, top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.attach_file, color: theme.textSecondary),
            onPressed: sending ? null : onMedia,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(color: theme.textPrimary),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Сообщение...',
                hintStyle: TextStyle(color: theme.textSecondary),
                filled: true,
                fillColor: theme.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          sending
              ? SizedBox(
                  width: 36, height: 36,
                  child: CircularProgressIndicator(color: theme.accent, strokeWidth: 2),
                )
              : GestureDetector(
                  onTap: onSend,
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: theme.accent, shape: BoxShape.circle),
                    child: const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
        ],
      ),
    );
  }
}
