import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../services/prefs_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_surface.dart';
import 'pin_lock_screen.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _auth = LocalAuthentication();
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    try {
      final available = await _auth.canCheckBiometrics;
      final enrolled = await _auth.isDeviceSupported();
      if (mounted) setState(() => _biometricAvailable = available && enrolled);
    } catch (_) {}
  }

  Future<void> _enableSecurity() async {
    final prefs = context.read<PrefsService>();
    final pin = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => const PinLockScreen(mode: 'set'),
      fullscreenDialog: true,
    ));
    if (pin == null || !mounted) return;
    await prefs.setPinCode(pin);
    await prefs.setSecurityEnabled(true);
  }

  Future<void> _disableSecurity() async {
    final prefs = context.read<PrefsService>();
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => const PinLockScreen(),
      fullscreenDialog: true,
    ));
    if (ok != true || !mounted) return;
    await prefs.setSecurityEnabled(false);
    await prefs.setPinCode('');
    await prefs.setBiometricEnabled(false);
  }

  Future<void> _changePin() async {
    final prefs = context.read<PrefsService>();
    // Сначала подтверждаем текущий пин
    final verified = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => const PinLockScreen(),
      fullscreenDialog: true,
    ));
    if (verified != true || !mounted) return;
    // Вводим новый
    final newPin = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => const PinLockScreen(mode: 'set'),
      fullscreenDialog: true,
    ));
    if (newPin == null || !mounted) return;
    await prefs.setPinCode(newPin);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пин-код изменён')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AppThemeNotifier>();
    final t = notifier.current;
    final a = notifier.accent;
    final prefs = context.watch<PrefsService>();

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.nav,
        title: Text('Безопасность',
            style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: GlassBg(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, 96 + MediaQuery.of(context).padding.bottom),
          children: [
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  _SwitchTile(
                    icon: Icons.lock_outline_rounded,
                    iconColor: a,
                    title: 'Защита пин-кодом',
                    subtitle: 'Запрашивать пин при открытии приложения',
                    value: prefs.securityEnabled,
                    t: t,
                    onChanged: (v) => v ? _enableSecurity() : _disableSecurity(),
                  ),
                  if (prefs.securityEnabled) ...[
                    Divider(color: t.cardBorder, height: 1),
                    if (_biometricAvailable)
                      _SwitchTile(
                        icon: Icons.fingerprint,
                        iconColor: Colors.greenAccent,
                        title: 'Биометрия',
                        subtitle: 'Отпечаток пальца / Face ID',
                        value: prefs.biometricEnabled,
                        t: t,
                        onChanged: (v) => prefs.setBiometricEnabled(v),
                      ),
                    if (_biometricAvailable)
                      Divider(color: t.cardBorder, height: 1),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.edit_outlined,
                            color: Colors.orangeAccent, size: 20),
                      ),
                      title: Text('Изменить пин-код',
                          style: TextStyle(color: t.textPrimary, fontSize: 15)),
                      trailing: Icon(Icons.chevron_right, color: t.textSecondary),
                      onTap: _changePin,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                prefs.securityEnabled
                    ? 'Пин-код запрашивается при возвращении в приложение после сворачивания.'
                    : 'Включите защиту, чтобы приложение запрашивало пин-код при открытии.',
                style: TextStyle(color: t.textSecondary, fontSize: 12, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ThemeDef t;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.t,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.read<AppThemeNotifier>().accent;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title,
          style: TextStyle(color: t.textPrimary, fontSize: 15,
              fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle,
          style: TextStyle(color: t.textSecondary, fontSize: 12)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: accent,
      ),
    );
  }
}
