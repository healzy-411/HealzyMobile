import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService I = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    // Türkiye için sabitlemek istersen:
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(initSettings);

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      return granted;
    }

    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission() ?? false;
      return granted;
    }

    return true;
  }

  /// Tek seferlik bildirim (tarih-saat geldiğinde)
  Future<void> scheduleOneTime({
    required int id,
    required String title,
    required String body,
    required DateTime whenLocal,
  }) async {
    // geçmiş tarih olursa schedule etme
    if (whenLocal.isBefore(DateTime.now())) return;

    const androidDetails = AndroidNotificationDetails(
      'healzy_reminders',
      'Healzy Reminders',
      channelDescription: 'İlaç hatırlatma bildirimleri',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(whenLocal, tz.local),
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null, // tek sefer
    );
  }

  /// Anında bildirim göster (sipariş/talep durum güncellemeleri için)
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'healzy_status',
      'Healzy Durum Bildirimleri',
      channelDescription: 'Sipariş ve talep durum bildirimleri',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  Future<void> cancelAll() => _plugin.cancelAll();
}