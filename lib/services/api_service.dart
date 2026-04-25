import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../Models/pharmacy_model.dart';
import '../Models/district_model.dart';
import '../Models/insurance_model.dart';
import '../Models/otcmedicine_model.dart';
import '../Models/duty_pharmacy_model.dart';
import '../Models/medicine_search_model.dart';
import 'session_guard.dart';
import 'package:healzy_app/config/api_config.dart';

class PharmacyCategoryItem {
  final String name;
  final String? imageUrl;
  PharmacyCategoryItem({required this.name, this.imageUrl});
}

class ApiService {
  // =========================================================
  // 🌍 BASE URL
  // =========================================================

  String get baseUrl {
    if (kIsWeb) {
      return '${ApiConfig.baseUrl}/api';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return '${ApiConfig.baseUrl}/api';
    }

    return '${ApiConfig.baseUrl}/api';
  }

  // =========================================================
  // 💊 PHARMACIES
  // =========================================================

  Future<List<Pharmacy>> getPharmacies() async {
    final url = Uri.parse('$baseUrl/pharmacies');

    final response = await http.get(
      url,
      headers: {'Accept': 'application/json'},
    );

    await SessionGuard.handle401(response);

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((e) => Pharmacy.fromJson(e)).toList();
    }

    throw Exception('Pharmacies load failed');
  }

  Future<List<Pharmacy>> filterPharmacies({
  String? district,
  List<int>? insuranceCompanyIds,
  List<int>? medicineIds,
}) async {
  final Map<String, dynamic> body = {};

  if (district != null) {
    body["district"] = district;
  }

  if (insuranceCompanyIds != null && insuranceCompanyIds.isNotEmpty) {
    body["insuranceCompanyIds"] = insuranceCompanyIds;
  }

  if (medicineIds != null && medicineIds.isNotEmpty) {
    body["medicineIds"] = medicineIds;
  }

  //debugPrint("📤 FILTER BODY: ${jsonEncode(body)}");

final response = await http.post(
  Uri.parse("$baseUrl/pharmacies/filter"),
  headers: {
    "Content-Type": "application/json",
    "Accept": "application/json",
  },
  body: jsonEncode(body),
);

//debugPrint("📥 STATUS: ${response.statusCode}");
//debugPrint("📥 RESPONSE: ${response.body}");

  await SessionGuard.handle401(response);

  if (response.statusCode == 200) {
    final List data = jsonDecode(response.body);
    return data.map((e) => Pharmacy.fromJson(e)).toList();
  } else {
    throw Exception("Filtreleme başarısız");
  }
}

  // =========================================================
  // 📍 DISTRICTS
  // =========================================================

  Future<List<District>> getDistricts() async {
    final url = Uri.parse('$baseUrl/districts');

    final response = await http.get(url);

    await SessionGuard.handle401(response);

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((e) => District.fromJson(e)).toList();
    }

    return [];
  }

  // =========================================================
  // 🏦 INSURANCES
  // =========================================================

  Future<List<Insurance>> getInsurances() async {
    final url = Uri.parse('$baseUrl/insurances');

    final response = await http.get(url);

    await SessionGuard.handle401(response);

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((e) => Insurance.fromJson(e)).toList();
    }

    throw Exception('Insurances load failed');
  }

  // =========================================================
  // 🗂️ PHARMACY → CATEGORIES  ✅
  // =========================================================

  /// GET /api/medicines/pharmacy/{pharmacyId}/categories
  Future<List<PharmacyCategoryItem>> getPharmacyCategories(int pharmacyId) async {
    final url = Uri.parse(
      '$baseUrl/medicines/pharmacy/$pharmacyId/categories',
    );

    final response = await http.get(
      url,
      headers: {'Accept': 'application/json'},
    );

    await SessionGuard.handle401(response);

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((e) {
        if (e is String) return PharmacyCategoryItem(name: e, imageUrl: null);
        final m = e as Map<String, dynamic>;
        return PharmacyCategoryItem(
          name: (m['name'] ?? '').toString(),
          imageUrl: m['imageUrl'] as String?,
        );
      }).toList();
    }

    throw Exception(
      'Categories load failed. StatusCode: ${response.statusCode}',
    );
  }

  // =========================================================
  // 💊 PHARMACY + CATEGORY → MEDICINES  ✅
  // =========================================================

  /// GET /api/medicines/pharmacy/{pharmacyId}?category=...
  Future<List<OtcMedicine>> getMedicinesByCategory(
  int pharmacyId,
  String categoryName,
) async {

  final url = Uri.parse(
    '$baseUrl/medicines/pharmacy/$pharmacyId/by-category'
    '?category=${Uri.encodeComponent(categoryName)}',
  );

  debugPrint("➡️ GET $url");

  final response = await http.get(
    url,
    headers: {'Accept': 'application/json'},
  );

  await SessionGuard.handle401(response);

  if (response.statusCode == 200) {
    final List<dynamic> jsonList = jsonDecode(response.body);
    return jsonList.map((e) => OtcMedicine.fromJson(e)).toList();
  }

  throw Exception(
    'Medicines load failed. StatusCode: ${response.statusCode}',
  );
}

Future<List<DutyPharmacyModel>> getDutyPharmacies() async {
  final url = Uri.parse('$baseUrl/duty-pharmacies'); 
  // ⚠️ endpoint adın swagger’da neyse aynen onu yaz:
  // örn: /api/DutyPharmacies ise => '$baseUrl/DutyPharmacies'

  final response = await http.get(
    url,
    headers: {'Accept': 'application/json'},
  );

  await SessionGuard.handle401(response);

  if (response.statusCode == 200) {
    final List<dynamic> jsonList = jsonDecode(response.body);
    return jsonList.map((e) => DutyPharmacyModel.fromJson(e)).toList();
  }

  throw Exception('Duty pharmacies load failed. StatusCode: ${response.statusCode}');
}

Future<List<OtcMedicine>> getAllMedicines() async {
  final url = Uri.parse('$baseUrl/medicines/all');

  debugPrint("➡️ GET $url");

  final response = await http.get(
    url,
    headers: {'Accept': 'application/json'},
  );

  //debugPrint("⬅️ STATUS: ${response.statusCode}");
  //debugPrint("⬅️ BODY: ${response.body}");

  await SessionGuard.handle401(response);

  if (response.statusCode == 200) {
    final List<dynamic> jsonList = jsonDecode(response.body);
    return jsonList.map((e) => OtcMedicine.fromJson(e)).toList();
  }

  throw Exception("Medicines load failed: ${response.statusCode}");
}

// =========================================================
// 🔍 MEDICINE SEARCH (OTC)
// =========================================================

Future<List<MedicineSearchResult>> searchOtcMedicines(String query) async {
  final url = Uri.parse(
    '$baseUrl/medicines/search?query=${Uri.encodeComponent(query)}',
  );

  final response = await http.get(
    url,
    headers: {'Accept': 'application/json'},
  );

  await SessionGuard.handle401(response);

  if (response.statusCode == 200) {
    final List<dynamic> jsonList = jsonDecode(response.body);
    return jsonList.map((e) => MedicineSearchResult.fromJson(e)).toList();
  }

  throw Exception("Ilac arama basarisiz: ${response.statusCode}");
}

// =========================================================
// 🔍 MEDICINE COMPARE (MULTIPLE)
// =========================================================

Future<List<PharmacyCompareResult>> compareMedicines(List<int> medicineIds) async {
  final url = Uri.parse('$baseUrl/medicines/compare');

  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: jsonEncode(medicineIds),
  );

  await SessionGuard.handle401(response);

  if (response.statusCode == 200) {
    final List<dynamic> jsonList = jsonDecode(response.body);
    return jsonList.map((e) => PharmacyCompareResult.fromJson(e)).toList();
  }

  throw Exception("Karsilastirma basarisiz: ${response.statusCode}");
}

}
