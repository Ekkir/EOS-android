import 'dart:typed_data';
import 'dart:async';
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
import '../widgets/revoked_animation.dart';

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
        _goToRevoked(status);
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
        _goToRevoked(status);
      }
    } catch (_) {}
  }

  void _goToRevoked(String status) {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => RevokedAnimation(status: status),
        transitionDuration: Duration.zero,
      ),
      (_) => false,
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
