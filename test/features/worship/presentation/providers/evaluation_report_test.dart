import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/worship/presentation/providers/evaluation_report.dart';

void main() {
  // Fixed timestamp so the Jalali header is deterministic in every timezone.
  // 2026-07-21 == 1405-04-30 (Tir).
  final anchor = DateTime(2026, 7, 21, 12);

  group('buildMonthlyReport', () {
    test('renders the summary header with the Jalali month label', () {
      final report = buildMonthlyReport(
        180,
        performanceRating: 'خوب',
        dailyAverage: 12.5,
        currentStreak: 4,
        bestStreak: 9,
        worshipDone: 2,
        worshipTotal: 3,
        monthlyScores: [30, 30, 0],
        totalCompleted: 120,
        totalSkipped: 6,
        now: anchor,
      );
      expect(report, contains('گزارش ماه تیر 1405'));
      expect(report, contains('امتیاز ماه: 180'));
      expect(report, contains('ارزیابی: خوب'));
      expect(report, contains('میانگین روزانه: 12.5'));
      expect(report, contains('رکورد زنجیره: 4 روز'));
      expect(report, contains('بهترین زنجیره: 9 روز'));
    });

    test('counts only positive days in the month summary section', () {
      final report = buildMonthlyReport(
        60,
        performanceRating: 'قابل قبول',
        dailyAverage: 2.0,
        currentStreak: 0,
        bestStreak: 2,
        worshipDone: 0,
        worshipTotal: 3,
        monthlyScores: [30, 0, 30, -5],
        totalCompleted: 2,
        totalSkipped: 1,
        now: anchor,
      );
      expect(report, contains('روز 1: 30 امتیاز'));
      expect(report, contains('روز 3: 30 امتیاز'));
      expect(report, isNot(contains('روز 2:')));
      expect(report, isNot(contains('روز 4:')));
    });

    test('null state fields render as zeros without throwing', () {
      final report = buildMonthlyReport(
        null,
        performanceRating: 'نیاز به تلاش بیشتر',
        dailyAverage: 0,
        currentStreak: 0,
        bestStreak: 0,
        worshipDone: 0,
        worshipTotal: 0,
        monthlyScores: const [],
        totalCompleted: 0,
        totalSkipped: 0,
        now: anchor,
      );
      expect(report, contains('امتیاز ماه: 0'));
      expect(report, contains('انجام شده امروز: 0/0'));
      expect(report, contains('مجموع اذکار انجام شده: 0'));
    });

    test('worship progress keeps the done/total shape', () {
      final report = buildMonthlyReport(
        10,
        performanceRating: 'خوب',
        dailyAverage: 1.0,
        currentStreak: 1,
        bestStreak: 1,
        worshipDone: 2,
        worshipTotal: 5,
        monthlyScores: const [10],
        totalCompleted: 1,
        totalSkipped: 1,
        now: anchor,
      );
      expect(report, contains('انجام شده امروز: 2/5'));
    });
  });
}
