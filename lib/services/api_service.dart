import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/traffic_state.dart';
import '../models/message.dart';
import '../models/channel.dart';
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

  Future<List<Channel>> getChannels() async {
    try {
      final r = await http.get(Uri.parse('${await _base}/channels'))
          .timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) {
        final list = jsonDecode(r.body) as List;
        return list.map((e) => Channel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Message>> getMessages(String channel, int since) async {
    try {
      final r = await http.get(
        Uri.parse('${await _base}/messages?channel=$channel&since=$since'),
      ).timeout(const Duration(seconds: 3));
      if (r.statusCode == 200) {
        final list = jsonDecode(r.body) as List;
        return list.map((e) => Message.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<Message?> sendMessage({
    required String channel,
    required String sender,
    required String text,
    String type = 'text',
    String mediaId = '',
  }) async {
    try {
      final r = await http.post(Uri.parse('${await _base}/messages'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'channel': channel, 'sender': sender,
            'text': text, 'type': type, 'media_id': mediaId,
          })).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) return Message.fromJson(jsonDecode(r.body));
    } catch (_) {}
    return null;
  }

  // ── Медиа ───────────────────────────────────────────────────────────────

  Future<String?> uploadMedia(File file) async {
    try {
      final base   = await _base;
      final req    = http.MultipartRequest('POST', Uri.parse('$base/media/upload'));
      req.files.add(await http.MultipartFile.fromPath('file', file.path));
      final resp   = await req.send().timeout(const Duration(seconds: 30));
      final body   = await resp.stream.bytesToString();
      if (resp.statusCode == 200) return (jsonDecode(body) as Map)['media_id'] as String?;
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

  Future<List<int>?> getAvatarByName(String name) async {
    try {
      final encoded = Uri.encodeComponent(name);
      final r = await http.get(Uri.parse('${await _base}/avatar/$encoded'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) return r.bodyBytes;
    } catch (_) {}
    return null;
  }

  Future<List<int>?> getAvatarByEmail(String email) async {
    try {
      final r = await http.get(Uri.parse('${await _base}/avatar/email/$email'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) return r.bodyBytes;
    } catch (_) {}
    return null;
  }

  // ── Профиль ─────────────────────────────────────────────────────────────

  Future<bool> syncProfile(String email, String displayName) async {
    try {
      final r = await http.post(Uri.parse('${await _base}/profile'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'google_email': email, 'display_name': displayName}))
          .timeout(const Duration(seconds: 8));
      return r.statusCode == 200;
    } catch (_) { return false; }
  }

  Future<Map<String, dynamic>?> getProfile(String email) async {
    try {
      final r = await http.get(Uri.parse('${await _base}/profile/$email'))
          .timeout(const Duration(seconds: 8));
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
}
