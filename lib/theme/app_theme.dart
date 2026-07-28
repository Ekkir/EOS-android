import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeDef {
  final String id;
  final String name;
  final Color bg;
  final Color surface;
  final Color nav;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final Color cardBorder;
  final bool glassy;

  const ThemeDef({
    required this.id,
    required this.name,
    required this.bg,
    required this.surface,
    required this.nav,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.cardBorder,
    this.glassy = false,
  });
}

class AppThemeNotifier extends ChangeNotifier {
  static final List<ThemeDef> themes = [
    ThemeDef(
      id: 'glassneon',
      name: 'Glass Neon',
      bg: const Color(0xFF0A0A14),
      surface: const Color(0x1AFFFFFF),
      nav: const Color(0xFF0D0D1A),
      accent: const Color(0xFF00E5FF),
      textPrimary: Colors.white,
      textSecondary: const Color(0x99FFFFFF),
      cardBorder: const Color(0x33FFFFFF),
      glassy: true,
    ),
    ThemeDef(
      id: 'minimal',
      name: 'Minimal',
      bg: const Color(0xFF111116),
      surface: const Color(0xFF1C1C24),
      nav: const Color(0xFF16161E),
      accent: const Color(0xFFE8E8F0),
      textPrimary: Colors.white,
      textSecondary: const Color(0x99FFFFFF),
      cardBorder: const Color(0x22FFFFFF),
      glassy: false,
    ),
  ];

  ThemeDef _current = themes[0];
  Color? _customAccent;

  ThemeDef get current => _current;
  Color get accent => _customAccent ?? _current.accent;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('theme_id') ?? 'glassneon';
    _current = themes.firstWhere((t) => t.id == id, orElse: () => themes[0]);
    final accentHex = prefs.getString('accent_$id');
    if (accentHex != null) {
      _customAccent = Color(int.parse(accentHex.replaceFirst('#', '0xFF')));
    }
    notifyListeners();
  }

  Future<void> apply(String id, {Color? customAccent}) async {
    final prefs = await SharedPreferences.getInstance();
    _current = themes.firstWhere((t) => t.id == id, orElse: () => themes[0]);
    _customAccent = customAccent;
    prefs.setString('theme_id', id);
    if (customAccent != null) {
      prefs.setString('accent_$id', '#${customAccent.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}');
    }
    notifyListeners();
  }
}
