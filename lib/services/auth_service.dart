import 'dart:convert';
import 'package:http/http.dart' as http;

import '../services/token_store.dart';
import '../models/me_model.dart';

class AuthService {
  final String baseUrl;

  AuthService({required this.baseUrl});

  Future<Map<String, dynamic>> registerCustomer({
    required String firstName,
    required String lastName,
    required String email,
    required String nationalId,
    required String phoneNumber,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/register');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "firstName": firstName,
        "lastName": lastName,
        "email": email,
        "nationalId": nationalId,
        // Backend RegisterRequest.Phone ile eşleşmeli
        "phone": phoneNumber,
        "password": password,
      }),
    );

    final body = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;

    throw Exception(body["message"] ?? "Register failed (${res.statusCode})");
  }

  Future<Map<String, dynamic>> registerPharmacist({
    required String firstName,
    required String lastName,
    required String email,
    required String nationalId,
    required String phone,
    required String password,
    required String pharmacyName,
    required String pharmacyDistrict,
    required String pharmacyAddress,
    required String pharmacyPhone,
    required double latitude,
    required double longitude,
    required String workingHours,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/register/pharmacist');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "firstName": firstName,
        "lastName": lastName,
        "email": email,
        "nationalId": nationalId,
        "phone": phone,
        "password": password,
        "pharmacyName": pharmacyName,
        "pharmacyDistrict": pharmacyDistrict,
        "pharmacyAddress": pharmacyAddress,
        "pharmacyPhone": pharmacyPhone,
        "latitude": latitude,
        "longitude": longitude,
        "workingHours": workingHours,
      }),
    );

    final body = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;

    throw Exception(body["message"] ?? "Pharmacist register failed (${res.statusCode})");
  }

  Future<Map<String, dynamic>> registerHomeCareProvider({
    required String firstName,
    required String lastName,
    required String email,
    required String nationalId,
    required String phone,
    required String password,
    required String providerName,
    required String providerPhone,
    required String city,
    required String district,
    required String address,
    String? description,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/register/home-care-provider');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "firstName": firstName,
        "lastName": lastName,
        "email": email,
        "nationalId": nationalId,
        "phone": phone,
        "password": password,
        "providerName": providerName,
        "providerPhone": providerPhone,
        "city": city,
        "district": district,
        "address": address,
        "description": description,
      }),
    );

    final body = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;

    throw Exception(body["message"] ?? "Home care provider register failed (${res.statusCode})");
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/login');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "email": email,
        "password": password,
      }),
    );

    final body = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;

    throw Exception(body["message"] ?? "Login failed (${res.statusCode})");
  }

  Future<void> sendEmailCode({required String email}) async {
    final url = Uri.parse('$baseUrl/api/auth/email/send-code');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"email": email}),
    );

    final body = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300) return;

    throw Exception(body["message"] ?? "Send code failed (${res.statusCode})");
  }

  Future<void> verifyEmail({required String email, required String code}) async {
    final url = Uri.parse('$baseUrl/api/auth/email/verify');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"email": email, "code": code}),
    );

    final body = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300) return;

    throw Exception(body["message"] ?? "Verify failed (${res.statusCode})");
  }

  // ✅ /api/auth/me
  Future<MeDto> me() async {
    final token = TokenStore.get();
    if (token == null || token.isEmpty) {
      throw Exception("Token yok. Lütfen tekrar giriş yap.");
    }

    final url = Uri.parse('$baseUrl/api/auth/me');
    final res = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final body = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return MeDto.fromJson(body);
    }

    throw Exception(body["message"] ?? "Me failed (${res.statusCode})");
  }

  Map<String, dynamic> _decode(http.Response res) {
    if (res.body.isEmpty) return {};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}