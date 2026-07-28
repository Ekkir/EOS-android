import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/prefs_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/circular_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  Uint8List? _avatarBytes;
  bool _saving = false;
  bool _loadingAvatar = false;

  final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  @override
  void initState() {
    super.initState();
    final prefs = context.read<PrefsService>();
    _nameCtrl.text = prefs.profileName;
    _descCtrl.text = prefs.profileDesc;
    _loadAvatar();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAvatar() async {
    final api = context.read<ApiService>();
    final prefs = context.read<PrefsService>();
    setState(() => _loadingAvatar = true);
    List<int>? bytes;
    if (prefs.googleEmail.isNotEmpty) {
      bytes = await api.getAvatarByEmail(prefs.googleEmail);
    }
    if (bytes == null && prefs.profileName.isNotEmpty) {
      bytes = await api.getAvatarByName(prefs.profileName);
    }
    if (mounted) {
      setState(() {
        if (bytes != null) _avatarBytes = Uint8List.fromList(bytes);
        _loadingAvatar = false;
      });
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 512);
    if (xfile == null || !mounted) return;

    final prefs = context.read<PrefsService>();
    final api = context.read<ApiService>();
    final file = File(xfile.path);

    setState(() => _saving = true);
    final ok = await api.uploadAvatar(
      file,
      prefs.profileName.isNotEmpty ? prefs.profileName : (prefs.googleName.isNotEmpty ? prefs.googleName : 'User'),
      email: prefs.googleEmail.isNotEmpty ? prefs.googleEmail : null,
    );

    if (ok && mounted) {
      _avatarBytes = await file.readAsBytes();
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _saveProfile() async {
    final prefs = context.read<PrefsService>();
    final api = context.read<ApiService>();
    setState(() => _saving = true);
    await prefs.setProfileName(_nameCtrl.text.trim());
    await prefs.setProfileDesc(_descCtrl.text.trim());
    if (prefs.googleSignedIn) {
      await api.syncProfile(prefs.googleEmail, _nameCtrl.text.trim());
    }
    if (mounted) setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Профиль сохранён'), duration: Duration(seconds: 2)),
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null || !mounted) return;
      final prefs = context.read<PrefsService>();
      await prefs.setGoogleAccount(
        signedIn: true,
        email: account.email,
        name: account.displayName ?? '',
        photo: account.photoUrl ?? '',
      );
      if (_nameCtrl.text.isEmpty) _nameCtrl.text = account.displayName ?? '';
      setState(() {});
      _loadAvatar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка входа: $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    await _googleSignIn.signOut();
    if (!mounted) return;
    final prefs = context.read<PrefsService>();
    await prefs.clearGoogleAccount();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = Provider.of<AppThemeNotifier>(context).current;
    final prefs = context.read<PrefsService>();

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.nav,
        title: Text('Профиль', style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Avatar
            GestureDetector(
              onTap: _pickAndUploadAvatar,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  _loadingAvatar
                      ? CircleAvatar(radius: 52, backgroundColor: t.surface,
                          child: CircularProgressIndicator(color: t.accent, strokeWidth: 2))
                      : CircularAvatar(
                          bytes: _avatarBytes,
                          name: prefs.profileName.isNotEmpty ? prefs.profileName
                              : (prefs.googleName.isNotEmpty ? prefs.googleName : '?'),
                          radius: 52,
                        ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Name & description fields
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Имя', style: TextStyle(color: t.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameCtrl,
                    style: TextStyle(color: t.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Ваше имя',
                      hintStyle: TextStyle(color: t.textSecondary),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.cardBorder)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.accent)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('О себе', style: TextStyle(color: t.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _descCtrl,
                    style: TextStyle(color: t.textPrimary),
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Расскажите о себе...',
                      hintStyle: TextStyle(color: t.textSecondary),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.cardBorder)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.accent)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.accent,
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
            const SizedBox(height: 20),

            // Google Sign-In
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: prefs.googleSignedIn
                  ? Row(
                      children: [
                        if (prefs.googlePhoto.isNotEmpty)
                          ClipOval(child: Image.network(prefs.googlePhoto, width: 40, height: 40, fit: BoxFit.cover))
                        else
                          CircleAvatar(radius: 20, backgroundColor: t.accent,
                              child: Text(prefs.googleName.isNotEmpty ? prefs.googleName[0].toUpperCase() : 'G',
                                  style: const TextStyle(color: Colors.white))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(prefs.googleName, style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600)),
                              Text(prefs.googleEmail, style: TextStyle(color: t.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _signOut,
                          child: Text('Выйти', style: TextStyle(color: t.accent)),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        const Icon(Icons.account_circle, color: Colors.white70, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Google аккаунт', style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600)),
                              Text('Войдите для синхронизации', style: TextStyle(color: t.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _signInWithGoogle,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4285F4),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Войти'),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

