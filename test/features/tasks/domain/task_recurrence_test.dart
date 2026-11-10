import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/tasks/domain/task_recurrence.dart';

void main() {
  group('TaskRecurrence.nextDue', () {
    test('daily rolls one day from the instance due date', () {
      final due = DateTime(2026, 9, 5);
      final next = TaskRecurrence.nextDue(
        type: 'daily',
        dueDate: due,
        completedAt: DateTime(2026, 9, 5, 21),
      );
      expect(next, DateTime(2026, 9, 6));
    });

    test('weekly keeps the same weekday as the instance due date', () {
      // Monday, 2026-09-07
      final due = DateTime(2026, 9, 7);
      final next = TaskRecurrence.nextDue(
        type: 'weekly',
        dueDate: due,
        completedAt: DateTime(2026, 9, 9), // Wednesday — checked late
      );
      expect(next, DateTime(2026, 9, 14)); // still the following Monday
    });

    test('skips whole missed periods when completed far past the due date', () {
      final due = DateTime(2026, 8, 3); // a Monday
      final next = TaskRecurrence.nextDue(
        type: 'weekly',
        dueDate: due,
        completedAt: DateTime(2026, 8, 28), // ~4 weeks overdue
      );
      expect(next, DateTime(2026, 8, 31)); // first Monday after completion
    });

    test('daily skips ahead when the task was completed late', () {
      final due = DateTime(2026, 9);
      final next = TaskRecurrence.nextDue(
        type: 'daily',
        dueDate: due,
        completedAt: DateTime(2026, 9, 3),
      );
      expect(next, DateTime(2026, 9, 4));
    });

    test('anchors on the completion day when the instance has no due date', () {
      final next = TaskRecurrence.nextDue(
        type: 'daily',
        dueDate: null,
        completedAt: DateTime(2026, 9, 5, 12),
      );
      expect(next, DateTime(2026, 9, 6));
    });

    test('returns null for unsupported patterns', () {
      expect(
        TaskRecurrence.nextDue(
          type: 'sometimes',
          dueDate: DateTime(2026, 9, 5),
          completedAt: DateTime(2026, 9, 5),
        ),
        isNull,
      );
    });
  });

  group('TaskRecurrence labels', () {
    test('daily/weekly/monthly have Persian labels, unknown patterns do not',
        () {
      expect(TaskRecurrence.label('daily'), 'روزانه');
      expect(TaskRecurrence.label('weekly'), 'هفتگی');
      expect(TaskRecurrence.label('monthly'), 'ماهانه');
      expect(TaskRecurrence.label('sometimes'), isNull);
    });

    test('isSupported accepts daily/weekly/monthly/every-N, not arbitrary', () {
      expect(TaskRecurrence.isSupported('daily'), isTrue);
      expect(TaskRecurrence.isSupported('weekly'), isTrue);
      expect(TaskRecurrence.isSupported('monthly'), isTrue);
      expect(TaskRecurrence.isSupported('every_n_days:4'), isTrue);
      expect(TaskRecurrence.isSupported('sometimes'), isFalse);
      expect(TaskRecurrence.isSupported(null), isFalse);
    });
  });
}
