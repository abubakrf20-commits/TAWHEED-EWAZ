import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tasks/domain/task_week_stats.dart';

void main() {
  group('taskWeekIndex / week start', () {
    test('the week always starts on Saturday', () {
      for (final day in [
        DateTime(2026, 9, 22),
        DateTime(2026, 9, 26),
        DateTime(2026, 9, 27),
        DateTime(2027),
      ]) {
        final start = taskWeekStart(day);
        expect(taskWeekIndex(start), 0);
        expect(taskWeekdayNameFa(taskWeekIndex(start)), 'شنبه');
        // Same week, never after the day itself.
        expect(start.isAfter(day), isFalse);
        expect(day.difference(start).inDays, lessThan(7));
      }
    });

    test('any two days of one week share the same start', () {
      final first = DateTime(2026, 9, 22, 23, 59);
      final start = taskWeekStart(first);
      expect(taskWeekStart(start), start);
      expect(
          taskWeekStart(start.add(const Duration(days: 6, hours: 5))), start);
      expect(taskWeekStart(start.add(const Duration(days: 7))),
          start.add(const Duration(days: 7)));
    });

    test('labels cover the whole week', () {
      expect(taskWeekdayShortFa, hasLength(7));
      expect(taskWeekdayNameFa(6), 'جمعه');
    });
  });

  group('weeklyCompletionCounts', () {
    test('buckets by weekday and ignores other weeks', () {
      final now = DateTime(2026, 9, 22, 15, 30);
      final start = taskWeekStart(now);
      final counts = weeklyCompletionCounts([
        start, // شنبه
        start.add(const Duration(days: 3)),
        start.add(const Duration(days: 3, hours: 4)),
        start.subtract(const Duration(days: 1)), // last week → ignored
        start.add(const Duration(days: 7)), // next week → ignored
      ], now);

      expect(counts[0], 1);
      expect(counts[3], 2);
      expect(counts.fold<int>(0, (s, c) => s + c), 3);
    });

    test('an empty history yields seven zeroes', () {
      expect(weeklyCompletionCounts(const [], DateTime(2026, 9, 22)),
          List<int>.filled(7, 0));
    });
  });
}
