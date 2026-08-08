import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';

class CyberpunkScanlines extends StatelessWidget {
  const CyberpunkScanlines({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ScanlinesPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _ScanlinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x1A000000)
      ..style = PaintingStyle.fill;
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1.5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final bool circle;

  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.padding,
    this.blur = 18,
    this.circle = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = dark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.50);
    final highlight = dark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.65);
    final shade = dark
        ? Colors.black.withValues(alpha: 0.25)
        : Colors.black.withValues(alpha: 0.06);
    final clip = circle ? BorderRadius.circular(999) : borderRadius;

    return Container(
      decoration: BoxDecoration(
        borderRadius: clip,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: dark ? 0.38 : 0.60),
            Colors.white.withValues(alpha: dark ? 0.06 : 0.12),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(0.7),
        child: ClipRRect(
          borderRadius: clip,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: clip,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.alphaBlend(highlight.withValues(alpha: 0.10), fill),
                    fill,
                    Color.alphaBlend(shade, fill),
                  ],
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Добавляет слабый градиент фона в glass-темах. Оборачивает body экрана.
class GlassBg extends StatelessWidget {
  final Widget child;
  const GlassBg({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final notifier = Provider.of<AppThemeNotifier>(context);
    final t = notifier.current;
    if (!t.isLiquidGlass && !t.glassy) return child;
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  notifier.accent.withValues(alpha: 0.07),
                  Colors.transparent,
                  notifier.accent2.withValues(alpha: 0.05),
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class AmbientGlow extends StatelessWidget {
  final Color? accent;
  const AmbientGlow({super.key, this.accent});

  Widget _blob(Color c, double size) => ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: c),
        ),
      );

  @override
  Widget build(BuildContext context) {
    const a = 0.55;
    final base = accent ?? const Color(0xFF3C78FF);
    return Stack(
      children: [
        Positioned(left: -50, top: 140,
            child: _blob(base.withValues(alpha: a), 360)),
        Positioned(right: -40, top: 120,
            child: _blob(const Color(0xFF9B5AFF).withValues(alpha: a), 320)),
        Positioned(left: 150, top: 180,
            child: _blob(const Color(0xFF28C8B4).withValues(alpha: a), 240)),
      ],
    );
  }
}
