import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VideoCircleRecorder extends StatefulWidget {
  const VideoCircleRecorder({super.key});

  @override
  State<VideoCircleRecorder> createState() => _VideoCircleRecorderState();
}

class _VideoCircleRecorderState extends State<VideoCircleRecorder>
    with SingleTickerProviderStateMixin {
  CameraController? _ctrl;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  bool _initialized = false;
  bool _recording = false;
  bool _switching = false;

  late final AnimationController _gradientAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _gradientAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _initCamera();
  }

  Future<void> _initCamera({int? index}) async {
    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
        if (_cameras.isEmpty) return;
        final frontIdx = _cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
        _cameraIndex = frontIdx >= 0 ? frontIdx : 0;
      } else {
        _cameraIndex = index ?? _cameraIndex;
      }

      await _ctrl?.dispose();
      final ctrl = CameraController(
        _cameras[_cameraIndex],
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await ctrl.initialize();
      if (mounted) {
        setState(() {
          _ctrl = ctrl;
          _initialized = true;
          _switching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _switching || _recording) return;
    setState(() {
      _initialized = false;
      _switching = true;
    });
    await _initCamera(index: (_cameraIndex + 1) % _cameras.length);
  }

  Future<void> _startRecording() async {
    if (_ctrl == null || !_initialized || _recording) return;
    try {
      await _ctrl!.startVideoRecording();
      if (mounted) setState(() => _recording = true);
      Future.delayed(const Duration(seconds: 60), () {
        if (mounted && _recording) _stopRecording();
      });
    } catch (_) {}
  }

  Future<void> _stopRecording() async {
    if (_ctrl == null || !_recording) return;
    try {
      final file = await _ctrl!.stopVideoRecording();
      if (mounted) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        Navigator.pop(context, file.path);
      }
    } catch (_) {
      if (mounted) setState(() => _recording = false);
    }
  }

  @override
  void dispose() {
    _gradientAnim.dispose();
    _ctrl?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final circleSize = screenWidth * 0.82;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(
                _recording ? '● Запись...' : 'Видео-кружок',
                style: TextStyle(
                  color: _recording ? Colors.redAccent : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                if (!_recording && _cameras.length > 1)
                  IconButton(
                    icon: const Icon(Icons.flip_camera_android, color: Colors.white),
                    tooltip: 'Сменить камеру',
                    onPressed: _switching ? null : _flipCamera,
                  ),
              ],
            ),
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _gradientAnim,
                  builder: (ctx, cameraChild) {
                    final angle = _gradientAnim.value * 2 * pi;
                    return Container(
                      width: circleSize + 6,
                      height: circleSize + 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: const [
                            Color(0xFF7B2FF7),
                            Color(0xFF2979FF),
                            Color(0xFF00E5FF),
                            Color(0xFF00E676),
                            Color(0xFFFF4081),
                            Color(0xFF7B2FF7),
                          ],
                          transform: GradientRotation(angle),
                        ),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: cameraChild,
                    );
                  },
                  child: ClipOval(
                    child: SizedBox(
                      width: circleSize,
                      height: circleSize,
                      child: _initialized && _ctrl != null
                          ? Builder(builder: (ctx) {
                              final size = _ctrl!.value.previewSize;
                              final w = size?.height ?? circleSize;
                              final h = size?.width ?? circleSize;
                              return FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: w,
                                  height: h,
                                  child: CameraPreview(_ctrl!),
                                ),
                              );
                            })
                          : Container(
                              color: Colors.black87,
                              child: const Center(
                                child: CircularProgressIndicator(color: Colors.white70),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 48, top: 24),
              child: GestureDetector(
                onLongPressStart: (_) => _startRecording(),
                onLongPressEnd: (_) => _stopRecording(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _recording ? Colors.redAccent : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _recording ? Colors.red.shade900 : Colors.white70,
                      width: 3,
                    ),
                    boxShadow: _recording
                        ? [const BoxShadow(color: Colors.redAccent, blurRadius: 16)]
                        : [],
                  ),
                  child: Icon(
                    _recording ? Icons.stop_rounded : Icons.videocam_rounded,
                    color: _recording ? Colors.white : Colors.black,
                    size: 34,
                  ),
                ),
              ),
            ),
            if (!_recording)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Зажмите для записи',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
