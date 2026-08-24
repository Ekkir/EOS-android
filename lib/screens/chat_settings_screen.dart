import 'dart:io';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/prefs_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_surface.dart';

class ChatSettingsScreen extends StatefulWidget {
  const ChatSettingsScreen({super.key});

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final notifier = Provider.of<AppThemeNotifier>(context);
    final t = notifier.current;
    final a = notifier.accent;
    final prefs = context.watch<PrefsService>();

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.nav,
        title: Text('Настройки чатов',
            style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: GlassBg(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            // ── Фон чата ────────────────────────────────────────────────────
            _sectionLabel('Фон чата', t),
            const SizedBox(height: 10),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (final entry in [
                        (0, 'Нет'),
                        (1, 'Цвет'),
                        (2, 'Градиент'),
                        (3, 'Изображение'),
                      ]) ...[
                        Expanded(
                          child: GestureDetector(
                            onTap: () => prefs.setChatBg(entry.$1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: prefs.chatBgType == entry.$1
                                    ? a.withValues(alpha: 0.25)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: prefs.chatBgType == entry.$1 ? a : t.cardBorder,
                                  width: prefs.chatBgType == entry.$1 ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                entry.$2,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: prefs.chatBgType == entry.$1 ? a : t.textSecondary,
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
                  if (prefs.chatBgType == 1) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10, runSpacing: 10,
                      children: _bgColors.map((color) {
                        final cur = Color(prefs.chatBgColor1);
                        final isActive = cur.toARGB32() == color.toARGB32();
                        return GestureDetector(
                          onTap: () => prefs.setChatBg(1, color1: color.toARGB32()),
                          child: Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle,
                              border: isActive ? Border.all(color: Colors.white, width: 3) : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 50, width: double.infinity,
                      decoration: BoxDecoration(
                        color: Color(prefs.chatBgColor1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: t.cardBorder),
                      ),
                      child: Center(child: Text('Превью', style: TextStyle(color: t.textSecondary, fontSize: 12))),
                    ),
                  ],
                  if (prefs.chatBgType == 2) ...[
                    const SizedBox(height: 14),
                    Text('Цвет 1', style: TextStyle(color: t.textPrimary, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: _bgColors.map((color) {
                      final isActive = Color(prefs.chatBgColor1).toARGB32() == color.toARGB32();
                      return GestureDetector(
                        onTap: () => prefs.setChatBg(2, color1: color.toARGB32()),
                        child: Container(width: 30, height: 30, decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle,
                          border: isActive ? Border.all(color: Colors.white, width: 2) : null)),
                      );
                    }).toList()),
                    const SizedBox(height: 10),
                    Text('Цвет 2', style: TextStyle(color: t.textPrimary, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: _bgColors.map((color) {
                      final isActive = Color(prefs.chatBgColor2).toARGB32() == color.toARGB32();
                      return GestureDetector(
                        onTap: () => prefs.setChatBg(2, color2: color.toARGB32()),
                        child: Container(width: 30, height: 30, decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle,
                          border: isActive ? Border.all(color: Colors.white, width: 2) : null)),
                      );
                    }).toList()),
                    const SizedBox(height: 10),
                    Container(
                      height: 50, width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: [Color(prefs.chatBgColor1), Color(prefs.chatBgColor2)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: t.cardBorder),
                      ),
                    ),
                  ],
                  if (prefs.chatBgType == 3) ...[
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.image, allowMultiple: false);
                        if (result?.files.single.path != null) {
                          await prefs.setChatBg(3, imagePath: result!.files.single.path!);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: a.withValues(alpha: 0.2),
                        foregroundColor: a, elevation: 0),
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: const Text('Выбрать изображение'),
                    ),
                    if (prefs.chatBgImage != null) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(File(prefs.chatBgImage!),
                          height: 80, width: double.infinity, fit: BoxFit.cover),
                      ),
                    ],
                  ],
                ],
              ),
            ),

            // ── Размер текста ────────────────────────────────────────────────
            const SizedBox(height: 24),
            _sectionLabel('Размер текста сообщений', t),
            const SizedBox(height: 10),
            GlassCard(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.text_fields, color: a, size: 18),
                      const SizedBox(width: 8),
                      Text('Размер',
                        style: TextStyle(color: t.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Text('${prefs.chatTextSize.toInt()} pt',
                        style: TextStyle(color: a, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: a,
                      inactiveTrackColor: t.cardBorder,
                      thumbColor: a,
                      overlayColor: a.withValues(alpha: 0.2),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: prefs.chatTextSize,
                      min: 11, max: 22, divisions: 11,
                      onChanged: (v) => prefs.setChatTextSize(v),
                    ),
                  ),
                  // Preview bubble
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: a.withValues(alpha: 0.18),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          topRight: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(3),
                        ),
                      ),
                      child: Text(
                        'Пример текста',
                        style: TextStyle(color: t.textPrimary, fontSize: prefs.chatTextSize),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Анимация сообщений ───────────────────────────────────────────
            const SizedBox(height: 24),
            _sectionLabel('Анимация появления сообщений', t),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _animations.map((anim) {
                final isSelected = prefs.chatAnimation == anim.key;
                return GestureDetector(
                  onTap: () => prefs.setChatAnimation(anim.key),
                  child: Container(
                    width: (MediaQuery.of(context).size.width - 52) / 2,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? a.withValues(alpha: 0.15)
                          : t.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? a : t.cardBorder,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        _AnimPreview(animKey: anim.key, accent: a, t: t),
                        const SizedBox(height: 8),
                        Text(
                          anim.label,
                          style: TextStyle(
                            color: isSelected ? a : t.textPrimary,
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle, color: a, size: 16),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, ThemeDef t) => Text(
    text,
    style: TextStyle(
      color: t.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 1,
    ),
  );

  static const _bgColors = [
    Colors.black, Color(0xFF0D0D20), Color(0xFF050510), Color(0xFF1A0030),
    Color(0xFF0A1628), Color(0xFF002020), Color(0xFF1A1A1A), Color(0xFF2D1B69),
    Color(0xFF1B0000), Color(0xFF0D1F0D), Color(0xFF1C1A00), Color(0xFF001A2E),
    Color(0xFF2C0A2C), Color(0xFF001A1A), Color(0xFF1A0A00), Color(0xFF0A001A),
  ];

  static const _animations = [
    _AnimDef('none',   'Без анимации'),
    _AnimDef('fade',   'Появление'),
    _AnimDef('slide',  'Слайд'),
    _AnimDef('scale',  'Масштаб'),
    _AnimDef('bounce', 'Отскок'),
    _AnimDef('glitch', 'Глитч'),
    _AnimDef('pixels', 'Пиксели'),
  ];
}

class _AnimDef {
  final String key;
  final String label;
  const _AnimDef(this.key, this.label);
}

class _AnimPreview extends StatefulWidget {
  final String animKey;
  final Color accent;
  final ThemeDef t;
  const _AnimPreview({required this.animKey, required this.accent, required this.t});

  @override
  State<_AnimPreview> createState() => _AnimPreviewState();
}

class _AnimPreviewState extends State<_AnimPreview> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = CurvedAnimation(
      parent: _ctrl,
      curve: widget.animKey == 'bounce' ? const ElasticOutCurve(0.8) : Curves.easeOut,
    );
    _ctrl.repeat(reverse: true, period: const Duration(milliseconds: 1800));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: widget.accent.withValues(alpha: 0.22),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
          bottomLeft: Radius.circular(10),
          bottomRight: Radius.circular(3),
        ),
      ),
      child: Text('Привет', style: TextStyle(color: widget.t.textPrimary, fontSize: 12)),
    );

    switch (widget.animKey) {
      case 'fade':
        return FadeTransition(opacity: _anim, child: bubble);
      case 'slide':
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.4, 0), end: Offset.zero,
          ).animate(_anim),
          child: FadeTransition(opacity: _anim, child: bubble),
        );
      case 'scale':
        return ScaleTransition(scale: _anim, child: bubble);
      case 'bounce':
        return ScaleTransition(scale: _anim, child: bubble);
      case 'glitch':
        return AnimatedBuilder(
          animation: _anim,
          builder: (_, child) => Transform.translate(
            offset: Offset((_anim.value * 8 * ((_anim.value * 7).toInt().isEven ? 1 : -1)), 0),
            child: Opacity(opacity: _anim.value < 0.2 ? 0.0 : 1.0, child: child),
          ),
          child: bubble,
        );
      case 'pixels':
        return ScaleTransition(
          scale: Tween<double>(begin: 0.3, end: 1.0).animate(_anim),
          child: FadeTransition(opacity: _anim, child: bubble),
        );
      default:
        return bubble;
    }
  }
}
