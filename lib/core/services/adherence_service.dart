import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../database/db_constants.dart';

/// Where a dose slot belongs on the "Today" dashboard.
enum DoseBucket { dueNow, upcoming, taken, missed }

/// A single scheduled dose for a given day, resolved against the dose logs.
@immutable
class DoseSlot {
  const DoseSlot({
    required this.medication,
    required this.scheduledTime,
    required this.status,
    this.scheduleId,
  });

  final Map<String, dynamic> medication;
  final DateTime scheduledTime;
  final String status; // pending / taken / missed / skipped
  final int? scheduleId;

  int get medicationId => medication[DBConstants.medId] as int;
  String get medicationName =>
      medication[DBConstants.medName] as String? ?? 'Medicine';

  DoseBucket bucket(DateTime now) {
    switch (status) {
      case DBConstants.statusTaken:
        return DoseBucket.taken;
      case DBConstants.statusMissed:
      case DBConstants.statusSkipped:
        return DoseBucket.missed;
      default:
        // Pending: due now if within the next hour or already overdue.
        final dueThreshold = now.add(const Duration(minutes: 60));
        return scheduledTime.isAfter(dueThreshold)
            ? DoseBucket.upcoming
            : DoseBucket.dueNow;
    }
  }
}

/// Adherence summary over a window of days.
@immutable
class AdherenceSummary {
  const AdherenceSummary({
    required this.taken,
    required this.missed,
    required this.skipped,
  });

  final int taken;
  final int missed;
  final int skipped;

  int get resolved => taken + missed + skipped;

  /// Fraction taken of all resolved doses. Empty set → 1.0 (nothing due).
  double get percent => resolved == 0 ? 1.0 : taken / resolved;
}

/// Computes today's dose slots, adherence percentages, and streaks from the
/// medicines, reminder schedules, and dose logs already stored locally.
///
/// The pure `computeX` static methods take pre-fetched data so they can be
/// unit-tested with a fixed clock and no database.
class AdherenceService {
  AdherenceService._();
  static final AdherenceService instance = AdherenceService._();

  final _db = DatabaseHelper.instance;

  // ── Public, DB-backed API ────────────────────────────────

  /// Today's dose slots for [patientId], sorted by scheduled time.
  Future<List<DoseSlot>> todaysDoses(
    int patientId, {
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    final meds = await _db.getMedicationsByPatient(patientId);

    final schedulesByMed = <int, List<Map<String, dynamic>>>{};
    for (final med in meds) {
      final medId = med[DBConstants.medId] as int;
      schedulesByMed[medId] = await _db.getSchedulesByMedication(medId);
    }

    final logs = await _db.getDoseLogsByPatient(patientId, limit: 1000);
    return computeTodaysDoses(
      medications: meds,
      schedulesByMed: schedulesByMed,
      logs: logs,
      now: clock,
    );
  }

  /// Adherence over the last [days] days (inclusive of today).
  Future<AdherenceSummary> adherence(
    int patientId, {
    int days = 7,
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    final logs = await _db.getDoseLogsByPatient(patientId, limit: 1000);
    return computeAdherence(logs: logs, now: clock, days: days);
  }

  /// Consecutive days (ending yesterday, plus today if fully taken) on which
  /// every scheduled dose was taken.
  Future<int> currentStreak(int patientId, {DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final meds = await _db.getMedicationsByPatient(patientId);
    final schedulesByMed = <int, List<Map<String, dynamic>>>{};
    for (final med in meds) {
      final medId = med[DBConstants.medId] as int;
      schedulesByMed[medId] = await _db.getSchedulesByMedication(medId);
    }
    final logs = await _db.getDoseLogsByPatient(patientId, limit: 2000);
    return computeStreak(
      medications: meds,
      schedulesByMed: schedulesByMed,
      logs: logs,
      now: clock,
    );
  }

  // ── Pure computation (unit-testable) ─────────────────────

  static List<DoseSlot> computeTodaysDoses({
    required List<Map<String, dynamic>> medications,
    required Map<int, List<Map<String, dynamic>>> schedulesByMed,
    required List<Map<String, dynamic>> logs,
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final weekday = today.weekday; // 1 = Mon … 7 = Sun
    final logIndex = _indexLogs(logs);
    final slots = <DoseSlot>[];

    for (final med in medications) {
      final medId = med[DBConstants.medId] as int;
      final schedules = schedulesByMed[medId] ?? const [];
      for (final sched in schedules) {
        if ((sched[DBConstants.schedIsEnabled] as int? ?? 1) == 0) continue;
        if (!_activeOnWeekday(
            sched[DBConstants.schedDays] as String?, weekday)) {
          continue;
        }
        final time = _parseHm(sched[DBConstants.schedTime] as String?);
        if (time == null) continue;

        final scheduledAt = DateTime(
          today.year,
          today.month,
          today.day,
          time.$1,
          time.$2,
        );
        final key = _logKey(medId, today, time.$1, time.$2);
        final status = logIndex[key] ?? DBConstants.statusPending;

        slots.add(DoseSlot(
          medication: med,
          scheduledTime: scheduledAt,
          status: status,
          scheduleId: sched[DBConstants.schedId] as int?,
        ));
      }
    }

    slots.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return slots;
  }

  static AdherenceSummary computeAdherence({
    required List<Map<String, dynamic>> logs,
    required DateTime now,
    required int days,
  }) {
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    var taken = 0, missed = 0, skipped = 0;

    for (final log in logs) {
      final scheduled =
          DateTime.tryParse(log[DBConstants.logScheduledTime] as String? ?? '');
      if (scheduled == null) continue;
      final day = DateTime(scheduled.year, scheduled.month, scheduled.day);
      if (day.isBefore(start) || day.isAfter(now)) continue;

      switch (log[DBConstants.logStatus] as String?) {
        case DBConstants.statusTaken:
          taken++;
        case DBConstants.statusMissed:
          missed++;
        case DBConstants.statusSkipped:
          skipped++;
      }
    }
    return AdherenceSummary(taken: taken, missed: missed, skipped: skipped);
  }

  static int computeStreak({
    required List<Map<String, dynamic>> medications,
    required Map<int, List<Map<String, dynamic>>> schedulesByMed,
    required List<Map<String, dynamic>> logs,
    required DateTime now,
    int maxLookbackDays = 365,
  }) {
    final logIndex = _indexLogs(logs);
    final today = DateTime(now.year, now.month, now.day);
    var streak = 0;

    for (var offset = 0; offset < maxLookbackDays; offset++) {
      final day = today.subtract(Duration(days: offset));
      final weekday = day.weekday;
      var scheduledCount = 0;
      var takenCount = 0;

      for (final med in medications) {
        final medId = med[DBConstants.medId] as int;
        final schedules = schedulesByMed[medId] ?? const [];
        for (final sched in schedules) {
          if ((sched[DBConstants.schedIsEnabled] as int? ?? 1) == 0) continue;
          if (!_activeOnWeekday(
              sched[DBConstants.schedDays] as String?, weekday)) {
            continue;
          }
          final time = _parseHm(sched[DBConstants.schedTime] as String?);
          if (time == null) continue;

          scheduledCount++;
          final status =
              logIndex[_logKey(medId, day, time.$1, time.$2)] ??
                  DBConstants.statusPending;
          if (status == DBConstants.statusTaken) takenCount++;
        }
      }

      if (scheduledCount == 0) {
        // No doses scheduled this day — doesn't extend or break the streak.
        continue;
      }
      if (takenCount == scheduledCount) {
        streak++;
      } else if (offset == 0) {
        // Today may still have upcoming/pending doses — don't break the
        // streak on it; it only counts once every dose is taken (above).
        continue;
      } else {
        break;
      }
    }
    return streak;
  }

  // ── Helpers ──────────────────────────────────────────────

  static Map<String, String> _indexLogs(List<Map<String, dynamic>> logs) {
    final index = <String, String>{};
    for (final log in logs) {
      final scheduled =
          DateTime.tryParse(log[DBConstants.logScheduledTime] as String? ?? '');
      final status = log[DBConstants.logStatus] as String?;
      final medId = log[DBConstants.logMedId] as int?;
      if (scheduled == null || status == null || medId == null) continue;
      final day = DateTime(scheduled.year, scheduled.month, scheduled.day);
      final key = _logKey(medId, day, scheduled.hour, scheduled.minute);
      // Prefer a resolved status over pending if duplicates exist.
      final existing = index[key];
      if (existing == null || existing == DBConstants.statusPending) {
        index[key] = status;
      }
    }
    return index;
  }

  static String _logKey(int medId, DateTime day, int hour, int minute) {
    final d =
        '${day.year}-${_two(day.month)}-${_two(day.day)}';
    return '$medId|$d|${_two(hour)}:${_two(minute)}';
  }

  static bool _activeOnWeekday(String? daysCsv, int weekday) {
    if (daysCsv == null || daysCsv.isEmpty) return true;
    return daysCsv
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .contains(weekday);
  }

  /// Parses "HH:mm" → (hour, minute).
  static (int, int)? _parseHm(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return (h, m);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
