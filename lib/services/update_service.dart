import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class UpdateService {
  static const currentVersion = '1.1.21';
  static const taskName = 'eos_update_check';
  static const notifChannelId = 'eos_updates';
  static const notifChannelName = 'Обновления';
  static const _releasesApi =
      'https://api.github.com/repos/Ekkir/EOS-android/releases/latest';

  // Returns {'version': 'v1.1.22', 'apk_url': '...', 'notes': '...'}
  // apk_url is null if release has no APK asset
  static Future<Map<String, String?>?> fetchReleaseInfo() async {
    try {
      final resp = await http.get(
        Uri.parse(_releasesApi),
        headers: {
          'User-Agent': 'EOS-App',
          'Accept': 'application/vnd.github+json',
        },
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) return null;

      final body = resp.body;

      final versionMatch = RegExp(r'"tag_name"\s*:\s*"([^"]+)"').firstMatch(body);
      final version = versionMatch?.group(1);
      if (version == null) return null;

      // Find APK in assets array
      String? apkUrl;
      final assetsMatch = RegExp(
        r'"browser_download_url"\s*:\s*"([^"]+\.apk)"',
      ).firstMatch(body);
      if (assetsMatch != null) apkUrl = assetsMatch.group(1);

      // Extract release notes (body field)
      final notesMatch = RegExp(
        r'"body"\s*:\s*"((?:[^"\\]|\\.)*)"',
      ).firstMatch(body);
      final notes = notesMatch?.group(1)
          ?.replaceAll(r'\n', '\n')
          .replaceAll(r'\r', '')
          .replaceAll(r'\"', '"');

      return {'version': version, 'apk_url': apkUrl, 'notes': notes};
    } catch (_) {}
    return null;
  }

  // Convenience method for background task (only version string)
  static Future<String?> fetchLatestVersion() async {
    final info = await fetchReleaseInfo();
    return info?['version'];
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

  // Downloads APK, calls onProgress(0.0..1.0), returns saved file path
  static Future<String?> downloadApk(
    String url,
    void Function(double progress) onProgress,
  ) async {
    try {
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/eos_update.apk';
      final file = File(savePath);

      final req = http.Request('GET', Uri.parse(url));
      final resp = await req.send().timeout(const Duration(minutes: 5));
      if (resp.statusCode != 200) return null;

      final total = resp.contentLength ?? 0;
      var received = 0;

      final sink = file.openWrite();
      await resp.stream.listen((chunk) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress(received / total);
      }).asFuture<void>();
      await sink.flush();
      await sink.close();

      return savePath;
    } catch (_) {}
    return null;
  }
}
