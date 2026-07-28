import 'dart:typed_data';
import 'package:flutter/material.dart';

class CircularAvatar extends StatelessWidget {
  final String name;
  final Uint8List? bytes;
  final double radius;
  final Color? accentColor;

  const CircularAvatar({
    super.key,
    required this.name,
    this.bytes,
    this.radius = 23,
    this.accentColor,
  });

  static const _palette = [
    Color(0xFFFF6B6B), Color(0xFF4ECDC4), Color(0xFF45B7D1),
    Color(0xFF96CEB4), Color(0xFFDDA0DD), Color(0xFFF7B731), Color(0xFF20BF6B),
  ];

  Color get _color {
    if (accentColor != null) return accentColor!;
    final idx = name.isEmpty ? 0 : name.codeUnits.reduce((a, b) => a + b) % _palette.length;
    return _palette[idx];
  }

  String get _initial => name.isNotEmpty ? name[0].toUpperCase() : '?';

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    return SizedBox(
      width: size, height: size,
      child: ClipOval(
        child: bytes != null
            ? Image.memory(bytes!, width: size, height: size, fit: BoxFit.cover)
            : Container(
                color: _color,
                alignment: Alignment.center,
                child: Text(
                  _initial,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.44,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
      ),
    );
  }
}
