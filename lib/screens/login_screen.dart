import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../services/prefs_service.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  late final AnimationController _gradCtrl;

  final _google = GoogleSignIn(scopes: ['email', 'profile']);
  bool _loading = false;
  String? _error;

  bool _pickingNick = false;
  String _googleEmail = '';
  String _googleName = '';
  String _googlePhoto = '';
  final _nickCtrl = TextEditingController();
  bool _checking = false;
  bool? _nickAvailable;

  @override
  void initState() {
    super.initState();
    _gradCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _gradCtrl.dispose();
    _nickCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() { _loading = true; _error = null; });
    try {
      final account = await _google.signIn();
      if (account == null) {
        setState(() { _loading = false; _error = 'Вход отменён'; });
        return;
      }

      _googleEmail = account.email;
      _googleName  = account.displayName ?? '';
      _googlePhoto = account.photoUrl ?? '';

      if (!mounted) return;
      final prefs = context.read<PrefsService>();
      final api   = context.read<ApiService>();

      await prefs.setGoogleAccount(
        signedIn: true,
        email: _googleEmail,
        name: _googleName,
        photo: _googlePhoto,
      );

      final desiredName = _googleName.isNotEmpty ? _googleName : _googleEmail.split('@').first;
      final err = await api.syncProfile(_googleEmail, desiredName);

      if (err == 'nickname_taken') {
        _nickCtrl.text = desiredName;
        setState(() { _loading = false; _pickingNick = true; });
        return;
      }

      await prefs.setProfileName(desiredName);
      if (!mounted) return;
      _goHome();
    } catch (_) {
      setState(() { _loading = false; _error = 'Ошибка входа. Попробуйте ещё раз.'; });
    }
  }

  Future<void> _checkNickAvailability(String name) async {
    if (name.isEmpty) { setState(() => _nickAvailable = null); return; }
    setState(() { _checking = true; _nickAvailable = null; });
    final api = context.read<ApiService>();
    final available = await api.checkNickname(name, excludeEmail: _googleEmail);
    if (mounted) setState(() { _checking = false; _nickAvailable = available; });
  }

  Future<void> _confirmNick() async {
    final name = _nickCtrl.text.trim();
    if (name.isEmpty || _nickAvailable == false) return;
    setState(() => _loading = true);

    final prefs = context.read<PrefsService>();
    final api   = context.read<ApiService>();
    final err = await api.syncProfile(_googleEmail, name);

    if (err == 'nickname_taken') {
      setState(() { _loading = false; _nickAvailable = false; });
      return;
    }

    await prefs.setProfileName(name);
    if (!mounted) return;
    _goHome();
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A18),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Rotating linear gradient
          AnimatedBuilder(
            animation: _gradCtrl,
            builder: (context, child) {
              final t = _gradCtrl.value * 2 * pi;
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(cos(t) * 0.8, sin(t) * 0.8),
                    end: Alignment(-cos(t) * 0.8, -sin(t) * 0.8),
                    colors: const [
                      Color(0xFF1A0A3E),
                      Color(0xFF050D2E),
                      Color(0xFF0A1628),
                      Color(0xFF001A2A),
                    ],
                  ),
                ),
              );
            },
          ),
          // Floating radial glow
          AnimatedBuilder(
            animation: _gradCtrl,
            builder: (context, child) {
              final t = _gradCtrl.value * 2 * pi + pi * 0.6;
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(sin(t) * 0.6, cos(t) * 0.5),
                    radius: 1.1,
                    colors: [
                      const Color(0xFF3A1070).withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: _pickingNick ? _buildNickPicker() : _buildSignIn(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignIn() {
    return Column(
      children: [
        const Spacer(flex: 3),
        const Text('EOS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 72,
            fontWeight: FontWeight.w900,
            letterSpacing: 10,
          ),
        ),
        const Spacer(flex: 2),
        if (_error != null) ...[
          Text(_error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _signIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4285F4),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF4285F4).withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _loading
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.login, size: 20),
                      SizedBox(width: 10),
                      Text('Войти через Google',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
          ),
        ),
        const Spacer(flex: 1),
      ],
    );
  }

  Widget _buildNickPicker() {
    final isValid = _nickAvailable == true && _nickCtrl.text.trim().isNotEmpty;
    return Column(
      children: [
        const Spacer(flex: 2),
        const Icon(Icons.person_outline, color: Colors.white54, size: 56),
        const SizedBox(height: 16),
        const Text('Выбери никнейм',
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Ник «$_googleName» уже занят.\nВыбери другой.',
          style: const TextStyle(color: Colors.white54, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const Spacer(flex: 1),
        TextField(
          controller: _nickCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Никнейм',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            suffixIcon: _checking
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)))
                : _nickAvailable == null
                    ? null
                    : Icon(
                        _nickAvailable! ? Icons.check_circle : Icons.cancel,
                        color: _nickAvailable! ? Colors.greenAccent : Colors.redAccent,
                      ),
          ),
          onChanged: (v) => _checkNickAvailability(v.trim()),
        ),
        if (_nickAvailable == false)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Этот ник уже занят', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
          ),
        if (_nickAvailable == true)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Ник свободен', style: TextStyle(color: Colors.greenAccent, fontSize: 13)),
          ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: (_loading || !isValid) ? null : _confirmNick,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.white24,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _loading
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.black54, strokeWidth: 2.5))
                : const Text('Продолжить',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const Spacer(flex: 2),
      ],
    );
  }
}
