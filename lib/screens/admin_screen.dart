import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_surface.dart';
import 'admin_reports_screen.dart';
import 'admin_users_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  Map<String, dynamic>? _stats;
  List<String> _log = [];
  List<Map<String, dynamic>> _pending = [];
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
    final log   = await api.getLog();
    final users = await api.getAdminUsers();
    if (!mounted) return;
    setState(() {
      _stats   = stats;
      _log     = log;
      _pending = users.where((u) => u['status'] == 'pending').toList();
      _loading = false;
    });
  }

  Future<void> _approve(String email) async {
    await context.read<ApiService>().approveUser(email);
    _fetch();
  }

  Future<void> _reject(String email) async {
    await context.read<ApiService>().rejectUser(email);
    _fetch();
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
                const SizedBox(height: 12),
                // ── Ожидают подтверждения ─────────────────────────────────
                if (_pending.isNotEmpty) ...[
                  GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 18),
                            const SizedBox(width: 8),
                            Text('Ожидают подтверждения',
                                style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text('${_pending.length}',
                                  style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._pending.map((u) {
                          final name   = u['display_name'] as String? ?? '';
                          final email  = u['email']        as String? ?? '';
                          final device = u['device_name']  as String? ?? '';
                          final initials = name.isNotEmpty
                              ? name.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join().toUpperCase()
                              : '?';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: notifier.accent.withValues(alpha: 0.2),
                                      child: Text(initials,
                                          style: TextStyle(color: notifier.accent, fontWeight: FontWeight.bold, fontSize: 13)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name.isNotEmpty ? name : email,
                                              style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                                          Text(email,
                                              style: TextStyle(color: t.textSecondary, fontSize: 11)),
                                          if (device.isNotEmpty)
                                            Text(device,
                                                style: TextStyle(color: t.textSecondary, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _approve(email),
                                        icon: const Icon(Icons.check, size: 15),
                                        label: const Text('Одобрить', style: TextStyle(fontSize: 13)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.greenAccent.shade700,
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                                          padding: const EdgeInsets.symmetric(vertical: 9),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _reject(email),
                                        icon: const Icon(Icons.close, size: 15),
                                        label: const Text('Отклонить', style: TextStyle(fontSize: 13)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.redAccent,
                                          side: const BorderSide(color: Colors.redAccent),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                                          padding: const EdgeInsets.symmetric(vertical: 9),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: Icon(Icons.people_outlined, color: notifier.accent),
                    title: Text('Пользователи',
                        style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
                    subtitle: Text('Одобрение доступа',
                        style: TextStyle(color: t.textSecondary, fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_pending.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('${_pending.length}',
                                style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        Icon(Icons.chevron_right, color: t.textSecondary),
                      ],
                    ),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AdminUsersScreen())).then((_) => _fetch()),
                  ),
                ),
                const SizedBox(height: 12),
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: Icon(Icons.bug_report_outlined, color: notifier.accent),
                    title: Text('Отчёты об ошибках',
                        style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
                    trailing: Icon(Icons.chevron_right, color: t.textSecondary),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AdminReportsScreen())),
                  ),
                ),
                const SizedBox(height: 12),
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
