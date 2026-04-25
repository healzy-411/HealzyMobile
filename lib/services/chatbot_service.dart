import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_store.dart';

class ChatMessage {
  final String role;
  final String content;
  ChatMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {"role": role, "content": content};

  factory ChatMessage.user(String text) => ChatMessage(role: "user", content: text);
  factory ChatMessage.assistant(String text) => ChatMessage(role: "assistant", content: text);
}

class ChatbotService {
  final String baseUrl;
  ChatbotService({required this.baseUrl});

  Future<String> ask({
    required String message,
    required List<ChatMessage> history,
  }) async {
    final url = Uri.parse('$baseUrl/api/chatbot/ask');
    final token = TokenStore.get();

    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        "message": message,
        "history": history.map((m) => m.toJson()).toList(),
      }),
    );

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body["reply"]?.toString() ?? "";
    }

    throw Exception(body["message"] ?? "Asistan yanıt vermedi (${res.statusCode})");
  }
}
