import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/update_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/circular_avatar.dart';

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
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
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
    if (_apkUrl == null) {
      // No APK attached to release — open release page instead
      _openGithub();
      return;
    }

    setState(() { _downloading = true; _downloadProgress = 0; });

    final path = await UpdateService.downloadApk(_apkUrl!, (progress) {
      if (mounted) setState(() => _downloadProgress = progress);
    });

    if (!mounted) return;
    setState(() => _downloading = false);

    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка скачивания. Попробуйте ещё раз.')),
      );
      return;
    }

    final result = await OpenFile.open(path, type: 'application/vnd.android.package-archive');
    if (result.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть установщик: ${result.message}')),
      );
    }
  }

  Future<void> _openGithub() async {
    final uri = Uri.parse(_githubRepo);
    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final t = Provider.of<AppThemeNotifier>(context).current;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.nav,
        title: Text('О приложении',
            style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Logo shimmer
            AnimatedBuilder(
              animation: _shimmerAnim,
              builder: (ctx, child) => ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment(_shimmerAnim.value - 1, 0),
                  end: Alignment(_shimmerAnim.value, 0),
                  colors: [
                    t.accent.withValues(alpha: 0.4),
                    t.accent,
                    t.accent.withValues(alpha: 0.4),
                  ],
                ).createShader(bounds),
                child: child,
              ),
              child: const Text('EOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text('Emergency Operations System',
              style: TextStyle(color: t.textSecondary, fontSize: 13, letterSpacing: 1),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Version card
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: t.accent),
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
                  OutlinedButton(
                    onPressed: (_checking || _downloading) ? null : _checkUpdate,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: t.accent,
                      side: BorderSide(color: t.accent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _checking
                        ? SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(color: t.accent, strokeWidth: 2))
                        : const Text('Проверить'),
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
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _downloadProgress,
                                backgroundColor: t.cardBorder,
                                color: Colors.green,
                                minHeight: 6,
                              ),
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
                  _InfoRow(icon: Icons.phone_android, label: 'Платформа', value: 'Android', t: t),
                  Divider(color: t.cardBorder, height: 16),
                  _InfoRow(icon: Icons.map, label: 'Карта', value: 'OpenStreetMap', t: t),
                  Divider(color: t.cardBorder, height: 16),
                  _InfoRow(icon: Icons.notifications, label: 'Push', value: 'Firebase FCM', t: t),
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
                          child: CircularProgressIndicator(color: t.accent, strokeWidth: 2),
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
                  IconButton(
                    icon: Icon(Icons.open_in_new, color: t.accent),
                    onPressed: _openGithub,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            GlassCard(
              onTap: _openGithub,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.source, color: t.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Исходный код на GitHub',
                      style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w500)),
                  ),
                  Icon(Icons.chevron_right, color: t.textSecondary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ThemeDef t;

  const _InfoRow({required this.icon, required this.label, required this.value, required this.t});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: t.accent, size: 18),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: t.textSecondary, fontSize: 14)),
        const Spacer(),
        Text(value,
          style: TextStyle(color: t.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
