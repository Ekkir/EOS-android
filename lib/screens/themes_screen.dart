import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_surface.dart';

class ThemesScreen extends StatefulWidget {
  const ThemesScreen({super.key});

  @override
  State<ThemesScreen> createState() => _ThemesScreenState();
}

class _ThemesScreenState extends State<ThemesScreen> {
  final _hexCtrl  = TextEditingController();
  final _hex2Ctrl = TextEditingController();
  String? _hexError;
  String? _hex2Error;

  @override
  void dispose() {
    _hexCtrl.dispose();
    _hex2Ctrl.dispose();
    super.dispose();
  }

  void _applyHex(AppThemeNotifier notifier) {
    final hex = _hexCtrl.text.trim().replaceFirst('#', '');
    if (hex.length != 6) { setState(() => _hexError = 'Введите 6 символов HEX'); return; }
    try {
      final color = Color(int.parse('FF$hex', radix: 16));
      setState(() => _hexError = null);
      notifier.apply(notifier.current.id, customAccent: color);
    } catch (_) { setState(() => _hexError = 'Неверный HEX'); }
  }

  void _applyHex2(AppThemeNotifier notifier) {
    final hex = _hex2Ctrl.text.trim().replaceFirst('#', '');
    if (hex.length != 6) { setState(() => _hex2Error = 'Введите 6 символов HEX'); return; }
    try {
      final color = Color(int.parse('FF$hex', radix: 16));
      setState(() => _hex2Error = null);
      notifier.apply(notifier.current.id, customAccent2: color);
    } catch (_) { setState(() => _hex2Error = 'Неверный HEX'); }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = Provider.of<AppThemeNotifier>(context);
    final t = notifier.current;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.nav,
        title: Text('Темы', style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: GlassBg(child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Тема оформления',
            style: TextStyle(color: t.textSecondary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 10),
          ...AppThemeNotifier.themes.map((theme) {
            final isSelected = t.id == theme.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                onTap: () => notifier.apply(theme.id),
                child: Row(
                  children: [
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: theme.bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.cardBorder.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Container(width: 15, height: 4,
                              decoration: BoxDecoration(color: theme.accent, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 2),
                            Container(width: 13, height: 4,
                              decoration: BoxDecoration(color: theme.accent2, borderRadius: BorderRadius.circular(2))),
                          ]),
                          const SizedBox(height: 4),
                          Container(width: 30, height: 4,
                            decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(2))),
                          const SizedBox(height: 4),
                          Container(width: 20, height: 4,
                            decoration: BoxDecoration(color: theme.textSecondary, borderRadius: BorderRadius.circular(2))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(theme.name,
                            style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
                          Text(theme.isLiquidGlass
                              ? 'iOS 26 Liquid Glass'
                              : theme.neonGlow ? 'Неоновое свечение'
                              : theme.glassy ? 'Glassmorphism'
                              : theme.cyberpunk ? 'Глитч и неоновое свечение'
                              : 'Чистый стиль',
                            style: TextStyle(color: t.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: notifier.accent),
                  ],
                ),
              ),
            );
          }),

          // Neon glow intensity slider
          if (t.neonGlow) ...[
            const SizedBox(height: 8),
            GlassCard(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: notifier.accent, size: 18),
                      const SizedBox(width: 8),
                      Text('Интенсивность свечения',
                        style: TextStyle(color: t.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Text('${(notifier.glowIntensity * 100).toInt()}%',
                        style: TextStyle(color: notifier.accent, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: notifier.accent,
                      inactiveTrackColor: t.cardBorder,
                      thumbColor: notifier.accent,
                      overlayColor: notifier.accent.withValues(alpha: 0.2),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: notifier.glowIntensity,
                      min: 0.3,
                      max: 2.5,
                      onChanged: (v) => notifier.setGlowIntensity(v),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Слабо', style: TextStyle(color: t.textSecondary, fontSize: 11)),
                      Text('Ярко', style: TextStyle(color: t.textSecondary, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          Text('Основной акцент',
            style: TextStyle(color: t.textSecondary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 10),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Готовые цвета', style: TextStyle(color: t.textPrimary, fontSize: 14)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => notifier.apply(t.id, resetAll: true),
                      child: Row(
                        children: [
                          Icon(Icons.refresh, color: t.textSecondary, size: 16),
                          const SizedBox(width: 4),
                          Text('Сбросить всё', style: TextStyle(color: t.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10, runSpacing: 10,
                  children: _accentColors.map((color) {
                    final isActive = notifier.accent.toARGB32() == color.toARGB32();
                    return GestureDetector(
                      onTap: () => notifier.apply(t.id, customAccent: color),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isActive ? Border.all(color: Colors.white, width: 3) : null,
                          boxShadow: isActive ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)] : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text('HEX', style: TextStyle(color: t.textPrimary, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('#', style: TextStyle(color: t.textSecondary, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _hexCtrl,
                        style: TextStyle(color: t.textPrimary, fontSize: 15),
                        maxLength: 6,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'RRGGBB',
                          hintStyle: TextStyle(color: t.textSecondary),
                          counterText: '',
                          errorText: _hexError,
                          errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.cardBorder)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: notifier.accent)),
                        ),
                        onSubmitted: (_) => _applyHex(notifier),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () => _applyHex(notifier),
                      style: TextButton.styleFrom(foregroundColor: notifier.accent),
                      child: const Text('Применить'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Text('Дополнительный акцент',
            style: TextStyle(color: t.textSecondary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(t.neonGlow ? 'Цвет бордера карточек и границ в неоне' : 'Вторичный цвет для подсветок',
            style: TextStyle(color: t.textSecondary, fontSize: 11)),
          const SizedBox(height: 10),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10, runSpacing: 10,
                  children: _accentColors.map((color) {
                    final isActive = notifier.accent2.toARGB32() == color.toARGB32();
                    return GestureDetector(
                      onTap: () => notifier.apply(t.id, customAccent2: color),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isActive ? Border.all(color: Colors.white, width: 3) : null,
                          boxShadow: isActive ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)] : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text('HEX', style: TextStyle(color: t.textPrimary, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('#', style: TextStyle(color: t.textSecondary, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _hex2Ctrl,
                        style: TextStyle(color: t.textPrimary, fontSize: 15),
                        maxLength: 6,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'RRGGBB',
                          hintStyle: TextStyle(color: t.textSecondary),
                          counterText: '',
                          errorText: _hex2Error,
                          errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.cardBorder)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: notifier.accent2)),
                        ),
                        onSubmitted: (_) => _applyHex2(notifier),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () => _applyHex2(notifier),
                      style: TextButton.styleFrom(foregroundColor: notifier.accent2),
                      child: const Text('Применить'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      )),
    );
  }

  static const _accentColors = [
    Color(0xFF00E5FF), Color(0xFF3C78FF), Color(0xFF76FF03), Color(0xFF39FF14),
    Color(0xFFFF4081), Color(0xFFFF6D00), Color(0xFFFFAB40), Color(0xFFFFFF00),
    Color(0xFF7C4DFF), Color(0xFFE040FB), Color(0xFF18FFFF), Color(0xFF64FFDA),
    Color(0xFFFF1744), Color(0xFF00BFA5), Color(0xFFFFD740), Color(0xFFCCFF90),
    Color(0xFFFFFFFF), Color(0xFF8D8D8D), Color(0xFFFF6B6B), Color(0xFF4ECDC4),
  ];
}
