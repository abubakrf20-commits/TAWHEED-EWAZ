import 'dart:math' as math;

import 'astronomy.dart';
import 'moon_position.dart';
import 'sun_position.dart';

/// یافتن دقیق طلوع/غروب خورشید و ماه برای هر مکان بر روی زمین.
class RiseSet {
  RiseSet._();

  /// غروب خورشید (درجه مرکز −0.833) — تعریف استاندارد دریایی/شرعی.
  static DateTime? sunset(DateTime day, double lat, double lng) =>
      _find(day, lat, lng, isSun: true, wantSunset: true);

  static DateTime? sunrise(DateTime day, double lat, double lng) =>
      _find(day, lat, lng, isSun: true, wantSunset: false);

  static DateTime? moonset(DateTime day, double lat, double lng) =>
      _find(day, lat, lng, isSun: false, wantSunset: true);

  static DateTime? moonrise(DateTime day, double lat, double lng) =>
      _find(day, lat, lng, isSun: false, wantSunset: false);

  /// ارتفاع هندسی در لحظه [date] (بدون شکست هوا — برای تشخیص افق)
  static double _altSun(DateTime date, double lat, double lng) =>
      Sun.geometricAltitude(date, lat, lng);

  /// ارتفاع هندسی توپومرکزی ماه (پارالاکس کامل میوس 11 در RA/Dec لحاظ شده).
  static double _altMoon(DateTime date, double lat, double lng) =>
      Moon.geocentricAltitude(date, lat, lng);

  /// جستجوی عددی با بایسکشن — هر 1٬100 پله صبر نمیشود؛ گام 2 دقیقهای
  /// برای ردگیری تغییر علامت کافی است (ماه ~0.5°/ساعت).
  static DateTime? _find(DateTime day, double lat, double lng,
      {required bool isSun, required bool wantSunset}) {
    final dayStart = DateTime(day.year, day.month, day.day);
    double altAt(DateTime t) =>
        isSun ? _altSun(t, lat, lng) : _altMoon(t, lat, lng);

    // هدف افق: خورشید −0.833° (شکست + نیمقطر). برای ماه: مرکز قرص در
    // −(0.125° + پارالاکس·cos) — پارالاکس افقی 0.95°، غروب ماه را 4–12 دقیقه
    // دیرتر از مدل زمینمرکزی میبرد؛ بدون این اصلاح مکث یالوپ (ورودی معیار
    // رؤیت هلال) از پایه خطا داشت.
    double targetAt(DateTime t) {
      if (isSun) return -0.833;
      final jd = Astronomy.julianDay(t);
      final par =
          math.asin(6378.14 / Moon.position(jd).distanceKm) * Astronomy.rad2Deg;
      return -0.125 - par * 0.7; // cos(alt≈0)≈1؛ فاکتور 0.7 میانگین مکث
    }

    const stepMin = 2;
    double crossing = double.nan;
    for (var m = 0; m < 24 * 60; m += stepMin) {
      final t0 = dayStart.add(Duration(minutes: m));
      final t1 = dayStart.add(Duration(minutes: m + stepMin));
      final a0 = altAt(t0), a1 = altAt(t1);
      final target0 = targetAt(t0), target1 = targetAt(t1);
      final wantsTransition = wantSunset
          ? (a0 > target0 && a1 <= target1) // گذر از بالا به پایین (غروب)
          : (a0 < target0 && a1 >= target1); // گذر از پایین به بالا (طلوع)
      if (wantsTransition) {
        // بایسکشن برای دقت دقیقهای
        var lo = m.toDouble(), hi = (m + stepMin).toDouble();
        for (var i = 0; i < 30 && (hi - lo) > 0.02; i++) {
          final mid = (lo + hi) / 2;
          final tMid = dayStart.add(Duration(
              minutes: mid.toInt(), seconds: ((mid * 60) % 60).toInt()));
          final aMid = altAt(tMid);
          final tMidTarget = targetAt(tMid);
          if (wantSunset) {
            if (aMid > tMidTarget) {
              lo = mid;
            } else {
              hi = mid;
            }
          } else {
            if (aMid < tMidTarget) {
              lo = mid;
            } else {
              hi = mid;
            }
          }
        }
        crossing = (lo + hi) / 2;
        break;
      }
    }
    if (crossing.isNaN) return null;
    final mins = crossing;
    return dayStart.add(
        Duration(minutes: mins.floor(), seconds: ((mins * 60) % 60).round()));
  }
}
