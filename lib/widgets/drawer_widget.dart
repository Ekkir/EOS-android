import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/prefs_service.dart';
import '../screens/settings_screen.dart';
import '../screens/chat_list_screen.dart';
import '../screens/about_screen.dart';
import '../screens/profile_screen.dart';

class DrawerWidget extends StatelessWidget {
  const DrawerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final t     = Provider.of<AppThemeNotifier>(context).current;
    final a     = Provider.of<AppThemeNotifier>(context).accent;
    final prefs = Provider.of<PrefsService>(context, listen: false);

    return Drawer(
      backgroundColor: t.nav,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            // Profile header
            ListTile(
              leading: CircleAvatar(
                backgroundColor: a.withValues(alpha: 0.2),
                child: Text(prefs.profileName.isNotEmpty
                    ? prefs.profileName[0].toUpperCase() : '?',
                    style: TextStyle(color: a, fontWeight: FontWeight.bold)),
              ),
              title: Text(prefs.profileName.isNotEmpty ? prefs.profileName : 'Профиль',
                  style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
              subtitle: Text('EOS', style: TextStyle(color: t.textSecondary, fontSize: 12)),
              onTap: () { Navigator.pop(context); _push(context, const ProfileScreen()); },
            ),
            Divider(color: t.cardBorder, indent: 16, endIndent: 16),
            _label('НАВИГАЦИЯ', t),
            _item('🏠', 'Главная',   context, t, a, () { Navigator.pop(context); }),
            _item('🚦', 'Светофоры', context, t, a, () { Navigator.pop(context); }),
            _item('🗺', 'Карта',     context, t, a, () { Navigator.pop(context); }),
            _item('📷', 'Камеры',    context, t, a, () { Navigator.pop(context); }),
            _item('⚙️', 'Настройки', context, t, a, () {
              Navigator.pop(context); _push(context, const SettingsScreen());
            }),
            Divider(color: t.cardBorder, indent: 16, endIndent: 16),
            _label('ОБЩЕНИЕ', t),
            _item('💬', 'Мессенджер', context, t, a, () {
              Navigator.pop(context); _push(context, const ChatListScreen());
            }),
            Divider(color: t.cardBorder, indent: 16, endIndent: 16),
            _item('ℹ️', 'О приложении', context, t, a, () {
              Navigator.pop(context); _push(context, const AboutScreen());
            }),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, ThemeDef t) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Text(text, style: TextStyle(color: t.textSecondary,
        fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
  );

  Widget _item(String icon, String label, BuildContext context,
      ThemeDef t, Color a, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: a.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(icon, style: const TextStyle(fontSize: 16)),
      ),
      title: Text(label, style: TextStyle(color: t.textPrimary, fontSize: 15)),
      onTap: onTap,
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}
