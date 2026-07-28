import 'dart:io';
import 'prefs_service.dart';

class ServerUrlResolver {
  static String _cached = '';
  static int    _lastMs = 0;
  static const  _ttlMs  = 30000;

  static Future<String> resolve(PrefsService prefs) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_cached.isNotEmpty && now - _lastMs < _ttlMs) return _cached;

    final remote = prefs.serverUrl;
    final local  = prefs.serverUrlLocal;
    if (local.isEmpty) {
      _cached = remote; _lastMs = now; return remote;
    }
    try {
      final uri    = Uri.parse('$local/stats');
      final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 700);
      final req    = await client.getUrl(uri);
      final resp   = await req.close().timeout(const Duration(milliseconds: 700));
      client.close();
      final result = resp.statusCode == 200 ? local : remote;
      _cached = result; _lastMs = now;
      return result;
    } catch (_) {
      _cached = remote; _lastMs = now;
      return remote;
    }
  }

  static void reset() { _cached = ''; _lastMs = 0; }
}
