import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

import 'theme/app_theme.dart';
import 'services/prefs_service.dart';
import 'services/api_service.dart';
import 'services/update_service.dart';
import 'screens/home_screen.dart';

final FlutterLocalNotificationsPlugin _localNotif = FlutterLocalNotificationsPlugin();

// ── Workmanager background entry point ──────────────────────────────────────

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, _) async {
    if (taskName != UpdateService.taskName) return true;
    try {
      final latest = await UpdateService.fetchLatestVersion();
      if (latest == null) return true;
      if (!UpdateService.isNewer(latest, UpdateService.currentVersion)) return true;

      final notif = FlutterLocalNotificationsPlugin();
      await notif.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await notif.show(
        42,
        'Доступно обновление EOS',
        'Версия $latest — откройте приложение для установки',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            UpdateService.notifChannelId,
            UpdateService.notifChannelName,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    } catch (_) {}
    return true;
  });
}

// ── FCM background handler ───────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
}

// ── Main ─────────────────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Firebase.initializeApp();

  // Local notifications setup
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await _localNotif.initialize(
    const InitializationSettings(android: androidSettings),
  );

  // Create notification channels
  final androidPlugin = _localNotif
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
    'eos_chat', 'Чат',
    description: 'Сообщения из чатов EOS',
    importance: Importance.high,
  ));
  await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
    UpdateService.notifChannelId,
    UpdateService.notifChannelName,
    description: 'Уведомления о новых версиях EOS',
    importance: Importance.defaultImportance,
  ));

  // FCM
  FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
  FirebaseMessaging.onMessage.listen((msg) {
    final title = msg.notification?.title ?? msg.data['sender'] ?? 'EOS';
    final body  = msg.notification?.body  ?? msg.data['text']   ?? '';
    if (body.isEmpty) return;
    _localNotif.show(
      msg.hashCode,
      title, body,
      const NotificationDetails(
        android: AndroidNotificationDetails('eos_chat', 'Чат',
            importance: Importance.high, priority: Priority.high),
      ),
    );
  });

  // Workmanager: hourly update check
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    UpdateService.taskName,
    UpdateService.taskName,
    frequency: const Duration(hours: 1),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingWorkPolicy.keep,
    backoffPolicy: BackoffPolicy.linear,
    backoffPolicyDelay: const Duration(minutes: 15),
  );

  final prefs = PrefsService();
  await prefs.init();

  final theme = AppThemeNotifier();
  await theme.load();

  _registerFcmToken(prefs);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: theme),
        Provider.value(value: prefs),
        ProxyProvider<PrefsService, ApiService>(
          update: (_, p, _) => ApiService(p),
        ),
      ],
      child: const EosApp(),
    ),
  );
}

void _registerFcmToken(PrefsService prefs) async {
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) {
      await prefs.setFcmToken(token);
      final sender = prefs.profileName;
      if (sender.isNotEmpty) await ApiService(prefs).registerFcmToken(sender, token);
    }
    FirebaseMessaging.instance.onTokenRefresh.listen((t) async {
      await prefs.setFcmToken(t);
      final sender = prefs.profileName;
      if (sender.isNotEmpty) await ApiService(prefs).registerFcmToken(sender, t);
    });
  } catch (_) {}
}

class EosApp extends StatelessWidget {
  const EosApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<AppThemeNotifier>(context);
    final t = themeNotifier.current;

    return MaterialApp(
      title: 'EOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          surface:   t.bg,
          primary:   themeNotifier.accent,
          secondary: themeNotifier.accent,
        ),
        scaffoldBackgroundColor: t.bg,
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
