import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/nav_bar_controller.dart';
import '../services/music_player_notifier.dart';
import '../services/prefs_service.dart';
import '../theme/app_theme.dart';
import '../screens/vpn_configs_screen.dart';
import '../screens/vpn_split_tunneling_screen.dart';

class GlobalNavOverlay extends StatelessWidget {
  const GlobalNavOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavBarController>();
    final notifier = context.watch<AppThemeNotifier>();
    final t = notifier.current;
    final a = notifier.accent;
    final a2 = notifier.accent2;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    final prefs = context.watch<PrefsService>();
    final pillTransition = prefs.navPillTransition;
    final musicPlayer = context.watch<MusicPlayerNotifier>();

    Widget pill;
    if (musicPlayer.hasTrack) {
      pill = _MusicNavPill(t: t, a: a, a2: a2);
    } else {
      pill = switch (nav.section) {
        NavSection.map        => _MapNavPill(nav: nav, t: t, a: a, a2: a2),
        NavSection.vpn        => _VpnNavPill(nav: nav, t: t, a: a, a2: a2),
        NavSection.vpnConfigs => _VpnConfigsNavPill(nav: nav, t: t, a: a, a2: a2),
        NavSection.chatList   => _ChatNavPill(nav: nav, t: t, a: a, a2: a2),
        NavSection.home       => _HomeNavPill(nav: nav, t: t, a: a, a2: a2),
        NavSection.messenger  => const SizedBox.shrink(),
      };
    }

    if (pillTransition == 'fade') {
      pill = AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
        child: KeyedSubtree(
            key: ValueKey(musicPlayer.hasTrack ? 'music' : nav.section.toString()),
            child: pill),
      );
    }

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: IgnorePointer(
        ignoring: !nav.visible,
        child: AnimatedSlide(
          offset: nav.visible ? Offset.zero : const Offset(0, 1.5),
          duration: const Duration(milliseconds: 260),
          curve: nav.visible ? Curves.easeOutBack : Curves.easeInCubic,
          child: AnimatedOpacity(
            opacity: nav.visible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Material(
              color: Colors.transparent,
              child: Container(
                color: Colors.transparent,
                padding: EdgeInsets.fromLTRB(62, 6, 62, 18 + safeBottom),
                child: pill,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Главная (4 вкладки) ───────────────────────────────────────────────────────

class _HomeNavPill extends StatelessWidget {
  final NavBarController nav;
  final ThemeDef t;
  final Color a;
  final Color a2;
  const _HomeNavPill({required this.nav, required this.t, required this.a, required this.a2});

  static const _items = [
    (Icons.home_rounded,         Icons.home_outlined,          'Главная'),
    (Icons.people_rounded,       Icons.people_outline,         'Друзья'),
    (Icons.settings_rounded,     Icons.settings_outlined,      'Настройки'),
    (Icons.person_rounded,       Icons.person_outline_rounded, 'Профиль'),
  ];

  static const _itemsPixel = [
    (Icons.home_rounded,              Icons.home_outlined,              'Главная'),
    (Icons.group_rounded,             Icons.group_outlined,             'Друзья'),
    (Icons.tune_rounded,              Icons.tune_outlined,              'Настройки'),
    (Icons.account_circle_rounded,    Icons.account_circle_outlined,    'Профиль'),
  ];

  static const _itemsGlass = [
    (Icons.home_outlined,             Icons.home_outlined,              'Главная'),
    (Icons.group_outlined,            Icons.group_outlined,             'Друзья'),
    (Icons.tune_outlined,             Icons.tune_outlined,              'Настройки'),
    (Icons.account_circle_outlined,   Icons.account_circle_outlined,   'Профиль'),
  ];

  static const _itemsNeon = [
    (Icons.bolt,                      Icons.bolt,                       'Главная'),
    (Icons.groups_rounded,            Icons.groups_outlined,            'Друзья'),
    (Icons.auto_awesome,              Icons.auto_awesome_outlined,      'Настройки'),
    (Icons.account_circle_rounded,    Icons.account_circle_outlined,    'Профиль'),
  ];

  static const _itemsCyber = [
    (Icons.dashboard_rounded,         Icons.dashboard_outlined,         'Главная'),
    (Icons.people_rounded,            Icons.people_outlined,            'Друзья'),
    (Icons.settings_system_daydream,  Icons.settings_system_daydream,  'Настройки'),
    (Icons.badge_rounded,             Icons.badge_outlined,             'Профиль'),
  ];

  static const _itemsMinimal = [
    (Icons.home,                      Icons.home_outlined,              'Главная'),
    (Icons.group,                     Icons.group_outlined,             'Друзья'),
    (Icons.settings,                  Icons.settings_outlined,          'Настройки'),
    (Icons.person,                    Icons.person_outlined,            'Профиль'),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = nav.homeTabIndex;
    final src = t.id == 'pixel' ? _itemsPixel
        : (t.isLiquidGlass || t.glassy) ? _itemsGlass
        : t.neonGlow ? _itemsNeon
        : t.cyberpunk ? _itemsCyber
        : t.id == 'minimal' ? _itemsMinimal
        : _items;
    final count = src.length;

    final items = Row(
      children: [
        for (var i = 0; i < count; i++)
          Expanded(
            child: _NavItem(
              iconFilled:   src[i].$1,
              iconOutlined: src[i].$2,
              label:        src[i].$3,
              selected:     selected == i,
              badge:        i == 0 ? nav.unreadCount : 0,
              accent:       a,
              t:            t,
              avatarBytes:  i == (count - 1) ? nav.avatarBytes : null,
              onTap: () {
                final navState = nav.navigatorKey.currentState;
                if (navState != null && navState.canPop()) {
                  navState.popUntil((r) => r.isFirst);
                }
                nav.switchTab(i);
              },
            ),
          ),
      ],
    );

    final navAnim = context.watch<PrefsService>().navBarAnimation;

    if (navAnim != 'pill') {
      return _pill(t: t, a: a, a2: a2, child: items);
    }

    final isGlass = t.isLiquidGlass || t.glassy;

    return _pill(
      t: t, a: a, a2: a2,
      child: LayoutBuilder(
        builder: (_, box) {
          final iw = box.maxWidth / count;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                left: selected * iw + 5,
                top: 5,
                bottom: 5,
                width: iw - 10,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(t.id == 'pixel' ? 32 : 24),
                    gradient: isGlass
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.32),
                              Colors.white.withValues(alpha: 0.14),
                            ],
                          )
                        : t.id == 'pixel'
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  a.withValues(alpha: 0.38),
                                  a2.withValues(alpha: 0.28),
                                ],
                              )
                            : null,
                    color: (isGlass || t.id == 'pixel') ? null : a.withValues(alpha: 0.18),
                    border: Border.all(
                      color: isGlass
                          ? Colors.white.withValues(alpha: 0.50)
                          : a.withValues(alpha: t.id == 'pixel' ? 0.60 : 0.40),
                      width: t.id == 'pixel' ? 1.2 : 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isGlass
                            ? Colors.white.withValues(alpha: 0.20)
                            : a.withValues(alpha: t.id == 'pixel' ? 0.30 : 0.15),
                        blurRadius: t.id == 'pixel' ? 14 : 10,
                        offset: Offset.zero,
                      ),
                    ],
                  ),
                ),
              ),
              items,
            ],
          );
        },
      ),
    );
  }
}

// ── Карта ─────────────────────────────────────────────────────────────────────

class _MapNavPill extends StatelessWidget {
  final NavBarController nav;
  final ThemeDef t;
  final Color a;
  final Color a2;
  const _MapNavPill({required this.nav, required this.t, required this.a, required this.a2});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        nav.mapSharing ? Icons.location_on : Icons.location_off,
        'Геолокация',
        nav.mapSharing ? Colors.green : t.textSecondary,
        nav.mapToggle,
      ),
      (
        Icons.add_location_alt_outlined,
        'Событие',
        a,
        nav.mapAddEvent,
      ),
      (
        Icons.my_location,
        'Центр',
        nav.mapHasLocation ? a : t.textSecondary,
        nav.mapHasLocation ? nav.mapCenter : null,
      ),
    ];

    return _pill(
      t: t, a: a, a2: a2,
      child: Row(
        children: items
            .map((item) => Expanded(
                  child: GestureDetector(
                    onTap: item.$4,
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.$1, color: item.$3, size: 20),
                        const SizedBox(height: 2),
                        Text(item.$2,
                            style: TextStyle(color: t.textSecondary, fontSize: 9)),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ── VPN ───────────────────────────────────────────────────────────────────────

class _VpnNavPill extends StatelessWidget {
  final NavBarController nav;
  final ThemeDef t;
  final Color a;
  final Color a2;
  const _VpnNavPill({required this.nav, required this.t, required this.a, required this.a2});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.tune,
        'Туннелирование',
        a,
        () => nav.pushRoute(
            MaterialPageRoute(builder: (_) => const VpnSplitTunnelingScreen())),
      ),
      (
        Icons.settings_outlined,
        'Конфигурации',
        a,
        () => nav.pushRoute(
            MaterialPageRoute(builder: (_) => const VpnConfigsScreen())),
      ),
    ];

    return _pill(
      t: t, a: a, a2: a2,
      child: Row(
        children: items
            .map((item) => Expanded(
                  child: GestureDetector(
                    onTap: item.$4,
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.$1, color: item.$3, size: 20),
                        const SizedBox(height: 2),
                        Text(item.$2,
                            style: TextStyle(color: t.textSecondary, fontSize: 9)),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ── VPN Конфигурации (одна кнопка "Добавить") ────────────────────────────────

class _VpnConfigsNavPill extends StatelessWidget {
  final NavBarController nav;
  final ThemeDef t;
  final Color a;
  final Color a2;
  const _VpnConfigsNavPill({required this.nav, required this.t, required this.a, required this.a2});

  @override
  Widget build(BuildContext context) {
    return _pill(
      t: t, a: a, a2: a2,
      child: GestureDetector(
        onTap: nav.vpnConfigsAdd,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: a, size: 20),
            const SizedBox(width: 8),
            Text('Добавить конфигурацию',
                style: TextStyle(color: t.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ── Чаты (поиск + кнопка добавить) ───────────────────────────────────────────

class _ChatNavPill extends StatefulWidget {
  final NavBarController nav;
  final ThemeDef t;
  final Color a;
  final Color a2;
  const _ChatNavPill({required this.nav, required this.t, required this.a, required this.a2});

  @override
  State<_ChatNavPill> createState() => _ChatNavPillState();
}

class _ChatNavPillState extends State<_ChatNavPill> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _pill(
      t: widget.t, a: widget.a, a2: widget.a2,
      child: Row(
        children: [
          const SizedBox(width: 10),
          Icon(Icons.search, size: 18, color: widget.t.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _ctrl,
              style: TextStyle(color: widget.t.textPrimary, fontSize: 13),
              decoration: InputDecoration.collapsed(
                hintText: 'Поиск чатов...',
                hintStyle: TextStyle(color: widget.t.textSecondary, fontSize: 13),
              ),
              onChanged: (v) => widget.nav.chatSearch?.call(v.trim()),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: widget.nav.chatAdd,
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(Icons.edit_outlined, color: widget.a, size: 18),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ── Мессенджер (поле ввода + mic + send/attach кружки) ───────────────────────

class _MessengerNavArea extends StatelessWidget {
  final NavBarController nav;
  final ThemeDef t;
  final Color a;
  final Color a2;
  final double safeBottom;
  const _MessengerNavArea({
    required this.nav, required this.t,
    required this.a, required this.a2, required this.safeBottom,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reply banner
        if (nav.messengerReplyText != null)
          Container(
            color: a.withValues(alpha: 0.10),
            padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
            child: Row(
              children: [
                Container(width: 3, height: 32, color: a),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(nav.messengerReplySender ?? '',
                        style: TextStyle(color: a, fontSize: 12, fontWeight: FontWeight.w600)),
                      Text(nav.messengerReplyText ?? '',
                        style: TextStyle(color: t.textSecondary, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: t.textSecondary),
                  onPressed: nav.messengerCancelReply,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),
        // Edit banner
        if (nav.messengerIsEditing)
          Container(
            color: a.withValues(alpha: 0.10),
            padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
            child: Row(
              children: [
                Icon(Icons.edit, size: 16, color: a),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Редактирование',
                    style: TextStyle(color: a, fontSize: 13)),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: t.textSecondary),
                  onPressed: nav.messengerCancelEdit,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),
        // Input row
        Padding(
          padding: EdgeInsets.fromLTRB(10, 6, 10, 14 + safeBottom),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _GlassCircle(
                icon: Icons.attach_file,
                onTap: nav.messengerAttach,
                t: t, a: a,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _pill(
                  t: t, a: a, a2: a2,
                  flexible: true,
                  child: _MessengerPillContent(nav: nav, t: t, a: a),
                ),
              ),
              const SizedBox(width: 8),
              _GlassCircle(
                icon: nav.messengerBusy ? null : Icons.send_rounded,
                onTap: nav.messengerBusy ? null : nav.messengerSend,
                t: t, a: a,
                bluish: true,
                busy: nav.messengerBusy,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Содержимое плашки мессенджера ────────────────────────────────────────────

class _MessengerPillContent extends StatefulWidget {
  final NavBarController nav;
  final ThemeDef t;
  final Color a;
  const _MessengerPillContent({required this.nav, required this.t, required this.a});

  @override
  State<_MessengerPillContent> createState() => _MessengerPillContentState();
}

class _MessengerPillContentState extends State<_MessengerPillContent> {
  double _lockStartY = 0;
  double _lockOffset = 0; // отрицательное = вверх

  @override
  Widget build(BuildContext context) {
    final nav = widget.nav;
    final t = widget.t;
    final a = widget.a;
    final isRecording = nav.messengerIsRecording;
    final locked = nav.messengerRecordingLocked;
    final videoMode = nav.messengerVideoMode;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
            const SizedBox(width: 12),
            Expanded(
              child: isRecording
                  ? Row(
                      children: [
                        const _NavPulsingDot(),
                        const SizedBox(width: 8),
                        Text(
                          _fmtDuration(nav.messengerRecordingSeconds),
                          style: TextStyle(
                            color: t.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        if (!locked)
                          Text('↑ Закрепить',
                            style: TextStyle(color: t.textSecondary, fontSize: 12))
                        else
                          const Icon(Icons.lock, color: Colors.redAccent, size: 16),
                        const SizedBox(width: 8),
                      ],
                    )
                  : TextField(
                      controller: nav.messengerController,
                      style: TextStyle(color: t.textPrimary, fontSize: 13),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => nav.messengerSend?.call(),
                      decoration: InputDecoration.collapsed(
                        hintText: 'Сообщение...',
                        hintStyle: TextStyle(color: t.textSecondary, fontSize: 13),
                      ),
                    ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: isRecording ? null : nav.messengerMicTap,
              onLongPressStart: (d) {
                _lockStartY = d.globalPosition.dy;
                setState(() => _lockOffset = 0);
                nav.messengerMicStart?.call(d.globalPosition.dy);
              },
              onLongPressMoveUpdate: (d) {
                final dy = d.offsetFromOrigin.dy;
                setState(() => _lockOffset = dy.clamp(-80.0, 0.0));
                nav.messengerMicMove?.call(d.globalPosition.dy);
              },
              onLongPressEnd: (_) {
                setState(() => _lockOffset = 0);
                nav.messengerMicEnd?.call();
              },
              child: isRecording
                  ? Container(
                      width: 36, height: 36,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: [Color(0xFFFF6B6B), Color(0xFFC62828)],
                        ),
                      ),
                      child: Center(child: Icon(
                        locked ? Icons.lock : Icons.mic,
                        color: Colors.white, size: 18)),
                    )
                  : (widget.t.isLiquidGlass || widget.t.glassy)
                      ? ClipOval(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.28),
                                    Colors.white.withValues(alpha: 0.12),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  width: 0.8),
                              ),
                              child: Center(child: Icon(
                                videoMode ? Icons.videocam : Icons.mic,
                                color: a, size: 18)),
                            ),
                          ),
                        )
                      : Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: a.withValues(alpha: 0.15),
                            shape: BoxShape.circle),
                          child: Center(child: Icon(
                            videoMode ? Icons.videocam : Icons.mic,
                            color: a, size: 18)),
                        ),
            ),
            const SizedBox(width: 6),
          ],
        ),
        ),
        // Lock indicator: плавающий замок над кнопкой микрофона при записи
        if (isRecording && !locked && _lockOffset < -8)
          Positioned(
            right: 6 + 9,
            bottom: 36 + (-_lockOffset).clamp(0.0, 80.0),
            child: Icon(
              Icons.lock_outline,
              color: Colors.redAccent.withValues(alpha: 0.8),
              size: 18,
            ),
          ),
      ],
    );
  }

  String _fmtDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

// ── Стеклянный / непрозрачный кружок (attach / send) ─────────────────────────

class _GlassCircle extends StatelessWidget {
  final IconData? icon;
  final VoidCallback? onTap;
  final ThemeDef t;
  final Color a;
  final bool bluish;
  final bool busy;

  const _GlassCircle({
    required this.icon,
    required this.onTap,
    required this.t,
    required this.a,
    this.bluish = false,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = bluish ? Colors.lightBlueAccent : a;
    final isGlass = t.isLiquidGlass || t.glassy;

    Widget content;
    if (busy) {
      content = SizedBox(
        width: 44, height: 44,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: bluish ? Colors.lightBlueAccent : a,
          ),
        ),
      );
    } else {
      content = SizedBox(
        width: 44, height: 44,
        child: Icon(icon, color: iconColor, size: 20),
      );
    }

    if (isGlass) {
      return GestureDetector(
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.22),
                    Colors.white.withValues(alpha: 0.10),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.28),
                  width: 0.8,
                ),
              ),
              child: content,
            ),
          ),
        ),
      );
    }

    // Непрозрачные темы
    final bgColor = bluish
        ? Colors.blueAccent.withValues(alpha: 0.85)
        : t.nav.withValues(alpha: 0.95);
    final borderColor = bluish
        ? Colors.lightBlueAccent.withValues(alpha: 0.40)
        : t.cardBorder;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor,
          border: Border.all(color: borderColor, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: busy
            ? Padding(
                padding: const EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: bluish ? Colors.white : a,
                ),
              )
            : Icon(icon, color: bluish ? Colors.white : a, size: 20),
      ),
    );
  }
}

// ── Пульсирующая точка (для overlay, дублирует класс из messenger_screen) ────

class _NavPulsingDot extends StatefulWidget {
  const _NavPulsingDot();
  @override
  State<_NavPulsingDot> createState() => _NavPulsingDotState();
}

class _NavPulsingDotState extends State<_NavPulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 10, height: 10,
        decoration: const BoxDecoration(
            color: Colors.redAccent, shape: BoxShape.circle),
      ),
    );
  }
}

// ── Элемент вкладки ──────────────────────────────────────────────────────────

class _NavItem extends StatefulWidget {
  final IconData iconFilled;
  final IconData iconOutlined;
  final String label;
  final bool selected;
  final int badge;
  final Color accent;
  final ThemeDef t;
  final Uint8List? avatarBytes;
  final VoidCallback onTap;

  const _NavItem({
    required this.iconFilled,
    required this.iconOutlined,
    required this.label,
    required this.selected,
    required this.badge,
    required this.accent,
    required this.t,
    required this.onTap,
    this.avatarBytes,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(_NavItem old) {
    super.didUpdateWidget(old);
    if (!old.selected && widget.selected) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navAnim = context.watch<PrefsService>().navBarAnimation;
    final color = widget.selected ? widget.accent : widget.t.textSecondary;
    final icon  = widget.selected ? widget.iconFilled : widget.iconOutlined;

    Widget iconWidget = widget.avatarBytes != null
        ? Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.selected ? widget.accent : Colors.transparent,
                width: 2,
              ),
              image: DecorationImage(
                image: MemoryImage(widget.avatarBytes!),
                fit: BoxFit.cover,
              ),
            ),
          )
        : Icon(icon, color: color, size: 21);

    iconWidget = _applyNavAnim(navAnim, iconWidget);

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                iconWidget,
                if (widget.badge > 0)
                  Positioned(
                    top: -5, right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: widget.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.badge > 99 ? '99+' : '${widget.badge}',
                        style: const TextStyle(
                          color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: color,
                fontSize: widget.selected ? 10 : 9,
                fontWeight: widget.selected ? FontWeight.bold : FontWeight.normal,
              ),
              child: Text(widget.label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _applyNavAnim(String navAnim, Widget child) {
    switch (navAnim) {
      case 'bounce':
        return ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1.15).animate(
            CurvedAnimation(parent: _ctrl, curve: const ElasticOutCurve(0.9))),
          child: child,
        );
      case 'pulse':
        return AnimatedBuilder(
          animation: _anim,
          builder: (_, c) => Transform.scale(
            scale: widget.selected ? 1.0 + 0.32 * sin(pi * _anim.value) : 1.0,
            child: c,
          ),
          child: child,
        );
      case 'glow':
        return AnimatedBuilder(
          animation: _anim,
          builder: (_, c) => Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: widget.selected
                  ? [BoxShadow(
                      color: widget.accent.withValues(alpha: 0.55 * _anim.value),
                      blurRadius: 20, spreadRadius: 2)]
                  : [],
            ),
            child: c,
          ),
          child: child,
        );
      case 'morph':
        return AnimatedBuilder(
          animation: _anim,
          builder: (_, c) => Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..rotateZ(widget.selected ? _anim.value * 0.18 : 0)
              ..scale(widget.selected ? 1.0 + _anim.value * 0.15 : 1.0),
            child: c,
          ),
          child: child,
        );
      case 'pill':
        return child;
      case 'scale':
      default:
        return AnimatedScale(
          scale: widget.selected ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: child,
        );
    }
  }
}

// ── Мини-плеер ───────────────────────────────────────────────────────────────

class _MusicNavPill extends StatefulWidget {
  final ThemeDef t;
  final Color a;
  final Color a2;
  const _MusicNavPill({required this.t, required this.a, required this.a2});

  @override
  State<_MusicNavPill> createState() => _MusicNavPillState();
}

class _MusicNavPillState extends State<_MusicNavPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _menuCtrl;
  late final Animation<double> _a1, _a2, _a3;
  bool _menuOpen = false;

  @override
  void initState() {
    super.initState();
    _menuCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
    _a1 = CurvedAnimation(parent: _menuCtrl,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack));
    _a2 = CurvedAnimation(parent: _menuCtrl,
        curve: const Interval(0.1, 0.75, curve: Curves.easeOutBack));
    _a3 = CurvedAnimation(parent: _menuCtrl,
        curve: const Interval(0.2, 0.85, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _menuCtrl.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    if (_menuOpen) {
      _menuCtrl.reverse().then((_) {
        if (mounted) setState(() => _menuOpen = false);
      });
    } else {
      setState(() => _menuOpen = true);
      _menuCtrl.forward();
    }
  }

  void _selectMode(PlayMode mode) {
    context.read<MusicPlayerNotifier>().setPlayMode(mode);
    _menuCtrl.reverse().then((_) {
      if (mounted) setState(() => _menuOpen = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<MusicPlayerNotifier>();
    final t = widget.t;
    final a = widget.a;
    final a2 = widget.a2;

    // Меню и пилюля в Column: Column расширяет hit-test область вверх,
    // поэтому пункты меню получают тапы (в отличие от overflow у Stack).
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: _menuOpen
              ? Padding(
                  padding: const EdgeInsets.only(left: 6, bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildModeItem(PlayMode.one, Icons.repeat_one, 'Один трек', _a1, player.playMode == PlayMode.one, t, a),
                      const SizedBox(height: 8),
                      _buildModeItem(PlayMode.loop, Icons.repeat, 'По кругу', _a2, player.playMode == PlayMode.loop, t, a),
                      const SizedBox(height: 8),
                      _buildModeItem(PlayMode.shuffleLoop, Icons.shuffle, 'Перемешать', _a3, player.playMode == PlayMode.shuffleLoop, t, a),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        _buildPill(player, t, a, a2),
      ],
    );
  }

  Widget _buildModeItem(PlayMode mode, IconData icon, String label,
      Animation<double> anim, bool selected, ThemeDef t, Color a) {
    return ScaleTransition(
      scale: anim,
      alignment: Alignment.bottomLeft,
      child: FadeTransition(
        opacity: anim,
        child: GestureDetector(
          onTap: () => _selectMode(mode),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? a.withValues(alpha: 0.28) : t.nav.withValues(alpha: 0.92),
                border: Border.all(
                  color: selected ? a.withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.18),
                  width: selected ? 1.5 : 0.8,
                ),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.32), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: Icon(icon, color: selected ? a : t.textSecondary, size: 20),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: t.nav.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 8)],
                border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.8),
              ),
              child: Text(label, style: TextStyle(
                  color: selected ? a : t.textPrimary, fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildPill(MusicPlayerNotifier player, ThemeDef t, Color a, Color a2) {
    final progress = player.progress;
    final isGlass = t.isLiquidGlass || t.glassy;

    // Кружок режима (слева)
    final modeBtn = GestureDetector(
      onTap: _toggleMenu,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: SizedBox(width: 40, height: 40, child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 34, height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: a.withValues(alpha: _menuOpen ? 0.28 : 0.10),
              border: Border.all(color: a.withValues(alpha: _menuOpen ? 0.55 : 0.25), width: 0.8),
            ),
            child: Icon(switch (player.playMode) {
              PlayMode.one => Icons.repeat_one,
              PlayMode.loop => Icons.repeat,
              PlayMode.shuffleLoop => Icons.shuffle,
            }, color: a, size: 16),
          ),
        )),
      ),
    );

    // Кружок play/pause (справа)
    final playBtn = GestureDetector(
      onTap: player.onToggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: a.withValues(alpha: 0.18),
            border: Border.all(color: a.withValues(alpha: 0.38), width: 0.8),
          ),
          child: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow, color: a, size: 22),
        ),
      ),
    );

    // Область заголовка с seek по тапу
    final titleArea = Expanded(
      child: LayoutBuilder(builder: (ctx, box) => GestureDetector(
        onTapUp: (d) {
          player.onSeek?.call((d.localPosition.dx / box.maxWidth).clamp(0.0, 1.0));
        },
        behavior: HitTestBehavior.opaque,
        child: Center(child: Text(
          player.title ?? '',
          style: TextStyle(color: t.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        )),
      )),
    );

    final row = Row(children: [modeBtn, titleArea, playBtn]);
    final prog = _progressLayer(progress, a);

    if (isGlass) {
      return SizedBox(
        height: 54,
        child: ClipRRect(borderRadius: BorderRadius.circular(32), child: Stack(children: [
          Positioned.fill(child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Colors.white.withValues(alpha: 0.18), Colors.white.withValues(alpha: 0.08)],
            ))),
          )),
          prog,
          Positioned.fill(child: IgnorePointer(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white.withValues(alpha: 0.20), width: 0.8), borderRadius: BorderRadius.circular(32))))),
          row,
        ])),
      );
    } else if (t.neonGlow) {
      return Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: a2.withValues(alpha: 0.50)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 20, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(32), child: Stack(children: [
          Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14), child: Container(color: t.nav.withValues(alpha: 0.90)))),
          prog, row,
        ])),
      );
    } else if (t.id == 'pixel') {
      return Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [
              Color.lerp(t.nav, a, 0.30)!,
              Color.lerp(t.nav, a2, 0.24)!,
            ],
          ),
          border: Border.all(color: a.withValues(alpha: 0.42), width: 1.2),
          boxShadow: [
            BoxShadow(color: a.withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 4)),
            BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 3)),
          ],
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(50), child: Stack(children: [prog, row])),
      );
    } else {
      return Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: t.cyberpunk ? a.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.08), width: t.cyberpunk ? 1.0 : 0.8),
          boxShadow: [
            BoxShadow(color: t.cyberpunk ? a.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.30), blurRadius: t.cyberpunk ? 20 : 24, offset: const Offset(0, 4)),
            if (t.cyberpunk) BoxShadow(color: a2.withValues(alpha: 0.12), blurRadius: 40),
          ],
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(32), child: Stack(children: [
          Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: Container(decoration: BoxDecoration(color: t.cyberpunk ? Colors.black.withValues(alpha: 0.82) : t.nav.withValues(alpha: 0.90), borderRadius: BorderRadius.circular(32))))),
          prog, row,
        ])),
      );
    }
  }

  Widget _progressLayer(double progress, Color a) {
    final p = progress.clamp(0.0, 1.0);
    if (p < 0.01) return const Positioned.fill(child: SizedBox());
    final soft = (p - 0.07).clamp(0.0, p - 0.001);
    return Positioned.fill(child: IgnorePointer(child: Container(decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.centerLeft, end: Alignment.centerRight,
        stops: [0.0, soft, p, 1.0],
        colors: [a.withValues(alpha: 0.28), a.withValues(alpha: 0.18), a.withValues(alpha: 0.03), Colors.transparent],
      ),
    ))));
  }
}

// ── Плавающая кнопка паузы/плея (верхний правый угол, вне раздела музыки) ────

class MusicFloatButton extends StatelessWidget {
  const MusicFloatButton({super.key});

  @override
  Widget build(BuildContext context) {
    final player  = context.watch<MusicPlayerNotifier>();
    if (!player.hasTrack) return const SizedBox.shrink();

    final notifier = context.watch<AppThemeNotifier>();
    final t = notifier.current;
    final a = notifier.accent;
    final safeTop = MediaQuery.of(context).padding.top;
    final isGlass = t.isLiquidGlass || t.glassy;

    final icon = Icon(
      player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
      color: a, size: 20,
    );

    Widget btn;
    if (isGlass) {
      btn = ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Colors.white.withValues(alpha: 0.28), Colors.white.withValues(alpha: 0.12)],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 0.8),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 12, offset: const Offset(0, 3))],
            ),
            child: Center(child: icon),
          ),
        ),
      );
    } else {
      btn = Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: t.nav.withValues(alpha: 0.93),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 0.8),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.32), blurRadius: 12, offset: const Offset(0, 3))],
        ),
        child: Center(child: icon),
      );
    }

    return Positioned(
      top: safeTop + 8,
      right: 12,
      child: GestureDetector(onTap: player.onToggle, child: btn),
    );
  }
}

// ── Общая обёртка плашки ─────────────────────────────────────────────────────

Widget _pill({
  required ThemeDef t,
  required Color a,
  required Color a2,
  required Widget child,
  bool flexible = false,
}) {
  if (t.isLiquidGlass || t.glassy) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.18),
                      Colors.white.withValues(alpha: 0.08),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20),
                    width: 0.8,
                  ),
                  borderRadius: BorderRadius.circular(32),
                ),
              ),
            ),
          ),
          SizedBox(height: flexible ? null : 54, child: child),
        ],
      ),
    );
  } else if (t.neonGlow) {
    return Container(
      height: flexible ? null : 54,
      constraints: flexible ? const BoxConstraints(minHeight: 54) : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: a2.withValues(alpha: 0.50)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            color: t.nav.withValues(alpha: 0.90),
            child: child,
          ),
        ),
      ),
    );
  } else if (t.id == 'pixel') {
    return Container(
      height: flexible ? null : 54,
      constraints: flexible ? const BoxConstraints(minHeight: 54) : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(t.nav, a, 0.30)!,
            Color.lerp(t.nav, a2, 0.24)!,
          ],
        ),
        border: Border.all(color: a.withValues(alpha: 0.42), width: 1.2),
        boxShadow: [
          BoxShadow(color: a.withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 3)),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(50), child: child),
    );
  } else {
    return Container(
      height: flexible ? null : 54,
      constraints: flexible ? const BoxConstraints(minHeight: 54) : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: t.cyberpunk
              ? a.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.08),
          width: t.cyberpunk ? 1.0 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: t.cyberpunk
                ? a.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.30),
            blurRadius: t.cyberpunk ? 20 : 24,
            offset: const Offset(0, 4),
          ),
          if (t.cyberpunk)
            BoxShadow(color: a2.withValues(alpha: 0.12), blurRadius: 40),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: t.cyberpunk
                  ? Colors.black.withValues(alpha: 0.82)
                  : t.nav.withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(32),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
