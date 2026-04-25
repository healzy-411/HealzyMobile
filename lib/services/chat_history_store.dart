import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'chatbot_service.dart';

class ChatHistoryStore {
  static const String _messagesKey = 'chatbot_messages';
  static const String _timestampKey = 'chatbot_last_activity';

  // Eski sohbeti ne kadar sure tutalim (1 saat)
  static const Duration ttl = Duration(hours: 1);

  static Future<List<ChatMessage>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final tsMillis = prefs.getInt(_timestampKey);
    if (tsMillis == null) return [];

    final lastActivity = DateTime.fromMillisecondsSinceEpoch(tsMillis);
    if (DateTime.now().difference(lastActivity) > ttl) {
      await clear();
      return [];
    }

    final raw = prefs.getString(_messagesKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => ChatMessage(
                role: (e as Map<String, dynamic>)["role"] as String,
                content: e["content"] as String,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_messagesKey, jsonEncode(messages.map((m) => m.toJson()).toList()));
    await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_messagesKey);
    await prefs.remove(_timestampKey);
  }
}
