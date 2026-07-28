import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class ThemesScreen extends StatelessWidget {
  const ThemesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifier = Provider.of<AppThemeNotifier>(context);
    final t = notifier.current;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.nav,
        title: Text('Темы', style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Тема оформления',
            style: TextStyle(color: t.textSecondary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 10),
          ...AppThemeNotifier.themes.map((theme) {
            final isSelected = t.id == theme.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                onTap: () => notifier.apply(theme.id),
                child: Row(
                  children: [
                    // Mini preview
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: theme.bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.cardBorder.withValues(alpha: 0.5), width: 1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(width: 30, height: 4,
                            decoration: BoxDecoration(color: theme.accent, borderRadius: BorderRadius.circular(2))),
                          const SizedBox(height: 4),
                          Container(width: 30, height: 4,
                            decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(2))),
                          const SizedBox(height: 4),
                          Container(width: 20, height: 4,
                            decoration: BoxDecoration(color: theme.textSecondary, borderRadius: BorderRadius.circular(2))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(theme.name,
                            style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
                          Text(theme.glassy ? 'Glassmorphism эффект' : 'Чистый стиль',
                            style: TextStyle(color: t.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: t.accent),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          Text('Цвет акцента',
            style: TextStyle(color: t.textSecondary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 10),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Выберите цвет', style: TextStyle(color: t.textPrimary, fontSize: 14)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10, runSpacing: 10,
                  children: _accentColors.map((color) {
                    final isActive = notifier.accent.toARGB32() == color.toARGB32();
                    return GestureDetector(
                      onTap: () => notifier.apply(t.id, customAccent: color),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isActive
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: isActive
                              ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _accentColors = [
    Color(0xFF00E5FF),
    Color(0xFF76FF03),
    Color(0xFFFF4081),
    Color(0xFFFFAB40),
    Color(0xFF7C4DFF),
    Color(0xFF18FFFF),
    Color(0xFFFFFF00),
    Color(0xFFFF6D00),
    Color(0xFF00BFA5),
    Color(0xFFE040FB),
    Color(0xFF64FFDA),
    Color(0xFFFFD740),
  ];
}
