import 'dart:convert';
import 'package:http/http.dart' as http;

import '../Models/medicine_reminder_model.dart';
import 'session_guard.dart';
import 'token_store.dart';

class MedicineReminderApiService {
  final String baseUrl; // örn: https://api.apphealzy.com

  MedicineReminderApiService({required this.baseUrl});

  Map<String, String> _authHeaders() {
    final token = TokenStore.get();
    if (token == null || token.isEmpty) {
      throw Exception("Token yok. Lütfen tekrar giriş yap.");
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  String _extractMessage(http.Response res, String fallback) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {}
    return fallback;
  }

  bool _ok(int code) => code >= 200 && code < 300;

  Future<void> _check401(http.Response res) => SessionGuard.handle401(res);

  /// Tüm reminder'lar (kullanıcının tüm planları)
  Future<List<MedicineReminderDto>> getMyReminders() async {
    final uri = Uri.parse('$baseUrl/api/medicine-reminders/me');
    final res = await http.get(uri, headers: _authHeaders());

    await _check401(res);

    if (_ok(res.statusCode)) {
      return MedicineReminderDto.listFromJson(res.body);
    }

    throw Exception(
      _extractMessage(res, 'İlaç planları yüklenemedi (${res.statusCode})'),
    );
  }

  Future<List<MedicineReminderDto>> getAllReminders() async {
    final uri = Uri.parse('$baseUrl/api/medicine-reminders/all');
    final res = await http.get(uri, headers: _authHeaders());

    await _check401(res);

    if (_ok(res.statusCode)) {
      return MedicineReminderDto.listFromJson(res.body);
    }

    throw Exception(
      _extractMessage(res, 'Ilac planlari yuklenemedi (${res.statusCode})'),
    );
  }

  /// ✅ Seçilen gün için reminder'lar (backend filtreli döndürür)
  /// dateUtc: UTC gönderiyoruz (controller zaten dateUtc bekliyor)
  Future<List<MedicineReminderDto>> getMyRemindersForDay(DateTime dateUtc) async {
    final isoUtc = dateUtc.toUtc().toIso8601String();

    final uri = Uri.parse('$baseUrl/api/medicine-reminders/day')
        .replace(queryParameters: {'dateUtc': isoUtc});

    final res = await http.get(uri, headers: _authHeaders());

    await _check401(res);

    if (_ok(res.statusCode)) {
      return MedicineReminderDto.listFromJson(res.body);
    }

    throw Exception(
      _extractMessage(
        res,
        'Günlük ilaç planları yüklenemedi (${res.statusCode})',
      ),
    );
  }

  Future<MedicineReminderDto> createReminder({
    required String name,
    required int frequencyType,
    required int xValue,
    required int timesPerDay,
    required int durationDays,
    required String firstTimeOfDay,
    required int intakeType,
    List<String>? mealTimes,
  }) async {
    final uri = Uri.parse('$baseUrl/api/medicine-reminders');
    final body = jsonEncode({
      'name': name,
      'frequencyType': frequencyType,
      'xValue': xValue,
      'timesPerDay': timesPerDay,
      'durationDays': durationDays,
      'firstTimeOfDay': firstTimeOfDay,
      'intakeType': intakeType,
      if (mealTimes != null && mealTimes.isNotEmpty) 'mealTimes': mealTimes,
    });

    final res = await http.post(uri, headers: _authHeaders(), body: body);

    await _check401(res);

    if (_ok(res.statusCode)) {
      return MedicineReminderDto.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }

    throw Exception(
      _extractMessage(res, 'İlaç planı oluşturulamadı (${res.statusCode})'),
    );
  }

  Future<MedicineReminderDto> updateReminder({
    required int id,
    required String name,
    required int frequencyType,
    required int xValue,
    required int timesPerDay,
    required int durationDays,
    required String firstTimeOfDay,
    required int intakeType,
    List<String>? mealTimes,
  }) async {
    final uri = Uri.parse('$baseUrl/api/medicine-reminders/$id');
    final body = jsonEncode({
      'name': name,
      'frequencyType': frequencyType,
      'xValue': xValue,
      'timesPerDay': timesPerDay,
      'durationDays': durationDays,
      'firstTimeOfDay': firstTimeOfDay,
      'intakeType': intakeType,
      if (mealTimes != null && mealTimes.isNotEmpty) 'mealTimes': mealTimes,
    });

    final res = await http.put(uri, headers: _authHeaders(), body: body);

    await _check401(res);

    if (_ok(res.statusCode)) {
      return MedicineReminderDto.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    }

    throw Exception(
      _extractMessage(res, 'İlaç planı güncellenemedi (${res.statusCode})'),
    );
  }

  Future<void> deleteReminder(int id) async {
    final uri = Uri.parse('$baseUrl/api/medicine-reminders/$id');
    final res = await http.delete(uri, headers: _authHeaders());

    await _check401(res);

    if (_ok(res.statusCode)) return;

    throw Exception(
      _extractMessage(res, 'İlaç planı silinemedi (${res.statusCode})'),
    );
  }

  Future<void> hardDeleteReminder(int id) async {
    final uri = Uri.parse('$baseUrl/api/medicine-reminders/$id/permanent');
    final res = await http.delete(uri, headers: _authHeaders());

    await _check401(res);

    if (_ok(res.statusCode)) return;

    throw Exception(
      _extractMessage(res, 'Kalici silme basarisiz (${res.statusCode})'),
    );
  }
}