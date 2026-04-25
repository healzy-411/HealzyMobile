import 'dart:convert';
import 'package:http/http.dart' as http;

import '../Models/saved_card_model.dart';
import 'token_store.dart';

class SavedCardApiService {
  final String baseUrl;
  SavedCardApiService({required this.baseUrl});

  Map<String, String> _headers() {
    final token = TokenStore.get();
    if (token == null || token.isEmpty) {
      throw Exception("Token yok. Lutfen tekrar giris yap.");
    }
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  Future<void> _check401(http.Response res) async {
    if (res.statusCode == 401) {
      await TokenStore.clear();
      throw Exception("Oturum suresi doldu. Lutfen tekrar giris yapin.");
    }
  }

  bool _isSuccess(int code) => code >= 200 && code < 300;

  String _extractMessage(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      return body['message'] ?? 'Bir hata olustu (${res.statusCode})';
    } catch (_) {
      return 'Bir hata olustu (${res.statusCode})';
    }
  }

  Future<List<SavedCardDto>> getMyCards() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/saved-cards'),
      headers: _headers(),
    );
    await _check401(res);
    if (_isSuccess(res.statusCode)) {
      final list = jsonDecode(res.body) as List;
      return list.map((e) => SavedCardDto.fromJson(e)).toList();
    }
    throw Exception(_extractMessage(res));
  }

  Future<SavedCardDto> createCard({
    required String cardName,
    required String cardholderName,
    required String cardNumber,
    required int expiryMonth,
    required int expiryYear,
    bool isDefault = false,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/saved-cards'),
      headers: _headers(),
      body: jsonEncode({
        'cardName': cardName,
        'cardholderName': cardholderName,
        'cardNumber': cardNumber,
        'expiryMonth': expiryMonth,
        'expiryYear': expiryYear,
        'isDefault': isDefault,
      }),
    );
    await _check401(res);
    if (_isSuccess(res.statusCode)) {
      return SavedCardDto.fromJson(jsonDecode(res.body));
    }
    throw Exception(_extractMessage(res));
  }

  Future<SavedCardDto> updateCard({
    required int id,
    required String cardName,
    required String cardholderName,
    required int expiryMonth,
    required int expiryYear,
    bool isDefault = false,
    String? cardNumber,
  }) async {
    final body = <String, dynamic>{
      'cardName': cardName,
      'cardholderName': cardholderName,
      'expiryMonth': expiryMonth,
      'expiryYear': expiryYear,
      'isDefault': isDefault,
    };
    if (cardNumber != null && cardNumber.isNotEmpty) {
      body['cardNumber'] = cardNumber;
    }
    final res = await http.put(
      Uri.parse('$baseUrl/api/saved-cards/$id'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    await _check401(res);
    if (_isSuccess(res.statusCode)) {
      return SavedCardDto.fromJson(jsonDecode(res.body));
    }
    throw Exception(_extractMessage(res));
  }

  Future<void> deleteCard(int id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/saved-cards/$id'),
      headers: _headers(),
    );
    await _check401(res);
    if (!_isSuccess(res.statusCode)) {
      throw Exception(_extractMessage(res));
    }
  }

  Future<void> setDefault(int id) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/saved-cards/$id/default'),
      headers: _headers(),
    );
    await _check401(res);
    if (!_isSuccess(res.statusCode)) {
      throw Exception(_extractMessage(res));
    }
  }
}
