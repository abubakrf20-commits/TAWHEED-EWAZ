import 'dart:math' as math;

/// یکتا منبع زمان محاق (میعوس فصل ۴۹ — تصحیحات لونیشن ضدارباه).
///
/// [LunarCalculator]، [HilalVisibility] و [HilalCalendar] همگی از همین کلاس
/// استفاده میکنند تا محاق‌های گزارش‌شده در صفحات مختلف هرگز واگرا نشوند.
class NewMoon {
  NewMoon._();

  /// JDE لونیشن صفر (۲۰۰۰-۰۱-۰۶ ۱۸:۱۴ UTC)
  static const double jde0 = 2451550.09766;

  /// میانگین طول دورهٔ سینودیک (روز)
  static const double synodicMonth = 29.530588861;

  /// زمان میانگین محاق برای لونیشن [k]
  static double meanNewMoonJd(double k) {
    final t = k / 1236.85;
    return jde0 +
        synodicMonth * k +
        0.00015437 * t * t -
        0.000000150 * t * t * t +
        0.00000000073 * t * t * t * t;
  }

  /// زمان دقیق محاق [k] (میانگین + تصحیحات میعوس ۴۹.A و A1..A14)
  static double trueNewMoonJd(double k) => meanNewMoonJd(k) + correction(k);

  /// approx. شمارهٔ لونیشنِ نزدیک به JD — برای seed کردن جستجوها
  static double kForJd(double jd) => (jd - jde0) / synodicMonth;

  /// JD آخرین محاقِ قبل یا همزمان [jd]
  static double lastNewMoonJdBefore(double jd) {
    var k = kForJd(jd).roundToDouble();
    var jdNm = trueNewMoonJd(k);
    while (jdNm > jd) {
      k -= 1;
      jdNm = trueNewMoonJd(k);
    }
    return jdNm;
  }

  /// تصحیح دوره‌ای (روز) — جدول ۴۹.A میعوس با ضریب E + جمله‌های A1..A14
  static double correction(double k) {
    final t = k / 1236.85;
    final E = 1 - 0.002516 * t - 0.0000074 * t * t;
    const rad = math.pi / 180;

    final m = _n360(2.5534 + 29.10535670 * k);
    final mp = _n360(201.5643 + 385.81693528 * k);
    final f = _n360(160.7108 + 390.67050284 * k);
    final om = _n360(124.7746 - 1.56375588 * k);

    var corr = -0.40720 * math.sin(mp * rad);
    corr += 0.17241 * E * math.sin(m * rad);
    corr += 0.01608 * math.sin(2 * mp * rad);
    corr += 0.01039 * math.sin(2 * f * rad);
    corr += 0.00739 * E * math.sin((mp - m) * rad);
    corr += -0.00514 * E * math.sin((mp + m) * rad);
    corr += 0.00208 * E * E * math.sin(2 * m * rad);
    corr += -0.00111 * math.sin((mp - 2 * f) * rad);
    corr += -0.00057 * math.sin((mp + 2 * f) * rad);
    corr += 0.00056 * E * math.sin((2 * m + mp) * rad);
    corr += -0.00042 * math.sin(3 * mp * rad);
    corr += 0.00042 * E * math.sin((m + 2 * f) * rad);
    corr += 0.00038 * E * math.sin((m - 2 * f) * rad);
    corr += -0.00024 * E * math.sin((2 * mp - 2 * m) * rad);
    corr += -0.00017 * math.sin(om * rad);
    corr += -0.00007 * math.sin((mp + 2 * m) * rad);
    corr += 0.00004 * math.sin((mp - 2 * f) * rad);
    corr += 0.00004 * math.sin(3 * m * rad);
    corr += 0.00003 * math.sin((mp + m - 2 * f) * rad);
    corr += 0.00003 * math.sin((2 * mp + 2 * f) * rad);
    corr += -0.00003 * math.sin((mp + m + 2 * f) * rad);
    corr += 0.00003 * math.sin((mp - m + 2 * f) * rad);
    corr += -0.00002 * math.sin((mp - m - 2 * f) * rad);
    corr += -0.00002 * math.sin((3 * mp + m) * rad);
    corr += 0.00002 * math.sin(4 * mp * rad);

    final a1 = _n360(299.77 + 0.107408 * k);
    final a2 = _n360(251.88 + 0.016321 * k);
    final a3 = _n360(251.83 + 26.651886 * k);
    final a4 = _n360(349.42 + 36.412478 * k);
    final a5 = _n360(84.66 + 18.206239 * k);
    final a6 = _n360(141.74 + 53.303771 * k);
    final a7 = _n360(207.14 + 2.453732 * k);
    final a8 = _n360(154.84 + 7.306860 * k);
    final a9 = _n360(34.52 + 27.261239 * k);
    final a10 = _n360(207.19 + 0.121824 * k);
    final a11 = _n360(291.34 + 1.844379 * k);
    final a12 = _n360(161.72 + 24.198154 * k);
    final a13 = _n360(239.56 + 25.513099 * k);
    final a14 = _n360(331.55 + 3.592518 * k);

    corr += 0.000325 * math.sin(a1 * rad);
    corr += 0.000165 * math.sin(a2 * rad);
    corr += 0.000164 * math.sin(a3 * rad);
    corr += 0.000126 * math.sin(a4 * rad);
    corr += 0.000110 * math.sin(a5 * rad);
    corr += 0.000062 * math.sin(a6 * rad);
    corr += 0.000060 * math.sin(a7 * rad);
    corr += 0.000056 * math.sin(a8 * rad);
    corr += 0.000047 * math.sin(a9 * rad);
    corr += 0.000042 * math.sin(a10 * rad);
    corr += 0.000040 * math.sin(a11 * rad);
    corr += 0.000037 * math.sin(a12 * rad);
    corr += 0.000035 * math.sin(a13 * rad);
    corr += 0.000023 * math.sin(a14 * rad);

    corr += 0.000325 * t * t;
    return corr;
  }

  static double _n360(double v) {
    var x = v % 360;
    if (x < 0) x += 360;
    return x;
  }
}
