import 'dart:math';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import '../services/update_service.dart';

class UpdateLoadingScreen extends StatefulWidget {
  final String apkPath;
  const UpdateLoadingScreen({super.key, required this.apkPath});

  @override
  State<UpdateLoadingScreen> createState() => _UpdateLoadingScreenState();
}

class _UpdateLoadingScreenState extends State<UpdateLoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _shimmerCtrl;
  late Animation<double> _shimmerAnim;
  late AnimationController _rotateCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);
    _shimmerAnim = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );

    _rotateCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 9))
          ..repeat();

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.88, end: 1.12).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _startInstall();
  }

  Future<void> _startInstall() async {
    final ok = await UpdateService.installApk(widget.apkPath);
    if (!ok && mounted) {
      await OpenFile.open(widget.apkPath,
          type: 'application/vnd.android.package-archive');
    }
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _rotateCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF15151A),
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // Glow blob behind logo
            Positioned.fill(
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, child) => Transform.scale(
                    scale: _pulseAnim.value,
                    child: child,
                  ),
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color(0x556B4FBB),
                          Color(0x259B59D0),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Rotating ring
            Positioned.fill(
              child: Center(
                child: AnimatedBuilder(
                  animation: _rotateCtrl,
                  builder: (_, child) => Transform.rotate(
                    angle: _rotateCtrl.value * 2 * pi,
                    child: child,
                  ),
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0xFFAA80FF).withValues(alpha: 0.35),
                          const Color(0xFF80CCFF).withValues(alpha: 0.35),
                          const Color(0xFFFF80AA).withValues(alpha: 0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Second counter-rotating ring
            Positioned.fill(
              child: Center(
                child: AnimatedBuilder(
                  animation: _rotateCtrl,
                  builder: (_, child) => Transform.rotate(
                    angle: -_rotateCtrl.value * 2 * pi * 0.7,
                    child: child,
                  ),
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0xFFFF80AA).withValues(alpha: 0.25),
                          const Color(0xFF80FFCC).withValues(alpha: 0.25),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // EOS iridescent text
                  AnimatedBuilder(
                    animation: _shimmerAnim,
                    builder: (_, child) => ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        begin: Alignment(_shimmerAnim.value - 1.0, -0.4),
                        end: Alignment(_shimmerAnim.value + 1.0, 0.4),
                        colors: const [
                          Color(0xFF6B4FBB),
                          Color(0xFFEC4899),
                          Color(0xFF06B6D4),
                          Color(0xFFFFFFFF),
                          Color(0xFF8B5CF6),
                          Color(0xFFEC4899),
                          Color(0xFF6B4FBB),
                        ],
                        stops: [0.0, 0.18, 0.36, 0.5, 0.65, 0.82, 1.0],
                      ).createShader(bounds),
                      child: child,
                    ),
                    child: const Text(
                      'EOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 100,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 10,
                        height: 1,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Subtitle
                  Text(
                    'Установка обновления...',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 15,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w300,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Dot loader
                  AnimatedBuilder(
                    animation: _shimmerCtrl,
                    builder: (_, __) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          final phase = (_shimmerCtrl.value + i / 3) % 1.0;
                          final opacity = sin(phase * pi).clamp(0.15, 1.0);
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF8B5CF6)
                                  .withValues(alpha: opacity),
                            ),
                          );
                        }),
                      );
                    },
                  ),

                  const SizedBox(height: 52),

                  Text(
                    'Нажмите чтобы вернуться',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.2),
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
