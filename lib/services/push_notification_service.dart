import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import 'notification_api_service.dart';
import 'token_store.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Background/terminated state'te FCM payload'i sistemin notification tarafindan gosterilir.
  // iOS'ta APNs notification field'i payload'a eklendigi icin ekstra ise gerek yok.
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService I = PushNotificationService._();

  final FirebaseMessaging _fm = FirebaseMessaging.instance;
  final NotificationApiService _api =
      NotificationApiService(baseUrl: ApiConfig.baseUrl);

  String? _currentToken;
  bool _initialized = false;
  bool _registeredOnBackend = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    await _fm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // iOS foreground'da banner/sound gostermesi icin
    await _fm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // iOS foreground gosterimini setForegroundNotificationPresentationOptions
    // hallediyor; ayrica showNow cagirmiyoruz, yoksa cift bildirim olur.
    FirebaseMessaging.onMessage.listen((_) {});

    _fm.onTokenRefresh.listen((newToken) {
      _currentToken = newToken;
      _registeredOnBackend = false;
      tryRegisterToken();
    });

    // iOS'ta APNs token gelene kadar FCM token null olabilir.
    try {
      _currentToken = await _fm.getToken();
    } catch (e) {
      if (kDebugMode) print('FCM getToken error: $e');
    }

    await tryRegisterToken();
  }

  /// JWT token mevcutsa cihaz token'ini backend'e kaydeder.
  /// Login sonrasi ve resume'da cagrilabilir.
  Future<void> tryRegisterToken() async {
    if (_registeredOnBackend) return;
    final jwt = TokenStore.get();
    if (jwt == null || jwt.isEmpty) return;

    var token = _currentToken;
    if (token == null) {
      try {
        token = await _fm.getToken();
        _currentToken = token;
      } catch (_) {}
    }
    if (token == null || token.isEmpty) return;

    try {
      await _api.registerDeviceToken(
        token: token,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
      _registeredOnBackend = true;
    } catch (e) {
      if (kDebugMode) print('Device token register failed: $e');
    }
  }

  /// Logout sirasinda cagrilir.
  Future<void> unregisterCurrentToken() async {
    final token = _currentToken;
    if (token == null) return;
    try {
      await _api.unregisterDeviceToken(token: token);
    } catch (_) {}
    _registeredOnBackend = false;
  }
}
