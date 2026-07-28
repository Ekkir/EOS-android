import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'theme/app_theme.dart';
import 'services/prefs_service.dart';
import 'services/api_service.dart';
import 'screens/home_screen.dart';

final FlutterLocalNotificationsPlugin _localNotif = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Firebase.initializeApp();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await _localNotif.initialize(
    const InitializationSettings(android: androidSettings),
  );

  const channel = AndroidNotificationChannel(
    'eos_chat', 'Чат',
    description: 'Сообщения из чатов EOS',
    importance: Importance.high,
  );
  await _localNotif
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

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
      if (sender.isNotEmpty) {
        await ApiService(prefs).registerFcmToken(sender, token);
      }
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
