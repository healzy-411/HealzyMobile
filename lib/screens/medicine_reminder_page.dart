import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../Models/medicine_reminder_model.dart';
import '../services/medicine_reminder_api_service.dart';
import '../services/local_notification_service.dart';
import 'all_reminders_page.dart';

class MedicineReminderPage extends StatefulWidget {
  final String baseUrl;

  const MedicineReminderPage({
    super.key,
    required this.baseUrl,
  });

  @override
  State<MedicineReminderPage> createState() => _MedicineReminderPageState();
}

class _MedicineReminderPageState extends State<MedicineReminderPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final Color healzyTurquoise = const Color(0xFF00A79D);
  final Color healzyDarkGreen = const Color(0xFF004D40);

  late final MedicineReminderApiService _api =
      MedicineReminderApiService(baseUrl: widget.baseUrl);

  // ✅ Takvim marker + scheduling için tüm reminder'lar
  List<MedicineReminderDto> _allReminders = [];

  // ✅ Liste için seçilen gün reminder'ları (UI ListView bunu kullanacak)
  List<MedicineReminderDto> _reminders = [];

  bool _loading = false;
  String? _error;

  // UI renkleri (id -> color)
  final Map<int, Color> _colorsById = {};

  // ===== Notification scheduling ayarları (sunum güvenli) =====
  static const int _scheduleWindowDays = 30; // ileriye dönük kaç gün schedule
  static const int _maxSchedulesTotal = 120; // maksimum kaç bildirim planlansın

  Color _colorFor(MedicineReminderDto r, int index) {
    return _colorsById[r.id] ??=
        Colors.primaries[(index * 3) % Colors.primaries.length];
  }

  double _dayIntervalFor(MedicineReminderDto r) {
    if (r.frequencyType == 0) return 1.0; // Her gün
    if (r.frequencyType == 1) return r.xValue.toDouble(); // X günde bir
    if (r.frequencyType == 2 && r.xValue > 0) {
      return 7 / r.xValue; // Haftada X gün ~ 7/X
    }
    return 1.0;
  }

  // ==== Takvim event loader (marker için ALL listesi) ====
  List<dynamic> _getEventsForDay(DateTime day) {
    final events = <dynamic>[];
    final checkDay = DateTime(day.year, day.month, day.day);

    for (var r in _allReminders) {
      final startDate =
          DateTime(r.startDateUtc.year, r.startDateUtc.month, r.startDateUtc.day);

      final dayInterval = _dayIntervalFor(r);
      final duration = r.durationDays;

      final differenceInDays = checkDay.difference(startDate).inDays;

      final isMedicineDay = differenceInDays >= 0 &&
          differenceInDays < duration &&
          ((differenceInDays / dayInterval) % 1.0).abs() < 0.01;

      if (isMedicineDay) events.add(r);
    }
    return events;
  }

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR', null);
    _selectedDay = _focusedDay;

    // İlk açılış: tüm verileri çek + selected day'i de doldur
    _loadAllAndSelectedDay();
  }

  // ✅ Sunum güvenli: önce tüm reminder'lar, sonra seçilen gün reminder'ları
  Future<void> _loadAllAndSelectedDay() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final all = await _api.getMyReminders();
      if (!mounted) return;

      setState(() {
        _allReminders = all;
      });

      // seçili günün listesi
      final day = (_selectedDay ?? DateTime.now()).toUtc();
      final dayList = await _api.getMyRemindersForDay(day);
      if (!mounted) return;

      setState(() {
        _reminders = dayList;
      });

      // Sunum güvenli: sync + schedule
      await _rescheduleAllNotifications();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ✅ Sadece seçilen gün listesini backend'den çek
  Future<void> _loadSelectedDayOnly(DateTime selectedDay) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dayList = await _api.getMyRemindersForDay(selectedDay.toUtc());
      if (!mounted) return;
      setState(() {
        _reminders = dayList;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _getFrequencyText(MedicineReminderDto item) {
    final type = item.frequencyType;
    final x = item.xValue;
    if (type == 0) return "Her gün";
    if (type == 1) return "$x günde bir";
    return "Haftada $x gün";
  }

  String _getIntakeTypeText(int intakeType) {
    return intakeType == 1 ? 'Tok' : 'Aç';
  }

  // ============================================================
  // =================== LOCAL NOTIFICATION =====================
  // ============================================================

  DateTime _combineDateAndTime(DateTime date, String hhmm) {
    final parts = hhmm.split(':');
    final hh = int.tryParse(parts[0]) ?? 0;
    final mm = int.tryParse(parts[1]) ?? 0;
    return DateTime(date.year, date.month, date.day, hh, mm);
  }

  int _notifId(int reminderId, DateTime when) {
    final y = when.year;
    final m = when.month.toString().padLeft(2, '0');
    final d = when.day.toString().padLeft(2, '0');
    final hh = when.hour.toString().padLeft(2, '0');
    final mm = when.minute.toString().padLeft(2, '0');
    final key = int.parse('$y$m$d$hh$mm'); // 202603021530
    return reminderId * 100000 + (key % 100000);
  }

  int _mealNotifId(int reminderId, DateTime when) {
    return _notifId(reminderId, when) + 50000;
  }

  int _preNotifId(int reminderId, DateTime when) {
    return _notifId(reminderId, when) + 70000;
  }

  bool _isMedicineDayFor(DateTime day, MedicineReminderDto r) {
    final checkDay = DateTime(day.year, day.month, day.day);
    final startDate =
        DateTime(r.startDateUtc.year, r.startDateUtc.month, r.startDateUtc.day);

    final interval = _dayIntervalFor(r);
    final diff = checkDay.difference(startDate).inDays;

    if (diff < 0) return false;
    if (diff >= r.durationDays) return false;

    return ((diff / interval) % 1.0).abs() < 0.01;
  }

  List<DateTime> _buildUpcomingSchedules(MedicineReminderDto r) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final windowEnd = today.add(const Duration(days: _scheduleWindowDays));

    final start =
        DateTime(r.startDateUtc.year, r.startDateUtc.month, r.startDateUtc.day);
    final reminderEnd = start.add(Duration(days: r.durationDays - 1));

    final end = reminderEnd.isBefore(windowEnd) ? reminderEnd : windowEnd;

    final out = <DateTime>[];

    final times = r.timesOfDay;
    if (times.isEmpty) return out;

    DateTime cursor = today;
    while (!cursor.isAfter(end)) {
      if (_isMedicineDayFor(cursor, r)) {
        for (final t in times) {
          final when = _combineDateAndTime(cursor, t);
          if (when.isAfter(now)) out.add(when);
        }
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    out.sort();
    return out;
  }

  /// Her ilaç saati için en yakın önceki yemek saatini bulur
  DateTime? _findClosestMealTimeBefore(DateTime medicineTime, List<String> mealTimes, DateTime day) {
    DateTime? closest;
    for (final mt in mealTimes) {
      final mealDt = _combineDateAndTime(day, mt);
      if (mealDt.isBefore(medicineTime)) {
        if (closest == null || mealDt.isAfter(closest)) {
          closest = mealDt;
        }
      }
    }
    return closest;
  }

  Future<void> _rescheduleAllNotifications() async {
    try {
      await LocalNotificationService.I.cancelAll();
    } catch (_) {}

    int scheduledCount = 0;

    final list = List<MedicineReminderDto>.from(_allReminders)
      ..sort((a, b) => a.id.compareTo(b.id));

    final now = DateTime.now();

    for (final r in list) {
      if (scheduledCount >= _maxSchedulesTotal) break;

      final times = _buildUpcomingSchedules(r);
      for (final when in times) {
        if (scheduledCount >= _maxSchedulesTotal) break;

        final day = DateTime(when.year, when.month, when.day);

        if (r.intakeType == 0) {
          // Aç karnına
          final id = _notifId(r.id, when);
          try {
            await LocalNotificationService.I.scheduleOneTime(
              id: id,
              title: 'İlaç Zamanı',
              body: '${r.name} ilacınızı aç karnına içmeyi unutmayın.',
              whenLocal: when,
            );
            scheduledCount++;
          } catch (_) {}
        } else if (r.intakeType == 1 && r.mealTimes.isNotEmpty) {
          // Tok karnına + yemek saatleri var → 3 aşamalı bildirim
          final mealTime = _findClosestMealTimeBefore(when, r.mealTimes, day);

          // 3. İlaç saatinde bildirim (her zaman)
          final medId = _notifId(r.id, when);
          try {
            await LocalNotificationService.I.scheduleOneTime(
              id: medId,
              title: 'İlaç Zamanı',
              body: '${r.name} ilacınızı içmeyi unutmayın.',
              whenLocal: when,
            );
            scheduledCount++;
          } catch (_) {}

          if (mealTime != null) {
            // 1. Yemek saatinde bildirim
            if (mealTime.isAfter(now) && scheduledCount < _maxSchedulesTotal) {
              final mealId = _mealNotifId(r.id, when);
              try {
                await LocalNotificationService.I.scheduleOneTime(
                  id: mealId,
                  title: 'Yemek Zamanı',
                  body: 'Yemeğinizi yemeyi unutmayın.',
                  whenLocal: mealTime,
                );
                scheduledCount++;
              } catch (_) {}
            }

            // 2. İlaç saatinden 30dk önce bildirim
            final preTime = when.subtract(const Duration(minutes: 30));
            if (preTime.isAfter(now) && scheduledCount < _maxSchedulesTotal) {
              final preId = _preNotifId(r.id, when);
              try {
                await LocalNotificationService.I.scheduleOneTime(
                  id: preId,
                  title: 'Yemek Hatırlatma',
                  body: 'İlacınız var, yemeğinizi yemeyi unutmayın.',
                  whenLocal: preTime,
                );
                scheduledCount++;
              } catch (_) {}
            }
          }
        } else {
          // Tok karnına ama yemek saati yok → mevcut davranış
          final id = _notifId(r.id, when);
          try {
            await LocalNotificationService.I.scheduleOneTime(
              id: id,
              title: 'İlaç Zamanı',
              body: '${r.name} ilacınızı içmeyi unutmayın.',
              whenLocal: when,
            );
            scheduledCount++;
          } catch (_) {}
        }
      }
    }
  }

  // ============================================================
  // =================== DELETE (ICON + SWIPE) ===================
  // ============================================================

  Future<void> _deleteReminder(MedicineReminderDto item) async {
    // optimistic UI
    final oldAll = List<MedicineReminderDto>.from(_allReminders);
    final oldDay = List<MedicineReminderDto>.from(_reminders);

    setState(() {
      _allReminders.removeWhere((r) => r.id == item.id);
      _reminders.removeWhere((r) => r.id == item.id);
    });

    try {
      await _api.deleteReminder(item.id);

      // Silme sonrası bildirimleri yeniden kur
      await _rescheduleAllNotifications();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} silindi')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _allReminders = oldAll;
        _reminders = oldDay;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Silme başarısız: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<bool> _confirmDelete(MedicineReminderDto item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Silinsin mi?'),
        content: Text('${item.name} hatırlatıcısı silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // ============================================================
  // =============== WHEEL TIME PICKER (alarm tarzı) ============
  // ============================================================

  Future<String?> _showWheelTimePicker(BuildContext ctx, {int initialHour = 12, int initialMinute = 0}) async {
    int selectedHour = initialHour;
    int selectedMinute = initialMinute;

    final confirmed = await showModalBottomSheet<bool>(
      context: ctx,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: 300,
            child: Column(
              children: [
                // Başlık + butonlar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('Vazgeç', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                      ),
                      Text(
                        'Saat Seçin',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: healzyDarkGreen,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('Tamam', style: TextStyle(color: healzyTurquoise, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Saat : Dakika wheel picker
                Expanded(
                  child: Row(
                    children: [
                      // Saat
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(initialItem: initialHour),
                          itemExtent: 40,
                          onSelectedItemChanged: (i) => selectedHour = i,
                          children: List.generate(24, (i) {
                            return Center(
                              child: Text(
                                i.toString().padLeft(2, '0'),
                                style: const TextStyle(fontSize: 22),
                              ),
                            );
                          }),
                        ),
                      ),
                      const Text(':', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                      // Dakika
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(initialItem: initialMinute),
                          itemExtent: 40,
                          onSelectedItemChanged: (i) => selectedMinute = i,
                          children: List.generate(60, (i) {
                            return Center(
                              child: Text(
                                i.toString().padLeft(2, '0'),
                                style: const TextStyle(fontSize: 22),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      final hh = selectedHour.toString().padLeft(2, '0');
      final mm = selectedMinute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
    return null;
  }

  // ============================================================
  // =================== ADD/EDIT DIALOG =========================
  // ============================================================

  void _showAddReminderDialog({MedicineReminderDto? editing}) {
    final nameController = TextEditingController(text: editing?.name ?? '');
    final timeController = TextEditingController(
      text: (editing?.timesOfDay.isNotEmpty ?? false)
          ? editing!.timesOfDay.first
          : '10:30',
    );
    final durationController =
        TextEditingController(text: editing?.durationDays.toString() ?? '');
    final customXController =
        TextEditingController(text: (editing?.xValue ?? 2).toString());

    int frequency = editing?.timesPerDay ?? 1;
    int frequencyType = editing?.frequencyType ?? 0;
    int intakeType = editing?.intakeType ?? 0; // 0=Aç, 1=Tok
    List<String> mealTimes = List<String>.from(editing?.mealTimes ?? []);
    String? popupError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'İlaç Planla',
                style: TextStyle(
                  color: healzyDarkGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: healzyTurquoise),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (popupError != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            popupError!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'İlaç Adı *',
                    prefixIcon: Icon(Icons.medication, color: healzyTurquoise),
                  ),
                ),
                const SizedBox(height: 15),

                // ── Aç / Tok Seçimi ──
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Kullanım Şekli *',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDialogState(() {
                          intakeType = 0;
                          mealTimes.clear();
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: intakeType == 0
                                ? healzyTurquoise
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Aç Karnına',
                            style: TextStyle(
                              color: intakeType == 0 ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDialogState(() => intakeType = 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: intakeType == 1
                                ? healzyTurquoise
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Tok Karnına',
                            style: TextStyle(
                              color: intakeType == 1 ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Yemek Saatleri (sadece Tok seçiliyse) ──
                if (intakeType == 1) ...[
                  const SizedBox(height: 15),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Yemek Saatleri (isteğe bağlı)',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...mealTimes.asMap().entries.map((entry) {
                        return Chip(
                          label: Text(entry.value),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () {
                            setDialogState(() {
                              mealTimes.removeAt(entry.key);
                            });
                          },
                          backgroundColor: healzyTurquoise.withOpacity(0.1),
                        );
                      }),
                      if (mealTimes.length < 5)
                        ActionChip(
                          avatar: Icon(Icons.add, size: 18, color: healzyTurquoise),
                          label: const Text('Yemek Saati Ekle'),
                          onPressed: () async {
                            final result = await _showWheelTimePicker(context);
                            if (result != null) {
                              setDialogState(() {
                                mealTimes.add(result);
                              });
                            }
                          },
                        ),
                    ],
                  ),
                  if (mealTimes.length >= 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'En fazla 5 yemek saati ekleyebilirsiniz.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ),
                ],

                const SizedBox(height: 15),
                DropdownButtonFormField<int>(
                  value: frequencyType,
                  decoration: InputDecoration(
                    labelText: 'Kullanım Sıklığı *',
                    prefixIcon: Icon(Icons.loop, color: healzyTurquoise),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Her Gün')),
                    DropdownMenuItem(value: 1, child: Text('X Günde Bir')),
                    DropdownMenuItem(value: 2, child: Text('Haftada X Gün')),
                  ],
                  onChanged: (val) => setDialogState(() => frequencyType = val!),
                ),
                if (frequencyType != 0) ...[
                  const SizedBox(height: 15),
                  TextField(
                    controller: customXController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: frequencyType == 1
                          ? 'Kaç günde bir? (X)'
                          : 'Haftada kaç gün? (X)',
                      prefixIcon: Icon(Icons.edit_calendar, color: healzyTurquoise),
                    ),
                  ),
                ],
                const SizedBox(height: 15),
                TextField(
                  controller: durationController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Toplam Kaç Gün Kullanılacak? *',
                    prefixIcon: Icon(Icons.calendar_month, color: healzyTurquoise),
                    hintText: "Örn: 10",
                  ),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<int>(
                  value: frequency,
                  decoration: InputDecoration(
                    labelText: 'Günde Kaç Defa? *',
                    prefixIcon: Icon(Icons.repeat, color: healzyTurquoise),
                  ),
                  items: [1, 2, 3, 4]
                      .map((f) => DropdownMenuItem(value: f, child: Text('$f Defa')))
                      .toList(),
                  onChanged: (val) => setDialogState(() => frequency = val!),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: timeController,
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(
                    labelText: 'İlk Doz Saati *',
                    prefixIcon: Icon(Icons.access_time, color: healzyTurquoise),
                    hintText: "SS:DD",
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: healzyTurquoise,
                minimumSize: const Size(double.infinity, 45),
              ),
              onPressed: () async {
                String? errorMessage;

                final name = nameController.text.trim();
                final durationText = durationController.text;
                final firstTime = timeController.text.trim();
                final xVal = int.tryParse(customXController.text) ?? 1;

                if (name.isEmpty) {
                  errorMessage = "İlaç adını girmelisiniz.";
                } else if (editing == null &&
                    _allReminders.any((r) => r.name.toLowerCase() == name.toLowerCase())) {
                  errorMessage = "Bu ilaç zaten listende kayıtlı!";
                } else if (durationText.isEmpty || int.tryParse(durationText) == null) {
                  errorMessage = "Geçerli bir kullanım süresi giriniz.";
                } else if (frequencyType != 0 && xVal <= 0) {
                  errorMessage = "X değeri 0'dan büyük olmalıdır.";
                } else if (firstTime.isEmpty || !firstTime.contains(':')) {
                  errorMessage = "Geçerli bir saat girmelisiniz.";
                }

                if (errorMessage != null) {
                  setDialogState(() => popupError = errorMessage);
                  return;
                }

                final durationDays = int.parse(durationText);

                try {
                  MedicineReminderDto saved;
                  if (editing == null) {
                    saved = await _api.createReminder(
                      name: name,
                      frequencyType: frequencyType,
                      xValue: xVal,
                      timesPerDay: frequency,
                      durationDays: durationDays,
                      firstTimeOfDay: firstTime,
                      intakeType: intakeType,
                      mealTimes: intakeType == 1 && mealTimes.isNotEmpty
                          ? mealTimes
                          : null,
                    );
                  } else {
                    saved = await _api.updateReminder(
                      id: editing.id,
                      name: name,
                      frequencyType: frequencyType,
                      xValue: xVal,
                      timesPerDay: frequency,
                      durationDays: durationDays,
                      firstTimeOfDay: firstTime,
                      intakeType: intakeType,
                      mealTimes: intakeType == 1 && mealTimes.isNotEmpty
                          ? mealTimes
                          : null,
                    );
                  }

                  if (!mounted) return;

                  // ✅ all list güncellenir
                  setState(() {
                    final idxAll = _allReminders.indexWhere((r) => r.id == saved.id);
                    if (idxAll >= 0) {
                      _allReminders[idxAll] = saved;
                    } else {
                      _allReminders.add(saved);
                    }
                  });

                  // ✅ seçili gün listesi de backend'den tazelenir (garanti)
                  final day = (_selectedDay ?? DateTime.now());
                  await _loadSelectedDayOnly(day);

                  // ✅ notification'ları yeniden kur
                  await _rescheduleAllNotifications();

                  if (!mounted) return;
                  Navigator.pop(context);
                } catch (e) {
                  setDialogState(() {
                    popupError = e.toString().replaceFirst('Exception: ', '');
                  });
                }
              },
              child: const Text(
                'KAYDET',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // =========================== UI ==============================
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final selectedDay = _selectedDay ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Healzy İlaç Hatırlatıcı",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: healzyTurquoise,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: "Yenile",
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllAndSelectedDay,
          ),
          IconButton(
            tooltip: "Tüm Hatırlatıcılar",
            icon: const Icon(Icons.menu),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AllRemindersPage(
                    api: _api,
                    healzyTurquoise: healzyTurquoise,
                    healzyDarkGreen: healzyDarkGreen,
                    onEdit: (item) => _showAddReminderDialog(editing: item),
                    onChanged: () => _loadAllAndSelectedDay(),
                  ),
                ),
              ).then((_) => _loadAllAndSelectedDay());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          TableCalendar(
            locale: 'tr_TR',
            firstDay: DateTime.utc(2025, 1, 1),
            lastDay: DateTime.utc(2027, 12, 31),
            focusedDay: _focusedDay,
            eventLoader: _getEventsForDay,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: healzyTurquoise,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: healzyTurquoise.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isNotEmpty) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: events.take(4).map((event) {
                      final r = event as MedicineReminderDto;
                      final idx = _allReminders.indexWhere((x) => x.id == r.id);
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 0.5),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _colorFor(r, idx < 0 ? 0 : idx),
                        ),
                      );
                    }).toList(),
                  );
                }
                return null;
              },
            ),
            onDaySelected: (day, focusedDay) async {
              setState(() {
                _selectedDay = day;
                _focusedDay = focusedDay;
              });

              // ✅ seçilen gün değişince backend'den o günün reminder'larını çek
              await _loadSelectedDayOnly(day);
            },
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _reminders.length,
              itemBuilder: (context, index) {
                final item = _reminders[index];
                final color = _colorFor(item, index);

                // ===== Swipe-to-delete (temayı bozmadan wrapper) =====
                return Dismissible(
                  key: ValueKey(item.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete, color: Colors.redAccent),
                  ),
                  confirmDismiss: (_) => _confirmDelete(item),
                  onDismissed: (_) async {
                    await _deleteReminder(item);
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.alarm, color: healzyTurquoise),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: healzyDarkGreen,
                                  ),
                                ),
                              ),
                              // Aç/Tok badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: item.intakeType == 0
                                      ? Colors.orange.withOpacity(0.15)
                                      : Colors.green.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _getIntakeTypeText(item.intakeType),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: item.intakeType == 0
                                        ? Colors.orange[800]
                                        : Colors.green[800],
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.edit,
                                    color: healzyTurquoise, size: 22),
                                onPressed: () =>
                                    _showAddReminderDialog(editing: item),
                              ),

                              // ✅ Sağ üst "delete" butonu
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                color: Colors.redAccent,
                                onPressed: () async {
                                  final ok = await _confirmDelete(item);
                                  if (ok) {
                                    await _deleteReminder(item);
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "${_getFrequencyText(item)} - Günde ${item.timesPerDay} kez",
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: item.timesOfDay
                                .map(
                                  (t) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      t,
                                      style: TextStyle(
                                        color: healzyDarkGreen,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          // Yemek saatleri gösterimi
                          if (item.intakeType == 1 && item.mealTimes.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              children: [
                                Icon(Icons.restaurant, size: 14, color: Colors.grey[500]),
                                ...item.mealTimes.map(
                                  (t) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      t,
                                      style: TextStyle(
                                        color: Colors.green[700],
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: healzyTurquoise,
        onPressed: () => _showAddReminderDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
