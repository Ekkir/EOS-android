import 'dart:typed_data';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart' show accessRevokedStream;
import '../services/api_service.dart';
import '../services/nav_bar_controller.dart';
import '../services/prefs_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'friends_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'approval_pending_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with RouteAware {
  int _index = 0;
  Timer? _unreadTimer;
  Timer? _accessTimer;
  StreamSubscription<String>? _accessSub;
  bool _revokedOverlayShown = false;
  NavBarController? _navCtrl;


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nc = context.read<NavBarController>();
    final route = ModalRoute.of(context);
    if (route is PageRoute) nc.routeObserver.subscribe(this, route);
    _navCtrl = nc;
  }

  @override
  void didPopNext() {
    _navCtrl?.exitSection();
    _navCtrl?.show();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _navCtrl = context.read<NavBarController>();
      _navCtrl!.registerTabSwitch((i) => setState(() => _index = i));
      _navCtrl!.show();
      _fetchUnread();
      _loadAvatar();
    });
    _unreadTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) { if (mounted) _fetchUnread(); },
    );
    final prefs = context.read<PrefsService>();
    if (!prefs.isAdmin) {
      _accessTimer = Timer.periodic(
        const Duration(seconds: 45),
        (_) { if (mounted) _checkAccess(); },
      );
      _accessSub = accessRevokedStream.stream.listen((status) {
        if (!mounted || _revokedOverlayShown) return;
        _revokedOverlayShown = true;
        _accessTimer?.cancel();
        _showRevokedOverlay(status);
      });
    }
  }

  @override
  void dispose() {
    _navCtrl?.routeObserver.unsubscribe(this);
    _navCtrl?.hide();
    _navCtrl?.registerTabSwitch((_) {});
    _unreadTimer?.cancel();
    _accessTimer?.cancel();
    _accessSub?.cancel();
    super.dispose();
  }

  Future<void> _checkAccess() async {
    if (!mounted || _revokedOverlayShown) return;
    final prefs = context.read<PrefsService>();
    if (prefs.isAdmin || prefs.googleEmail.isEmpty) return;
    try {
      final api = context.read<ApiService>();
      final status = await api.getApprovalStatus(prefs.googleEmail);
      await prefs.setApprovalStatus(status);
      if (!mounted || _revokedOverlayShown) return;
      if (status == 'rejected' || status == 'suspended') {
        _revokedOverlayShown = true;
        _accessTimer?.cancel();
        _showRevokedOverlay(status);
      }
    } catch (_) {}
  }

  void _showRevokedOverlay(String status) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      pageBuilder: (ctx, _, __) => _RevokedOverlay(
        status: status,
        onContinue: () {
          Navigator.of(ctx).pop();
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const ApprovalPendingScreen(),
              transitionDuration: const Duration(milliseconds: 400),
              transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
            ),
            (_) => false,
          );
        },
      ),
    );
  }

  Future<void> _loadAvatar() async {
    final prefs = context.read<PrefsService>();
    final api = context.read<ApiService>();
    List<int>? bytes;
    if (prefs.googleSignedIn && prefs.googleEmail.isNotEmpty) {
      bytes = await api.getAvatarByEmail(prefs.googleEmail);
    } else if (prefs.profileName.isNotEmpty) {
      bytes = await api.getAvatarByName(prefs.profileName);
    }
    if (bytes != null && mounted) {
      _navCtrl?.setAvatarBytes(Uint8List.fromList(bytes!));
    }
  }

  Future<void> _fetchUnread() async {
    try {
      final api = context.read<ApiService>();
      final prefs = context.read<PrefsService>();
      final myName = prefs.profileName.isNotEmpty ? prefs.profileName : prefs.googleName;
      final channels = await api.getChannels(myName: myName);
      if (!mounted) return;
      final count = channels
          .where((ch) => ch.lastMessageId > prefs.getLastReadId(ch.id))
          .length;
      if (count != (_navCtrl?.unreadCount ?? 0)) {
        _navCtrl?.setUnreadCount(count);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AppThemeNotifier>();
    final bg = notifier.bgDecoration;
    return Scaffold(
      backgroundColor: bg != null ? Colors.transparent : notifier.current.bg,
      body: Stack(
        children: [
          if (bg != null) Positioned.fill(child: Container(decoration: bg)),
          IndexedStack(index: _index, children: [
            HomeScreen(),
            FriendsScreen(),
            SettingsScreen(),
            ProfileScreen(),
          ]),
        ],
      ),
    );
  }
}

class _RevokedOverlay extends StatefulWidget {
  final String status;
  final VoidCallback onContinue;
  const _RevokedOverlay({required this.status, required this.onContinue});

  @override
  State<_RevokedOverlay> createState() => _RevokedOverlayState();
}

class _RevokedOverlayState extends State<_RevokedOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;
  late final Animation<double> _gradAnim;
  Timer? _autoTimer;
  int _countdown = 5;


  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.88, end: 1.08).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    _gradAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_pulse);
    _autoTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _countdown--);
      if (_countdown <= 0) {
        _autoTimer?.cancel();
        widget.onContinue();
      }
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSuspended = widget.status == 'suspended';
    final color    = isSuspended ? const Color(0xFFFF9800) : const Color(0xFFFF3D3D);
    final icon     = isSuspended ? Icons.pause_circle_rounded : Icons.block_rounded;
    final title    = isSuspended ? 'Ключ доступа\nприостановлен' : 'Ключ доступа\nотозван';
    final sub      = isSuspended
        ? 'Администратор временно приостановил ваш доступ к системе'
        : 'Администратор отозвал ваш доступ к системе';
    final btnLabel = isSuspended ? 'Перейти к ожиданию' : 'Выйти из аккаунта';

    return AnimatedBuilder(
      animation: _gradAnim,
      builder: (_, __) {
        final t = _gradAnim.value * 2 * pi;
        return Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(cos(t) * 0.6, sin(t) * 0.6),
                end:   Alignment(-cos(t) * 0.6, -sin(t) * 0.6),
                colors: isSuspended
                    ? const [Color(0xFF0F0800), Color(0xFF180C00), Color(0xFF100900)]
                    : const [Color(0xFF100308), Color(0xFF1A0305), Color(0xFF0F0208)],
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _scale,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.08),
                        border: Border.all(color: color.withValues(alpha: 0.6), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.35),
                            blurRadius: 40,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(icon, size: 56, color: color),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      sub,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 14,
                        height: 1.55,
                      ),
                    ),
                  ),
                  const SizedBox(height: 56),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          _autoTimer?.cancel();
                          widget.onContinue();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color.withValues(alpha: 0.18),
                          foregroundColor: color,
                          side: BorderSide(color: color.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: Text(
                          '$btnLabel  ($_countdown)',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
