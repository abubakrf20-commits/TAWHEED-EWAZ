import 'dart:math' as math;
import 'astronomy.dart';
import 'moon_position.dart';
import 'new_moon.dart';
import 'rise_set.dart';
import 'sun_position.dart';

/// معیارهای علمی رؤیت هلال — یالوپ، عوده (ICOP)، بروین، دانژون.
///
/// منابع:
///  - B. D. Yallop, «A method for predicting the first sighting of the new
///    crescent Moon», HM Nautical Almanac Office Technical Note No. 69 (1997/
///    1998): پارامتر q از (ARCV زمین‌مرکز، عرض هلال) با بهترین زمان رصد
///    T_b = Ts + (4/9)·Lag.
///  - M. S. Odeh, «A new criterion for lunar crescent visibility» (2006,
///    ICOP): معیار مبتنی بر ARCV توپومرکزی و عرض هلال با چهار ناحیه.
///  - F. Bruin (1977) — جدول 3 در یادداشت فنی 69 یالوپ و برازش مکعبی.
///  - حد دانژون: elongation ~7 درجه (عوده از 737 رصد حد 6.4 درجه یافت).
class HilalVisibility {
  HilalVisibility._();

  /// محاسبهٔ کامل وضعیت هلال برای غروب روز [date] در مختصات [lat]/[lng].
  ///
  /// اگر در آن روز غروب خورشید وجود نداشته باشد (قطب‌ها) `null` برمی‌گرداند.
  static SunsetHilalData? atSunset({
    required DateTime date,
    required double lat,
    required double lng,
  }) {
    final sunset = RiseSet.sunset(date, lat, lng);
    if (sunset == null) return null;

    final moonset = RiseSet.moonset(date, lat, lng);

    // زمان بهینهٔ رصد (یالوپ) — 4/9 از فاصلهٔ غروب تا غروب ماه
    final hasVisibleEvening = moonset != null && moonset.isAfter(sunset);
    final bestTime = hasVisibleEvening
        ? sunset.add(Duration(
            microseconds: (moonset.difference(sunset).inMicroseconds * 4 ~/ 9)))
        : sunset;

    final jd = Astronomy.julianDay(bestTime);
    final mp = Moon.position(jd);
    final sp = Sun.position(jd);
    final lst = Astronomy.lst(jd, lng);

    // ── موقعیت خورشید (هندسی) و ماه (توپومرکزی کامل) ──
    final hSun = Astronomy.equatorialToHorizontal(
        Astronomy.hourAngle(lst, sp.ra), sp.dec, lat);

    // پارالاکس کامل میوس 11 در RA/Dec — ارتفاع و آزیموت واقعی رصدگر را
    // میدهد (تقریب −π·cos آزیموت را تا ~1° خطا میبرد؛ برای تعیین جهت رصد
    // اهمیت دارد).
    final moonTopo = Moon.topocentricEquatorial(jd: jd, lat: lat, lng: lng);
    final hMoon = Astronomy.equatorialToHorizontal(
        Astronomy.hourAngle(lst, moonTopo.ra), moonTopo.dec, lat);

    final sunAlt = hSun.alt;
    final moonAltTopo = hMoon.alt;
    // Same convention as the compass relAz (moon − sun): the two
    // «اختلاف آزیموت» readouts must agree with each other.
    final daz = _norm180(hMoon.az - hSun.az);

    // ارتفاع زمینمرکزی (برای مقایسهٔ ARVC دو‌مرکزی)
    final hMoonGeo = Astronomy.equatorialToHorizontal(
        Astronomy.hourAngle(lst, mp.ra), mp.dec, lat);
    final moonAltGeo = hMoonGeo.alt;
    final parallax = mp.horizontalParallaxDeg;

    // شکست هوا روی ارتفاع ماه توپومرکزی — تعریف عوده ARCV توپومرکزی را با
    // شکست میداند (~0.1–0.16° نزدیک افق؛ مرز طبقات B/C را جابهجا میکند).
    final moonAltTopoRefr = moonAltTopo + Astronomy.refraction(moonAltTopo);

    final arcvGeo = moonAltGeo - sunAlt;
    final arcvTopo = moonAltTopoRefr - sunAlt;

    // elongation زمین‌مرکز (ARCL)
    final cosArcl = math.sin(sp.dec * Astronomy.deg2Rad) *
            math.sin(mp.dec * Astronomy.deg2Rad) +
        math.cos(sp.dec * Astronomy.deg2Rad) *
            math.cos(mp.dec * Astronomy.deg2Rad) *
            math.cos((sp.ra - mp.ra) * Astronomy.deg2Rad);
    final arcl = math.acos(cosArcl.clamp(-1.0, 1.0)) * Astronomy.rad2Deg;

    // عرض هلال (دقیقه‌ی قوس) — W = SD·(1 − cos ARCL)
    final sdDeg = math.asin(1738.1 / mp.distanceKm) * Astronomy.rad2Deg;
    final sdArcMin = sdDeg * 60;
    final widthArcMin = sdArcMin * (1 - math.cos(arcl * Astronomy.deg2Rad));
    final widthDeg = sdDeg * (1 - math.cos(arcl * Astronomy.deg2Rad));

    final illumination = (1 - math.cos(arcl * Astronomy.deg2Rad)) / 2 * 100;

    final ageAtSunset = _ageHoursAt(sunset);
    final ageAtBest = _ageHoursAt(bestTime);
    // علامت طبیعی: مثبت = ماه پس از خورشید غروب میکند، منفی = پیش از آن.
    // (سرویس قبلاً مقدارِ already-negative را قرینه میکرد و غروبِ زودِ ماه
    // مثبت نشان داده میشد.) نبودِ غروب ماه در آن روز → ۰.
    final lagMin = moonset?.difference(sunset).inMinutes ?? 0;

    final moonAltSunset = Moon.apparentAltitude(sunset, lat, lng);

    return SunsetHilalData(
      date: date,
      sunset: sunset,
      moonset: moonset,
      bestTime: bestTime,
      lagMinutes: lagMin,
      sunAltitude: sunAlt,
      moonAltitudeGeocentric: moonAltGeo,
      moonAltitudeTopocentric: moonAltTopo,
      sunAzimuth: hSun.az,
      moonAzimuth: hMoon.az,
      daz: daz,
      arcvGeocentric: arcvGeo,
      arcvTopocentric: arcvTopo,
      arcl: arcl,
      crescentWidthArcMin: widthArcMin,
      crescentWidthDeg: widthDeg,
      moonSemidiameterArcMin: sdArcMin,
      illuminationPercent: illumination,
      moonDistanceKm: mp.distanceKm,
      moonParallaxDeg: parallax,
      ageHoursAtSunset: ageAtSunset,
      ageHoursAtBest: ageAtBest,
      moonAltitudeAtSunset: moonAltSunset,
      yallop: _evaluateYallop(arcvGeo, widthArcMin, arcl),
      odeh: _evaluateOdeh(arcvTopo, widthArcMin),
      bruin: _evaluateBruin(arcvGeo, widthArcMin),
      danjon: _evaluateDanjon(arcl),
      // رای کلی
      verdict: _overallVerdict(
        hasVisibleEvening: hasVisibleEvening,
        danjon: _evaluateDanjon(arcl),
        yallop: _evaluateYallop(arcvGeo, widthArcMin, arcl),
        odeh: _evaluateOdeh(arcvTopo, widthArcMin),
      ),
    );
  }

  /// معیار یالوپ: q = (ARCV − ARCV′) / 10 با
  /// ARCV′ = 11.8371 − 6.3226W + 0.7319W² − 0.1018W³  (W بر حسب دقیقهٔ قوس)
  static YallopResult _evaluateYallop(
      double arcvGeo, double widthArcMin, double arcl) {
    const a0 = 11.8371, a1 = -6.3226, a2 = 0.7319, a3 = -0.1018;
    final arcvPrime = a0 +
        a1 * widthArcMin +
        a2 * widthArcMin * widthArcMin +
        a3 * widthArcMin * widthArcMin * widthArcMin;
    final q = (arcvGeo - arcvPrime) / 10;
    final YallopClass cls;
    if (q >= 0.216) {
      cls = YallopClass.a;
    } else if (q >= -0.014) {
      cls = YallopClass.b;
    } else if (q >= -0.160) {
      cls = YallopClass.c;
    } else if (q >= -0.232) {
      cls = YallopClass.d;
    } else if (q >= -0.293) {
      cls = YallopClass.e;
    } else {
      cls = YallopClass.f;
    }
    return YallopResult(cls: cls, q: q, arcvPrime: arcvPrime, arcl: arcl);
  }

  /// معیار عوده (ICOP، 2006):
  /// V = ARCV(توپومرکزی) + 6.3226W − 0.7319W² + 0.1018W³ − 7.1651
  static OdehResult _evaluateOdeh(double arcvTopo, double widthArcMin) {
    final v = arcvTopo +
        6.3226 * widthArcMin -
        0.7319 * widthArcMin * widthArcMin +
        0.1018 * widthArcMin * widthArcMin * widthArcMin -
        7.1651;
    final OdehClass cls;
    if (v >= 5.65) {
      cls = OdehClass.a;
    } else if (v >= 2.0) {
      cls = OdehClass.b;
    } else if (v >= -0.96) {
      cls = OdehClass.c;
    } else {
      cls = OdehClass.d;
    }
    return OdehResult(cls: cls, v: v);
  }

  /// معیار بروین (1977) طبق جدول 3 و رابطه (3.3) در فنی‌نوت 69:
  /// ARCV > 12.4023 − 9.4878W + 3.9512W² − 0.5632W³
  static BruinResult _evaluateBruin(double arcvGeo, double widthArcMin) {
    final crit = 12.4023 -
        9.4878 * widthArcMin +
        3.9512 * widthArcMin * widthArcMin -
        0.5632 * widthArcMin * widthArcMin * widthArcMin;
    return BruinResult(visible: arcvGeo > crit, arcvCritical: crit);
  }

  /// حد دانژون: elongation کمتر از ~7° یعنی هلال هیچ‌وقت نور کافی برای
  /// رؤیت حتی با تلسکوپ ندارد.
  static DanjonResult _evaluateDanjon(double arcl) =>
      DanjonResult(limitDeg: 7.0, belowLimit: arcl < 7.0, arcl: arcl);

  static HilalSightingVerdict _overallVerdict({
    required bool hasVisibleEvening,
    required DanjonResult danjon,
    required YallopResult yallop,
    required OdehResult odeh,
  }) {
    if (!hasVisibleEvening) return HilalSightingVerdict.preSunsetMoonset;
    if (danjon.belowLimit) return HilalSightingVerdict.belowDanjon;
    if (yallop.cls == YallopClass.a || odeh.cls == OdehClass.a) {
      return HilalSightingVerdict.easilyVisible;
    }
    if (yallop.cls == YallopClass.b || odeh.cls == OdehClass.b) {
      return HilalSightingVerdict.nakedEyePossible;
    }
    if (yallop.cls == YallopClass.c ||
        yallop.cls == YallopClass.d ||
        odeh.cls == OdehClass.c) {
      return HilalSightingVerdict.opticalAid;
    }
    return HilalSightingVerdict.notVisible;
  }

  // ── سن ماه — از NewMoon (میعوس فصل ۴۹، منبع یکتا) ──────────────────────

  static double _ageHoursAt(DateTime t) =>
      (Astronomy.julianDay(t) -
          NewMoon.lastNewMoonJdBefore(Astronomy.julianDay(t))) *
      24;

  static double _norm180(double v) {
    var x = v % 360;
    if (x > 180) x -= 360;
    if (x < -180) x += 360;
    return x;
  }
}

/// دادهٔ کامل یک غروب — خروجی آماده برای جدول استهلال.
class SunsetHilalData {
  /// روزِ غروب (مبدأ محلی)
  final DateTime date;

  /// لحظهٔ غروب خورشید (محلی)
  final DateTime sunset;

  /// لحظهٔ غروب ماه (محلی؛ `null` → ماه نشید/بالای افق نیست)
  final DateTime? moonset;

  /// بهترین زمان رصد = غروب + 4/9·مکث
  final DateTime bestTime;

  /// مکث (دقیقه) — منفی = غروب ماه قبل از غروب خورشید
  final int lagMinutes;

  /// ارتفاع هندسی خورشید در بهترین زمان (درجه)
  final double sunAltitude;

  /// ارتفاع هندسی (زمین‌مرکز) ماه
  final double moonAltitudeGeocentric;

  /// ارتفاع توپومرکزی ماه (پارالاکس کامل، بدون شکست — شکست در ARCV لحاظ شده)
  final double moonAltitudeTopocentric;

  final double sunAzimuth;
  final double moonAzimuth;

  /// اختلاف آزیموت (ماه − خورشید) در [−180, 180]
  final double daz;

  /// قوس رؤیت زمین‌مرکزی (درجه)
  final double arcvGeocentric;

  /// قوس رؤیت توپومرکزی با شکست هوا (درجه) — مبنا در معیار عوده
  final double arcvTopocentric;

  /// elongation زمین‌مرکز = ARCL (درجه)
  final double arcl;

  /// عرض هلال (دقیقهٔ قوس) — W = SD·(1 − cos ARCL)
  final double crescentWidthArcMin;
  final double crescentWidthDeg;

  /// نیم‌قطر ظاهری ماه (دقیقهٔ قوس)
  final double moonSemidiameterArcMin;

  final double illuminationPercent;
  final double moonDistanceKm;
  final double moonParallaxDeg;

  /// سن ماه در لحظهٔ غروب و بهترین زمان (ساعت)
  final double ageHoursAtSunset;
  final double ageHoursAtBest;

  /// ارتفاع ظاهری ماه در لحظهٔ غروب خورشید (درجه)
  final double moonAltitudeAtSunset;

  final YallopResult yallop;
  final OdehResult odeh;
  final BruinResult bruin;
  final DanjonResult danjon;
  final HilalSightingVerdict verdict;

  const SunsetHilalData({
    required this.date,
    required this.sunset,
    required this.moonset,
    required this.bestTime,
    required this.lagMinutes,
    required this.sunAltitude,
    required this.moonAltitudeGeocentric,
    required this.moonAltitudeTopocentric,
    required this.sunAzimuth,
    required this.moonAzimuth,
    required this.daz,
    required this.arcvGeocentric,
    required this.arcvTopocentric,
    required this.arcl,
    required this.crescentWidthArcMin,
    required this.crescentWidthDeg,
    required this.moonSemidiameterArcMin,
    required this.illuminationPercent,
    required this.moonDistanceKm,
    required this.moonParallaxDeg,
    required this.ageHoursAtSunset,
    required this.ageHoursAtBest,
    required this.moonAltitudeAtSunset,
    required this.yallop,
    required this.odeh,
    required this.bruin,
    required this.danjon,
    required this.verdict,
  });

  /// True اگر هلالِ آن غروب بالقوه قابلیت رؤیت دارد (چشم، و یا لااقل ابزار).
  bool get anyPossibility =>
      verdict == HilalSightingVerdict.easilyVisible ||
      verdict == HilalSightingVerdict.nakedEyePossible ||
      verdict == HilalSightingVerdict.opticalAid;
}

/// طبقه‌بندی شش‌گانهٔ یالوپ
enum YallopClass {
  a('A', 'به‌آسانی با چشم غیرمسلح', 'q ≥ 0.216 و ARCL ≥ 12°'),
  b('B', 'با چشم غیرمسلح در شرایط مساعد', '0.216 > q ≥ −0.014'),
  c('C', 'پس از یافتن با ابزار با چشم دیده می‌شود', '0.014− > q ≥ −0.160'),
  d('D', 'تنها با دوربین / تلسکوپ', '0.160− > q ≥ −0.232'),
  e('E', 'با تلسکوپ معمولی نامرئی', '0.232− > q ≥ −0.293 (ARCL ≲ 8.5°)'),
  f('F', 'نامرئی — فروتر از حد دانژون', 'q < −0.293 (ARCL ≲ 8°)');

  final String code;
  final String persian;
  final String range;
  const YallopClass(this.code, this.persian, this.range);
}

class YallopResult {
  final YallopClass cls;
  final double q;
  final double arcvPrime;
  final double arcl;
  const YallopResult({
    required this.cls,
    required this.q,
    required this.arcvPrime,
    required this.arcl,
  });
}

/// چهار ناحیهٔ عوده (ICOP، 2006)
enum OdehClass {
  a('A', 'رؤیت با چشم غیرمسلح', 'V ≥ 5.65'),
  b('B', 'رؤیت با ابزار — احتمالاً با چشم', '2 ≤ V < 5.65'),
  c('C', 'تنها با ابزار اپتیکی', '−0.96 ≤ V < 2'),
  d('D', 'نامرئی حتی با ابزار', 'V < −0.96');

  final String code;
  final String persian;
  final String range;
  const OdehClass(this.code, this.persian, this.range);
}

class OdehResult {
  final OdehClass cls;
  final double v;
  const OdehResult({required this.cls, required this.v});
}

class BruinResult {
  final bool visible;
  final double arcvCritical;
  const BruinResult({required this.visible, required this.arcvCritical});
}

class DanjonResult {
  final double limitDeg;
  final double arcl;
  final bool belowLimit;
  const DanjonResult({
    required this.limitDeg,
    required this.arcl,
    required this.belowLimit,
  });
}

/// رای کلی نمایشی برای یک غروب
enum HilalSightingVerdict {
  easilyVisible(
      'به‌آسانی قابل رؤیت با چشم', 'هلال روشن — در غروب روشن دیده می‌شود'),
  nakedEyePossible('قابل رؤیت با چشم در شرایط مساعد',
      'با آسمان صاف احتمال دیده شدن با چشم وجود دارد'),
  opticalAid('قابل رؤیت با ابزار اپتیکی', 'با تلسکوپ / دوربین قابل رؤیت'),
  notVisible('نامرئی', 'بر اساس معیارهای رایج قابل رؤیت نیست'),
  preSunsetMoonset(
      'ماه پیش از غروب غروب کرده', 'ماه پس از غروب خورشید بالای افق نیست'),
  belowDanjon(
      'فروتر از حد دانژون', 'elongation کمتر از ~7° — حتی با تلسکوپ نامرئی');

  final String persian;
  final String desc;
  const HilalSightingVerdict(this.persian, this.desc);
}
