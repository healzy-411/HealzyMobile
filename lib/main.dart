import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'services/local_notification_service.dart';
import 'services/push_notification_service.dart';
import 'services/token_store.dart';
import 'screens/auth_gate.dart';
import 'screens/splash_page.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ekran yönünü dikey olarak kilitle
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Local Notification init
  await LocalNotificationService.I.init();
  await LocalNotificationService.I.requestPermissions();

  // Load persisted token
  await TokenStore.load();

  // Firebase + FCM push notifications
  try {
    await Firebase.initializeApp();
    await PushNotificationService.I.init();
  } catch (e) {
    debugPrint('Firebase init skipped: $e');
  }

  // Load theme preference
  await ThemeController.I.load();

  runApp(const HealzyApp());
}

class HealzyApp extends StatefulWidget {
  const HealzyApp({super.key});

  @override
  State<HealzyApp> createState() => _HealzyAppState();
}

class _HealzyAppState extends State<HealzyApp> with WidgetsBindingObserver {
  DateTime? _backgroundedAt;

  // App background'a alındıktan sonra bu süreyi geçmişse foreground'a
  // dönüşte splash'i tekrar göster. Hızlı tab değişimlerinde splash gelmez.
  static const Duration _resumeSplashThreshold = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      // Login sonrasi veya resume'da FCM token'i backend'e kaydetmeyi dene
      PushNotificationService.I.tryRegisterToken();
      final bg = _backgroundedAt;
      _backgroundedAt = null;
      if (bg == null) return;
      final away = DateTime.now().difference(bg);
      if (away < _resumeSplashThreshold) return;
      // Yeterince uzun süre arka planda kaldı → splash'i baştan göster.
      // AuthGate de yeniden token doğrulaması yapacak.
      final nav = navigatorKey.currentState;
      if (nav == null) return;
      nav.pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              const SplashPage(nextPage: AuthGate()),
          transitionDuration: Duration.zero,
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.I,
      builder: (context, _) => MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Healzy',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeController.I.mode,
        scrollBehavior: _HealzyScrollBehavior(),
        home: const SplashPage(nextPage: AuthGate()),
      ),
    );
  }
}

class _HealzyScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };

  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    return Scrollbar(
      controller: details.controller,
      thickness: 5,
      radius: const Radius.circular(8),
      child: child,
    );
  }
}
