import 'dart:math' as math;
import 'astronomy.dart';

/// موقعیت زمینمرکز ماه — میوس فصل 47 (جدول کامل 47.A + تصحیحات).
class Moon {
  Moon._();

  // محاسبات میانگی
  static double _n(double v) {
    var x = v % 360;
    if (x < 0) x += 360;
    return x;
  }

  /// عناصر اصلی مدار ماه در لحظه [jd].
  static ({
    double lMean, // طول متوسط ماه
    double elong, // جدایی متوسط
    double mSun, // آنومالی متوسط خورشید
    double mMoon, // آنومالی متوسط ماه
    double argLat, // استدلال عرض
  }) _mean(double jd) {
    final T = Astronomy.T(jd);
    final t2 = T * T, t3 = t2 * T, t4 = t3 * T;
    return (
      lMean: _n(218.3164477 +
          481267.88123421 * T -
          0.0015786 * t2 +
          t3 / 538841 -
          t4 / 65194000),
      elong: _n(297.8501921 +
          445267.1114034 * T -
          0.0018819 * t2 +
          t3 / 545868 -
          t4 / 113065000),
      mSun:
          _n(357.5291092 + 35999.0502909 * T - 0.0001536 * t2 + t3 / 24490000),
      mMoon: _n(134.9633964 +
          477198.8675055 * T +
          0.0087414 * t2 +
          t3 / 69699 -
          t4 / 14712000),
      argLat: _n(93.2720950 +
          483202.0175233 * T -
          0.0036539 * t2 -
          t3 / 3526000 +
          t4 / 863310000),
    );
  }

  // ── جدول 47.A (ضرایب در 1e-6 درجه / کیلومتر) ──────────────────────────
  // طول/فاصله (60 جمله): هر ردیف (D, M, Mp, F, Σl, Σr)
  static const List<List<double>> _tGeo = [
    [0, 0, 1, 0, 6288774, -20905355],
    [2, 0, -1, 0, 1274027, -3699111],
    [2, 0, 0, 0, 658314, -2955968],
    [0, 0, 2, 0, 213618, -569925],
    [0, 1, 0, 0, -185116, 48888],
    [0, 0, 0, 2, -114332, -3149],
    [2, 0, -2, 0, 58793, 246158],
    [2, -1, -1, 0, 57066, -152138],
    [2, 0, 1, 0, 53322, -170733],
    [2, -1, 0, 0, 45758, -204586],
    [0, 1, -1, 0, -40923, -129620],
    [1, 0, 0, 0, -34720, 108743],
    [0, 1, 1, 0, -30383, 104755],
    [2, 0, 0, -2, 15327, 10321],
    [0, 0, 1, 2, -12528, 0],
    [0, 0, 1, -2, 10980, 79661],
    [4, 0, -1, 0, 10675, -34782],
    [0, 0, 3, 0, 10034, -23210],
    [4, 0, -2, 0, 8548, -21636],
    [2, 1, -1, 0, -7888, 24208],
    [2, 1, 0, 0, -6766, 30824],
    [1, 0, -1, 0, -5163, -8379],
    [1, 1, 0, 0, 4987, -16675],
    [2, -1, 1, 0, 4036, -12831],
    [2, 0, 2, 0, 3994, -10445],
    [4, 0, 0, 0, 3861, -11650],
    [2, 0, -3, 0, 3665, 14403],
    [0, 1, -2, 0, -2689, -7003],
    [2, 0, -1, 2, -2602, 0],
    [2, -1, -2, 0, 2390, 10056],
    [1, 0, 1, 0, -2348, 6322],
    [2, -2, 0, 0, 2236, -9884],
    [0, 1, 2, 0, -2120, 5751],
    [0, 2, 0, 0, -2069, 0],
    [2, -2, -1, 0, 2048, -4950],
    [2, 0, 1, -2, -1773, 4130],
    [2, 0, 0, 2, -1595, 0],
    [4, -1, -1, 0, 1215, -3958],
    [0, 0, 2, 2, -1110, 0],
    [3, 0, -1, 0, -892, 3258],
    [2, 1, 1, 0, -810, 2616],
    [4, -1, -2, 0, 759, -1897],
    [0, 2, -1, 0, -713, -2117],
    [2, 2, -1, 0, -700, 2354],
    [2, 1, -2, 0, 691, 0],
    [2, -1, 0, -2, 596, 0],
    [4, 0, 1, 0, 549, -1423],
    [0, 0, 4, 0, 537, -1117],
    [4, -1, 0, 0, 520, -1571],
    [1, 0, -2, 0, -487, -1739],
    [2, 1, 0, -2, -399, 0],
    [0, 0, 2, -2, -381, -4421],
    [1, 1, 1, 0, 351, 0],
    [3, 0, -2, 0, -340, 0],
    [4, 0, -3, 0, 330, 0],
    [2, -1, 2, 0, 327, 0],
    [0, 2, 1, 0, -323, 1165],
    [1, 1, -1, 0, 299, 0],
    [2, 0, 3, 0, 294, 0],
    [2, 0, -1, -2, 0, 8752],
  ];

  // عرض (60 جمله): هر ردیف (D, M, Mp, F, Σb)
  static const List<List<double>> _tLat = [
    [0, 0, 0, 1, 5128122],
    [0, 0, 1, 1, 280602],
    [0, 0, 1, -1, 277693],
    [2, 0, 0, -1, 173237],
    [2, 0, -1, 1, 55413],
    [2, 0, -1, -1, 46271],
    [2, 0, 0, 1, 32573],
    [0, 0, 2, 1, 17198],
    [2, 0, 1, -1, 9266],
    [0, 0, 2, -1, 8822],
    [2, -1, 0, -1, 8216],
    [2, 0, -2, -1, 4324],
    [2, 0, 1, 1, 4200],
    [2, 1, 0, -1, -3359],
    [2, -1, -1, 1, 2463],
    [2, -1, 0, 1, 2211],
    [2, -1, -1, -1, 2065],
    [0, 1, -1, -1, -1870],
    [4, 0, -1, -1, 1828],
    [0, 1, 0, 1, -1794],
    [0, 0, 0, 3, -1749],
    [0, 1, -1, 1, -1565],
    [1, 0, 0, 1, -1491],
    [0, 1, 1, 1, -1475],
    [0, 1, 1, -1, -1410],
    [0, 1, 0, -1, -1344],
    [1, 0, 0, -1, -1335],
    [0, 0, 3, 1, 1107],
    [4, 0, 0, -1, 1021],
    [4, 0, -1, 1, 833],
    [0, 0, 1, -3, 777],
    [4, 0, -2, 1, 671],
    [2, 0, 0, -3, 607],
    [2, 0, 2, -1, 596],
    [2, -1, 1, -1, 491],
    [2, 0, -2, 1, -451],
    [0, 0, 3, -1, 439],
    [2, 0, 2, 1, 422],
    [2, 0, -3, -1, 421],
    [2, 1, -1, 1, -366],
    [2, 1, 0, 1, -351],
    [4, 0, 0, 1, 331],
    [2, -1, 1, 1, 315],
    [2, -2, 0, -1, 302],
    [0, 0, 1, 3, -283],
    [2, 1, 1, -1, -229],
    [1, 1, 0, -1, 223],
    [1, 1, 0, 1, 223],
    [0, 1, -2, -1, -220],
    [2, 1, -1, -1, -220],
    [1, 0, 1, 1, -185],
    [2, -1, -2, -1, 181],
    [0, 1, 2, 1, -177],
    [4, 0, -2, -1, 176],
    [4, -1, -1, -1, 166],
    [1, 0, 1, -1, -164],
    [4, 0, 1, -1, 132],
    [1, 0, -1, -1, -119],
    [4, -1, 0, -1, 115],
    [2, -2, 0, 1, 107],
  ];

  /// موقعیت ماه: طول/عرض دائرةالبروج ظاهری (با ناتیشن)، فاصله، و برابرهای
  /// استوایی. [jd] زمان مؤثر.
  static ({
    double apparentLongitude,
    double latitude,
    double distanceKm, // فاصله زمینمرکز
    double horizontalParallaxDeg, // پارالاکس افقی استوایی
    double ra,
    double dec,
  }) position(double jd) {
    final m = _mean(jd);
    final T = Astronomy.T(jd);
    final E = 1 - 0.002516 * T - 0.0000074 * T * T;

    var sl = 0.0, sr = 0.0;
    const r = Astronomy.deg2Rad;
    for (final row in _tGeo) {
      final arg = row[0] * m.elong +
          row[1] * m.mSun +
          row[2] * m.mMoon +
          row[3] * m.argLat;
      final ePow = (row[1].abs() == 1) ? E : 1.0;
      sl += ePow * row[4] * math.sin(arg * r);
      sr += ePow * row[5] * math.cos(arg * r); // Σr با کسینوس (میوس 47)
    }
    var sb = 0.0;
    for (final row in _tLat) {
      final arg = row[0] * m.elong +
          row[1] * m.mSun +
          row[2] * m.mMoon +
          row[3] * m.argLat;
      final s = math.sin(arg * r);
      final ePow = (row[1].abs() == 1) ? E : 1.0;
      sb += ePow * row[4] * s;
    }

    // تصحیحات سیارهای (میوس 47.8)
    final a1 = _n(119.75 + 131.849 * T);
    final a2 = _n(53.09 + 479264.290 * T);
    final a3 = _n(313.45 + 481266.484 * T);

    final lon = m.lMean +
        (sl +
                3958 * math.sin(a1 * r) +
                1962 * math.sin((m.lMean - m.argLat) * r) +
                318 * math.sin(a2 * r)) /
            1000000;

    final lat = (sb +
            -2235 * math.sin(m.lMean * r) +
            382 * math.sin(a3 * r) +
            175 * math.sin((a1 - m.argLat) * r) +
            175 * math.sin((a1 + m.argLat) * r) +
            127 * math.sin((m.lMean - m.mMoon) * r) -
            115 * math.sin((m.lMean + m.mMoon) * r)) /
        1000000;

    // ناتیشن روی طول
    final appLon = _n(lon + Astronomy.nutation(jd).$1);

    final dist = 385000.56 + sr / 1000; // km
    final par = math.asin(6378.14 / dist) * Astronomy.rad2Deg;

    final eps = Astronomy.trueObliquity(jd);
    final eq = Astronomy.eclipticToEquatorial(appLon, lat, eps);

    return (
      apparentLongitude: _n(appLon),
      latitude: lat,
      distanceKm: dist,
      horizontalParallaxDeg: par,
      ra: eq.ra,
      dec: eq.dec,
    );
  }

  // ── پارالاکس روزانه (میوس فصل 11، معادله‌های 11.9–11.10) ────────────────

  /// تبدیل مختصات استوایی زمینمرکزی هر جسم به توپومرکزی — پارالاکس کامل در
  /// راستطلوع و میل (نه فقط تقریب −π·cos روی ارتفاع). [distKm] فاصلهٔ
  /// زمینمرکزی؛ عرض زمینمرکزی φ′ با تختشدگی WGS84.
  /// ارتفاع رصدگر از سطح دریا ناچیز فرض میشود (برای ماه < 0.5 ثانیه قوسی).
  static ({double ra, double dec}) topocentricFromGeocentric({
    required double ra,
    required double dec,
    required double distKm,
    required double jd,
    required double lat,
    required double lng,
  }) {
    final lst = Astronomy.lst(jd, lng);
    final ha = Astronomy.hourAngle(lst, ra) * Astronomy.deg2Rad;
    final decR = dec * Astronomy.deg2Rad;
    final latR = lat * Astronomy.deg2Rad;

    // عرض زمینمرکزی φ′ (میوس 11.6): tan φ′ = (1−f)² · tan φ
    const f = 1 / 298.257223563;
    final phiPrime = math.atan((1 - f) * (1 - f) * math.tan(latR));
    final hpRad = math.asin(6378.14 / distKm); // پارالاکس استوایی

    final sinPhi = math.sin(phiPrime), cosPhi = math.cos(phiPrime);
    final sinDec = math.sin(decR), cosDec = math.cos(decR);

    final deltaRa =
        -(hpRad * cosPhi * math.sin(ha) / cosDec) * Astronomy.rad2Deg;
    // علامت منفی: پارالاکس جسم را از سمتی دور میکند (ارتفاع کم میشود)؛
    // آزمون قطبی: در قطب شمال میل باید π·cosδ کم شود.
    final deltaDec = -hpRad *
        (sinPhi * cosDec - cosPhi * sinDec * math.cos(ha)) *
        Astronomy.rad2Deg;

    return (ra: _n(ra + deltaRa), dec: dec + deltaDec);
  }

  /// مختصات استوایی توپومرکزی ماه در [jd] برای رصدگر در [lat]/[lng].
  static ({double ra, double dec}) topocentricEquatorial({
    required double jd,
    required double lat,
    required double lng,
  }) {
    final geo = position(jd);
    return topocentricFromGeocentric(
      ra: geo.ra,
      dec: geo.dec,
      distKm: geo.distanceKm,
      jd: jd,
      lat: lat,
      lng: lng,
    );
  }

  /// ارتفاع ظاهری ماه (درجه) — با پارالاکس کامل توپومرکزی و شکست هوا.
  /// برای رؤیت هلال و هر کاربرد رصدی.
  static double apparentAltitude(DateTime date, double lat, double lng,
      {bool withRefraction = true}) {
    final jd = Astronomy.julianDay(date);
    final topo = topocentricEquatorial(jd: jd, lat: lat, lng: lng);
    final lst = Astronomy.lst(jd, lng);
    final ha = Astronomy.hourAngle(lst, topo.ra);
    final alt = Astronomy.equatorialToHorizontal(ha, topo.dec, lat).alt;
    return withRefraction ? alt + Astronomy.refraction(alt) : alt;
  }

  /// ارتفاع هندسی توپومرکزی (بدون شکست، با پارالاکس کامل) — معیار افق برای
  /// غروب/طلوع ماه.
  static double geocentricAltitude(DateTime date, double lat, double lng) {
    final jd = Astronomy.julianDay(date);
    final topo = topocentricEquatorial(jd: jd, lat: lat, lng: lng);
    final lst = Astronomy.lst(jd, lng);
    final ha = Astronomy.hourAngle(lst, topo.ra);
    return Astronomy.equatorialToHorizontal(ha, topo.dec, lat).alt;
  }
}
