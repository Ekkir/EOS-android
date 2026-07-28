import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/traffic_state.dart';
import '../widgets/road_map_widget.dart';
import '../widgets/glass_card.dart';

class TrafficScreen extends StatefulWidget {
  const TrafficScreen({super.key});

  @override
  State<TrafficScreen> createState() => _TrafficScreenState();
}

class _TrafficScreenState extends State<TrafficScreen> {
  TrafficSnapshot? _snapshot;
  Timer? _timer;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    final api = context.read<ApiService>();
    final snap = await api.getLights();
    if (!mounted) return;
    setState(() {
      if (snap != null) {
        _snapshot = snap;
        _error = false;
      } else {
        _error = _snapshot == null;
      }
      _loading = false;
    });
  }

  Future<void> _resetRoad(String road) async {
    final api = context.read<ApiService>();
    await api.resetRoad(road);
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final t = Provider.of<AppThemeNotifier>(context).current;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.nav,
        title: Text('Светофоры', style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textPrimary),
        actions: [
          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: t.accent),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_error)
            Container(
              width: double.infinity,
              color: Colors.red.shade900,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: const Text('Нет соединения с сервером',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
            ),
          Expanded(
            flex: 3,
            child: _snapshot == null
                ? Center(
                    child: _loading
                        ? CircularProgressIndicator(color: t.accent)
                        : Text('Нет данных', style: TextStyle(color: t.textSecondary)),
                  )
                : RoadMapWidget(
                    snapshot: _snapshot!,
                    theme: t,
                    onRoadTap: _showRoadMenu,
                  ),
          ),
          if (_snapshot != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _StatusCards(snapshot: _snapshot!, theme: t),
            ),
        ],
      ),
    );
  }

  void _showRoadMenu(String road) {
    final names = {'pereval': 'Перевал', 'abaza': 'Абаза', 'zarechka': 'Заречка'};
    showModalBottomSheet(
      context: context,
      backgroundColor: Provider.of<AppThemeNotifier>(context, listen: false).current.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final t = Provider.of<AppThemeNotifier>(ctx).current;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(names[road]!, style: TextStyle(color: t.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.refresh, color: Colors.orangeAccent),
                title: Text('Сбросить таймер', style: TextStyle(color: t.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _resetRoad(road);
                },
              ),
              ListTile(
                leading: Icon(Icons.close, color: t.textSecondary),
                title: Text('Отмена', style: TextStyle(color: t.textSecondary)),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusCards extends StatelessWidget {
  final TrafficSnapshot snapshot;
  final ThemeDef theme;

  const _StatusCards({required this.snapshot, required this.theme});

  static const _roads = [
    ('pereval',  'Перевал',  Icons.landscape),
    ('abaza',    'Абаза',    Icons.location_city),
    ('zarechka', 'Заречка',  Icons.water),
  ];

  Color _stateColor(String state) {
    switch (state) {
      case 'green':  return const Color(0xFF00E676);
      case 'yellow': return const Color(0xFFFFD600);
      case 'red':    return const Color(0xFFFF1744);
      default:       return Colors.grey;
    }
  }

  String _stateLabel(String state) {
    switch (state) {
      case 'green':  return 'Зелёный';
      case 'yellow': return 'Жёлтый';
      case 'red':    return 'Красный';
      default:       return state;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _roads.map((r) {
        final (id, name, icon) = r;
        final rs = snapshot[id];
        final color = _stateColor(rs.state);
        final timer = rs.state == 'red' ? rs.toGreen : rs.remaining;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(height: 4),
                  Text(name, style: TextStyle(color: theme.textSecondary, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(_stateLabel(rs.state),
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                  if (timer > 0)
                    Text('$timer с', style: TextStyle(color: theme.textSecondary, fontSize: 11)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
