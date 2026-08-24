import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

class CachedTileProvider extends TileProvider {
  final Directory cacheDir;
  static const _maxAgeDays = 7;

  CachedTileProvider({required this.cacheDir});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    final fileName = '${coordinates.z}_${coordinates.x}_${coordinates.y}.png';
    final file = File('${cacheDir.path}/$fileName');
    return _CachedTileImage(url: url, file: file, maxAgeDays: _maxAgeDays);
  }

  static void cleanOldTiles(Directory dir) {
    if (!dir.existsSync()) return;
    final cutoff = DateTime.now().subtract(const Duration(days: _maxAgeDays));
    for (final entity in dir.listSync()) {
      if (entity is File) {
        final modified = entity.statSync().modified;
        if (modified.isBefore(cutoff)) {
          try { entity.deleteSync(); } catch (_) {}
        }
      }
    }
  }
}

class _CachedTileImage extends ImageProvider<_CachedTileImage> {
  final String url;
  final File file;
  final int maxAgeDays;

  const _CachedTileImage({
    required this.url,
    required this.file,
    required this.maxAgeDays,
  });

  @override
  Future<_CachedTileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
      _CachedTileImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadBytes(key).then((bytes) =>
          ui.ImmutableBuffer.fromUint8List(bytes).then(decode)),
      scale: 1.0,
    );
  }

  Future<Uint8List> _loadBytes(_CachedTileImage key) async {
    if (file.existsSync()) {
      final age = DateTime.now().difference(file.statSync().modified);
      if (age.inDays < maxAgeDays) {
        return file.readAsBytes();
      }
    }
    final response = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'EOS-App/1.0 (com.traffic.app)'},
    );
    if (response.statusCode == 200) {
      try {
        await file.parent.create(recursive: true);
        await file.writeAsBytes(response.bodyBytes);
      } catch (_) {}
      return response.bodyBytes;
    }
    throw Exception('Tile load failed: ${response.statusCode} $url');
  }

  @override
  bool operator ==(Object other) =>
      other is _CachedTileImage && other.url == url;

  @override
  int get hashCode => url.hashCode;
}
