import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/prefs_service.dart';
import '../services/nav_bar_controller.dart';
import '../widgets/glitch_wrapper.dart';
import '../widgets/circular_avatar.dart';
import '../services/api_service.dart';
import 'connection_screen.dart';
import 'themes_screen.dart';
import 'admin_screen.dart';
import 'bug_report_screen.dart';
import 'about_screen.dart';
import 'home_tiles_screen.dart';
import 'chat_settings_screen.dart';
import 'nav_bar_settings_screen.dart';
import 'security_screen.dart';

IconData _themeIcon(ThemeDef t, IconData def, {
  IconData? pixel, IconData? glass, IconData? neon,
  IconData? cyber, IconData? minimal,
}) {
  if (t.id == 'pixel' && pixel != null) return pixel;
  if ((t.isLiquidGlass || t.glassy) && glass != null) return glass;
  if (t.neonGlow && neon != null) return neon;
  if (t.cyberpunk && cyber != null) return cyber;
  if (t.id == 'minimal' && minimal != null) return minimal;
  return def;
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  double _scrollOffset = 0;
  AppThemeNotifier? _themeNotifier;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      final o = _scrollCtrl.offset.clamp(0.0, 80.0);
      if ((o - _scrollOffset).abs() > 0.5) setState(() => _scrollOffset = o);
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

  Future<void> _openWithPassword(BuildContext ctx, Widget Function() builder) async {
    final pwCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Введите пароль'),
        content: TextField(
          controller: pwCtrl,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Пароль администратора',
            prefixIcon: Icon(Icons.lock_outline),
          ),
          onSubmitted: (_) => Navigator.pop(dCtx, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Войти')),
        ],
      ),
    );
    if (confirmed != true || !ctx.mounted) return;
    final password = pwCtrl.text;
    pwCtrl.dispose();
    if (password.isEmpty) return;
    final api = ctx.read<ApiService>();
    final ok = await api.checkAdmin(password);
    if (!ctx.mounted) return;
    if (ok) {
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => builder()));
    } else {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Неверный пароль')),
      );
    }
  }

  @override
  void dispose() {
    _themeNotifier?.removeListener(_onTheme);
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = Provider.of<AppThemeNotifier>(context);
    final t = notifier.current;
    final a = notifier.accent;
    final a2 = notifier.accent2;
    final prefs = context.read<PrefsService>();
    final nav = context.read<NavBarController>();
    final profileName = prefs.profileName.isNotEmpty ? prefs.profileName : prefs.googleName;

    final progress = (_scrollOffset / 80.0).clamp(0.0, 1.0);
    final avatarRadius = lerpDouble(30, 16, progress)!;
    final nameOpacity = (1.0 - progress * 1.5).clamp(0.0, 1.0);

    final group1 = <_TileData>[
      if (prefs.isAdmin) _TileData(
        icon: (t) => _themeIcon(t, Icons.wifi,
          pixel: Icons.wifi_rounded, glass: Icons.water_drop,
          neon: Icons.electric_bolt, cyber: Icons.signal_cellular_alt_rounded,
          minimal: Icons.link),
        label: 'Подключение', subtitle: 'URL сервера',
        color: const Color(0xFF448AFF),
        onTap: () => _openWithPassword(context, () => const ConnectionScreen()),
      ),
      _TileData(
        icon: (t) => _themeIcon(t, Icons.palette,
          pixel: Icons.color_lens_rounded, glass: Icons.blur_on,
          neon: Icons.auto_awesome, cyber: Icons.auto_fix_high,
          minimal: Icons.circle),
        label: 'Темы', subtitle: 'Оформление приложения',
        color: const Color(0xFFAA00FF),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThemesScreen())),
      ),
      if (prefs.isAdmin) _TileData(
        icon: (t) => Icons.admin_panel_settings_rounded,
        label: 'Администратор', subtitle: 'Статистика и управление',
        color: const Color(0xFFFF6D00),
        onTap: () => _openWithPassword(context, () => const AdminScreen()),
      ),
      _TileData(
        icon: (t) => _themeIcon(t, Icons.dashboard_customize_outlined,
          pixel: Icons.view_quilt_rounded, glass: Icons.grid_view,
          neon: Icons.star_rounded, cyber: Icons.dashboard_rounded,
          minimal: Icons.apps),
        label: 'Главная страница',
        subtitle: 'Настроить отображаемые разделы',
        color: const Color(0xFF00BCD4),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeTilesScreen())),
      ),
      _TileData(
        icon: (t) => _themeIcon(t, Icons.chat_bubble_outline,
          pixel: Icons.forum_rounded, glass: Icons.chat_rounded,
          neon: Icons.speaker_notes_rounded, cyber: Icons.terminal,
          minimal: Icons.chat_bubble_outline),
        label: 'Настройки чатов',
        subtitle: 'Фон, размер текста, анимации',
        color: const Color(0xFF26C6DA),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatSettingsScreen())),
      ),
      _TileData(
        icon: (t) => _themeIcon(t, Icons.dashboard_customize_outlined,
          pixel: Icons.space_bar_rounded, glass: Icons.view_stream_rounded,
          neon: Icons.nightlight_round, cyber: Icons.memory_rounded,
          minimal: Icons.more_horiz),
        label: 'Панель навигации',
        subtitle: 'Анимация кнопок',
        color: const Color(0xFF7C4DFF),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NavBarSettingsScreen())),
      ),
      _TileData(
        icon: (t) => _themeIcon(t, Icons.shield_outlined,
          pixel: Icons.lock_rounded, glass: Icons.fingerprint,
          neon: Icons.security_rounded, cyber: Icons.security_rounded,
          minimal: Icons.lock),
        label: 'Безопасность',
        subtitle: 'Пин-код и биометрия',
        color: const Color(0xFF00BFA5),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityScreen())),
      ),
    ];

    final group2 = <_TileData>[
      _TileData(
        icon: (t) => _themeIcon(t, Icons.info_outline,
          pixel: Icons.info_rounded, glass: Icons.info_rounded,
          neon: Icons.lightbulb_rounded, cyber: Icons.code_rounded,
          minimal: Icons.info_outline),
        label: 'О приложении', subtitle: 'Версия, разработчик, обновления',
        color: const Color(0xFF7B2FF7),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
      ),
      _TileData(
        icon: (t) => _themeIcon(t, Icons.bug_report_outlined,
          pixel: Icons.bug_report_rounded, glass: Icons.report_rounded,
          neon: Icons.report_rounded, cyber: Icons.report_problem_rounded,
          minimal: Icons.bug_report),
        label: 'Отчёт об ошибке',
        subtitle: 'Сообщить о проблеме разработчику',
        color: Colors.redAccent,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BugReportScreen())),
      ),
    ];

    final allTiles = [...group1, ...group2];
    final filtered = _searchQuery.isEmpty
        ? null
        : allTiles.where((td) =>
            td.label.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            td.subtitle.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    final isGlass = t.isLiquidGlass || t.glassy;

    return Scaffold(
      backgroundColor: notifier.bgDecoration != null ? Colors.transparent : t.bg,
      body: Stack(
        children: [
          if (isGlass)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      a.withValues(alpha: 0.07),
                      Colors.transparent,
                      a2.withValues(alpha: 0.05),
                    ],
                  ),
                ),
              ),
            ),
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    children: [
                      CircularAvatar(
                        bytes: nav.avatarBytes,
                        name: profileName.isNotEmpty ? profileName : '?',
                        radius: avatarRadius,
                      ),
                      const SizedBox(height: 6),
                      AnimatedOpacity(
                        opacity: nameOpacity,
                        duration: Duration.zero,
                        child: Text(
                          profileName.isNotEmpty ? profileName : 'Профиль',
                          style: TextStyle(
                            color: t.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _searchField(t, a),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                  children: filtered != null
                      ? [
                          for (final td in filtered) ...[
                            _SettingTile(
                              icon: td.icon, label: td.label, subtitle: td.subtitle,
                              color: td.color, onTap: td.onTap,
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (filtered.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 32),
                              child: Center(
                                child: Text('Ничего не найдено',
                                  style: TextStyle(color: t.textSecondary, fontSize: 14)),
                              ),
                            ),
                        ]
                      : [
                          for (final td in group1) ...[
                            _SettingTile(
                              icon: td.icon, label: td.label, subtitle: td.subtitle,
                              color: td.color, onTap: td.onTap,
                            ),
                            const SizedBox(height: 8),
                          ],
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                            child: Text('О приложении',
                              style: TextStyle(color: t.textSecondary, fontSize: 12,
                                  fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                          ),
                          for (final td in group2) ...[
                            _SettingTile(
                              icon: td.icon, label: td.label, subtitle: td.subtitle,
                              color: td.color, onTap: td.onTap,
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _searchField(ThemeDef t, Color a) {
    final isGlass = t.isLiquidGlass || t.glassy;
    final field = TextField(
      controller: _searchCtrl,
      style: TextStyle(color: t.textPrimary, fontSize: 14),
      onChanged: (v) => setState(() => _searchQuery = v.trim()),
      decoration: InputDecoration(
        hintText: 'Поиск настроек...',
        hintStyle: TextStyle(color: t.textSecondary, fontSize: 14),
        prefixIcon: Icon(Icons.search, color: t.textSecondary, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                },
                child: Icon(Icons.close, color: t.textSecondary, size: 18),
              )
            : null,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: InputBorder.none,
      ),
    );

    if (isGlass) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: field,
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.cardBorder),
      ),
      child: field,
    );
  }
}

class _TileData {
  final IconData Function(ThemeDef) icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  _TileData({
    required this.icon, required this.label, required this.subtitle,
    required this.color, required this.onTap,
  });
}

class _SettingTile extends StatelessWidget {
  final IconData Function(ThemeDef) icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SettingTile({
    required this.icon, required this.label, required this.subtitle,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AppThemeNotifier>();
    final t = notifier.current;
    final isPixel = t.id == 'pixel';

    Widget iconWidget = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isPixel ? 0.22 : 0.15),
        borderRadius: BorderRadius.circular(isPixel ? 50 : 12),
      ),
      child: Icon(icon(t), color: color, size: 22),
    );
    if (t.cyberpunk) {
      iconWidget = GlitchWrapper(
        intensity: 0.5, frequency: 0.5, chromatic: true, child: iconWidget);
    }

    final content = Row(
      children: [
        iconWidget,
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
              Text(subtitle, style: TextStyle(color: t.textSecondary, fontSize: 13)),
            ],
          ),
        ),
        Icon(isPixel ? Icons.chevron_right_rounded : Icons.chevron_right,
            color: t.textSecondary),
      ],
    );

    Widget card;
    if (t.isLiquidGlass || t.glassy) {
      final blur = notifier.glassBlur;
      card = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.12),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 0.8),
            ),
            child: content,
          ),
        ),
      );
    } else if (t.neonGlow) {
      final nA2 = notifier.accent2;
      card = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: nA2.withValues(alpha: 0.55), width: 1),
        ),
        child: content,
      );
    } else if (t.cyberpunk) {
      card = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: notifier.accent.withValues(alpha: 0.5), width: 1),
          boxShadow: [
            BoxShadow(color: notifier.accent.withValues(alpha: 0.20), blurRadius: 14),
            BoxShadow(color: notifier.accent2.withValues(alpha: 0.12), blurRadius: 24),
          ],
        ),
        child: content,
      );
    } else if (isPixel) {
      card = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Color.lerp(t.surface, color, 0.07),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withValues(alpha: 0.22), width: 1),
        ),
        child: content,
      );
    } else {
      card = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.cardBorder),
        ),
        child: content,
      );
    }

    return GestureDetector(onTap: onTap, child: card);
  }
}
