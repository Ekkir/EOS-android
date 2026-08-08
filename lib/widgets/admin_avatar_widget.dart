import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/prefs_service.dart';
import 'circular_avatar.dart';
import 'aurora_ring.dart';
import 'glitch_wrapper.dart';
import 'pixel_disintegration_wrapper.dart';

/// Centralized admin avatar widget that reacts to effect changes from PrefsService.
/// Pass [isAdminAvatar] = true when displaying the admin's avatar to apply the effect.
/// Pass [effectOverride] to use a specific effect (e.g. fetched from server profile).
class AdminAvatarWidget extends StatelessWidget {
  final Uint8List? bytes;
  final String name;
  final double radius;
  final bool isAdminAvatar;
  final String? effectOverride;

  const AdminAvatarWidget({
    super.key,
    this.bytes,
    required this.name,
    this.radius = 16,
    this.isAdminAvatar = false,
    this.effectOverride,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = CircularAvatar(bytes: bytes, name: name, radius: radius);
    if (!isAdminAvatar) return avatar;

    final prefs = context.watch<PrefsService>();
    final effect = effectOverride ?? prefs.adminEffect;
    return switch (effect) {
      'glitch'         => GlitchWrapper(
          intensity: prefs.glitchIntensity,
          speed: prefs.glitchSpeed,
          frequency: prefs.glitchFrequency,
          child: avatar),
      'none'           => avatar,
      'disintegration' => PixelDisintegrationWrapper(
          speed: prefs.disintSpeed,
          child: avatar),
      _                => AuroraRing(
          ringPadding: 2,
          innerPadding: 2,
          speed: prefs.auroraSpeed,
          child: avatar),
    };
  }
}
