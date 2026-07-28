import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/prefs_service.dart';
import '../widgets/glass_card.dart';
import 'calibration_screen.dart';
import 'connection_screen.dart';
import 'themes_screen.dart';
import 'admin_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Provider.of<AppThemeNotifier>(context).current;
    final prefs = context.read<PrefsService>();

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.nav,
        title: Text('Настройки', style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _SettingTile(
            icon: Icons.traffic,
            label: 'Калибровка',
            subtitle: 'Тайминги светофоров',
            color: const Color(0xFF00BFA5),
            t: t,
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CalibrationScreen())),
          ),
          const SizedBox(height: 8),
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
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
      child: Row(
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
      ),
    );
  }
}
