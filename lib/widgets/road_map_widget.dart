import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/traffic_state.dart';
import '../theme/app_theme.dart';

class RoadMapWidget extends StatelessWidget {
  final TrafficSnapshot snapshot;
  final ThemeDef theme;
  final void Function(String road)? onRoadTap;

  const RoadMapWidget({
    super.key,
    required this.snapshot,
    required this.theme,
    this.onRoadTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: (details) {
        if (onRoadTap == null) return;
        final size = context.size ?? Size.zero;
        final road = _hitTestRoad(details.localPosition, size);
        if (road != null) onRoadTap!(road);
      },
      child: CustomPaint(
        painter: _RoadMapPainter(snapshot: snapshot, theme: theme),
        child: const SizedBox.expand(),
      ),
    );
  }

  String? _hitTestRoad(Offset pos, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h * 0.52;
    // Rough hit areas
    if ((pos - Offset(cx, cy - h * 0.22)).distance < 60) return 'pereval';
    if ((pos - Offset(cx - w * 0.22, cy + h * 0.08)).distance < 60) return 'abaza';
    if ((pos - Offset(cx + w * 0.22, cy + h * 0.08)).distance < 60) return 'zarechka';
    return null;
  }
}

class _RoadMapPainter extends CustomPainter {
  final TrafficSnapshot snapshot;
  final ThemeDef theme;

  _RoadMapPainter({required this.snapshot, required this.theme});

  static const _roads = ['pereval', 'abaza', 'zarechka'];
  static const _roadWidth = 36.0;

  Color _lightColor(String state, String target) {
    if (state == target) {
      switch (target) {
        case 'green':  return const Color(0xFF00E676);
        case 'yellow': return const Color(0xFFFFD600);
        case 'red':    return const Color(0xFFFF1744);
      }
    }
    return Colors.black45;
  }

  Color _roadColor(String state) {
    switch (state) {
      case 'green':  return const Color(0xFF1B5E20);
      case 'yellow': return const Color(0xFFF57F17);
      case 'red':    return const Color(0xFFB71C1C);
      default:       return Colors.grey.shade800;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h * 0.52;

    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()..color = theme.bg);

    // Road angles: pereval=up, abaza=lower-left, zarechka=lower-right
    final roadAngles = {
      'pereval':  -math.pi / 2,
      'abaza':    math.pi * 0.83,
      'zarechka': math.pi * 0.17,
    };
    final roadNames = {
      'pereval':  'Перевал',
      'abaza':    'Абаза',
      'zarechka': 'Заречка',
    };

    const roadLen = 0.38;
    final len = math.min(w, h) * roadLen;

    final roadPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = _roadWidth..strokeCap = StrokeCap.butt;
    final asphaltPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = _roadWidth - 8..strokeCap = StrokeCap.butt..color = const Color(0xFF263238);
    final dashPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0x44FFFFFF)..strokeCap = StrokeCap.round;

    for (final road in _roads) {
      final angle = roadAngles[road]!;
      final rs = snapshot[road];
      final end = Offset(cx + math.cos(angle) * len, cy + math.sin(angle) * len);

      roadPaint.color = _roadColor(rs.state).withValues(alpha: 0.6);
      canvas.drawLine(Offset(cx, cy), end, roadPaint);
      canvas.drawLine(Offset(cx, cy), end, asphaltPaint);

      // Dashed center line
      _drawDashedLine(canvas, Offset(cx, cy), end, dashPaint);
    }

    // Center circle
    final centerPaint = Paint()..color = const Color(0xFF37474F);
    canvas.drawCircle(Offset(cx, cy), _roadWidth / 2 + 2, centerPaint);

    // Traffic lights and labels
    for (final road in _roads) {
      final angle = roadAngles[road]!;
      final rs = snapshot[road];
      final dist = len * 0.62;
      final lightPos = Offset(cx + math.cos(angle) * dist, cy + math.sin(angle) * dist);

      _drawTrafficLight(canvas, lightPos, rs, size);

      // Road label
      final labelDist = len + 18;
      final labelPos = Offset(cx + math.cos(angle) * labelDist, cy + math.sin(angle) * labelDist);
      _drawLabel(canvas, roadNames[road]!, labelPos, angle, rs, size);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    const dashLen = 10.0;
    const gapLen = 8.0;
    var drawn = _roadWidth / 2 + 4.0;
    while (drawn < dist - _roadWidth / 2) {
      final t1 = drawn / dist;
      final t2 = math.min((drawn + dashLen) / dist, 1.0);
      canvas.drawLine(
        Offset(start.dx + dx * t1, start.dy + dy * t1),
        Offset(start.dx + dx * t2, start.dy + dy * t2),
        paint,
      );
      drawn += dashLen + gapLen;
    }
  }

  void _drawTrafficLight(Canvas canvas, Offset pos, RoadState rs, Size size) {
    const boxW = 22.0;
    const boxH = 54.0;
    const radius = 6.0;
    const lightR = 7.0;

    // Housing
    final housing = RRect.fromRectAndRadius(
      Rect.fromCenter(center: pos, width: boxW, height: boxH),
      const Radius.circular(radius),
    );
    canvas.drawRRect(housing, Paint()..color = const Color(0xFF1A1A1A));
    canvas.drawRRect(housing, Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 1);

    // Lights: red top, yellow middle, green bottom
    final centers = [
      Offset(pos.dx, pos.dy - boxH / 2 + 10),
      Offset(pos.dx, pos.dy),
      Offset(pos.dx, pos.dy + boxH / 2 - 10),
    ];
    final states = ['red', 'yellow', 'green'];

    for (var i = 0; i < 3; i++) {
      final glow = Paint()..color = _lightColor(rs.state, states[i]);
      final hasShadow = rs.state == states[i];
      if (hasShadow) {
        canvas.drawCircle(centers[i], lightR + 4,
            Paint()..color = _lightColor(rs.state, states[i]).withValues(alpha: 0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      }
      canvas.drawCircle(centers[i], lightR, glow);
      canvas.drawCircle(centers[i], lightR,
          Paint()..color = Colors.black26..style = PaintingStyle.stroke..strokeWidth = 1);
    }

    // Timer badge
    final timerSec = rs.state == 'red' ? rs.toGreen : rs.remaining;
    if (timerSec > 0) {
      final badgePos = Offset(pos.dx + boxW / 2 + 12, pos.dy + boxH / 2 - 4);
      _drawTimerBadge(canvas, badgePos, timerSec, rs.state);
    }
  }

  void _drawTimerBadge(Canvas canvas, Offset pos, int seconds, String state) {
    const r = 14.0;
    final bgColor = _roadColor(state).withValues(alpha: 0.85);
    canvas.drawCircle(pos, r, Paint()..color = bgColor);
    canvas.drawCircle(pos, r, Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 1);

    final tp = TextPainter(
      text: TextSpan(
        text: seconds > 99 ? '99+' : '$seconds',
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawLabel(Canvas canvas, String text, Offset pos, double angle, RoadState rs, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final x = pos.dx.clamp(tp.width / 2 + 8, size.width - tp.width / 2 - 8);
    final y = pos.dy.clamp(tp.height / 2 + 8, size.height - tp.height / 2 - 8);
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  @override
  bool shouldRepaint(_RoadMapPainter old) =>
      old.snapshot != snapshot || old.theme != theme;
}
