import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/hifz/domain/entities/hifz_lesson_model.dart';
import 'package:tawheeed/features/hifz/domain/entities/hifz_review_model.dart';
import 'package:tawheeed/features/hifz/domain/hifz_report.dart';

HifzLessonModel _lesson(
  String id,
  DateTime date,
  int pages, {
  required int sFrom,
  required int aFrom,
  required int sTo,
  required int aTo,
}) =>
    HifzLessonModel(
      id: id,
      hafizId: 'h1',
      date: date,
      surahFrom: sFrom,
      ayahFrom: aFrom,
      surahTo: sTo,
      ayahTo: aTo,
      pages: pages,
      createdAt: date,
    );

HifzReviewModel _review(
        String id, DateTime date, ReviewType t, ReviewQuality q) =>
    HifzReviewModel(
      id: id,
      hafizId: 'h1',
      date: date,
      type: t,
      surahFrom: 1,
      ayahFrom: 1,
      surahTo: 1,
      ayahTo: 7,
      pages: 1,
      quality: q,
      createdAt: date,
    );

void main() {
  group('buildPeriodReport', () {
    final start = DateTime(2025, 5);
    final end = DateTime(2025, 6);

    test('counts only lessons inside the period and keeps cumulative', () {
      final report = buildPeriodReport(
        lessons: [
          // Pages 1-3 (3 pages), before the period.
          _lesson('l1', DateTime(2025, 4, 30), 3,
              sFrom: 1, aFrom: 1, sTo: 2, aTo: 6),
          // Pages 21-22 (2 pages).
          _lesson('l2', DateTime(2025, 5), 2,
              sFrom: 2, aFrom: 141, sTo: 2, aTo: 142),
          // Page 293 (1 page).
          _lesson('l3', DateTime(2025, 5, 15), 1,
              sFrom: 18, aFrom: 1, sTo: 18, aTo: 1),
          // Pages 50-53 (4 pages), after the period (end is exclusive).
          _lesson('l4', DateTime(2025, 6), 4,
              sFrom: 3, aFrom: 1, sTo: 3, aTo: 25),
        ],
        reviews: const [],
        start: start,
        end: end,
      );
      expect(report.lessonPages, 3);
      expect(report.lessonCount, 2);
      expect(report.cumulativePages, 6); // 3 + 2 + 1
      expect(report.previousCumulativePages, 3);
    });

    test('breaks down review counts and qualities', () {
      final report = buildPeriodReport(
        lessons: const [],
        reviews: [
          _review(
              'r1', DateTime(2025, 5, 2), ReviewType.sabaq, ReviewQuality.weak),
          _review('r2', DateTime(2025, 5, 3), ReviewType.sabaq,
              ReviewQuality.excellent),
          _review('r3', DateTime(2025, 5, 4), ReviewType.sabaq,
              ReviewQuality.excellent),
          _review('r4', DateTime(2025, 5, 5), ReviewType.murajaah,
              ReviewQuality.medium),
          _review('r5', DateTime(2025, 4, 30), ReviewType.sabaq,
              ReviewQuality.excellent), // outside period
        ],
        start: start,
        end: end,
      );
      expect(report.sabaqCount, 3);
      expect(report.murajaahCount, 1);
      expect(report.sabaqQuality.weak, 1);
      expect(report.sabaqQuality.medium, 0);
      expect(report.sabaqQuality.excellent, 2);
      expect(report.murajaahQuality.medium, 1);
      expect(report.murajaahQuality.total, 1);
    });
  });

  group('pagesByDayInMonth', () {
    test('groups distinct pages by day of month', () {
      final byDay = pagesByDayInMonth(
        lessons: [
          // Pages 2-3.
          _lesson('l1', DateTime(2025, 5), 2,
              sFrom: 2, aFrom: 1, sTo: 2, aTo: 6),
          // Exact repeat of l1 on the same day: counted once.
          _lesson('l2', DateTime(2025, 5), 1,
              sFrom: 2, aFrom: 1, sTo: 2, aTo: 6),
          // Page 293: a new page on the same day.
          _lesson('l3', DateTime(2025, 5), 1,
              sFrom: 18, aFrom: 1, sTo: 18, aTo: 1),
          _lesson('l4', DateTime(2025, 5, 15), 1,
              sFrom: 36, aFrom: 1, sTo: 36, aTo: 1),
          // Page 1, outside the month.
          _lesson('l5', DateTime(2025, 4, 30), 9,
              sFrom: 1, aFrom: 1, sTo: 1, aTo: 7),
        ],
        monthStart: DateTime(2025, 5),
        monthEnd: DateTime(2025, 6),
      );
      expect(byDay[1], 3); // pages 2, 3, 293 — repeat counted once
      expect(byDay[15], 1);
      expect(byDay.containsKey(30), isFalse);
    });
  });

  group('buildYearReport', () {
    test('aggregates 12 monthly slices and totals', () {
      final monthStarts = [
        for (var m = 1; m <= 12; m++) DateTime(2025, m),
      ];
      final lessons = [
        // Pages 2-3 (2 pages).
        _lesson('l1', DateTime(2025, 1, 10), 2,
            sFrom: 2, aFrom: 1, sTo: 2, aTo: 6),
        // Page 293 (1 page).
        _lesson('l2', DateTime(2025, 1, 20), 1,
            sFrom: 18, aFrom: 1, sTo: 18, aTo: 1),
        // Pages 50-53 (4 pages).
        _lesson('l3', DateTime(2025, 6, 5), 4,
            sFrom: 3, aFrom: 1, sTo: 3, aTo: 25),
        // Pages 106-108 (3 pages).
        _lesson('l4', DateTime(2025, 12, 25), 3,
            sFrom: 5, aFrom: 1, sTo: 5, aTo: 7),
        // Pages 4-8 (5 pages), before the year.
        _lesson('l5', DateTime(2024, 12, 31), 5,
            sFrom: 2, aFrom: 19, sTo: 2, aTo: 49),
      ];
      final year = buildYearReport(
        lessons: lessons,
        reviews: [
          _review('r1', DateTime(2025, 3), ReviewType.sabaq,
              ReviewQuality.excellent),
          _review('r2', DateTime(2025, 11), ReviewType.murajaah,
              ReviewQuality.weak),
        ],
        jYear: 1404,
        monthStarts: monthStarts,
        yearEnd: DateTime(2026),
      );

      expect(year.months, hasLength(12));
      expect(year.total.lessonPages, 10); // 2+1+4+3
      expect(year.total.lessonCount, 4);
      expect(year.total.sabaqCount, 1);
      expect(year.total.murajaahCount, 1);
      expect(year.total.sabaqQuality.excellent, 1);
      expect(year.total.murajaahQuality.weak, 1);
      // cumulative = all lessons before 2026-01-01 (includes 2024 lesson)
      expect(year.total.cumulativePages, 15);
      expect(year.total.previousCumulativePages, 5);

      expect(year.months[0].report.lessonPages, 3); // Farvardin
      expect(year.months[5].report.lessonPages, 4); // Shahrivar
      expect(year.months[11].report.lessonPages, 3); // Esfand
      expect(year.months[1].report.lessonPages, 0);
    });

    test('inYearCumulativeTrend is monotonic and excludes pre-year pages', () {
      final monthStarts = [
        for (var m = 1; m <= 12; m++) DateTime(2025, m),
      ];
      final lessons = [
        // Pages 4-8 (5 pages), before the year.
        _lesson('p0', DateTime(2024, 12, 31), 5,
            sFrom: 2, aFrom: 19, sTo: 2, aTo: 49),
        // Pages 2-3 (2 pages).
        _lesson('a', DateTime(2025, 1, 10), 2,
            sFrom: 2, aFrom: 1, sTo: 2, aTo: 6),
        // Page 293 (1 page).
        _lesson('b', DateTime(2025, 1, 20), 1,
            sFrom: 18, aFrom: 1, sTo: 18, aTo: 1),
        // Pages 50-53 (4 pages).
        _lesson('c', DateTime(2025, 6, 5), 4,
            sFrom: 3, aFrom: 1, sTo: 3, aTo: 25),
        // Pages 106-108 (3 pages).
        _lesson('d', DateTime(2025, 12, 25), 3,
            sFrom: 5, aFrom: 1, sTo: 5, aTo: 7),
      ];
      final year = buildYearReport(
        lessons: lessons,
        reviews: const [],
        jYear: 1404,
        monthStarts: monthStarts,
        yearEnd: DateTime(2026),
      );

      final trend = year.inYearCumulativeTrend;
      expect(trend, hasLength(12));
      // Pre-year lesson (5 pages) is excluded: after Farvardin = 2+1 = 3.
      expect(trend.first, 3);
      expect(trend[0], 3);
      // After Shahrivar = 3 + 4 = 7.
      expect(trend[5], 7);
      // After Esfand = 7 + 3 = 10.
      expect(trend[11], 10);
      // Monotonic non-decreasing.
      for (var i = 1; i < trend.length; i++) {
        expect(trend[i] >= trend[i - 1], isTrue, reason: 'index $i');
      }
      expect(trend[11], year.total.lessonPages);
    });
  });
}
