import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeDef {
  final String id;
  final String name;
  final Color bg;
  final Color surface;
  final Color nav;
  final Color accent;
  final Color accent2;
  final Color textPrimary;
  final Color textSecondary;
  final Color cardBorder;
  final bool glassy;
  final bool isLiquidGlass;
  final bool neonGlow;
  final bool cyberpunk;

  const ThemeDef({
    required this.id,
    required this.name,
    required this.bg,
    required this.surface,
    required this.nav,
    required this.accent,
    Color? accent2,
    required this.textPrimary,
    required this.textSecondary,
    required this.cardBorder,
    this.glassy = false,
    this.isLiquidGlass = false,
    this.neonGlow = false,
    this.cyberpunk = false,
  }) : accent2 = accent2 ?? accent;
}

class AppThemeNotifier extends ChangeNotifier {
  static final List<ThemeDef> themes = [
    ThemeDef(
      id: 'liquidglass',
      name: 'Liquid Glass',
      bg: const Color(0xFF0E0E15),
      surface: const Color(0x1AFFFFFF),
      nav: const Color(0xFF0E0E15),
      accent: const Color(0xFF3C78FF),
      accent2: const Color(0xFF7C4DFF),
      textPrimary: Colors.white,
      textSecondary: const Color(0xFF8A8A95),
      cardBorder: const Color(0x33FFFFFF),
      glassy: true,
      isLiquidGlass: true,
    ),
    ThemeDef(
      id: 'neon',
      name: 'Neon',
      bg: const Color(0xFF050510),
      surface: const Color(0xFF0D0D20),
      nav: const Color(0xFF0A0A1A),
      accent: const Color(0xFF39FF14),
      accent2: const Color(0xFF00E5FF),
      textPrimary: Colors.white,
      textSecondary: const Color(0xFF6A6A7A),
      cardBorder: const Color(0x5500E5FF),
      neonGlow: true,
    ),
    ThemeDef(
      id: 'minimal',
      name: 'Minimal',
      bg: const Color(0xFF111116),
      surface: const Color(0xFF1C1C24),
      nav: const Color(0xFF16161E),
      accent: const Color(0xFFE8E8F0),
      accent2: const Color(0xFF8D8D8D),
      textPrimary: Colors.white,
      textSecondary: const Color(0x99FFFFFF),
      cardBorder: const Color(0x22FFFFFF),
    ),
    ThemeDef(
      id: 'cyberpunk',
      name: 'Cyberpunk',
      bg: const Color(0xFF050010),
      surface: const Color(0xFF0D0022),
      nav: const Color(0xFF080018),
      accent: const Color(0xFFFF0090),
      accent2: const Color(0xFF00F0FF),
      textPrimary: Colors.white,
      textSecondary: const Color(0xFF9966BB),
      cardBorder: const Color(0x66FF0090),
      cyberpunk: true,
    ),
  ];

  ThemeDef _current = themes[0];
  Color? _customAccent;
  Color? _customAccent2;
  double _glowIntensity = 1.0;

  ThemeDef get current => _current;
  Color get accent  => _customAccent  ?? _current.accent;
  Color get accent2 => _customAccent2 ?? _current.accent2;
  double get glowIntensity => _glowIntensity;

  static String _toHex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  static Color _fromHex(String hex) =>
      Color(int.parse(hex.replaceFirst('#', '0xFF')));

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('theme_id') ?? 'liquidglass';
    if (id == 'glassneon') id = 'liquidglass'; // migrate
    _current = themes.firstWhere((t) => t.id == id, orElse: () => themes[0]);
    final h1 = prefs.getString('accent_$id');
    final h2 = prefs.getString('accent2_$id');
    if (h1 != null) _customAccent  = _fromHex(h1);
    if (h2 != null) _customAccent2 = _fromHex(h2);
    _glowIntensity = prefs.getDouble('glow_intensity') ?? 1.0;
    notifyListeners();
  }

  Future<void> apply(String id, {Color? customAccent, Color? customAccent2, bool resetAll = false}) async {
    final prefs = await SharedPreferences.getInstance();
    _current = themes.firstWhere((t) => t.id == id, orElse: () => themes[0]);
    if (resetAll) {
      _customAccent = null;
      _customAccent2 = null;
      prefs.remove('accent_$id');
      prefs.remove('accent2_$id');
    } else {
      _customAccent  = customAccent  ?? _customAccent;
      _customAccent2 = customAccent2 ?? _customAccent2;
      if (customAccent  != null) prefs.setString('accent_$id',  _toHex(customAccent));
      if (customAccent2 != null) prefs.setString('accent2_$id', _toHex(customAccent2));
    }
    prefs.setString('theme_id', id);
    notifyListeners();
  }

  Future<void> setGlowIntensity(double v) async {
    _glowIntensity = v.clamp(0.3, 2.5);
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('glow_intensity', _glowIntensity);
    notifyListeners();
  }
}
