import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_surface.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final users = await context.read<ApiService>().getAdminUsers();
    if (mounted) setState(() { _users = users; _loading = false; });
  }

  Future<void> _approve(String email) async {
    await context.read<ApiService>().approveUser(email);
    _load();
  }

  Future<void> _reject(String email) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final t = Provider.of<AppThemeNotifier>(ctx).current;
        return AlertDialog(
          backgroundColor: t.surface,
          title: Text('Отклонить', style: TextStyle(color: t.textPrimary)),
          content: Text('Отклонить доступ для $email?',
              style: TextStyle(color: t.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: Text('Отмена', style: TextStyle(color: t.textSecondary))),
            TextButton(onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Отклонить', style: TextStyle(color: Colors.red))),
          ],
        );
      },
    );
    if (ok == true) {
      await context.read<ApiService>().rejectUser(email);
      _load();
    }
  }

  Future<void> _revoke(String email) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final t = Provider.of<AppThemeNotifier>(ctx).current;
        return AlertDialog(
          backgroundColor: t.surface,
          title: Text('Отозвать доступ', style: TextStyle(color: t.textPrimary)),
          content: Text(
            'Пользователь $email потеряет доступ к приложению при следующем запуске.',
            style: TextStyle(color: t.textSecondary),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: Text('Отмена', style: TextStyle(color: t.textSecondary))),
            TextButton(onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Отозвать', style: TextStyle(color: Colors.orange))),
          ],
        );
      },
    );
    if (ok == true) {
      await context.read<ApiService>().rejectUser(email);
      _load();
    }
  }

  Future<void> _suspend(String email) async {
    await context.read<ApiService>().suspendUser(email);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = Provider.of<AppThemeNotifier>(context);
    final t = notifier.current;

    final pending   = _users.where((u) => u['status'] == 'pending').toList();
    final approved  = _users.where((u) => u['status'] == 'approved').toList();
    final suspended = _users.where((u) => u['status'] == 'suspended').toList();
    final rejected  = _users.where((u) => u['status'] == 'rejected').toList();

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.nav,
        title: Text('Пользователи', style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: notifier.accent),
            onPressed: _load,
          ),
        ],
      ),
      body: GlassBg(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: notifier.accent))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (pending.isNotEmpty) ...[
                      _SectionHeader(
                        label: 'Ожидают подтверждения',
                        count: pending.length,
                        color: Colors.amber,
                      ),
                      ...pending.map((u) => _UserCard(
                        user: u, theme: t, accent: notifier.accent,
                        onApprove: () => _approve(u['email'] as String),
                        onReject:  () => _reject(u['email']  as String),
                      )),
                      const SizedBox(height: 16),
                    ],
                    if (approved.isNotEmpty) ...[
                      _SectionHeader(
                        label: 'Одобренные',
                        count: approved.length,
                        color: Colors.greenAccent,
                      ),
                      ...approved.map((u) => _UserCard(
                        user: u, theme: t, accent: notifier.accent,
                        onRevoke:  () => _revoke(u['email'] as String),
                        onSuspend: () => _suspend(u['email'] as String),
                      )),
                      const SizedBox(height: 16),
                    ],
                    if (suspended.isNotEmpty) ...[
                      _SectionHeader(
                        label: 'Приостановленные',
                        count: suspended.length,
                        color: Colors.orangeAccent,
                      ),
                      ...suspended.map((u) => _UserCard(
                        user: u, theme: t, accent: notifier.accent,
                        onApprove: () => _approve(u['email'] as String),
                        onReject:  () => _reject(u['email']  as String),
                      )),
                      const SizedBox(height: 16),
                    ],
                    if (rejected.isNotEmpty) ...[
                      _SectionHeader(
                        label: 'Отклонённые',
                        count: rejected.length,
                        color: Colors.redAccent,
                      ),
                      ...rejected.map((u) => _UserCard(
                        user: u, theme: t, accent: notifier.accent,
                        onApprove: () => _approve(u['email'] as String),
                      )),
                    ],
                    if (_users.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                          child: Text('Нет зарегистрированных пользователей',
                              style: TextStyle(color: t.textSecondary)),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SectionHeader({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                  child: Text('$count', style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final ThemeDef theme;
  final Color accent;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onRevoke;
  final VoidCallback? onSuspend;
  const _UserCard({
    required this.user,
    required this.theme,
    required this.accent,
    this.onApprove,
    this.onReject,
    this.onRevoke,
    this.onSuspend,
  });

  @override
  Widget build(BuildContext context) {
    final name       = user['display_name'] as String? ?? '';
    final email      = user['email']        as String? ?? '';
    final deviceName = user['device_name']  as String? ?? '';
    final deviceId   = user['device_id']    as String? ?? '';
    final status     = user['status']       as String? ?? 'pending';
    final createdAt  = user['created_at']   as int?   ?? 0;

    final dateStr = createdAt > 0
        ? _formatDate(DateTime.fromMillisecondsSinceEpoch(createdAt * 1000))
        : '';

    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join().toUpperCase()
        : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: accent.withValues(alpha: 0.2),
                  child: Text(initials, style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isNotEmpty ? name : email,
                          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold)),
                      Text(email, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                _StatusBadge(status: status),
              ],
            ),
            if (deviceName.isNotEmpty || deviceId.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (deviceName.isNotEmpty)
                      Row(children: [
                        Icon(Icons.phone_android, size: 14, color: theme.textSecondary),
                        const SizedBox(width: 6),
                        Text(deviceName, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                      ]),
                    if (deviceId.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.fingerprint, size: 14, color: theme.textSecondary),
                        const SizedBox(width: 6),
                        Text('ID: $deviceId', style: TextStyle(color: theme.textSecondary, fontSize: 11)),
                      ]),
                    ],
                  ],
                ),
              ),
            ],
            if (dateStr.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Зарегистрирован: $dateStr',
                  style: TextStyle(color: theme.textSecondary, fontSize: 11)),
            ],
            if (onApprove != null || onReject != null || onRevoke != null || onSuspend != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onApprove != null)
                    ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Одобрить'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent.shade700,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  if (onSuspend != null)
                    OutlinedButton.icon(
                      onPressed: onSuspend,
                      icon: const Icon(Icons.pause_circle_outline, size: 16),
                      label: const Text('Приостановить'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orangeAccent,
                        side: const BorderSide(color: Colors.orangeAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  if (onReject != null)
                    OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Отклонить'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  if (onRevoke != null)
                    OutlinedButton.icon(
                      onPressed: onRevoke,
                      icon: const Icon(Icons.block, size: 16),
                      label: const Text('Отозвать'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'approved'  => ('Одобрен',          Colors.greenAccent),
      'rejected'  => ('Отклонён',         Colors.redAccent),
      'suspended' => ('Приостановлен',    Colors.orangeAccent),
      _           => ('Ожидает',          Colors.amber),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
