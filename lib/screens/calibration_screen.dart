import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_surface.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  Map<String, dynamic>? _config;
  final Map<String, TextEditingController> _ctrls = {};
  bool _loading = true;
  bool _saving = false;

  static const _fields = [
    ('pereval_green',   'Перевал — зелёный (с)'),
    ('pereval_yellow',  'Перевал — жёлтый (с)'),
    ('pereval_red',     'Перевал — красный (с)'),
    ('abaza_green',     'Абаза — зелёный (с)'),
    ('abaza_yellow',    'Абаза — жёлтый (с)'),
    ('abaza_red',       'Абаза — красный (с)'),
    ('zarechka_green',  'Заречка — зелёный (с)'),
    ('zarechka_yellow', 'Заречка — жёлтый (с)'),
    ('zarechka_red',    'Заречка — красный (с)'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.read<ApiService>();
    final cfg = await api.getConfig();
    if (!mounted) return;
    setState(() {
      _config = cfg ?? {};
      for (final (key, _) in _fields) {
        _ctrls[key] = TextEditingController(
          text: (_config?[key] ?? 30).toString(),
        );
      }
      _loading = false;
    });
  }

  Future<void> _save() async {
    final api = context.read<ApiService>();
    setState(() => _saving = true);
    final Map<String, dynamic> updated = {};
    for (final (key, _) in _fields) {
      updated[key] = int.tryParse(_ctrls[key]?.text ?? '') ?? 30;
    }
    final ok = await api.setConfig(updated);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Сохранено' : 'Ошибка сохранения'),
            duration: const Duration(seconds: 2)),
      );
    }
  }

  Future<void> _resetRoad(String road) async {
    final api = context.read<ApiService>();
    await api.resetRoad(road);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$road сброшен'), duration: const Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = Provider.of<AppThemeNotifier>(context);
    final t = notifier.current;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.nav,
        title: Text('Калибровка', style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: GlassBg(child: _loading
          ? Center(child: CircularProgressIndicator(color: notifier.accent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final road in ['pereval', 'abaza', 'zarechka']) ...[
                  _RoadSection(road: road, fields: _fields, ctrls: _ctrls, theme: t, onReset: _resetRoad),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: notifier.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            )),
    );
  }
}

class _RoadSection extends StatelessWidget {
  final String road;
  final List<(String, String)> fields;
  final Map<String, TextEditingController> ctrls;
  final ThemeDef theme;
  final void Function(String) onReset;

  const _RoadSection({
    required this.road, required this.fields, required this.ctrls,
    required this.theme, required this.onReset,
  });

  static const _names = {'pereval': 'Перевал', 'abaza': 'Абаза', 'zarechka': 'Заречка'};

  @override
  Widget build(BuildContext context) {
    final accent = context.read<AppThemeNotifier>().accent;
    final roadFields = fields.where((f) => f.$1.startsWith(road)).toList();
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_names[road]!,
                style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
              TextButton.icon(
                onPressed: () => onReset(road),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Сброс'),
                style: TextButton.styleFrom(foregroundColor: accent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...roadFields.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(f.$2.split(' — ').last,
                    style: TextStyle(color: theme.textSecondary, fontSize: 14)),
                ),
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: ctrls[f.$1],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.textPrimary),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: theme.cardBorder),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: accent),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
