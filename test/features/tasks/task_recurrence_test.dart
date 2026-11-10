import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tasks/domain/task_recurrence.dart';
import 'package:tawheeed/features/tasks/domain/entities/task_model.dart';
import 'package:tawheeed/features/tasks/presentation/providers/task_provider.dart';

void main() {
  group('TaskRecurrence.nextDue', () {
    test('weekly rolls forward by whole weeks past completion', () {
      // Monday 2026-09-07 due, completed Tuesday 2026-09-08 → next Monday.
      final next = TaskRecurrence.nextDue(
        type: TaskRecurrence.weekly,
        dueDate: DateTime(2026, 9, 7),
        completedAt: DateTime(2026, 9, 8, 12),
      );
      expect(next, DateTime(2026, 9, 14));
    });

    test('daily rolls to the next day', () {
      final next = TaskRecurrence.nextDue(
        type: TaskRecurrence.daily,
        dueDate: DateTime(2026, 9, 7),
        completedAt: DateTime(2026, 9, 7, 20),
      );
      expect(next, DateTime(2026, 9, 8));
    });

    test('unsupported type returns null', () {
      expect(
        TaskRecurrence.nextDue(
          type: 'sometimes',
          dueDate: DateTime(2026, 9, 7),
          completedAt: DateTime(2026, 9, 7),
        ),
        isNull,
      );
    });

    test('monthly keeps the day-of-month and rolls to the next month', () {
      final next = TaskRecurrence.nextDue(
        type: TaskRecurrence.monthly,
        dueDate: DateTime(2026, 9, 7),
        completedAt: DateTime(2026, 9, 7, 20),
      );
      expect(next, DateTime(2026, 10, 7));
    });

    test('monthly clamps the 31st to the target month length', () {
      // Jan 31 → Feb has no 31st → Feb 28 (2027 is not a leap year).
      final next = TaskRecurrence.nextDue(
        type: TaskRecurrence.monthly,
        dueDate: DateTime(2027, 1, 31),
        completedAt: DateTime(2027, 1, 31, 20),
      );
      expect(next, DateTime(2027, 2, 28));
    });

    test('monthly skips whole missed months when completed late', () {
      final next = TaskRecurrence.nextDue(
        type: TaskRecurrence.monthly,
        dueDate: DateTime(2026, 6, 7),
        completedAt: DateTime(2026, 9, 20),
      );
      expect(next, DateTime(2026, 10, 7));
    });

    test('every N days steps from the due date, skipping missed periods', () {
      final next = TaskRecurrence.nextDue(
        type: TaskRecurrence.encodeEveryN(3),
        dueDate: DateTime(2026, 9, 7),
        completedAt: DateTime(2026, 9, 9, 20),
      );
      // 7th + 3 = 10th, which is already after the completion day (9th)
      // → stays (unlike daily/weekly semantics here, no extra skip needed).
      expect(next, DateTime(2026, 9, 10));
    });

    test('every N days skips whole missed periods when completed late', () {
      final next = TaskRecurrence.nextDue(
        type: TaskRecurrence.encodeEveryN(3),
        dueDate: DateTime(2026, 9, 7),
        completedAt: DateTime(2026, 9, 11, 20),
      );
      // 10th is before the 11th completion → skipped → 13th.
      expect(next, DateTime(2026, 9, 13));
    });

    test('every N days decode/label round-trips', () {
      final type = TaskRecurrence.encodeEveryN(5);
      expect(TaskRecurrence.baseOf(type), TaskRecurrence.everyNDays);
      expect(TaskRecurrence.intervalOf(type), 5);
      expect(TaskRecurrence.label(type), 'هر 5 روز');
      expect(TaskRecurrence.isSupported(type), isTrue);
      expect(
          TaskRecurrence.intervalOf(null), TaskRecurrence.defaultIntervalDays);
    });
  });

  group('TaskRecurrence weekdays', () {
    test('weekdayNameFa matches the Persian week', () {
      // 2026-09-09 is a Wednesday.
      expect(TaskRecurrence.weekdayNameFa(DateTime(2026, 9, 9)), 'چهارشنبه');
      expect(TaskRecurrence.weekdayNameFa(DateTime(2026, 9, 5)), 'شنبه');
      expect(TaskRecurrence.weekdayNameFa(DateTime(2026, 9, 11)), 'جمعه');
    });

    test('nextWeekday anchors on the coming weekday', () {
      // Wednesday 2026-09-09 → next Wednesday (Dart weekday 3) is itself.
      expect(TaskRecurrence.nextWeekday(DateTime(2026, 9, 9), 3),
          DateTime(2026, 9, 9));
      // …and next Saturday (Dart weekday 6) is 2026-09-12.
      expect(TaskRecurrence.nextWeekday(DateTime(2026, 9, 9), 6),
          DateTime(2026, 9, 12));
      // Monday (1) after Wednesday wraps to next week.
      expect(TaskRecurrence.nextWeekday(DateTime(2026, 9, 9), 1),
          DateTime(2026, 9, 14));
    });
  });

  group('TaskRecurrence.currentStreak', () {
    test('daily counts consecutive days back from today', () {
      final now = DateTime(2026, 9, 9, 12);
      expect(
        TaskRecurrence.currentStreak(
          [DateTime(2026, 9, 9), DateTime(2026, 9, 8), DateTime(2026, 9, 7)],
          TaskRecurrence.daily,
          now,
        ),
        3,
      );
    });

    test('daily tolerates one missing current day', () {
      final now = DateTime(2026, 9, 9, 12);
      expect(
        TaskRecurrence.currentStreak(
          [DateTime(2026, 9, 8), DateTime(2026, 9, 7)],
          TaskRecurrence.daily,
          now,
        ),
        2,
      );
    });

    test('daily breaks on a gap', () {
      final now = DateTime(2026, 9, 9, 12);
      expect(
        TaskRecurrence.currentStreak(
          [DateTime(2026, 9, 9), DateTime(2026, 9, 7)],
          TaskRecurrence.daily,
          now,
        ),
        1,
      );
    });

    test('weekly counts consecutive Saturday-weeks', () {
      // Wednesdays 2026-08-26, 2026-09-02, 2026-09-09 → 3 weeks.
      final now = DateTime(2026, 9, 9, 12);
      expect(
        TaskRecurrence.currentStreak(
          [DateTime(2026, 9, 9), DateTime(2026, 9, 2), DateTime(2026, 8, 26)],
          TaskRecurrence.weekly,
          now,
        ),
        3,
      );
    });

    test('empty history is zero', () {
      expect(
          TaskRecurrence.currentStreak(
              [], TaskRecurrence.daily, DateTime(2026, 9, 9)),
          0);
    });

    test('monthly counts calendar months, not days', () {
      // One completion a month, on scattered days of the month. Pre-fix this
      // treated every non-weekly cadence as daily, so a monthly task could
      // never count past 1 — the badge never appeared for it at all.
      final now = DateTime(2026, 9, 20, 12);
      expect(
        TaskRecurrence.currentStreak(
          [
            DateTime(2026, 9, 5),
            DateTime(2026, 8, 10),
            DateTime(2026, 7, 20),
          ],
          TaskRecurrence.monthly,
          now,
        ),
        3,
      );
    });

    test('monthly breaks on a skipped month', () {
      final now = DateTime(2026, 9, 20, 12);
      expect(
        TaskRecurrence.currentStreak(
          [DateTime(2026, 9, 5), DateTime(2026, 7, 10)],
          TaskRecurrence.monthly,
          now,
        ),
        1,
      );
    });

    test('monthly tolerates the current month still being open', () {
      // Nothing done yet this month; last month and the one before count.
      final now = DateTime(2026, 9, 2, 8);
      expect(
        TaskRecurrence.currentStreak(
          [DateTime(2026, 8, 31), DateTime(2026, 7, 1)],
          TaskRecurrence.monthly,
          now,
        ),
        2,
      );
    });

    test('every-N-days counts windows of N days', () {
      final now = DateTime(2026, 9, 9, 12);
      expect(
        TaskRecurrence.currentStreak(
          [
            DateTime(2026, 9, 9),
            DateTime(2026, 9, 6),
            DateTime(2026, 9, 3),
          ],
          TaskRecurrence.encodeEveryN(3),
          now,
        ),
        3,
      );
    });

    test('every-N-days breaks when a whole window is skipped', () {
      final now = DateTime(2026, 9, 9, 12);
      expect(
        TaskRecurrence.currentStreak(
          [DateTime(2026, 9, 9), DateTime(2026, 9, 3)],
          TaskRecurrence.encodeEveryN(3),
          now,
        ),
        1,
      );
    });
  });

  group('isTaskArchived', () {
    TaskModel task({bool done = true, DateTime? at}) => TaskModel(
          id: 't',
          title: 't',
          isCompleted: done,
          completedAt: at,
          createdAt: DateTime(2026),
        );

    test('pending tasks never archive', () {
      expect(isTaskArchived(task(done: false)), isFalse);
    });

    test('recently completed tasks stay visible', () {
      final now = DateTime.now();
      expect(
          isTaskArchived(task(
              at: now
                  .subtract(const Duration(days: taskArchiveThresholdDays)))),
          isFalse);
    });

    test('tasks completed over a month ago archive', () {
      final now = DateTime.now();
      expect(
          isTaskArchived(task(
              at: now.subtract(
                  const Duration(days: taskArchiveThresholdDays + 1)))),
          isTrue);
    });
  });
}
