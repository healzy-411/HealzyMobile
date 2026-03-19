import 'dart:convert';

class MedicineReminderDto {
  final int id;
  final String name;
  /// 0: EveryDay, 1: EveryXDays, 2: XDaysPerWeek
  final int frequencyType;
  final int xValue;
  /// Günde kaç defa
  final int timesPerDay;
  /// Toplam kaç gün
  final int durationDays;
  final DateTime startDateUtc;
  /// "HH:mm" formatında saat listesi
  final List<String> timesOfDay;
  final bool isActive;

  MedicineReminderDto({
    required this.id,
    required this.name,
    required this.frequencyType,
    required this.xValue,
    required this.timesPerDay,
    required this.durationDays,
    required this.startDateUtc,
    required this.timesOfDay,
    required this.isActive,
  });

  factory MedicineReminderDto.fromJson(Map<String, dynamic> json) {
    final rawTimes = json['timesOfDay'] ?? json['TimesOfDay'] ?? [];
    final times = (rawTimes is List)
        ? rawTimes.map((e) => e.toString()).toList()
        : <String>[];

    return MedicineReminderDto(
      id: (json['id'] ?? json['Id'] ?? 0) as int,
      name: (json['name'] ?? json['Name'] ?? '').toString(),
      frequencyType:
          (json['frequencyType'] ?? json['FrequencyType'] ?? 0) as int,
      xValue: (json['xValue'] ?? json['XValue'] ?? 1) as int,
      timesPerDay:
          (json['timesPerDay'] ?? json['TimesPerDay'] ?? 1) as int,
      durationDays:
          (json['durationDays'] ?? json['DurationDays'] ?? 1) as int,
      startDateUtc: DateTime.parse(
        (json['startDateUtc'] ?? json['StartDateUtc']).toString(),
      ),
      timesOfDay: times,
      isActive: (json['isActive'] ?? json['IsActive'] ?? true) as bool,
    );
  }

  static List<MedicineReminderDto> listFromJson(String body) {
    final decoded = jsonDecode(body);
    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(MedicineReminderDto.fromJson)
          .toList();
    }
    return [];
  }
}

