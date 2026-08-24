import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_surface.dart';

class CarScreen extends StatelessWidget {
  const CarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AppThemeNotifier>();
    final t = notifier.current;
    final a = notifier.accent;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: (t.isLiquidGlass || t.glassy)
          ? PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: AppBar(
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    title: Text('Машина',
                        style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
                    iconTheme: IconThemeData(color: t.textPrimary),
                  ),
                ),
              ),
            )
          : AppBar(
              backgroundColor: t.nav,
              title: Text('Машина',
                  style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
              iconTheme: IconThemeData(color: t.textPrimary),
            ),
      body: GlassBg(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: a.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.directions_car_outlined, color: a, size: 44),
              ),
              const SizedBox(height: 20),
              Text('Раздел в разработке',
                  style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Управление транспортом — скоро',
                  style: TextStyle(color: t.textSecondary, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
