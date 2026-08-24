import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/prefs_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_surface.dart';

class HomeTilesScreen extends StatelessWidget {
  const HomeTilesScreen({super.key});

  static const _tilesMeta = {
    'traffic': ('Светофоры', Icons.traffic_outlined, 'Управление трафиком'),
    'map':     ('Карта',     Icons.map_outlined,      'Перекрёстки на карте'),
    'cameras': ('Камеры',    Icons.videocam_outlined,  'Видеонаблюдение'),
    'chats':   ('Чаты',      Icons.chat_bubble_outline, 'Сообщения и каналы'),
    'vpn':     ('VPN',       Icons.vpn_lock_outlined,  'AmneziaWG защита трафика'),
    'car':     ('Машина',    Icons.directions_car_outlined, 'Управление транспортом'),
    'music':   ('Музыка',   Icons.music_note_outlined,     'Треки с сервера'),
  };

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AppThemeNotifier>();
    final prefs    = context.watch<PrefsService>();
    final t        = notifier.current;
    final a        = notifier.accent;
    final order    = prefs.tileOrder;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.nav,
        title: Text('Плашки главной страницы',
            style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: GlassBg(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Выберите разделы и порядок отображения. '
                  'Раздел «Настройки» всегда виден.',
                  style: TextStyle(color: t.textSecondary, fontSize: 13),
                ),
              ),
            ),

            // ── Квадратные плашки ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  child: SwitchListTile(
                    value: prefs.squareTiles,
                    activeThumbColor: a,
                    onChanged: (v) => prefs.setSquareTiles(v),
                    secondary: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: a.withValues(alpha: prefs.squareTiles ? 0.15 : 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.grid_view_rounded,
                          color: prefs.squareTiles ? a : t.textSecondary, size: 20),
                    ),
                    title: Text('Квадратные плашки',
                        style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text('Отображать разделы в виде сетки 2×2',
                        style: TextStyle(color: t.textSecondary, fontSize: 12)),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Text('РАЗДЕЛЫ',
                    style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
              ),
            ),

            // ── Перетаскиваемый список ────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverReorderableList(
                proxyDecorator: (child, index, animation) => Material(
                  color: Colors.transparent, elevation: 0, child: child),
                itemCount: order.length,
                onReorderItem: (oldIdx, newIdx) {
                  final list = List<String>.from(order);
                  list.insert(newIdx, list.removeAt(oldIdx));
                  prefs.setTileOrder(list);
                },
                itemBuilder: (ctx, i) {
                  final key     = order[i];
                  final meta    = _tilesMeta[key];
                  if (meta == null) return const SizedBox.shrink(key: ValueKey('_'));
                  final (label, icon, sub) = meta;
                  final visible = prefs.isTileVisible(key);

                  return Padding(
                    key: ValueKey(key),
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GlassCard(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: a.withValues(alpha: visible ? 0.15 : 0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon,
                              color: visible ? a : t.textSecondary, size: 20),
                        ),
                        title: Text(label,
                            style: TextStyle(
                                color: visible ? t.textPrimary : t.textSecondary,
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(sub,
                            style: TextStyle(color: t.textSecondary, fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: visible,
                              activeThumbColor: a,
                              onChanged: (v) => prefs.setTileVisible(key, v),
                            ),
                            ReorderableDragStartListener(
                              index: i,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(Icons.drag_handle,
                                    color: t.textSecondary, size: 22),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Настройки (всегда видны) ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: a.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.settings_outlined, color: a, size: 20),
                    ),
                    title: Text('Настройки',
                        style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text('Всегда отображается',
                        style: TextStyle(color: t.textSecondary, fontSize: 12)),
                    trailing: Switch(
                      value: true,
                      onChanged: null,
                      activeThumbColor: a,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
