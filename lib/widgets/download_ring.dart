import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/download_state.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

class DownloadRingOverlay extends StatelessWidget {
  const DownloadRingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final dl = context.watch<DownloadState>();
    if (!dl.isDownloading && !dl.isInstallReady) return const SizedBox.shrink();

    final notifier = context.watch<AppThemeNotifier>();
    final t = notifier.current;

    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 14, top: 10),
          child: dl.isInstallReady
              ? _InstallReadyButton(dl: dl)
              : GestureDetector(
                  onTap: () => _showPopup(context),
                  child: _buildRing(t, notifier, dl),
                ),
        ),
      ),
    );
  }

  Widget _buildRing(ThemeDef t, AppThemeNotifier notifier, DownloadState dl) {
    final accent = notifier.accent;
    return SizedBox(
      width: 30,
      height: 30,
      child: CircularProgressIndicator(
        value: dl.progress,
        strokeWidth: 2.5,
        strokeCap: StrokeCap.round,
        backgroundColor: t.cardBorder,
        valueColor: AlwaysStoppedAnimation<Color>(accent),
      ),
    );
  }

  void _showPopup(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black26,
      builder: (ctx) => Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 64, right: 14),
          child: Material(
            color: Colors.transparent,
            child: Consumer2<DownloadState, AppThemeNotifier>(
              builder: (_, dl, notifier, __) {
                final t = notifier.current;
                return GlassCard(
                  radius: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: SizedBox(
                    width: 200,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.download, color: t.accent, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Загрузка обновления',
                              style: TextStyle(
                                color: t.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: dl.progress,
                            backgroundColor: t.cardBorder,
                            valueColor: AlwaysStoppedAnimation<Color>(t.accent),
                            minHeight: 5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${(dl.progress * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: t.accent,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${dl.speedMbps.toStringAsFixed(2)} МБ/с',
                              style: TextStyle(color: t.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _InstallReadyButton extends StatefulWidget {
  final DownloadState dl;
  const _InstallReadyButton({required this.dl});

  @override
  State<_InstallReadyButton> createState() => _InstallReadyButtonState();
}

class _InstallReadyButtonState extends State<_InstallReadyButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _busy ? null : _install,
      child: Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(
          color: Color(0xFF00C853),
          shape: BoxShape.circle,
        ),
        child: _busy
            ? const Padding(
                padding: EdgeInsets.all(7),
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.system_update_outlined, color: Colors.white, size: 18),
      ),
    );
  }

  Future<void> _install() async {
    final path = widget.dl.completedPath;
    if (path == null) return;
    setState(() => _busy = true);
    widget.dl.clearInstall();
    final err = await UpdateService.installApk(path);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      UpdateService.handleInstallError(context, err);
    }
  }
}
