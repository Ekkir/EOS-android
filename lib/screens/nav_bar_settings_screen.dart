import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/prefs_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_surface.dart';

class NavBarSettingsScreen extends StatelessWidget {
  const NavBarSettingsScreen({super.key});

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
        title: Text('Панель навигации',
            style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: GlassBg(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 100),
          children: [
            Text('Анимация кнопок',
              style: TextStyle(color: t.textSecondary, fontSize: 12,
                  fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _navAnims.map((entry) {
                final isSelected = prefs.navBarAnimation == entry.key;
                return GestureDetector(
                  onTap: () => prefs.setNavBarAnimation(entry.key),
                  child: Container(
                    width: (MediaQuery.of(context).size.width - 52) / 2,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? a.withValues(alpha: 0.15) : t.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? a : t.cardBorder,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        _NavAnimPreview(animKey: entry.key, accent: a, t: t),
                        const SizedBox(height: 8),
                        Text(
                          entry.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? a : t.textPrimary,
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        if (isSelected) Icon(Icons.check_circle, color: a, size: 16),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text('Смена разделов',
              style: TextStyle(color: t.textSecondary, fontSize: 12,
                  fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _pillTransitions.map((entry) {
                final isSelected = prefs.navPillTransition == entry.key;
                return GestureDetector(
                  onTap: () => prefs.setNavPillTransition(entry.key),
                  child: Container(
                    width: (MediaQuery.of(context).size.width - 52) / 2,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? a.withValues(alpha: 0.15) : t.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? a : t.cardBorder,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        _PillTransitionPreview(transKey: entry.key, accent: a, t: t),
                        const SizedBox(height: 8),
                        Text(
                          entry.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? a : t.textPrimary,
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        if (isSelected) Icon(Icons.check_circle, color: a, size: 16),
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

  static const _pillTransitions = [
    _NavAnimDef('none', 'Без анимации'),
    _NavAnimDef('fade', 'Растворение'),
  ];

  static const _navAnims = [
    _NavAnimDef('scale',  'Масштаб'),
    _NavAnimDef('bounce', 'Отскок'),
    _NavAnimDef('pulse',  'Вспышка'),
    _NavAnimDef('glow',   'Свечение'),
    _NavAnimDef('morph',  'Морф'),
    _NavAnimDef('pill',   'Пилюля'),
  ];
}

class _NavAnimDef {
  final String key;
  final String label;
  const _NavAnimDef(this.key, this.label);
}

class _NavAnimPreview extends StatefulWidget {
  final String animKey;
  final Color accent;
  final ThemeDef t;
  const _NavAnimPreview({required this.animKey, required this.accent, required this.t});

  @override
  State<_NavAnimPreview> createState() => _NavAnimPreviewState();
}

class _NavAnimPreviewState extends State<_NavAnimPreview>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    final isElastic = widget.animKey == 'bounce';
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: isElastic ? 900 : 600),
    );
    _anim = CurvedAnimation(
      parent: _ctrl,
      curve: isElastic ? const ElasticOutCurve(0.9) : Curves.easeOut,
    );
    _ctrl.repeat(reverse: true, period: const Duration(milliseconds: 1600));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(Icons.home_rounded, color: widget.accent, size: 24);

    switch (widget.animKey) {
      case 'scale':
        return ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 1.18).animate(_anim),
          child: icon,
        );
      case 'bounce':
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.18).animate(_anim),
          child: icon,
        );
      case 'pulse':
        return AnimatedBuilder(
          animation: _anim,
          builder: (_, child) => Transform.scale(
            scale: 1.0 + 0.32 * sin(pi * _anim.value),
            child: child,
          ),
          child: icon,
        );
      case 'glow':
        return AnimatedBuilder(
          animation: _anim,
          builder: (_, child) => Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.accent.withValues(alpha: 0.6 * _anim.value),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: child,
          ),
          child: icon,
        );
      case 'morph':
        return AnimatedBuilder(
          animation: _anim,
          builder: (_, child) => Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..rotateZ(_anim.value * 0.18)
              ..scale(1.0 + _anim.value * 0.15),
            child: child,
          ),
          child: icon,
        );
      case 'pill':
        return SizedBox(
          width: 80, height: 36,
          child: AnimatedBuilder(
            animation: _anim,
            builder: (_, __) {
              final pos = _anim.value * 40.0;
              final leftActive = _anim.value < 0.5;
              return Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: widget.t.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: widget.t.cardBorder, width: 0.8),
                    ),
                  ),
                  Positioned(
                    left: pos + 3,
                    top: 3, bottom: 3, width: 34,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        color: widget.accent.withValues(alpha: 0.22),
                        border: Border.all(
                            color: widget.accent.withValues(alpha: 0.42), width: 0.8),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(child: Center(child: Icon(Icons.home_rounded,
                          color: leftActive ? widget.accent : widget.t.textSecondary, size: 16))),
                      Expanded(child: Center(child: Icon(Icons.people_rounded,
                          color: leftActive ? widget.t.textSecondary : widget.accent, size: 16))),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      default:
        return icon;
    }
  }
}

// ── Превью перехода между разделами ──────────────────────────────────────────

class _PillTransitionPreview extends StatefulWidget {
  final String transKey;
  final Color accent;
  final ThemeDef t;
  const _PillTransitionPreview({required this.transKey, required this.accent, required this.t});

  @override
  State<_PillTransitionPreview> createState() => _PillTransitionPreviewState();
}

class _PillTransitionPreviewState extends State<_PillTransitionPreview>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _showFirst = true;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _periodicallyToggle();
  }

  void _periodicallyToggle() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) break;
      setState(() => _showFirst = !_showFirst);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget _pill(IconData icon, String label) => Container(
      height: 32,
      decoration: BoxDecoration(
        color: widget.t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.t.cardBorder, width: 0.8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: widget.accent, size: 14),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: widget.accent, fontSize: 10,
              fontWeight: FontWeight.w600)),
        ],
      ),
    );

    final first  = _pill(Icons.home_rounded,       'Главная');
    final second = _pill(Icons.shield_rounded, 'VPN');

    if (widget.transKey == 'fade') {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
        child: KeyedSubtree(
          key: ValueKey(_showFirst),
          child: _showFirst ? first : second,
        ),
      );
    }

    // none
    return _showFirst ? first : second;
  }
}
