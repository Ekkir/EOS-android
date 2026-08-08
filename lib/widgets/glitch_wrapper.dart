import 'dart:math';
import 'package:flutter/material.dart';

class GlitchWrapper extends StatefulWidget {
  final Widget child;
  final double intensity;  // 0.0–1.0
  final double speed;
  final double frequency;
  final bool chromatic;    // RGB chromatic aberration on glitch

  const GlitchWrapper({
    super.key,
    required this.child,
    this.intensity = 0.5,
    this.speed = 1.0,
    this.frequency = 1.0,
    this.chromatic = false,
  });

  @override
  State<GlitchWrapper> createState() => _GlitchWrapperState();
}

class _GlitchWrapperState extends State<GlitchWrapper> {
  static final _rng = Random();
  Offset _offset = Offset.zero;
  bool _colorShift = false;

  @override
  void initState() {
    super.initState();
    _scheduleGlitch();
  }

  void _scheduleGlitch() {
    final baseDelay = 2000 + _rng.nextInt(4000);
    final delay = (baseDelay / widget.frequency).round().clamp(300, 10000);
    Future.delayed(Duration(milliseconds: delay), _runGlitch);
  }

  Future<void> _runGlitch() async {
    if (!mounted) return;
    final maxShift = 6.0 * widget.intensity;
    final frameDuration = Duration(milliseconds: (50 / widget.speed).round().clamp(15, 300));
    for (int i = 0; i < 4; i++) {
      if (!mounted) return;
      setState(() {
        _offset = Offset(
          _rng.nextDouble() * maxShift * 2 - maxShift,
          _rng.nextDouble() * maxShift - maxShift / 2,
        );
        _colorShift = i.isEven;
      });
      await Future.delayed(frameDuration);
    }
    if (mounted) {
      setState(() { _offset = Offset.zero; _colorShift = false; });
      _scheduleGlitch();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chromatic && _colorShift) {
      final shift = 3.5 * widget.intensity;
      return Transform.translate(
        offset: _offset,
        child: Stack(
          children: [
            // Cyan (G+B) shifted left
            Transform.translate(
              offset: Offset(-shift, 0),
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  0, 0, 0, 0, 0,
                  0, 1, 0, 0, 0,
                  0, 0, 1, 0, 0,
                  0, 0, 0, 0.65, 0,
                ]),
                child: widget.child,
              ),
            ),
            // Red shifted right
            Transform.translate(
              offset: Offset(shift, 0),
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  1, 0, 0, 0, 0,
                  0, 0, 0, 0, 0,
                  0, 0, 0, 0, 0,
                  0, 0, 0, 0.65, 0,
                ]),
                child: widget.child,
              ),
            ),
            // Normal center
            widget.child,
          ],
        ),
      );
    }

    Widget child = widget.child;
    if (_colorShift) {
      child = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          1.3, 0,   0,   0, 20,
          0,   1.0, 0,   0, -10,
          0,   0,   1.2, 0, 0,
          0,   0,   0,   1, 0,
        ]),
        child: child,
      );
    }
    return Transform.translate(offset: _offset, child: child);
  }
}
