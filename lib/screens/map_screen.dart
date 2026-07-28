import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/prefs_service.dart';
import '../models/traffic_state.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  TrafficSnapshot? _snapshot;
  Timer? _timer;
  LatLng? _myLocation;

  // Default: Абаза, Хакасия
  static const _defaultCenter = LatLng(52.6526, 90.1021);

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _fetch());
    _requestLocationPermission();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final api = context.read<ApiService>();
    final snap = await api.getLights();
    if (mounted && snap != null) setState(() => _snapshot = snap);
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    if (status.isGranted) _startLocationTracking();
  }

  void _startLocationTracking() {
    // Simplified: geolocator not in deps yet — just request once via permission_handler
    // Full GPS tracking would use geolocator package
  }

  Color _markerColor(String? state) {
    switch (state) {
      case 'green':  return const Color(0xFF00E676);
      case 'yellow': return const Color(0xFFFFD600);
      case 'red':    return const Color(0xFFFF1744);
      default:       return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Provider.of<AppThemeNotifier>(context).current;
    final prefs = context.read<PrefsService>();

    final roadMarkers = _buildRoadMarkers(prefs);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.nav,
        title: Text('Карта', style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.my_location, color: t.accent),
            onPressed: _myLocation != null
                ? () => _mapController.move(_myLocation!, 15)
                : null,
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _defaultCenter,
          initialZoom: 13,
          onLongPress: (tapPos, latLng) => _showSetMarkerDialog(latLng, prefs),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.traffic.app',
          ),
          if (roadMarkers.isNotEmpty)
            MarkerLayer(markers: roadMarkers),
          if (_myLocation != null)
            MarkerLayer(markers: [
              Marker(
                point: _myLocation!,
                width: 20, height: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: t.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: t.accent.withValues(alpha: 0.4), blurRadius: 8)],
                  ),
                ),
              ),
            ]),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: t.surface,
        onPressed: () => _mapController.move(_defaultCenter, 13),
        child: Icon(Icons.home, color: t.accent),
      ),
    );
  }

  List<Marker> _buildRoadMarkers(PrefsService prefs) {
    final markers = <Marker>[];
    const roads = [
      ('pereval',  'П', LatLng(52.660, 90.110)),
      ('abaza',    'А', LatLng(52.650, 90.100)),
      ('zarechka', 'З', LatLng(52.645, 90.095)),
    ];

    for (final (id, label, defaultPos) in roads) {
      final lat = prefs.getMarkerLat(id) ?? defaultPos.latitude;
      final lon = prefs.getMarkerLon(id) ?? defaultPos.longitude;
      final pos = LatLng(lat, lon);
      final state = _snapshot?[id].state;
      final color = _markerColor(state);

      markers.add(Marker(
        point: pos,
        width: 44, height: 52,
        child: Column(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.85),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)],
              ),
              child: Center(
                child: Text(label, style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
            CustomPaint(
              size: const Size(2, 12),
              painter: _PinTailPainter(color: color),
            ),
          ],
        ),
      ));
    }
    return markers;
  }

  void _showSetMarkerDialog(LatLng latLng, PrefsService prefs) {
    final t = Provider.of<AppThemeNotifier>(context, listen: false).current;
    showModalBottomSheet(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Установить перекрёсток',
                  style: TextStyle(color: t.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            for (final (id, name) in [('pereval', 'Перевал'), ('abaza', 'Абаза'), ('zarechka', 'Заречка')])
              ListTile(
                title: Text(name, style: TextStyle(color: t.textPrimary)),
                subtitle: Text(
                  '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}',
                  style: TextStyle(color: t.textSecondary, fontSize: 12),
                ),
                onTap: () async {
                  await prefs.setMarker(id, latLng.latitude, latLng.longitude);
                  if (mounted) setState(() {});
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ListTile(
              title: Text('Отмена', style: TextStyle(color: t.textSecondary)),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        );
      },
    );
  }
}

class _PinTailPainter extends CustomPainter {
  final Color color;
  const _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      Paint()..color = color..strokeWidth = 2..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_PinTailPainter old) => old.color != color;
}
