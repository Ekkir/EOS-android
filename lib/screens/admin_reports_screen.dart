import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<ApiService>();
    final list = await api.getBugReports();
    if (mounted) setState(() { _reports = list; _loading = false; });
  }

  Future<void> _delete(Map<String, dynamic> report) async {
    final id = report['id'] as int? ?? 0;
    final api = context.read<ApiService>();
    final ok = await api.deleteBugReport(id);
    if (ok && mounted) {
      setState(() => _reports.removeWhere((r) => r['id'] == id));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить отчёт')),
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
        title: Text('Отчёты об ошибках',
            style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: t.textPrimary),
            onPressed: () { setState(() => _loading = true); _load(); },
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: notifier.accent))
          : _reports.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, color: t.textSecondary, size: 48),
                      const SizedBox(height: 12),
                      Text('Отчётов нет', style: TextStyle(color: t.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _reports.length,
                  itemBuilder: (_, i) {
                    final r = _reports[i];
                    final from   = r['from']   as String? ?? '—';
                    final device = r['device'] as String? ?? '—';
                    final text   = r['text']   as String? ?? '';
                    return Card(
                      color: t.surface,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: t.cardBorder),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person_outline, color: notifier.accent, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(from,
                                      style: TextStyle(color: t.textPrimary,
                                          fontWeight: FontWeight.w600)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.redAccent, size: 20),
                                  tooltip: 'Удалить',
                                  onPressed: () => _delete(r),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.phone_android, color: t.textSecondary, size: 14),
                                const SizedBox(width: 4),
                                Text(device,
                                    style: TextStyle(color: t.textSecondary, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(text,
                                style: TextStyle(color: t.textPrimary, fontSize: 14, height: 1.4)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
