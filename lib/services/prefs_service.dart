import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrefsService extends ChangeNotifier {
  static const String keyServerUrl      = 'server_url';
  static const String keyServerUrlLocal = 'server_url_local';
  static const String keyProfileName    = 'profile_name';
  static const String keyProfileDesc    = 'profile_desc';
  static const String keyGoogleSignedIn = 'google_signed_in';
  static const String keyGoogleName     = 'google_name';
  static const String keyGoogleEmail    = 'google_email';
  static const String keyGooglePhoto    = 'google_photo';
  static const String keyFcmToken       = 'fcm_token';
  static const String keyThemeId        = 'theme_id';
  static const String keyThemeChosen    = 'theme_chosen';
  static const String keyViewpoint           = 'viewpoint';
  static const String keySharingLocation     = 'sharing_location';
  static const String keySharingInBackground = 'sharing_in_background';

  static const String defaultServerUrl      = 'http://eos-traffic.ddns.net:5000';
  static const String defaultServerUrlLocal = 'http://192.168.0.15:5000';
  static const String adminEmail            = 'razzorenovkiril@gmail.com';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String  get serverUrl      => _prefs.getString(keyServerUrl)      ?? defaultServerUrl;
  String  get serverUrlLocal => _prefs.getString(keyServerUrlLocal) ?? defaultServerUrlLocal;
  String  get profileName    => _prefs.getString(keyProfileName)    ?? '';
  String  get profileDesc    => _prefs.getString(keyProfileDesc)    ?? '';
  bool    get googleSignedIn => _prefs.getBool(keyGoogleSignedIn)   ?? false;
  String  get googleEmail    => _prefs.getString(keyGoogleEmail)    ?? '';
  String  get googleName     => _prefs.getString(keyGoogleName)     ?? '';
  String  get googlePhoto    => _prefs.getString(keyGooglePhoto)    ?? '';
  String  get fcmToken       => _prefs.getString(keyFcmToken)       ?? '';
  bool    get themeChosen    => _prefs.getBool(keyThemeChosen)      ?? false;
  String  get viewpoint           => _prefs.getString(keyViewpoint)           ?? 'abaza';
  bool    get sharingLocation     => _prefs.getBool(keySharingLocation)        ?? false;
  bool    get sharingInBackground => _prefs.getBool(keySharingInBackground)    ?? false;
  bool    get isAdmin             => googleEmail == adminEmail;

  Future<void> setServerUrl(String v)      async => _prefs.setString(keyServerUrl, v);
  Future<void> setServerUrlLocal(String v) async => _prefs.setString(keyServerUrlLocal, v);
  Future<void> setProfileName(String v)    async => _prefs.setString(keyProfileName, v);
  Future<void> setProfileDesc(String v)    async => _prefs.setString(keyProfileDesc, v);
  Future<void> setFcmToken(String v)       async => _prefs.setString(keyFcmToken, v);
  Future<void> setThemeChosen(bool v)      async => _prefs.setBool(keyThemeChosen, v);
  Future<void> setViewpoint(String v)           async => _prefs.setString(keyViewpoint, v);
  Future<void> setSharingLocation(bool v)        async => _prefs.setBool(keySharingLocation, v);
  Future<void> setSharingInBackground(bool v)    async => _prefs.setBool(keySharingInBackground, v);

  Future<void> setGoogleAccount({
    required bool signedIn,
    required String email,
    required String name,
    String photo = '',
  }) async {
    await _prefs.setBool(keyGoogleSignedIn, signedIn);
    await _prefs.setString(keyGoogleEmail, email);
    await _prefs.setString(keyGoogleName, name);
    await _prefs.setString(keyGooglePhoto, photo);
  }

  Future<void> clearGoogleAccount() async {
    await _prefs.setBool(keyGoogleSignedIn, false);
    await _prefs.setString(keyGoogleEmail, '');
    await _prefs.setString(keyGoogleName, '');
    await _prefs.setString(keyGooglePhoto, '');
  }

  double? getMarkerLat(String key) => _prefs.getDouble('cross_${key}_lat');
  double? getMarkerLon(String key) => _prefs.getDouble('cross_${key}_lon');
  Future<void> setMarker(String key, double lat, double lon) async {
    await _prefs.setDouble('cross_${key}_lat', lat);
    await _prefs.setDouble('cross_${key}_lon', lon);
  }

  Color get ringColor1 => Color(_prefs.getInt('ring_color_1') ?? 0xFFBB00FF);
  Color get ringColor2 => Color(_prefs.getInt('ring_color_2') ?? 0xFF00E5FF);
  Future<void> setRingColor1(Color c) async {
    await _prefs.setInt('ring_color_1', c.toARGB32());
    notifyListeners();
  }
  Future<void> setRingColor2(Color c) async {
    await _prefs.setInt('ring_color_2', c.toARGB32());
    notifyListeners();
  }

  String get adminEffect => _prefs.getString('admin_effect') ?? 'aurora';
  Future<void> setAdminEffect(String e) async {
    await _prefs.setString('admin_effect', e);
    notifyListeners();
  }

  // ── Mute чатов ─────────────────────────────────────────────────────────────
  Set<String> get mutedChannels =>
      Set<String>.from(_prefs.getStringList('muted_channels') ?? []);

  bool isChannelMuted(String channelId) => mutedChannels.contains(channelId);

  Future<void> muteChannel(String channelId) async {
    final set = mutedChannels..add(channelId);
    await _prefs.setStringList('muted_channels', set.toList());
    notifyListeners();
  }

  Future<void> unmuteChannel(String channelId) async {
    final set = mutedChannels..remove(channelId);
    await _prefs.setStringList('muted_channels', set.toList());
    notifyListeners();
  }

  // ── Непрочитанные сообщения ─────────────────────────────────────────────────
  int getLastReadId(String channelId) => _prefs.getInt('read_$channelId') ?? 0;

  Future<void> setLastReadId(String channelId, int id) async {
    await _prefs.setInt('read_$channelId', id);
    notifyListeners();
  }

  // ── Версия аватара (для обновления Drawer) ─────────────────────────────
  int get avatarVersion => _prefs.getInt('avatar_version') ?? 0;
  Future<void> incrementAvatarVersion() async {
    await _prefs.setInt('avatar_version', avatarVersion + 1);
    notifyListeners();
  }

  // ── Параметры анимаций аватара ──────────────────────────────────────────
  double get glitchIntensity  => _prefs.getDouble('glitch_intensity')  ?? 0.5;
  double get glitchSpeed      => _prefs.getDouble('glitch_speed')      ?? 1.0;
  double get glitchFrequency  => _prefs.getDouble('glitch_frequency')  ?? 1.0;
  double get auroraSpeed      => _prefs.getDouble('aurora_speed')      ?? 1.0;
  double get disintSpeed      => _prefs.getDouble('disint_speed')      ?? 1.0;

  Future<void> setGlitchIntensity(double v) async {
    await _prefs.setDouble('glitch_intensity', v);
    notifyListeners();
  }
  Future<void> setGlitchSpeed(double v) async {
    await _prefs.setDouble('glitch_speed', v);
    notifyListeners();
  }
  Future<void> setGlitchFrequency(double v) async {
    await _prefs.setDouble('glitch_frequency', v);
    notifyListeners();
  }
  Future<void> setAuroraSpeed(double v) async {
    await _prefs.setDouble('aurora_speed', v);
    notifyListeners();
  }
  Future<void> setDisintSpeed(double v) async {
    await _prefs.setDouble('disint_speed', v);
    notifyListeners();
  }
}
