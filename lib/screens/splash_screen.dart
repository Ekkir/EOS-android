import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../services/prefs_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _ctrl;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _ctrl = VideoPlayerController.asset(
      'assets/splash.mp4',
      // mixWithOthers: true — не перехватывает аудиофокус, музыка не прерывается
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )
      ..setLooping(false)
      ..setVolume(0)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);
        _ctrl.play();
      });

    _ctrl.addListener(_onVideoUpdate);
  }

  void _onVideoUpdate() {
    if (!mounted) return;
    final pos = _ctrl.value.position;
    final dur = _ctrl.value.duration;
    if (dur > Duration.zero && pos >= dur - const Duration(milliseconds: 100)) {
      _goHome();
    }
  }

  void _goHome() {
    _ctrl.removeListener(_onVideoUpdate);
    if (!mounted) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    final prefs = context.read<PrefsService>();
    final isSignedIn = prefs.googleEmail.isNotEmpty;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => isSignedIn ? const HomeScreen() : const LoginScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onVideoUpdate);
    _ctrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _initialized
          ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _ctrl.value.size.width,
                  height: _ctrl.value.size.height,
                  child: VideoPlayer(_ctrl),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
