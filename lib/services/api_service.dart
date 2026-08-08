import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/traffic_state.dart';
import '../models/message.dart';
import '../models/channel.dart';
import '../models/event.dart';
import 'prefs_service.dart';
import 'server_url_resolver.dart';

class ApiService {
  final PrefsService prefs;
  ApiService(this.prefs);

  Future<String> get _base => ServerUrlResolver.resolve(prefs);

  // ── Трафик ──────────────────────────────────────────────────────────────

  Future<TrafficSnapshot?> getLights() async {
    try {
      final r = await http.get(Uri.parse('${await _base}/lights'))
          .timeout(const Duration(seconds: 3));
      if (r.statusCode == 200) return TrafficSnapshot.fromJson(jsonDecode(r.body));
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getConfig() async {
    try {
      final r = await http.get(Uri.parse('${await _base}/config'))
          .timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {}
    return null;
  }

  Future<bool> setConfig(Map<String, dynamic> config) async {
    try {
      final r = await http.post(Uri.parse('${await _base}/config'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(config)).timeout(const Duration(seconds: 5));
      return r.statusCode == 200;
    } catch (_) { return false; }
  }

  Future<bool> resetRoad(String road) async {
    try {
      final r = await http.post(Uri.parse('${await _base}/reset'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'road': road})).timeout(const Duration(seconds: 5));
      return r.statusCode == 200;
    } catch (_) { return false; }
  }

  // ── Мессенджер ──────────────────────────────────────────────────────────

  Future<List<Channel>> getChannels({String? myName}) async {
    try {
      final param = (myName != null && myName.isNotEmpty)
          ? '?name=${Uri.encodeComponent(myName)}'
          : '';
      final r = await http.get(Uri.parse('${await _base}/channels$param'))
          .timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) {
        final list = jsonDecode(r.body) as List;
        final all = list.map((e) => Channel.fromJson(e as Map<String, dynamic>)).toList();
        // Client-side fallback: filter DMs to only those containing our name
        if (myName != null && myName.isNotEmpty) {
          final lc = myName.toLowerCase();
          return all.where((ch) {
            if (!ch.isDm) return true;
            final body = ch.id.substring(3).toLowerCase();
            final parts = body.contains('~') ? body.split('~') : [body];
            return parts.any((p) => p == lc);
          }).toList();
        }
        return all;
      }
    } catch (_) {}
    return [];
  }

  Future<({List<Message> messages, List<int> deleted})> getMessages(
      String channel, int since) async {
    try {
      final r = await http.get(
        Uri.parse('${await _base}/messages?channel=$channel&since=$since'),
      ).timeout(const Duration(seconds: 3));
      if (r.statusCode == 200) {
        final body = jsonDecode(r.body);
        if (body is Map) {
          final msgs = (body['messages'] as List? ?? [])
              .map((e) => Message.fromJson(e as Map<String, dynamic>))
              .toList();
          final del = (body['deleted'] as List? ?? [])
              .map((e) => e as int)
              .toList();
          return (messages: msgs, deleted: del);
        } else if (body is List) {
          // backwards compat: old server returning plain list
          final msgs = body
              .map((e) => Message.fromJson(e as Map<String, dynamic>))
              .toList();
          return (messages: msgs, deleted: <int>[]);
        }
      }
    } catch (_) {}
    return (messages: <Message>[], deleted: <int>[]);
  }

  Future<Message?> sendMessage({
    required String channel,
    required String sender,
    required String text,
    String type = 'text',
    String mediaId = '',
    int? replyToId,
    String? replyToText,
  }) async {
    try {
      final r = await http.post(Uri.parse('${await _base}/messages'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'channel': channel, 'sender': sender,
            'text': text, 'type': type, 'media_id': mediaId,
            if (replyToId != null) 'reply_to_id': replyToId,
            if (replyToText != null) 'reply_to_text': replyToText,
          })).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) return Message.fromJson(jsonDecode(r.body));
    } catch (_) {}
    return null;
  }

  Future<bool> editMessage(String channel, int msgId, String sender, String text) async {
    try {
      final r = await http.put(
        Uri.parse('${await _base}/messages/$msgId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'channel': channel, 'sender': sender, 'text': text}),
      ).timeout(const Duration(seconds: 8));
      return r.statusCode == 200;
    } catch (_) { return false; }
  }

  // ── Медиа ───────────────────────────────────────────────────────────────

  Future<String?> uploadMedia(File file, {void Function(double)? onProgress}) async {
    try {
      final base     = await _base;
      final bytes    = await file.readAsBytes();
      final total    = bytes.length;
      final filename = file.path.split(RegExp(r'[/\\]')).last;

      if (onProgress == null) {
        final req = http.MultipartRequest('POST', Uri.parse('$base/media/upload'));
        req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
        final resp = await req.send().timeout(const Duration(seconds: 60));
        final body = await resp.stream.bytesToString();
        if (resp.statusCode == 200) return (jsonDecode(body) as Map)['media_id'] as String?;
      } else {
        final boundary = 'EOS${DateTime.now().millisecondsSinceEpoch}';
        final prefix = utf8.encode(
          '--$boundary\r\nContent-Disposition: form-data; name="file"; '
          'filename="$filename"\r\nContent-Type: application/octet-stream\r\n\r\n',
        );
        final suffix     = utf8.encode('\r\n--$boundary--\r\n');
        final contentLen = prefix.length + total + suffix.length;

        final client = http.Client();
        try {
          final req = http.StreamedRequest('POST', Uri.parse('$base/media/upload'))
            ..headers['Content-Type'] = 'multipart/form-data; boundary=$boundary'
            ..headers['Content-Length'] = '$contentLen';
          final respFuture = client.send(req).timeout(const Duration(seconds: 60));

          req.sink.add(prefix);
          const chunkSize = 32768;
          int sent = prefix.length;
          for (var i = 0; i < total; i += chunkSize) {
            final end = (i + chunkSize).clamp(0, total);
            req.sink.add(bytes.sublist(i, end));
            sent += end - i;
            onProgress(sent / contentLen);
            await Future.delayed(Duration.zero);
          }
          req.sink.add(suffix);
          await req.sink.close();
          onProgress(1.0);

          final resp = await respFuture;
          final body = await resp.stream.bytesToString();
          if (resp.statusCode == 200) return (jsonDecode(body) as Map)['media_id'] as String?;
        } finally {
          client.close();
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<int>?> downloadMedia(String mediaId) async {
    try {
      final r = await http.get(Uri.parse('${await _base}/media/$mediaId'))
          .timeout(const Duration(seconds: 30));
      if (r.statusCode == 200) return r.bodyBytes;
    } catch (_) {}
    return null;
  }

  Future<bool> deleteMedia(String mediaId) async {
    try {
      final r = await http.delete(Uri.parse('${await _base}/media/$mediaId'))
          .timeout(const Duration(seconds: 5));
      return r.statusCode == 200;
    } catch (_) { return false; }
  }

  // ── Аватары ─────────────────────────────────────────────────────────────

  Future<bool> uploadAvatar(File file, String sender, {String? email}) async {
    try {
      final base = await _base;
      final req  = http.MultipartRequest('POST', Uri.parse('$base/avatar'));
      req.fields['sender'] = sender;
      if (email != null && email.isNotEmpty) req.fields['google_email'] = email;
      req.files.add(await http.MultipartFile.fromPath('file', file.path));
      final resp = await req.send().timeout(const Duration(seconds: 15));
      return resp.statusCode == 200;
    } catch (_) { return false; }
  }

  static Future<String> _avatarCacheDir() async =>
      (await getApplicationCacheDirectory()).path;

  static Future<Uint8List?> _avatarFromDisk(String key) async {
    try {
      final f = File('${await _avatarCacheDir()}/av_$key.jpg');
      if (f.existsSync()) return f.readAsBytesSync();
    } catch (_) {}
    return null;
  }

  static Future<void> _avatarToDisk(String key, List<int> bytes) async {
    try {
      final f = File('${await _avatarCacheDir()}/av_$key.jpg');
      await f.writeAsBytes(bytes);
    } catch (_) {}
  }

  Future<List<int>?> getAvatarByName(String name) async {
    final key = name.replaceAll(RegExp(r'[^\w]'), '_');
    final cached = await _avatarFromDisk(key);
    if (cached != null) return cached;
    try {
      final encoded = Uri.encodeComponent(name);
      final r = await http.get(Uri.parse('${await _base}/avatar/$encoded'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        await _avatarToDisk(key, r.bodyBytes);
        return r.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  Future<List<int>?> getAvatarByEmail(String email) async {
    final key = 'em_${email.replaceAll(RegExp(r'[^\w@]'), '_')}';
    final cached = await _avatarFromDisk(key);
    if (cached != null) return cached;
    try {
      final r = await http.get(Uri.parse('${await _base}/avatar/email/$email'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        await _avatarToDisk(key, r.bodyBytes);
        return r.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  // ── Профиль ─────────────────────────────────────────────────────────────

  // Returns null on success, error message on failure (e.g. 'nickname_taken')
  Future<String?> syncProfile(String email, String displayName,
      {String? bio, String? avatarEffect}) async {
    try {
      final r = await http.post(Uri.parse('${await _base}/profile'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'google_email': email,
            'display_name': displayName,
            if (bio != null) 'bio': bio,
            if (avatarEffect != null) 'avatar_effect': avatarEffect,
          })).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) return null;
      if (r.statusCode == 409) return 'nickname_taken';
      return 'error';
    } catch (_) { return 'error'; }
  }

  Future<bool> checkNickname(String name, {String? excludeEmail}) async {
    try {
      final encoded = Uri.encodeComponent(name);
      var url = '${await _base}/check_nickname/$encoded';
      if (excludeEmail != null) url += '?email=${Uri.encodeComponent(excludeEmail)}';
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        return data['available'] == true;
      }
    } catch (_) {}
    return true;
  }

  Future<void> ping(String email) async {
    try {
      await http.post(Uri.parse('${await _base}/ping'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email}))
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> getProfile(String email, {String? viewer}) async {
    try {
      var url = '${await _base}/profile/$email';
      if (viewer != null && viewer.isNotEmpty) {
        url += '?viewer=${Uri.encodeComponent(viewer)}';
      }
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {}
    return null;
  }

  // ── FCM ─────────────────────────────────────────────────────────────────

  Future<void> registerFcmToken(String sender, String token) async {
    try {
      await http.post(Uri.parse('${await _base}/fcm_token'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'sender': sender, 'token': token}))
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  // ── Статистика (Admin) ───────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getStats() async {
    try {
      final r = await http.get(Uri.parse('${await _base}/stats'))
          .timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {}
    return null;
  }

  Future<List<String>> getLog() async {
    try {
      final r = await http.get(Uri.parse('${await _base}/log'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final raw = (jsonDecode(r.body) as Map)['log'] as String? ?? '';
        return raw.isEmpty ? [] : raw.split('\n');
      }
    } catch (_) {}
    return [];
  }

  Future<bool> restartServer() async {
    try {
      final r = await http.post(Uri.parse('${await _base}/restart'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({}))
          .timeout(const Duration(seconds: 10));
      return r.statusCode == 200;
    } catch (_) { return false; }
  }

  Future<bool> checkAdmin(String password) async {
    try {
      final r = await http.post(Uri.parse('${await _base}/check_admin'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'password': password}))
          .timeout(const Duration(seconds: 8));
      return r.statusCode == 200;
    } catch (_) { return false; }
  }

  Future<bool> deleteMessage(String channel, int id) async {
    try {
      final r = await http.delete(
        Uri.parse('${await _base}/messages/$id?channel=$channel'),
      ).timeout(const Duration(seconds: 5));
      return r.statusCode == 200;
    } catch (_) { return false; }
  }

  // ── Отчёты об ошибках ───────────────────────────────────────────────────

  Future<bool> submitBugReport({
    required String from,
    required String device,
    required String text,
  }) async {
    try {
      final r = await http.post(Uri.parse('${await _base}/bug_reports'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'from': from, 'device': device, 'text': text}))
          .timeout(const Duration(seconds: 8));
      return r.statusCode == 200;
    } catch (_) { return false; }
  }

  Future<List<Map<String, dynamic>>> getBugReports() async {
    try {
      final r = await http.get(Uri.parse('${await _base}/bug_reports'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final list = jsonDecode(r.body) as List;
        return list.map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> deleteBugReport(int id) async {
    try {
      final r = await http.delete(Uri.parse('${await _base}/bug_reports/$id'))
          .timeout(const Duration(seconds: 5));
      return r.statusCode == 200;
    } catch (_) { return false; }
  }

  Future<bool> usernameExists(String name) async {
    try {
      final encoded = Uri.encodeComponent(name);
      final r = await http.get(Uri.parse('${await _base}/profile/name/$encoded'))
          .timeout(const Duration(seconds: 5));
      return r.statusCode == 200;
    } catch (_) { return false; }
  }

  Future<Map<String, dynamic>?> getProfileByName(String name) async {
    try {
      final encoded = Uri.encodeComponent(name);
      final r = await http.get(Uri.parse('${await _base}/profile/name/$encoded'))
          .timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
      return null;
    } catch (_) { return null; }
  }

  // ── Друзья ──────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getFriends(String email) async {
    try {
      final encoded = Uri.encodeComponent(email);
      final r = await http.get(Uri.parse('${await _base}/friends/$encoded'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final list = jsonDecode(r.body) as List;
        return list.map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> addFriend(String myEmail, String friendEmail) async {
    try {
      final r = await http.post(Uri.parse('${await _base}/friends/add'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': myEmail, 'friend_email': friendEmail}))
          .timeout(const Duration(seconds: 8));
      return r.statusCode == 200;
    } catch (_) { return false; }
  }

  Future<bool> removeFriend(String myEmail, String friendEmail) async {
    try {
      final r = await http.post(Uri.parse('${await _base}/friends/remove'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': myEmail, 'friend_email': friendEmail}))
          .timeout(const Duration(seconds: 8));
      return r.statusCode == 200;
    } catch (_) { return false; }
  }

  // ── События на карте ─────────────────────────────────────────────────────────

  Future<List<EosEvent>> getEvents({double since = 0}) async {
    try {
      final r = await http.get(Uri.parse('${await _base}/events?since=$since'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final list = jsonDecode(r.body) as List;
        return list.map((e) => EosEvent.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<EosEvent?> createEvent(Map<String, dynamic> data) async {
    try {
      final r = await http.post(Uri.parse('${await _base}/events'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(data))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) return EosEvent.fromJson(jsonDecode(r.body));
    } catch (_) {}
    return null;
  }

  Future<bool> deleteEvent(int id) async {
    try {
      final r = await http.delete(Uri.parse('${await _base}/events/$id'))
          .timeout(const Duration(seconds: 8));
      return r.statusCode == 200;
    } catch (_) { return false; }
  }

  // ── Геолокация пользователей ─────────────────────────────────────────────────

  Future<void> updateLocation(String email, double lat, double lon, String displayName) async {
    try {
      await http.post(Uri.parse('${await _base}/location'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'lat': lat, 'lon': lon, 'display_name': displayName}))
          .timeout(const Duration(seconds: 6));
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getLiveLocations() async {
    try {
      final r = await http.get(Uri.parse('${await _base}/locations'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final list = jsonDecode(r.body) as List;
        return list.map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> deleteChannel(String channelId) async {
    try {
      final encoded = Uri.encodeComponent(channelId);
      final r = await http.delete(Uri.parse('${await _base}/channels/$encoded'))
          .timeout(const Duration(seconds: 8));
      return r.statusCode == 200;
    } catch (_) { return false; }
  }
}
