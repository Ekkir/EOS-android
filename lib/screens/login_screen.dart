import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../services/prefs_service.dart';
import '../services/api_service.dart';
import '../services/update_service.dart';
import 'main_shell.dart';
import 'terminal_auth_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _google = GoogleSignIn(scopes: ['email', 'profile']);

  final _lines      = <_TLine>[];
  final _scrollCtrl = ScrollController();
  Timer? _cursorTimer;
  bool   _cursorOn     = true;
  bool   _bootDone     = false;
  bool   _loading      = false;
  bool   _pickingNick  = false;
  String? _error;

  String _googleEmail = '';
  String _googleName  = '';
  String _googlePhoto = '';
  final _nickCtrl       = TextEditingController();
  bool  _checking       = false;
  bool? _nickAvailable;

  static const _green  = Color(0xFF3DFF7A);
  static const _dim    = Color(0xFF1D6B38);
  static const _white  = Color(0xFFCCDDFF);
  static const _cyan   = Color(0xFF38D0FF);
  static const _red    = Color(0xFFFF4455);
  static const _yellow = Color(0xFFFFD060);

  static const _bg1 = Color(0xFF050C18);
  static const _bg2 = Color(0xFF080F1C);
  static const _bg3 = Color(0xFF050D14);

  @override
  void initState() {
    super.initState();
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 520),
        (_) { if (mounted) setState(() => _cursorOn = !_cursorOn); });
    _runBoot();
  }

  @override
  void dispose() {
    _cursorTimer?.cancel();
    _scrollCtrl.dispose();
    _nickCtrl.dispose();
    super.dispose();
  }

  Future<void> _runBoot() async {
    await _wait(300);
    _add('', _dim);
    _add('  EOS SECURE SYSTEM  ·  v${UpdateService.currentVersion}', _green);
    _add('  ───────────────────────────────────', _dim);
    _add('', _dim);
    await _wait(350);

    await _type('> kernel.boot()', _dim, 20);
    _add('    ✓ ядро загружено', _green);
    await _wait(80);

    await _type('> network.scan()', _dim, 20);
    _add('    ✓ 192.168.0.15  ONLINE', _green);
    await _wait(80);

    await _type('> auth.module.load()', _dim, 18);
    _add('    ✓ модуль авторизации готов', _green);
    await _wait(200);

    _add('', _dim);
    _add('  ───────────────────────────────────', _dim);
    _add('', _dim);
    await _type('  Требуется авторизация пользователя', _yellow, 16);
    _add('', _dim);

    if (mounted) setState(() => _bootDone = true);
  }

  Future<void> _signIn() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });

    _add('', _dim);
    await _type('> auth.login --provider=google', _cyan, 22);

    try {
      final account = await _google.signIn();
      if (account == null) {
        _add('    ✗ вход отменён пользователем', _red);
        if (mounted) setState(() { _loading = false; _error = ''; });
        return;
      }

      _googleEmail = account.email;
      _googleName  = account.displayName ?? '';
      _googlePhoto = account.photoUrl ?? '';

      _add('    ✓ Google аккаунт получен', _green);
      await _wait(120);

      if (!mounted) return;
      final prefs = context.read<PrefsService>();
      final api   = context.read<ApiService>();

      await prefs.setGoogleAccount(
        signedIn: true,
        email: _googleEmail,
        name: _googleName,
        photo: _googlePhoto,
      );

      await _type('> profile.sync(${_googleEmail.split('@').first})', _cyan, 18);

      final desiredName = _googleName.isNotEmpty ? _googleName : _googleEmail.split('@').first;
      final err = await api.syncProfile(_googleEmail, desiredName);

      if (err == 'nickname_taken') {
        _add('    ✗ никнейм «$desiredName» занят', _red);
        _add('', _dim);
        await _type('  Требуется другой никнейм', _yellow, 18);
        _nickCtrl.text = desiredName;
        if (mounted) setState(() { _loading = false; _pickingNick = true; });
        return;
      }

      _add('    ✓ профиль синхронизирован', _green);
      await prefs.setProfileName(desiredName);
      if (!mounted) return;
      await _checkApprovalAndNavigate(prefs, api, _googleEmail, desiredName);
    } catch (_) {
      _add('    ✗ ошибка подключения', _red);
      if (mounted) setState(() { _loading = false; _error = ''; });
    }
  }

  Future<void> _checkNickAvailability(String name) async {
    if (name.isEmpty) { setState(() => _nickAvailable = null); return; }
    setState(() { _checking = true; _nickAvailable = null; });
    final available = await context.read<ApiService>().checkNickname(name, excludeEmail: _googleEmail);
    if (mounted) setState(() { _checking = false; _nickAvailable = available; });
  }

  Future<void> _confirmNick() async {
    final name = _nickCtrl.text.trim();
    if (name.isEmpty || _nickAvailable == false) return;
    setState(() => _loading = true);

    _add('', _dim);
    await _type('> profile.set_name("$name")', _cyan, 18);

    final prefs = context.read<PrefsService>();
    final api   = context.read<ApiService>();
    final err   = await api.syncProfile(_googleEmail, name);

    if (err == 'nickname_taken') {
      _add('    ✗ никнейм занят', _red);
      if (mounted) setState(() { _loading = false; _nickAvailable = false; });
      return;
    }
    _add('    ✓ никнейм установлен', _green);
    await prefs.setProfileName(name);
    if (!mounted) return;
    await _checkApprovalAndNavigate(prefs, api, _googleEmail, name);
  }

  Future<void> _checkApprovalAndNavigate(
      PrefsService prefs, ApiService api, String email, String displayName) async {
    if (prefs.isAdmin) {
      _add('    ✓ администратор — полный доступ', _green);
      await _wait(300);
      _goHome();
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => TerminalAuthScreen(email: email, displayName: displayName),
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    ));
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const MainShell(),
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    ));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _add(String text, Color color) {
    if (!mounted) return;
    setState(() => _lines.add(_TLine(text, color)));
    _scrollEnd();
  }

  Future<void> _type(String text, Color color, int msPerChar) async {
    if (!mounted) return;
    setState(() => _lines.add(_TLine('', color)));
    _scrollEnd();
    for (int i = 0; i <= text.length; i++) {
      if (!mounted) return;
      setState(() => _lines[_lines.length - 1] = _TLine(text.substring(0, i), color));
      await Future.delayed(Duration(milliseconds: msPerChar));
    }
    _scrollEnd();
  }

  Future<void> _wait(int ms) => Future.delayed(Duration(milliseconds: ms));

  void _scrollEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 80), curve: Curves.easeOut);
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bg1, _bg2, _bg3],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 8),
                  itemCount: _lines.length + 1,
                  itemBuilder: (_, i) {
                    if (i == _lines.length) {
                      return Text(
                        _cursorOn ? '▋' : ' ',
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 14,
                            color: _green, height: 1.65),
                      );
                    }
                    final l = _lines[i];
                    return Text(l.text,
                        style: TextStyle(
                            fontFamily: 'monospace', fontSize: 13,
                            color: l.color, height: 1.65));
                  },
                ),
              ),
              if (_bootDone && !_pickingNick) _buildLoginButton(),
              if (_bootDone && _pickingNick)  _buildNickPanel(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
      child: GestureDetector(
        onTap: _loading ? null : _signIn,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: _loading
                ? _green.withValues(alpha: 0.06)
                : _green.withValues(alpha: 0.10),
            border: Border.all(
              color: _loading
                  ? _green.withValues(alpha: 0.3)
                  : _green.withValues(alpha: 0.55),
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Text('> ', style: TextStyle(
                  fontFamily: 'monospace', fontSize: 14,
                  color: _green.withValues(alpha: 0.7))),
              if (_loading) ...[
                SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(
                      color: _green.withValues(alpha: 0.7), strokeWidth: 1.5),
                ),
                const SizedBox(width: 10),
                Text('подключение...', style: TextStyle(
                    fontFamily: 'monospace', fontSize: 13,
                    color: _green.withValues(alpha: 0.7))),
              ] else ...[
                const Icon(Icons.login, color: _green, size: 16),
                const SizedBox(width: 10),
                const Text('Войти через Google',
                    style: TextStyle(
                        fontFamily: 'monospace', fontSize: 13,
                        color: _green, fontWeight: FontWeight.bold)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNickPanel() {
    final isValid = _nickAvailable == true && _nickCtrl.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('> nickname.set( __ )', style: TextStyle(
              fontFamily: 'monospace', fontSize: 13,
              color: _cyan.withValues(alpha: 0.8))),
          const SizedBox(height: 8),
          TextField(
            controller: _nickCtrl,
            autofocus: true,
            style: const TextStyle(fontFamily: 'monospace', color: _white, fontSize: 14),
            cursorColor: _green,
            decoration: InputDecoration(
              hintText: 'введи никнейм...',
              hintStyle: TextStyle(fontFamily: 'monospace',
                  color: _dim.withValues(alpha: 0.8), fontSize: 13),
              filled: true,
              fillColor: _green.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: _green.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: _green.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: _green.withValues(alpha: 0.7)),
              ),
              suffixIcon: _checking
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: _green.withValues(alpha: 0.6))))
                  : _nickAvailable == null
                      ? null
                      : Icon(
                          _nickAvailable! ? Icons.check : Icons.close,
                          color: _nickAvailable! ? _green : _red,
                          size: 18,
                        ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onChanged: (v) => _checkNickAvailability(v.trim()),
          ),
          const SizedBox(height: 6),
          if (_nickAvailable == false)
            Text('    ✗ никнейм занят', style: const TextStyle(
                fontFamily: 'monospace', fontSize: 12, color: _red)),
          if (_nickAvailable == true)
            Text('    ✓ никнейм свободен', style: const TextStyle(
                fontFamily: 'monospace', fontSize: 12, color: _green)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: (_loading || !isValid) ? null : _confirmNick,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isValid
                    ? _green.withValues(alpha: 0.12)
                    : _green.withValues(alpha: 0.04),
                border: Border.all(
                  color: isValid
                      ? _green.withValues(alpha: 0.6)
                      : _dim.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Text('> ', style: TextStyle(fontFamily: 'monospace', fontSize: 13,
                      color: isValid ? _green : _dim)),
                  if (_loading)
                    SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(
                            color: _green.withValues(alpha: 0.7), strokeWidth: 1.5))
                  else
                    Text('Продолжить', style: TextStyle(
                        fontFamily: 'monospace', fontSize: 13,
                        color: isValid ? _green : _dim,
                        fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TLine {
  final String text;
  final Color  color;
  const _TLine(this.text, this.color);
}
