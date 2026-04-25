import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Models/notification_model.dart';
import 'session_guard.dart';
import 'token_store.dart';

class NotificationApiService {
  final String baseUrl;

  NotificationApiService({required this.baseUrl});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${TokenStore.get()}',
      };

  Future<void> _check401(http.Response res) => SessionGuard.handle401(res);

  Future<List<NotificationModel>> getMyNotifications({int page = 1, int pageSize = 20}) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/notifications/me?page=$page&pageSize=$pageSize'),
      headers: _headers,
    );
    await _check401(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = jsonDecode(res.body) as List;
      return list.map((e) => NotificationModel.fromJson(e)).toList();
    }
    throw Exception("Bildirimler yuklenemedi (${res.statusCode})");
  }

  Future<void> markAsRead(int id) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/notifications/$id/read'),
      headers: _headers,
    );
    await _check401(res);
  }

  Future<void> markAllAsRead() async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/notifications/read-all'),
      headers: _headers,
    );
    await _check401(res);
  }

  Future<int> getUnreadCount() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/notifications/unread-count'),
      headers: _headers,
    );
    await _check401(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['count'] ?? 0;
    }
    return 0;
  }
}
