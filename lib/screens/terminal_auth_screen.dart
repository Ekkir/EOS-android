import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/prefs_service.dart';
import '../services/device_id_service.dart';
import '../services/update_service.dart';
import 'main_shell.dart';
import 'login_screen.dart';

class TerminalAuthScreen extends StatefulWidget {
  final String email;
  final String displayName;
  const TerminalAuthScreen({super.key, required this.email, required this.displayName});

  @override
  State<TerminalAuthScreen> createState() => _TerminalAuthScreenState();
}

class _TerminalAuthScreenState extends State<TerminalAuthScreen> {
  final _lines      = <_TermLine>[];
  final _scrollCtrl = ScrollController();
  Timer? _cursorTimer;
  Timer? _pollTimer;
  bool   _cursorOn  = true;
  bool   _flashRed  = false;

  static const _green  = Color(0xFF3DFF7A);
  static const _dim    = Color(0xFF1D6B38);
  static const _red    = Color(0xFFFF4455);
  static const _yellow = Color(0xFFFFD060);
  static const _white  = Color(0xFFCCDDFF);
  static const _cyan   = Color(0xFF38D0FF);

  // Gradient colors
  static const _bg1 = Color(0xFF050C18);
  static const _bg2 = Color(0xFF080F1C);
  static const _bg3 = Color(0xFF050D14);

  @override
  void initState() {
    super.initState();
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 520),
        (_) { if (mounted) setState(() => _cursorOn = !_cursorOn); });
    _startApproval();
    _runAnimation();
  }

  @override
  void dispose() {
    _cursorTimer?.cancel();
    _pollTimer?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // Register user on server (fire once)
  Future<void> _startApproval() async {
    try {
      final api    = context.read<ApiService>();
      final prefs  = context.read<PrefsService>();
      final device = await DeviceIdService.get();
      await prefs.setDeviceId(device.id);
      await api.requestApproval(
        email: widget.email,
        displayName: widget.displayName,
        deviceId: device.id,
        deviceName: device.name,
      );
    } catch (_) {}
  }

  // Start polling every 10s after animation finishes
  void _startPolling() {
    _poll();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _poll());
  }

  Future<void> _poll() async {
    if (!mounted) return;
    try {
      final api    = context.read<ApiService>();
      final prefs  = context.read<PrefsService>();
      final status = await api.getApprovalStatus(prefs.googleEmail);
      await prefs.setApprovalStatus(status);
      if (!mounted) return;
      if (status == 'approved') {
        _pollTimer?.cancel();
        _navigateHome();
      } else if (status == 'rejected') {
        _pollTimer?.cancel();
        _showRejectedDialog();
      }
    } catch (_) {}
  }

  void _navigateHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const MainShell(),
      transitionDuration: const Duration(milliseconds: 700),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  void _showRejectedDialog() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1520),
        title: const Text('Доступ отклонён',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Администратор отклонил ваш запрос на доступ.',
            style: TextStyle(color: Colors.white54)),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = context.read<PrefsService>();
              await prefs.clearGoogleAccount();
              await prefs.setApprovalStatus('pending');
              if (!mounted) return;
              Navigator.of(context).pushReplacement(PageRouteBuilder(
                pageBuilder: (_, __, ___) => const LoginScreen(),
                transitionDuration: const Duration(milliseconds: 400),
                transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
              ));
            },
            child: const Text('Выйти', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  // ── Animation ──────────────────────────────────────────────────────────────

  Future<void> _runAnimation() async {
    final rnd = Random();
    await _wait(300);

    // Header — minimal
    _add('', _dim);
    _add('  EOS SECURE SYSTEM  ·  v${UpdateService.currentVersion}', _green);
    _add('  ───────────────────────────────────', _dim);
    _add('', _dim);
    await _wait(400);

    // Auth
    await _type('> auth.init()', _dim, 22);
    await _wait(150);
    await _type('> user    ${widget.email}', _white, 32);
    await _wait(200);
    final pass = '•' * (10 + rnd.nextInt(6));
    await _type('> pass    $pass', _white, 65);
    await _wait(350);

    // System checks
    final checks = [
      'kernel.load',
      'fs.mount --encrypted',
      'ssl.verify',
      'session.scan',
      'device.fingerprint',
    ];
    for (final c in checks) {
      await _type('  $c', _dim, 9);
      _add('    ✓', _green);
      await _wait(35);
    }
    await _wait(300);

    // Security breach — clean
    _add('', _dim);
    await _flash();
    _add('  ⚠  SECURITY BREACH DETECTED', _red);
    _add('  ⚠  НАРУШЕНИЕ БЕЗОПАСНОСТИ', _red);
    await _wait(350);
    await _type('  security.protocol --activate', _yellow, 14);
    _add('    ✓ угроза нейтрализована', _green);
    await _wait(400);

    // Server connect
    _add('', _dim);
    await _type('> server.connect', _cyan, 22);
    await _wait(400);
    _add('    ✓ 192.168.0.15  AES-256-GCM', _green);
    await _wait(150);
    await _type('> auth.request --key', _cyan, 16);
    await _wait(280);
    _add('    ✓ запрос отправлен', _green);

    // Waiting
    _add('', _dim);
    _add('  ───────────────────────────────────', _dim);
    _add('', _dim);
    await _type('  ожидание ключа от администратора', _yellow, 18);
    _add('', _dim);

    _startPolling();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _add(String text, Color color) {
    if (!mounted) return;
    setState(() => _lines.add(_TermLine(text, color)));
    _scrollEnd();
  }

  Future<void> _type(String text, Color color, int msPerChar) async {
    if (!mounted) return;
    setState(() => _lines.add(_TermLine('', color)));
    _scrollEnd();
    for (int i = 0; i <= text.length; i++) {
      if (!mounted) return;
      setState(() => _lines[_lines.length - 1] = _TermLine(text.substring(0, i), color));
      await Future.delayed(Duration(milliseconds: msPerChar));
    }
    _scrollEnd();
  }

  Future<void> _flash() async {
    for (int i = 0; i < 2; i++) {
      if (!mounted) return;
      setState(() => _flashRed = true);
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      setState(() => _flashRed = false);
      await Future.delayed(const Duration(milliseconds: 65));
    }
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
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _flashRed
                ? const [Color(0xFF1A0508), Color(0xFF110508), Color(0xFF140308)]
                : const [_bg1, _bg2, _bg3],
          ),
        ),
        child: SafeArea(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
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
      ),
    );
  }
}

class _TermLine {
  final String text;
  final Color  color;
  const _TermLine(this.text, this.color);
}
