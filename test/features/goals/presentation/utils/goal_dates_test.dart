import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/goals/presentation/utils/goal_dates.dart';
import 'package:tawheeed/features/goals/presentation/utils/goal_ids.dart';

void main() {
  group('goalIsoLooksValid', () {
    test('accepts a zero-padded ISO day', () {
      expect(goalIsoLooksValid('2026-09-01'), isTrue);
      expect(goalIsoLooksValid('2026-12-31'), isTrue);
    });

    test('treats an empty value as "unset", not as malformed', () {
      // A goal with no start date and no deadline stores ''. Rejecting it
      // would make every such goal unsaveable.
      expect(goalIsoLooksValid(''), isTrue);
    });

    test('rejects an unpadded day', () {
      // This is the subtle one. `2026-9-1` parses fine, so a range check
      // alone would accept it — but `progressOn` compares the key by exact
      // string equality and `progressByDay` sorts the chart lexicographically,
      // so this spelling silently becomes a different day from `2026-09-01`.
      expect(goalIsoLooksValid('2026-9-1'), isFalse);
      expect(goalIsoLooksValid('2026-09-1'), isFalse);
    });

    test('rejects a day that does not exist', () {
      expect(goalIsoLooksValid('2026-02-31'), isFalse);
      expect(goalIsoLooksValid('2026-13-01'), isFalse);
      expect(goalIsoLooksValid('2026-00-10'), isFalse);
    });

    test('rejects other shapes outright', () {
      expect(goalIsoLooksValid('2026/09/01'), isFalse);
      expect(goalIsoLooksValid('26-09-01'), isFalse);
      expect(goalIsoLooksValid('2026-09-01T00:00'), isFalse);
      expect(goalIsoLooksValid('abc'), isFalse);
    });
  });

  group('goalDaysUntil', () {
    /// ISO key for a day offset from today. Built from the clock so the
    /// assertions cannot drift into the past overnight.
    String isoIn(int days) {
      final d = DateTime.now().add(Duration(days: days));
      return '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    }

    test('counts days forward as positive', () {
      expect(goalDaysUntil(isoIn(10)), 10);
    });

    test('counts days past as negative', () {
      expect(goalDaysUntil(isoIn(-3)), -3);
    });

    test('today is zero', () {
      expect(goalDaysUntil(isoIn(0)), 0);
    });

    test('is null for an unset or unparseable deadline', () {
      expect(goalDaysUntil(''), isNull);
      expect(goalDaysUntil('not-a-date'), isNull);
    });
  });

  group('goalDaysBetween', () {
    test('counts whole days in either direction', () {
      expect(goalDaysBetween(DateTime(2026, 9, 1), DateTime(2026, 9, 11)), 10);
      expect(goalDaysBetween(DateTime(2026, 9, 11), DateTime(2026, 9, 1)), -10);
    });

    test('ignores the time of day', () {
      expect(
        goalDaysBetween(
          DateTime(2026, 9, 1, 23, 59),
          DateTime(2026, 9, 2, 0, 1),
        ),
        1,
      );
    });

    test('a DST-shortened day still counts as one day', () {
      // The defect this guards: `inDays` on a local span truncates a 23-hour
      // day to 0, so a streak spanning the spring-forward night silently lost
      // a day and a "daily" goal showed 0 progress. Both ends are lifted to
      // UTC before subtracting, so every calendar day is exactly one day.
      final springForward = DateTime(2026, 3, 29, 12); // Europe: 23-hour day
      final next = springForward.add(const Duration(days: 1));
      expect(goalDaysBetween(springForward, next), 1);
      expect(goalDaysBetween(springForward, DateTime(2026, 3, 31, 12)), 2);
    });

    test('same day is zero regardless of the hour', () {
      expect(goalDaysBetween(DateTime(2026, 9, 1, 1), DateTime(2026, 9, 1, 22)), 0);
    });
  });

  group('booleanProgressId', () {
    test('is stable for the same goal and day', () {
      // A per-install random id would insert a second row on every toggle
      // instead of replacing the first, and the day's count would climb.
      final a = booleanProgressId('g1', '2026-09-01');
      final b = booleanProgressId('g1', '2026-09-01');
      expect(a, b);
    });

    test('differs per goal and per day', () {
      expect(booleanProgressId('g1', '2026-09-01'),
          isNot(booleanProgressId('g2', '2026-09-01')));
      expect(booleanProgressId('g1', '2026-09-01'),
          isNot(booleanProgressId('g1', '2026-09-02')));
    });
  });

  group('newGoalId', () {
    test('is unique across rapid calls', () {
      // The old id was derived from the millisecond clock, so two goals
      // created in the same millisecond collided and the second one upserted
      // over the first.
      //
      // 500 ids was not enough to catch the follow-on fix of adding
      // `nextInt(999999)`: from a million slots, 500 draws collide about 12%
      // of the time, so this test failed roughly one run in eight rather than
      // every time — a flaky pass is not a guard. 5000 draws against a
      // million slots collide with probability ~1 - e^(-12.5), so the old
      // scheme cannot pass this even once by luck.
      final ids = {for (var i = 0; i < 5000; i++) newGoalId()};
      expect(ids.length, 5000);
    });

    test('progress ids are unique too', () {
      // Progress rows are written through the same insert-on-conflict path, so
      // a collision here loses an entry just as silently as one on the goal.
      final ids = {for (var i = 0; i < 5000; i++) newProgressId()};
      expect(ids.length, 5000);
    });

    test('ids minted in the same millisecond still differ', () {
      // Pins the counter's actual job: the clock alone cannot separate these,
      // so only the per-process counter can.
      final ids = <String>{};
      for (var i = 0; i < 200; i++) {
        ids.add(newGoalId());
        if (ids.length == 200) break;
      }
      expect(ids.length, 200);
    });

    test('is not empty and has no invisible characters', () {
      for (var i = 0; i < 50; i++) {
        final id = newGoalId();
        expect(id, isNotEmpty);
        // A zero-width space or similar would be invisible here and corrupt
        // every future equality comparison on the id.
        expect(id.runes.every((r) => r > 0x20 && r < 0x7F), isTrue,
            reason: 'id "$id" contains an unexpected character');
      }
    });

    test('sorts chronologically as a string', () {
      // The id is documented as creation-time sortable, and the goals list
      // leans on that. The timestamp leads, so a plain string compare has to
      // agree with the order the rows were created in.
      final ids = [for (var i = 0; i < 50; i++) newGoalId()];
      final sorted = [...ids]..sort();
      expect(sorted, orderedEquals(ids));
    });
  });
}
