// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import '../database/database_helper.dart';
import '../database/db_constants.dart';
import '../navigation/app_navigator.dart';
import '../../features/patient/screens/dose_confirmation_screen.dart';

class NotificationService {
  // ── Singleton ─────────────────────────────────────────
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _launchPayload;

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

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _launchPayload = launchDetails?.notificationResponse?.payload;
    }

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
    _openDoseConfirmationFromPayload(response.payload);
  }

  Future<void> processPendingLaunchPayload() async {
    final payload = _launchPayload;
    if (payload == null || payload.isEmpty) return;
    _launchPayload = null;
    await _openDoseConfirmationFromPayload(payload);
  }

  Future<void> _openDoseConfirmationFromPayload(
    String? payload,
  ) async {
    if (payload == null || payload.isEmpty) return;

    final parts = payload.split('|');
    if (parts.length < 4) return;

    final patientId = int.tryParse(parts[0]);
    final medicationId = int.tryParse(parts[1]);
    final timeToken = parts[2];
    final reminderStage = int.tryParse(parts[3]) ?? 1;

    if (patientId == null || medicationId == null) return;

    final patient = await DatabaseHelper.instance.getPatientById(patientId);
    final medication =
        await DatabaseHelper.instance.getMedicationById(medicationId);

    final navigator = appNavigatorKey.currentState;
    if (navigator == null || patient == null || medication == null) {
      return;
    }

    final scheduledDateTime = reminderStage == 2
        ? DateTime.tryParse(timeToken) ?? DateTime.now()
        : _scheduledDateTimeFromClock(timeToken);

    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => DoseConfirmationScreen(
          medication: medication,
          patientId: patientId,
          patientName:
              patient[DBConstants.patientFullName] as String? ?? 'Patient',
          scheduledTime: scheduledDateTime.toIso8601String(),
          autoPlayReminder: true,
          reminderStage: reminderStage,
        ),
      ),
    );
  }

  DateTime _scheduledDateTimeFromClock(String timeToken) {
    final now = DateTime.now();
    final timeParts = timeToken.split(':');
    final hour = timeParts.isNotEmpty
        ? int.tryParse(timeParts[0]) ?? now.hour
        : now.hour;
    final minute = timeParts.length > 1
        ? int.tryParse(timeParts[1]) ?? now.minute
        : now.minute;

    return DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
  }

  // ══════════════════════════════════════════════════════
  //  SCHEDULE DAILY MEDICINE REMINDER
  // ══════════════════════════════════════════════════════
  Future<void> scheduleMedicineReminder({
    required int notificationId,
    required int patientId,
    required int medicationId,
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
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'medivoice_reminders',
      'Medicine Reminders',
      channelDescription: 'Reminders to take your medicine on time',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      ticker: 'Medicine Reminder',
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      autoCancel: false,
      ongoing: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
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
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // repeat daily
      payload: '$patientId|$medicationId|'
          '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}|1',
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
    required int patientId,
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
        patientId: patientId,
        medicationId: medicationId,
        medicineName: medicineName,
        dosage: dosage,
        unit: unit,
        time: timeSlots[i],
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

  Future<void> scheduleSecondReminder({
    required int patientId,
    required int medicationId,
    required String medicineName,
    required String dosage,
    required String unit,
    required DateTime originalScheduledTime,
    int minutesLater = 10,
  }) async {
    if (!_initialized) await initialize();

    final scheduledDate = tz.TZDateTime.from(
      originalScheduledTime.add(Duration(minutes: minutesLater)),
      tz.local,
    );

    const androidDetails = AndroidNotificationDetails(
      'medivoice_follow_up_reminders',
      'Follow-up Medicine Reminders',
      channelDescription: 'Second reminders for unconfirmed medicine doses',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      autoCancel: false,
      ongoing: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      icon: '@mipmap/ic_launcher',
    );

    await _plugin.zonedSchedule(
      _secondReminderId(medicationId, originalScheduledTime),
      'Medicine reminder',
      'Please take $medicineName $dosage $unit',
      scheduledDate,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload:
          '$patientId|$medicationId|${originalScheduledTime.toIso8601String()}|2',
    );
  }

  Future<void> cancelSecondReminder({
    required int medicationId,
    required DateTime originalScheduledTime,
  }) async {
    await _plugin.cancel(
      _secondReminderId(medicationId, originalScheduledTime),
    );
  }

  int _secondReminderId(
    int medicationId,
    DateTime originalScheduledTime,
  ) {
    final minutesOfDay =
        (originalScheduledTime.hour * 60) + originalScheduledTime.minute;
    // Stride must be >= 1440 (minutes/day) so each medication gets a
    // non-overlapping block of IDs — otherwise two meds could collide on the
    // same notification ID and cancel each other's follow-up reminder.
    return 500000 + (medicationId * 1440) + minutesOfDay;
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
      channelDescription: 'Reminders to take your medicine on time',
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
