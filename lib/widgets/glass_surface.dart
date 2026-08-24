import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';

class CyberpunkScanlines extends StatelessWidget {
  const CyberpunkScanlines({super.key});

  @override
  Widget build(BuildContext context) {
    final opacity = context.watch<AppThemeNotifier>().scanlineOpacity;
    return IgnorePointer(
      child: CustomPaint(
        painter: _ScanlinesPainter(opacity),
        size: Size.infinite,
      ),
    );
  }
}

class _ScanlinesPainter extends CustomPainter {
  final double opacity;
  const _ScanlinesPainter(this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final paint = Paint()
      ..color = Color.fromARGB((opacity * 255).round().clamp(0, 255), 0, 0, 0)
      ..style = PaintingStyle.fill;
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1.5), paint);
    }
  }

  @override
  bool shouldRepaint(_ScanlinesPainter old) => old.opacity != opacity;
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
    final dark = !context.watch<AppThemeNotifier>().current.isLight;
    final clip = circle ? BorderRadius.circular(999) : borderRadius;

    return Container(
      decoration: BoxDecoration(
        borderRadius: clip,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: clip,
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: dark ? 0.18 : 0.52),
                        Colors.white.withValues(alpha: dark ? 0.08 : 0.28),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (!circle) ...[
              Positioned(
                left: 0, top: 0, bottom: 0,
                child: Container(
                  width: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white.withValues(alpha: dark ? 0.30 : 0.55),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0, top: 0, right: 0,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: dark ? 0.22 : 0.45),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              Positioned(
                left: 0, top: 0, bottom: 0, right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.5, -0.5),
                      radius: 1.0,
                      colors: [
                        Colors.white.withValues(alpha: dark ? 0.30 : 0.55),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
            // Border overlay
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: clip,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: dark ? 0.25 : 0.55),
                      width: 0.8,
                    ),
                  ),
                ),
              ),
            ),
            // Non-positioned content: determines Stack size, transparent so blur shows through
            if (padding != null)
              Padding(padding: padding!, child: child)
            else
              child,
          ],
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
