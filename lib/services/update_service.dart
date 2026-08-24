import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'prefs_service.dart';
import 'server_url_resolver.dart';

class UpdateLogger {
  static final _entries = <String>[];

  static void log(String msg) {
    final t = DateTime.now().toLocal();
    final ts = '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}:${t.second.toString().padLeft(2,'0')}';
    _entries.add('[$ts] $msg');
  }

  static void clear() => _entries.clear();

  static String get dump => _entries.join('\n');

  static bool get hasEntries => _entries.isNotEmpty;
}

class UpdateService {
  static const currentVersion = '1.2.23';
  static const _installerChannel = MethodChannel('com.traffic.app/installer');
  static const taskName = 'eos_update_check';
  static const notifChannelId = 'eos_updates';
  static const notifChannelName = 'Обновления';
  static const _githubApi =
      'https://api.github.com/repos/Ekkir/EOS-android/releases/latest';

  // Returns {'version': 'v1.1.22', 'apk_url': '...', 'notes': '...'}
  // Pass [prefs] to enable server-proxy (avoids GitHub rate limit).
  static Future<Map<String, String?>?> fetchReleaseInfo({PrefsService? prefs}) async {
    UpdateLogger.log('Проверка обновлений. Текущая версия: $currentVersion');

    // Try backend proxy first (avoids GitHub rate limit)
    if (prefs != null) {
      final fromServer = await _fetchFromBackend(prefs);
      if (fromServer != null) return fromServer;
    }

    // Fallback: direct GitHub
    UpdateLogger.log('Резервный запрос напрямую к GitHub...');
    UpdateLogger.log('URL: $_githubApi');
    try {
      UpdateLogger.log('Отправка HTTP-запроса...');
      final resp = await http.get(
        Uri.parse(_githubApi),
        headers: {'User-Agent': 'EOS-App', 'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 10));

      UpdateLogger.log('HTTP статус: ${resp.statusCode}');
      if (resp.statusCode != 200) {
        UpdateLogger.log('ОШИБКА: неожиданный статус ${resp.statusCode}');
        UpdateLogger.log('Тело ответа: ${resp.body.length > 200 ? resp.body.substring(0, 200) : resp.body}');
        return null;
      }

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final version = json['tag_name'] as String?;
      if (version == null) { UpdateLogger.log('ОШИБКА: поле tag_name отсутствует'); return null; }
      UpdateLogger.log('Версия: $version');

      String? apkUrl;
      for (final asset in (json['assets'] as List? ?? [])) {
        final url = (asset as Map)['browser_download_url'] as String?;
        if (url != null && url.endsWith('.apk')) apkUrl = url;
      }
      UpdateLogger.log(apkUrl != null ? 'APK: $apkUrl' : 'APK не найден');
      UpdateLogger.log('Готово (GitHub direct)');
      return {'version': version, 'apk_url': apkUrl, 'notes': json['body'] as String?};
    } on TimeoutException {
      UpdateLogger.log('ОШИБКА: таймаут 10 сек');
    } on SocketException catch (e) {
      UpdateLogger.log('ОШИБКА сети: $e');
    } catch (e) {
      UpdateLogger.log('ОШИБКА: $e');
    }
    return null;
  }

  static Future<Map<String, String?>?> _fetchFromBackend(PrefsService prefs) async {
    try {
      final serverUrl = await ServerUrlResolver.resolve(prefs);
      if (serverUrl.isEmpty) { UpdateLogger.log('Сервер недоступен, пробуем GitHub'); return null; }
      final url = '$serverUrl/latest_release';
      UpdateLogger.log('URL (сервер): $url');
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      UpdateLogger.log('HTTP статус (сервер): ${resp.statusCode}');
      if (resp.statusCode != 200) return null;
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      if (json.containsKey('error')) { UpdateLogger.log('Ошибка сервера: ${json['error']}'); return null; }
      final version = json['version'] as String?;
      if (version == null) return null;
      UpdateLogger.log('Версия: $version');
      final apkUrl = json['apk_url'] as String?;
      UpdateLogger.log(apkUrl != null ? 'APK: $apkUrl' : 'APK не найден');
      UpdateLogger.log('Готово (сервер-прокси)');
      return {'version': version, 'apk_url': apkUrl, 'notes': json['notes'] as String?};
    } catch (e) {
      UpdateLogger.log('Прокси недоступен ($e), пробуем GitHub');
      return null;
    }
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

  // Deletes all cached update APKs — call on app startup
  static Future<void> clearAllCache() async {
    try {
      final dir = Directory(await _cacheDir());
      await for (final f in dir.list()) {
        if (f is File && f.path.contains('eos_update_')) {
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
