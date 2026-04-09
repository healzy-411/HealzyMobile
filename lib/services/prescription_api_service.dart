import 'dart:convert';

import 'package:http/http.dart' as http;

import '../Models/prescription_models.dart';
import '../Models/cart_model.dart';
import 'token_store.dart';

class PrescriptionApiService {
  final String baseUrl; // örn: http://localhost:5009

  PrescriptionApiService({required this.baseUrl});

  String _extractErrorMessage(http.Response res) {
    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data.containsKey('message')) return data['message'];
    } catch (_) {}
    return 'Bir hata oluştu (${res.statusCode})';
  }

  Future<Map<String, String>> _headers() async {
    final token = TokenStore.get();
    if (token == null || token.isEmpty) {
      throw Exception("Token not found. Please login again.");
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<PrescriptionDetailDto> loadPrescription(String prescriptionNumber) async {
    final uri = Uri.parse('$baseUrl/api/prescriptions/load');

    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode({
        "prescriptionNumber": prescriptionNumber.trim(),
      }),
    );

    if (res.statusCode == 401) {
      await TokenStore.clear();
      throw Exception("Oturum suresi doldu. Lutfen tekrar giris yapin.");
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return PrescriptionDetailDto.fromJson(data);
    }

    throw Exception(_extractErrorMessage(res));
  }

  Future<PrescriptionPriceResultDto> simulate({
    required String prescriptionNumber,
    required List<int> selectedItemIds,
    String? district,
    List<int>? insuranceCompanyIds,
  }) async {
    final uri = Uri.parse('$baseUrl/api/prescriptions/simulate');

    final body = <String, dynamic>{
      "prescriptionNumber": prescriptionNumber.trim(),
      "selectedItemIds": selectedItemIds,
      "district": district,
      "insuranceCompanyIds": insuranceCompanyIds,
    };

    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(body),
    );

    if (res.statusCode == 401) {
      await TokenStore.clear();
      throw Exception("Oturum suresi doldu. Lutfen tekrar giris yapin.");
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return PrescriptionPriceResultDto.fromJson(data);
    }

    throw Exception(_extractErrorMessage(res));
  }

  Future<CartResponse> addPrescriptionToCart({
    required String prescriptionNumber,
    required int pharmacyId,
    required List<int> selectedItemIds,
  }) async {
    final uri = Uri.parse('$baseUrl/api/prescriptions/add-to-cart');

    final body = <String, dynamic>{
      "prescriptionNumber": prescriptionNumber.trim(),
      "pharmacyId": pharmacyId,
      "selectedItemIds": selectedItemIds,
    };

    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(body),
    );

    if (res.statusCode == 401) {
      await TokenStore.clear();
      throw Exception("Oturum suresi doldu. Lutfen tekrar giris yapin.");
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return CartResponse.fromJson(data);
    }

    throw Exception(_extractErrorMessage(res));
  }
}

