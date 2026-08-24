import 'package:flutter/services.dart';

class MusicSessionService {
  static const _ch = MethodChannel('com.traffic.app/music_session');
  static bool _ready = false;

  static void init({
    required void Function() onToggle,
    required void Function() onNext,
    required void Function() onPrev,
  }) {
    if (_ready) return;
    _ready = true;
    _ch.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onToggle': onToggle(); break;
        case 'onNext':   onNext();   break;
        case 'onPrev':   onPrev();   break;
      }
    });
  }

  static Future<void> show(String title, {required bool isPlaying}) async {
    try {
      await _ch.invokeMethod('show', {'title': title, 'playing': isPlaying});
    } catch (e) {
      // ignore: avoid_print
      print('[MusicSession] show error: $e');
    }
  }

  static Future<void> hide() async {
    try { await _ch.invokeMethod('hide'); } catch (_) {}
  }
}
