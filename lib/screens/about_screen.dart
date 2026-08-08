import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/download_state.dart';
import '../services/update_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_surface.dart';
import '../widgets/glitch_wrapper.dart';
import '../widgets/circular_avatar.dart';
import '../widgets/gradient_progress_bar.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
    with SingleTickerProviderStateMixin {
  static const _githubRepo = 'https://github.com/Ekkir/EOS-android';

  Uint8List? _creatorAvatar;
  bool _loadingAvatar = true;

  // Update state
  bool _checking = false;
  bool _downloading = false;
  double _downloadProgress = 0;
  String? _latestVersion;
  String? _apkUrl;
  String? _releaseNotes;
  bool? _updateAvailable;

  late AnimationController _shimmerCtrl;
  late Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _shimmerAnim = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );
    _loadCreatorAvatar();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCreatorAvatar() async {
    final api = context.read<ApiService>();
    final bytes = await api.getAvatarByName('Ekkir');
    if (mounted) {
      setState(() {
        if (bytes != null) _creatorAvatar = Uint8List.fromList(bytes);
        _loadingAvatar = false;
      });
    }
  }

  Future<void> _checkUpdate() async {
    setState(() { _checking = true; _updateAvailable = null; });
    final info = await UpdateService.fetchReleaseInfo();
    if (!mounted) return;
    final version = info?['version'];
    setState(() {
      _latestVersion = version;
      _apkUrl = info?['apk_url'];
      _releaseNotes = info?['notes'];
      _updateAvailable = version != null &&
          UpdateService.isNewer(version, UpdateService.currentVersion);
      _checking = false;
    });
  }

  Future<void> _downloadAndInstall() async {
    if (_apkUrl == null || _latestVersion == null) {
      _openGithub();
      return;
    }

    // Check cache first
    final cached = await UpdateService.getCachedApk(_latestVersion!);
    if (cached != null) {
      UpdateService.installApk(cached);
      return;
    }

    setState(() { _downloading = true; _downloadProgress = 0; });
    final dlState = context.read<DownloadState>();
    dlState.startDownload();

    final path = await UpdateService.downloadApk(_apkUrl!, _latestVersion!, (progress, r, t) {
      try { if (mounted) setState(() => _downloadProgress = progress); } catch (_) {}
      dlState.onProgress(progress, r, t);
    });

    dlState.complete(path);

    if (!mounted) {
      if (path != null) UpdateService.installApk(path);
      return;
    }

    setState(() => _downloading = false);

    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка скачивания. Попробуйте ещё раз.')),
      );
      return;
    }

    UpdateService.installApk(path);
  }

  Future<void> _openGithub() async {
    final uri = Uri.parse(_githubRepo);
    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final notifier = Provider.of<AppThemeNotifier>(context);
    final t = notifier.current;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.nav,
        title: Text('О приложении',
            style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: GlassBg(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Logo glitch
            GlitchWrapper(
              intensity: 0.55,
              frequency: 0.7,
              child: Text('EOS',
                style: TextStyle(
                  color: notifier.accent,
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Version card
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: notifier.accent),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Версия', style: TextStyle(color: t.textSecondary, fontSize: 12)),
                      Text(UpdateService.currentVersion,
                        style: TextStyle(color: t.textPrimary, fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _shimmerAnim,
                    builder: (_, _) => OutlinedButton(
                      onPressed: (_checking || _downloading) ? null : _checkUpdate,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: notifier.accent,
                        side: BorderSide(color: notifier.accent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _checking
                          ? SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(color: notifier.accent, strokeWidth: 2))
                          : ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                begin: Alignment(_shimmerAnim.value - 1, 0),
                                end: Alignment(_shimmerAnim.value + 1, 0),
                                colors: [notifier.accent, Colors.white, notifier.accent],
                              ).createShader(bounds),
                              blendMode: BlendMode.srcIn,
                              child: const Text('Проверить'),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            // Update available
            if (_updateAvailable == true) ...[
              const SizedBox(height: 8),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.system_update, color: Colors.green),
                        const SizedBox(width: 8),
                        Text('Доступна версия $_latestVersion',
                          style: const TextStyle(color: Colors.green,
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    if (_releaseNotes != null && _releaseNotes!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(_releaseNotes!,
                        style: TextStyle(color: t.textSecondary, fontSize: 13, height: 1.5)),
                    ],
                    const SizedBox(height: 14),
                    if (_downloading) ...[
                      Row(
                        children: [
                          Expanded(
                            child: GradientProgressBar(
                              value: _downloadProgress,
                              height: 6,
                              background: t.cardBorder,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('${(_downloadProgress * 100).toInt()}%',
                            style: TextStyle(color: t.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _downloadAndInstall,
                          icon: Icon(_apkUrl != null ? Icons.download : Icons.open_in_new),
                          label: Text(_apkUrl != null
                              ? 'Скачать и установить'
                              : 'Открыть на GitHub'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ] else if (_updateAvailable == false) ...[
              const SizedBox(height: 8),
              GlassCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text('У вас последняя версия',
                      style: TextStyle(color: t.textSecondary)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Tech stack
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  _InfoRow(icon: Icons.code, label: 'Язык', value: 'Dart / Flutter', t: t),
                  Divider(color: t.cardBorder, height: 16),
                  _InfoRow(icon: Icons.phone_android, label: 'Платформа', value: 'Android', t: t, valueIcon: Icons.android),
                  Divider(color: t.cardBorder, height: 16),
                  _InfoRow(icon: Icons.map, label: 'Карта', value: 'OpenStreetMap', t: t),
                  Divider(color: t.cardBorder, height: 16),
                  _InfoRow(icon: Icons.notifications, label: 'Push', value: 'Firebase FCM', t: t),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // GitHub
            GlassCard(
              onTap: _openGithub,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.code, color: notifier.accent, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Исходный код',
                          style: TextStyle(color: t.textPrimary,
                              fontWeight: FontWeight.w600, fontSize: 14)),
                        Text('github.com/Ekkir/EOS-android',
                          style: TextStyle(color: t.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.open_in_new, color: t.textSecondary, size: 18),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Creator
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _loadingAvatar
                      ? CircleAvatar(
                          radius: 28,
                          backgroundColor: t.surface,
                          child: CircularProgressIndicator(color: notifier.accent, strokeWidth: 2),
                        )
                      : CircularAvatar(bytes: _creatorAvatar, name: 'Ekkir', radius: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ekkir',
                          style: TextStyle(color: t.textPrimary,
                              fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Разработчик',
                          style: TextStyle(color: t.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      )),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ThemeDef t;
  final IconData? valueIcon;

  const _InfoRow({required this.icon, required this.label, required this.value, required this.t, this.valueIcon});

  @override
  Widget build(BuildContext context) {
    final accent = context.read<AppThemeNotifier>().accent;
    return Row(
      children: [
        Icon(icon, color: accent, size: 18),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: t.textSecondary, fontSize: 14)),
        const Spacer(),
        if (valueIcon != null) ...[
          Icon(valueIcon, color: t.textPrimary, size: 16),
          const SizedBox(width: 6),
        ],
        Text(value,
          style: TextStyle(color: t.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
