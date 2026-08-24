import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart' show AppThemeNotifier, ThemeDef, NeonTextStyle;
import '../services/api_service.dart';
import '../services/prefs_service.dart';
import '../models/channel.dart';
import '../services/nav_bar_controller.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_surface.dart';
import '../widgets/circular_avatar.dart';
import 'messenger_screen.dart';
import 'user_profile_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with RouteAware {
  List<Channel> _channels = [];
  final Map<String, String> _dmDisplayNames = {};
  final Map<String, Uint8List?> _dmAvatarCache = {};
  Timer? _timer;
  bool _loading = true;
  String _searchQuery = '';
  NavBarController? _navCtrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nc = context.read<NavBarController>();
    final route = ModalRoute.of(context);
    if (route is PageRoute) nc.routeObserver.subscribe(this, route);
    _navCtrl = nc;
  }

  @override
  void didPopNext() => _enterSection();

  void _enterSection() {
    _navCtrl?.enterChatList(
      onSearch: (q) => setState(() => _searchQuery = q),
      onAdd: _showNewDmDialog,
    );
  }

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetch());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _enterSection();
    });
  }

  @override
  void dispose() {
    _navCtrl?.routeObserver.unsubscribe(this);
    _navCtrl?.exitChatList();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    final api = context.read<ApiService>();
    final prefs = context.read<PrefsService>();
    final myName = prefs.profileName.isNotEmpty ? prefs.profileName : prefs.googleName;
    final channels = await api.getChannels(myName: myName);
    if (!mounted) return;
    setState(() {
      _channels = channels;
      _loading = false;
    });
    for (final ch in channels.where((c) => c.isDm)) {
      if (!_dmDisplayNames.containsKey(ch.id)) {
        _fetchDmName(ch);
      }
    }
  }

  Future<void> _fetchDmName(Channel ch) async {
    final prefs = context.read<PrefsService>();
    final myName = prefs.profileName.isNotEmpty ? prefs.profileName : prefs.googleName;
    final api = context.read<ApiService>();

    final idBody = ch.id.substring(3); // убрать 'dm_'
    String partnerName;
    if (idBody.contains('~')) {
      // Новый канонический формат: dm_Alice~Bob
      final parts = idBody.split('~');
      partnerName = parts.firstWhere(
        (p) => p.toLowerCase() != myName.toLowerCase(),
        orElse: () => parts.last,
      );
    } else {
      // Старый формат: dm_PartnerName
      partnerName = idBody;
      if (partnerName.toLowerCase() == myName.toLowerCase()) {
        if (mounted) setState(() => _dmDisplayNames[ch.id] = 'Личный чат');
        return;
      }
    }

    final profile = await api.getProfileByName(partnerName);
    if (!mounted) return;
    setState(() => _dmDisplayNames[ch.id] =
        profile?['display_name'] as String? ?? partnerName);

    final avatarBytes = await api.getAvatarByName(partnerName);
    if (!mounted) return;
    if (avatarBytes != null) {
      setState(() => _dmAvatarCache[ch.id] = Uint8List.fromList(avatarBytes));
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
    final notifier = Provider.of<AppThemeNotifier>(context);
    final t = notifier.current;
    final prefs = context.watch<PrefsService>();
    final q = _searchQuery.toLowerCase();
    final publicChannels = _channels
        .where((c) => !c.isDm && c.displayName.toLowerCase().contains(q))
        .toList();
    final dmChannels = _channels
        .where((c) => c.isDm && (
            c.displayName.toLowerCase().contains(q) ||
            (_dmDisplayNames[c.id] ?? '').toLowerCase().contains(q)))
        .toList();

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.nav,
        title: Text('Чаты', style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: GlassBg(child: Column(
        children: [
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: notifier.accent))
                : _channels.isEmpty
                    ? Center(child: Text('Нет каналов', style: TextStyle(color: t.textSecondary)))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                        children: [
                          if (publicChannels.isNotEmpty) ...[
                            _SectionHeader(title: 'КАНАЛЫ', theme: t),
                            const SizedBox(height: 6),
                            ...publicChannels.map((ch) => _ChannelTile(
                              channel: ch,
                              theme: t,
                              timeStr: _formatTime(ch.lastTs),
                              hasUnread: ch.lastMessageId > prefs.getLastReadId(ch.id),
                              onTap: () => _openChat(ch),
                            )),
                            const SizedBox(height: 12),
                          ],
                          if (dmChannels.isNotEmpty) ...[
                            _SectionHeader(title: 'ЛИЧНЫЕ', theme: t),
                            const SizedBox(height: 6),
                            ...dmChannels.map((ch) => _ChannelTile(
                              channel: ch,
                              displayNameOverride: _dmDisplayNames[ch.id],
                              dmAvatarBytes: _dmAvatarCache[ch.id],
                              theme: t,
                              timeStr: _formatTime(ch.lastTs),
                              hasUnread: ch.lastMessageId > prefs.getLastReadId(ch.id),
                              onTap: () => _openChat(ch),
                              onLongPress: () => _confirmDelete(ch),
                              isDm: true,
                            )),
                          ],
                        ],
                      ),
          ),
        ],
      )),
    );
  }

  void _openChat(Channel channel) {
    // Пометить канал как прочитанный сразу при открытии
    final prefs = context.read<PrefsService>();
    if (channel.lastMessageId > prefs.getLastReadId(channel.id)) {
      prefs.setLastReadId(channel.id, channel.lastMessageId);
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessengerScreen(channel: channel),
      ),
    );
  }

  Future<void> _confirmDelete(Channel channel) async {
    final t = Provider.of<AppThemeNotifier>(context, listen: false).current;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        title: Text('Удалить чат?', style: TextStyle(color: t.textPrimary)),
        content: Text(
          'Все сообщения с «${channel.displayName}» будут удалены у всех участников.',
          style: TextStyle(color: t.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Отмена', style: TextStyle(color: t.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final api = context.read<ApiService>();
    await api.deleteChannel(channel.id);
    _fetch();
  }

  void _showNewDmDialog() {
    final dmNotifier = Provider.of<AppThemeNotifier>(context, listen: false);
    final t = dmNotifier.current;
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        title: Text('Написать сообщение', style: TextStyle(color: t.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: t.textPrimary),
          decoration: InputDecoration(
            hintText: 'Имя пользователя',
            hintStyle: TextStyle(color: t.textSecondary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.cardBorder)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: dmNotifier.accent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена', style: TextStyle(color: t.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              final prefs = context.read<PrefsService>();
              final myName = prefs.profileName.isNotEmpty ? prefs.profileName : prefs.googleName;
              final sorted = [myName, name]..sort();
              final dmId = 'dm_${sorted[0]}~${sorted[1]}';
              Navigator.pop(ctx);
              _openChat(Channel(
                id: dmId,
                name: name,
                icon: '💬',
                lastText: '',
                lastTs: 0,
              ));
            },
            child: Text('Открыть', style: TextStyle(color: dmNotifier.accent)),
          ),
        ],
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
  final String? displayNameOverride;
  final Uint8List? dmAvatarBytes;
  final ThemeDef theme;
  final String timeStr;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isDm;
  final bool hasUnread;

  const _ChannelTile({
    required this.channel,
    this.displayNameOverride,
    this.dmAvatarBytes,
    required this.theme,
    required this.timeStr,
    required this.onTap,
    this.onLongPress,
    this.isDm = false,
    this.hasUnread = false,
  });

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<AppThemeNotifier>();
    final accent = notifier.accent;
    final neon = theme.neonGlow;
    final name = displayNameOverride ?? channel.displayName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                isDm
                    ? CircularAvatar(name: name, bytes: dmAvatarBytes, radius: 22)
                    : CircleAvatar(
                        radius: 22,
                        backgroundColor: accent.withValues(alpha: 0.2),
                        child: Text(channel.icon, style: const TextStyle(fontSize: 20)),
                      ),
                if (hasUnread)
                  Positioned(
                    right: -2, top: -2,
                    child: Container(
                      width: 12, height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                    style: (() {
                      final base = TextStyle(
                        color: theme.textPrimary,
                        fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                        fontSize: 15,
                      );
                      return neon ? base.withNeonGlow(accent) : base;
                    })(),
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
