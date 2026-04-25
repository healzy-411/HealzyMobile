import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStore {
  static const _storage = FlutterSecureStorage();
  static String? _cachedToken;
  static String? _cachedRefreshToken;

  // ───────── access token ─────────

  static Future<void> set(String token) async {
    _cachedToken = token;
    await _storage.write(key: 'jwt_token', value: token);
  }

  static String? get() => _cachedToken;

  // ───────── refresh token ─────────

  static Future<void> setRefreshToken(String token) async {
    _cachedRefreshToken = token;
    await _storage.write(key: 'refresh_token', value: token);
  }

  static String? getRefreshToken() => _cachedRefreshToken;

  static Future<String?> loadRefreshToken() async {
    _cachedRefreshToken = await _storage.read(key: 'refresh_token');
    return _cachedRefreshToken;
  }

  // ───────── lifecycle ─────────

  static Future<String?> load() async {
    _cachedToken = await _storage.read(key: 'jwt_token');
    _cachedRefreshToken = await _storage.read(key: 'refresh_token');
    return _cachedToken;
  }

  static Future<void> clear() async {
    _cachedToken = null;
    _cachedRefreshToken = null;
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'refresh_token');
  }
}
