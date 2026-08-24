import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/music_audio_handler.dart';
import '../services/music_player_notifier.dart';
import '../services/playlists_notifier.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_surface.dart';

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  List<Map<String, dynamic>> _tracks = [];
  bool _loading = true;
  String? _error;

  int? _playingIndex;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  int _lastPosMs = 0;

  final _rng = Random();
  final Map<int, double?> _dl = {}; // null=не скачан, 0..1=прогресс, -1=готово

  MusicAudioHandler? _handler;
  MusicPlayerNotifier? _notifier;

  StreamSubscription? _stateSub;
  StreamSubscription? _posSub;
  StreamSubscription? _itemSub;
  StreamSubscription? _completeSub;
  StreamSubscription? _nextSub;
  StreamSubscription? _prevSub;

  bool _uploading = false;
  bool _settingsOpen = false;
  bool _playlistsOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notifier ??= context.read<MusicPlayerNotifier>();
    if (_handler == null) {
      _handler = context.read<MusicAudioHandler>();
      _stateSub = _handler!.stateStream.listen((state) {
        if (!mounted) return;
        final playing = state == PlayerState.playing;
        setState(() => _isPlaying = playing);
        _notifier?.setPlaying(playing);
      });
      _posSub = _handler!.positionStream.listen((pos) {
        if (!mounted) return;
        setState(() => _position = pos);
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastPosMs >= 400) {
          _lastPosMs = now;
          _notifier?.setPosition(pos, _duration);
        }
      });
      _itemSub = _handler!.durationStream.listen((dur) {
        if (!mounted) return;
        setState(() => _duration = dur);
        _notifier?.setPosition(_position, dur);
      });
      _completeSub = _handler!.completeStream.listen((_) {
        if (!mounted) return;
        _autoNext();
      });
      _nextSub = _handler!.onNextRequested.listen((_) {
        if (!mounted) return;
        _playNext();
      });
      _prevSub = _handler!.onPrevRequested.listen((_) {
        if (!mounted) return;
        _playPrev();
      });
    }
    if (_loading && _tracks.isEmpty && _error == null) _fetchTracks();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _itemSub?.cancel();
    _completeSub?.cancel();
    _nextSub?.cancel();
    _prevSub?.cancel();
    _handler?.clearItem();
    _notifier?.clear();
    super.dispose();
  }

  List<Map<String, dynamic>> _visibleTracks() {
    try {
      final pl = context.read<PlaylistsNotifier>().activePlaylist;
      if (pl != null) {
        final names = Set<String>.from(pl.filenames);
        return _tracks.where((t) => names.contains(t['filename'] as String)).toList();
      }
    } catch (_) {}
    return _tracks;
  }

  static const _cacheKey = 'music_tracks_cache';

  Future<void> _loadCache() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_cacheKey);
      if (raw != null) {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        if (mounted && list.isNotEmpty) {
          setState(() { _tracks = list; _loading = false; });
          _checkDownloaded();
        }
      }
    } catch (_) {}
  }

  Future<void> _saveCache(List<Map<String, dynamic>> tracks) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_cacheKey, jsonEncode(tracks));
    } catch (_) {}
  }

  Future<void> _fetchTracks() async {
    // Показываем кеш сразу, чтобы офлайн не был пустым экраном
    await _loadCache();
    try {
      final api = context.read<ApiService>();
      final tracks = await api.getMusicTracks();
      if (!mounted) return;
      setState(() { _tracks = tracks; _loading = false; });
      _checkDownloaded();
      _saveCache(tracks);
    } catch (e) {
      if (!mounted) return;
      // Если кеш уже загружен — не показываем ошибку, просто работаем офлайн
      if (_tracks.isNotEmpty) {
        setState(() => _loading = false);
      } else {
        setState(() { _error = 'Нет подключения'; _loading = false; });
      }
    }
  }

  Future<void> _checkDownloaded() async {
    final dir = await getApplicationDocumentsDirectory();
    final updates = <int, double?>{};
    for (var i = 0; i < _tracks.length; i++) {
      if (await File('${dir.path}/music/${_tracks[i]['filename']}').exists()) {
        updates[i] = -1.0;
      }
    }
    if (mounted && updates.isNotEmpty) setState(() => _dl.addAll(updates));
  }

  void _handleSeek(double ratio) {
    if (_duration == Duration.zero) return;
    _handler?.seek(Duration(milliseconds: (ratio * _duration.inMilliseconds).round()));
  }

  Future<void> _play(int index) async {
    if (index < 0 || index >= _tracks.length) return;
    final handler = _handler;
    if (handler == null) return;
    final notifier = _notifier ?? context.read<MusicPlayerNotifier>();
    final api = context.read<ApiService>();
    final filename = _tracks[index]['filename'] as String;
    final title    = _tracks[index]['title']    as String;
    if (!mounted) return;
    setState(() {
      _playingIndex = index;
      _isPlaying    = false;
      _position     = Duration.zero;
      _duration     = Duration.zero;
    });
    notifier.update(
      title:  title,
      isPlaying: false,
      toggle: _togglePlayPause,
      next:   _playNext,
      prev:   _playPrev,
      seek:   _handleSeek,
    );
    notifier.setPosition(Duration.zero, Duration.zero);

    // Приоритет локальному файлу — мгновенный старт без сети
    final dir = await getApplicationDocumentsDirectory();
    final localFile = File('${dir.path}/music/$filename');
    if (await localFile.exists()) {
      await handler.playTrack(filename: filename, title: title, isLocal: true, localPath: localFile.path);
    } else {
      final url = '${await api.baseUrl}/music/${Uri.encodeComponent(filename)}';
      await handler.playTrack(filename: filename, title: title, isLocal: false, remoteUrl: url);
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) { await _handler?.pause(); }
    else if (_playingIndex != null) { await _handler?.play(); }
  }

  void _playNext() {
    if (_playingIndex == null || _tracks.isEmpty) return;
    final vis = _visibleTracks();
    if (vis.isEmpty) return;
    final cur = _tracks[_playingIndex!];
    final idx = vis.indexOf(cur);
    _play(_tracks.indexOf(vis[(idx < 0 ? 0 : (idx + 1)) % vis.length]));
  }

  void _playPrev() {
    if (_playingIndex == null || _tracks.isEmpty) return;
    final vis = _visibleTracks();
    if (vis.isEmpty) return;
    final cur = _tracks[_playingIndex!];
    final idx = vis.indexOf(cur);
    _play(_tracks.indexOf(vis[(idx < 0 ? 0 : (idx - 1 + vis.length)) % vis.length]));
  }

  void _autoNext() {
    if (_playingIndex == null || _tracks.isEmpty) return;
    final vis = _visibleTracks();
    if (vis.isEmpty) return;
    final cur = _tracks[_playingIndex!];
    final vi  = vis.indexOf(cur);
    switch (_notifier?.playMode ?? PlayMode.loop) {
      case PlayMode.one:
        _play(_playingIndex!);
      case PlayMode.loop:
        _play(_tracks.indexOf(vis[(vi < 0 ? 0 : (vi + 1)) % vis.length]));
      case PlayMode.shuffleLoop:
        if (vis.length <= 1) { _play(_playingIndex!); return; }
        int n = _rng.nextInt(vis.length);
        while (n == vi) n = _rng.nextInt(vis.length);
        _play(_tracks.indexOf(vis[n]));
    }
  }

  Future<void> _download(int i) async {
    if (_dl[i] != null) return;
    final filename = _tracks[i]['filename'] as String;
    setState(() => _dl[i] = 0.0);
    try {
      final api = context.read<ApiService>();
      final url = '${await api.baseUrl}/music/${Uri.encodeComponent(filename)}';
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/music/$filename');
      await file.parent.create(recursive: true);
      final resp = await http.Client().send(http.Request('GET', Uri.parse(url)));
      final total = resp.contentLength ?? 0;
      int received = 0;
      final sink = file.openWrite();
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && mounted) setState(() => _dl[i] = received / total);
      }
      await sink.close();
      if (mounted) setState(() => _dl[i] = -1.0);
    } catch (_) {
      if (mounted) setState(() => _dl.remove(i));
    }
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: true);
    if (result == null || result.files.isEmpty || !mounted) return;

    setState(() => _uploading = true);
    try {
      final api = context.read<ApiService>();
      final base = await api.baseUrl;
      final playlists = context.read<PlaylistsNotifier>();
      final activeId = playlists.activeId;
      final added = <String>[];

      for (final pf in result.files) {
        final path = pf.path;
        if (path == null) continue;
        final req = http.MultipartRequest('POST', Uri.parse('$base/music/upload'));
        req.files.add(await http.MultipartFile.fromPath('file', path));
        final resp = await req.send();
        if (resp.statusCode == 200) {
          try {
            final body = await resp.stream.bytesToString();
            final fn = (jsonDecode(body) as Map<String, dynamic>)['filename'] as String?;
            if (fn != null) added.add(fn);
          } catch (_) {}
        }
      }

      if (activeId != null && added.isNotEmpty && mounted) {
        await context.read<PlaylistsNotifier>().addTracks(activeId, added);
      }

      if (mounted) setState(() { _tracks = []; _loading = true; _error = null; });
      await _fetchTracks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _createPlaylistDialog(ThemeDef t, Color a) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.nav,
        title: Text('Новый плейлист', style: TextStyle(color: t.textPrimary)),
        content: TextField(
          controller: ctrl, autofocus: true,
          style: TextStyle(color: t.textPrimary),
          decoration: InputDecoration(
            hintText: 'Название...', hintStyle: TextStyle(color: t.textSecondary)),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text('Отмена', style: TextStyle(color: t.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: Text('Создать', style: TextStyle(color: a))),
        ],
      ),
    );
    ctrl.dispose();
    if (name != null && name.isNotEmpty && mounted) {
      context.read<PlaylistsNotifier>().createPlaylist(name);
    }
  }

  Future<void> _confirmDeletePlaylist(MusicPlaylist pl, ThemeDef t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.nav,
        title: Text('Удалить плейлист?', style: TextStyle(color: t.textPrimary)),
        content: Text('«${pl.name}» будет удалён', style: TextStyle(color: t.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Отмена', style: TextStyle(color: t.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok == true && mounted) context.read<PlaylistsNotifier>().deletePlaylist(pl.id);
  }

  // ── Маленькая пилюля-кнопка ────────────────────────────────────────────────
  Widget _buildMiniPill({
    required String label, required IconData icon,
    required bool active, required VoidCallback onTap,
    required ThemeDef t, required Color a,
  }) {
    final isGlass = t.isLiquidGlass || t.glassy;
    final content = Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: active ? a : t.textSecondary, size: 15),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(
        color: active ? a : t.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
    ]);

    if (isGlass) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0.10)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active ? a.withValues(alpha: 0.60) : Colors.white.withValues(alpha: 0.30),
                    width: active ? 1.2 : 0.8,
                  ),
                ),
                child: Center(child: content),
              ),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: t.nav.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? a.withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.18),
            width: active ? 1.2 : 0.8,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Center(child: content),
      ),
    );
  }

  // ── Панель плейлистов ──────────────────────────────────────────────────────
  Widget _buildPlaylistPanel(PlaylistsNotifier playlists, ThemeDef t, Color a) {
    final isGlass = t.isLiquidGlass || t.glassy;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        _playlistItem(
          label: 'Все треки', icon: Icons.music_note,
          selected: playlists.activeId == null,
          onTap: () => context.read<PlaylistsNotifier>().setActive(null),
          t: t, a: a,
        ),
        for (final pl in playlists.playlists)
          _playlistItem(
            label: pl.name, icon: Icons.playlist_play,
            selected: playlists.activeId == pl.id,
            onTap: () => context.read<PlaylistsNotifier>().setActive(pl.id),
            onLongPress: () => _confirmDeletePlaylist(pl, t),
            t: t, a: a,
          ),
        Divider(height: 1, color: Colors.white.withValues(alpha: 0.12), indent: 12, endIndent: 12),
        InkWell(
          onTap: () => _createPlaylistDialog(t, a),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Icon(Icons.add_circle_outline, color: a, size: 16),
              const SizedBox(width: 10),
              Text('Создать плейлист',
                  style: TextStyle(color: a, fontSize: 12, fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
      ],
    );

    if (isGlass) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Container(
          width: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Colors.white.withValues(alpha: 0.20), Colors.white.withValues(alpha: 0.09)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.28), width: 0.8),
                ),
                child: body,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: t.nav.withValues(alpha: 0.93),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 0.8),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: body,
      ),
    );
  }

  Widget _playlistItem({
    required String label, required IconData icon,
    required bool selected, required VoidCallback onTap,
    required ThemeDef t, required Color a, VoidCallback? onLongPress,
  }) {
    return InkWell(
      onTap: onTap, onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Icon(icon, color: selected ? a : t.textSecondary, size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(label,
            style: TextStyle(color: selected ? a : t.textPrimary, fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal),
            overflow: TextOverflow.ellipsis)),
          if (selected) Icon(Icons.check, color: a, size: 14),
        ]),
      ),
    );
  }

  // ── Суб-кнопка настроек ───────────────────────────────────────────────────
  Widget _buildSubBtn({
    required String label, required IconData icon,
    required bool uploading, required VoidCallback? onTap,
    required ThemeDef t, required Color a,
  }) {
    final isGlass = t.isLiquidGlass || t.glassy;
    final content = Row(mainAxisSize: MainAxisSize.min, children: [
      uploading
          ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: a))
          : Icon(icon, color: a, size: 15),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(color: t.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
    ]);

    if (isGlass) {
      return GestureDetector(
        onTap: uploading ? null : onTap,
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0.10)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.28), width: 0.8),
                ),
                child: Center(child: content),
              ),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: uploading ? null : onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: t.nav.withValues(alpha: 0.93),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 0.8),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Center(child: content),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeN = context.watch<AppThemeNotifier>();
    final t = themeN.current;
    final a = themeN.accent;
    final playlists = context.watch<PlaylistsNotifier>();
    final safeBottom = MediaQuery.of(context).padding.bottom;

    // Фильтрация по плейлисту
    final activePl = playlists.activePlaylist;
    final visible = activePl != null
        ? _tracks.where((tr) => Set<String>.from(activePl.filenames).contains(tr['filename'] as String)).toList()
        : _tracks;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.nav,
        title: Text('Музыка', style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: GlassBg(
        child: Stack(
          children: [
            // ── Список треков ───────────────────────────────────────────────
            if (_loading)
              Center(child: CircularProgressIndicator(color: a))
            else if (_error != null)
              Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_error!, style: TextStyle(color: t.textSecondary), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () { setState(() { _error = null; _loading = true; }); _fetchTracks(); },
                  child: Text('Повторить', style: TextStyle(color: a))),
              ]))
            else
              ListView.builder(
                padding: EdgeInsets.fromLTRB(12, 52, 12, 80 + safeBottom),
                itemCount: visible.length,
                itemBuilder: (_, vi) {
                  final track   = visible[vi];
                  final title   = track['title'] as String;
                  final fi      = _tracks.indexOf(track);
                  final active  = _playingIndex == fi;
                  final dlState = _dl[fi];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      onTap: () => _play(fi),
                      child: Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(shape: BoxShape.circle,
                              color: a.withValues(alpha: active ? 0.20 : 0.08)),
                          child: Icon(active && _isPlaying ? Icons.pause : Icons.play_arrow,
                              color: active ? a : t.textSecondary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(title,
                          style: TextStyle(color: active ? a : t.textPrimary,
                              fontWeight: active ? FontWeight.w600 : FontWeight.normal, fontSize: 14),
                          overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 4),
                        SizedBox(width: 36, height: 36,
                          child: dlState == null
                              ? IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: Icon(Icons.download_outlined, size: 18, color: t.textSecondary),
                                  onPressed: () => _download(fi))
                              : dlState < 0
                                  ? const Icon(Icons.check_circle_outline, size: 18, color: Colors.green)
                                  : Padding(padding: const EdgeInsets.all(8),
                                      child: CircularProgressIndicator(value: dlState, strokeWidth: 2, color: a))),
                      ]),
                    ),
                  );
                },
              ),

            // ── Плейлисты (слева) ──────────────────────────────────────────
            Positioned(
              top: 6, left: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMiniPill(
                    label: 'Плейлисты', icon: Icons.queue_music,
                    active: _playlistsOpen || playlists.activeId != null,
                    onTap: () => setState(() {
                      _playlistsOpen = !_playlistsOpen;
                      if (_playlistsOpen) _settingsOpen = false;
                    }),
                    t: t, a: a,
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 210),
                    curve: Curves.easeOutCubic,
                    child: _playlistsOpen ? _buildPlaylistPanel(playlists, t, a) : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            // ── Настройки (справа) ─────────────────────────────────────────
            Positioned(
              top: 6, right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMiniPill(
                    label: 'Настройки', icon: Icons.settings_outlined,
                    active: _settingsOpen,
                    onTap: () => setState(() {
                      _settingsOpen = !_settingsOpen;
                      if (_settingsOpen) _playlistsOpen = false;
                    }),
                    t: t, a: a,
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 210),
                    curve: Curves.easeOutCubic,
                    child: _settingsOpen
                        ? Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: _buildSubBtn(
                              label: 'Загрузить трек', icon: Icons.upload_file,
                              uploading: _uploading,
                              onTap: () { setState(() => _settingsOpen = false); _pickAndUpload(); },
                              t: t, a: a,
                            ),
                          )
                        : const SizedBox.shrink(),
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
