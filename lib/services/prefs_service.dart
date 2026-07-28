import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
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
  static const String keyViewpoint      = 'viewpoint';

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
  String  get viewpoint      => _prefs.getString(keyViewpoint)      ?? 'abaza';
  bool    get isAdmin        => googleEmail == adminEmail;

  Future<void> setServerUrl(String v)      async => _prefs.setString(keyServerUrl, v);
  Future<void> setServerUrlLocal(String v) async => _prefs.setString(keyServerUrlLocal, v);
  Future<void> setProfileName(String v)    async => _prefs.setString(keyProfileName, v);
  Future<void> setProfileDesc(String v)    async => _prefs.setString(keyProfileDesc, v);
  Future<void> setFcmToken(String v)       async => _prefs.setString(keyFcmToken, v);
  Future<void> setThemeChosen(bool v)      async => _prefs.setBool(keyThemeChosen, v);
  Future<void> setViewpoint(String v)      async => _prefs.setString(keyViewpoint, v);

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
}
