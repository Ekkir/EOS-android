import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/prefs_service.dart';
import '../models/channel.dart';
import '../widgets/admin_avatar_widget.dart';
import 'messenger_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String username;
  final String? email;

  const UserProfileScreen({super.key, required this.username, this.email});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Uint8List? _avatar;
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _isAdmin = false;
  String? _adminAvatarEffect;
  bool _isFriend = false;
  bool _friendLoading = false;
  bool _isOwnProfile = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<ApiService>();
    final prefs = context.read<PrefsService>();
    final myEmail = prefs.googleEmail;

    final bytes = widget.email != null
        ? await api.getAvatarByEmail(widget.email!)
        : await api.getAvatarByName(widget.username);

    Map<String, dynamic>? profile;
    if (widget.email != null) {
      profile = await api.getProfile(widget.email!, viewer: myEmail.isNotEmpty ? myEmail : null);
    } else {
      final byName = await api.getProfileByName(widget.username);
      if (byName != null) {
        final email = byName['email'] as String?;
        if (email != null && email.isNotEmpty) {
          profile = await api.getProfile(email, viewer: myEmail.isNotEmpty ? myEmail : null);
        } else {
          profile = byName;
        }
      }
    }

    final viewedEmail = widget.email ?? (profile?['google_email'] as String? ?? '');
    final isOwn = myEmail.isNotEmpty && viewedEmail == myEmail;

    if (mounted) {
      setState(() {
        if (bytes != null) _avatar = Uint8List.fromList(bytes);
        _profile = profile;
        _isAdmin = profile?['google_email'] == PrefsService.adminEmail;
        _adminAvatarEffect = profile?['avatar_effect'] as String?;
        _isFriend = profile?['is_friend'] as bool? ?? false;
        _isOwnProfile = isOwn;
        _loading = false;
      });
    }
  }

  String _formatLastSeen(num ts) {
    final diff = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt()));
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return 'был(а) ${diff.inMinutes} мин. назад';
    if (diff.inHours < 24) return 'был(а) ${diff.inHours} ч. назад';
    return 'был(а) ${diff.inDays} д. назад';
  }

  Future<void> _toggleFriend() async {
    final prefs = context.read<PrefsService>();
    final api = context.read<ApiService>();
    final myEmail = prefs.googleEmail;
    final theirEmail = widget.email ?? (_profile?['google_email'] as String? ?? '');
    if (myEmail.isEmpty || theirEmail.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(myEmail.isEmpty
            ? 'Войдите через Google для управления друзьями'
            : 'Профиль пользователя не загружен')));
      return;
    }

    setState(() => _friendLoading = true);
    final ok = _isFriend
        ? await api.removeFriend(myEmail, theirEmail)
        : await api.addFriend(myEmail, theirEmail);
    setState(() {
      if (ok) _isFriend = !_isFriend;
      _friendLoading = false;
    });
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка — попробуйте ещё раз')));
    }
  }

  void _openDm() {
    final prefs = context.read<PrefsService>();
    final myName = prefs.profileName.isNotEmpty ? prefs.profileName : prefs.googleName;
    final sorted = [myName, widget.username]..sort();
    final dmId = 'dm_${sorted[0]}~${sorted[1]}';
    final channel = Channel(
      id: dmId,
      name: widget.username,
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
    final prefs = context.read<PrefsService>();
    final displayName = _profile?['display_name'] as String? ?? widget.username;
    final bio = _profile?['bio'] as String? ?? '';
    final isOnline = _profile?['is_online'] as bool? ?? false;
    final lastSeenTs = _profile?['last_seen'] as num?;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.nav,
        title: Text(displayName, style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: notifier.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  AdminAvatarWidget(
                    bytes: _avatar,
                    name: displayName,
                    radius: 52,
                    isAdminAvatar: _isAdmin,
                    effectOverride: _isAdmin ? _adminAvatarEffect : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(displayName,
                        style: TextStyle(color: t.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                      if (isOnline) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 10, height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (isOnline)
                    Text('онлайн',
                      style: TextStyle(color: Colors.greenAccent.withValues(alpha: 0.8), fontSize: 12))
                  else if (lastSeenTs != null && lastSeenTs > 0)
                    Text(_formatLastSeen(lastSeenTs),
                      style: TextStyle(color: t.textSecondary, fontSize: 12)),
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(bio,
                      style: TextStyle(color: t.textSecondary, fontSize: 14, height: 1.4),
                      textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 24),
                  if (!_isOwnProfile && prefs.googleEmail.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _friendLoading ? null : _toggleFriend,
                            icon: _friendLoading
                                ? const SizedBox(width: 16, height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Icon(_isFriend ? Icons.person_remove_outlined : Icons.person_add_outlined),
                            label: Text(_isFriend ? 'Удалить из друзей' : '+ Добавить в друзья'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isFriend
                                  ? t.surface
                                  : notifier.accent,
                              foregroundColor: _isFriend ? t.textSecondary : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: _isFriend
                                    ? BorderSide(color: t.cardBorder)
                                    : BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _openDm,
                            icon: const Icon(Icons.message),
                            label: const Text('Написать'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: notifier.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (_isOwnProfile) ...[
                    // own profile — no write/friend button
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openDm,
                        icon: const Icon(Icons.message),
                        label: const Text('Написать'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: notifier.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
