import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/tasks/domain/entities/task_model.dart';
import 'package:tawheeed/features/tasks/services/task_reminder_scheduler.dart';

void main() {
  TaskModel task({
    bool done = false,
    bool remind = true,
    DateTime? due,
    String? at,
  }) =>
      TaskModel(
        id: 't1',
        title: 'task',
        createdAt: DateTime(2026),
        isCompleted: done,
        remindEnabled: remind,
        dueDate: due,
        remindAt: at,
      );

  group('TaskReminderScheduler.shouldSchedule', () {
    test('true only for pending tasks with reminder + due + time', () {
      expect(
          TaskReminderScheduler.shouldSchedule(
              task(due: DateTime(2030), at: '08:00')),
          isTrue);
    });

    test('false when completed', () {
      expect(
          TaskReminderScheduler.shouldSchedule(
              task(done: true, due: DateTime(2030), at: '08:00')),
          isFalse);
    });

    test('false when reminder disabled', () {
      expect(
          TaskReminderScheduler.shouldSchedule(
              task(remind: false, due: DateTime(2030), at: '08:00')),
          isFalse);
    });

    test('false when due date missing', () {
      expect(TaskReminderScheduler.shouldSchedule(task(at: '08:00')), isFalse);
    });

    test('false when reminder time missing', () {
      expect(TaskReminderScheduler.shouldSchedule(task(due: DateTime(2030))),
          isFalse);
    });
  });
}
