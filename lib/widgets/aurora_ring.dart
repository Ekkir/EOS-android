import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/prefs_service.dart';

const Color _auroraGreen = Color(0xFF00FF88);

class AuroraRing extends StatefulWidget {
  final Widget child;
  final double ringPadding;
  final double innerPadding;
  final double speed; // rotation speed multiplier, default 1.0

  const AuroraRing({
    super.key,
    required this.child,
    this.ringPadding = 4.0,
    this.innerPadding = 3.0,
    this.speed = 1.0,
  });

  @override
  State<AuroraRing> createState() => _AuroraRingState();
}

class _AuroraRingState extends State<AuroraRing> with TickerProviderStateMixin {
  late AnimationController _rotCtrl;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _rotCtrl = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: (4000 / widget.speed).round()))
      ..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(AuroraRing old) {
    super.didUpdateWidget(old);
    if (old.speed != widget.speed) {
      _rotCtrl.duration = Duration(milliseconds: (4000 / widget.speed).round());
      if (_rotCtrl.isAnimating) _rotCtrl.repeat();
    }
  }

  @override
  void dispose() {
    _rotCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.read<PrefsService>();
    final color1 = prefs.ringColor1;
    final color2 = prefs.ringColor2;

    return AnimatedBuilder(
      animation: Listenable.merge([_rotCtrl, _pulseCtrl]),
      builder: (_, child) {
        final p = _pulseCtrl.value;
        final opacity = 0.55 + 0.45 * p;
        final spread = widget.ringPadding * 0.5 + 4.0 * p;

        return Container(
          padding: EdgeInsets.all(widget.ringPadding),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              transform: GradientRotation(_rotCtrl.value * 2 * pi),
              colors: [color1, _auroraGreen, color2, _auroraGreen, color1],
              stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: _auroraGreen.withValues(alpha: opacity * 0.75),
                blurRadius: 10,
                spreadRadius: spread,
              ),
              BoxShadow(
                color: color1.withValues(alpha: opacity * 0.5),
                blurRadius: 20,
                spreadRadius: spread * 0.6,
              ),
              BoxShadow(
                color: color2.withValues(alpha: opacity * 0.3),
                blurRadius: 35,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Container(
            padding: EdgeInsets.all(widget.innerPadding),
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
