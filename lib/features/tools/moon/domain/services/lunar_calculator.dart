import 'dart:math' as math;
import 'package:tawheeed/core/constants/moon_constants.dart';
import 'package:tawheeed/features/tools/moon/domain/services/astronomy/astronomy.dart';
import 'package:tawheeed/features/tools/moon/domain/services/astronomy/eclipse_calculator.dart';
import 'package:tawheeed/features/tools/moon/domain/services/astronomy/hilal_calendar.dart'
    as hc;
import 'package:tawheeed/features/tools/moon/domain/services/astronomy/hilal_visibility.dart'
    as hv;
import 'package:tawheeed/features/tools/moon/domain/services/astronomy/moon_position.dart';
import 'package:tawheeed/features/tools/moon/domain/services/astronomy/new_moon.dart';
import 'package:tawheeed/features/tools/moon/domain/services/astronomy/rise_set.dart';
import 'package:tawheeed/features/tools/moon/domain/services/astronomy/sun_position.dart';

/// موتور نجومی خالص برای ماه — بر اساس «Astronomical Algorithms» جان میوس.
///
/// موقعیت ماه از جدول کامل فصل 47، موقعیت خورشید از فصل 25 و فاز/ملاقات از
/// فصل 49 (لونیشن ضدارباه) محاسبه میشود. آفلاین کامل.
class LunarCalculator {
  LunarCalculator._();

  // ── ابزار پایه ──────────────────────────────────────────────────────────

  static double toJulianDay(DateTime date) => Astronomy.julianDay(date);

  static DateTime fromJulianDay(double jd) => Astronomy.fromJulianDay(jd);

  // ── فاز ماه — الگوریتم میوس فصل 49 (منبع یکتا: NewMoon) ───────────────

  /// زمان دقیق محاق مربوط به لونیشن [kInt]
  static DateTime trueNewMoon(int kInt) =>
      fromJulianDay(NewMoon.trueNewMoonJd(kInt.toDouble()));

  /// آخرین محاق قبل (یا همزمان با) [date]
  static DateTime lastNewMoonBefore(DateTime date) =>
      fromJulianDay(NewMoon.lastNewMoonJdBefore(toJulianDay(date)));

  /// سن ماه (روز) — فاصله از آخرین محاق
  static double moonAge(DateTime date) {
    final nm = lastNewMoonBefore(date);
    return toJulianDay(date) - toJulianDay(nm);
  }

  /// طول دوره سینودیک واقعی بین دو محاق متوالی حول [date]
  static double synodicMonthAt(DateTime date) {
    final nm1 = lastNewMoonBefore(date);
    final nm2 = lastNewMoonBefore(nm1.subtract(const Duration(hours: 1)));
    return toJulianDay(nm1) - toJulianDay(nm2);
  }

  // ── فاز و روشنایی ──────────────────────────────────────────────────────

  /// فاز 0..1 (0=محاق، 0.5=بدر) — بر پایه سن ماه
  static double phase(DateTime date) => moonAge(date) / 29.53058867;

  /// درصد روشنایی — از جدایی واقعی خورشید-ماه (دقیقتر از فاز ساده)
  static double illumination(DateTime date) {
    final jd = toJulianDay(date);
    final mp = Moon.position(jd);
    final sp = Sun.position(jd);
    // زاویه جدایی زمینمرکز (elongation) بین خورشید و ماه
    const r = math.pi / 180;
    final cosSep = math.sin(sp.dec * r) * math.sin(mp.dec * r) +
        math.cos(sp.dec * r) *
            math.cos(mp.dec * r) *
            math.cos((sp.ra - mp.ra) * r);
    final sep = math.acos(cosSep.clamp(-1.0, 1.0)) / r;
    // درصد روشنایی = (1 - cos(elongation))/2 — elongation=180° (بدر) باید
    // 100% بدهد نه 0%؛ فرمول قبلی علامت cos را برعکس می‌گرفت.
    return (1 - math.cos(sep * r)) / 2 * 100;
  }

  /// جدایی خورشید-ماه بر حسب درجه (تعبیر هندسی elongation)
  static double elongationDeg(DateTime date) {
    final jd = toJulianDay(date);
    final mp = Moon.position(jd);
    final sp = Sun.position(jd);
    const r = math.pi / 180;
    final cosSep = math.sin(sp.dec * r) * math.sin(mp.dec * r) +
        math.cos(sp.dec * r) *
            math.cos(mp.dec * r) *
            math.cos((sp.ra - mp.ra) * r);
    return math.acos(cosSep.clamp(-1.0, 1.0)) / r;
  }

  static MoonPhaseName phaseName(DateTime date) {
    final p = phase(date);
    if (p < 0.02 || p >= 0.98) return MoonPhaseName.newMoon;
    if (p < 0.235) return MoonPhaseName.waxingCrescent;
    if (p < 0.265) return MoonPhaseName.firstQuarter;
    if (p < 0.485) return MoonPhaseName.waxingGibbous;
    if (p < 0.515) return MoonPhaseName.fullMoon;
    if (p < 0.735) return MoonPhaseName.waningGibbous;
    if (p < 0.765) return MoonPhaseName.lastQuarter;
    return MoonPhaseName.waningCrescent;
  }

  // ── منازل القمر ────────────────────────────────────────────────────────

  /// طول دایرةالبروج ماه (درجه 0..360) — جدول کامل میوس
  static double moonLongitude(DateTime date) =>
      Moon.position(toJulianDay(date)).apparentLongitude;

  /// میانگین تراکم اعتدالین در طول دائرةالبروج ≈ ۵۰٫۳۶ ثانیه قوسی/سال
  static double _precessionSinceJ2000(DateTime date) =>
      (toJulianDay(date) - 2451545.0) / 365.25 * 0.0139647;

  /// طول منازل‌محور: خانه‌ها به ستارگان ثابت گره خورده‌اند، نه به نقطهٔ
  /// بهاری که هر سال ~۱٫۴ درجه عقب می‌رود. بدون این تصحیح، منازل پس از
  /// ۱۴ قرن ~۲۰ درجه (≈۱٫۵ منزل) با ستارهٔ نام‌گذاری‌شدهٔ خودشان واگرا
  /// میشوند — مثلاً قمرِ نزدیک β حمل در منزل «ثریا» نشان داده میشد.
  static double siderealMoonLongitude(DateTime date) {
    var lon = moonLongitude(date) - _precessionSinceJ2000(date);
    lon %= 360;
    if (lon < 0) lon += 360;
    return lon;
  }

  /// آغاز منازل در چارچوب نجومی (β/γ حمل ≈ ۲۹° تا ۳۳° — «دو شاخ» درست پس
  /// از این مرز وارد خانهٔ صفر میشوند).
  static const double _manzilAnchorDeg = 27.0;

  static int manzilIndex(DateTime date) {
    final lon = (siderealMoonLongitude(date) - _manzilAnchorDeg) % 360;
    return (lon / (360 / 28)).floor().clamp(0, 27);
  }

  /// «منزل امشب» باید شب ارزیابی شود، نه نیمه‌روز/ساعت بازکردن صفحه.
  static DateTime _eveningOf(DateTime date) =>
      date.hour < 20 ? DateTime(date.year, date.month, date.day, 20, 15) : date;

  static MoonManzil currentManzil(DateTime date) =>
      kMoonManazil[manzilIndex(_eveningOf(date))];

  // ── موقعیت ظاهری ماه (برای طلوع/غروب و ارتفاع) ─────────────────────────

  /// ارتفاع ظاهری ماه (درجه) — صحیح، با پارالاکس/شکست
  static double moonAltitude(DateTime date, double lat, double lng) =>
      Moon.apparentAltitude(date, lat, lng);

  /// آزیموت ماه (درجه از شمال، ساعت‌گرد) — توپومرکزی با پارالاکس کامل
  static double moonAzimuth(DateTime date, double lat, double lng) {
    final jd = toJulianDay(date);
    final topo = Moon.topocentricEquatorial(jd: jd, lat: lat, lng: lng);
    final lst = Astronomy.lst(jd, lng);
    final ha = Astronomy.hourAngle(lst, topo.ra);
    return Astronomy.equatorialToHorizontal(ha, topo.dec, lat).az;
  }

  /// طلوع/غروب ماه در روز [date]
  static ({DateTime? rise, DateTime? set}) moonRiseSet(
          DateTime date, double lat, double lng) =>
      (
        rise: RiseSet.moonrise(date, lat, lng),
        set: RiseSet.moonset(date, lat, lng),
      );

  /// غروب/طلوع خورشید در روز [date]
  static ({DateTime? sunset, DateTime? sunrise}) sunRiseSet(
          DateTime date, double lat, double lng) =>
      (
        sunset: RiseSet.sunset(date, lat, lng),
        sunrise: RiseSet.sunrise(date, lat, lng),
      );

  // ── پیش‌بینی ──────────────────────────────────────────────────────────

  /// محاق بعدی — همیشه کاملاً بعد از [from]
  static DateTime nextNewMoon(DateTime from) {
    var k = NewMoon.kForJd(toJulianDay(from)).floor();
    var next = trueNewMoon(k + 1);
    while (!next.isAfter(from)) {
      k++;
      next = trueNewMoon(k + 1);
    }
    return next;
  }

  /// بدر بعدی (نزدیک‌ترین لحظهٔ فاز 0.5)
  static DateTime nextFullMoon(DateTime from) {
    var lo = from;
    var hi = from.add(const Duration(days: 31));
    double err(DateTime d) => (phase(d) - 0.5).abs();
    for (var i = 0; i < 40; i++) {
      final mid1 = lo.add(hi.difference(lo) ~/ 3);
      final mid2 = hi.subtract(hi.difference(lo) ~/ 3);
      if (err(mid1) < err(mid2)) {
        hi = mid2;
      } else {
        lo = mid1;
      }
    }
    final result = lo.add(hi.difference(lo) ~/ 2);
    return result.isAfter(from) ? result : result.add(const Duration(days: 29));
  }

  static String formatAge(double age) {
    var d = age.floor();
    var h = ((age - d) * 24).round();
    // 23.6 ساعت گرد → «24 ساعت» اشتباه نشود — یک روز کامل حساب شود.
    if (h >= 24) {
      d += 1;
      h -= 24;
    }
    if (d == 0) return '$h ساعت';
    if (h == 0) return '$d روز';
    return '$d روز و $h ساعت';
  }

  static String formatDateTimeFa(DateTime dt) =>
      '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  // ── رؤیت هلال (فاز 2) ──────────────────────────────────────────────────

  static hv.SunsetHilalData? sunsetHilal(
          DateTime date, double lat, double lng) =>
      hv.HilalVisibility.atSunset(date: date, lat: lat, lng: lng);

  static List<hc.HilalMonth> hilalMonths({
    required DateTime after,
    required double lat,
    required double lng,
    int count = 12,
    hc.HilalMonthBasis basis = hc.HilalMonthBasis.nakedEye,
  }) =>
      hc.HilalCalendar.forecast(
          after: after, lat: lat, lng: lng, count: count, basis: basis);

  static Map<hc.HilalMonthBasis, List<hc.HilalMonth>> hilalMonthsAllBases({
    required DateTime after,
    required double lat,
    required double lng,
    int count = 12,
  }) =>
      hc.HilalCalendar.forecastAllBases(
          after: after, lat: lat, lng: lng, count: count);

  // ── کسوف/خسوف — محاسبۀ کامل میوس فصل 54/55 (fase 3) ──

  static List<EclipseInfo> upcomingEclipses(DateTime from,
          {double lat = 35.6892, double lng = 51.389}) =>
      EclipseCalculator.upcoming(from, lat: lat, lng: lng);
}
