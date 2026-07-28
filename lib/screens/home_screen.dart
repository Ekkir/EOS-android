import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/drawer_widget.dart';
import 'traffic_screen.dart';
import 'map_screen.dart';
import 'settings_screen.dart';
import 'placeholder_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Provider.of<AppThemeNotifier>(context).current;
    final a = Provider.of<AppThemeNotifier>(context).accent;

    final sections = [
      _Section('🚦', 'Светофоры', 'Управление трафиком', () =>
          _push(context, const TrafficScreen())),
      _Section('🗺', 'Карта', 'Перекрёстки на карте', () =>
          _push(context, const MapScreen())),
      _Section('📷', 'Камеры', 'Видеонаблюдение', () =>
          _push(context, const PlaceholderScreen(icon: '📷', title: 'Камеры'))),
      _Section('⚙️', 'Настройки', 'Конфигурация системы', () =>
          _push(context, const SettingsScreen())),
    ];

    return Scaffold(
      backgroundColor: t.bg,
      drawer: const DrawerWidget(),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, t, a),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  children: sections.map((s) => _buildCard(context, s, t, a)).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeDef t, Color a) {
    return Container(
      color: t.nav,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: a.withValues(alpha: 0.15),
              ),
              alignment: Alignment.center,
              child: Text('☰', style: TextStyle(color: a, fontSize: 20)),
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
    return GestureDetector(
      onTap: s.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.cardBorder),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: a.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(s.icon, style: const TextStyle(fontSize: 24)),
            ),
            const Spacer(),
            Text(s.title, style: TextStyle(color: t.textPrimary,
                fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(s.subtitle, style: TextStyle(color: t.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _Section {
  final String icon, title, subtitle;
  final VoidCallback onTap;
  _Section(this.icon, this.title, this.subtitle, this.onTap);
}
