import 'package:flutter/foundation.dart';

class DownloadState extends ChangeNotifier {
  bool isDownloading = false;
  bool isInstallReady = false;
  double progress = 0.0;
  double speedMbps = 0.0;
  String? completedPath;

  DateTime? _lastTs;
  int _lastReceived = 0;

  void startDownload() {
    isDownloading = true;
    isInstallReady = false;
    progress = 0;
    speedMbps = 0;
    completedPath = null;
    _lastTs = null;
    _lastReceived = 0;
    notifyListeners();
  }

  void onProgress(double p, int received, int total) {
    final now = DateTime.now();
    if (_lastTs != null) {
      final ms = now.difference(_lastTs!).inMilliseconds;
      if (ms >= 300) {
        final deltaBytes = received - _lastReceived;
        speedMbps = deltaBytes / ms * 1000 / (1024 * 1024);
        _lastTs = now;
        _lastReceived = received;
      }
    } else {
      _lastTs = now;
      _lastReceived = received;
    }
    progress = p;
    notifyListeners();
  }

  void complete(String? path) {
    isDownloading = false;
    completedPath = path;
    isInstallReady = path != null;
    progress = 0;
    speedMbps = 0;
    notifyListeners();
  }

  void clearInstall() {
    isInstallReady = false;
    completedPath = null;
    notifyListeners();
  }
}
