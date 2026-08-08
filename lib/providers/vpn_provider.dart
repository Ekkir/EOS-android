import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vpn_config.dart';
import '../models/vpn_state.dart';
import '../services/awg_channel.dart';

class VpnProvider extends ChangeNotifier {
  final _channel = AwgChannel.instance;

  List<VpnConfig> _configs = [];
  VpnConfig? _activeConfig;
  VpnStatus _status = VpnStatus.disconnected;
  TrafficStats _stats = TrafficStats.zero;
  String? _errorMessage;

  StreamSubscription<VpnStatus>? _statusSub;
  Timer? _statsTicker;

  List<VpnConfig> get configs => List.unmodifiable(_configs);
  VpnConfig? get activeConfig => _activeConfig;
  VpnStatus get status => _status;
  TrafficStats get stats => _stats;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _status == VpnStatus.connected;
  bool get isBusy =>
      _status == VpnStatus.connecting || _status == VpnStatus.disconnecting;

  VpnProvider() {
    _init();
  }

  Future<void> _init() async {
    await _loadConfigs();
    try {
      _status = await _channel.getStatus();
    } catch (_) {}
    _subscribeStatus();
    notifyListeners();
  }

  void _subscribeStatus() {
    _statusSub?.cancel();
    _statusSub = _channel.statusStream.listen(
      (s) {
        final prev = _status;
        _status = s;
        if (s == VpnStatus.connected) {
          _startStatsTicker();
        } else {
          _stopStatsTicker();
          if (s == VpnStatus.disconnected) _stats = TrafficStats.zero;
        }
        if (s == VpnStatus.error && prev != VpnStatus.error) {
          // keep error message
        } else if (s != VpnStatus.error) {
          _errorMessage = null;
        }
        notifyListeners();
      },
      onError: (e) {
        _status = VpnStatus.error;
        _errorMessage = e.toString();
        notifyListeners();
      },
    );
  }

  void _startStatsTicker() {
    _statsTicker?.cancel();
    _statsTicker = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        _stats = await _channel.getStats();
        notifyListeners();
      } catch (_) {}
    });
  }

  void _stopStatsTicker() {
    _statsTicker?.cancel();
    _statsTicker = null;
  }

  Future<void> connect(VpnConfig config) async {
    if (isBusy) return;
    _activeConfig = config;
    _status = VpnStatus.connecting;
    _errorMessage = null;
    notifyListeners();
    try {
      await _channel.connect(config);
    } catch (e) {
      _status = VpnStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    if (isBusy) return;
    _status = VpnStatus.disconnecting;
    notifyListeners();
    try {
      await _channel.disconnect();
    } catch (e) {
      _status = VpnStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> toggle() async {
    if (isConnected || _status == VpnStatus.disconnecting) {
      await disconnect();
    } else if (_activeConfig != null) {
      await connect(_activeConfig!);
    }
  }

  void selectConfig(VpnConfig config) {
    _activeConfig = config;
    notifyListeners();
  }

  bool addConfigFromText(String text, {String? name}) {
    final config = VpnConfig.parse(text, nameHint: name);
    if (config == null) return false;
    _configs.add(config);
    _activeConfig ??= config;
    _saveConfigs();
    notifyListeners();
    return true;
  }

  void removeConfig(String id) {
    _configs.removeWhere((c) => c.id == id);
    if (_activeConfig?.id == id) {
      _activeConfig = _configs.isNotEmpty ? _configs.first : null;
    }
    _saveConfigs();
    notifyListeners();
  }

  Future<void> _loadConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('vpn_configs') ?? [];
      _configs = list.map((s) => VpnConfig.fromJsonString(s)).toList();
      final activeId = prefs.getString('active_vpn_config_id');
      if (activeId != null) {
        _activeConfig = _configs.where((c) => c.id == activeId).firstOrNull;
      }
      _activeConfig ??= _configs.firstOrNull;

      if (_configs.isEmpty) {
        await _loadBundledConfig();
      }
    } catch (_) {}
  }

  Future<void> _loadBundledConfig() async {
    try {
      final raw = await rootBundle.loadString('assets/stockholm.conf');
      final config = VpnConfig.parse(raw, nameHint: 'Stockholm');
      if (config != null) {
        _configs.add(config);
        _activeConfig = config;
        await _saveConfigs();
      }
    } catch (_) {}
  }

  Future<void> _saveConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'vpn_configs',
        _configs.map((c) => c.toJsonString()).toList(),
      );
      if (_activeConfig != null) {
        await prefs.setString('active_vpn_config_id', _activeConfig!.id);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _statsTicker?.cancel();
    super.dispose();
  }
}
