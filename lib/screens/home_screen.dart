import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/download_state.dart';
import '../services/prefs_service.dart';
import '../services/update_service.dart';
import '../widgets/drawer_widget.dart';
import '../widgets/glass_surface.dart';
import '../widgets/glitch_wrapper.dart';
import '../widgets/gradient_progress_bar.dart';
import 'traffic_screen.dart';
import 'map_screen.dart';
import 'settings_screen.dart';
import 'cameras_screen.dart';
import 'chat_list_screen.dart';
import 'vpn_screen.dart';
import 'car_screen.dart';
import 'music_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _unreadCount = 0;
  AppThemeNotifier? _themeNotifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdate();
      _pingServer();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _themeNotifier?.removeListener(_onTheme);
    _themeNotifier = Provider.of<AppThemeNotifier>(context, listen: false);
    _themeNotifier!.addListener(_onTheme);
  }

  void _onTheme() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    _themeNotifier?.removeListener(_onTheme);
    super.dispose();
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

  Future<void> _checkUpdate() async {
    final info = await UpdateService.fetchReleaseInfo(prefs: context.read<PrefsService>());
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
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: t.cardBorder,
                        borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Row(children: [
                  const Icon(Icons.system_update, color: Colors.green),
                  const SizedBox(width: 8),
                  Text('Доступна версия $version',
                      style: const TextStyle(color: Colors.green,
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(notes, style: TextStyle(color: t.textSecondary, fontSize: 13, height: 1.5)),
                ],
                const SizedBox(height: 20),
                if (downloading)
                  Column(children: [
                    GradientProgressBar(value: progress, height: 6, background: t.cardBorder),
                    const SizedBox(height: 6),
                    Text('${(progress * 100).toInt()}%',
                        style: TextStyle(color: t.textSecondary, fontSize: 13)),
                  ])
                else
                  Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: apkUrl == null ? null : () async {
                          final cached = await UpdateService.getCachedApk(version);
                          if (cached != null) {
                            if (ctx.mounted) Navigator.pop(ctx);
                            final err = await UpdateService.installApk(cached);
                            if (err != null && context.mounted) UpdateService.handleInstallError(context, err);
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
                            if (err != null && context.mounted) UpdateService.handleInstallError(context, err);
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Загрузка прервана. Проверьте соединение и попробуйте снова.'),
                              duration: Duration(seconds: 4),
                            ));
                          }
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('Скачать и установить'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Позже'),
                    ),
                  ]),
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

    final prefs = context.watch<PrefsService>();

    _Section? _sectionForKey(String key) {
      if (!prefs.isTileVisible(key)) return null;
      switch (key) {
        case 'traffic': return _Section(Icons.traffic_outlined, 'Светофоры', 'Управление трафиком', 0, () =>
            _push(context, const TrafficScreen()));
        case 'map': return _Section(Icons.map_outlined, 'Карта', 'Перекрёстки на карте', 0, () =>
            _push(context, const MapScreen()));
        case 'cameras': return _Section(Icons.videocam_outlined, 'Камеры', 'Видеонаблюдение', 0, () =>
            _push(context, const CamerasScreen()));
        case 'chats': return _Section(Icons.chat_bubble_outline, 'Чаты', 'Сообщения и каналы', _unreadCount, () =>
            _push(context, const ChatListScreen()));
        case 'vpn': return _Section(Icons.vpn_lock_outlined, 'VPN', 'AmneziaWG защита трафика', 0, () =>
            _push(context, const VpnScreen()));
        case 'car': return _Section(Icons.directions_car_outlined, 'Машина', 'Управление транспортом', 0, () =>
            _push(context, const CarScreen()));
        case 'music': return _Section(Icons.music_note_outlined, 'Музыка', 'Треки с сервера', 0, () =>
            _push(context, const MusicScreen()));
        default: return null;
      }
    }

    final sections = [
      for (final key in prefs.tileOrder)
        if (_sectionForKey(key) != null) _sectionForKey(key)!,
    ];
    final displayName = prefs.googleName.isNotEmpty
        ? prefs.googleName
        : (prefs.profileName.isNotEmpty ? prefs.profileName : '?');

    return Scaffold(
      backgroundColor: notifier.bgDecoration != null ? Colors.transparent : t.bg,
      body: SafeArea(
        child: Stack(
          children: [
            if (t.isLiquidGlass || t.cyberpunk)
              Positioned.fill(child: AmbientGlow(accent: a)),
            if (t.isLiquidGlass || t.glassy)
              Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.15))),
            if (t.cyberpunk)
              const Positioned.fill(child: CyberpunkScanlines()),
            Column(
              children: [
                Builder(builder: (ctx) => _buildHeader(ctx, t, a, displayName)),
                Expanded(
                  child: prefs.squareTiles
                      ? GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.0,
                          ),
                          itemCount: sections.length,
                          itemBuilder: (_, i) => _buildSquareCard(context, sections[i], t, a),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: sections.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
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
      child: Builder(builder: (ctx) {
        Widget title = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('EOS', style: TextStyle(color: t.textPrimary,
                fontSize: 22, fontWeight: FontWeight.bold)),
            Text('SYSTEM', style: TextStyle(color: a, fontSize: 9,
                letterSpacing: 3, fontWeight: FontWeight.bold)),
          ],
        );
        if (t.cyberpunk) {
          title = GlitchWrapper(
            intensity: 0.9,
            frequency: 0.7,
            chromatic: true,
            child: title,
          );
        }
        return Center(child: title);
      }),
    );
  }

  Widget _buildCard(BuildContext context, _Section s, ThemeDef t, Color a) {
    final notifier = Provider.of<AppThemeNotifier>(context, listen: false);
    final a2 = notifier.accent2;

    Widget iconBox = Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: a.withValues(alpha: t.cyberpunk ? 0.12 : 0.15),
        borderRadius: BorderRadius.circular(12),
        boxShadow: t.cyberpunk
            ? [BoxShadow(color: a.withValues(alpha: 0.35), blurRadius: 10)]
            : null,
      ),
      alignment: Alignment.center,
      child: Icon(s.icon, color: a, size: 22),
    );

    if (t.cyberpunk) {
      iconBox = GlitchWrapper(
        intensity: 0.5,
        frequency: 0.5,
        chromatic: true,
        child: iconBox,
      );
    }

    final rowContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              iconBox,
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
    } else if (t.cyberpunk) {
      card = Container(
        height: 72,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: a.withValues(alpha: 0.5), width: 1),
          boxShadow: [
            BoxShadow(color: a.withValues(alpha: 0.20), blurRadius: 14, spreadRadius: 0),
            BoxShadow(color: a2.withValues(alpha: 0.12), blurRadius: 24, spreadRadius: 0),
          ],
        ),
        child: rowContent,
      );
    } else if (t.neonGlow) {
      card = Container(
        height: 72,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: a2.withValues(alpha: 0.55), width: 1),
        ),
        child: rowContent,
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

  Widget _buildSquareCard(BuildContext context, _Section s, ThemeDef t, Color a) {
    final notifier = Provider.of<AppThemeNotifier>(context, listen: false);
    final a2 = notifier.accent2;

    Widget iconBox = Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        color: a.withValues(alpha: t.cyberpunk ? 0.12 : 0.15),
        borderRadius: BorderRadius.circular(14),
        boxShadow: t.cyberpunk
            ? [BoxShadow(color: a.withValues(alpha: 0.35), blurRadius: 10)]
            : null,
      ),
      alignment: Alignment.center,
      child: Icon(s.icon, color: a, size: 26),
    );

    if (t.cyberpunk) {
      iconBox = GlitchWrapper(intensity: 0.5, frequency: 0.5, chromatic: true, child: iconBox);
    }

    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(clipBehavior: Clip.none, children: [
          iconBox,
          if (s.badge > 0)
            Positioned(
              top: -4, right: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: a, borderRadius: BorderRadius.circular(10)),
                child: Text(s.badge > 99 ? '99+' : '${s.badge}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        Text(s.title, style: TextStyle(color: t.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );

    Widget card;
    if (t.isLiquidGlass || t.glassy) {
      card = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Center(child: Padding(padding: const EdgeInsets.all(12), child: content)),
          ),
        ),
      );
    } else if (t.cyberpunk) {
      card = Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: a.withValues(alpha: 0.5), width: 1),
          boxShadow: [
            BoxShadow(color: a.withValues(alpha: 0.20), blurRadius: 14),
            BoxShadow(color: a2.withValues(alpha: 0.12), blurRadius: 24),
          ],
        ),
        child: Center(child: Padding(padding: const EdgeInsets.all(12), child: content)),
      );
    } else if (t.neonGlow) {
      card = Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: a2.withValues(alpha: 0.55), width: 1),
        ),
        child: Center(child: Padding(padding: const EdgeInsets.all(12), child: content)),
      );
    } else {
      card = Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.cardBorder),
        ),
        child: Center(child: Padding(padding: const EdgeInsets.all(12), child: content)),
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
