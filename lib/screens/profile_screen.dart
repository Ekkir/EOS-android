import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/prefs_service.dart';
import '../widgets/aurora_ring.dart';
import '../widgets/glitch_wrapper.dart';
import '../widgets/pixel_disintegration_wrapper.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_surface.dart';
import '../widgets/circular_avatar.dart';
import 'admin_reports_screen.dart';
import 'friends_screen.dart';
import 'login_screen.dart';

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

    setState(() => _loadingAvatar = true);
    final ok = await api.uploadAvatar(
      file,
      prefs.profileName.isNotEmpty ? prefs.profileName : (prefs.googleName.isNotEmpty ? prefs.googleName : 'User'),
      email: prefs.googleEmail.isNotEmpty ? prefs.googleEmail : null,
    );

    if (!mounted) return;
    if (ok) {
      final bytes = await file.readAsBytes();
      await prefs.incrementAvatarVersion();
      if (mounted) setState(() { _avatarBytes = Uint8List.fromList(bytes); _loadingAvatar = false; });
    } else {
      setState(() => _loadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить аватар. Проверьте подключение.')),
      );
    }
  }

  Future<void> _saveProfile() async {
    final prefs = context.read<PrefsService>();
    final api = context.read<ApiService>();
    final newName = _nameCtrl.text.trim();
    final oldName = prefs.profileName;

    setState(() => _saving = true);

    if (newName.isNotEmpty && newName != oldName) {
      final taken = await api.usernameExists(newName);
      if (taken && mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Этот ник уже занят')),
        );
        return;
      }
    }

    if (prefs.googleSignedIn) {
      final error = await api.syncProfile(
        prefs.googleEmail,
        newName,
        bio: _descCtrl.text.trim(),
        avatarEffect: prefs.isAdmin ? prefs.adminEffect : null,
      );
      if (error == 'nickname_taken' && mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Этот ник уже занят')),
        );
        return;
      }
    }
    await prefs.setProfileName(newName);
    await prefs.setProfileDesc(_descCtrl.text.trim());
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text('Вы будете перенаправлены на экран входа.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Выйти', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _googleSignIn.signOut();
    if (!mounted) return;
    final prefs = context.read<PrefsService>();
    await prefs.clearGoogleAccount();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = Provider.of<AppThemeNotifier>(context);
    final t = notifier.current;
    final prefs = context.read<PrefsService>();

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.nav,
        title: Text('Профиль', style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: GlassBg(child: SingleChildScrollView(
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
                          child: CircularProgressIndicator(color: notifier.accent, strokeWidth: 2))
                      : CircularAvatar(
                          bytes: _avatarBytes,
                          name: prefs.profileName.isNotEmpty ? prefs.profileName
                              : (prefs.googleName.isNotEmpty ? prefs.googleName : '?'),
                          radius: 52,
                        ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: notifier.accent, shape: BoxShape.circle),
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
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: notifier.accent)),
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
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: notifier.accent)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Эта информация будет видна другим пользователям',
                    style: TextStyle(color: t.textSecondary, fontSize: 11)),
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
            const SizedBox(height: 20),

            // Admin-only section
            if (prefs.isAdmin) ...[
              const SizedBox(height: 20),
              // Effect picker
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Эффект аватара',
                      style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('Анимация вокруг вашего аватара',
                      style: TextStyle(color: t.textSecondary, fontSize: 12)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final e in [
                          ('aurora',         'Аврора'),
                          ('glitch',         'Глитч'),
                          ('disintegration', 'Пиксели'),
                          ('none',           'Нет'),
                        ])
                          GestureDetector(
                            onTap: () async {
                              await prefs.setAdminEffect(e.$1);
                              if (mounted) setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: prefs.adminEffect == e.$1
                                    ? notifier.accent.withValues(alpha: 0.2)
                                    : t.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: prefs.adminEffect == e.$1
                                      ? notifier.accent
                                      : t.cardBorder,
                                ),
                              ),
                              child: Text(e.$2,
                                style: TextStyle(
                                  color: prefs.adminEffect == e.$1
                                      ? notifier.accent
                                      : t.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Preview
                    Center(
                      child: () {
                        const avatar = CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.black,
                          child: Icon(Icons.person, color: Colors.white54, size: 26),
                        );
                        return switch (prefs.adminEffect) {
                          'glitch'         => GlitchWrapper(
                              intensity: prefs.glitchIntensity,
                              speed: prefs.glitchSpeed,
                              frequency: prefs.glitchFrequency,
                              child: avatar),
                          'none'           => avatar,
                          'disintegration' => const PixelDisintegrationWrapper(child: avatar),
                          _                => const AuroraRing(ringPadding: 3, innerPadding: 3, child: avatar),
                        };
                      }(),
                    ),
                  ],
                ),
              ),
              // Per-effect settings
              if (prefs.adminEffect == 'aurora') ...[
                const SizedBox(height: 12),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Северное сияние',
                        style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('Цвета авроры вокруг аватара',
                        style: TextStyle(color: t.textSecondary, fontSize: 12)),
                      const SizedBox(height: 16),
                      _RingColorPicker(
                        label: 'Цвет 1',
                        selected: prefs.ringColor1,
                        onChanged: (c) async {
                          await prefs.setRingColor1(c);
                          if (mounted) setState(() {});
                        },
                        theme: t,
                      ),
                      const SizedBox(height: 12),
                      _RingColorPicker(
                        label: 'Цвет 2',
                        selected: prefs.ringColor2,
                        onChanged: (c) async {
                          await prefs.setRingColor2(c);
                          if (mounted) setState(() {});
                        },
                        theme: t,
                      ),
                      const SizedBox(height: 16),
                      _AnimSlider(
                        label: 'Скорость вращения',
                        value: prefs.auroraSpeed,
                        min: 0.3, max: 3.0,
                        onChanged: prefs.setAuroraSpeed,
                        theme: t,
                      ),
                    ],
                  ),
                ),
              ],
              if (prefs.adminEffect == 'glitch') ...[
                const SizedBox(height: 12),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Настройки глитча',
                        style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 16),
                      _AnimSlider(
                        label: 'Интенсивность',
                        value: prefs.glitchIntensity,
                        min: 0.1, max: 1.0,
                        onChanged: prefs.setGlitchIntensity,
                        theme: t,
                      ),
                      const SizedBox(height: 12),
                      _AnimSlider(
                        label: 'Скорость анимации',
                        value: prefs.glitchSpeed,
                        min: 0.3, max: 3.0,
                        onChanged: prefs.setGlitchSpeed,
                        theme: t,
                      ),
                      const SizedBox(height: 12),
                      _AnimSlider(
                        label: 'Частота',
                        value: prefs.glitchFrequency,
                        min: 0.3, max: 3.0,
                        onChanged: prefs.setGlitchFrequency,
                        theme: t,
                      ),
                    ],
                  ),
                ),
              ],
              if (prefs.adminEffect == 'disintegration') ...[
                const SizedBox(height: 12),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Настройки пикселей',
                        style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 16),
                      _AnimSlider(
                        label: 'Скорость',
                        value: prefs.disintSpeed,
                        min: 0.3, max: 3.0,
                        onChanged: prefs.setDisintSpeed,
                        theme: t,
                      ),
                    ],
                  ),
                ),
              ],
              // Bug reports
              const SizedBox(height: 12),
              GlassCard(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AdminReportsScreen())),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.bug_report_outlined, color: notifier.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Отчёты об ошибках',
                            style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600)),
                          Text('Читать и удалять',
                            style: TextStyle(color: t.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: t.textSecondary),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            // Друзья
            if (prefs.googleSignedIn && prefs.googleEmail.isNotEmpty)
              GlassCard(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const FriendsScreen())),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.people_outline, color: notifier.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Друзья',
                        style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600)),
                    ),
                    Icon(Icons.chevron_right, color: t.textSecondary),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            // Google Sign-In
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: prefs.googleSignedIn
                  ? Row(
                      children: [
                        if (prefs.googlePhoto.isNotEmpty)
                          ClipOval(child: Image.network(prefs.googlePhoto, width: 40, height: 40, fit: BoxFit.cover))
                        else
                          CircleAvatar(radius: 20, backgroundColor: notifier.accent,
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
                          child: Text('Выйти', style: TextStyle(color: notifier.accent)),
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
      )),
    );
  }
}

// ── Animation slider ──────────────────────────────────────────────────────────

class _AnimSlider extends StatefulWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final void Function(double) onChanged;
  final ThemeDef theme;

  const _AnimSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.theme,
  });

  @override
  State<_AnimSlider> createState() => _AnimSliderState();
}

class _AnimSliderState extends State<_AnimSlider> {
  late double _val;

  @override
  void initState() {
    super.initState();
    _val = widget.value;
  }

  @override
  void didUpdateWidget(_AnimSlider old) {
    super.didUpdateWidget(old);
    if ((widget.value - _val).abs() > 0.05) _val = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.read<AppThemeNotifier>().accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.label, style: TextStyle(color: widget.theme.textSecondary, fontSize: 13)),
            Text(_val.toStringAsFixed(1),
                style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: accent,
            inactiveTrackColor: widget.theme.cardBorder,
            thumbColor: accent,
            overlayColor: accent.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: _val,
            min: widget.min,
            max: widget.max,
            onChanged: (v) {
              setState(() => _val = v);
              widget.onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}

// ── Ring color picker ─────────────────────────────────────────────────────────

class _RingColorPicker extends StatelessWidget {
  final String label;
  final Color selected;
  final ValueChanged<Color> onChanged;
  final ThemeDef theme;

  static const _colors = [
    Color(0xFFBB00FF), Color(0xFF00E5FF), Color(0xFF39FF14), Color(0xFFFF4081),
    Color(0xFFFF6D00), Color(0xFF3C78FF), Color(0xFFFFD700), Color(0xFF00BFA5),
    Color(0xFFE040FB), Color(0xFFFF1744), Color(0xFFFFFFFF), Color(0xFF18FFFF),
  ];

  const _RingColorPicker({
    required this.label,
    required this.selected,
    required this.onChanged,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _colors.map((c) {
            final isActive = selected.toARGB32() == c.toARGB32();
            return GestureDetector(
              onTap: () => onChanged(c),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: isActive ? Border.all(color: Colors.white, width: 3) : null,
                  boxShadow: isActive ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 8)] : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}


