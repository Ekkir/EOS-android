import 'package:flutter/material.dart';

class GradientProgressBar extends StatefulWidget {
  final double value;
  final double height;
  final Color background;

  const GradientProgressBar({
    super.key,
    required this.value,
    this.height = 6,
    this.background = const Color(0x22FFFFFF),
  });

  @override
  State<GradientProgressBar> createState() => _GradientProgressBarState();
}

class _GradientProgressBarState extends State<GradientProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
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
      builder: (_, _) => CustomPaint(
        size: Size(double.infinity, widget.height),
        painter: _BarPainter(
          value: widget.value.clamp(0.0, 1.0),
          phase: _ctrl.value,
          background: widget.background,
          height: widget.height,
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  final double value;
  final double phase;
  final Color background;
  final double height;

  const _BarPainter({
    required this.value,
    required this.phase,
    required this.background,
    required this.height,
  });

  static const _colors = [
    Color(0xFF00E5FF), // cyan
    Color(0xFFBB00FF), // purple
    Color(0xFF39FF14), // green
    Color(0xFFFF4081), // pink
    Color(0xFF00E5FF), // cyan — бесшовный цикл
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(height / 2);

    // Фон
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = background,
    );

    if (value <= 0) return;

    // Градиент рассчитывается от полной ширины, но отрисовывается только до value
    final fillRect = Rect.fromLTWH(0, 0, size.width * value, size.height);
    final fullRect = Offset.zero & size;

    final paint = Paint()
      ..shader = LinearGradient(
        colors: _colors,
        begin: Alignment(-1.0 + phase * 2, 0),
        end: Alignment(1.0 + phase * 2, 0),
      ).createShader(fullRect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(fillRect, radius),
      paint,
    );
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.value != value || old.phase != phase;
}
