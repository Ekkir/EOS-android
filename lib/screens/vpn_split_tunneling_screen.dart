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
  bool _showOnlySelected = false;
  String _searchQuery = '';

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

  void _filterApps([String? query]) {
    if (query != null) _searchQuery = query.toLowerCase();
    final q = _searchQuery;
    setState(() {
      _filteredApps = _apps.where((a) {
        final matchesSearch = q.isEmpty ||
            (a['appName'] ?? '').toLowerCase().contains(q) ||
            (a['packageName'] ?? '').toLowerCase().contains(q);
        final matchesFilter = !_showOnlySelected ||
            _selectedApps.contains(a['packageName']);
        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  Future<void> _saveMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _mode = mode);
    await prefs.setString('vpn_split_mode', mode);
  }

  Future<void> _toggleApp(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    if (_selectedApps.contains(packageName)) {
      _selectedApps.remove(packageName);
    } else {
      _selectedApps.add(packageName);
    }
    _filterApps();
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
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: t.nav,
        title: Text('Раздельное туннелирование',
            style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: GlassBg(
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            // ── Выбор режима ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
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
            ),

            if (_mode != 'none') ...[
              // ── Поиск ────────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _mode == 'whitelist'
                            ? 'ПРИЛОЖЕНИЯ ЧЕРЕЗ VPN'
                            : 'ПРИЛОЖЕНИЯ БЕЗ VPN',
                        style: TextStyle(
                            color: t.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _FilterChip(
                            label: 'Все',
                            active: !_showOnlySelected,
                            accent: a,
                            t: t,
                            onTap: () {
                              _showOnlySelected = false;
                              _filterApps();
                            },
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Выбранные (${_selectedApps.length})',
                            active: _showOnlySelected,
                            accent: a,
                            t: t,
                            onTap: () {
                              _showOnlySelected = true;
                              _filterApps();
                            },
                          ),
                        ],
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
                      const SizedBox(height: 6),
                      Text(
                        '${_filteredApps.length} из ${_apps.length} приложений',
                        style: TextStyle(color: t.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // ── Список приложений ─────────────────────────────────────────────
              if (_loading)
                SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: a)),
                )
              else if (_filteredApps.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Text('Нет приложений',
                        style: TextStyle(color: t.textSecondary)),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverList.builder(
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
                            secondary: _AppIconWidget(packageName: pkg, fallbackColor: a),
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
              SliverFillRemaining(
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

// ── Ленивая загрузка значка приложения ─────────────────────────────────────
class _AppIconWidget extends StatefulWidget {
  final String packageName;
  final Color fallbackColor;
  const _AppIconWidget({required this.packageName, required this.fallbackColor});

  @override
  State<_AppIconWidget> createState() => _AppIconWidgetState();
}

class _AppIconWidgetState extends State<_AppIconWidget> {
  static const _channel = MethodChannel('com.traffic.app/apps');
  static final _cache = <String, Uint8List?>{};

  Uint8List? _icon;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _syncFromCache();
  }

  @override
  void didUpdateWidget(_AppIconWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.packageName != widget.packageName) {
      _syncFromCache();
    }
  }

  void _syncFromCache() {
    if (_cache.containsKey(widget.packageName)) {
      if (mounted) {
        setState(() { _icon = _cache[widget.packageName]; _loaded = true; });
      } else {
        _icon = _cache[widget.packageName];
        _loaded = true;
      }
    } else {
      _icon = null;
      _loaded = false;
      _loadIcon();
    }
  }

  Future<void> _loadIcon() async {
    try {
      final raw = await _channel.invokeMethod('getAppIcon', {'packageName': widget.packageName});
      final bytes = raw is Uint8List ? raw : null;
      _cache[widget.packageName] = bytes;
      if (mounted) setState(() { _icon = bytes; _loaded = true; });
    } catch (_) {
      _cache[widget.packageName] = null;
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return SizedBox(
        width: 36, height: 36,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: CircularProgressIndicator(
              strokeWidth: 2, color: widget.fallbackColor.withValues(alpha: 0.4)),
        ),
      );
    }
    if (_icon != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(_icon!, width: 36, height: 36, fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback()),
      );
    }
    return _fallback();
  }

  Widget _fallback() => Container(
    width: 36, height: 36,
    decoration: BoxDecoration(
      color: widget.fallbackColor.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(Icons.apps, color: widget.fallbackColor, size: 20),
  );
}

// ── Чип фильтра (Все / Выбранные) ────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color accent;
  final ThemeDef t;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label, required this.active,
    required this.accent, required this.t, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.15) : t.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? accent.withValues(alpha: 0.60) : t.cardBorder,
            width: active ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? accent : t.textSecondary,
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── Плитка выбора режима ──────────────────────────────────────────────────
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
