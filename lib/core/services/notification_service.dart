// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  // ── Singleton ─────────────────────────────────────────
  NotificationService._();
  static final NotificationService instance =
      NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ══════════════════════════════════════════════════════
  //  INITIALIZE — call once in main.dart
  // ══════════════════════════════════════════════════════
  Future<void> initialize() async {
    if (_initialized) return;

    // Init timezone data
    tz_data.initializeTimeZones();
    tz.setLocalLocation(
      tz.getLocation('Africa/Kampala'), // Uganda timezone
    );

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Request permission Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Request exact alarm permission
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();

    _initialized = true;
    debugPrint('✅ NOTIFICATIONS: Initialized');
  }

  // ── Handle notification tap ───────────────────────────
  void _onNotificationTap(NotificationResponse response) {
    debugPrint(
      '🔔 NOTIFICATION TAPPED: ${response.payload}',
    );
  }

  // ══════════════════════════════════════════════════════
  //  SCHEDULE DAILY MEDICINE REMINDER
  // ══════════════════════════════════════════════════════
  Future<void> scheduleMedicineReminder({
    required int notificationId,
    required String medicineName,
    required String dosage,
    required String unit,
    required TimeOfDay time,
  }) async {
    if (!_initialized) await initialize();

    final now = tz.TZDateTime.now(tz.local);

    // Build scheduled time for today
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
      0,
    );

    // If time already passed today → schedule tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate
          .add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'medivoice_reminders',
      'Medicine Reminders',
      channelDescription:
          'Reminders to take your medicine on time',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      ticker: 'Medicine Reminder',
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.zonedSchedule(
      notificationId,
      '💊 Time for your medicine',
      'Take your $medicineName — $dosage $unit',
      scheduledDate,
      notificationDetails,
      androidScheduleMode:
          AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents:
          DateTimeComponents.time, // repeat daily
      payload: '$notificationId|$medicineName',
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint(
      '✅ ALARM SET: $medicineName at '
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')} '
      '(ID: $notificationId)',
    );
  }

  // ══════════════════════════════════════════════════════
  //  SCHEDULE ALL REMINDERS FOR A MEDICINE
  //  Call this after saving medication + time slots
  // ══════════════════════════════════════════════════════
  Future<void> scheduleAllReminders({
    required int medicationId,
    required String medicineName,
    required String dosage,
    required String unit,
    required List<TimeOfDay> timeSlots,
  }) async {
    for (int i = 0; i < timeSlots.length; i++) {
      // Unique ID per slot:
      // medicationId * 100 + slot index
      // e.g. med 5, slot 2 → ID 502
      final notifId = (medicationId * 100) + i;

      await scheduleMedicineReminder(
        notificationId: notifId,
        medicineName:   medicineName,
        dosage:         dosage,
        unit:           unit,
        time:           timeSlots[i],
      );
    }
  }

  // ══════════════════════════════════════════════════════
  //  CANCEL REMINDERS FOR A MEDICINE
  //  Call this when medicine is deleted/updated
  // ══════════════════════════════════════════════════════
  Future<void> cancelMedicineReminders({
    required int medicationId,
    required int slotCount,
  }) async {
    for (int i = 0; i < slotCount; i++) {
      final notifId = (medicationId * 100) + i;
      await _plugin.cancel(notifId);
      debugPrint('🗑️ ALARM CANCELLED: ID $notifId');
    }
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    debugPrint('🗑️ ALL ALARMS CANCELLED');
  }

  // ══════════════════════════════════════════════════════
  //  TEST — fires immediately to confirm it works
  // ══════════════════════════════════════════════════════
  Future<void> showTestNotification({
    String medicineName = 'Paracetamol',
    String dosage = '500',
    String unit = 'mg',
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'medivoice_reminders',
      'Medicine Reminders',
      channelDescription:
          'Reminders to take your medicine on time',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      playSound: true,
      enableVibration: true,
    );

    await _plugin.show(
      9999,
      '💊 Time for your medicine',
      'Take your $medicineName — $dosage $unit',
      const NotificationDetails(android: androidDetails),
    );

    debugPrint('✅ TEST NOTIFICATION SENT');
  }
}