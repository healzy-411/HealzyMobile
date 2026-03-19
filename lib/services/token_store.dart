import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStore {
  static const _storage = FlutterSecureStorage();
  static String? _cachedToken;

  static Future<void> set(String token) async {
    _cachedToken = token;
    await _storage.write(key: 'jwt_token', value: token);
  }

  static String? get() => _cachedToken;

  static Future<String?> load() async {
    _cachedToken = await _storage.read(key: 'jwt_token');
    return _cachedToken;
  }

  static Future<void> clear() async {
    _cachedToken = null;
    await _storage.delete(key: 'jwt_token');
  }
}
