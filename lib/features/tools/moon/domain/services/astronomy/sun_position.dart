import 'dart:math' as math;
import 'astronomy.dart';

/// موقعیت زمینمرکز خورشید — میوس فصل 25 (دقت ~0.01 درجه، کافی برای
/// جدول استهلال و رؤیت هلال).
class Sun {
  Sun._();

  /// عناصر خورشید در لحظه [jd] (زمان مؤثر همان ژولیان ورودی).
  static ({
    double apparentLongitude, // طول حقیقی ظاهری (deg)
    double distance, // فاصله (AU)
    double ra, // راست‌طلوع (deg)
    double dec, // میل استوایی (deg)
  }) position(double jd) {
    final T = Astronomy.T(jd);
    final l0 = _n(280.46646 + 36000.76983 * T + 0.0003032 * T * T);
    final m = _n(357.52911 + 35999.05029 * T - 0.0001537 * T * T);
    final e = 0.016708634 - 0.000042037 * T - 0.0000001267 * T * T;

    // معادله مرکز
    final C = (1.914602 - 0.004817 * T - 0.000014 * T * T) *
            math.sin(m * Astronomy.deg2Rad) +
        (0.019993 - 0.000101 * T) * math.sin(2 * m * Astronomy.deg2Rad) +
        0.000289 * math.sin(3 * m * Astronomy.deg2Rad);

    final trueLong = l0 + C;
    final om = _n(125.04 - 1934.136 * T);
    final appLong =
        trueLong - 0.00569 - 0.00478 * math.sin(om * Astronomy.deg2Rad);

    // فاصله بر حسب واحد نجومی
    final nu = m + C;
    final dist =
        1.000001018 * (1 - e * e) / (1 + e * math.cos(nu * Astronomy.deg2Rad));

    // میل استوایی (عرض دائرةالبروج = 0)
    final eps = Astronomy.trueObliquity(jd);
    final eq = Astronomy.eclipticToEquatorial(appLong, 0, eps);

    return (
      apparentLongitude: _n(appLong),
      distance: dist,
      ra: eq.ra,
      dec: eq.dec
    );
  }

  /// ارتفاع ظاهری خورشید (درجه) — توانایی تشخیص افق (شکست هوا لحاظ شده).
  static double apparentAltitude(DateTime date, double lat, double lng) {
    final jd = Astronomy.julianDay(date);
    final s = position(jd);
    final lst = Astronomy.lst(jd, lng);
    final ha = Astronomy.hourAngle(lst, s.ra);
    final h = Astronomy.equatorialToHorizontal(ha, s.dec, lat);
    return h.alt + Astronomy.refraction(h.alt);
  }

  /// ارتفاع هندسی (بدون شکست) برای محاسبات دقیقتر در زاویه‌های مثبت.
  static double geometricAltitude(DateTime date, double lat, double lng) {
    final jd = Astronomy.julianDay(date);
    final s = position(jd);
    final lst = Astronomy.lst(jd, lng);
    final ha = Astronomy.hourAngle(lst, s.ra);
    return Astronomy.equatorialToHorizontal(ha, s.dec, lat).alt;
  }

  static double _n(double v) {
    var x = v % 360;
    if (x < 0) x += 360;
    return x;
  }
}
