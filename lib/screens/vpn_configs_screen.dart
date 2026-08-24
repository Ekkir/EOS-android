import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vpn_config.dart';
import '../providers/vpn_provider.dart';
import '../services/nav_bar_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_surface.dart';

class VpnConfigsScreen extends StatefulWidget {
  const VpnConfigsScreen({super.key});

  @override
  State<VpnConfigsScreen> createState() => _VpnConfigsScreenState();
}

class _VpnConfigsScreenState extends State<VpnConfigsScreen> {
  NavBarController? _navCtrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navCtrl = context.read<NavBarController>();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _navCtrl!.enterVpnConfigs(onAdd: _onAdd);
    });
  }

  @override
  void dispose() {
    _navCtrl?.exitVpnConfigs();
    super.dispose();
  }

  void _onAdd() {
    if (!mounted) return;
    final vpn = context.read<VpnProvider>();
    final t = Provider.of<AppThemeNotifier>(context, listen: false).current;
    _showAddConfigSheet(vpn, t);
  }

  @override
  Widget build(BuildContext context) {
    final vpn = context.watch<VpnProvider>();
    final notifier = context.watch<AppThemeNotifier>();
    final t = notifier.current;
    final a = notifier.accent;

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
                    title: Text('Конфигурации VPN',
                        style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
                    iconTheme: IconThemeData(color: t.textPrimary),
                  ),
                ),
              )
            : AppBar(
                backgroundColor: t.nav,
                title: Text('Конфигурации VPN',
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
          vpn.configs.isEmpty
              ? Center(
                  child: Text(
                    'Нет конфигураций\nНажмите + в панели навигации',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: t.textSecondary, fontSize: 15, height: 1.6),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                  itemCount: vpn.configs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final c = vpn.configs[i];
                    final isActive = vpn.activeConfig?.id == c.id;
                    final tile = ListTile(
                      leading: Icon(
                        isActive
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isActive ? const Color(0xFF7B2FF7) : t.textSecondary,
                        size: 22,
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
                                  color: Color(0xFF7B2FF7),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                            )
                          : null,
                      onTap: () => vpn.selectConfig(c),
                      onLongPress: () => _confirmDelete(vpn, c, t),
                    );

                    if (t.isLiquidGlass || t.glassy) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.10)),
                            ),
                            child: tile,
                          ),
                        ),
                      );
                    }
                    return Container(
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: t.cardBorder),
                      ),
                      child: tile,
                    );
                  },
                ),
        ],
      ),
    );
  }

  void _showAddConfigSheet(VpnProvider vpn, ThemeDef t) {
    final ctrl = TextEditingController();
    final nameCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isGlass = t.isLiquidGlass || t.glassy;
        final inner = Container(
          decoration: BoxDecoration(
            color: isGlass ? Colors.white.withValues(alpha: 0.06) : t.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: t.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Добавить конфигурацию',
                  style: TextStyle(
                      color: t.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: t.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Название (необязательно)',
                  hintStyle: TextStyle(color: t.textSecondary),
                  filled: true,
                  fillColor: t.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: t.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: t.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                style: TextStyle(color: t.textPrimary, fontSize: 12),
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: '[Interface]\nPrivateKey = ...\n\n[Peer]\nPublicKey = ...',
                  hintStyle: TextStyle(color: t.textSecondary, fontSize: 12),
                  filled: true,
                  fillColor: t.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: t.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: t.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim();
                    final ok = vpn.addConfigFromText(ctrl.text, name: name);
                    Navigator.pop(ctx);
                    if (!ok && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Неверный формат конфигурации')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B2FF7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Добавить'),
                ),
              ),
            ],
          ),
        );

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: isGlass
              ? ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: inner,
                  ),
                )
              : inner,
        );
      },
    );
  }

  void _confirmDelete(VpnProvider vpn, VpnConfig c, ThemeDef t) {
    showDialog<void>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: t.surface,
        title: Text('Удалить "${c.name}"?', style: TextStyle(color: t.textPrimary)),
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
