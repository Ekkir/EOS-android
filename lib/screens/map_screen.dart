import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/cached_tile_provider.dart';
import '../services/nav_bar_controller.dart';
import '../services/prefs_service.dart';
import '../models/traffic_state.dart';
import '../models/event.dart';
import '../main.dart' show localNotifPlugin;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver, RouteAware {
  final _mapController = MapController();
  TrafficSnapshot? _snapshot;
  Timer? _timer;
  Timer? _locationShareTimer;
  LatLng? _myLocation;
  StreamSubscription<Position>? _locationSub;
  List<EosEvent> _events = [];
  List<Map<String, dynamic>> _liveLocations = [];
  final Map<String, Map<String, dynamic>> _lastKnownLocations = {};
  bool _sharingLocation = false;
  bool _sharingInBackground = false;
  bool _pickingEventLocation = false;
  final Map<String, Uint8List?> _avatarCache = {};
  CachedTileProvider? _tileProvider;
  Map<String, LatLng> _crossroadPos = {};
  String? _draggingMarkerId;
  NavBarController? _navCtrl;

  static const _defaultCenter = LatLng(52.6526, 90.1021);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetch();
    _fetchEvents();
    _fetchLocations();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _fetch());
    Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchEvents();
      _fetchLocations();
    });
    _requestLocationPermission();
    _initTileCache();
    _loadCrossroadPositions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreLocationSharing();
      if (mounted) context.read<AppThemeNotifier>().setSuppressScanlines(true);
      if (mounted) _enterSection();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nc = context.read<NavBarController>();
    final route = ModalRoute.of(context);
    if (route is PageRoute) nc.routeObserver.subscribe(this, route);
    _navCtrl = nc;
  }

  @override
  void didPopNext() => _enterSection();

  void _enterSection() {
    _navCtrl?.enterMap(
      sharing: _sharingLocation,
      hasLocation: _myLocation != null,
      toggle: _toggleLocationSharing,
      addEvent: () => setState(() => _pickingEventLocation = true),
      center: () {
        if (_myLocation != null) _mapController.move(_myLocation!, 15);
      },
    );
  }

  @override
  void dispose() {
    _navCtrl?.routeObserver.unsubscribe(this);
    context.read<AppThemeNotifier>().setSuppressScanlines(false);
    _navCtrl?.exitSection();
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _locationSub?.cancel();
    _locationShareTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _syncNavBar() {
    _navCtrl?.updateMapState(
      sharing: _sharingLocation,
      hasLocation: _myLocation != null,
    );
  }

  Future<void> _initTileCache() async {
    try {
      final base = await getApplicationCacheDirectory();
      final dir = Directory('${base.path}/map_tiles');
      await dir.create(recursive: true);
      CachedTileProvider.cleanOldTiles(dir);
      if (mounted) setState(() => _tileProvider = CachedTileProvider(cacheDir: dir));
    } catch (_) {}
  }

  Future<void> _loadCrossroadPositions() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.getCrossroadPositions();
      if (mounted && data.isNotEmpty) {
        setState(() {
          _crossroadPos = data.map((k, v) => MapEntry(k, LatLng(v[0], v[1])));
        });
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_sharingLocation) return;
    if (state == AppLifecycleState.paused) {
      _showLocationStatusNotif();
    } else if (state == AppLifecycleState.resumed && !_sharingInBackground) {
      localNotifPlugin.cancel(_locationNotifId);
    }
  }

  Future<void> _fetch() async {
    final api = context.read<ApiService>();
    final snap = await api.getLights();
    if (mounted && snap != null) setState(() => _snapshot = snap);
  }

  Future<void> _fetchEvents() async {
    final api = context.read<ApiService>();
    final list = await api.getEvents();
    if (mounted) setState(() => _events = list);
  }

  Future<void> _fetchLocations() async {
    final api = context.read<ApiService>();
    final list = await api.getLiveLocations();
    if (!mounted) return;
    for (final loc in list) {
      final email = loc['email'] as String? ?? '';
      if (email.isNotEmpty) {
        _lastKnownLocations[email] = loc;
        if (!_avatarCache.containsKey(email)) {
          _avatarCache[email] = null;
          api.getAvatarByEmail(email).then((bytes) {
            if (mounted && bytes != null) {
              setState(() => _avatarCache[email] = Uint8List.fromList(bytes));
            }
          });
        }
      }
    }
    setState(() => _liveLocations = list);
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    if (status.isGranted) _startLocationTracking();
  }

  void _startLocationTracking() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    _locationSub = Geolocator.getPositionStream(locationSettings: settings).listen((pos) {
      if (!mounted) return;
      setState(() => _myLocation = LatLng(pos.latitude, pos.longitude));
      _syncNavBar();
    });
  }

  Future<void> _sendMyLocation() async {
    final prefs = context.read<PrefsService>();
    final api = context.read<ApiService>();
    final email = prefs.googleEmail;
    if (email.isEmpty) return;
    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 8));
    } catch (_) {
      return;
    }
    final name = prefs.profileName.isNotEmpty ? prefs.profileName : prefs.googleName;
    await api.updateLocation(email, pos.latitude, pos.longitude, name);
    if (mounted) {
      setState(() => _myLocation = LatLng(pos.latitude, pos.longitude));
      _syncNavBar();
    }
  }

  Future<void> _restoreLocationSharing() async {
    final prefs = context.read<PrefsService>();
    if (!prefs.sharingLocation) return;
    setState(() => _sharingLocation = true);
    _sendMyLocation();
    _locationShareTimer = Timer.periodic(const Duration(seconds: 10), (_) => _sendMyLocation());
    if (prefs.sharingInBackground) await _startBackgroundSharing();
  }

  void _toggleLocationSharing() {
    final prefs = context.read<PrefsService>();
    if (_sharingLocation) {
      _locationShareTimer?.cancel();
      _locationShareTimer = null;
      if (_sharingInBackground) _stopBackgroundSharing();
      setState(() => _sharingLocation = false);
      _syncNavBar();
      prefs.setSharingLocation(false);
      prefs.setSharingInBackground(false);
    } else {
      setState(() => _sharingLocation = true);
      _syncNavBar();
      prefs.setSharingLocation(true);
      _sendMyLocation();
      _locationShareTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _sendMyLocation(),
      );
    }
  }

  static const _locationNotifId = 7777;
  static const _locationNotifChannel = 'eos_location';

  Future<void> _showLocationStatusNotif() async {
    try {
      final androidPlugin = localNotifPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
        _locationNotifChannel,
        'Геолокация',
        description: 'Трансляция местоположения в фоне',
        importance: Importance.low,
      ));
      await localNotifPlugin.show(
        _locationNotifId,
        'EOS — геолокация активна',
        _sharingInBackground
            ? 'Трансляция в фоне активна'
            : 'Трансляция приостановится при закрытии приложения',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _locationNotifChannel,
            'Геолокация',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            icon: 'ic_notification',
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> _startBackgroundSharing() async {
    setState(() => _sharingInBackground = true);
    context.read<PrefsService>().setSharingInBackground(true);
    await _showLocationStatusNotif();
  }

  Future<void> _stopBackgroundSharing() async {
    setState(() => _sharingInBackground = false);
    context.read<PrefsService>().setSharingInBackground(false);
    try {
      await localNotifPlugin.cancel(_locationNotifId);
    } catch (_) {}
  }

  String _timeAgo(double ts) {
    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt()),
    );
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин. назад';
    if (diff.inHours < 24) return '${diff.inHours} ч. назад';
    return '${diff.inDays} д. назад';
  }

  Color _markerColor(String? state) {
    switch (state) {
      case 'green':  return const Color(0xFF00E676);
      case 'yellow': return const Color(0xFFFFD600);
      case 'red':    return const Color(0xFFFF1744);
      default:       return Colors.grey;
    }
  }

  IconData _eventIcon(String type) {
    switch (type) {
      case 'meetup': return Icons.people_outlined;
      case 'here':   return Icons.pin_drop_outlined;
      default:       return Icons.help_outline;
    }
  }

  Color _eventColor(String type) {
    switch (type) {
      case 'meetup': return const Color(0xFFAB47BC);
      case 'here':   return const Color(0xFF29B6F6);
      default:       return const Color(0xFFFF7043);
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'meetup': return 'Сходка';
      case 'here':   return 'Я тут';
      default:       return 'Другое';
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = Provider.of<AppThemeNotifier>(context);
    final t = notifier.current;
    final prefs = context.read<PrefsService>();
    final myEmail = prefs.googleEmail;

    final roadMarkers = _buildRoadMarkers();
    final eventMarkers = _buildEventMarkers();
    final locationMarkers = _buildLocationMarkers(myEmail, t);
    final offlineMarkers = _buildOfflineLocationMarkers(myEmail, t);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.nav,
        title: Text('Карта', style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: 13,
              onTap: (tapPos, latLng) {
                if (_draggingMarkerId != null) {
                  final id = _draggingMarkerId!;
                  setState(() {
                    _crossroadPos[id] = latLng;
                    _draggingMarkerId = null;
                  });
                  context.read<ApiService>().setCrossroadPosition(id, latLng.latitude, latLng.longitude);
                  return;
                }
                if (_pickingEventLocation) {
                  setState(() => _pickingEventLocation = false);
                  final prefs = context.read<PrefsService>();
                  _showCreateEventDialog(latLng, prefs);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.traffic.app',
                tileProvider: _tileProvider,
              ),
              if (roadMarkers.isNotEmpty)
                MarkerLayer(markers: roadMarkers),
              if (eventMarkers.isNotEmpty)
                MarkerLayer(markers: eventMarkers),
              if (offlineMarkers.isNotEmpty)
                MarkerLayer(markers: offlineMarkers),
              if (locationMarkers.isNotEmpty)
                MarkerLayer(markers: locationMarkers),
              if (_myLocation != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _myLocation!,
                    width: 20, height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _sharingLocation ? Colors.green : notifier.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [BoxShadow(
                          color: (_sharingLocation ? Colors.green : notifier.accent).withValues(alpha: 0.4),
                          blurRadius: 8,
                        )],
                      ),
                    ),
                  ),
                ]),
            ],
          ),
          if (_draggingMarkerId != null)
            Positioned(
              bottom: 100,
              left: 24,
              right: 24,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.touch_app, color: Colors.yellow, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Тапните на карту для нового положения маркера',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _draggingMarkerId = null),
                        child: const Icon(Icons.close, color: Colors.white54, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_pickingEventLocation)
            Positioned(
              bottom: 100,
              left: 24,
              right: 24,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.touch_app, color: Colors.white70, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Нажмите на карту для выбора места события',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _pickingEventLocation = false),
                        child: const Icon(Icons.close, color: Colors.white54, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Marker> _buildRoadMarkers() {
    final markers = <Marker>[];
    final prefs = context.read<PrefsService>();
    const roads = [
      ('pereval',  'П', LatLng(52.660, 90.110)),
      ('abaza',    'А', LatLng(52.650, 90.100)),
      ('zarechka', 'З', LatLng(52.645, 90.095)),
    ];

    for (final (id, label, defaultPos) in roads) {
      final pos = _crossroadPos[id] ?? defaultPos;
      final state = _snapshot?[id].state;
      final color = _markerColor(state);
      final isDragging = _draggingMarkerId == id;

      markers.add(Marker(
        point: pos,
        width: 44, height: 52,
        child: GestureDetector(
          onLongPress: prefs.isAdmin
              ? () => setState(() => _draggingMarkerId = id)
              : null,
          child: Column(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDragging ? 1.0 : 0.85),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: isDragging ? Colors.yellow : Colors.white, width: 2),
                  boxShadow: [BoxShadow(
                      color: color.withValues(alpha: isDragging ? 0.8 : 0.4),
                      blurRadius: isDragging ? 16 : 8)],
                ),
                child: Center(
                  child: Text(label, style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
              CustomPaint(
                size: const Size(2, 12),
                painter: _PinTailPainter(color: isDragging ? Colors.yellow : color),
              ),
            ],
          ),
        ),
      ));
    }
    return markers;
  }

  List<Marker> _buildEventMarkers() {
    return _events.map((ev) {
      final color = _eventColor(ev.type);
      final icon = _eventIcon(ev.type);
      return Marker(
        point: LatLng(ev.lat, ev.lon),
        width: 40, height: 40,
        child: GestureDetector(
          onTap: () => _showEventDetail(ev),
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildLocationMarkers(String myEmail, ThemeDef t) {
    final accent = context.read<AppThemeNotifier>().accent;
    return _liveLocations
        .where((loc) => (loc['email'] as String? ?? '') != myEmail)
        .map((loc) {
      final name = loc['display_name'] as String? ?? '';
      final email = loc['email'] as String? ?? '';
      final avatarBytes = _avatarCache[email];
      return Marker(
        point: LatLng(
          (loc['lat'] as num? ?? 0).toDouble(),
          (loc['lon'] as num? ?? 0).toDouble(),
        ),
        width: 90, height: 72,
        child: Column(
          children: [
            Container(
              width: 36, height: 36,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: avatarBytes != null
                  ? Image.memory(avatarBytes, fit: BoxFit.cover)
                  : Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                name.isNotEmpty ? name : '?',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Marker> _buildOfflineLocationMarkers(String myEmail, ThemeDef t) {
    final activeEmails = _liveLocations.map((l) => l['email'] as String? ?? '').toSet();
    return _lastKnownLocations.entries
        .where((e) => e.key != myEmail && !activeEmails.contains(e.key))
        .map((e) {
      final loc = e.value;
      final name = loc['display_name'] as String? ?? '';
      final email = e.key;
      final avatarBytes = _avatarCache[email];
      final ts = (loc['ts'] as num? ?? 0).toDouble();
      return Marker(
        point: LatLng(
          (loc['lat'] as num? ?? 0).toDouble(),
          (loc['lon'] as num? ?? 0).toDouble(),
        ),
        width: 90, height: 72,
        child: GestureDetector(
          onTap: () {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('$name — был(а) ${_timeAgo(ts)}'),
              duration: const Duration(seconds: 3),
            ));
          },
          child: Column(
            children: [
              ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0,      0,      0,      0.6, 0,
                ]),
                child: Stack(
                  children: [
                    Container(
                      width: 36, height: 36,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey,
                        border: Border.all(color: Colors.white54, width: 2),
                      ),
                      child: avatarBytes != null
                          ? Image.memory(avatarBytes, fit: BoxFit.cover)
                          : Center(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                    ),
                    const Positioned(
                      right: 0, bottom: 0,
                      child: Icon(Icons.access_time, size: 14, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.70),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  name.isNotEmpty ? name : '?',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  void _showEventDetail(EosEvent ev) {
    final t = Provider.of<AppThemeNotifier>(context, listen: false).current;
    final prefs = context.read<PrefsService>();
    final myName = prefs.profileName.isNotEmpty ? prefs.profileName : prefs.googleName;
    final myEmail = prefs.googleEmail;
    final canDelete = prefs.isAdmin || ev.creator == myName || ev.creator == myEmail;

    showModalBottomSheet(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final color = _eventColor(ev.type);
        final icon = _eventIcon(ev.type);
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ev.title.isNotEmpty ? ev.title : _typeLabel(ev.type),
                          style: TextStyle(
                            color: t.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _typeLabel(ev.type),
                          style: TextStyle(color: color, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (ev.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(ev.description, style: TextStyle(color: t.textSecondary, fontSize: 13)),
              ],
              const SizedBox(height: 8),
              Text(
                ev.creator.isNotEmpty ? 'Добавил: ${ev.creator}' : '',
                style: TextStyle(color: t.textSecondary, fontSize: 11),
              ),
              if (ev.expiresAt != null) ...[
                const SizedBox(height: 4),
                Builder(builder: (_) {
                  final rem = ev.expiresAt! - DateTime.now().millisecondsSinceEpoch ~/ 1000;
                  return Text(
                    rem > 0 ? 'Истекает через ${rem ~/ 60} мин' : 'Истекло',
                    style: TextStyle(
                      color: rem > 0 ? Colors.orange : Colors.redAccent,
                      fontSize: 11,
                    ),
                  );
                }),
              ],
              if (canDelete) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final api = context.read<ApiService>();
                      await api.deleteEvent(ev.id);
                      _fetchEvents();
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    label: const Text('Удалить событие',
                      style: TextStyle(color: Colors.redAccent)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showCreateEventDialog(LatLng latLng, PrefsService prefs) {
    final evtNotifier = Provider.of<AppThemeNotifier>(context, listen: false);
    final t = evtNotifier.current;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedType = 'meetup';
    int selectedDuration = 60;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Новое событие',
                  style: TextStyle(color: t.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                Text('Тип', style: TextStyle(color: t.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final (type, label) in [
                      ('meetup', 'Сходка'),
                      ('here',   'Я тут'),
                      ('other',  'Другое'),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: selectedType == type,
                        onSelected: (_) => setLocal(() => selectedType = type),
                        selectedColor: _eventColor(type).withValues(alpha: 0.25),
                        labelStyle: TextStyle(
                          color: selectedType == type ? _eventColor(type) : t.textSecondary,
                        ),
                        backgroundColor: t.surface,
                        side: BorderSide(
                          color: selectedType == type ? _eventColor(type) : t.cardBorder,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                Text('Время действия', style: TextStyle(color: t.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final (dur, lbl) in [
                      (15, '15 мин'),
                      (30, '30 мин'),
                      (60, '1 час'),
                      (0,  'Бессрочно'),
                    ])
                      ChoiceChip(
                        label: Text(lbl),
                        selected: selectedDuration == dur,
                        onSelected: (_) => setLocal(() => selectedDuration = dur),
                        selectedColor: evtNotifier.accent.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: selectedDuration == dur ? evtNotifier.accent : t.textSecondary,
                        ),
                        backgroundColor: t.surface,
                        side: BorderSide(
                          color: selectedDuration == dur ? evtNotifier.accent : t.cardBorder,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: titleCtrl,
                  style: TextStyle(color: t.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Название',
                    labelStyle: TextStyle(color: t.textSecondary),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.cardBorder)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: evtNotifier.accent)),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: descCtrl,
                  style: TextStyle(color: t.textPrimary),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Описание (необязательно)',
                    labelStyle: TextStyle(color: t.textSecondary),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.cardBorder)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: evtNotifier.accent)),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty) return;
                      Navigator.pop(ctx);
                      final myName = prefs.profileName.isNotEmpty
                          ? prefs.profileName
                          : prefs.googleName;
                      final api = context.read<ApiService>();
                      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
                      final expiresAt = selectedDuration == 0 ? null : now + selectedDuration * 60;
                      await api.createEvent({
                        'type':        selectedType,
                        'title':       titleCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'lat':         latLng.latitude,
                        'lon':         latLng.longitude,
                        'creator':     myName,
                        if (expiresAt != null) 'expires_at': expiresAt,
                      });
                      _fetchEvents();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: evtNotifier.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Добавить', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

// ── Pin tail painter ──────────────────────────────────────────────────────────

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
