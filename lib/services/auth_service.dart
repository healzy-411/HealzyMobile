import 'dart:convert';
import 'package:http/http.dart' as http;

import 'token_store.dart';
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

  /// Refresh token ile yeni access+refresh çifti alır ve TokenStore'a yazar.
  /// Başarısız olursa exception fırlatır; çağıran taraf logout akışını tetikler.
  Future<void> refresh() async {
    final rt = TokenStore.getRefreshToken();
    if (rt == null || rt.isEmpty) {
      throw Exception('Refresh token bulunamadi.');
    }
    final url = Uri.parse('$baseUrl/api/auth/refresh');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': rt}),
    );
    final body = _decode(res);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(body['message'] ?? 'Refresh failed (${res.statusCode})');
    }
    final newAccess = (body['accessToken'] ?? body['token'])?.toString();
    final newRefresh = body['refreshToken']?.toString();
    if (newAccess == null || newAccess.isEmpty) {
      throw Exception('Refresh response invalid.');
    }
    await TokenStore.set(newAccess);
    if (newRefresh != null && newRefresh.isNotEmpty) {
      await TokenStore.setRefreshToken(newRefresh);
    }
  }

  /// Backend'e logout isteği yollar (refresh token revoke) ve local store'u temizler.
  Future<void> logout() async {
    final token = TokenStore.get();
    final rt = TokenStore.getRefreshToken();
    try {
      if (token != null) {
        await http.post(
          Uri.parse('$baseUrl/api/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'refreshToken': rt}),
        );
      }
    } catch (_) {
      // logout best-effort; backend down olsa bile local clear yap
    }
    await TokenStore.clear();
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

  Future<void> forgotPassword({required String email}) async {
    final url = Uri.parse('$baseUrl/api/auth/password/forgot');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"email": email}),
    );

    final body = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300) return;

    throw Exception(body["message"] ?? "İstek başarısız (${res.statusCode})");
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/password/reset');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "email": email,
        "code": code,
        "newPassword": newPassword,
      }),
    );

    final body = _decode(res);
    if (res.statusCode >= 200 && res.statusCode < 300) return;

    throw Exception(body["message"] ?? "Şifre sıfırlama başarısız (${res.statusCode})");
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

  Future<void> requestEmailChange() async {
    final token = TokenStore.get();
    if (token == null || token.isEmpty) {
      throw Exception("Token bulunamadı. Lütfen tekrar giriş yapın.");
    }
    final url = Uri.parse('$baseUrl/api/auth/email/change/request');
    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (res.statusCode >= 200 && res.statusCode < 300) return;

    final body = _decode(res);
    throw Exception(body["message"] ?? "Kod gönderilemedi (${res.statusCode})");
  }

  Future<void> confirmEmailChange({required String code, required String newEmail}) async {
    final token = TokenStore.get();
    if (token == null || token.isEmpty) {
      throw Exception("Token bulunamadı. Lütfen tekrar giriş yapın.");
    }
    final url = Uri.parse('$baseUrl/api/auth/email/change/confirm');
    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({"code": code, "newEmail": newEmail}),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) return;

    final body = _decode(res);
    throw Exception(body["message"] ?? "E-posta güncellenemedi (${res.statusCode})");
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