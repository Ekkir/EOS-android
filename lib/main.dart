import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'theme/app_theme.dart';
import 'services/download_state.dart';
import 'services/prefs_service.dart';
import 'services/api_service.dart';
import 'services/update_service.dart';
import 'providers/vpn_provider.dart';
import 'widgets/download_ring.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';

final FlutterLocalNotificationsPlugin localNotifPlugin = FlutterLocalNotificationsPlugin();

// Текущий открытый канал — для фильтрации уведомлений
String? currentChatChannelId;

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
          android: AndroidInitializationSettings('ic_notification'),
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
  final title = message.notification?.title ?? message.data['sender'] ?? 'EOS';
  final body  = message.notification?.body  ?? message.data['text']   ?? '';
  if (body.isEmpty) return;
  final channel = message.data['channel'] ?? '';
  final sp = await SharedPreferences.getInstance();
  final muted = sp.getStringList('muted_channels') ?? [];
  if (channel.isNotEmpty && muted.contains(channel)) return;
  final notif = FlutterLocalNotificationsPlugin();
  await notif.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('ic_notification'),
  ));
  await notif.show(
    message.hashCode,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'eos_chat', 'Чат',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}

// ── Main ─────────────────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Firebase.initializeApp();

  // Local notifications setup
  try {
    const androidSettings = AndroidInitializationSettings('ic_notification');
    await localNotifPlugin.initialize(
      const InitializationSettings(android: androidSettings),
    );
    final androidPlugin = localNotifPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
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
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      'eos_events',
      'События на карте',
      description: 'Уведомления о новых событиях на карте',
      importance: Importance.high,
    ));
  } catch (_) {}

  // Request FCM permission
  try {
    await FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true,
    );
  } catch (_) {}

  // FCM
  FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
  FirebaseMessaging.onMessage.listen((msg) async {
    final title = msg.notification?.title ?? msg.data['sender'] ?? 'EOS';
    final body  = msg.notification?.body  ?? msg.data['text']   ?? '';
    if (body.isEmpty) return;
    final channel = msg.data['channel'] ?? '';

    // События — всегда показываем
    if (channel == 'eos_events') {
      localNotifPlugin.show(
        msg.hashCode,
        title, body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'eos_events', 'События на карте',
            importance: Importance.high, priority: Priority.high,
          ),
        ),
      );
      return;
    }

    if (channel.isNotEmpty && channel == currentChatChannelId) return;
    final sp = await SharedPreferences.getInstance();
    final muted = sp.getStringList('muted_channels') ?? [];
    if (channel.isNotEmpty && muted.contains(channel)) return;
    localNotifPlugin.show(
      msg.hashCode,
      title, body,
      const NotificationDetails(
        android: AndroidNotificationDetails('eos_chat', 'Чат',
            importance: Importance.high, priority: Priority.high),
      ),
    );
  });

  // Workmanager: hourly update check
  try {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    await Workmanager().registerPeriodicTask(
      UpdateService.taskName,
      UpdateService.taskName,
      frequency: const Duration(hours: 1),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 15),
    );
  } catch (_) {}

  final prefs = PrefsService();
  await prefs.init();

  final theme = AppThemeNotifier();
  await theme.load();

  _registerFcmToken(prefs);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: theme),
        ChangeNotifierProvider.value(value: prefs),
        ChangeNotifierProvider(create: (_) => DownloadState()),
        ChangeNotifierProvider(create: (_) => VpnProvider()),
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
      final sender = prefs.profileName.isNotEmpty ? prefs.profileName : prefs.googleName;
      if (sender.isNotEmpty) await ApiService(prefs).registerFcmToken(sender, token);
    }
    FirebaseMessaging.instance.onTokenRefresh.listen((t) async {
      await prefs.setFcmToken(t);
      final sender = prefs.profileName.isNotEmpty ? prefs.profileName : prefs.googleName;
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

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ));

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
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
            systemNavigationBarContrastEnforced: false,
          ),
        ),
      ),
      builder: (context, child) => Stack(
        children: [
          child!,
          const DownloadRingOverlay(),
        ],
      ),
      home: const SplashScreen(),
    );
  }
}
