import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_surface.dart';

class CamerasScreen extends StatefulWidget {
  const CamerasScreen({super.key});

  @override
  State<CamerasScreen> createState() => _CamerasScreenState();
}

class _CamerasScreenState extends State<CamerasScreen> {
  static const _prefsKey = 'ip_cameras';
  List<Map<String, String>> _cameras = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map((e) => e.map((k, v) => MapEntry(k, v.toString())))
          .toList();
      if (mounted) setState(() => _cameras = list);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_cameras));
  }

  void _showAddDialog(ThemeDef t) {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Добавить камеру', style: TextStyle(color: t.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: TextStyle(color: t.textPrimary),
              decoration: InputDecoration(
                hintText: 'Название',
                hintStyle: TextStyle(color: t.textSecondary),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: t.cardBorder)),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: t.accent)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              style: TextStyle(color: t.textPrimary),
              decoration: InputDecoration(
                hintText: 'URL (rtsp:// или http://)',
                hintStyle: TextStyle(color: t.textSecondary),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: t.cardBorder)),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: t.accent)),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена', style: TextStyle(color: t.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final url = urlCtrl.text.trim();
              if (name.isEmpty || url.isEmpty) return;
              setState(() => _cameras.add({'name': name, 'url': url}));
              _save();
              Navigator.pop(ctx);
            },
            child: Text('Добавить', style: TextStyle(color: t.accent)),
          ),
        ],
      ),
    );
  }

  void _delete(int index) {
    setState(() => _cameras.removeAt(index));
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final t = Provider.of<AppThemeNotifier>(context).current;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.nav,
        title: Text('Камеры', style: TextStyle(color: t.textPrimary)),
        iconTheme: IconThemeData(color: t.textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: t.accent),
            onPressed: () => _showAddDialog(t),
            tooltip: 'Добавить камеру',
          ),
        ],
      ),
      body: GlassBg(child: _cameras.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_off_outlined,
                      size: 64, color: t.textSecondary),
                  const SizedBox(height: 16),
                  Text('Нет добавленных камер',
                      style: TextStyle(color: t.textSecondary, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Нажмите + чтобы добавить IP-камеру',
                      style: TextStyle(color: t.textSecondary, fontSize: 13)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _cameras.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final cam = _cameras[i];
                return GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: t.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Icon(Icons.videocam_outlined, color: t.accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cam['name'] ?? '',
                                style: TextStyle(
                                    color: t.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(cam['url'] ?? '',
                                style: TextStyle(
                                    color: t.textSecondary, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.play_circle_outline, color: t.accent),
                        tooltip: 'Смотреть',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _CameraViewerScreen(
                              name: cam['name'] ?? 'Камера',
                              url: cam['url'] ?? '',
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: t.textSecondary),
                        tooltip: 'Удалить',
                        onPressed: () => _delete(i),
                      ),
                    ],
                  ),
                );
              },
            )),
    );
  }
}  // _CamerasScreenState

class _CameraViewerScreen extends StatefulWidget {
  final String name;
  final String url;
  const _CameraViewerScreen({required this.name, required this.url});

  @override
  State<_CameraViewerScreen> createState() => _CameraViewerScreenState();
}

class _CameraViewerScreenState extends State<_CameraViewerScreen> {
  late final WebViewController _webController;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() { _loading = true; _hasError = false; }),
        onPageFinished: (_) => setState(() => _loading = false),
        onWebResourceError: (_) => setState(() { _hasError = true; _loading = false; }),
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final t = Provider.of<AppThemeNotifier>(context).current;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.name, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Перезагрузить',
            onPressed: () => _webController.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _webController),
          if (_loading)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: t.accent),
                  const SizedBox(height: 16),
                  const Text('Подключение...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          if (_hasError && !_loading)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  const Text('Не удалось подключиться к камере',
                      style: TextStyle(color: Colors.white, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text(widget.url,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    label: const Text('Повторить', style: TextStyle(color: Colors.white70)),
                    onPressed: () => _webController.reload(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
