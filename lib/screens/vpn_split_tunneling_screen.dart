import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_surface.dart';

class VpnSplitTunnelingScreen extends StatefulWidget {
  const VpnSplitTunnelingScreen({super.key});

  @override
  State<VpnSplitTunnelingScreen> createState() => _VpnSplitTunnelingScreenState();
}

class _VpnSplitTunnelingScreenState extends State<VpnSplitTunnelingScreen> {
  static const _appsChannel = MethodChannel('com.traffic.app/apps');

  String _mode = 'none';
  Set<String> _selectedApps = {};
  List<Map<String, String>> _apps = [];
  List<Map<String, String>> _filteredApps = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = prefs.getString('vpn_split_mode') ?? 'none';
    final json = prefs.getString('vpn_split_apps') ?? '[]';
    _selectedApps = Set<String>.from(jsonDecode(json) as List);

    try {
      final raw = await _appsChannel.invokeListMethod<Map>('getInstalledApps');
      final apps = (raw ?? []).map((m) => Map<String, String>.from(
        m.map((k, v) => MapEntry(k.toString(), v.toString()))
      )).toList();
      if (mounted) {
        setState(() {
          _apps = apps;
          _filteredApps = apps;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filterApps(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filteredApps = _apps.where((a) =>
          (a['appName'] ?? '').toLowerCase().contains(q) ||
          (a['packageName'] ?? '').toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _saveMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _mode = mode);
    await prefs.setString('vpn_split_mode', mode);
  }

  Future<void> _toggleApp(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_selectedApps.contains(packageName)) {
        _selectedApps.remove(packageName);
      } else {
        _selectedApps.add(packageName);
      }
    });
    await prefs.setString('vpn_split_apps', jsonEncode(_selectedApps.toList()));
  }

  String get _modeDescription {
    switch (_mode) {
      case 'whitelist':
        return 'Только выбранные приложения передают трафик через VPN. '
            'Остальные используют обычное соединение.';
      case 'blacklist':
        return 'Выбранные приложения обходят VPN и используют обычное соединение. '
            'Остальные передают трафик через VPN.';
      default:
        return 'Весь трафик устройства проходит через VPN без исключений.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AppThemeNotifier>();
    final t = notifier.current;
    final a = notifier.accent;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.nav,
        title: Text('Раздельное туннелирование',
            style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: GlassBg(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Режим
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Режим', style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _ModeTile(
                          label: 'Выкл',
                          subtitle: 'Весь трафик через VPN',
                          icon: Icons.vpn_lock,
                          selected: _mode == 'none',
                          color: a,
                          t: t,
                          onTap: () => _saveMode('none'),
                        ),
                        Divider(height: 1, color: t.cardBorder),
                        _ModeTile(
                          label: 'Белый список',
                          subtitle: 'Только выбранные — через VPN',
                          icon: Icons.check_circle_outline,
                          selected: _mode == 'whitelist',
                          color: a,
                          t: t,
                          onTap: () => _saveMode('whitelist'),
                        ),
                        Divider(height: 1, color: t.cardBorder),
                        _ModeTile(
                          label: 'Чёрный список',
                          subtitle: 'Выбранные обходят VPN',
                          icon: Icons.block_outlined,
                          selected: _mode == 'blacklist',
                          color: Colors.orangeAccent,
                          t: t,
                          onTap: () => _saveMode('blacklist'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Пояснение
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: a.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: a.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: a, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_modeDescription,
                              style: TextStyle(color: t.textSecondary, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Список приложений (только если режим не none)
            if (_mode != 'none') ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _mode == 'whitelist'
                          ? 'Приложения через VPN'
                          : 'Приложения без VPN',
                      style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      style: TextStyle(color: t.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Поиск приложений...',
                        hintStyle: TextStyle(color: t.textSecondary),
                        prefixIcon: Icon(Icons.search, color: t.textSecondary, size: 20),
                        filled: true,
                        fillColor: t.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: _filterApps,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_selectedApps.length} выбрано',
                      style: TextStyle(color: t.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator(color: a))
                    : _filteredApps.isEmpty
                        ? Center(child: Text('Нет приложений',
                            style: TextStyle(color: t.textSecondary)))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: _filteredApps.length,
                            itemBuilder: (_, i) {
                              final app = _filteredApps[i];
                              final pkg = app['packageName'] ?? '';
                              final name = app['appName'] ?? pkg;
                              final isSelected = _selectedApps.contains(pkg);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: GlassCard(
                                  padding: EdgeInsets.zero,
                                  child: CheckboxListTile(
                                    value: isSelected,
                                    activeColor: a,
                                    checkColor: Colors.white,
                                    onChanged: (_) => _toggleApp(pkg),
                                    secondary: Container(
                                      width: 36, height: 36,
                                      decoration: BoxDecoration(
                                        color: a.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.apps, color: a, size: 20),
                                    ),
                                    title: Text(name,
                                        style: TextStyle(
                                            color: t.textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500)),
                                    subtitle: Text(pkg,
                                        style: TextStyle(color: t.textSecondary, fontSize: 11)),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ] else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.vpn_lock, color: t.textSecondary, size: 48),
                      const SizedBox(height: 12),
                      Text('Раздельное туннелирование отключено',
                          style: TextStyle(color: t.textSecondary)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final Color color;
  final ThemeDef t;
  final VoidCallback onTap;
  const _ModeTile({
    required this.label, required this.subtitle, required this.icon,
    required this.selected, required this.color, required this.t, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: selected ? color : t.textSecondary),
      title: Text(label, style: TextStyle(
          color: selected ? color : t.textPrimary,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      subtitle: Text(subtitle, style: TextStyle(color: t.textSecondary, fontSize: 12)),
      trailing: selected
          ? Icon(Icons.check_circle, color: color, size: 20)
          : const SizedBox.shrink(),
      onTap: onTap,
    );
  }
}
