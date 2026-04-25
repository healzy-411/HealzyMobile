import 'dart:convert';
import 'package:http/http.dart' as http;

import '../Models/home_care_models.dart';
import '../services/token_store.dart';

class HomeCareApiService {
  final String baseUrl;

  HomeCareApiService({required this.baseUrl});

  Map<String, String> _authHeaders() {
    final token = TokenStore.get();
    if (token == null || token.isEmpty) {
      throw Exception("Token yok. Lütfen tekrar giriş yap.");
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  bool _ok(int code) => code >= 200 && code < 300;

  Future<void> _check401(http.Response res) async {
    if (res.statusCode == 401) {
      await TokenStore.clear();
      throw Exception("Oturum suresi doldu. Lutfen tekrar giris yapin.");
    }
  }

  String _extractMessage(http.Response res, String fallback) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {}
    return fallback;
  }

  // ✅ NEW: GET /api/home-care/requests/providers  (controller içine eklediğin route)
  Future<List<HomeCareProviderModel>> getProviders() async {
    final uri = Uri.parse('$baseUrl/api/home-care/requests/providers');

    final res = await http.get(uri, headers: _authHeaders());
    await _check401(res);
    if (_ok(res.statusCode)) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(HomeCareProviderModel.fromJson)
            .toList();
      }
      return [];
    }
    throw Exception(
      _extractMessage(res, 'Sağlayıcılar yüklenemedi (${res.statusCode})'),
    );
  }

  Future<List<String>> getProviderTimeSlots(int providerId) async {
    final uri = Uri.parse('$baseUrl/api/home-care/requests/providers/$providerId/time-slots');
    final res = await http.get(uri, headers: _authHeaders());
    await _check401(res);
    if (_ok(res.statusCode)) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((m) => (m['label'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return [];
    }
    return [];
  }

  /// Slot availability: kapasite ve doluluk bilgisi
  Future<List<Map<String, dynamic>>> getSlotAvailability(int providerId, String date) async {
    final uri = Uri.parse('$baseUrl/api/home-care/requests/providers/$providerId/slot-availability?date=$date');
    final res = await http.get(uri, headers: _authHeaders());
    await _check401(res);
    if (_ok(res.statusCode)) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  Future<HomeCareRequestModel> createRequest({
    required int providerId,
    required int addressId,
    required DateTime serviceDate, // local
    required String timeSlot,
    String? note,
  }) async {
    final uri = Uri.parse('$baseUrl/api/home-care/requests');

    final body = jsonEncode({
      'providerId': providerId,
      'addressId': addressId,
      'serviceDateUtc': serviceDate.toUtc().toIso8601String(),
      'timeSlot': timeSlot,
      'note': note,
    });

    final res = await http.post(uri, headers: _authHeaders(), body: body);
    await _check401(res);
    if (_ok(res.statusCode)) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return HomeCareRequestModel.fromJson(decoded);
    }
    throw Exception(
      _extractMessage(res, 'Talep oluşturulamadı (${res.statusCode})'),
    );
  }

  Future<List<HomeCareRequestModel>> getMyRequests() async {
    final uri = Uri.parse('$baseUrl/api/home-care/requests/me');
    final res = await http.get(uri, headers: _authHeaders());
    await _check401(res);
    if (_ok(res.statusCode)) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(HomeCareRequestModel.fromJson)
            .toList();
      }
      return [];
    }
    throw Exception(
      _extractMessage(res, 'Talepler yüklenemedi (${res.statusCode})'),
    );
  }

  Future<void> cancelRequest(int id) async {
    final uri = Uri.parse('$baseUrl/api/home-care/requests/$id/cancel');
    final res = await http.post(uri, headers: _authHeaders());
    await _check401(res);
    if (_ok(res.statusCode)) return;
    throw Exception(
      _extractMessage(res, 'Talep iptal edilemedi (${res.statusCode})'),
    );
  }
}