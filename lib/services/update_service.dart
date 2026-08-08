import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

class UpdateService {
  static const currentVersion = '1.1.93';
  static const _installerChannel = MethodChannel('com.traffic.app/installer');
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

  // Installs APK. Returns null on success, 'NO_PERMISSION:<path>' if permission needed, error message on other errors.
  static Future<String?> installApk(String path) async {
    try {
      final result = await _installerChannel.invokeMethod<bool>('installApk', {'path': path});
      if (result == true) return null;
      // Нативный канал вернул не-true — пробуем OpenFile
    } on PlatformException catch (e) {
      if (e.code == 'NO_INSTALL_PERMISSION') return 'NO_PERMISSION:${e.message}';
      // Нативная ошибка — OpenFile как запасной вариант
      try {
        await OpenFile.open(path, type: 'application/vnd.android.package-archive');
        return null;
      } catch (_) {}
      return e.message ?? 'Ошибка установки';
    } catch (e) {
      // Не-нативная ошибка — OpenFile как запасной вариант
      try {
        await OpenFile.open(path, type: 'application/vnd.android.package-archive');
        return null;
      } catch (_) {}
      return e.toString();
    }
    // Fallback после non-true результата
    try {
      await OpenFile.open(path, type: 'application/vnd.android.package-archive');
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Единая обработка ошибок установки — используется из home_screen и download_ring.
  // err: строка из installApk (null = успех, 'NO_PERMISSION:<path>' = нет разрешения).
  static void handleInstallError(BuildContext context, String err) {
    if (!context.mounted) return;
    if (err.startsWith('NO_PERMISSION:')) {
      final apkPath = err.substring('NO_PERMISSION:'.length);
      showDialog<void>(
        context: context,
        builder: (dCtx) => AlertDialog(
          title: const Text('Разрешение на установку'),
          content: const Text(
            'Включите "Установка из неизвестных источников" для EOS '
            'в открывшихся настройках, затем вернитесь и нажмите "Установить".',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dCtx);
                final err2 = await installApk(apkPath);
                if (err2 != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка установки: $err2')),
                  );
                }
              },
              child: const Text('Установить'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка установки: $err')),
      );
    }
  }

  static Future<String> _cacheDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  static String _apkFilename(String version) =>
      'eos_update_${version.replaceAll('.', '_')}.apk';

  // Returns path to a cached APK for this version, or null if not cached / incomplete
  static Future<String?> getCachedApk(String version) async {
    try {
      final path = '${await _cacheDir()}/${_apkFilename(version)}';
      final f = File(path);
      if (await f.exists() && await f.length() >= 5 * 1024 * 1024) return path;
    } catch (_) {}
    return null;
  }

  // Deletes cached APKs for versions other than the given one
  static Future<void> clearOldCache(String keepVersion) async {
    try {
      final dir = Directory(await _cacheDir());
      await for (final f in dir.list()) {
        if (f is File &&
            f.path.contains('eos_update_') &&
            !f.path.contains(_apkFilename(keepVersion))) {
          await f.delete();
        }
      }
    } catch (_) {}
  }

  // Downloads APK, calls onProgress(0.0..1.0, receivedBytes, totalBytes), returns saved file path
  static Future<String?> downloadApk(
    String url,
    String version,
    void Function(double progress, int received, int total) onProgress,
  ) async {
    final savePath = '${await _cacheDir()}/${_apkFilename(version)}';
    final file = File(savePath);
    IOSink? sink;
    try {
      final req = http.Request('GET', Uri.parse(url));
      final resp = await req.send().timeout(const Duration(minutes: 5));
      if (resp.statusCode != 200) return null;

      final total = resp.contentLength ?? 0;
      var received = 0;

      sink = file.openWrite();
      await resp.stream.listen((chunk) {
        sink!.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress(received / total, received, total);
      }).asFuture<void>();
      await sink.flush();
      await sink.close();
      sink = null;

      // Если сервер передал Content-Length — проверяем что скачали всё
      if (total > 0 && received < total) {
        try { await file.delete(); } catch (_) {}
        return null;
      }
      // Минимальный размер APK — 5 МБ
      if (await file.length() < 5 * 1024 * 1024) {
        try { await file.delete(); } catch (_) {}
        return null;
      }

      await clearOldCache(version);
      return savePath;
    } catch (_) {
      try { await sink?.close(); } catch (_) {}
      try { if (await file.exists()) await file.delete(); } catch (_) {}
      return null;
    }
  }
}
