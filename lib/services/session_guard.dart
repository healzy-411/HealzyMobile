import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../main.dart' show navigatorKey;
import '../screens/auth_page.dart';
import '../screens/home_page.dart';
import 'auth_service.dart';
import 'token_store.dart';

/// Tüm API service'leri için ortak 401 handler.
///
/// Davranış:
///  - status != 401 → no-op.
///  - 401 + elimizde refresh token var → refresh dene.
///    Başarılı: yeni access token store'a yazılır, çağrana
///    "yeniden deneyin" mesajı throw edilir (mevcut snackbar pattern'i bozulmaz,
///    bir sonraki kullanıcı aksiyonunda fresh token ile çalışır).
///    Başarısız: forceLogout() + redirect.
///  - 401 + refresh token yok → forceLogout() + redirect.
class SessionGuard {
  static bool _refreshing = false;
  static bool _redirecting = false;

  /// Tek seferde sadece bir refresh çalışır (race condition koruması).
  static Future<void> handle401(http.Response res) async {
    if (res.statusCode != 401) return;

    final rt = TokenStore.getRefreshToken();
    if (rt == null || rt.isEmpty) {
      await _forceLogoutAndRedirect();
      throw Exception('Oturum suresi doldu. Lutfen tekrar giris yapin.');
    }

    if (_refreshing) {
      // Başka bir istek refresh ediyor; biz sadece bekleyip tekrar dene mesajı verelim.
      throw Exception('Oturum yenileniyor, lutfen tekrar deneyin.');
    }

    _refreshing = true;
    try {
      await AuthService(baseUrl: ApiConfig.baseUrl).refresh();
      // Refresh başarılı: kullanıcının aksiyonu retry edilmeli.
      throw Exception('Oturum yenilendi, lutfen tekrar deneyin.');
    } catch (e) {
      // Refresh başarısız → logout + redirect
      await _forceLogoutAndRedirect();
      rethrow;
    } finally {
      _refreshing = false;
    }
  }

  static Future<void> _forceLogoutAndRedirect() async {
    if (_redirecting) return;
    _redirecting = true;
    try {
      await TokenStore.clear();
      final nav = navigatorKey.currentState;
      if (nav != null) {
        await nav.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => AuthPage(
              authService: AuthService(baseUrl: ApiConfig.baseUrl),
              customerHome: const HomePage(),
            ),
          ),
          (route) => false,
        );
      }
    } finally {
      _redirecting = false;
    }
  }
}
