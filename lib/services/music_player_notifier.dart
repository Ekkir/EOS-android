import 'package:flutter/material.dart';
import 'music_session_service.dart';

enum PlayMode { one, loop, shuffleLoop }

class MusicPlayerNotifier extends ChangeNotifier {
  static MusicPlayerNotifier? instance;

  MusicPlayerNotifier() {
    instance = this;
    MusicSessionService.init(
      onToggle: () => onToggle?.call(),
      onNext:   () => onNext?.call(),
      onPrev:   () => onPrev?.call(),
    );
  }

  String? _title;
  bool _isPlaying = false;
  bool _isFavorite = false;
  PlayMode _playMode = PlayMode.loop;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  String? get title      => _title;
  bool get isPlaying     => _isPlaying;
  bool get isFavorite    => _isFavorite;
  PlayMode get playMode  => _playMode;
  bool get hasTrack      => _title != null;

  double get progress {
    final d = _duration.inMilliseconds;
    if (d == 0) return 0.0;
    return (_position.inMilliseconds / d).clamp(0.0, 1.0);
  }

  VoidCallback? onToggle;
  VoidCallback? onNext;
  VoidCallback? onPrev;
  void Function(double ratio)? onSeek;

  void update({
    String? title,
    bool? isPlaying,
    VoidCallback? toggle,
    VoidCallback? next,
    VoidCallback? prev,
    void Function(double)? seek,
  }) {
    if (title != null) _title = title;
    if (isPlaying != null) _isPlaying = isPlaying;
    if (toggle != null) onToggle = toggle;
    if (next != null) onNext = next;
    if (prev != null) onPrev = prev;
    if (seek != null) onSeek = seek;
    if (_title != null) MusicSessionService.show(_title!, isPlaying: _isPlaying);
    notifyListeners();
  }

  void setPlaying(bool v) {
    if (_isPlaying == v) return;
    _isPlaying = v;
    if (_title != null) MusicSessionService.show(_title!, isPlaying: v);
    notifyListeners();
  }

  void setPosition(Duration pos, Duration dur) {
    _position = pos;
    _duration = dur;
    notifyListeners();
  }

  void setPlayMode(PlayMode mode) {
    if (_playMode == mode) return;
    _playMode = mode;
    notifyListeners();
  }

  void toggleFavorite() {
    _isFavorite = !_isFavorite;
    notifyListeners();
  }

  void clear() {
    _title = null;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    MusicSessionService.hide();
    notifyListeners();
  }
}
