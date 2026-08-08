import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/prefs_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_surface.dart';

class BugReportScreen extends StatefulWidget {
  const BugReportScreen({super.key});

  @override
  State<BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends State<BugReportScreen> {
  final _fromCtrl   = TextEditingController();
  final _deviceCtrl = TextEditingController();
  final _textCtrl   = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _initFields();
  }

  Future<void> _initFields() async {
    final prefs = context.read<PrefsService>();
    final name = prefs.profileName.isNotEmpty
        ? prefs.profileName
        : (prefs.googleName.isNotEmpty ? prefs.googleName : '');
    _fromCtrl.text = name;

    try {
      final android = await DeviceInfoPlugin().androidInfo;
      _deviceCtrl.text = 'Android ${android.model}';
    } catch (_) {
      _deviceCtrl.text = 'Android';
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _deviceCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Опишите ошибку')),
      );
      return;
    }
    setState(() => _sending = true);
    final api = context.read<ApiService>();
    final ok = await api.submitBugReport(
      from:   _fromCtrl.text.trim(),
      device: _deviceCtrl.text.trim(),
      text:   text,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Отчёт отправлен. Спасибо!')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось отправить. Проверьте соединение.')),
      );
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
        title: Text('Отчёт об ошибке',
            style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: GlassBg(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('От кого', style: TextStyle(color: t.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _fromCtrl,
                    style: TextStyle(color: t.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Ваше имя',
                      hintStyle: TextStyle(color: t.textSecondary),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.cardBorder)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: notifier.accent)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Устройство', style: TextStyle(color: t.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _deviceCtrl,
                    style: TextStyle(color: t.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Модель устройства',
                      hintStyle: TextStyle(color: t.textSecondary),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.cardBorder)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: notifier.accent)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Описание ошибки', style: TextStyle(color: t.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _textCtrl,
                    style: TextStyle(color: t.textPrimary),
                    maxLines: 6,
                    minLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Опишите что произошло...',
                      hintStyle: TextStyle(color: t.textSecondary),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: t.cardBorder),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: notifier.accent),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send),
                label: const Text('Отправить', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: notifier.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      )),
    );
  }
}
