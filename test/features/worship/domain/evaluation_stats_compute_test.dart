import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/worship/domain/evaluation_stats_compute.dart';

void main() {
  group('EvaluationStatsCompute.performanceRating (Audit 8.17)', () {
    const dailyMax = 100;

    test('current month: thresholds are relative to the ELAPSED days', () {
      // Clock-independent: anchor at today inside the real current month, so
      // the function takes the elapsed-days path by construction.
      final now = DateTime.now();
      final anchor = DateTime(now.year, now.month, now.day);
      final elapsed = now.day;
      // Old formula: 0.5 * 100 * daysInMonth kept the fraction at ~half of
      // the threshold band all month → «نیاز به تلاش بیشتر» for weeks.
      // New formula: 0.5 * 100 * elapsed = 50% of the REACHABLE points.
      final half = (dailyMax * elapsed * 0.5).round();
      expect(
        EvaluationStatsCompute.performanceRating(half, dailyMax, anchor),
        'قابل قبول',
      );
    });

    test('current month: excellent works for a perfect pace, mid-month', () {
      final now = DateTime.now();
      final anchor = DateTime(now.year, now.month, now.day);
      expect(
        EvaluationStatsCompute.performanceRating(
            dailyMax * now.day, dailyMax, anchor),
        'عالی',
      );
    });

    test('browsed past month keeps the whole-month formula', () {
      // A fixed anchor safely in the past: fully scored, whole-month max.
      final pastMonth = DateTime(2026, 6, 20); // June 2026 has 30 days
      expect(
        EvaluationStatsCompute.performanceRating(
            (dailyMax * 30 * 0.9).round(), dailyMax, pastMonth),
        'عالی',
      );
      expect(
        EvaluationStatsCompute.performanceRating(0, dailyMax, pastMonth),
        'نیاز به تلاش بیشتر',
      );
    });

    test('zero daily max never divides by zero', () {
      expect(
        EvaluationStatsCompute.performanceRating(100, 0, DateTime(2026, 7, 16)),
        'نیاز به تلاش بیشتر',
      );
    });
  });

  group('EvaluationStatsCompute score totals', () {
    test('monthlyScoreTotal sums only the anchor month', () {
      final cache = {
        '2026-07-01': 10,
        '2026-07-31': 5,
        '2026-08-01': 99,
        'garbage': 7,
      };
      expect(
        EvaluationStatsCompute.monthlyScoreTotal(cache, DateTime(2026, 7, 15)),
        15,
      );
    });

    test('weeklyScoreTotal sums the trailing 7 days including today', () {
      final cache = {
        '2026-07-09': 1, // 8 days ago → out
        '2026-07-10': 2, // 7 days ago → in
        '2026-07-16': 4, // today → in
        '2026-07-17': 8, // tomorrow → out
      };
      expect(
        EvaluationStatsCompute.weeklyScoreTotal(cache, DateTime(2026, 7, 16)),
        6,
      );
    });
  });
}
