import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/channel.dart';
import '../widgets/circular_avatar.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<ApiService>();
    final bytes = widget.email != null
        ? await api.getAvatarByEmail(widget.email!)
        : await api.getAvatarByName(widget.username);
    if (widget.email != null) {
      final profile = await api.getProfile(widget.email!);
      if (mounted) setState(() => _profile = profile);
    }
    if (mounted) {
      setState(() {
        if (bytes != null) _avatar = Uint8List.fromList(bytes);
        _loading = false;
      });
    }
  }

  void _openDm() {
    final dmId = 'dm_${widget.username}';
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
    final t = Provider.of<AppThemeNotifier>(context).current;
    final displayName = _profile?['display_name'] as String? ?? widget.username;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.nav,
        title: Text(widget.username, style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: t.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  CircularAvatar(bytes: _avatar, name: displayName, radius: 52),
                  const SizedBox(height: 16),
                  Text(displayName,
                    style: TextStyle(color: t.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                  if (widget.email != null) ...[
                    const SizedBox(height: 4),
                    Text(widget.email!,
                      style: TextStyle(color: t.textSecondary, fontSize: 14)),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openDm,
                      icon: const Icon(Icons.message),
                      label: const Text('Написать'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: t.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
