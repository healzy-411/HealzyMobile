import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_store.dart';
import '../Models/order_model.dart';
import '../Models/cart_model.dart';

class OrderApiService {
  final String baseUrl;
  OrderApiService({required this.baseUrl});

  Map<String, String> _headersWithAuth() {
    final token = TokenStore.get();
    if (token == null || token.isEmpty) {
      throw Exception("Not authenticated (token missing).");
    }
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  /// POST /api/orders
  Future<Map<String, dynamic>> createFromMyCart({Map<String, dynamic>? body}) async {
    final uri = Uri.parse("$baseUrl/api/orders");

    final res = await http.post(
      uri,
      headers: _headersWithAuth(),
      body: body != null ? jsonEncode(body) : null,
    );

    if (res.statusCode == 401) {
      await TokenStore.clear();
      throw Exception("Oturum suresi doldu. Lutfen tekrar giris yapin.");
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    throw Exception(_extractMessage(res));
  }

  /// GET /api/orders/me
  Future<List<dynamic>> getMyOrdersRaw() async {
    final uri = Uri.parse("$baseUrl/api/orders/me");

    final res = await http.get(
      uri,
      headers: _headersWithAuth(),
    );

    if (res.statusCode == 401) {
      await TokenStore.clear();
      throw Exception("Oturum suresi doldu. Lutfen tekrar giris yapin.");
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) return decoded;
      return [];
    }

    throw Exception(_extractMessage(res));
  }

  Future<List<OrderDto>> getMyOrders() async {
    final raw = await getMyOrdersRaw();
    return raw
        .whereType<Map<String, dynamic>>()
        .map((j) => OrderDto.fromJson(j))
        .toList();
  }

  /// GET /api/orders/active
  Future<List<OrderDto>> getActiveOrders() async {
    final uri = Uri.parse("$baseUrl/api/orders/active");

    final res = await http.get(
      uri,
      headers: _headersWithAuth(),
    );

    if (res.statusCode == 401) {
      await TokenStore.clear();
      throw Exception("Oturum suresi doldu. Lutfen tekrar giris yapin.");
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((j) => OrderDto.fromJson(j))
            .toList();
      }
      return [];
    }

    throw Exception(_extractMessage(res));
  }

  /// POST /api/orders/{orderId}/repeat
  Future<CartResponse> repeatOrder(int orderId) async {
    final uri = Uri.parse("$baseUrl/api/orders/$orderId/repeat");

    final res = await http.post(
      uri,
      headers: _headersWithAuth(),
    );

    if (res.statusCode == 401) {
      await TokenStore.clear();
      throw Exception("Oturum suresi doldu. Lutfen tekrar giris yapin.");
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return CartResponse.fromJson(jsonDecode(res.body));
    }

    throw Exception(_extractMessage(res));
  }

  String _extractMessage(http.Response res) {
    // Controller bad request: { message: "..." }
    String msg = "Request failed (${res.statusCode})";
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map) {
        if (decoded["message"] != null) return decoded["message"].toString();
        if (decoded["title"] != null) return decoded["title"].toString();
        if (decoded["error"] != null) return decoded["error"].toString();
      }
    } catch (_) {}
    return msg;
  }
}