import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart' show AppThemeNotifier, ThemeDef, NeonTextStyle;
import '../services/prefs_service.dart';
import 'admin_avatar_widget.dart';
import '../services/api_service.dart';
import '../screens/settings_screen.dart';
import '../screens/chat_list_screen.dart';
import '../screens/about_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/bug_report_screen.dart';
import '../screens/traffic_screen.dart';
import '../screens/map_screen.dart';
import '../screens/cameras_screen.dart';
import 'circular_avatar.dart';

class DrawerWidget extends StatefulWidget {
  const DrawerWidget({super.key});

  @override
  State<DrawerWidget> createState() => _DrawerWidgetState();
}

class _DrawerWidgetState extends State<DrawerWidget> {
  Uint8List? _avatarBytes;
  String _loadedKey = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prefs = context.watch<PrefsService>();
    final key = '${prefs.googleEmail}_${prefs.profileName}_${prefs.avatarVersion}';
    if (key != _loadedKey) {
      _loadedKey = key;
      _loadAvatar(prefs);
    }
  }

  Future<void> _loadAvatar(PrefsService prefs) async {
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

  @override
  Widget build(BuildContext context) {
    final t     = Provider.of<AppThemeNotifier>(context).current;
    final a     = Provider.of<AppThemeNotifier>(context).accent;
    final prefs = Provider.of<PrefsService>(context, listen: false);

    final displayName = prefs.profileName.isNotEmpty
        ? prefs.profileName
        : (prefs.googleName.isNotEmpty ? prefs.googleName : 'Профиль');

    return Drawer(
      backgroundColor: t.nav,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            ListTile(
              leading: GestureDetector(
                onTap: () { Navigator.pop(context); _push(context, const ProfileScreen()); },
                child: AdminAvatarWidget(
                  bytes: _avatarBytes,
                  name: displayName,
                  radius: 22,
                  isAdminAvatar: prefs.isAdmin,
                ),
              ),
              title: Text(displayName,
                  style: t.neonGlow
                      ? TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold).withNeonGlow(a)
                      : TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
              subtitle: Text('EOS', style: TextStyle(color: t.textSecondary, fontSize: 12)),
              onTap: () { Navigator.pop(context); _push(context, const ProfileScreen()); },
            ),
            Divider(color: t.cardBorder, indent: 16, endIndent: 16),
            _label('НАВИГАЦИЯ', t),
            _item(Icons.home_outlined, 'Главная', t, a, () {
              Navigator.pop(context);
              Navigator.popUntil(context, (r) => r.isFirst);
            }),
            _item(Icons.traffic_outlined, 'Светофоры', t, a, () {
              Navigator.pop(context);
              _push(context, const TrafficScreen());
            }),
            _item(Icons.map_outlined, 'Карта', t, a, () {
              Navigator.pop(context);
              _push(context, const MapScreen());
            }),
            _item(Icons.videocam_outlined, 'Камеры', t, a, () {
              Navigator.pop(context);
              _push(context, const CamerasScreen());
            }),
            _item(Icons.settings_outlined, 'Настройки', t, a, () {
              Navigator.pop(context); _push(context, const SettingsScreen());
            }),
            Divider(color: t.cardBorder, indent: 16, endIndent: 16),
            _label('ОБЩЕНИЕ', t),
            _item(Icons.chat_outlined, 'Чаты', t, a, () {
              Navigator.pop(context); _push(context, const ChatListScreen());
            }),
            Divider(color: t.cardBorder, indent: 16, endIndent: 16),
            _item(Icons.info_outline, 'О приложении', t, a, () {
              Navigator.pop(context); _push(context, const AboutScreen());
            }),
            _item(Icons.bug_report_outlined, 'Отчёт об ошибке', t, a, () {
              Navigator.pop(context); _push(context, const BugReportScreen());
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

  Widget _item(IconData icon, String label, ThemeDef t, Color a, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: a.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: a, size: 18),
      ),
      title: Text(label,
          style: t.neonGlow
              ? TextStyle(color: t.textPrimary, fontSize: 15).withNeonGlow(a)
              : TextStyle(color: t.textPrimary, fontSize: 15)),
      onTap: onTap,
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}
