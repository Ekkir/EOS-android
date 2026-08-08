import 'dart:math';
import 'package:flutter/material.dart';

class AudioVisualizerWrapper extends StatefulWidget {
  final Widget child;
  final double avatarRadius;

  const AudioVisualizerWrapper({
    super.key,
    required this.child,
    this.avatarRadius = 16,
  });

  @override
  State<AudioVisualizerWrapper> createState() => _AudioVisualizerWrapperState();
}

class _AudioVisualizerWrapperState extends State<AudioVisualizerWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  static const _nBars = 32;
  final _rng = Random(12345);
  final List<double> _cur = List.filled(_nBars, 0.5);
  final List<double> _tgt = List.filled(_nBars, 0.5);

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
          ..repeat()
          ..addListener(_tick);
  }

  void _tick() {
    final t = _ctrl.value;
    final bass = (t % 0.25) < 0.042;
    if (_rng.nextDouble() < 0.14) {
      for (var i = 0; i < _nBars; i++) {
        _tgt[i] = bass ? 0.72 + _rng.nextDouble() * 0.28 : _rng.nextDouble();
      }
    }
    setState(() {
      final smooth = bass ? 0.38 : 0.11;
      for (var i = 0; i < _nBars; i++) {
        _cur[i] += (_tgt[i] - _cur[i]) * smooth;
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final extra = widget.avatarRadius * 1.4 + 12;
    final total = (widget.avatarRadius + extra) * 2;
    return SizedBox(
      width: total,
      height: total,
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _VisualizerPainter(_ctrl.value, _cur, widget.avatarRadius),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisualizerPainter extends CustomPainter {
  final double t;
  final List<double> heights;
  final double avatarR;

  const _VisualizerPainter(this.t, this.heights, this.avatarR);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const nBars = 32;
    const twoPi = 2 * pi;

    // Inner pulsing ring
    final ringR = avatarR + 5 + sin(t * twoPi) * 1.8;
    canvas.drawCircle(
      center,
      ringR,
      Paint()
        ..color = const Color(0xFF00FFFF).withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Radial bars
    final barsStart = avatarR + 10.0;
    for (var i = 0; i < nBars; i++) {
      final angle = i / nBars * twoPi - pi / 2;
      final barH = heights[i] * 15 + 4;
      final frac = i / nBars;
      final barColor = Color.lerp(
        const Color(0xFFFF00FF),
        const Color(0xFF00FFFF),
        frac,
      )!;

      final x1 = center.dx + cos(angle) * barsStart;
      final y1 = center.dy + sin(angle) * barsStart;
      final x2 = center.dx + cos(angle) * (barsStart + barH);
      final y2 = center.dy + sin(angle) * (barsStart + barH);

      canvas.drawLine(
        Offset(x1, y1),
        Offset(x2, y2),
        Paint()
          ..color = barColor.withValues(alpha: 0.88)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }
  }

  @override
  bool shouldRepaint(_VisualizerPainter old) => true;
}
