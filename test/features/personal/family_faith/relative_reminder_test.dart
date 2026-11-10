import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/worship/silat_al_rahim/domain/silat_al_rahim_models.dart';
import 'package:tawheeed/features/personal/family_faith/relatives/relative_reminder_planner.dart';

Relative _relative({
  required String id,
  String name = 'مادر',
  DateTime? lastContactAt,
  DateTime? snoozeUntil,
  int intervalDays = 7,
  bool muted = false,
  bool archived = false,
}) =>
    Relative(
      id: id,
      name: name,
      relation: RelationKind.mother,
      createdAt: DateTime(2026, 1, 1),
      lastContactAt: lastContactAt,
      snoozeUntil: snoozeUntil,
      intervalDays: intervalDays,
      muted: muted,
      archived: archived,
    );

List<FamilyReminderEvent> _plan(
  List<Relative> relatives,
  DateTime now, {
  FamilyReminderSettings settings = const FamilyReminderSettings(),
  int horizonDays = 30,
}) =>
    const RelativeReminderPlanner()
        .plan(relatives: relatives, settings: settings, now: now, horizonDays: horizonDays);

void main() {
  group('cadence', () {
    test('one notice on the due day at the chosen hour', () {
      final events = _plan(
        [_relative(id: 'r1', lastContactAt: DateTime(2026, 9, 1))],
        DateTime(2026, 9, 5, 8),
      );
      expect(events, hasLength(1));
      expect(events.single.at, DateTime(2026, 9, 8, 9));
      expect(events.single.payload, 'family_relative_r1');
      expect(events.single.title, contains('مادر'));
    });

    test('overdue: weekly nudges only, and never more than maxNudges',
        () {
      // Due 8 Sep; now 10 Sep. Nudges at +7 (15 Sep) and +14 (22 Sep) only —
      // the due-day notice counts as the first of the three.
      final events = _plan(
        [_relative(id: 'r1', lastContactAt: DateTime(2026, 9, 1))],
        DateTime(2026, 9, 10, 8),
      );
      expect(events.map((e) => e.at), [
        DateTime(2026, 9, 15, 9),
        DateTime(2026, 9, 22, 9),
      ]);
      expect(events.every((e) => e.payload == 'family_relative_r1'), isTrue);
    });

    test('a long overdue relative stops nudging after the cap', () {
      final events = _plan(
        [_relative(id: 'r1', lastContactAt: DateTime(2026, 1, 1))],
        DateTime(2026, 9, 10, 8),
        horizonDays: 60,
      );
      expect(events.length, lessThanOrEqualTo(2));
    });

    test('weekly nudges can be turned off', () {
      final events = _plan(
        [_relative(id: 'r1', lastContactAt: DateTime(2026, 9, 1))],
        DateTime(2026, 9, 10, 8),
        settings: const FamilyReminderSettings(weeklyNudge: false),
      );
      expect(events, isEmpty);
    });

    test('muted and archived relatives are skipped', () {
      final events = _plan(
        [
          _relative(id: 'muted', muted: true),
          _relative(id: 'archived', archived: true),
        ],
        DateTime(2026, 2, 1, 8),
      );
      expect(events, isEmpty);
    });

    test('a snoozed relative is not nudged before the snooze ends', () {
      final events = _plan(
        [
          _relative(
            id: 'r1',
            lastContactAt: DateTime(2026, 9, 1),
            snoozeUntil: DateTime(2026, 9, 20),
          ),
        ],
        DateTime(2026, 9, 10, 8),
        horizonDays: 20,
      );
      expect(events.single.at, DateTime(2026, 9, 20, 9));
    });

    test('the plan is disabled wholesale when reminders are off', () {
      final events = _plan(
        [_relative(id: 'r1')],
        DateTime(2026, 1, 2, 8),
        settings: const FamilyReminderSettings(enabled: false),
      );
      expect(events, isEmpty);
    });
  });

  group('quiet hours', () {
    test('a quiet delivery hour moves to the end of the window', () {
      final events = _plan(
        [_relative(id: 'r1', lastContactAt: DateTime(2026, 9, 1))],
        DateTime(2026, 9, 5, 6),
        settings: const FamilyReminderSettings(hour: 23, quietStart: 22, quietEnd: 7),
      );
      expect(events.single.at.hour, 7);
    });

    test('a normal hour is untouched', () {
      final events = _plan(
        [_relative(id: 'r1', lastContactAt: DateTime(2026, 9, 1))],
        DateTime(2026, 9, 5, 6),
        settings: const FamilyReminderSettings(hour: 11),
      );
      expect(events.single.at.hour, 11);
    });
  });

  group('grouping', () {
    test('two relatives due the same day become ONE summary', () {
      final events = _plan(
        [
          _relative(id: 'a', name: 'مادر', lastContactAt: DateTime(2026, 9, 1)),
          _relative(id: 'b', name: 'عمو', lastContactAt: DateTime(2026, 9, 1)),
        ],
        DateTime(2026, 9, 5, 8),
      );
      expect(events, hasLength(1));
      expect(events.single.isGroup, isTrue);
      expect(events.single.title, contains('2 تماس'));
      expect(events.single.payload, 'family_relative_day_2026-09-08');
    });

    test('no birthday notice is planned any more (2026-11-07 decision)', () {
      // The setting itself is gone, so this documents the absence: a relative
      // with an old birthday-shaped cycle produces nothing but call notices.
      final events = _plan(
        [
          _relative(
            id: 'r1',
            lastContactAt: DateTime(2026, 9, 10),
            intervalDays: 365,
          ),
        ],
        DateTime(2026, 9, 10, 8),
      );
      expect(events.every((e) => !e.title.contains('تولد')), isTrue);
    });

    test('an event whose hour already passed today is dropped', () {
      final events = _plan(
        [_relative(id: 'r1', lastContactAt: DateTime(2026, 9, 8))],
        DateTime(2026, 9, 15, 10),
      );
      // Due 15 Sep at 09:00, but it is 10:00 already.
      expect(events.where((e) => e.at == DateTime(2026, 9, 15, 9)), isEmpty);
    });

    test('nothing is planned beyond the horizon', () {
      final events = _plan(
        [_relative(id: 'r1', lastContactAt: DateTime(2026, 9, 1))],
        DateTime(2026, 9, 5, 8),
        horizonDays: 1,
      );
      expect(events, isEmpty);
    });
  });
}
