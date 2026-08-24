import 'dart:io';
import 'dart:math' show sin, pi, sqrt, Random;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vpn_config.dart';
import '../providers/vpn_provider.dart';
import '../services/nav_bar_controller.dart';
import '../services/prefs_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_surface.dart';
import 'vpn_configs_screen.dart';
import 'vpn_split_tunneling_screen.dart';

class VpnScreen extends StatefulWidget {
  const VpnScreen({super.key});

  @override
  State<VpnScreen> createState() => _VpnScreenState();
}

class _VpnScreenState extends State<VpnScreen> with TickerProviderStateMixin, RouteAware {
  late final AnimationController _pulseCtrl;
  late final AnimationController _matrixCtrl;
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
  void didPopNext() => _enterSection();

  void _enterSection() {
    _navCtrl?.enterVpn(
      splitTunnel: () => _navCtrl!.pushRoute(
          MaterialPageRoute(builder: (_) => const VpnSplitTunnelingScreen())),
      configs: () => _navCtrl!.pushRoute(
          MaterialPageRoute(builder: (_) => const VpnConfigsScreen())),
    );
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _matrixCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _enterSection();
    });
  }

  @override
  void dispose() {
    _navCtrl?.routeObserver.unsubscribe(this);
    _navCtrl?.exitSection();
    _pulseCtrl.dispose();
    _matrixCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VpnProvider>();
    final notifier = context.watch<AppThemeNotifier>();
    final t = notifier.current;
    final a = notifier.accent;
    final a2 = notifier.accent2;

    if (vpn.isBusy) {
      if (!_pulseCtrl.isAnimating) _pulseCtrl.repeat();
    } else {
      if (_pulseCtrl.isAnimating) { _pulseCtrl.stop(); _pulseCtrl.reset(); }
    }
    if (vpn.isConnected) {
      if (!_matrixCtrl.isAnimating) _matrixCtrl.repeat();
    } else {
      if (_matrixCtrl.isAnimating) { _matrixCtrl.stop(); _matrixCtrl.reset(); }
    }

    return Scaffold(
      backgroundColor: t.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: (t.isLiquidGlass || t.glassy)
            ? ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: AppBar(
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    title: Text('VPN',
                        style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
                    iconTheme: IconThemeData(color: t.textPrimary),
                  ),
                ),
              )
            : AppBar(
                backgroundColor: t.nav,
                title: Text('VPN',
                    style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
                iconTheme: IconThemeData(color: t.textPrimary),
              ),
      ),
      body: Stack(
        children: [
          if (t.isLiquidGlass)
            Positioned.fill(child: AmbientGlow(accent: a)),
          if (t.isLiquidGlass || t.glassy)
            Positioned.fill(
                child: Container(color: Colors.black.withValues(alpha: 0.15))),
          Positioned(
            top: 40, left: 0, right: 0,
            child: Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      a.withValues(alpha: vpn.isConnected ? 0.18 : 0.09),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: Listenable.merge([_pulseCtrl, _matrixCtrl]),
                        builder: (_, child) => Stack(
                          alignment: Alignment.center,
                          children: [
                            if (vpn.isConnected)
                              SizedBox(
                                width: 230, height: 230,
                                child: CustomPaint(
                                  painter: (t.isLiquidGlass || t.glassy)
                                      ? _GradientRingPainter(
                                          time: _matrixCtrl.value, accent: a, accent2: a2)
                                      : _MatrixPainter(time: _matrixCtrl.value),
                                ),
                              ),
                            if (vpn.isBusy) ...[
                              _PulseRing(
                                scale: 1.0 + _pulseCtrl.value * 0.5,
                                opacity: (1.0 - _pulseCtrl.value).clamp(0.0, 1.0),
                                color: a,
                              ),
                              _PulseRing(
                                scale: 1.0 + ((_pulseCtrl.value + 0.5) % 1.0) * 0.5,
                                opacity: (1.0 - (_pulseCtrl.value + 0.5) % 1.0).clamp(0.0, 1.0),
                                color: a,
                              ),
                            ],
                            child!,
                          ],
                        ),
                        child: _ConnectButton(vpn: vpn, t: t),
                      ),
                      const SizedBox(height: 20),
                      _StatusLabel(vpn: vpn, t: t),
                      const SizedBox(height: 32),
                      if (vpn.isConnected) _TrafficCard(vpn: vpn, t: t),
                      if (vpn.errorMessage != null)
                        _ErrorCard(msg: vpn.errorMessage!, t: t),
                    ],
                  ),
                ),
              ),
              if (vpn.configs.isNotEmpty) _ConfigsList(vpn: vpn, t: t, a: a, a2: a2),
              const SizedBox(height: 110),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectButton extends StatelessWidget {
  final VpnProvider vpn;
  final ThemeDef t;
  const _ConnectButton({required this.vpn, required this.t});

  @override
  Widget build(BuildContext context) {
    final connected = vpn.isConnected;
    final busy = vpn.isBusy;

    Color btnColor;
    if (connected) {
      btnColor = const Color(0xFF00C853);
    } else if (busy) {
      btnColor = const Color(0xFF7B2FF7).withValues(alpha: 0.6);
    } else {
      btnColor = const Color(0xFF7B2FF7);
    }

    return GestureDetector(
      onTap: busy ? null : () {
        if (vpn.activeConfig == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Нет конфигурации VPN')),
          );
          return;
        }
        vpn.toggle();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: btnColor,
          boxShadow: [
            BoxShadow(
              color: btnColor.withValues(alpha: 0.45),
              blurRadius: 32,
              spreadRadius: 4,
            ),
          ],
        ),
        child: busy
            ? const Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              )
            : Icon(
                connected ? Icons.lock : Icons.lock_open,
                color: Colors.white,
                size: 52,
              ),
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  final VpnProvider vpn;
  final ThemeDef t;
  const _StatusLabel({required this.vpn, required this.t});

  @override
  Widget build(BuildContext context) {
    final config = vpn.activeConfig;
    return Column(
      children: [
        Text(
          vpn.status.label,
          style: TextStyle(
            color: vpn.isConnected ? const Color(0xFF00C853) : t.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (config != null) ...[
          const SizedBox(height: 4),
          Text(config.name, style: TextStyle(color: t.textSecondary, fontSize: 13)),
        ],
      ],
    );
  }
}

class _TrafficCard extends StatelessWidget {
  final VpnProvider vpn;
  final ThemeDef t;
  const _TrafficCard({required this.vpn, required this.t});

  @override
  Widget build(BuildContext context) {
    final inner = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _TrafficItem(icon: Icons.arrow_downward, label: 'Получено',
            value: vpn.stats.rxFormatted, color: const Color(0xFF2979FF)),
        Container(
          width: 1,
          height: 36,
          color: (t.isLiquidGlass || t.glassy)
              ? Colors.white.withValues(alpha: 0.15)
              : t.cardBorder,
        ),
        _TrafficItem(icon: Icons.arrow_upward, label: 'Отправлено',
            value: vpn.stats.txFormatted, color: const Color(0xFF7B2FF7)),
      ],
    );

    final notifier = context.read<AppThemeNotifier>();
    final a = notifier.accent;
    final a2 = notifier.accent2;

    if (t.isLiquidGlass || t.glassy) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: inner,
          ),
        ),
      );
    } else if (t.cyberpunk) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: a.withValues(alpha: 0.5), width: 1),
          boxShadow: [
            BoxShadow(color: a.withValues(alpha: 0.20), blurRadius: 14),
            BoxShadow(color: a2.withValues(alpha: 0.12), blurRadius: 24),
          ],
        ),
        child: inner,
      );
    } else if (t.neonGlow) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: a2.withValues(alpha: 0.55), width: 1),
        ),
        child: inner,
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.cardBorder),
      ),
      child: inner,
    );
  }
}

class _TrafficItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _TrafficItem({required this.icon, required this.label,
      required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AnimatedArrow(isUp: icon == Icons.arrow_upward, color: color, value: value),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }
}

class _AnimatedArrow extends StatefulWidget {
  final bool isUp;
  final Color color;
  final String value;
  const _AnimatedArrow({required this.isUp, required this.color, required this.value});

  @override
  State<_AnimatedArrow> createState() => _AnimatedArrowState();
}

class _AnimatedArrowState extends State<_AnimatedArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) _ctrl.reset();
    });
  }

  @override
  void didUpdateWidget(_AnimatedArrow old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final direction = widget.isUp ? -1.0 : 1.0;
    final iconData = widget.isUp ? Icons.arrow_upward : Icons.arrow_downward;
    return SizedBox(
      width: 18,
      height: 18,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) {
          final t = _ctrl.value;
          if (t == 0.0) {
            return Icon(iconData, color: widget.color, size: 18);
          }
          final dy = direction * (t - 0.5) * 20.0;
          final opacity = sin(t * pi).clamp(0.0, 1.0);
          return ClipRect(
            child: Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Icon(iconData, color: widget.color, size: 18),
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- Matrix shield painter ---

class _ColCfg {
  final double x, speed, phase, redPhase;
  final bool isRedCol;
  const _ColCfg({
    required this.x, required this.speed, required this.phase,
    required this.isRedCol, required this.redPhase,
  });
}

class _MatrixPainter extends CustomPainter {
  final double time;

  static const _chars = '0101001101001011ABCDEF{}[]<>/\\;:=@!?#';
  static const _colCount = 14;
  static const _canvasW = 230.0;
  static const _colW = _canvasW / _colCount;
  static const _charH = 13.0;
  static const _fontSize = 9.0;
  static const _trailLen = 6;
  static const _btnR = 72.0;
  static const _glitchZone = 42.0;

  static final List<_ColCfg> _cols = _genCols();

  static List<_ColCfg> _genCols() {
    final rng = Random(999);
    return List.generate(_colCount, (i) => _ColCfg(
      x: i * _colW + _colW / 2,
      speed: (rng.nextInt(2) + 1).toDouble(),
      phase: rng.nextDouble(),
      isRedCol: i == 2 || i == 6 || i == 11,
      redPhase: rng.nextDouble(),
    ));
  }

  _MatrixPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    for (final col in _cols) {
      final headFrac = (time * col.speed + col.phase) % 1.0;
      final headY = headFrac * (size.height + _trailLen * _charH) - _trailLen * _charH;

      final redFrac = (time * 0.6 + col.redPhase) % 1.0;
      final isRed = col.isRedCol && redFrac < 0.30;

      for (var i = 0; i < _trailLen; i++) {
        final y = headY + i * _charH;
        if (y < -_charH || y > size.height + _charH) continue;

        final dx = col.x - cx;
        final dy = y - cy;
        final dist = sqrt(dx * dx + dy * dy);

        if (dist < _btnR - 4) continue;

        final brightness = (1.0 - i / _trailLen).clamp(0.0, 1.0);
        if (brightness < 0.02) continue;

        final charIdx = ((col.x.toInt() * 13 + y.toInt() * 7 + (time * 60).toInt()) & 0xFFFF) % _chars.length;

        if (isRed) {
          final distFromEdge = dist - _btnR;

          if (distFromEdge < _glitchZone) {
            // Глитч: высокочастотная осцилляция red↔green
            final g = 1.0 - (distFromEdge / _glitchZone).clamp(0.0, 1.0);
            final osc = sin((time * 22 + col.x * 0.4 + y * 0.06) * pi * 2);
            // Чем ближе к кнопке — тем сильнее зелёный побеждает
            final greenWins = osc > (1.0 - 2.2 * g);

            // Дрожание позиции
            final jitter = g * 3.5 * sin((time * 40 + i) * pi * 2);
            final renderX = col.x + jitter;

            final Color charColor;
            if (greenWins) {
              charColor = const Color(0xFF00E676).withValues(alpha: (brightness * 0.95).clamp(0, 1));
            } else {
              charColor = const Color(0xFFFF1744).withValues(alpha: (brightness * (1 - g * 0.4)).clamp(0, 1));
            }
            _drawChar(canvas, _chars[charIdx], renderX, y, charColor);
          } else {
            // За пределами глитч-зоны — чисто красный
            final color = const Color(0xFFFF1744).withValues(alpha: (brightness * 0.85).clamp(0, 1));
            _drawChar(canvas, _chars[charIdx], col.x, y, color);
          }
        } else {
          // Зелёный поток
          final alpha = i == 0 ? brightness : brightness * 0.55;
          final color = const Color(0xFF00E676).withValues(alpha: alpha.clamp(0, 1));
          _drawChar(canvas, _chars[charIdx], col.x, y, color);
        }
      }
    }
  }

  void _drawChar(Canvas canvas, String char, double x, double y, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: char,
        style: TextStyle(color: color, fontSize: _fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  @override
  bool shouldRepaint(_MatrixPainter old) => old.time != time;
}

class _ErrorCard extends StatelessWidget {
  final String msg;
  final ThemeDef t;
  const _ErrorCard({required this.msg, required this.t});

  @override
  Widget build(BuildContext context) {
    final inner = Row(
      children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(msg, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
        ),
      ],
    );

    if (t.isLiquidGlass || t.glassy) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
            ),
            child: inner,
          ),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: inner,
    );
  }
}

Future<int?> _pingEndpoint(String endpoint) async {
  final parts = endpoint.split(':');
  if (parts.length < 2) return null;
  final host = parts.sublist(0, parts.length - 1).join(':');
  final port = int.tryParse(parts.last) ?? 51820;
  final sw = Stopwatch()..start();
  try {
    final socket = await Socket.connect(host, port,
        timeout: const Duration(seconds: 3));
    final ms = sw.elapsedMilliseconds;
    socket.destroy();
    return ms;
  } catch (_) {
    return null;
  }
}

class _ConfigsList extends StatefulWidget {
  final VpnProvider vpn;
  final ThemeDef t;
  final Color a;
  final Color a2;
  const _ConfigsList({required this.vpn, required this.t, required this.a, required this.a2});

  @override
  State<_ConfigsList> createState() => _ConfigsListState();
}

class _ConfigsListState extends State<_ConfigsList> {
  final Map<String, int?> _pings = {};

  @override
  void initState() {
    super.initState();
    _pingAll();
  }

  @override
  void didUpdateWidget(_ConfigsList old) {
    super.didUpdateWidget(old);
    if (old.vpn.configs != widget.vpn.configs) _pingAll();
  }

  void _pingAll() {
    for (final c in widget.vpn.configs) {
      _pingEndpoint(c.endpoint).then((ms) {
        if (mounted) setState(() => _pings[c.id] = ms);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final c in widget.vpn.configs)
          _ConfigRow(
            config: c,
            isActive: widget.vpn.activeConfig?.id == c.id,
            pingMs: _pings[c.id],
            t: widget.t, a: widget.a, a2: widget.a2,
            onTap: () => widget.vpn.selectConfig(c),
            onLongPress: () => _confirmDelete(context, widget.vpn, c, widget.t),
          ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, VpnProvider vpn, VpnConfig c, ThemeDef t) {
    showDialog<void>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: t.surface,
        title: Text('Удалить "${c.name}"?',
            style: TextStyle(color: t.textPrimary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: Text('Отмена', style: TextStyle(color: t.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              vpn.removeConfig(c.id);
              Navigator.pop(dCtx);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

// ── Config row (pill-style) ───────────────────────────────────────────────────

class _ConfigRow extends StatelessWidget {
  final VpnConfig config;
  final bool isActive;
  final int? pingMs;
  final ThemeDef t;
  final Color a;
  final Color a2;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ConfigRow({
    required this.config,
    required this.isActive,
    required this.t,
    required this.a,
    required this.a2,
    required this.onTap,
    required this.onLongPress,
    this.pingMs,
  });

  static const _r = 14.0;

  Color _pingColor(int ms) {
    if (ms < 80) return Colors.greenAccent;
    if (ms < 200) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final inner = Row(
      children: [
        const SizedBox(width: 14),
        Icon(
          isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: isActive ? a : t.textSecondary,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                config.name,
                style: TextStyle(
                  color: t.textPrimary,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
              Text(
                config.shortEndpoint,
                style: TextStyle(color: t.textSecondary, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (config.isAmneziaWg)
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF7B2FF7).withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('AWG',
                style: TextStyle(
                    color: Color(0xFF7B2FF7),
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        Text(
          pingMs != null ? '${pingMs}ms' : '—',
          style: TextStyle(
            color: pingMs != null ? _pingColor(pingMs!) : t.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 14),
      ],
    );

    Widget pill;
    if (t.isLiquidGlass || t.glassy) {
      pill = Container(
        height: 56,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_r),
          child: Stack(children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
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
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                      color: isActive
                          ? a.withValues(alpha: 0.40)
                          : Colors.white.withValues(alpha: 0.18),
                      width: 0.8),
                  borderRadius: BorderRadius.circular(_r),
                ),
                child: inner,
              ),
            ),
          ]),
        ),
      );
    } else if (t.neonGlow) {
      pill = Container(
        height: 56,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_r),
          border: Border.all(
              color: isActive ? a.withValues(alpha: 0.60) : a2.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(color: t.nav.withValues(alpha: 0.90), child: inner),
          ),
        ),
      );
    } else {
      pill = Container(
        height: 56,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_r),
          border: Border.all(
            color: t.cyberpunk
                ? (isActive ? a.withValues(alpha: 0.55) : a.withValues(alpha: 0.25))
                : (isActive
                    ? a.withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.08)),
            width: t.cyberpunk ? 1.0 : 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: t.cyberpunk
                  ? a.withValues(alpha: isActive ? 0.20 : 0.08)
                  : Colors.black.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: t.cyberpunk
                    ? Colors.black.withValues(alpha: 0.82)
                    : t.nav.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(_r),
              ),
              child: inner,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: pill,
    );
  }
}

// ── Server info card ─────────────────────────────────────────────────────────

class _ServerInfoCard extends StatelessWidget {
  final ThemeDef t;
  final Color a;
  final Color a2;
  const _ServerInfoCard({required this.t, required this.a, required this.a2});

  @override
  Widget build(BuildContext context) {
    final prefs = context.read<PrefsService>();
    final inner = Row(
      children: [
        Icon(Icons.dns_outlined, color: a, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            prefs.serverUrl,
            style: TextStyle(color: t.textSecondary, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    if (t.isLiquidGlass || t.glassy) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: inner,
          ),
        ),
      );
    } else if (t.cyberpunk) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: a.withValues(alpha: 0.4), width: 1),
          boxShadow: [BoxShadow(color: a.withValues(alpha: 0.15), blurRadius: 10)],
        ),
        child: inner,
      );
    } else if (t.neonGlow) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: a2.withValues(alpha: 0.5), width: 1),
        ),
        child: inner,
      );
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.cardBorder),
      ),
      child: inner,
    );
  }
}

// ── Gradient ring painter (Glass theme) ──────────────────────────────────────

class _GradientRingPainter extends CustomPainter {
  final double time;
  final Color accent;
  final Color accent2;
  const _GradientRingPainter({required this.time, required this.accent, required this.accent2});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    for (var i = 0; i < 3; i++) {
      final r = 82.0 + i * 18.0 + sin(time * 2 * pi + i * 1.2) * 4.0;
      final alpha = (0.55 - i * 0.15).clamp(0.0, 1.0);
      final angle = time * 2 * pi + i * 0.8;
      final sweep = SweepGradient(
        startAngle: angle,
        endAngle: angle + 2 * pi,
        colors: [
          accent.withValues(alpha: 0),
          accent.withValues(alpha: alpha),
          accent2.withValues(alpha: alpha * 0.7),
          accent.withValues(alpha: 0),
        ],
      );
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..shader = sweep.createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 - i * 0.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  @override
  bool shouldRepaint(_GradientRingPainter old) => old.time != time;
}

class _PulseRing extends StatelessWidget {
  final double scale;
  final double opacity;
  final Color color;
  const _PulseRing({required this.scale, required this.opacity, required this.color});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 140, height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(alpha: opacity * 0.55),
            width: 2,
          ),
        ),
      ),
    );
  }
}

