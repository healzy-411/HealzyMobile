import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Models/review_model.dart';
import 'token_store.dart';

class ReviewApiService {
  final String baseUrl;

  ReviewApiService({required this.baseUrl});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${TokenStore.get()}',
      };

  Future<void> _check401(http.Response res) async {
    if (res.statusCode == 401) {
      await TokenStore.clear();
      throw Exception("Oturum suresi doldu. Lutfen tekrar giris yapin.");
    }
  }

  Future<ReviewDto> createReview({
    required int orderId,
    required int rating,
    String? comment,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/reviews'),
      headers: _headers,
      body: jsonEncode({
        'orderId': orderId,
        'rating': rating,
        'comment': comment,
      }),
    );
    await _check401(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return ReviewDto.fromJson(body);
    }
    throw Exception(body['message'] ?? "Degerlendirme gonderilemedi (${res.statusCode})");
  }

  Future<PharmacyDetailModel> getPharmacyDetail(int pharmacyId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/pharmacies/$pharmacyId/detail'),
      headers: {'Accept': 'application/json'},
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return PharmacyDetailModel.fromJson(jsonDecode(res.body));
    }
    throw Exception("Eczane detay yuklenemedi (${res.statusCode})");
  }

  Future<List<ReviewDto>> getPharmacyReviews(int pharmacyId, {int page = 1, int pageSize = 20}) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/pharmacies/$pharmacyId/reviews?page=$page&pageSize=$pageSize'),
      headers: {'Accept': 'application/json'},
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = jsonDecode(res.body) as List;
      return list.map((e) => ReviewDto.fromJson(e)).toList();
    }
    throw Exception("Yorumlar yuklenemedi (${res.statusCode})");
  }

  Future<bool> hasReviewedOrder(int orderId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/orders/$orderId/has-review'),
      headers: _headers,
    );
    await _check401(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['hasReview'] ?? false;
    }
    return false;
  }
}
