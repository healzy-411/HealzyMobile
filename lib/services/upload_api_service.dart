import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'session_guard.dart';
import 'token_store.dart';

class UploadApiService {
  final String baseUrl;

  UploadApiService({required this.baseUrl});

  Future<String> uploadImage(File imageFile) async {
    final token = TokenStore.get();
    if (token == null || token.isEmpty) {
      throw Exception("Oturum bulunamadi. Lutfen tekrar giris yapin.");
    }

    final uri = Uri.parse('$baseUrl/api/uploads/image');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    await SessionGuard.handle401(res);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['imageUrl'] as String;
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception(body['message'] ?? "Gorsel yuklenemedi (${res.statusCode})");
  }
}
