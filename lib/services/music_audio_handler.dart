import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';

class MusicAudioHandler {
  final _player = AudioPlayer();

  final _nextCtrl = StreamController<void>.broadcast();
  final _prevCtrl = StreamController<void>.broadcast();

  Stream<PlayerState> get stateStream     => _player.onPlayerStateChanged;
  Stream<Duration>    get positionStream  => _player.onPositionChanged;
  Stream<Duration>    get durationStream  => _player.onDurationChanged;
  Stream<void>        get completeStream  => _player.onPlayerComplete.map((_) {});
  Stream<void>        get onNextRequested => _nextCtrl.stream;
  Stream<void>        get onPrevRequested => _prevCtrl.stream;

  Future<void> playTrack({
    required String filename,
    required String title,
    bool isLocal = false,
    String? localPath,
    String? remoteUrl,
  }) async {
    await _player.stop();
    if (isLocal && localPath != null) {
      await _player.play(DeviceFileSource(localPath));
    } else if (remoteUrl != null) {
      await _player.play(UrlSource(remoteUrl));
    }
  }

  Future<void> play()                 => _player.resume();
  Future<void> pause()                => _player.pause();
  Future<void> seek(Duration pos)     => _player.seek(pos);
  Future<void> skipToNext()   async   => _nextCtrl.add(null);
  Future<void> skipToPrevious() async => _prevCtrl.add(null);

  Future<void> stop() async {
    await _player.stop();
  }

  void clearItem() {}

  void dispose() {
    _nextCtrl.close();
    _prevCtrl.close();
    _player.dispose();
  }
}
