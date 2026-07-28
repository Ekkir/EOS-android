import 'dart:io';

class UpdateService {
  static const currentVersion = '1.1.22';
  static const taskName = 'eos_update_check';
  static const notifChannelId = 'eos_updates';
  static const notifChannelName = 'Обновления';
  static const _releasesApi =
      'https://api.github.com/repos/Ekkir/EOS-android/releases/latest';

  static Future<String?> fetchLatestVersion() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(Uri.parse(_releasesApi));
      req.headers.set('User-Agent', 'EOS-App');
      req.headers.set('Accept', 'application/vnd.github+json');
      final resp = await req.close().timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final body = await resp.transform(const SystemEncoding().decoder).join();
        final match = RegExp(r'"tag_name"\s*:\s*"([^"]+)"').firstMatch(body);
        client.close();
        return match?.group(1);
      }
      client.close();
    } catch (_) {}
    return null;
  }

  static bool isNewer(String remote, String local) {
    List<int> parse(String v) =>
        v.replaceFirst('v', '').split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final r = parse(remote);
    final l = parse(local);
    for (var i = 0; i < 3; i++) {
      final rv = i < r.length ? r[i] : 0;
      final lv = i < l.length ? l[i] : 0;
      if (rv > lv) return true;
      if (rv < lv) return false;
    }
    return false;
  }
}
