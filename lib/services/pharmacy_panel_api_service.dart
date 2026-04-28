import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session_guard.dart';
import '../services/token_store.dart';
import '../Models/order_model.dart';

class PharmacyPanelApiService {
  final String baseUrl;

  PharmacyPanelApiService({required this.baseUrl});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${TokenStore.get()}',
      };

  Future<void> _check401(http.Response res) => SessionGuard.handle401(res);

  // DELETE /api/pharmacy-panel/account — eczane hesabini ve eczaneyi siler
  Future<void> deleteAccount(String confirmation) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/pharmacy-panel/account'),
      headers: _headers,
      body: jsonEncode({'confirmation': confirmation}),
    );
    await _check401(res);
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception(body['message'] ?? 'Hesap silinemedi (${res.statusCode})');
  }

  // GET /api/pharmacy-panel/profile
  Future<Map<String, dynamic>> getProfile() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/pharmacy-panel/profile'),
      headers: _headers,
    );
    await _check401(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body["message"] ?? "Profile failed (${res.statusCode})");
  }

  // PUT /api/pharmacy-panel/toggle-status
  Future<Map<String, dynamic>> toggleStatus() async {
    final res = await http.put(
      Uri.parse('$baseUrl/api/pharmacy-panel/toggle-status'),
      headers: _headers,
    );
    await _check401(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body["message"] ?? "Toggle failed (${res.statusCode})");
  }

  // GET /api/pharmacy-panel/orders
  Future<List<OrderDto>> getOrders() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/pharmacy-panel/orders'),
      headers: _headers,
    );
    await _check401(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = jsonDecode(res.body) as List;
      return list.map((e) => OrderDto.fromJson(e)).toList();
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception(body["message"] ?? "Orders failed (${res.statusCode})");
  }

  // GET /api/pharmacy-panel/dashboard?from=...&to=...
  Future<Map<String, dynamic>> getDashboard(DateTime from, DateTime to) async {
    final fromStr = from.toUtc().toIso8601String();
    final toStr = to.toUtc().toIso8601String();
    final res = await http.get(
      Uri.parse('$baseUrl/api/pharmacy-panel/dashboard?from=$fromStr&to=$toStr'),
      headers: _headers,
    );
    await _check401(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body["message"] ?? "Dashboard failed (${res.statusCode})");
  }

  // ===================== STOK YÖNETİMİ =====================

  // GET /api/pharmacy-panel/stocks
  Future<List<Map<String, dynamic>>> getStocks() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/pharmacy-panel/stocks'),
      headers: _headers,
    );
    await _check401(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = jsonDecode(res.body) as List;
      return list.cast<Map<String, dynamic>>();
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception(body["message"] ?? "Stocks failed (${res.statusCode})");
  }

  // POST /api/pharmacy-panel/stocks
  Future<Map<String, dynamic>> addStock({
    required int medicineId,
    required int quantity,
    required double unitPrice,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/pharmacy-panel/stocks'),
      headers: _headers,
      body: jsonEncode({
        "medicineId": medicineId,
        "quantity": quantity,
        "unitPrice": unitPrice,
      }),
    );
    await _check401(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body["message"] ?? "Add stock failed (${res.statusCode})");
  }

  // PUT /api/pharmacy-panel/stocks/{medicineId}
  Future<Map<String, dynamic>> updateStock({
    required int medicineId,
    required int quantity,
    required double unitPrice,
  }) async {
    final res = await http.put(
      Uri.parse('$baseUrl/api/pharmacy-panel/stocks/$medicineId'),
      headers: _headers,
      body: jsonEncode({
        "quantity": quantity,
        "unitPrice": unitPrice,
      }),
    );
    await _check401(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body["message"] ?? "Update stock failed (${res.statusCode})");
  }

  // DELETE /api/pharmacy-panel/stocks/{medicineId}
  Future<void> removeStock(int medicineId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/pharmacy-panel/stocks/$medicineId'),
      headers: _headers,
    );
    await _check401(res);
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception(body["message"] ?? "Remove stock failed (${res.statusCode})");
  }

  // GET /api/medicines/all?includeRx=true (tüm ilaçlar - stok ekleme için, reçeteliler dahil)
  Future<List<Map<String, dynamic>>> getAllMedicines() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/medicines/all?includeRx=true'),
      headers: _headers,
    );
    await _check401(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = jsonDecode(res.body) as List;
      return list.cast<Map<String, dynamic>>();
    }
    throw Exception("Medicines fetch failed (${res.statusCode})");
  }

  // GET /api/categories
  Future<List<Map<String, dynamic>>> getCategories() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/categories'),
      headers: _headers,
    );
    await _check401(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = jsonDecode(res.body) as List;
      return list.cast<Map<String, dynamic>>();
    }
    throw Exception("Categories fetch failed (${res.statusCode})");
  }

  // PUT /api/pharmacy-panel/orders/{orderId}/status
  Future<OrderDto> updateOrderStatus(int orderId, String status, {String? note}) async {
    final res = await http.put(
      Uri.parse('$baseUrl/api/pharmacy-panel/orders/$orderId/status'),
      headers: _headers,
      body: jsonEncode({"status": status, "note": note}),
    );
    await _check401(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return OrderDto.fromJson(body);
    }
    throw Exception(body["message"] ?? "Status update failed (${res.statusCode})");
  }

  // PUT /api/pharmacy-panel/profile
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('$baseUrl/api/pharmacy-panel/profile'),
      headers: _headers,
      body: jsonEncode(data),
    );
    await _check401(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body["message"] ?? "Update profile failed (${res.statusCode})");
  }

  // GET /api/pharmacy-panel/summary
  Future<Map<String, dynamic>> getSummary() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/pharmacy-panel/summary'),
      headers: _headers,
    );
    await _check401(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body["message"] ?? "Summary failed (${res.statusCode})");
  }

  // GET /api/pharmacy-panel/insurances
  Future<List<Map<String, dynamic>>> getInsurances() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/pharmacy-panel/insurances'),
      headers: _headers,
    );
    await _check401(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = jsonDecode(res.body) as List;
      return list.cast<Map<String, dynamic>>();
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception(body["message"] ?? "Insurances failed (${res.statusCode})");
  }

  // POST /api/pharmacy-panel/insurances
  Future<void> addInsurance(int insuranceCompanyId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/pharmacy-panel/insurances'),
      headers: _headers,
      body: jsonEncode({"insuranceCompanyId": insuranceCompanyId}),
    );
    await _check401(res);
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception(body["message"] ?? "Add insurance failed (${res.statusCode})");
  }

  // DELETE /api/pharmacy-panel/insurances/{id}
  Future<void> removeInsurance(int insuranceCompanyId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/pharmacy-panel/insurances/$insuranceCompanyId'),
      headers: _headers,
    );
    await _check401(res);
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception(body["message"] ?? "Remove insurance failed (${res.statusCode})");
  }

  // POST /api/geocoding/geocode
  Future<Map<String, dynamic>> geocodeAddress(String district, String? address) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/geocoding/geocode'),
      headers: _headers,
      body: jsonEncode({"district": district, "address": address}),
    );
    await _check401(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body["message"] ?? "Geocode failed (${res.statusCode})");
  }

  // POST /api/geocoding/reverse-geocode
  Future<Map<String, dynamic>> reverseGeocode(double latitude, double longitude) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/geocoding/reverse-geocode'),
      headers: _headers,
      body: jsonEncode({"latitude": latitude, "longitude": longitude}),
    );
    await _check401(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body["message"] ?? "Reverse geocode failed (${res.statusCode})");
  }

  // GET /api/pharmacy-panel/registration-info
  Future<Map<String, dynamic>> getRegistrationInfo() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/pharmacy-panel/registration-info'),
      headers: _headers,
    );
    await _check401(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body["message"] ?? "Registration info failed (${res.statusCode})");
  }

  // GET /api/insurances (tüm sigorta şirketleri)
  Future<List<Map<String, dynamic>>> getAllInsuranceCompanies() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/insurances'),
      headers: _headers,
    );
    await _check401(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = jsonDecode(res.body) as List;
      return list.cast<Map<String, dynamic>>();
    }
    throw Exception("Insurance companies fetch failed (${res.statusCode})");
  }
}
