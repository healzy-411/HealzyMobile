import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../services/token_store.dart';
import '../theme/app_colors.dart';
import 'auth_page.dart';
import 'home_page.dart';
import 'pharmacy_panel_home_page.dart';
import 'home_care_provider_panel_home_page.dart';

/// Splash sonrası entry point.
/// Token varsa backend ile doğrular (`/api/auth/me`), sonuca göre rolüne uygun
/// ana sayfaya veya AuthPage'e yönlendirir. Sunucuda silinmiş / deaktif edilmiş
/// hesapları tespit edip uygulamadan otomatik çıkarır.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthService _authService;
  Future<Widget>? _resolved;

  @override
  void initState() {
    super.initState();
    _authService = AuthService(baseUrl: ApiConfig.baseUrl);
    _resolved = _resolveStartPage();
  }

  Future<Widget> _resolveStartPage() async {
    final token = TokenStore.get();

    // Token yoksa veya expired → direkt login
    if (token == null || token.isEmpty || JwtDecoder.isExpired(token)) {
      await TokenStore.clear();
      return _authPage();
    }

    // Token cihazda var → backend'e doğrulat (hesap silinmiş/pasif olabilir)
    try {
      final me = await _authService.me();
      switch (me.role) {
        case 'Customer':
          return const HomePage();
        case 'Pharmacist':
          return const PharmacyPanelHomePage();
        case 'HomeCareProvider':
          return const HomeCareProviderPanelHomePage();
        default:
          await TokenStore.clear();
          return _authPage();
      }
    } catch (e) {
      final msg = e.toString();
      // 401/403/404 → hesap geçersiz → tokens temiz, login
      // SessionGuard zaten redirect yapmış olabilir; yine de güvenli AuthPage döndürelim
      if (msg.contains('401') ||
          msg.contains('403') ||
          msg.contains('404') ||
          msg.contains('Me failed') ||
          msg.contains('Oturum')) {
        await TokenStore.clear();
        return _authPage();
      }
      // Network / 5xx → token decode'a fallback (offline tolerance)
      try {
        final decoded = JwtDecoder.decode(token);
        final role = (decoded['role'] ??
                decoded['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'])
            ?.toString();
        if (role == 'Customer') return const HomePage();
        if (role == 'Pharmacist') return const PharmacyPanelHomePage();
        if (role == 'HomeCareProvider') {
          return const HomeCareProviderPanelHomePage();
        }
      } catch (_) {}
      return _authPage();
    }
  }

  Widget _authPage() => AuthPage(
        authService: _authService,
        customerHome: const HomePage(),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _resolved,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // Splash zaten 3sn animation gösterdi; burada genelde anında snap olur.
          // Yine de kısa bir blank fallback ekranı:
          return const Scaffold(
            backgroundColor: AppColors.darkBg,
            body: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return snapshot.data ?? _authPage();
      },
    );
  }
}
