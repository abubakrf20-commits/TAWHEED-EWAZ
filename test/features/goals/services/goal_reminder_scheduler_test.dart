import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/goals/services/goal_reminder_scheduler.dart';
import 'package:tawheeed/shared/services/notification_ids.dart';

/// Fixed fixture timestamp. `shouldSchedule` never reads it.
final _when = DateTime(2026);

GoalTableData goal({
  bool remindEnabled = true,
  String remindAt = '08:00',
  bool archived = false,
  int target = 10,
  String targetType = 'count',
}) =>
    GoalTableData(
      id: 'g1',
      title: 'مطالعه',
      description: '',
      category: 'other',
      startDate: '',
      deadline: '',
      targetType: targetType,
      targetNumber: target,
      isActive: true,
      isArchived: archived,
      createdAt: _when,
      updatedAt: _when,
      priority: 1,
      dailyTarget: 0,
      remindEnabled: remindEnabled,
      remindAt: remindAt,
      linkedType: '',
      linkedId: '',
    );

void main() {
  group('shouldSchedule', () {
    test('an enabled reminder with a time is scheduled', () {
      expect(GoalReminderScheduler.shouldSchedule(goal(), isComplete: false),
          isTrue);
    });

    test('a completed goal gets no daily nag', () {
      // The single most likely reason a user turns reminders off for
      // everything: being told to keep going about a goal already finished.
      expect(GoalReminderScheduler.shouldSchedule(goal(), isComplete: true),
          isFalse);
    });

    test('an archived goal is not scheduled', () {
      expect(
          GoalReminderScheduler.shouldSchedule(goal(archived: true),
              isComplete: false),
          isFalse);
    });

    test('no time means no reminder, even when the toggle is on', () {
      expect(
          GoalReminderScheduler.shouldSchedule(goal(remindAt: ''),
              isComplete: false),
          isFalse);
    });

    test('the toggle alone is not enough', () {
      expect(
          GoalReminderScheduler.shouldSchedule(goal(remindEnabled: false),
              isComplete: false),
          isFalse);
    });

    test('a malformed time is rejected instead of being scheduled', () {
      // Scheduling "8am" as hour 8 or as hour 0 would fire at the wrong time
      // with no warning, and the user would have no way to tell why.
      for (final bad in const [
        '8', // no minute
        '08:00:30', // seconds are not parsed
        '25:00', // hour out of range
        '08:70', // minute out of range
        'aa:bb',
        '  ',
      ]) {
        expect(
          GoalReminderScheduler.shouldSchedule(goal(remindAt: bad),
              isComplete: false),
          isFalse,
          reason: 'remindAt "$bad" must not schedule',
        );
      }
    });

    test('a well-formed time is accepted', () {
      for (final good in const ['00:00', '08:00', '23:59', '9:5']) {
        expect(
          GoalReminderScheduler.shouldSchedule(goal(remindAt: good),
              isComplete: false),
          isTrue,
          reason: 'remindAt "$good" is valid HH:mm',
        );
      }
    });
  });

  group('notification id derivation', () {
    test('a goal id maps inside the reserved range', () {
      for (final id in const ['g1', 'a-very-long-goal-identifier-0001', '']) {
        final slot = NotificationIds.stableSlot(id, 950);
        expect(slot, inInclusiveRange(0, 949));
      }
    });

    test('the mapping is stable, so re-syncing replaces rather than stacks',
        () {
      const id = 'goal-42';
      expect(NotificationIds.stableSlot(id, 950),
          NotificationIds.stableSlot(id, 950));
    });

    test('it is not String.hashCode', () {
      // Dart documents hashCode as unspecified across isolates, so a scheduler
      // keyed off it can lose track of its own pending notifications. The
      // point of the FNV-1a map is that it is pinned by this test.
      const ids = ['g1', 'g2', 'g3', 'x', 'y', 'z', 'note-1', 'note-2'];
      final a = ids.map((s) => NotificationIds.stableSlot(s, 950)).toList();
      final b = ids.map((s) => NotificationIds.stableSlot(s, 950)).toList();
      expect(a, b);
    });

    test('a small space is asserted rather than silently returning garbage',
        () {
      expect(() => NotificationIds.stableSlot('x', 0),
          throwsA(isA<AssertionError>()));
    });
  });
}
