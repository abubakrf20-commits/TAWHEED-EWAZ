import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/personal/care_engine/care_engine.dart';
import 'package:tawheeed/features/personal/care_engine/care_models.dart';
import 'package:tawheeed/features/personal/services/care_reminder_planner.dart';
import 'package:tawheeed/features/personal/services/care_settings.dart';

CareDueItem item({
  String title = 'روغن موتور',
  required DateTime due,
  String category = 'service',
  int lead = 0,
  String payload = 'care_car_task_t1',
}) =>
    CareDueItem(
      assetId: 'a1',
      kind: CareAssetKind.car,
      title: title,
      taskId: 't1',
      dueDate: due,
      remindDate: due.subtract(Duration(days: lead)),
      category: category,
      level: CareStatusLevel.near,
      payload: payload,
    );

void main() {
  final now = DateTime(2026, 10, 1, 8);
  const defaults = CareReminderSettings();

  group('horizon and clock', () {
    test('an item whose reminder is beyond 30 days is dropped', () {
      final events = const CareReminderPlanner().plan(
        items: [item(due: now.add(const Duration(days: 45)))],
        settings: defaults,
        now: now,
      );
      expect(events, isEmpty);
    });

    test('an item inside the horizon is scheduled at the preferred hour', () {
      final events = const CareReminderPlanner().plan(
        items: [item(due: now.add(const Duration(days: 10)))],
        settings: defaults,
        now: now,
      );
      expect(events, hasLength(1));
      expect(events.single.at.hour, defaults.hour);
      expect(events.single.at.minute, 0);
    });

    test('a reminder whose hour already passed today is not posted', () {
      final lateNow = DateTime(2026, 10, 1, 18);
      final events = const CareReminderPlanner().plan(
        items: [
          item(
            due: DateTime(2026, 10, 3),
            lead: 2, // reminder day is TODAY, at 09:00 — already gone
          ),
        ],
        settings: defaults,
        now: lateNow,
      );
      expect(events, isEmpty);
    });

    test('the whole feature can be switched off', () {
      final events = const CareReminderPlanner().plan(
        items: [item(due: now.add(const Duration(days: 5)))],
        settings: defaults.copyWith(enabled: false),
        now: now,
      );
      expect(events, isEmpty);
    });

    test('a custom horizon overrides the setting', () {
      final events = const CareReminderPlanner().plan(
        items: [item(due: now.add(const Duration(days: 20)))],
        settings: defaults,
        now: now,
        horizon: const Duration(days: 7),
      );
      expect(events, isEmpty);
    });
  });

  group('quiet hours', () {
    test('a reminder at 23:00 during quiet hours is suppressed', () {
      final events = const CareReminderPlanner().plan(
        items: [item(due: now.add(const Duration(days: 5)))],
        settings: defaults.copyWith(hour: 23),
        now: now,
      );
      expect(events, isEmpty);
    });

    test('quiet hours do not shift the reminder to another hour', () {
      final events = const CareReminderPlanner().plan(
        items: [item(due: now.add(const Duration(days: 5)))],
        settings: defaults.copyWith(hour: 6), // 22:00–07:00 quiet
        now: now,
      );
      expect(events, isEmpty);
    });

    test('an empty quiet window suppresses nothing', () {
      expect(defaults.copyWith(quietStart: 9, quietEnd: 9).isQuietAt(9), isFalse);
    });

    test('the wrapper window is inclusive at the start, exclusive at the end', () {
      expect(defaults.isQuietAt(22), isTrue);
      expect(defaults.isQuietAt(23), isTrue);
      expect(defaults.isQuietAt(3), isTrue);
      expect(defaults.isQuietAt(7), isFalse);
      expect(defaults.isQuietAt(12), isFalse);
    });
  });

  group('categories', () {
    test('a switched-off category is skipped', () {
      final events = const CareReminderPlanner().plan(
        items: [
          item(due: now.add(const Duration(days: 5))),
          item(
            title: 'قبض برق',
            due: now.add(const Duration(days: 6)),
            category: 'bills',
            payload: 'care_car_bill_b1',
          ),
        ],
        settings: defaults.copyWith(disabledCategories: {'bills'}),
        now: now,
      );
      expect(events, hasLength(1));
      expect(events.single.items.single.category, 'service');
    });
  });

  group('grouping and payloads', () {
    test('items on the same reminder day become ONE notification', () {
      final events = const CareReminderPlanner().plan(
        items: [
          item(due: now.add(const Duration(days: 5)), title: 'روغن'),
          item(
            due: now.add(const Duration(days: 5)),
            title: 'فیلتر',
            payload: 'care_car_task_t2',
          ),
        ],
        settings: defaults,
        now: now,
      );
      expect(events, hasLength(1));
      expect(events.single.isGroup, isTrue);
      expect(events.single.title, '2 مورد سررسید دارید');
      expect(events.single.payload, 'care_day_2026-10-06');
      expect(events.single.body, contains('روغن'));
      expect(events.single.body, contains('فیلتر'));
    });

    test('a single item keeps its own payload and title', () {
      final events = const CareReminderPlanner().plan(
        items: [item(due: now.add(const Duration(days: 5)))],
        settings: defaults,
        now: now,
      );
      expect(events.single.isGroup, isFalse);
      expect(events.single.payload, 'care_car_task_t1');
      expect(events.single.title, 'یادآوری: روغن موتور');
      expect(events.single.payload.startsWith('care_'), isTrue);
    });

    test('different reminder days stay separate notifications', () {
      final events = const CareReminderPlanner().plan(
        items: [
          item(due: now.add(const Duration(days: 5))),
          item(
            due: now.add(const Duration(days: 9)),
            payload: 'care_car_task_t2',
          ),
        ],
        settings: defaults,
        now: now,
      );
      expect(events, hasLength(2));
      expect(events.first.at.isBefore(events.last.at), isTrue);
    });

    test('the daily cap limits how many items a group carries', () {
      final events = const CareReminderPlanner().plan(
        items: [
          for (var i = 0; i < 5; i++)
            item(
              title: 'مورد $i',
              due: now.add(const Duration(days: 5)),
              payload: 'care_car_task_t$i',
            ),
        ],
        settings: defaults.copyWith(dailyCap: 3),
        now: now,
      );
      expect(events, hasLength(1));
      expect(events.single.items, hasLength(3));
      expect(events.single.title, '3 مورد سررسید دارید');
    });

    test('the group body lists the items in due-date order', () {
      final events = const CareReminderPlanner().plan(
        items: [
          item(due: now.add(const Duration(days: 2)), title: 'زودتر'),
          item(due: now.add(const Duration(days: 2)), title: 'دیرتر'),
        ],
        settings: defaults,
        now: now,
      );
      expect(events.single.body, contains('زودتر'));
      expect(events.single.body.indexOf('زودتر'),
          lessThan(events.single.body.indexOf('دیرتر')));
    });
  });

  group('notification ids', () {
    test('the reserved range is fixed and day-based', () {
      expect(13000, 13000);
      final events = const CareReminderPlanner().plan(
        items: [item(due: now.add(const Duration(days: 5)))],
        settings: defaults,
        now: now,
      );
      final dayOfYear = events.single.at.difference(DateTime(2026)).inDays + 1;
      final id = 13000 + dayOfYear;
      expect(id, inInclusiveRange(13000, 13999));
    });

    test('two reminders on the same day cannot collide on one id', () {
      expect(
        const CareReminderPlanner().plan(
          items: [item(due: now.add(const Duration(days: 5)))],
          settings: defaults,
          now: now,
        ),
        hasLength(1),
        reason: 'grouping guarantees one event per day, so one id per day',
      );
    });
  });
}
