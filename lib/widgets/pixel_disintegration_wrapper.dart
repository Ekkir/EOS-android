import 'dart:math';
import 'package:flutter/material.dart';

class PixelDisintegrationWrapper extends StatefulWidget {
  final Widget child;
  final double speed; // cycle speed multiplier, default 1.0

  const PixelDisintegrationWrapper({super.key, required this.child, this.speed = 1.0});

  @override
  State<PixelDisintegrationWrapper> createState() =>
      _PixelDisintegrationWrapperState();
}

class _PixelDisintegrationWrapperState
    extends State<PixelDisintegrationWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late final List<_Pixel> _pixels;
  static final _rng = Random(77);

  @override
  void initState() {
    super.initState();
    _pixels = List.generate(38, (_) => _Pixel(_rng));
    _ctrl = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: (3000 / widget.speed).round()))
      ..repeat();
  }

  @override
  void didUpdateWidget(PixelDisintegrationWrapper old) {
    super.didUpdateWidget(old);
    if (old.speed != widget.speed) {
      _ctrl.duration = Duration(milliseconds: (3000 / widget.speed).round());
      if (_ctrl.isAnimating) _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value;
        final opacity = t < 0.45
            ? (1.0 - t / 0.45 * 0.68).clamp(0.0, 1.0)
            : t < 0.55
                ? 0.32
                : (0.32 + (t - 0.55) / 0.45 * 0.68).clamp(0.0, 1.0);
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Opacity(opacity: opacity, child: child),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _DisintegrationPainter(t, _pixels),
                ),
              ),
            ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _Pixel {
  final double nx, ny;
  final Color color;
  final double size;
  final double phase;
  final double driftX, driftY;

  _Pixel(Random rng)
      : nx = rng.nextDouble(),
        ny = rng.nextDouble(),
        color = _palette[rng.nextInt(_palette.length)],
        size = rng.nextDouble() * 2.8 + 1.5,
        phase = rng.nextDouble() * 0.38,
        driftX = (rng.nextDouble() - 0.65) * 30,
        driftY = -(rng.nextDouble() * 22 + 7);

  static const _palette = [
    Color(0xFFFF6B6B), Color(0xFF4ECDC4), Color(0xFF45B7D1),
    Color(0xFFFFA07A), Color(0xFFFFD93D), Color(0xFF98D8C8),
    Color(0xFFFF8C94), Color(0xFFA8E6CF), Color(0xFFDDA0DD),
    Color(0xFF6BCB77), Color(0xFF4D96FF), Color(0xFFFFB347),
  ];
}

class _DisintegrationPainter extends CustomPainter {
  final double t;
  final List<_Pixel> pixels;

  _DisintegrationPainter(this.t, this.pixels);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in pixels) {
      double alpha;
      double dx, dy;

      if (t < 0.45) {
        // Disintegration wave: pixels on the right leave first
        final delay = p.phase * (1.0 - p.nx * 0.45);
        if (t < delay) continue;
        final progress = ((t - delay) / (0.45 - delay)).clamp(0.0, 1.0);
        alpha = (1.0 - progress * 1.1).clamp(0.0, 1.0);
        dx = p.driftX * progress;
        dy = p.driftY * progress;
      } else if (t < 0.55) {
        continue;
      } else {
        // Reconstitution wave: pixels on the left arrive first
        final delay = p.phase * p.nx * 0.45;
        if (t < 0.55 + delay) continue;
        final elapsed = t - 0.55 - delay;
        final span = (0.45 - delay).clamp(0.01, 0.45);
        final progress = (elapsed / span).clamp(0.0, 1.0);
        alpha = (progress * 1.1).clamp(0.0, 1.0);
        dx = p.driftX * (1.0 - progress) * -1;
        dy = p.driftY * (1.0 - progress) * -1;
      }

      if (alpha <= 0) continue;
      paint.color = p.color.withValues(alpha: alpha.clamp(0.0, 1.0));
      final x = p.nx * size.width + dx;
      final y = p.ny * size.height + dy;
      canvas.drawRect(Rect.fromLTWH(x, y, p.size, p.size), paint);
    }
  }

  @override
  bool shouldRepaint(_DisintegrationPainter old) => old.t != t;
}
