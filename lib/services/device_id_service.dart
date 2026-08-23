import 'package:device_info_plus/device_info_plus.dart';

class DeviceIdService {
  static Future<({String id, String name})> get() async {
    final info = DeviceInfoPlugin();
    try {
      final a = await info.androidInfo;
      return (id: a.id, name: '${a.manufacturer} ${a.model}');
    } catch (_) {
      return (id: 'unknown', name: 'Android Device');
    }
  }
}
