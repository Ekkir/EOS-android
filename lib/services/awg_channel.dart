import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vpn_config.dart';
import '../models/vpn_state.dart';

const _methodChannel = MethodChannel('com.traffic.app.awg/channel');
const _statusChannel = EventChannel('com.traffic.app.awg/status');

class AwgChannel {
  AwgChannel._();
  static final instance = AwgChannel._();

  Stream<VpnStatus> get statusStream => _statusChannel
      .receiveBroadcastStream()
      .map((event) => VpnStatus.fromString(event as String));

  Future<void> connect(VpnConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final splitMode = prefs.getString('vpn_split_mode') ?? 'none';
    final splitAppsJson = prefs.getString('vpn_split_apps') ?? '[]';
    final splitApps = (jsonDecode(splitAppsJson) as List).cast<String>();
    final args = Map<String, dynamic>.from(config.toJson());
    args['split_mode'] = splitMode;
    args['split_apps'] = splitApps;
    await _methodChannel.invokeMethod<void>('connect', args);
  }

  Future<void> disconnect() async {
    await _methodChannel.invokeMethod<void>('disconnect');
  }

  Future<VpnStatus> getStatus() async {
    final s = await _methodChannel.invokeMethod<String>('getStatus');
    return VpnStatus.fromString(s ?? 'disconnected');
  }

  Future<TrafficStats> getStats() async {
    final raw = await _methodChannel.invokeMethod<Map>('getStats');
    if (raw == null) return TrafficStats.zero;
    return TrafficStats(
      rxBytes: (raw['rxBytes'] as int?) ?? 0,
      txBytes: (raw['txBytes'] as int?) ?? 0,
    );
  }
}
