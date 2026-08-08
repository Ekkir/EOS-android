import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_surface.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  Map<String, dynamic>? _stats;
  List<String> _log = [];
  Timer? _timer;
  bool _loading = true;
  bool _restarting = false;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    final api = context.read<ApiService>();
    final stats = await api.getStats();
    final log = await api.getLog();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _log = log;
      _loading = false;
    });
  }

  Future<void> _restart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final t = Provider.of<AppThemeNotifier>(ctx).current;
        return AlertDialog(
          backgroundColor: t.surface,
          title: Text('Перезапуск', style: TextStyle(color: t.textPrimary)),
          content: Text('Перезапустить сервер?', style: TextStyle(color: t.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Отмена', style: TextStyle(color: t.textSecondary))),
            TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text('Да', style: TextStyle(color: Colors.red))),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() => _restarting = true);
    await context.read<ApiService>().restartServer();
    if (mounted) setState(() => _restarting = false);
  }

  @override
  Widget build(BuildContext context) {
    final notifier = Provider.of<AppThemeNotifier>(context);
    final t = notifier.current;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.nav,
        title: Text('Администратор', style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: notifier.accent),
            onPressed: _fetch,
          ),
          IconButton(
            icon: _restarting
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: notifier.accent, strokeWidth: 2))
                : const Icon(Icons.power_settings_new, color: Colors.red),
            onPressed: _restarting ? null : _restart,
          ),
        ],
      ),
      body: GlassBg(child: _loading
          ? Center(child: CircularProgressIndicator(color: notifier.accent))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (_stats != null) ...[
                  _StatCard(stats: _stats!, theme: t),
                  const SizedBox(height: 12),
                ],
                if (_log.isNotEmpty)
                  GlassCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Лог сервера',
                          style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 8),
                        Container(
                          height: 300,
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: _log.length,
                            reverse: true,
                            itemBuilder: (ctx, i) => Text(
                              _log[_log.length - 1 - i],
                              style: TextStyle(
                                color: t.textSecondary,
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            )),
    );
  }
}

class _StatCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  final ThemeDef theme;
  const _StatCard({required this.stats, required this.theme});

  static const _labels = <String, String>{
    'uptime':           'Аптайм',
    'connections':      'Соединений',
    'messages':         'Сообщений',
    'messages_total':   'Всего сообщений',
    'users':            'Пользователей',
    'clients':          'Клиентов',
    'channels':         'Каналов',
    'fcm_tokens':       'FCM токенов',
    'media_files':      'Медиафайлов',
    'requests':         'Запросов',
    'requests_total':   'Запросов всего',
    'memory':           'Память',
    'cpu':              'CPU',
    'version':          'Версия',
    'started':          'Запущен',
    'lights_requests':  'Запросов светофоров',
    'errors':           'Ошибок',
    'active_channels':  'Активных каналов',
    'online':           'Онлайн',
  };

  @override
  Widget build(BuildContext context) {
    final accent = context.read<AppThemeNotifier>().accent;
    final items = stats.entries.toList();
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Статистика', style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12, runSpacing: 8,
            children: items.map((e) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.neonGlow
                      ? accent.withValues(alpha: 0.55)
                      : theme.cyberpunk
                          ? accent.withValues(alpha: 0.5)
                          : theme.cardBorder,
                ),
              ),
              child: Column(
                children: [
                  Text('${e.value}',
                    style: TextStyle(color: accent, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(_labels[e.key] ?? e.key,
                    style: TextStyle(color: theme.textSecondary, fontSize: 11)),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}
