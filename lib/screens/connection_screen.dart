import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/prefs_service.dart';
import '../services/server_url_resolver.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_surface.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  late TextEditingController _remoteCtrl;
  late TextEditingController _localCtrl;
  bool _saving = false;
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    final prefs = context.read<PrefsService>();
    _remoteCtrl = TextEditingController(text: prefs.serverUrl);
    _localCtrl  = TextEditingController(text: prefs.serverUrlLocal);
  }

  @override
  void dispose() {
    _remoteCtrl.dispose();
    _localCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final prefs = context.read<PrefsService>();
    setState(() => _saving = true);
    await prefs.setServerUrl(_remoteCtrl.text.trim());
    await prefs.setServerUrlLocal(_localCtrl.text.trim());
    ServerUrlResolver.reset();
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сохранено'), duration: Duration(seconds: 2)),
      );
    }
  }

  Future<void> _test() async {
    final prefs = context.read<PrefsService>();
    setState(() { _testing = true; _testResult = null; });
    ServerUrlResolver.reset();
    try {
      final url = await ServerUrlResolver.resolve(prefs);
      if (mounted) setState(() { _testResult = 'OK: $url'; _testing = false; });
    } catch (e) {
      if (mounted) setState(() { _testResult = 'Ошибка: $e'; _testing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = Provider.of<AppThemeNotifier>(context);
    final t = notifier.current;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.nav,
        title: Text('Подключение', style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: GlassBg(child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Внешний URL', style: TextStyle(color: t.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: _remoteCtrl,
                  style: TextStyle(color: t.textPrimary),
                  keyboardType: TextInputType.url,
                  decoration: _inputDec('http://example.com:5000', t),
                ),
                const SizedBox(height: 16),
                Text('Локальный URL', style: TextStyle(color: t.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: _localCtrl,
                  style: TextStyle(color: t.textPrimary),
                  keyboardType: TextInputType.url,
                  decoration: _inputDec('http://192.168.x.x:5000', t),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: notifier.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _testing ? null : _test,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: notifier.accent,
                    side: BorderSide(color: notifier.accent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _testing
                      ? SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(color: notifier.accent, strokeWidth: 2))
                      : const Text('Проверить', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    _testResult!.startsWith('OK') ? Icons.check_circle : Icons.error,
                    color: _testResult!.startsWith('OK') ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_testResult!,
                      style: TextStyle(
                        color: _testResult!.startsWith('OK') ? Colors.green : Colors.red,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      )),
    );
  }

  InputDecoration _inputDec(String hint, ThemeDef t) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: t.textSecondary),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: t.cardBorder),
      borderRadius: BorderRadius.circular(10),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Provider.of<AppThemeNotifier>(context, listen: false).accent),
      borderRadius: BorderRadius.circular(10),
    ),
    filled: true,
    fillColor: Colors.black12,
  );
}
