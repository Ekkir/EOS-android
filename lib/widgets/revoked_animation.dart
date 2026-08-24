import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../screens/approval_pending_screen.dart';

class RevokedAnimation extends StatefulWidget {
  final String status; // 'suspended' | 'rejected'
  const RevokedAnimation({super.key, required this.status});

  @override
  State<RevokedAnimation> createState() => _RevokedAnimationState();
}

class _RevokedAnimationState extends State<RevokedAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static const _totalDuration = Duration(milliseconds: 3900);

  Color get _accent => widget.status == 'suspended'
      ? const Color(0xFFFF9800)
      : const Color(0xFFFF4455);

  Color get _termBg => widget.status == 'suspended'
      ? const Color(0xFF0D0700)
      : const Color(0xFF0D0002);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _totalDuration);
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => ApprovalPendingScreen(
              revokedFrom: widget.status,
              skipRevocation: true,
              termBg: _termBg,
            ),
            transitionDuration: Duration.zero,
          ),
        );
      }
    });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Fade-in/hold/fade-out envelope
  double _fade(double t, double s0, double s1, double e0, double e1) {
    if (t <= s0) return 0;
    if (t <= s1) return (t - s0) / (s1 - s0);
    if (t <= e0) return 1;
    if (t <= e1) return 1 - (t - e0) / (e1 - e0);
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) {
        final t = _ctrl.value;

        // Phase fractions
        final overlayA = _fade(t, 0.00, 0.07, 1.0, 1.0);
        final morphT   = Curves.easeInOut.transform(_fade(t, 0.0, 0.0, 0.27, 0.27));
        final bangA    = _fade(t, 0.37, 0.48, 0.60, 0.70);
        final textA    = _fade(t, 0.63, 0.73, 0.81, 0.88);
        final expandRaw = _fade(t, 0.88, 0.88, 1.00, 1.00);
        final expandT  = Curves.easeInOut.transform(expandRaw);

        // Shape color: gray → accent (during morph), accent → termBg (during expand)
        final Color shapeColor;
        if (expandT > 0) {
          shapeColor = Color.lerp(_accent, _termBg, expandT)!;
        } else {
          shapeColor = Color.lerp(const Color(0xFF2B2B2B), _accent, morphT)!;
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // Dark background
              Opacity(
                opacity: overlayA,
                child: Container(color: const Color(0xFF060606)),
              ),
              // Morphing triangle
              CustomPaint(
                size: size,
                painter: _MorphPainter(
                  morphT: morphT,
                  expandT: expandT,
                  color: shapeColor,
                ),
              ),
              // Exclamation mark
              if (bangA > 0)
                Center(
                  child: Opacity(
                    opacity: bangA,
                    child: const Text(
                      '!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 80,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        height: 1,
                      ),
                    ),
                  ),
                ),
              // Status text
              if (textA > 0)
                Center(
                  child: Opacity(
                    opacity: textA,
                    child: Text(
                      widget.status == 'suspended'
                          ? 'KEY  SUSPENDED'
                          : 'ACCESS  REVOKED',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 5.0,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Custom painter ────────────────────────────────────────────────────────────

class _MorphPainter extends CustomPainter {
  final double morphT;
  final double expandT;
  final Color  color;

  const _MorphPainter({
    required this.morphT,
    required this.expandT,
    required this.color,
  });

  static const _triR  = 92.0;  // circumradius of triangle
  static const _triCR = 16.0;  // triangle corner radius
  static const _navH  = 74.0;  // approx navbar height
  static const _navCR = 28.0;  // navbar corner radius

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final cx = size.width  / 2;
    final cy = size.height / 2;

    // Full fill once expansion is complete
    if (expandT >= 1.0) {
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }

    // Triangle vertices (equilateral, pointing up, centered at (cx, cy))
    final triTop = Offset(cx,                               cy - _triR);
    final triBR  = Offset(cx + _triR * math.sqrt(3) / 2,   cy + _triR / 2);
    final triBL  = Offset(cx - _triR * math.sqrt(3) / 2,   cy + _triR / 2);

    // Expanding phase: scale the triangle outward
    if (expandT > 0) {
      final maxScale = size.height * 1.6 / _triR;
      final scale    = 1.0 + (maxScale - 1.0) * expandT;
      final cr       = _triCR * math.max(0.0, 1.0 - expandT * 6);
      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(scale);
      canvas.translate(-cx, -cy);
      _drawTriangle(canvas, paint, triTop, triBR, triBL, cr);
      canvas.restore();
      return;
    }

    // Fully morphed triangle (no expand yet)
    if (morphT >= 1.0) {
      _drawTriangle(canvas, paint, triTop, triBR, triBL, _triCR);
      return;
    }

    // Morph: rounded rectangle (navbar) → triangle
    final navW  = size.width - 36.0;
    final navCY = size.height - _navH / 2 - 22.0;
    final navT  = navCY - _navH / 2;
    final navB  = navCY + _navH / 2;

    // Navbar corners (raw, not arc centres)
    final rTL = Offset(cx - navW / 2, navT);
    final rTR = Offset(cx + navW / 2, navT);
    final rBR = Offset(cx + navW / 2, navB);
    final rBL = Offset(cx - navW / 2, navB);

    // Lerp: top-two corners collapse to triTop, bottom corners spread to triangle base
    final p0 = Offset.lerp(rTL, triTop, morphT)!;
    final p1 = Offset.lerp(rTR, triTop, morphT)!;
    final p2 = Offset.lerp(rBR, triBR,  morphT)!;
    final p3 = Offset.lerp(rBL, triBL,  morphT)!;
    final cr = lerpDouble(_navCR, _triCR, morphT)!;

    _drawQuad(canvas, paint, p0, p1, p2, p3, cr);
  }

  // Rounded equilateral triangle from pre-computed vertices
  void _drawTriangle(Canvas canvas, Paint paint,
      Offset top, Offset br, Offset bl, double cr) {
    final v = [top, br, bl];
    final path = Path();
    for (int i = 0; i < 3; i++) {
      final prev = v[(i + 2) % 3];
      final curr = v[i];
      final next = v[(i + 1) % 3];
      final d1 = _normTo(prev - curr, cr);
      final d2 = _normTo(next - curr, cr);
      if (i == 0) path.moveTo((curr + d1).dx, (curr + d1).dy);
      else        path.lineTo((curr + d1).dx, (curr + d1).dy);
      path.quadraticBezierTo(curr.dx, curr.dy, (curr + d2).dx, (curr + d2).dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  // 4-corner shape that degrades to triangle when p0 == p1
  void _drawQuad(Canvas canvas, Paint paint,
      Offset p0, Offset p1, Offset p2, Offset p3, double cr) {
    final pts  = [p0, p1, p2, p3];
    final path = Path();
    bool first = true;

    for (int i = 0; i < 4; i++) {
      final prev = pts[(i + 3) % 4];
      final curr = pts[i];
      final next = pts[(i + 1) % 4];

      final dIn  = curr - prev;
      final dOut = next - curr;
      final lenIn  = dIn.distance;
      final lenOut = dOut.distance;

      // Skip fully degenerate corners (no edges at all)
      if (lenIn < 0.5 && lenOut < 0.5) continue;

      final approach = math.min(cr, lenIn  * 0.5);
      final leave    = math.min(cr, lenOut * 0.5);

      final pIn  = lenIn  > 0.1 ? curr - _normTo(dIn,  approach) : curr;
      final pOut = lenOut > 0.1 ? curr + _normTo(dOut, leave)    : curr;

      if (first) { path.moveTo(pIn.dx, pIn.dy); first = false; }
      else        path.lineTo(pIn.dx, pIn.dy);

      path.quadraticBezierTo(curr.dx, curr.dy, pOut.dx, pOut.dy);
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  // Returns a vector in the direction of v with magnitude len
  Offset _normTo(Offset v, double len) {
    final d = v.distance;
    return d < 0.0001 ? Offset.zero : v * (len / d);
  }

  @override
  bool shouldRepaint(_MorphPainter old) =>
      old.morphT   != morphT   ||
      old.expandT  != expandT  ||
      old.color    != color;
}
