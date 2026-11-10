import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/goals/domain/goal_streak.dart';

/// A fixed "today" so the arithmetic does not depend on when the suite runs.
final today = DateTime(2026, 9, 10);

String d(int day) => '2026-09-${day.toString().padLeft(2, '0')}';

void main() {
  group('goalStreakFrom', () {
    test('no days is no streak', () {
      expect(goalStreakFrom(const [], today: today), GoalStreak.empty);
    });

    test('a single active day is a streak of one', () {
      final s = goalStreakFrom([d(10)], today: today);
      expect(s.current, 1);
      expect(s.best, 1);
      expect(s.isActiveToday, isTrue);
    });

    test('counts consecutive days ending today', () {
      final s = goalStreakFrom([d(8), d(9), d(10)], today: today);
      expect(s.current, 3);
      expect(s.isActiveToday, isTrue);
    });

    test('an unlogged today does not break a live streak', () {
      // The decision the doc states: at 8am the day is not over, so a streak
      // that ended yesterday still reads as alive.
      final s = goalStreakFrom([d(8), d(9)], today: today);
      expect(s.current, 2);
      expect(s.isActiveToday, isFalse,
          reason: 'the card must not imply today is already done');
    });

    test('a two-day gap ends the current streak but keeps the best', () {
      final s = goalStreakFrom([d(1), d(2), d(3), d(9)], today: today);
      expect(s.current, 1);
      expect(s.best, 3);
    });

    test('best is the longest run anywhere in the history', () {
      // A five-day run in early September, then nothing until the day before
      // today. The current streak is the short one; the best is the old run.
      final s = goalStreakFrom(
        [d(1), d(2), d(3), d(4), d(5), d(9)],
        today: today,
      );
      expect(s.current, 1);
      expect(s.best, 5);
    });

    test('a run ending long ago leaves no current streak', () {
      final s = goalStreakFrom([d(1), d(2)], today: today);
      expect(s.current, 0);
      expect(s.best, 2);
    });

    test('best is never below the current streak', () {
      // The current run is by definition a run, so it must be a candidate.
      final s = goalStreakFrom([d(6), d(7), d(8), d(9), d(10)], today: today);
      expect(s.best, s.current);
    });

    test('duplicate and unsorted input is handled', () {
      final s = goalStreakFrom(
        [d(10), d(8), d(9), d(9), d(10)],
        today: today,
      );
      expect(s.current, 3);
    });

    test('unparseable keys are ignored, not thrown on', () {
      // A corrupt row must not take the whole list screen down, and it cannot
      // legitimately extend a streak.
      final s = goalStreakFrom(
        [d(9), d(10), 'not-a-date', '', '2026-13-45'],
        today: today,
      );
      expect(s.current, 2);
    });

    test('days in the future are not counted', () {
      // A future date cannot have happened yet; counting it would let a
      // streak be extended before it is earned.
      final s = goalStreakFrom([d(9), d(10), d(11)], today: today);
      expect(s.current, 2);
    });

    test('crosses a month boundary', () {
      final s = goalStreakFrom(
        ['2026-08-30', '2026-08-31', '2026-09-01'],
        today: DateTime(2026, 9),
      );
      expect(s.current, 3);
    });

    test('crosses a leap day', () {
      final s = goalStreakFrom(
        ['2028-02-28', '2028-02-29', '2028-03-01'],
        today: DateTime(2028, 3),
      );
      expect(s.current, 3);
    });
  });

  group('GoalStreak', () {
    test('isActiveToday is false when the streak hangs off yesterday', () {
      // Defaulted, not stated: the flag being off is what this asserts.
      const s = GoalStreak(current: 5, best: 9);
      expect(s.hasStreak, isTrue);
      expect(s.isActiveToday, isFalse);
    });

    test('isActiveToday is independent of hasStreak', () {
      // A live streak and a stale one are both "a streak"; only the flag
      // separates them, so it cannot be derived from `current`.
      expect(
          const GoalStreak(current: 5, best: 9, isActiveToday: true)
              .isActiveToday,
          isTrue);
      expect(
          const GoalStreak(current: 0, best: 9, isActiveToday: true).hasStreak,
          isFalse);
    });

    test('value equality', () {
      expect(
        const GoalStreak(current: 2, best: 5, isActiveToday: true),
        const GoalStreak(current: 2, best: 5, isActiveToday: true),
      );
      // A streak with the same numbers but a different "anchored on" reads
      // differently to the user, so it is a different value.
      expect(
        const GoalStreak(current: 2, best: 5, isActiveToday: true),
        isNot(const GoalStreak(current: 2, best: 5)),
      );
    });
  });
}
