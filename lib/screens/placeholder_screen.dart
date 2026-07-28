import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';

class PlaceholderScreen extends StatelessWidget {
  final String icon;
  final String title;
  const PlaceholderScreen({super.key, required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final t = Provider.of<AppThemeNotifier>(context).current;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(backgroundColor: t.nav, title: Text(title,
          style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold))),
      body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(icon, style: const TextStyle(fontSize: 64)),
        const SizedBox(height: 16),
        Text('Скоро', style: TextStyle(color: t.textSecondary, fontSize: 18)),
      ])),
    );
  }
}
