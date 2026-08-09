import 'dart:math' show sin, pi;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vpn_config.dart';
import '../providers/vpn_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_surface.dart';
import 'vpn_configs_screen.dart';
import 'vpn_split_tunneling_screen.dart';

class VpnScreen extends StatefulWidget {
  const VpnScreen({super.key});

  @override
  State<VpnScreen> createState() => _VpnScreenState();
}

class _VpnScreenState extends State<VpnScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VpnProvider>();
    final notifier = context.watch<AppThemeNotifier>();
    final t = notifier.current;
    final a = notifier.accent;

    if (vpn.isBusy) {
      if (!_pulseCtrl.isAnimating) _pulseCtrl.repeat();
    } else {
      if (_pulseCtrl.isAnimating) { _pulseCtrl.stop(); _pulseCtrl.reset(); }
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
                    actions: [
                      IconButton(
                        icon: Icon(Icons.settings_outlined, color: t.textPrimary),
                        tooltip: 'Конфигурации VPN',
                        onPressed: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const VpnConfigsScreen())),
                      ),
                    ],
                  ),
                ),
              )
            : AppBar(
                backgroundColor: t.nav,
                title: Text('VPN',
                    style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
                iconTheme: IconThemeData(color: t.textPrimary),
                actions: [
                  IconButton(
                    icon: Icon(Icons.settings_outlined, color: t.textPrimary),
                    tooltip: 'Конфигурации VPN',
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const VpnConfigsScreen())),
                  ),
                ],
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
                        animation: _pulseCtrl,
                        builder: (_, child) => Stack(
                          alignment: Alignment.center,
                          children: [
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
              if (vpn.configs.isNotEmpty) _ConfigsList(vpn: vpn, t: t),
              _SplitTunnelTile(t: t, a: a),
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
        _AnimatedArrow(isUp: icon == Icons.arrow_upward, color: color),
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
  const _AnimatedArrow({required this.isUp, required this.color});

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
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final direction = widget.isUp ? -1.0 : 1.0;
    return SizedBox(
      width: 18,
      height: 18,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = _ctrl.value;
          // стрелка движется в направлении потока данных
          final dy = direction * (t - 0.5) * 20.0;
          // плавно появляется и исчезает через sin(t*π)
          final opacity = sin(t * pi).clamp(0.0, 1.0);
          return ClipRect(
            child: Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Icon(
                  widget.isUp ? Icons.arrow_upward : Icons.arrow_downward,
                  color: widget.color,
                  size: 18,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
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

class _ConfigsList extends StatelessWidget {
  final VpnProvider vpn;
  final ThemeDef t;
  const _ConfigsList({required this.vpn, required this.t});

  @override
  Widget build(BuildContext context) {
    final isGlass = t.isLiquidGlass || t.glassy;

    final list = ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: vpn.configs.length,
      itemBuilder: (_, i) {
        final c = vpn.configs[i];
        final isActive = vpn.activeConfig?.id == c.id;
        return ListTile(
          dense: true,
          leading: Icon(
            isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: isActive ? const Color(0xFF7B2FF7) : t.textSecondary,
            size: 20,
          ),
          title: Text(c.name, style: TextStyle(
            color: t.textPrimary,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          )),
          subtitle: Text(c.shortEndpoint,
              style: TextStyle(color: t.textSecondary, fontSize: 12)),
          trailing: c.isAmneziaWg
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B2FF7).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('AWG', style: TextStyle(
                      color: Color(0xFF7B2FF7), fontSize: 10, fontWeight: FontWeight.bold)),
                )
              : null,
          onTap: () => vpn.selectConfig(c),
          onLongPress: () => _confirmDelete(context, vpn, c, t),
        );
      },
    );

    final bottomPad = MediaQuery.paddingOf(context).bottom;

    if (isGlass) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 200),
            padding: EdgeInsets.only(bottom: bottomPad),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.10))),
            ),
            child: list,
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.cardBorder)),
      ),
      constraints: const BoxConstraints(maxHeight: 200),
      padding: EdgeInsets.only(bottom: bottomPad),
      child: list,
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

class _SplitTunnelTile extends StatefulWidget {
  final ThemeDef t;
  final Color a;
  const _SplitTunnelTile({required this.t, required this.a});

  @override
  State<_SplitTunnelTile> createState() => _SplitTunnelTileState();
}

class _SplitTunnelTileState extends State<_SplitTunnelTile> {
  String _modeLabel = 'Выкл';

  @override
  void initState() {
    super.initState();
    _loadMode();
  }

  Future<void> _loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('vpn_split_mode') ?? 'none';
    if (mounted) {
      setState(() {
        _modeLabel = _labelFor(mode);
      });
    }
  }

  String _labelFor(String mode) {
    switch (mode) {
      case 'whitelist': return 'Белый список';
      case 'blacklist': return 'Чёрный список';
      default: return 'Выкл';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.tune, color: widget.a),
      title: Text('Раздельное туннелирование',
          style: TextStyle(color: widget.t.textPrimary)),
      subtitle: Text(_modeLabel,
          style: TextStyle(color: widget.t.textSecondary, fontSize: 12)),
      trailing: Icon(Icons.chevron_right, color: widget.t.textSecondary),
      onTap: () async {
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const VpnSplitTunnelingScreen()));
        _loadMode();
      },
    );
  }
}
