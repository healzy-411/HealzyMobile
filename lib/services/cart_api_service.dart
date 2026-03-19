import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/cart_model.dart';
import 'token_store.dart';

class CartApiService {
  final String baseUrl;
  final Future<String?> Function() getToken; // token'ı buradan alacağız

  CartApiService({required this.baseUrl, required this.getToken});

  Future<Map<String, String>> _headers() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception("Token not found. Please login again.");
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<CartResponse> getMyCart() async {
    final uri = Uri.parse('$baseUrl/api/cart/me');
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 401) {
      await TokenStore.clear();
      throw Exception("Oturum suresi doldu. Lutfen tekrar giris yapin.");
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return CartResponse.fromJson(jsonDecode(res.body));
    }
    throw Exception('Get cart failed: ${res.statusCode} ${res.body}');
  }

  Future<CartResponse> addToCart({
    required int pharmacyId,
    required int medicineId,
    required int quantity,
  }) async {
    final uri = Uri.parse('$baseUrl/api/cart/items');
    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode({
        "pharmacyId": pharmacyId,
        "medicineId": medicineId,
        "quantity": quantity,
      }),
    );
    if (res.statusCode == 401) {
      await TokenStore.clear();
      throw Exception("Oturum suresi doldu. Lutfen tekrar giris yapin.");
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return CartResponse.fromJson(jsonDecode(res.body));
    }
    throw Exception('Add to cart failed: ${res.statusCode} ${res.body}');
  }

  Future<CartResponse> updateItemQty({
    required int itemId,
    required int quantity,
  }) async {
    final uri = Uri.parse('$baseUrl/api/cart/items/$itemId');
    final res = await http.put(
      uri,
      headers: await _headers(),
      body: jsonEncode({"quantity": quantity}),
    );
    if (res.statusCode == 401) {
      await TokenStore.clear();
      throw Exception("Oturum suresi doldu. Lutfen tekrar giris yapin.");
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return CartResponse.fromJson(jsonDecode(res.body));
    }
    throw Exception('Update qty failed: ${res.statusCode} ${res.body}');
  }

  Future<CartResponse> removeItem(int itemId) async {
    final uri = Uri.parse('$baseUrl/api/cart/items/$itemId');
    final res = await http.delete(uri, headers: await _headers());
    if (res.statusCode == 401) {
      await TokenStore.clear();
      throw Exception("Oturum suresi doldu. Lutfen tekrar giris yapin.");
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return CartResponse.fromJson(jsonDecode(res.body));
    }
    throw Exception('Remove item failed: ${res.statusCode} ${res.body}');
  }

  Future<void> clearCart() async {
    final uri = Uri.parse('$baseUrl/api/cart/me');
    final res = await http.delete(uri, headers: await _headers());
    if (res.statusCode == 401) {
      await TokenStore.clear();
      throw Exception("Oturum suresi doldu. Lutfen tekrar giris yapin.");
    }
    if (res.statusCode == 204) return;
    throw Exception('Clear cart failed: ${res.statusCode} ${res.body}');
  }
}
