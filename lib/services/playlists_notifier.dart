import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MusicPlaylist {
  final String id;
  String name;
  List<String> filenames;

  MusicPlaylist({required this.id, required this.name, List<String>? filenames})
      : filenames = filenames ?? [];

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'filenames': filenames};

  factory MusicPlaylist.fromJson(Map<String, dynamic> j) => MusicPlaylist(
        id: j['id'] as String,
        name: j['name'] as String,
        filenames: (j['filenames'] as List).cast<String>());
}

class PlaylistsNotifier extends ChangeNotifier {
  static const _key = 'music_playlists_v1';
  static const _activeKey = 'music_active_playlist';

  List<MusicPlaylist> _playlists = [];
  String? _activeId;

  List<MusicPlaylist> get playlists => List.unmodifiable(_playlists);
  String? get activeId => _activeId;

  MusicPlaylist? get activePlaylist =>
      _activeId == null ? null : _playlists.where((p) => p.id == _activeId).firstOrNull;

  Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _playlists = list
            .map((e) => MusicPlaylist.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    _activeId = sp.getString(_activeKey);
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
        _key, jsonEncode(_playlists.map((p) => p.toJson()).toList()));
    if (_activeId != null) {
      await sp.setString(_activeKey, _activeId!);
    } else {
      await sp.remove(_activeKey);
    }
  }

  void setActive(String? id) {
    _activeId = id;
    _save();
    notifyListeners();
  }

  Future<void> createPlaylist(String name) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _playlists.add(MusicPlaylist(id: id, name: name));
    _activeId = id;
    await _save();
    notifyListeners();
  }

  Future<void> addTracks(String playlistId, List<String> filenames) async {
    final pl = _playlists.where((p) => p.id == playlistId).firstOrNull;
    if (pl == null) return;
    for (final f in filenames) {
      if (!pl.filenames.contains(f)) pl.filenames.add(f);
    }
    await _save();
    notifyListeners();
  }

  Future<void> deletePlaylist(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    if (_activeId == id) _activeId = null;
    await _save();
    notifyListeners();
  }
}
