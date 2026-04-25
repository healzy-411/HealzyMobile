import 'dart:convert';
import 'package:http/http.dart' as http;

import '../services/token_store.dart';
import '../Models/me_model.dart';

class EmailNotVerifiedException implements Exception {
  final String email;
  final String message;
  EmailNotVerifiedException({required this.email, required this.message});

  @override
  String toString() => message;
}

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
    required String licenseNumber,
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
        "licenseNumber": licenseNumber,
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
    required String licenseNumber,
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
        "licenseNumber": licenseNumber,
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
    bool rememberMe = false,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/login');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "email": email,
        "password": password,
        "rememberMe": rememberMe,
      }),
    );

    final body = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;

    if (res.statusCode == 403 && body["requiresEmailVerification"] == true) {
      throw EmailNotVerifiedException(
        email: body["email"]?.toString() ?? email,
        message: body["message"]?.toString() ?? "Hesabınız henüz doğrulanmamış.",
      );
    }

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
      throw Exception("Oturumunuz sona erdi. Lütfen tekrar giriş yapın.");
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

  Future<MeDto> updateProfile({String? firstName, String? lastName, String? phone}) async {
    final token = TokenStore.get();
    if (token == null || token.isEmpty) {
      throw Exception("Token bulunamadı. Lütfen tekrar giriş yapın.");
    }

    final url = Uri.parse('$baseUrl/api/auth/profile');
    final body = <String, dynamic>{};
    if (firstName != null) body['firstName'] = firstName;
    if (lastName != null) body['lastName'] = lastName;
    if (phone != null) body['phone'] = phone;

    final res = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return MeDto.fromJson(jsonDecode(res.body));
    }

    final data = _decode(res);
    throw Exception(data["message"] ?? "Profil güncellenemedi (${res.statusCode})");
  }

  Future<void> deleteAccount(String confirmation) async {
    final token = TokenStore.get();
    if (token == null || token.isEmpty) {
      throw Exception("Token bulunamadı. Lütfen tekrar giriş yapın.");
    }

    final url = Uri.parse('$baseUrl/api/auth/account');
    final res = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({"confirmation": confirmation}),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) return;

    final body = _decode(res);
    throw Exception(body["message"] ?? "Hesap silinemedi (${res.statusCode})");
  }

  Map<String, dynamic> _decode(http.Response res) {
    if (res.body.isEmpty) return {};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}