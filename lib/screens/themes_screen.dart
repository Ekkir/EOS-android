import 'dart:io';
import 'package:file_picker/file_picker.dart';
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

  final _bgHex1Ctrl = TextEditingController();
  final _bgHex2Ctrl = TextEditingController();
  String? _bgHex1Error;
  String? _bgHex2Error;

  @override
  void dispose() {
    _hexCtrl.dispose();
    _hex2Ctrl.dispose();
    _bgHex1Ctrl.dispose();
    _bgHex2Ctrl.dispose();
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

  void _applyBgHex1(AppThemeNotifier notifier) {
    final hex = _bgHex1Ctrl.text.trim().replaceFirst('#', '');
    if (hex.length != 6) { setState(() => _bgHex1Error = 'Введите 6 символов HEX'); return; }
    try {
      final color = Color(int.parse('FF$hex', radix: 16));
      setState(() => _bgHex1Error = null);
      notifier.setBg(notifier.bgType, c1: color);
    } catch (_) { setState(() => _bgHex1Error = 'Неверный HEX'); }
  }

  void _applyBgHex2(AppThemeNotifier notifier) {
    final hex = _bgHex2Ctrl.text.trim().replaceFirst('#', '');
    if (hex.length != 6) { setState(() => _bgHex2Error = 'Введите 6 символов HEX'); return; }
    try {
      final color = Color(int.parse('FF$hex', radix: 16));
      setState(() => _bgHex2Error = null);
      notifier.setBg(notifier.bgType, c2: color);
    } catch (_) { setState(() => _bgHex2Error = 'Неверный HEX'); }
  }

  Future<void> _pickBgImage(AppThemeNotifier notifier) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      await notifier.setBg(AppBgType.image, imagePath: result.files.single.path);
    }
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
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 100),
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

          // Glass blur slider (liquidglass/glassy)
          if (t.isLiquidGlass || t.glassy) ...[
            const SizedBox(height: 8),
            GlassCard(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.blur_on, color: notifier.accent, size: 18),
                      const SizedBox(width: 8),
                      Text('Размытие стекла',
                        style: TextStyle(color: t.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Text(notifier.glassBlur.toStringAsFixed(1),
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
                      value: notifier.glassBlur,
                      min: 2.0,
                      max: 14.0,
                      onChanged: (v) => notifier.setGlassBlur(v),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Слабо', style: TextStyle(color: t.textSecondary, fontSize: 11)),
                      Text('Сильно', style: TextStyle(color: t.textSecondary, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Cyberpunk scanline intensity slider
          if (t.cyberpunk) ...[
            const SizedBox(height: 8),
            GlassCard(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.grid_4x4, color: notifier.accent, size: 18),
                      const SizedBox(width: 8),
                      Text('Интенсивность сканлайнов',
                        style: TextStyle(color: t.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Text('${(notifier.scanlineOpacity * 200).toInt()}%',
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
                      value: notifier.scanlineOpacity,
                      min: 0.0,
                      max: 0.5,
                      onChanged: (v) => notifier.setScanlineOpacity(v),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Нет', style: TextStyle(color: t.textSecondary, fontSize: 11)),
                      Text('Ярко', style: TextStyle(color: t.textSecondary, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ],

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
          // ── Фон приложения ──────────────────────────────────────────────
          const SizedBox(height: 24),
          Text('Фон приложения',
            style: TextStyle(color: t.textSecondary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 10),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selector row
                Row(
                  children: [
                    for (final entry in [
                      (AppBgType.none,     'Нет'),
                      (AppBgType.color,    'Цвет'),
                      (AppBgType.gradient, 'Градиент'),
                      (AppBgType.image,    'Изображение'),
                    ]) ...[
                      Expanded(
                        child: GestureDetector(
                          onTap: () => notifier.setBg(entry.$1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: notifier.bgType == entry.$1
                                  ? notifier.accent.withValues(alpha: 0.25)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: notifier.bgType == entry.$1
                                    ? notifier.accent
                                    : t.cardBorder,
                                width: notifier.bgType == entry.$1 ? 1.5 : 1,
                              ),
                            ),
                            child: Text(
                              entry.$2,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: notifier.bgType == entry.$1
                                    ? notifier.accent
                                    : t.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (notifier.bgType == AppBgType.color) ...[
                  const SizedBox(height: 16),
                  Text('Цвет фона', style: TextStyle(color: t.textPrimary, fontSize: 14)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10, runSpacing: 10,
                    children: _bgColors.map((color) {
                      final isActive = notifier.bgColor1.toARGB32() == color.toARGB32();
                      return GestureDetector(
                        onTap: () => notifier.setBg(AppBgType.color, c1: color),
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
                  const SizedBox(height: 12),
                  Row(children: [
                    Text('#', style: TextStyle(color: t.textSecondary, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    Expanded(child: TextField(
                      controller: _bgHex1Ctrl,
                      style: TextStyle(color: t.textPrimary, fontSize: 15),
                      maxLength: 6, textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'RRGGBB', hintStyle: TextStyle(color: t.textSecondary),
                        counterText: '', errorText: _bgHex1Error,
                        errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.cardBorder)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: notifier.accent)),
                      ),
                      onSubmitted: (_) => _applyBgHex1(notifier),
                    )),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () => _applyBgHex1(notifier),
                      style: TextButton.styleFrom(foregroundColor: notifier.accent),
                      child: const Text('OK'),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  // Preview
                  Container(
                    height: 60, width: double.infinity,
                    decoration: BoxDecoration(
                      color: notifier.bgColor1,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: t.cardBorder),
                    ),
                  ),
                ],
                if (notifier.bgType == AppBgType.gradient) ...[
                  const SizedBox(height: 16),
                  Text('Цвет 1', style: TextStyle(color: t.textPrimary, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _bgColors.map((color) {
                      final isActive = notifier.bgColor1.toARGB32() == color.toARGB32();
                      return GestureDetector(
                        onTap: () => notifier.setBg(AppBgType.gradient, c1: color),
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle,
                            border: isActive ? Border.all(color: Colors.white, width: 2) : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  Row(children: [
                    Text('#', style: TextStyle(color: t.textSecondary, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    Expanded(child: TextField(
                      controller: _bgHex1Ctrl, style: TextStyle(color: t.textPrimary, fontSize: 15),
                      maxLength: 6, textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'RRGGBB', hintStyle: TextStyle(color: t.textSecondary),
                        counterText: '', errorText: _bgHex1Error,
                        errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.cardBorder)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: notifier.accent)),
                      ),
                      onSubmitted: (_) => _applyBgHex1(notifier),
                    )),
                    TextButton(onPressed: () => _applyBgHex1(notifier),
                      style: TextButton.styleFrom(foregroundColor: notifier.accent),
                      child: const Text('OK')),
                  ]),
                  const SizedBox(height: 12),
                  Text('Цвет 2', style: TextStyle(color: t.textPrimary, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _bgColors.map((color) {
                      final isActive = notifier.bgColor2.toARGB32() == color.toARGB32();
                      return GestureDetector(
                        onTap: () => notifier.setBg(AppBgType.gradient, c2: color),
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle,
                            border: isActive ? Border.all(color: Colors.white, width: 2) : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  Row(children: [
                    Text('#', style: TextStyle(color: t.textSecondary, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    Expanded(child: TextField(
                      controller: _bgHex2Ctrl, style: TextStyle(color: t.textPrimary, fontSize: 15),
                      maxLength: 6, textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'RRGGBB', hintStyle: TextStyle(color: t.textSecondary),
                        counterText: '', errorText: _bgHex2Error,
                        errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.cardBorder)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: notifier.accent)),
                      ),
                      onSubmitted: (_) => _applyBgHex2(notifier),
                    )),
                    TextButton(onPressed: () => _applyBgHex2(notifier),
                      style: TextButton.styleFrom(foregroundColor: notifier.accent),
                      child: const Text('OK')),
                  ]),
                  const SizedBox(height: 8),
                  Container(
                    height: 60, width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [notifier.bgColor1, notifier.bgColor2],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: t.cardBorder),
                    ),
                  ),
                ],
                if (notifier.bgType == AppBgType.image) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _pickBgImage(notifier),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: notifier.accent.withValues(alpha: 0.2),
                      foregroundColor: notifier.accent,
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: const Text('Выбрать изображение'),
                  ),
                  if (notifier.bgImagePath != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(notifier.bgImagePath!),
                        height: 100, width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      )),
    );
  }

  static const _bgColors = [
    Colors.black, Color(0xFF0D0D20), Color(0xFF050510), Color(0xFF1A0030),
    Color(0xFF0A1628), Color(0xFF002020), Color(0xFF1A1A1A), Color(0xFF2D1B69),
    Color(0xFF1B0000), Color(0xFF0D1F0D), Color(0xFF1C1A00), Color(0xFF001A2E),
    Color(0xFF2C0A2C), Color(0xFF001A1A), Color(0xFF1A0A00), Color(0xFF0A001A),
  ];

  static const _accentColors = [
    Color(0xFF00E5FF), Color(0xFF3C78FF), Color(0xFF76FF03), Color(0xFF39FF14),
    Color(0xFFFF4081), Color(0xFFFF6D00), Color(0xFFFFAB40), Color(0xFFFFFF00),
    Color(0xFF7C4DFF), Color(0xFFE040FB), Color(0xFF18FFFF), Color(0xFF64FFDA),
    Color(0xFFFF1744), Color(0xFF00BFA5), Color(0xFFFFD740), Color(0xFFCCFF90),
    Color(0xFFFFFFFF), Color(0xFF8D8D8D), Color(0xFFFF6B6B), Color(0xFF4ECDC4),
  ];
}
