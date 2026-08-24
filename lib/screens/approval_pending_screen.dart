import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/prefs_service.dart';
import 'main_shell.dart';
import 'login_screen.dart';

class ApprovalPendingScreen extends StatefulWidget {
  const ApprovalPendingScreen({super.key});

  @override
  State<ApprovalPendingScreen> createState() => _ApprovalPendingScreenState();
}

class _ApprovalPendingScreenState extends State<ApprovalPendingScreen> {
  Timer? _pollTimer;
  Timer? _cursorTimer;
  Timer? _dotsTimer;

  final _lines      = <_TLine>[];
  final _scrollCtrl = ScrollController();
  bool   _cursorOn  = true;
  bool   _rejected  = false;
  int    _dots      = 0;

  static const _green  = Color(0xFF3DFF7A);
  static const _dim    = Color(0xFF1D6B38);
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
    _rejected = context.read<PrefsService>().approvalStatus == 'rejected';
    _runBoot();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cursorTimer?.cancel();
    _dotsTimer?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _runBoot() async {
    await _wait(200);
    _add('', _dim);
    _add('  EOS SECURE SYSTEM', _green);
    _add('  ───────────────────────────────────', _dim);
    _add('', _dim);
    await _wait(250);

    await _type('> access_key.verify()', _cyan, 20);

    if (_rejected) {
      await _showRejected();
    } else {
      _add('    Запрос отправлен администратору', _dim);
      _add('', _dim);
      await _type('  Ожидание подтверждения ключа доступа', _yellow, 15);
      _add('', _dim);
      _startDots();
    }
  }

  void _startDots() {
    if (!mounted) return;
    _add('> ', _dim);
    _dotsTimer?.cancel();
    _dotsTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (!mounted) return;
      _dots = (_dots + 1) % 4;
      setState(() {
        _lines[_lines.length - 1] = _TLine(
          '> ожидание${'.' * _dots}',
          _dim,
        );
      });
    });
  }

  Future<void> _showRejected() async {
    _dotsTimer?.cancel();
    _add('', _dim);
    _add('    ✗ ACCESS DENIED', _red);
    _add('', _dim);
    await _type('  Ключ доступа отозван', _red, 18);
    _add('  Администратор отозвал ваш доступ', _dim);
    _add('', _dim);
    await _type('> auth.logout --force', _dim, 16);
  }

  Future<void> _poll() async {
    if (!mounted) return;
    final prefs = context.read<PrefsService>();
    final api   = context.read<ApiService>();
    try {
      final status = await api.getApprovalStatus(prefs.googleEmail);
      await prefs.setApprovalStatus(status);
      if (!mounted) return;
      if (status == 'approved') {
        _dotsTimer?.cancel();
        _add('', _dim);
        _add('    ✓ ДОСТУП РАЗРЕШЁН', _green);
        await _wait(600);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainShell(),
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
        ));
      } else if (status == 'rejected' && !_rejected) {
        _dotsTimer?.cancel();
        setState(() => _rejected = true);
        await _showRejected();
      } else if ((status == 'pending' || status == 'suspended') && _rejected) {
        setState(() { _rejected = false; });
        _startDots();
      }
    } catch (_) {}
  }

  Future<void> _signOut() async {
    final prefs = context.read<PrefsService>();
    await prefs.clearGoogleAccount();
    await prefs.setApprovalStatus('pending');
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const LoginScreen(),
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
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
              _buildSignOutBtn(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignOutBtn() {
    final color = _rejected ? _red : _dim;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
      child: GestureDetector(
        onTap: _signOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            border: Border.all(color: color.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('> ', style: TextStyle(
                  fontFamily: 'monospace', fontSize: 13,
                  color: color.withValues(alpha: 0.7))),
              Text('Выйти из аккаунта',
                  style: TextStyle(
                      fontFamily: 'monospace', fontSize: 13,
                      color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TLine {
  final String text;
  final Color  color;
  const _TLine(this.text, this.color);
}
