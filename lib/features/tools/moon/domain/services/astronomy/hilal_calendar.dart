import 'package:tawheeed/features/tools/moon/domain/services/astronomy/astronomy.dart';
import 'package:tawheeed/features/tools/moon/domain/services/astronomy/hilal_visibility.dart';
import 'package:tawheeed/features/tools/moon/domain/services/astronomy/new_moon.dart';
import 'package:tawheeed/features/tools/moon/domain/services/astronomy/rise_set.dart';

/// پیش‌بینی ماه‌های قمری بر پایهٔ سه مبنا:
///  - [HilalMonthBasis.nakedEye]: اگر هلالِ شب 29ام با چشم غیرمسلح رؤیت‌پذیر
///    باشد ماه 29 روزه است، در غیر این صورت 30 روزه.
///  - [HilalMonthBasis.opticalAid]: ملاک، رؤیت‌پذیری با ابزار اپتیکی.
///  - [HilalMonthBasis.danjon]: ملاک صرفاً عبور از حد دانژون (elongation ≥ 7°)
///    همراه با بالای افق بودن ماه پس از غروب.
///  - [HilalMonthBasis.conjunction]: مبنای صرفاً نجومی — طول ماه از فاصلهٔ
///    دو اقتران متوالی (گردش سینودیک) تعیین می‌شود.
class HilalCalendar {
  HilalCalendar._();

  /// پیش‌بینی [count] ماه قمری که روز اولشان پس از [after] است.
  static List<HilalMonth> forecast({
    required DateTime after,
    required double lat,
    required double lng,
    int count = 12,
    HilalMonthBasis basis = HilalMonthBasis.nakedEye,
  }) {
    final months = <HilalMonth>[];
    var anchor = _nextNewMoonAtOrAfter(after);
    var day1 = _firstSunsetCivilDateAfter(anchor, lat, lng);

    for (var i = 0; i < count; i++) {
      final HilalMonth m;
      if (basis == HilalMonthBasis.conjunction) {
        // هر ماه مستقل از قبلی روی غروبِ بعد از اقترانِ خودش می‌نشیند
        final nextNm =
            _nextNewMoonAtOrAfter(anchor.add(const Duration(hours: 1)));
        final nextDay1 = _firstSunsetCivilDateAfter(nextNm, lat, lng);
        m = HilalMonth(
          startDate: day1,
          days: nextDay1.difference(day1).inDays,
          conjunctionUtc: anchor,
          basis: basis,
          sightingEvening: HilalVisibility.atSunset(
            date: day1.subtract(const Duration(days: 1)),
            lat: lat,
            lng: lng,
          ),
        );
        anchor = nextNm;
        day1 = nextDay1;
      } else {
        m = _buildSightingMonth(anchor, day1, lat, lng, basis);
        day1 = m.endDateExclusive;
        anchor = _nextNewMoonAtOrAfter(day1.subtract(const Duration(days: 1)));
      }
      months.add(m);
    }
    return months;
  }

  /// همان [forecast] برای هر سه مبنا — «تقویم سه‌مبنا».
  static Map<HilalMonthBasis, List<HilalMonth>> forecastAllBases({
    required DateTime after,
    required double lat,
    required double lng,
    int count = 12,
  }) =>
      {
        for (final b in HilalMonthBasis.values)
          b: forecast(after: after, lat: lat, lng: lng, count: count, basis: b),
      };

  /// روز مدنیِ نخستین غروبی که پس از [conjunction] می‌افتد — روز اول ماه.
  static DateTime _firstSunsetCivilDateAfter(
      DateTime conjunction, double lat, double lng) {
    var d = DateTime(conjunction.year, conjunction.month, conjunction.day);
    for (var i = 0; i < 4; i++) {
      final s = RiseSet.sunset(d, lat, lng);
      if (s != null && s.isAfter(conjunction)) {
        return DateTime(d.year, d.month, d.day);
      }
      d = d.add(const Duration(days: 1));
    }
    return DateTime(conjunction.year, conjunction.month, conjunction.day)
        .add(const Duration(days: 1));
  }

  static HilalMonth _buildSightingMonth(DateTime conjunction, DateTime day1,
      double lat, double lng, HilalMonthBasis basis) {
    final evening29 = day1.add(const Duration(days: 28));
    final data29 =
        HilalVisibility.atSunset(date: evening29, lat: lat, lng: lng);
    final visible29 = data29 != null && _visibleByBasis(data29, basis);
    final days = visible29 ? 29 : 30;

    return HilalMonth(
      startDate: day1,
      days: days,
      conjunctionUtc: conjunction,
      basis: basis,
      sightingEvening: visible29
          ? data29
          : HilalVisibility.atSunset(
              date: evening29.add(const Duration(days: 1)),
              lat: lat,
              lng: lng,
            ),
    );
  }

  static bool _visibleByBasis(SunsetHilalData data, HilalMonthBasis basis) {
    switch (basis) {
      case HilalMonthBasis.nakedEye:
        return data.verdict == HilalSightingVerdict.easilyVisible ||
            data.verdict == HilalSightingVerdict.nakedEyePossible;
      case HilalMonthBasis.opticalAid:
        return data.anyPossibility;
      case HilalMonthBasis.danjon:
        return data.verdict != HilalSightingVerdict.belowDanjon &&
            data.verdict != HilalSightingVerdict.preSunsetMoonset &&
            data.verdict != HilalSightingVerdict.notVisible;
      case HilalMonthBasis.conjunction:
        return true; // در این مبنا طول ماه از اقتران‌ها تعیین شده
    }
  }

  // ── اقتران (Meeus فصل 49) — از NewMoon، منبع یکتای محاق ────────────────

  static DateTime _nextNewMoonAtOrAfter(DateTime from) {
    final jd = Astronomy.julianDay(from);
    var k = NewMoon.kForJd(jd).floor();
    var next = Astronomy.fromJulianDay(NewMoon.trueNewMoonJd(k + 1));
    while (next.isBefore(from)) {
      k++;
      next = Astronomy.fromJulianDay(NewMoon.trueNewMoonJd(k + 1));
    }
    return next;
  }
}

/// مبنای تعیین طول ماه
enum HilalMonthBasis {
  nakedEye('چشم غیرمسلح', 'رؤیت هلالِ شب 29ام با چشم غیرمسلح'),
  opticalAid(
      'رؤیت با ابزار', 'قابلیت رؤیت با ابزار اپتیکی (یالوپ C/D یا عوده C)'),
  danjon('فقط جلوتر از حد دانژون', 'elongation ≥ 7° و بالای افق ماندن ماه'),
  conjunction('اقتران نجومی', 'طول ماه از دو اقتران متوالی (گردش سینودیک)');

  final String persian;
  final String desc;
  const HilalMonthBasis(this.persian, this.desc);
}

/// یک ماه قمری پیش‌بینی‌شده
class HilalMonth {
  /// روز اول ماه (تاریخ محلی — غروبِ همان روز آغاز ماه است)
  final DateTime startDate;

  /// 29 یا 30
  final int days;

  /// لحظهٔ اقتران آغاز ماه
  final DateTime conjunctionUtc;

  final HilalMonthBasis basis;

  /// دادهٔ هلالِ غروبِ شبِ تعیین‌کننده (شب 29ام یا 30ام)
  final SunsetHilalData? sightingEvening;

  DateTime get endDateExclusive => startDate.add(Duration(days: days));

  const HilalMonth({
    required this.startDate,
    required this.days,
    required this.conjunctionUtc,
    required this.basis,
    required this.sightingEvening,
  });
}
