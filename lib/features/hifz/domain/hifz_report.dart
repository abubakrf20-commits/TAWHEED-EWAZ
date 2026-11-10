import 'package:tawheeed/features/hifz/domain/entities/hifz_lesson_model.dart';
import 'package:tawheeed/features/hifz/domain/entities/hifz_review_model.dart';
import 'package:tawheeed/features/hifz/domain/hifz_helpers.dart';

/// Report scope: a single (Jalali) month or a full year.
enum HifzReportMode { month, year }

/// Quality counts for a review type.
class QualityCounts {
  final int weak;
  final int medium;
  final int excellent;

  const QualityCounts({this.weak = 0, this.medium = 0, this.excellent = 0});

  int get total => weak + medium + excellent;

  QualityCounts operator +(QualityCounts other) => QualityCounts(
        weak: weak + other.weak,
        medium: medium + other.medium,
        excellent: excellent + other.excellent,
      );
}

/// Aggregated hifz stats over a period [start, end).
class HifzPeriodReport {
  /// Distinct pages newly memorized within the period (growth).
  final int lessonPages;
  final int lessonCount;
  final int sabaqCount;
  final int murajaahCount;
  final QualityCounts sabaqQuality;
  final QualityCounts murajaahQuality;

  /// Memorized pages from ALL lessons before [end] (cumulative progress).
  final int cumulativePages;

  /// Memorized pages before [start] (to show the period's own growth).
  final int previousCumulativePages;

  const HifzPeriodReport({
    this.lessonPages = 0,
    this.lessonCount = 0,
    this.sabaqCount = 0,
    this.murajaahCount = 0,
    this.sabaqQuality = const QualityCounts(),
    this.murajaahQuality = const QualityCounts(),
    this.cumulativePages = 0,
    this.previousCumulativePages = 0,
  });

  int get periodGrowthPages => lessonPages;
  double get progressFraction =>
      totalQuranPagesConst > 0 ? cumulativePages / totalQuranPagesConst : 0;

  static const int totalQuranPagesConst = 604;
}

/// Distinct pages covered by the ranges of [lessons] that are before
/// [before] — repeated ayahs are counted once.
int _uniquePagesBefore(List<HifzLessonModel> lessons, DateTime before) {
  return uniquePagesOf([
    for (final l in lessons)
      if (l.date.isBefore(before))
        (
          sFrom: l.surahFrom,
          aFrom: l.ayahFrom,
          sTo: l.surahTo,
          aTo: l.ayahTo,
        ),
  ]);
}

/// Builds a period report for all lessons/reviews within [start, end).
/// [end] is exclusive.
HifzPeriodReport buildPeriodReport({
  required List<HifzLessonModel> lessons,
  required List<HifzReviewModel> reviews,
  required DateTime start,
  required DateTime end,
}) {
  var lessonCount = 0;
  var sabaqCount = 0;
  var murajaahCount = 0;
  var sabaqWeak = 0;
  var sabaqMedium = 0;
  var sabaqExcellent = 0;
  var murajaahWeak = 0;
  var murajaahMedium = 0;
  var murajaahExcellent = 0;

  for (final l in lessons) {
    if (!l.date.isBefore(start) && l.date.isBefore(end)) lessonCount++;
  }

  for (final r in reviews) {
    if (r.date.isBefore(start) || !r.date.isBefore(end)) continue;
    final q = r.quality;
    if (r.type == ReviewType.sabaq) {
      sabaqCount++;
      if (q == ReviewQuality.weak) {
        sabaqWeak++;
      } else if (q == ReviewQuality.medium) {
        sabaqMedium++;
      } else {
        sabaqExcellent++;
      }
    } else {
      murajaahCount++;
      if (q == ReviewQuality.weak) {
        murajaahWeak++;
      } else if (q == ReviewQuality.medium) {
        murajaahMedium++;
      } else {
        murajaahExcellent++;
      }
    }
  }

  final cumulativePages = _uniquePagesBefore(lessons, end);
  final previousCumulativePages = _uniquePagesBefore(lessons, start);

  return HifzPeriodReport(
    lessonPages: cumulativePages - previousCumulativePages,
    lessonCount: lessonCount,
    sabaqCount: sabaqCount,
    murajaahCount: murajaahCount,
    sabaqQuality: QualityCounts(
        weak: sabaqWeak, medium: sabaqMedium, excellent: sabaqExcellent),
    murajaahQuality: QualityCounts(
        weak: murajaahWeak,
        medium: murajaahMedium,
        excellent: murajaahExcellent),
    cumulativePages: cumulativePages,
    previousCumulativePages: previousCumulativePages,
  );
}

/// Pages memorized per day-of-month within [monthStart] (a Jalali month).
/// Returns a map day → distinct pages for days that have lessons.
/// Repeated ayahs on the same day are counted once.
Map<int, int> pagesByDayInMonth({
  required List<HifzLessonModel> lessons,
  required DateTime monthStart,
  required DateTime monthEnd, // exclusive
}) {
  final byDay = <int, List<({int sFrom, int aFrom, int sTo, int aTo})>>{};
  for (final l in lessons) {
    if (l.date.isBefore(monthStart) || !l.date.isBefore(monthEnd)) continue;
    byDay.putIfAbsent(l.date.day, () => []).add((
      sFrom: l.surahFrom,
      aFrom: l.ayahFrom,
      sTo: l.surahTo,
      aTo: l.ayahTo,
    ));
  }
  return {
    for (final e in byDay.entries) e.key: uniquePagesOf(e.value),
  };
}

/// A monthly slice of a year report.
class HifzMonthSlice {
  final int jMonth; // 1..12 (Jalali month number)
  final HifzPeriodReport report;
  const HifzMonthSlice({required this.jMonth, required this.report});
}

/// Aggregated stats over a full (Jalali) year: 12 monthly slices + totals.
class HifzYearReport {
  final int jYear;
  final List<HifzMonthSlice> months;
  final HifzPeriodReport total;

  const HifzYearReport({
    required this.jYear,
    required this.months,
    required this.total,
  });

  /// Cumulative memorized pages at the end of each Jalali month, measured
  /// from the start of this year (i.e. excluding pages memorized before the
  /// year). 12 values, one per month — used for the yearly growth trend line.
  List<int> get inYearCumulativeTrend {
    final base = total.previousCumulativePages;
    return [
      for (final m in months)
        (m.report.cumulativePages - base).clamp(0, 1 << 31),
    ];
  }
}

/// Builds a year report for the Jalali year [jYear]. The caller supplies
/// [monthStarts]: gregorian DateTime of the 1st of each Jalali month (12
/// entries) and the [yearEnd] (exclusive) that ends the year.
HifzYearReport buildYearReport({
  required List<HifzLessonModel> lessons,
  required List<HifzReviewModel> reviews,
  required int jYear,
  required List<DateTime> monthStarts,
  required DateTime yearEnd,
}) {
  final slices = <HifzMonthSlice>[];
  var totalPages = 0;
  var totalCount = 0;
  var sabaqTotal = 0;
  var murajaahTotal = 0;
  var sabaqQ = const QualityCounts();
  var murajaahQ = const QualityCounts();

  for (var i = 0; i < monthStarts.length; i++) {
    final start = monthStarts[i];
    final end = i + 1 < monthStarts.length ? monthStarts[i + 1] : yearEnd;
    final report = buildPeriodReport(
        lessons: lessons, reviews: reviews, start: start, end: end);
    slices.add(HifzMonthSlice(jMonth: i + 1, report: report));
    totalPages += report.lessonPages;
    totalCount += report.lessonCount;
    sabaqTotal += report.sabaqCount;
    murajaahTotal += report.murajaahCount;
    sabaqQ = sabaqQ + report.sabaqQuality;
    murajaahQ = murajaahQ + report.murajaahQuality;
  }

  final cumulative = buildPeriodReport(
          lessons: lessons,
          reviews: reviews,
          start: monthStarts.first,
          end: yearEnd)
      .cumulativePages;
  final previous = buildPeriodReport(
          lessons: lessons,
          reviews: reviews,
          start: DateTime(2000),
          end: monthStarts.first)
      .cumulativePages;

  return HifzYearReport(
    jYear: jYear,
    months: slices,
    total: HifzPeriodReport(
      lessonPages: totalPages,
      lessonCount: totalCount,
      sabaqCount: sabaqTotal,
      murajaahCount: murajaahTotal,
      sabaqQuality: sabaqQ,
      murajaahQuality: murajaahQ,
      cumulativePages: cumulative,
      previousCumulativePages: previous,
    ),
  );
}
