import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/download_state.dart';
import '../services/prefs_service.dart';
import '../services/update_service.dart';
import '../widgets/admin_avatar_widget.dart';
import '../widgets/drawer_widget.dart';
import '../widgets/glass_surface.dart';
import '../widgets/gradient_progress_bar.dart';
import 'traffic_screen.dart';
import 'map_screen.dart';
import 'settings_screen.dart';
import 'cameras_screen.dart';
import 'chat_list_screen.dart';
import 'vpn_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Uint8List? _avatarBytes;
  int _unreadCount = 0;
  Timer? _unreadTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAvatar();
      _checkUpdate();
      _pingServer();
      _fetchUnread();
    });
    _unreadTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _fetchUnread();
    });
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUnread() async {
    final api = context.read<ApiService>();
    final prefs = context.read<PrefsService>();
    final myName = prefs.profileName.isNotEmpty ? prefs.profileName : prefs.googleName;
    final channels = await api.getChannels(myName: myName);
    if (!mounted) return;
    final count = channels.where((ch) => ch.lastMessageId > prefs.getLastReadId(ch.id)).length;
    if (count != _unreadCount) setState(() => _unreadCount = count);
  }

  Future<void> _pingServer() async {
    final prefs = context.read<PrefsService>();
    if (prefs.googleEmail.isEmpty) return;
    final api = context.read<ApiService>();
    await api.ping(prefs.googleEmail);
    // Повторять каждые 2 минуты пока виджет жив
    Future.doWhile(() async {
      await Future.delayed(const Duration(minutes: 2));
      if (!mounted) return false;
      final p = context.read<PrefsService>();
      if (p.googleEmail.isNotEmpty) {
        await context.read<ApiService>().ping(p.googleEmail);
      }
      return mounted;
    });
  }

  Future<void> _loadAvatar() async {
    final prefs = context.read<PrefsService>();
    final api = context.read<ApiService>();

    List<int>? bytes;
    if (prefs.googleSignedIn && prefs.googleEmail.isNotEmpty) {
      bytes = await api.getAvatarByEmail(prefs.googleEmail);
    } else if (prefs.profileName.isNotEmpty) {
      bytes = await api.getAvatarByName(prefs.profileName);
    }
    if (bytes != null && mounted) {
      setState(() => _avatarBytes = Uint8List.fromList(bytes!));
    }
  }

  Future<void> _checkUpdate() async {
    final info = await UpdateService.fetchReleaseInfo();
    if (!mounted || info == null) return;
    final version = info['version'];
    if (version == null) return;
    if (!UpdateService.isNewer(version, UpdateService.currentVersion)) return;
    if (!mounted) return;
    _showUpdateSheet(version, info['notes'], info['apk_url']);
  }

  double _calcSheetSize(String? notes) {
    const base = 0.32;
    final extra = notes != null ? (notes.length / 80 * 0.05).clamp(0.0, 0.45) : 0.0;
    return (base + extra).clamp(0.30, 0.85);
  }

  void _showUpdateSheet(String version, String? notes, String? apkUrl) {
    final t = Provider.of<AppThemeNotifier>(context, listen: false).current;
    bool downloading = false;
    double progress = 0;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: _calcSheetSize(notes),
        minChildSize: 0.2,
        maxChildSize: 0.92,
        expand: false,
        builder: (ctx, scrollCtrl) => StatefulBuilder(
          builder: (ctx, setLocal) => Container(
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: t.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.system_update, color: Colors.green),
                    const SizedBox(width: 8),
                    Text('Доступна версия $version',
                      style: const TextStyle(color: Colors.green,
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    notes,
                    style: TextStyle(color: t.textSecondary, fontSize: 13, height: 1.5),
                  ),
                ],
                const SizedBox(height: 20),
                if (downloading)
                  Column(
                    children: [
                      GradientProgressBar(
                        value: progress,
                        height: 6,
                        background: t.cardBorder,
                      ),
                      const SizedBox(height: 6),
                      Text('${(progress * 100).toInt()}%',
                        style: TextStyle(color: t.textSecondary, fontSize: 13)),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: apkUrl == null ? null : () async {
                            final cached = await UpdateService.getCachedApk(version);
                            if (cached != null) {
                              if (ctx.mounted) Navigator.pop(ctx);
                              final err = await UpdateService.installApk(cached);
                              if (err != null && context.mounted) {
                                UpdateService.handleInstallError(context, err);
                              }
                              return;
                            }
                            setLocal(() => downloading = true);
                            final dlState = context.read<DownloadState>();
                            dlState.startDownload();
                            final path = await UpdateService.downloadApk(apkUrl, version, (p, r, tt) {
                              try { setLocal(() => progress = p); } catch (_) {}
                              dlState.onProgress(p, r, tt);
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                            dlState.complete(path);
                            if (path != null) {
                              final err = await UpdateService.installApk(path);
                              if (err != null && context.mounted) {
                                UpdateService.handleInstallError(context, err);
                              }
                            } else if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Загрузка прервана. Проверьте соединение и попробуйте снова.'),
                                  duration: Duration(seconds: 4),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.download),
                          label: const Text('Скачать и установить'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: t.textSecondary,
                          side: BorderSide(color: t.cardBorder),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Позже'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = Provider.of<AppThemeNotifier>(context);
    final t = notifier.current;
    final a = notifier.accent;

    final sections = [
      _Section(Icons.traffic_outlined, 'Светофоры', 'Управление трафиком', 0, () =>
          _push(context, const TrafficScreen())),
      _Section(Icons.map_outlined, 'Карта', 'Перекрёстки на карте', 0, () =>
          _push(context, const MapScreen())),
      _Section(Icons.videocam_outlined, 'Камеры', 'Видеонаблюдение', 0, () =>
          _push(context, const CamerasScreen())),
      _Section(Icons.chat_bubble_outline, 'Чаты', 'Сообщения и каналы', _unreadCount, () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen()));
        _fetchUnread();
      }),
      _Section(Icons.vpn_lock_outlined, 'VPN', 'AmneziaWG защита трафика', 0, () =>
          _push(context, const VpnScreen())),
      _Section(Icons.settings_outlined, 'Настройки', 'Конфигурация системы', 0, () =>
          _push(context, const SettingsScreen())),
    ];

    final prefs = context.read<PrefsService>();
    final displayName = prefs.googleName.isNotEmpty
        ? prefs.googleName
        : (prefs.profileName.isNotEmpty ? prefs.profileName : '?');

    return Scaffold(
      backgroundColor: t.bg,
      drawer: const DrawerWidget(),
      body: SafeArea(
        child: Stack(
          children: [
            if (t.isLiquidGlass)
              Positioned.fill(child: AmbientGlow(accent: a)),
            if (t.isLiquidGlass || t.glassy)
              Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.15))),
            Column(
              children: [
                Builder(builder: (ctx) => _buildHeader(ctx, t, a, displayName)),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: sections.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _buildCard(context, sections[i], t, a),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeDef t, Color a, String name) {
    final prefs = context.read<PrefsService>();
    return Container(
      color: t.nav,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: AdminAvatarWidget(
              bytes: _avatarBytes,
              name: name,
              radius: 22,
              isAdminAvatar: prefs.isAdmin,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text('EOS', style: TextStyle(color: t.textPrimary,
                    fontSize: 22, fontWeight: FontWeight.bold)),
                Text('SYSTEM', style: TextStyle(color: a, fontSize: 9,
                    letterSpacing: 3, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, _Section s, ThemeDef t, Color a) {
    final rowContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: a.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(s.icon, color: a, size: 22),
              ),
              if (s.badge > 0)
                Positioned(
                  top: -4, right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: a, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      s.badge > 99 ? '99+' : '${s.badge}',
                      style: const TextStyle(color: Colors.white, fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.title, style: TextStyle(color: t.textPrimary,
                    fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(s.subtitle, style: TextStyle(color: t.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: t.textSecondary, size: 20),
        ],
      ),
    );

    Widget card;
    if (t.isLiquidGlass || t.glassy) {
      card = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            child: rowContent,
          ),
        ),
      );
    } else {
      card = Container(
        height: 72,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.cardBorder),
        ),
        child: rowContent,
      );
    }

    return GestureDetector(onTap: s.onTap, child: card);
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _Section {
  final IconData icon;
  final String title, subtitle;
  final int badge;
  final VoidCallback onTap;
  _Section(this.icon, this.title, this.subtitle, this.badge, this.onTap);
}
