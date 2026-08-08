import 'package:flutter/services.dart';
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
    await _methodChannel.invokeMethod<void>('connect', config.toJson());
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
