import 'dart:math' as math;

/// تبدیل مختصات و محاسبات زمان ستارهای — بر اساس «Astronomical Algorithms»
/// جان میوس (چاپ دوم). تمام توابع درجه/کمیتهای نجومی را برمیگردانند.
class Astronomy {
  Astronomy._();

  static const double deg2Rad = math.pi / 180;
  static const double rad2Deg = 180 / math.pi;

  static double _norm360(double v) {
    var x = v % 360;
    if (x < 0) x += 360;
    return x;
  }

  static double _norm180(double v) {
    var x = v % 360;
    if (x > 180) x -= 360;
    if (x < -180) x += 360;
    return x;
  }

  /// روز ژولیانی از DateTime (به UTC تبدیل میشود) — میوس فصل 7.
  static double julianDay(DateTime date) {
    final utc = date.toUtc();
    var y = utc.year;
    var m = utc.month;
    final d = utc.day + (utc.hour + utc.minute / 60 + utc.second / 3600) / 24;
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    final a = (y / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (y + 4716)).floor() +
        (30.6001 * (m + 1)).floor() +
        d +
        b -
        1524.5;
  }

  static DateTime fromJulianDay(double jd) {
    final z = jd.floorToDouble() + 0.5;
    final f = jd + 0.5 - z;
    double a = z;
    if (z >= 2299161) {
      final alpha = ((z - 1867216.25) / 36524.25).floorToDouble();
      a = z + 1 + alpha - (alpha / 4).floorToDouble();
    }
    final b = a + 1524;
    final c = ((b - 122.1) / 365.25).floorToDouble();
    final d = (365.25 * c).floorToDouble();
    final e = ((b - d) / 30.6001).floorToDouble();
    final dayFrac = b - d - (30.6001 * e).floorToDouble() + f;
    final day = dayFrac.floor();
    final month = (e < 14 ? e - 1 : e - 13).toInt();
    final year = (month > 2 ? c - 4716 : c - 4715).toInt();
    var rem = dayFrac - day;
    final hour = (rem * 24).toInt();
    rem = rem * 24 - hour;
    final minute = (rem * 60).toInt();
    rem = rem * 60 - minute;
    final second = (rem * 60).round();
    return DateTime.utc(
            year, month.clamp(1, 12), day, hour, minute, second.clamp(0, 59))
        .toLocal();
  }

  /// قرن ژولیانی از مبدأ J2000
  static double T(double jd) => (jd - 2451545.0) / 36525;

  // ── میل حقیقی (فصل 22 میوس) ───────────────────────────────────────────

  static double meanObliquity(double T) {
    // 21.448 ثانیه قوسی
    return 23.43929111 -
        0.0130041667 * T -
        0.0000001639 * T * T +
        0.0000005036 * T * T * T;
  }

  /// ناتیشن: (Δψ, Δε) بر حسب درجه — فصل 22 معادلههای اصلی
  static (double, double) nutation(double jd) {
    final T = Astronomy.T(jd);
    final om = _norm360(125.04452 - 1934.136261 * T);
    final lsunMean = _norm360(280.4665 + 36000.7698 * T);
    final lmoonMean = _norm360(218.3165 + 481267.8813 * T);
    final dpsi = -17.20 * math.sin(om * deg2Rad) -
        1.32 * math.sin(2 * lsunMean * deg2Rad) -
        0.23 * math.sin(2 * lmoonMean * deg2Rad) +
        0.21 * math.sin(2 * om * deg2Rad);
    final deps = 9.20 * math.cos(om * deg2Rad) +
        0.57 * math.cos(2 * lsunMean * deg2Rad) +
        0.10 * math.cos(2 * lmoonMean * deg2Rad) -
        0.09 * math.cos(2 * om * deg2Rad);
    return (dpsi / 3600.0, deps / 3600.0);
  }

  /// میل حقیقی بر حسب درجه
  static double trueObliquity(double jd) {
    final T = Astronomy.T(jd);
    return meanObliquity(T) + nutation(jd).$2;
  }

  // ── زمان ستارهای (فصل 12 میوس) ────────────────────────────────────────

  /// GMST بر حسب درجه
  static double gmst(double jd) {
    final T = Astronomy.T(jd);
    return _norm360(280.46061837 +
        360.98564736629 * (jd - 2451545.0) +
        0.000387933 * T * T -
        T * T * T / 38710000);
  }

  /// LST بر حسب درجه (longitude شرقی مثبت)
  static double lst(double jd, double longitude) =>
      _norm360(gmst(jd) + longitude);

  // ── تبدیلها ───────────────────────────────────────────────────────────

  /// دائرةالبروج → استوایی. [lon]/[lat] طول/عرض بر حسب درجه، [eps] میل حقیقی.
  static ({double ra, double dec}) eclipticToEquatorial(
      double lon, double lat, double eps) {
    final kl = lon * deg2Rad, kb = lat * deg2Rad, ke = eps * deg2Rad;
    final ra = math.atan2(
        math.sin(kl) * math.cos(ke) - math.tan(kb) * math.sin(ke),
        math.cos(kl));
    final dec = math.asin(math.sin(kb) * math.cos(ke) +
        math.cos(kb) * math.sin(ke) * math.sin(kl));
    return (ra: _norm360(ra * rad2Deg), dec: dec * rad2Deg);
  }

  /// استوایی → افقی: (altitude, azimuth از شمال ساعتگرد).
  /// [ha] زاویه ساعتی بر حسب درجه، [lat] عرض جغرافیایی.
  static ({double alt, double az}) equatorialToHorizontal(
      double ha, double dec, double lat) {
    final kh = ha * deg2Rad, kd = dec * deg2Rad, kf = lat * deg2Rad;
    final sinAlt = math.sin(kd) * math.sin(kf) +
        math.cos(kd) * math.cos(kf) * math.cos(kh);
    final alt = math.asin(sinAlt.clamp(-1.0, 1.0));
    final cosAz = (math.sin(kd) - math.sin(alt) * math.sin(kf)) /
        (math.cos(alt) * math.cos(kf));
    var az = math.acos(cosAz.clamp(-1.0, 1.0)) * rad2Deg;
    if (math.sin(kh) > 0) az = 360 - az;
    return (alt: alt * rad2Deg, az: _norm360(az));
  }

  /// زاویه ساعتی بر حسب درجه (LST - RA)
  static double hourAngle(double lstDeg, double raDeg) =>
      _norm180(lstDeg - raDeg);

  /// شکست اتمسفر: اینپوت ارتفاع واقعی، خروجی مقدار شکست بر حسب درجه.
  /// (میوس فرمول 16.4، محدود معتبر برای h > -1°)
  static double refraction(double trueAltitudeDeg) {
    final h = trueAltitudeDeg;
    if (h < -1.0) return 0;
    // 1.02' / tan(h + 10.3/(h + 5.11))
    final arg = (h + 10.3 / (h + 5.11)) * deg2Rad;
    final rArcMin = 1.02 / math.tan(arg);
    return (rArcMin / 60.0).clamp(0.0, 5.0);
  }
}
