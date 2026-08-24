import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/prefs_service.dart';
import '../models/channel.dart';
import '../widgets/circular_avatar.dart';
import 'messenger_screen.dart';
import 'user_profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  List<Map<String, dynamic>> _friends = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<ApiService>();
    final prefs = context.read<PrefsService>();
    if (prefs.googleEmail.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final list = await api.getFriends(prefs.googleEmail);
    if (mounted) setState(() { _friends = list; _loading = false; });
  }

  void _openDm(String username) {
    final prefs = context.read<PrefsService>();
    final myName = prefs.profileName.isNotEmpty ? prefs.profileName : prefs.googleName;
    final sorted = [myName, username]..sort();
    final dmId = 'dm_${sorted[0]}~${sorted[1]}';
    final channel = Channel(
      id: dmId,
      name: username,
      icon: '💬',
      lastText: '',
      lastTs: 0,
    );
    Navigator.push(context, MaterialPageRoute(builder: (_) => MessengerScreen(channel: channel)));
  }

  @override
  Widget build(BuildContext context) {
    final notifier = Provider.of<AppThemeNotifier>(context);
    final t = notifier.current;

    return Scaffold(
      backgroundColor: notifier.bgDecoration != null ? Colors.transparent : t.bg,
      appBar: AppBar(
        backgroundColor: t.nav,
        title: Text('Друзья', style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: notifier.accent))
          : _friends.isEmpty
              ? Center(
                  child: Text('Список друзей пуст',
                    style: TextStyle(color: t.textSecondary, fontSize: 15)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _friends.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (ctx, i) {
                    final f = _friends[i];
                    final name = f['display_name'] as String? ?? f['email'] as String? ?? '?';
                    final isOnline = f['is_online'] as bool? ?? false;
                    final BoxDecoration friendDecor;
                    if (t.neonGlow) {
                      friendDecor = BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: notifier.accent2.withValues(alpha: 0.55), width: 1),
                      );
                    } else if (t.cyberpunk) {
                      friendDecor = BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: notifier.accent.withValues(alpha: 0.5), width: 1),
                        boxShadow: [
                          BoxShadow(color: notifier.accent.withValues(alpha: 0.18), blurRadius: 10),
                        ],
                      );
                    } else {
                      friendDecor = BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: t.cardBorder),
                      );
                    }
                    return Container(
                      decoration: friendDecor,
                      child: ListTile(
                        leading: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircularAvatar(name: name, radius: 22),
                            if (isOnline)
                              Positioned(
                                right: -2, bottom: -2,
                                child: Container(
                                  width: 12, height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.greenAccent,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: t.surface, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(name,
                          style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          isOnline ? 'онлайн' : 'не в сети',
                          style: TextStyle(
                            color: isOnline ? Colors.greenAccent : t.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.message_outlined, color: notifier.accent),
                          tooltip: 'Написать',
                          onPressed: () => _openDm(name),
                        ),
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => UserProfileScreen(
                            username: name,
                            email: f['email'] as String?,
                          ),
                        )),
                      ),
                    );
                  },
                ),
    );
  }
}
