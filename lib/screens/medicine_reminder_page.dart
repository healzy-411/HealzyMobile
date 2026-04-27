import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../Models/medicine_reminder_model.dart';
import '../services/medicine_reminder_api_service.dart';
import '../services/local_notification_service.dart';
import 'all_reminders_page.dart';
import 'dart:ui';
import '../widgets/healzy_bottom_nav.dart';

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

  final Color midnightBlue = const Color(0xFF1B4965);
  final Color pearlWhite = const Color(0xFFFFF8E8);
  final Color glassWhite = Colors.white.withOpacity(0.2); // Camsı efekt için şeffaf beyaz  

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  

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

  String _getIntakeTypeText(int intakeType) {
    return intakeType == 1 ? 'Tok' : 'Aç';
  }

  double _dayIntervalFor(MedicineReminderDto r) {
    if (r.frequencyType == 0) return 1.0; // Her gün
    if (r.frequencyType == 1) return r.xValue.toDouble(); // X günde bir
    return 1.0; // Haftada X gün icin ayri hesap
  }

  bool _isWeeklyMedicineDay(int diffDays, int xValue) {
    if (xValue <= 0) return false;
    final dayInWeek = diffDays % 7;
    return dayInWeek < xValue;
  }

  // ==== Takvim event loader (marker için ALL listesi) ====
  List<dynamic> _getEventsForDay(DateTime day) {
    final events = <dynamic>[];
    final checkDay = DateTime(day.year, day.month, day.day);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    // Geçmiş günlerde nokta gösterme
    if (checkDay.isBefore(today)) return events;

    for (var r in _allReminders) {
      // Sadece aktif hatırlatıcıları takvimde göster
      if (!r.isActive) continue;

      final startDate =
          DateTime(r.startDateUtc.year, r.startDateUtc.month, r.startDateUtc.day);

      final duration = r.durationDays;
      final differenceInDays = checkDay.difference(startDate).inDays;

      // Süresi dolmuş hatırlatıcıları da gösterme
      if (differenceInDays >= duration) continue;

      bool isMedicineDay;
      if (r.frequencyType == 2) {
        isMedicineDay = differenceInDays >= 0 &&
            _isWeeklyMedicineDay(differenceInDays, r.xValue);
      } else {
        final dayInterval = _dayIntervalFor(r);
        isMedicineDay = differenceInDays >= 0 &&
            ((differenceInDays / dayInterval) % 1.0).abs() < 0.01;
      }

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

    final diff = checkDay.difference(startDate).inDays;

    if (diff < 0) return false;
    if (diff >= r.durationDays) return false;

    if (r.frequencyType == 2) {
      return _isWeeklyMedicineDay(diff, r.xValue);
    }

    final interval = _dayIntervalFor(r);
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

    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF132B44) : Colors.white;
    final textColor = isDark ? Colors.white : midnightBlue;

    final confirmed = await showModalBottomSheet<bool>(
      context: ctx,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: 300,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('Vazgeç',
                            style: TextStyle(
                                color: textColor.withValues(alpha: 0.6),
                                fontSize: 16)),
                      ),
                      Text(
                        'Saat Seçin',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: textColor,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('Tamam',
                            style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(initialItem: initialHour),
                          itemExtent: 40,
                          onSelectedItemChanged: (i) => selectedHour = i,
                          children: List.generate(24, (i) {
                            return Center(
                              child: Text(
                                i.toString().padLeft(2, '0'),
                                style: TextStyle(fontSize: 22, color: textColor),
                              ),
                            );
                          }),
                        ),
                      ),
                      Text(':',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: textColor)),
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(initialItem: initialMinute),
                          itemExtent: 40,
                          onSelectedItemChanged: (i) => selectedMinute = i,
                          children: List.generate(60, (i) {
                            return Center(
                              child: Text(
                                i.toString().padLeft(2, '0'),
                                style: TextStyle(fontSize: 22, color: textColor),
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
          ? editing!.timesOfDay.first.split(':').take(2).join(':')
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
      builder: (context) => Theme(
    // ✅ BURASI ÖNEMLİ: Dialog içindeki tüm form elemanlarını beyaz/pearlWhite yapar
    data: Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme.apply(
            bodyColor: pearlWhite, 
            displayColor: pearlWhite,
          ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(color: pearlWhite.withOpacity(0.8), fontSize: 18),
        hintStyle: TextStyle(color: pearlWhite.withOpacity(0.5), fontSize: 18),
        prefixIconColor: pearlWhite,
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: pearlWhite.withOpacity(0.3))),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: pearlWhite)),
      ),
    ),
    child: StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: midnightBlue.withOpacity(0.9),//arka renk
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'İlaç Planla',
                style: TextStyle(
                  color: pearlWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: pearlWhite),
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
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: nameController,
                  style: TextStyle(color: pearlWhite, fontSize: 18),
                  decoration: InputDecoration(
                    labelText: 'İlaç Adı ',
                    prefixIcon: Icon(Icons.medication, color: pearlWhite),
                  ),
                ),
                const SizedBox(height: 15),

                // ── Aç / Tok Seçimi ──
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Kullanım Şekli ',
                    style: TextStyle(
                      fontSize: 18,
                      //color: Colors.grey[600],
                      color: pearlWhite
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
                            color: intakeType == 0 ? pearlWhite : pearlWhite.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Aç Karnına',
                            style: TextStyle(
                              color: midnightBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
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
                            color: intakeType == 1 ? pearlWhite : pearlWhite.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Tok Karnına',
                            style: TextStyle(
                              //color: intakeType == 1 ? Colors.white : Colors.black87,
                              color: midnightBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Yemek Saatleri (sadece Tok seçiliyse) ──
                if (intakeType == 1) ...[
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Yemek Saatleri (isteğe bağlı)',
                      style: TextStyle(
                        fontSize: 18,
                        color: pearlWhite,
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
                          backgroundColor: pearlWhite.withOpacity(0.1),
                        );
                      }),
                      if (mealTimes.length < 5)
                        ActionChip(
                          avatar: Icon(Icons.add, size: 20, color: pearlWhite),
                          label: Text('Yemek Saati Ekle', style: TextStyle(color: midnightBlue, fontWeight: FontWeight.bold)),
                          backgroundColor: pearlWhite,
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
                        style: TextStyle(fontSize: 18, color: pearlWhite),
                      ),
                    ),
                ],

                const SizedBox(height: 15),
                DropdownButtonFormField<int>(
                  value: frequencyType,
                  dropdownColor: midnightBlue,
                  style: TextStyle(color: pearlWhite, fontSize: 18),
                  decoration: InputDecoration(
                    labelText: 'Kullanım Sıklığı ',
                    filled: true,
                    fillColor: midnightBlue.withOpacity(0.5), 
                    prefixIcon: Icon(Icons.loop, color: pearlWhite),
                    labelStyle: TextStyle(color: pearlWhite, fontSize: 18),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Her Gün', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 1, child: Text('X Günde Bir', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 2, child: Text('Haftada X Gün', style: TextStyle(color: Colors.white))),
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
                      prefixIcon: Icon(Icons.edit_calendar, color: pearlWhite),
                    ),
                  ),
                ],
                const SizedBox(height: 15),
                TextField(
                  controller: durationController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: frequencyType == 0
                        ? 'Kaç Gün Kullanılacak?'
                        : 'Kaç Doz Kullanılacak?',
                    prefixIcon: Icon(Icons.calendar_month, color: pearlWhite),
                    hintText: "Örn: 10",
                  ),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<int>(
                  value: frequency,
                  dropdownColor: midnightBlue,
                  style: TextStyle(color: pearlWhite, fontSize: 18),
                  decoration: InputDecoration(
                    labelText: 'Günde Kaç Defa?',
                    filled: true,
                    fillColor: midnightBlue.withOpacity(0.5),
                    labelStyle: TextStyle(color: pearlWhite, fontSize: 18),
                    prefixIcon: Icon(Icons.repeat, color: pearlWhite),
                    enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: pearlWhite.withOpacity(0.3)),
                    ),
                    focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: pearlWhite),
                    ),
                  ),
                  items: [1, 2, 3, 4]
                      .map((f) => DropdownMenuItem(value: f, child: Text('$f Defa', style: const TextStyle(color: Colors.white),)))
                      .toList(),
                  onChanged: (val) => setDialogState(() => frequency = val!),
                ),
                const SizedBox(height: 15),
                GestureDetector(
                  onTap: () async {
                    final parts = timeController.text.split(':');
                    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 10;
                    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 30;
                    final result = await _showWheelTimePicker(context, initialHour: h, initialMinute: m);
                    if (result != null) {
                      setDialogState(() => timeController.text = result);
                    }
                  },
                  child: AbsorbPointer(
                    child: TextField(
                      controller: timeController,
                      style: TextStyle(color: pearlWhite, fontSize: 18),
                      decoration: InputDecoration(
                        labelText: 'İlk Doz Saati',
                        prefixIcon: Icon(Icons.access_time, color: pearlWhite),
                        hintText: "SS:DD",
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: pearlWhite,
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

                final inputValue = int.parse(durationText);
                // Frequency'e gore gercek durationDays hesapla
                int durationDays;
                if (frequencyType == 0) {
                  durationDays = inputValue; // Her gun: input = toplam gun
                } else if (frequencyType == 1) {
                  durationDays = inputValue * xVal; // X gunde bir, N doz icin N*X gun
                } else {
                  // Haftada X gun: N doz icin tam haftalar + kalan gunler
                  final fullWeeks = inputValue ~/ xVal;
                  final remainder = inputValue % xVal;
                  durationDays = fullWeeks * 7 + (remainder == 0 ? 0 : remainder);
                }

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

                  setState(() {
                    final idxAll = _allReminders.indexWhere((r) => r.id == saved.id);
                    if (idxAll >= 0) {
                      _allReminders[idxAll] = saved;
                    } else {
                      _allReminders.add(saved);
                    }
                    });

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

                  /*if (!mounted) return;
                  Navigator.pop(context);
                } catch (e) {
                  setDialogState(() {
                    popupError = e.toString().replaceFirst('Exception: ', '');
                  });
                }*/
                if (Navigator.of(context, rootNavigator: true).canPop()) {
                  Navigator.of(context, rootNavigator: true).pop();
                }
                } catch (e) {
                  // Hata durumunda diyagram kapanmaz, hata mesajı kullanıcıya gösterilir
                  setDialogState(() {
                  popupError = e.toString().replaceFirst('Exception: ', '');
                });
              }

                
              },
              child: Text(
                'KAYDET',
                style: TextStyle(color: midnightBlue, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              
            ),
          ],
        ),
      ),
    ),
    );
  }

  // ============================================================
  // =========================== UI ==============================
  // ============================================================

  @override
  /*Widget build(BuildContext context) {
    final selectedDay = _selectedDay ?? DateTime.now();

    return Scaffold(
      bottomNavigationBar: const HealzyBottomNav(current: HealzyNavTab.reminder),
      appBar: AppBar(
        title: const Text(
          "Healzy İlaç Hatırlatıcı",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: pearlWhite,
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
              Navigator.push<MedicineReminderDto?>(
                context,
                MaterialPageRoute(
                  builder: (_) => AllRemindersPage(
                    api: _api,
                    healzyTurquoise: pearlWhite,
                    healzyDarkGreen: midnightBlue,
                    onEdit: (item) => _showAddReminderDialog(editing: item),
                    onChanged: () => _loadAllAndSelectedDay(),
                  ),
                ),
              ).then((editItem) {
                _loadAllAndSelectedDay();
                if (editItem != null) {
                  _showAddReminderDialog(editing: editItem);
                }
              });
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
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: pearlWhite,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: pearlWhite.withOpacity(0.4),
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
                              Icon(Icons.alarm, color: pearlWhite),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: midnightBlue,
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
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: item.intakeType == 0
                                        ? Colors.orange[800]
                                        : Colors.green[800],
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.edit,
                                    color: pearlWhite, size: 22),
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
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "${item.startDateUtc.day.toString().padLeft(2, '0')}.${item.startDateUtc.month.toString().padLeft(2, '0')}.${item.startDateUtc.year} — ${item.startDateUtc.add(Duration(days: item.durationDays)).day.toString().padLeft(2, '0')}.${item.startDateUtc.add(Duration(days: item.durationDays)).month.toString().padLeft(2, '0')}.${item.startDateUtc.add(Duration(days: item.durationDays)).year}",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
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
                                      t.split(':').take(2).join(':'),
                                      style: TextStyle(
                                        color: midnightBlue,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
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
                                      t.split(':').take(2).join(':'),
                                      style: TextStyle(
                                        color: Colors.green[700],
                                        fontSize: 14,
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
        backgroundColor: pearlWhite,
        onPressed: () => _showAddReminderDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}*/

Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A1A2B), Color(0xFF132B44), Color(0xFF1B3A5C)],
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              const Color(0xFFD4EAF7),
              const Color(0xFFB8D8EB),
            ],
          );
    final fgColor = isDark ? const Color(0xFFF1F6FC) : midnightBlue;

    return Scaffold(
      bottomNavigationBar: const HealzyBottomNav(current: HealzyNavTab.reminder),
      extendBody: true,
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true, // AppBar'ın arkasına gradient geçmesi için
      appBar: AppBar(
        title: Text(
          "İlaç Hatırlatıcı",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: fgColor),
        ),
        backgroundColor: Colors.transparent, // Cam tasarımı için şeffaf
        elevation: 0,
        foregroundColor: fgColor,
        iconTheme: IconThemeData(color: fgColor),
        actions: [
          IconButton(
    icon: const Icon(Icons.refresh),
    onPressed: _loadAllAndSelectedDay,
    tooltip: "Yenile",
  ),
  IconButton(
    icon: const Icon(Icons.calendar_view_day_rounded), // Burası senin bahsettiğin buton
    tooltip: "Tüm Hatırlatıcılar",
    onPressed: () {
      Navigator.push<MedicineReminderDto?>(
        context,
        MaterialPageRoute(
          builder: (_) => AllRemindersPage(
            api: _api,
            healzyTurquoise: pearlWhite,
            healzyDarkGreen: midnightBlue,
            onEdit: (item) => _showAddReminderDialog(editing: item),
            onChanged: () => _loadAllAndSelectedDay(),
          ),
        ),
      ).then((editItem) {
        _loadAllAndSelectedDay();
        if (editItem != null) {
          _showAddReminderDialog(editing: editItem);
        }
      });
    },
  ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              if (_loading) const LinearProgressIndicator(),
              
              // === CAM GÖRÜNÜMLÜ TAKVİM BAŞLANGIÇ ===
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF132B44).withValues(alpha: 0.85)
                            : Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.white.withValues(alpha: 0.4)),
                      ),
                      child: TableCalendar(
                        locale: 'tr_TR',
                        firstDay: DateTime.utc(2025, 1, 1),
                        lastDay: DateTime.utc(2099, 12, 31),
                        focusedDay: _focusedDay,
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        eventLoader: _getEventsForDay,
                        daysOfWeekStyle: DaysOfWeekStyle(
                          weekdayStyle: TextStyle(color: fgColor.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
                          weekendStyle: TextStyle(color: fgColor.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
                        ),
                        headerStyle: HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: TextStyle(
                            color: fgColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          leftChevronIcon: Icon(Icons.chevron_left, color: fgColor),
                          rightChevronIcon: Icon(Icons.chevron_right, color: fgColor),
                        ),
                        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                        calendarStyle: CalendarStyle(
                          defaultTextStyle: TextStyle(color: fgColor, fontWeight: FontWeight.w500, fontSize: 15),
                          weekendTextStyle: TextStyle(color: fgColor, fontWeight: FontWeight.w500, fontSize: 15),
                          outsideDaysVisible: false,
                          selectedDecoration: BoxDecoration(
                            color: isDark ? pearlWhite : midnightBlue,
                            shape: BoxShape.circle,
                          ),
                          selectedTextStyle: TextStyle(
                              color: isDark ? midnightBlue : Colors.white,
                              fontWeight: FontWeight.bold),
                          todayDecoration: BoxDecoration(
                            color: fgColor.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                        ),
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, date, events) {
                            if (events.isNotEmpty) {
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: events.take(4).map((event) {
                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 0.5),
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.orangeAccent, // Önemli günler için renk
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
                          await _loadSelectedDayOnly(day);
                        },
                      ),
                    ),
                  ),
                ),
              ),
              // === CAM GÖRÜNÜMLÜ TAKVİM BİTİŞ ===

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Bugünkü İlaçlar",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: fgColor),
                  ),
                ),
              ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: _reminders.length,
                  itemBuilder: (context, index) {
                    final item = _reminders[index];
                    return _buildModernMedicineCard(item, index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: isDark ? const Color(0xFF1B3A5C) : midnightBlue,
        onPressed: () => _showAddReminderDialog(),
        child: Icon(Icons.add, color: isDark ? const Color(0xFFF1F6FC) : Colors.white),
      ),
    );
  }

  Widget _buildModernMedicineCard(MedicineReminderDto item, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? const Color(0xFFF1F6FC) : midnightBlue;
    final subtitleColor = isDark ? const Color(0xFFB0C2D6) : const Color(0xFF5A6B80);
    final iconBg = isDark ? const Color(0xFF1B3A5C) : midnightBlue.withValues(alpha: 0.1);
    final iconColor = isDark ? const Color(0xFFF1F6FC) : midnightBlue;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : midnightBlue).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF132B44).withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : midnightBlue.withValues(alpha: 0.1),
                width: 0.8,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: CircleAvatar(
                backgroundColor: iconBg,
                child: Icon(Icons.medication, color: iconColor),
              ),
              title: Text(item.name, style: TextStyle(fontWeight: FontWeight.bold, color: titleColor)),
              subtitle: Text(
                "${_getFrequencyText(item)} - ${item.timesPerDay} Kez",
                style: TextStyle(color: subtitleColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

