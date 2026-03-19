import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/neighborhood_model.dart';

class NeighborhoodApiService {
  final String baseUrl; // ör: http://localhost:5009

  NeighborhoodApiService({required this.baseUrl});

  Future<List<Neighborhood>> getByDistrictId(int districtId) async {
    final url = Uri.parse('$baseUrl/api/neighborhoods?districtId=$districtId');
    final res = await http.get(url, headers: {'Accept': 'application/json'});

    if (res.statusCode != 200) {
      throw Exception('Neighborhoods load failed: ${res.statusCode}');
    }

    final List<dynamic> jsonList = jsonDecode(res.body);
    return jsonList.map((e) => Neighborhood.fromJson(e)).toList();
  }
}