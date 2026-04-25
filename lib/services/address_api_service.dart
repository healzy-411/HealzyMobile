import 'dart:convert';
import 'package:http/http.dart' as http;

import '../Models/address_model.dart';
import 'session_guard.dart';
import 'token_store.dart';

class AddressApiService {
  final String baseUrl;
  AddressApiService({required this.baseUrl});

  Map<String, String> _headers() {
    final token = TokenStore.get();
    if (token == null || token.isEmpty) {
      throw Exception("Token yok. Lütfen tekrar giriş yap.");
    }
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  String _extractMessage(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded["message"] != null) {
        return decoded["message"].toString();
      }
    } catch (_) {}
    return fallback;
  }

  bool _isSuccess(int code) => code >= 200 && code < 300;

  Future<void> _check401(http.Response res) => SessionGuard.handle401(res);

  Future<List<AddressDto>> getMyAddresses() async {
    final uri = Uri.parse("$baseUrl/api/addresses/my");
    final res = await http.get(uri, headers: _headers());

    await _check401(res);

    if (_isSuccess(res.statusCode)) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) {
        return decoded
            .map((x) => AddressDto.fromJson(x as Map<String, dynamic>))
            .toList();
      }
      return [];
    }

    final msg = _extractMessage(
      res.body,
      "Adresler alınamadı (${res.statusCode})",
    );
    throw Exception(msg);
  }

  Future<void> selectAddress(int id) async {
    final uri = Uri.parse("$baseUrl/api/addresses/$id/select");
    final res = await http.post(uri, headers: _headers());

    await _check401(res);

    if (_isSuccess(res.statusCode)) return;

    final msg = _extractMessage(
      res.body,
      "Adres seçilemedi (${res.statusCode})",
    );
    throw Exception(msg);
  }

  Future<void> setDefault(int id) async {
    final uri = Uri.parse("$baseUrl/api/addresses/$id/default");
    final res = await http.post(uri, headers: _headers());

    await _check401(res);

    if (_isSuccess(res.statusCode)) return;

    final msg = _extractMessage(
      res.body,
      "Varsayılan adres ayarlanamadı (${res.statusCode})",
    );
    throw Exception(msg);
  }

  Future<AddressDto> updateAddress({
    required int id,
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse("$baseUrl/api/addresses/$id");
    final res = await http.put(
      uri,
      headers: _headers(),
      body: jsonEncode(body),
    );

    await _check401(res);

    if (_isSuccess(res.statusCode)) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return AddressDto.fromJson(decoded);
    }

    final msg = _extractMessage(
      res.body,
      "Adres güncellenemedi (${res.statusCode})",
    );
    throw Exception(msg);
  }

  Future<AddressDto> createAddress(Map<String, dynamic> body) async {
    final uri = Uri.parse("$baseUrl/api/addresses");
    final res = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode(body),
    );

    await _check401(res);

    if (_isSuccess(res.statusCode)) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return AddressDto.fromJson(decoded);
    }

    final msg = _extractMessage(
      res.body,
      "Adres eklenemedi (${res.statusCode})",
    );
    throw Exception(msg);
  }

  Future<void> deleteAddress(int id) async {
    final uri = Uri.parse("$baseUrl/api/addresses/$id");
    final res = await http.delete(uri, headers: _headers());

    await _check401(res);

    if (_isSuccess(res.statusCode)) return;

    final msg = _extractMessage(
      res.body,
      "Adres silinemedi (${res.statusCode})",
    );
    throw Exception(msg);
  }
}