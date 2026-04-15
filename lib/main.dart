import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import 'services/auth_service.dart';
import 'services/local_notification_service.dart';
import 'services/token_store.dart';
import 'screens/auth_page.dart';
import 'screens/home_page.dart';
import 'screens/pharmacy_panel_home_page.dart';
import 'screens/home_care_provider_panel_home_page.dart';
import 'package:healzy_app/config/api_config.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local Notification init
  await LocalNotificationService.I.init();
  await LocalNotificationService.I.requestPermissions();

  // Load persisted token
  await TokenStore.load();

  // Load theme preference
  await ThemeController.I.load();

  runApp(const HealzyApp());
}

class HealzyApp extends StatelessWidget {
  const HealzyApp({super.key});

  Widget _getInitialPage(AuthService authService) {
    final token = TokenStore.get();
    if (token != null && token.isNotEmpty) {
      try {
        if (!JwtDecoder.isExpired(token)) {
          final decoded = JwtDecoder.decode(token);
          final role = (decoded["role"] ??
                  decoded["http://schemas.microsoft.com/ws/2008/06/identity/claims/role"])
              ?.toString();

          if (role == "Customer") return const HomePage();
          if (role == "Pharmacist") return const PharmacyPanelHomePage();
          if (role == "HomeCareProvider") return const HomeCareProviderPanelHomePage();
        }
      } catch (_) {
        // Token decode failed, go to login
      }
    }

    return AuthPage(
      authService: authService,
      customerHome: const HomePage(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseUrl = ApiConfig.baseUrl;
    final authService = AuthService(baseUrl: baseUrl);

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
        home: _getInitialPage(authService),
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
    return child;
  }
}
