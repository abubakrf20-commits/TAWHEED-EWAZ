import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/services/notification_service.dart';

/// Source of the declaring library: the catch-up lives in a `part`, so this is
/// the only import that can reach it (and it re-exports `notification_ids.dart`).
String readSource(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');

String stripComments(String source) => source.split('\n').map((line) {
      final cut = line.indexOf('//');
      return cut == -1 ? line : line.substring(0, cut);
    }).join('\n');

String sliceBetween(String source, String start, String end) {
  final from = source.indexOf(start);
  expect(from, isNot(-1), reason: 'missing start marker: $start');
  final to = source.indexOf(end, from);
  expect(to, isNot(-1), reason: 'missing end marker: $end');
  return source.substring(from, to);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('reminderWasMissed', () {
    // 2026-10-30 is a Friday; the weekday only matters to the callers, the
    // predicate itself works on the day's own occurrence.
    final day = DateTime(2026, 10, 30, 9, 30);
    bool missedAt(DateTime lastRun, {int hour = 7, int minute = 0}) =>
        reminderWasMissed(
            now: day, lastRun: lastRun, hour: hour, minute: minute);

    test('a moment that passed with no run in its window is missed', () {
      // Fire 07:00. Armed only by a run in [29th 07:00, 30th 07:00); the last
      // run is two days old, so nothing ever armed it.
      expect(missedAt(DateTime(2026, 10, 28, 21)), isTrue);
    });

    test('a run inside the 24 h before the fire time armed it', () {
      expect(missedAt(DateTime(2026, 10, 29, 20)), isFalse);
    });

    test('a run after the fire time today is not a missed reminder', () {
      expect(missedAt(DateTime(2026, 10, 30, 8)), isFalse);
    });

    test('exactly 24 h before the fire time still counts as armed', () {
      // Boundary: `isBefore` is false at equality, so this is the earliest
      // arm and must not be reported.
      expect(missedAt(DateTime(2026, 10, 29, 7)), isFalse);
      expect(missedAt(DateTime(2026, 10, 29, 6, 59)), isTrue);
    });

    test('a fire time still in the future is never reported', () {
      expect(missedAt(DateTime(2026, 10, 20), hour: 23), isFalse);
    });

    test("the fire time is today's occurrence, not tomorrow's", () {
      // A rolling helper (_nextInstanceOfTime & co.) would move 07:00 to
      // tomorrow once it has passed, and the reminder would never be missed.
      expect(missedAt(DateTime(2026, 10)), isTrue);
      // …and 23:59 today, which the same helper pushes a day out, is also
      // today's occurrence: it has not passed at 09:30 and cannot be missed.
      expect(missedAt(DateTime(2026, 10), hour: 23, minute: 59), isFalse);
    });
  });

  group('catch-up wiring', () {
    late String daily;
    late String lib;
    late String catchUp;

    setUpAll(() {
      final source = stripComments(
          readSource('lib/shared/services/notification_daily_reminders.dart'));
      daily = source;
      lib = stripComments(
          readSource('lib/shared/services/notification_service.dart'));
      catchUp = sliceBetween(source, 'Future<void> catchUpMissedReminders({',
          'bool reminderWasMissed(');
    });

    test('the daily sync awaits the catch-up', () {
      final sync = sliceBetween(
          daily,
          'Future<void> scheduleDailyRemindersFromSettings(',
          'Future<void> cancelAllDailyReminders(');
      expect(sync.contains('await catchUpMissedReminders(settings: settings);'),
          isTrue);
    });

    test('the run is stamped before the first-run guard returns', () {
      final stamp =
          catchUp.indexOf('catchUpLastRunKey, at.millisecondsSinceEpoch');
      final guard = catchUp.indexOf('if (lastRunMs == null) return;');
      expect(stamp, isNot(-1));
      expect(guard, isNot(-1));
      // Stamping first is what keeps a second sync in the same boot quiet.
      expect(stamp, lessThan(guard));
    });

    test('one silent digest, and nothing scheduled', () {
      expect('NotificationIds.'.allMatches(catchUp).length, 1);
      expect(catchUp.contains('NotificationIds.missedRemindersDigest'), isTrue);
      expect(catchUp.contains("soundName: 'silent'"), isTrue);
      expect(catchUp.contains('showLocalNotification('), isTrue);
      // A scheduling API would roll the past time to tomorrow; the digest is
      // shown immediately instead.
      expect(catchUp.contains('zonedSchedule'), isFalse);
      expect(catchUp.contains('_scheduleNotification'), isFalse);
      expect(catchUp.contains('applyReminderOps'), isFalse);
    });

    test('no rolling helper supplies the fire time', () {
      expect(catchUp.contains('_nextInstanceOfTime'), isFalse);
      expect(catchUp.contains('_nextWeekdayAt'), isFalse);
      expect(catchUp.contains('_nextFridayAt'), isFalse);
    });

    test('the predicate stays top-level so it needs no service instance', () {
      final lines = daily.split('\n');
      final index =
          lines.indexWhere((l) => l.startsWith('bool reminderWasMissed('));
      expect(index, isNot(-1));
      // Column 0 == outside the mixin, so importing the library cannot open
      // any channel just to reach it.
      // The mixin closes right above it: the doc block between them blanks out
      // under comment stripping, so the previous non-blank line is that brace.
      var above = index - 1;
      while (above >= 0 && lines[above].trim().isEmpty) {
        above--;
      }
      expect(above, isNot(-1));
      expect(lines[above].trim(), '}');
    });

    test('the ledger key and the digest id exist exactly once', () {
      expect(
          lib.contains('static const String catchUpLastRunKey = '
              "'notif_catchup_last_run';"),
          isTrue);
      expect(lib.contains('static const int missedRemindersDigest = 432;'),
          isFalse,
          reason: 'the id belongs to notification_ids.dart, not the service');
      final ids = stripComments(
          readSource('lib/shared/services/notification_ids.dart'));
      expect(
          'static const int missedRemindersDigest'.allMatches(ids).length, 1);
      expect(ids.contains('static const int missedRemindersDigest = 432;'),
          isTrue);
    });
  });
}
