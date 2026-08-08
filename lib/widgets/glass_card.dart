import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 16,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final notifier = Provider.of<AppThemeNotifier>(context);
    final t = notifier.current;

    Widget content;

    if (t.isLiquidGlass || t.glassy) {
      final blur = notifier.glassBlur;
      content = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      );
    } else if (t.neonGlow) {
      final gi = notifier.glowIntensity;
      content = Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: notifier.accent2.withValues(alpha: 0.55), width: 1),
        ),
        padding: padding ?? const EdgeInsets.all(16),
        child: Builder(builder: (ctx) {
          final textColor = DefaultTextStyle.of(ctx).style.color ?? Colors.white;
          return DefaultTextStyle.merge(
            style: TextStyle(
              shadows: [
                Shadow(color: textColor.withValues(alpha: (0.25 * gi).clamp(0, 1)), blurRadius: 36),
                Shadow(color: textColor.withValues(alpha: (0.50 * gi).clamp(0, 1)), blurRadius: 14),
                Shadow(color: textColor.withValues(alpha: (0.75 * gi).clamp(0, 1)), blurRadius: 5),
                Shadow(color: textColor.withValues(alpha: (1.00 * gi).clamp(0, 1)), blurRadius: 2),
              ],
            ),
            child: child,
          );
        }),
      );
    } else if (t.cyberpunk) {
      final a  = notifier.accent;
      final a2 = notifier.accent2;
      content = Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: a.withValues(alpha: 0.55), width: 1),
          boxShadow: [
            BoxShadow(color: a.withValues(alpha: 0.18), blurRadius: 12),
            BoxShadow(color: a2.withValues(alpha: 0.10), blurRadius: 22),
          ],
        ),
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      );
    } else {
      content = Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: t.cardBorder, width: 1),
        ),
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      );
    }

    if (onTap != null || onLongPress != null) {
      return GestureDetector(onTap: onTap, onLongPress: onLongPress, child: content);
    }
    return content;
  }
}
