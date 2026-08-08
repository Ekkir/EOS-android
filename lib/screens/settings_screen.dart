import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/prefs_service.dart';
import 'connection_screen.dart';
import 'themes_screen.dart';
import 'admin_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifier = Provider.of<AppThemeNotifier>(context);
    final t = notifier.current;
    final a = notifier.accent;
    final a2 = notifier.accent2;
    final prefs = context.read<PrefsService>();

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.nav,
        title: Text('Настройки', style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: Stack(
        children: [
          if (t.isLiquidGlass || t.glassy)
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
          ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _SettingTile(
                icon: Icons.wifi,
                label: 'Подключение',
                subtitle: 'URL сервера',
                color: const Color(0xFF448AFF),
                t: t,
                onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ConnectionScreen())),
              ),
              const SizedBox(height: 8),
              _SettingTile(
                icon: Icons.palette,
                label: 'Темы',
                subtitle: 'Оформление приложения',
                color: const Color(0xFFAA00FF),
                t: t,
                onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ThemesScreen())),
              ),
              if (prefs.isAdmin) ...[
                const SizedBox(height: 8),
                _SettingTile(
                  icon: Icons.admin_panel_settings,
                  label: 'Администратор',
                  subtitle: 'Статистика и управление',
                  color: const Color(0xFFFF6D00),
                  t: t,
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AdminScreen())),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final ThemeDef t;
  final VoidCallback onTap;

  const _SettingTile({
    required this.icon, required this.label, required this.subtitle,
    required this.color, required this.t, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
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
        Icon(Icons.chevron_right, color: t.textSecondary),
      ],
    );

    Widget card;
    if (t.isLiquidGlass || t.glassy) {
      final blur = context.read<AppThemeNotifier>().glassBlur;
      card = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: content,
          ),
        ),
      );
    } else if (t.neonGlow) {
      final nA2 = context.read<AppThemeNotifier>().accent2;
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
      final cpN = context.read<AppThemeNotifier>();
      card = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cpN.accent.withValues(alpha: 0.5), width: 1),
          boxShadow: [
            BoxShadow(color: cpN.accent.withValues(alpha: 0.20), blurRadius: 14),
            BoxShadow(color: cpN.accent2.withValues(alpha: 0.12), blurRadius: 24),
          ],
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
