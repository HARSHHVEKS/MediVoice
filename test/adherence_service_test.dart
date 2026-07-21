import 'package:flutter_test/flutter_test.dart';
import 'package:medivoice/core/database/db_constants.dart';
import 'package:medivoice/core/services/adherence_service.dart';

Map<String, dynamic> med(int id, {String name = 'Med'}) => {
      DBConstants.medId: id,
      DBConstants.medName: name,
      DBConstants.medDosage: '1',
      DBConstants.medDosageUnit: 'tab',
    };

Map<String, dynamic> sched(
  int id,
  int medId,
  String time, {
  String days = '1,2,3,4,5,6,7',
  int enabled = 1,
}) =>
    {
      DBConstants.schedId: id,
      DBConstants.schedMedId: medId,
      DBConstants.schedTime: time,
      DBConstants.schedDays: days,
      DBConstants.schedIsEnabled: enabled,
    };

Map<String, dynamic> log(int medId, DateTime scheduled, String status) => {
      DBConstants.logMedId: medId,
      DBConstants.logScheduledTime: scheduled.toIso8601String(),
      DBConstants.logStatus: status,
    };

void main() {
  group('computeTodaysDoses', () {
    final now = DateTime(2026, 7, 21, 10, 0); // fixed clock

    test('buckets overdue-pending as dueNow and later as upcoming', () {
      final slots = AdherenceService.computeTodaysDoses(
        medications: [med(1)],
        schedulesByMed: {
          1: [sched(1, 1, '08:00'), sched(2, 1, '20:00')],
        },
        logs: const [],
        now: now,
      );

      expect(slots.length, 2);
      expect(slots[0].scheduledTime.hour, 8);
      expect(slots[0].bucket(now), DoseBucket.dueNow);
      expect(slots[1].scheduledTime.hour, 20);
      expect(slots[1].bucket(now), DoseBucket.upcoming);
    });

    test('a matching taken log marks the slot taken', () {
      final slots = AdherenceService.computeTodaysDoses(
        medications: [med(1)],
        schedulesByMed: {
          1: [sched(1, 1, '08:00'), sched(2, 1, '20:00')],
        },
        logs: [
          log(1, DateTime(2026, 7, 21, 8, 0), DBConstants.statusTaken),
        ],
        now: now,
      );

      expect(slots[0].status, DBConstants.statusTaken);
      expect(slots[0].bucket(now), DoseBucket.taken);
      expect(slots[1].bucket(now), DoseBucket.upcoming);
    });

    test('disabled schedules and other weekdays are excluded', () {
      final slots = AdherenceService.computeTodaysDoses(
        medications: [med(1)],
        schedulesByMed: {
          1: [
            sched(1, 1, '08:00', enabled: 0),
            // 2026-07-21 is a Tuesday (weekday 2); only allow Monday.
            sched(2, 1, '09:00', days: '1'),
          ],
        },
        logs: const [],
        now: now,
      );

      expect(slots, isEmpty);
    });
  });

  group('computeAdherence', () {
    final now = DateTime(2026, 7, 21, 23, 0);

    test('percent is taken over resolved', () {
      final summary = AdherenceService.computeAdherence(
        logs: [
          log(1, DateTime(2026, 7, 21, 8, 0), DBConstants.statusTaken),
          log(1, DateTime(2026, 7, 20, 8, 0), DBConstants.statusTaken),
          log(1, DateTime(2026, 7, 20, 20, 0), DBConstants.statusTaken),
          log(1, DateTime(2026, 7, 19, 8, 0), DBConstants.statusMissed),
          log(1, DateTime(2026, 7, 19, 20, 0), DBConstants.statusSkipped),
        ],
        now: now,
        days: 7,
      );

      expect(summary.taken, 3);
      expect(summary.missed, 1);
      expect(summary.skipped, 1);
      expect(summary.percent, closeTo(3 / 5, 1e-9));
    });

    test('empty set is treated as 100%', () {
      final summary = AdherenceService.computeAdherence(
        logs: const [],
        now: now,
        days: 7,
      );
      expect(summary.percent, 1.0);
    });

    test('logs outside the window are ignored', () {
      final summary = AdherenceService.computeAdherence(
        logs: [
          log(1, DateTime(2026, 7, 1, 8, 0), DBConstants.statusTaken),
        ],
        now: now,
        days: 7,
      );
      expect(summary.resolved, 0);
    });
  });

  group('computeStreak', () {
    final now = DateTime(2026, 7, 21, 10, 0);
    final meds = [med(1)];
    final schedules = {
      1: [sched(1, 1, '09:00')],
    };

    test('counts consecutive fully-taken past days, ignoring pending today', () {
      final streak = AdherenceService.computeStreak(
        medications: meds,
        schedulesByMed: schedules,
        logs: [
          log(1, DateTime(2026, 7, 20, 9, 0), DBConstants.statusTaken),
          log(1, DateTime(2026, 7, 19, 9, 0), DBConstants.statusTaken),
          // 2026-07-18 has no taken log → streak stops there.
        ],
        now: now,
      );
      expect(streak, 2);
    });

    test('a missed day breaks the streak', () {
      final streak = AdherenceService.computeStreak(
        medications: meds,
        schedulesByMed: schedules,
        logs: [
          log(1, DateTime(2026, 7, 20, 9, 0), DBConstants.statusMissed),
        ],
        now: now,
      );
      expect(streak, 0);
    });
  });
}
