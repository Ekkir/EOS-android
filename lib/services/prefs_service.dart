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

  // ── Плашки главной страницы ────────────────────────────────────────────
  static const _keyHiddenTiles = 'home_hidden_tiles';
  static const _defaultTileOrder = ['traffic', 'map', 'cameras', 'chats', 'vpn', 'car', 'music'];

  static const _defaultHiddenTiles = ['music'];

  Set<String> get hiddenHomeTiles =>
      Set<String>.from(_prefs.getStringList(_keyHiddenTiles) ?? _defaultHiddenTiles);

  bool isTileVisible(String key) => !hiddenHomeTiles.contains(key);

  Future<void> setTileVisible(String key, bool visible) async {
    final hidden = hiddenHomeTiles;
    if (visible) { hidden.remove(key); } else { hidden.add(key); }
    await _prefs.setStringList(_keyHiddenTiles, hidden.toList());
    notifyListeners();
  }

  List<String> get tileOrder {
    final saved = _prefs.getStringList('home_tile_order');
    if (saved != null && saved.toSet().containsAll(_defaultTileOrder)) return saved;
    return List.from(_defaultTileOrder);
  }

  Future<void> setTileOrder(List<String> order) async {
    await _prefs.setStringList('home_tile_order', order);
    notifyListeners();
  }

  bool get squareTiles => _prefs.getBool('square_tiles') ?? false;

  Future<void> setSquareTiles(bool v) async {
    await _prefs.setBool('square_tiles', v);
    notifyListeners();
  }

  // ── Настройки чатов ────────────────────────────────────────────────────────
  static const _keyChatBgType   = 'chat_bg_type';
  static const _keyChatBgColor1 = 'chat_bg_color1';
  static const _keyChatBgColor2 = 'chat_bg_color2';
  static const _keyChatBgImage  = 'chat_bg_image';
  static const _keyChatTextSize = 'chat_text_size';
  static const _keyChatAnim     = 'chat_msg_animation';

  int    get chatBgType   => _prefs.getInt(_keyChatBgType)       ?? 0;
  int    get chatBgColor1 => _prefs.getInt(_keyChatBgColor1)     ?? 0xFF000000;
  int    get chatBgColor2 => _prefs.getInt(_keyChatBgColor2)     ?? 0xFF1A0030;
  String? get chatBgImage => _prefs.getString(_keyChatBgImage);
  double get chatTextSize => _prefs.getDouble(_keyChatTextSize)  ?? 15.0;
  String get chatAnimation => _prefs.getString(_keyChatAnim)     ?? 'none';

  Future<void> setChatBg(int type, {int? color1, int? color2, String? imagePath}) async {
    await _prefs.setInt(_keyChatBgType, type);
    if (color1 != null) await _prefs.setInt(_keyChatBgColor1, color1);
    if (color2 != null) await _prefs.setInt(_keyChatBgColor2, color2);
    if (imagePath != null) await _prefs.setString(_keyChatBgImage, imagePath);
    notifyListeners();
  }

  Future<void> setChatTextSize(double v) async {
    await _prefs.setDouble(_keyChatTextSize, v.clamp(11.0, 22.0));
    notifyListeners();
  }

  Future<void> setChatAnimation(String v) async {
    await _prefs.setString(_keyChatAnim, v);
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

  // ── Безопасность ──────────────────────────────────────────────────────────────
  static const _keySecurityEnabled  = 'security_enabled';
  static const _keyPinCode          = 'pin_code';
  static const _keyBiometricEnabled = 'biometric_enabled';

  bool   get securityEnabled  => _prefs.getBool(_keySecurityEnabled)  ?? false;
  String get pinCode          => _prefs.getString(_keyPinCode)        ?? '';
  bool   get biometricEnabled => _prefs.getBool(_keyBiometricEnabled) ?? false;

  Future<void> setSecurityEnabled(bool v) async {
    await _prefs.setBool(_keySecurityEnabled, v);
    notifyListeners();
  }
  Future<void> setPinCode(String v) async {
    await _prefs.setString(_keyPinCode, v);
    notifyListeners();
  }
  Future<void> setBiometricEnabled(bool v) async {
    await _prefs.setBool(_keyBiometricEnabled, v);
    notifyListeners();
  }

  // ── Настройки панели навигации ─────────────────────────────────────────────
  static const _keyNavAnim = 'nav_bar_animation';
  String get navBarAnimation => _prefs.getString(_keyNavAnim) ?? 'scale';
  Future<void> setNavBarAnimation(String v) async {
    await _prefs.setString(_keyNavAnim, v);
    notifyListeners();
  }

  static const _keyNavPillTransition = 'nav_pill_transition';
  String get navPillTransition => _prefs.getString(_keyNavPillTransition) ?? 'none';
  Future<void> setNavPillTransition(String v) async {
    await _prefs.setString(_keyNavPillTransition, v);
    notifyListeners();
  }

  // ── Одобрение пользователей ────────────────────────────────────────────────
  static const _keyApprovalStatus = 'approval_status';
  static const _keyDeviceId       = 'device_id';

  String get approvalStatus => _prefs.getString(_keyApprovalStatus) ?? 'pending';
  Future<void> setApprovalStatus(String s) async {
    await _prefs.setString(_keyApprovalStatus, s);
    notifyListeners();
  }

  String get deviceId => _prefs.getString(_keyDeviceId) ?? '';
  Future<void> setDeviceId(String id) async =>
      _prefs.setString(_keyDeviceId, id);
}
