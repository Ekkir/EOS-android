import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/channel.dart';
import '../widgets/glass_card.dart';
import '../widgets/circular_avatar.dart';
import 'messenger_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Channel> _channels = [];
  Timer? _timer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    final api = context.read<ApiService>();
    final channels = await api.getChannels();
    if (mounted) {
      setState(() {
        _channels = channels;
        _loading = false;
      });
    }
  }

  String _formatTime(int ts) {
    if (ts == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = Provider.of<AppThemeNotifier>(context).current;
    final publicChannels = _channels.where((c) => !c.isDm).toList();
    final dmChannels = _channels.where((c) => c.isDm).toList();

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.nav,
        title: Text('Мессенджер', style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: t.accent))
          : _channels.isEmpty
              ? Center(child: Text('Нет каналов', style: TextStyle(color: t.textSecondary)))
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (publicChannels.isNotEmpty) ...[
                      _SectionHeader(title: 'КАНАЛЫ', theme: t),
                      const SizedBox(height: 6),
                      ...publicChannels.map((ch) => _ChannelTile(
                        channel: ch,
                        theme: t,
                        timeStr: _formatTime(ch.lastTs),
                        onTap: () => _openChat(ch),
                      )),
                      const SizedBox(height: 12),
                    ],
                    if (dmChannels.isNotEmpty) ...[
                      _SectionHeader(title: 'ЛИЧНЫЕ', theme: t),
                      const SizedBox(height: 6),
                      ...dmChannels.map((ch) => _ChannelTile(
                        channel: ch,
                        theme: t,
                        timeStr: _formatTime(ch.lastTs),
                        onTap: () => _openChat(ch),
                        isDm: true,
                      )),
                    ],
                  ],
                ),
    );
  }

  void _openChat(Channel channel) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessengerScreen(channel: channel),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final ThemeDef theme;
  const _SectionHeader({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(title,
        style: TextStyle(
          color: theme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final Channel channel;
  final ThemeDef theme;
  final String timeStr;
  final VoidCallback onTap;
  final bool isDm;

  const _ChannelTile({
    required this.channel,
    required this.theme,
    required this.timeStr,
    required this.onTap,
    this.isDm = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onTap: onTap,
        child: Row(
          children: [
            isDm
                ? CircularAvatar(name: channel.name, radius: 22)
                : CircleAvatar(
                    radius: 22,
                    backgroundColor: theme.accent.withValues(alpha: 0.2),
                    child: Text(channel.icon, style: const TextStyle(fontSize: 20)),
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(channel.name,
                    style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (channel.lastText.isNotEmpty)
                    Text(channel.lastText,
                      style: TextStyle(color: theme.textSecondary, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                ],
              ),
            ),
            if (timeStr.isNotEmpty)
              Text(timeStr, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
