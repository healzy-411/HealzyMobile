import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session_guard.dart';
import '../services/token_store.dart';

class HomeCarePanelApiService {
  final String baseUrl;

  HomeCarePanelApiService({required this.baseUrl});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${TokenStore.get()}',
      };

  Future<void> _check401(http.Response res) => SessionGuard.handle401(res);

  // DELETE /api/home-care-panel/account — saglayici hesabini ve saglayiciyi siler
  Future<void> deleteAccount(String confirmation) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/home-care-panel/account'),
      headers: _headers,
      body: jsonEncode({'confirmation': confirmation}),
    );
    await _check401(res);
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception(body['message'] ?? 'Hesap silinemedi (${res.statusCode})');
  }

  // GET /api/home-care-panel/profile
  Future<Map<String, dynamic>> getProfile() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/home-care-panel/profile'),
      headers: _headers,
    );
    await _check401(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body["message"] ?? "Profile failed (${res.statusCode})");
  }

  // PUT /api/home-care-panel/profile
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('$baseUrl/api/home-care-panel/profile'),
      headers: _headers,
      body: jsonEncode(data),
    );
    await _check401(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body["message"] ?? "Update profile failed (${res.statusCode})");
  }

  // GET /api/home-care-panel/requests
  Future<List<Map<String, dynamic>>> getRequests() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/home-care-panel/requests'),
      headers: _headers,
    );
    await _check401(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = jsonDecode(res.body) as List;
      return list.cast<Map<String, dynamic>>();
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception(body["message"] ?? "Requests failed (${res.statusCode})");
  }

  // PUT /api/home-care-panel/requests/{requestId}/status
  Future<Map<String, dynamic>> updateRequestStatus(
    int requestId,
    String status, {
    String? note,
    double? earningAmount,
  }) async {
    final res = await http.put(
      Uri.parse('$baseUrl/api/home-care-panel/requests/$requestId/status'),
      headers: _headers,
      body: jsonEncode({
        "status": status,
        "note": note,
        "earningAmount": earningAmount,
      }),
    );
    await _check401(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body["message"] ?? "Status update failed (${res.statusCode})");
  }

  // GET /api/home-care-panel/registration-info
  Future<Map<String, dynamic>> getRegistrationInfo() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/home-care-panel/registration-info'),
      headers: _headers,
    );
    await _check401(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body["message"] ?? "Registration info failed (${res.statusCode})");
  }

  // PUT /api/home-care-panel/update-info
  Future<Map<String, dynamic>> updateProviderInfo(Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('$baseUrl/api/home-care-panel/update-info'),
      headers: _headers,
      body: jsonEncode(data),
    );
    await _check401(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body["message"] ?? "Update info failed (${res.statusCode})");
  }

  // GET /api/home-care-panel/employees
  Future<List<Map<String, dynamic>>> getEmployees() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/home-care-panel/employees'),
      headers: _headers,
    );
    await _check401(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = jsonDecode(res.body) as List;
      return list.cast<Map<String, dynamic>>();
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception(body["message"] ?? "Employees failed (${res.statusCode})");
  }

  // GET /api/home-care-panel/employees/available?requestId=
  Future<List<Map<String, dynamic>>> getAvailableEmployees(int requestId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/home-care-panel/employees/available?requestId=$requestId'),
      headers: _headers,
    );
    await _check401(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = jsonDecode(res.body) as List;
      return list.cast<Map<String, dynamic>>();
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception(body["message"] ?? "Available employees failed (${res.statusCode})");
  }

  // PUT /api/home-care-panel/requests/{requestId}/accept-with-employee
  Future<Map<String, dynamic>> acceptRequestWithEmployee(
    int requestId,
    String employeeUserId, {
    String? note,
  }) async {
    final res = await http.put(
      Uri.parse('$baseUrl/api/home-care-panel/requests/$requestId/accept-with-employee'),
      headers: _headers,
      body: jsonEncode({"employeeUserId": employeeUserId, "note": note}),
    );
    await _check401(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body["message"] ?? "Accept failed (${res.statusCode})");
  }

  // GET /api/home-care-panel/summary
  Future<Map<String, dynamic>> getSummary() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/home-care-panel/summary'),
      headers: _headers,
    );
    await _check401(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw Exception(body["message"] ?? "Summary failed (${res.statusCode})");
  }
}
