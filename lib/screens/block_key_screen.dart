import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'approval_pending_screen.dart';

class BlockKeyScreen extends StatefulWidget {
  final String status; // 'rejected' | 'suspended'

  const BlockKeyScreen({super.key, required this.status});

  String get _asset => status == 'rejected'
      ? 'assets/block_key.mp4'
      : 'assets/stop_key.mp4';

  @override
  State<BlockKeyScreen> createState() => _BlockKeyScreenState();
}

class _BlockKeyScreenState extends State<BlockKeyScreen> {
  late VideoPlayerController _ctrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // Убираем статус-бар для полного погружения
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _ctrl = VideoPlayerController.asset(widget._asset);
    _ctrl.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _ctrl.setLooping(false);
      _ctrl.play();
    }).catchError((_) => _goToTerminal());

    _ctrl.addListener(_checkEnd);

    // Страховочный таймаут — если видео не запустилось за 4 сек
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && !_ready) _goToTerminal();
    });
  }

  void _checkEnd() {
    if (!mounted) return;
    final v = _ctrl.value;
    if (v.duration > Duration.zero &&
        v.position >= v.duration - const Duration(milliseconds: 200)) {
      _ctrl.removeListener(_checkEnd);
      _goToTerminal();
    }
  }

  void _goToTerminal() {
    if (!mounted) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ApprovalPendingScreen(
          revokedFrom: widget.status,
        ),
        transitionDuration: Duration.zero,
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.removeListener(_checkEnd);
    _ctrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // блокируем кнопку назад
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _ready
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
      ),
    );
  }
}
