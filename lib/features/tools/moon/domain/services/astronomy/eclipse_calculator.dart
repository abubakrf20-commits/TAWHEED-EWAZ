import 'dart:math' as math;
import 'astronomy.dart';
import 'moon_position.dart';
import 'sun_position.dart';

/// نوع رویداد کسوف/خسوف
enum EclipseKind { solar, lunar }

/// نتیجه محاسبة یک کسوف یا خسوف (لحظة بیشینه، نوع، بزرگی، رویت در ایران)
class EclipseInfo {
  final DateTime dateTime; // لحظة بیشینه (UTC)
  final EclipseKind kind;
  final String type; // برچسب فارسی

  /// بزرگی کلی زمینمرکزی (مطابق کاتالوگها). برای کسوف، بزرگیدن حداکثر
  /// گرفت در کره زمین — نه آنچه ناظر مشخصی میبیند.
  final double magnitude;

  /// بزرگی محلی کسوف خورشیدی از دید ناظر در [lat]/[lng] — با پارالاکس
  /// کامل توپومرکزی ماه و خورشید (تفاضل برداری موقعیتها). صفر یعنی از
  /// این مکان گرفت دیده نمیشود. برای خسوف `null` (بزرگی خسوف همانی است
  /// که همه ناظر شبِ گرفت میبینند).
  final double? localMagnitude;

  final bool visibleInIran;

  const EclipseInfo({
    required this.dateTime,
    required this.kind,
    required this.type,
    required this.magnitude,
    this.localMagnitude,
    required this.visibleInIran,
  });

  /// تاریخ «yyyy-MM-dd» برای نمایش
  String get date {
    final m = dateTime.month.toString().padLeft(2, '0');
    final d = dateTime.day.toString().padLeft(2, '0');
    return '${dateTime.year}-$m-$d';
  }
}

/// پیش‌بینی کسوف و خسوف — میوس فصل‌های 54 (خسوف) و 55 (کسوف).
/// عناصر بسل به‌جای جداول آماده، از موقعیت‌های ظاهری زمین‌مرکز خورشید/ماه
/// (معادلات بنیادی اسپناک/astrogreg) ساخته می‌شوند.
class EclipseCalculator {
  EclipseCalculator._();

  static const double _auKm = 149597870.7;
  static const double _earthRadiusKm = 6378.137;
  static const double _sunRadiusKm = 695700.0;
  static const double _moonRadiusKm = 1737.4;
  static const double _sunRadiusEarth = _sunRadiusKm / _earthRadiusKm;
  static const double _moonRadiusEarth = _moonRadiusKm / _earthRadiusKm;
  static const double _uThreshold = 0.0047;
  static const double _tehranLat = 35.6892;
  static const double _tehranLng = 51.3890;

  /// کش پویش سالانه — کلید: «آغاز سال | عرض | طول»
  static final Map<String, List<EclipseInfo>> _cache = {};

  /// رویدادهای پیشِ‌رو از تاریخ [from] (به تفکیک نوع)، به‌ترتیب زمانی.
  static List<EclipseInfo> upcoming(
    DateTime from, {
    double lat = _tehranLat,
    double lng = _tehranLng,
    int count = 4,
  }) {
    final origin = DateTime.utc(from.year);
    final key = '$origin|$lat|$lng';
    final all = _cache.putIfAbsent(key, () => _scan(origin, lat, lng));
    return all.where((e) => e.dateTime.isAfter(from)).take(count).toList();
  }

  /// پویش افق 10 سال از [origin].
  static List<EclipseInfo> _scan(DateTime origin, double lat, double lng) {
    final events = <EclipseInfo>[];
    final jdFrom = Astronomy.julianDay(origin);
    final jdEnd = jdFrom + 10 * 365.25 + 1;
    var jd = jdFrom - 1.0;
    while (jd < jdEnd) {
      final jdNext = jd + 0.5;
      if (_hasRisingCross(jd, jdNext, 0)) {
        final t = _bisect(jd, jdNext, 0);
        final e = _computeSolar(t, lat, lng);
        if (e != null) events.add(e);
      }
      if (_hasRisingCross(jd, jdNext, 180)) {
        final t = _bisect(jd, jdNext, 180);
        final e = _computeLunar(t, lat, lng);
        if (e != null) events.add(e);
      }
      jd = jdNext;
    }
    events.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return events;
  }

  // ── ابزار پایه ─────────────────────────────────────────────────────────

  static double _norm360(double v) {
    var x = v % 360;
    if (x < 0) x += 360;
    return x;
  }

  /// جدایی زمین‌مرکز طول دایرةالبروجی ماه و خورشید [0,360)
  static double _elongation(double jd) {
    final m = Moon.position(jd).apparentLongitude;
    final s = Sun.position(jd).apparentLongitude;
    return _norm360(m - s);
  }

  /// سینوسِ «فاصله از هدف» برای یافتن گذر صعودی از [ref] در دورة رشد.
  /// هنگام عبور صعودی از [ref]، مقدار از منفی به مثبت تغییر می‌کند.
  static double _phaseSign(double jd, double ref) {
    final e = _elongation(jd);
    var v = _norm360(e - ref);
    if (v > 180) v -= 360;
    return v;
  }

  static bool _hasRisingCross(double jdLo, double jdHi, double ref) {
    final s1 = _phaseSign(jdLo, ref);
    if (s1 >= 0) return false;
    final s2 = _phaseSign(jdHi, ref);
    return s2 > 0 && (s2 - s1) < 180;
  }

  static double _bisect(double jdLo, double jdHi, double ref) {
    var lo = jdLo, hi = jdHi;
    final sLo = _phaseSign(lo, ref);
    for (var i = 0; i < 60; i++) {
      final mid = (lo + hi) / 2;
      if (_phaseSign(mid, ref).sign == sLo.sign) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }

  static double _sepGeo(double jd) {
    final m = Moon.position(jd);
    final s = Sun.position(jd);
    final d1 = m.dec * Astronomy.deg2Rad, d2 = s.dec * Astronomy.deg2Rad;
    final da = (m.ra - s.ra) * Astronomy.deg2Rad;
    return math.acos((math.sin(d1) * math.sin(d2) +
                math.cos(d1) * math.cos(d2) * math.cos(da))
            .clamp(-1.0, 1.0)) *
        Astronomy.rad2Deg;
  }

  static List<double> _unitVec(double raDeg, double decDeg) {
    final a = raDeg * Astronomy.deg2Rad, d = decDeg * Astronomy.deg2Rad;
    return [math.cos(d) * math.cos(a), math.cos(d) * math.sin(a), math.sin(d)];
  }

  // ── کسوف خورشیدی (فصل 55) ───────────────────────────────────────────────

  static EclipseInfo? _computeSolar(double jdNew, double lat, double lng) {
    final tMax = _greatestSeparation(jdNew);
    final m = Moon.position(tMax);
    final s = Sun.position(tMax);
    final rM = m.distanceKm / _earthRadiusKm;
    final rS = s.distance * _auKm / _earthRadiusKm;

    final e = _unitVec(s.ra, s.dec).map((v) => v * rS).toList();
    final mv = _unitVec(m.ra, m.dec).map((v) => v * rM).toList();
    final gx = e[0] - mv[0], gy = e[1] - mv[1], gz = e[2] - mv[2];
    final g = math.sqrt(gx * gx + gy * gy + gz * gz);

    final aZ = math.atan2(gy, gx);
    final dZ = math.asin((gz / g).clamp(-1.0, 1.0));
    final aM = m.ra * Astronomy.deg2Rad, dM = m.dec * Astronomy.deg2Rad;

    final kx = math.cos(dM) * math.sin(aM - aZ);
    final ky = math.sin(dM) * math.cos(dZ) -
        math.cos(dM) * math.sin(dZ) * math.cos(aM - aZ);
    final kz = math.sin(dM) * math.sin(dZ) +
        math.cos(dM) * math.cos(dZ) * math.cos(aM - aZ);
    final x = rM * kx, y = rM * ky, z = rM * kz;
    final gamma = math.sqrt(x * x + y * y);

    final sinF2 = ((_sunRadiusEarth - _moonRadiusEarth) / g).clamp(-1.0, 1.0);
    final tanF2 = math.tan(math.asin(sinF2));
    final l2 = (z - _moonRadiusEarth / sinF2) * tanF2;

    final mag = (1.5433 + l2 - gamma) / (0.5461 + 2 * l2);
    if (mag <= 1e-5) return null;

    String type;
    if (gamma < 1.0) {
      if (l2 < 0) {
        type = 'کسوف کلی';
      } else if (l2 > _uThreshold) {
        type = 'کسوف حلقوی';
      } else {
        final w = 0.00464 * math.sqrt((1 - gamma * gamma).clamp(0.0, 1.0));
        type = l2 < w ? 'کسوف مرکب' : 'کسوف حلقوی';
      }
    } else {
      type = 'کسوف جزئی';
    }

    return EclipseInfo(
      dateTime: Astronomy.fromJulianDay(tMax).toUtc(),
      kind: EclipseKind.solar,
      type: type,
      magnitude: mag,
      localMagnitude: _localMagnitude(tMax, lat, lng),
      visibleInIran: _solarVisible(tMax, lat, lng),
    );
  }

  /// نزدیک‌ترین لحظه به بیشینة گرفت با پویش ریز دور مقارنة جغرافیایی.
  static double _greatestSeparation(double jdNew) {
    var bestSep = double.infinity;
    var best = jdNew;
    for (var i = -24; i <= 24; i++) {
      final t = jdNew + i * (2.0 / 1440.0);
      final sep = _sepGeo(t);
      if (sep < bestSep) {
        bestSep = sep;
        best = t;
      }
    }
    for (var i = -16; i <= 16; i++) {
      final t = best + i * (0.25 / 1440.0);
      final sep = _sepGeo(t);
      if (sep < bestSep) {
        bestSep = sep;
        best = t;
      }
    }
    return best;
  }

  /// رویت کسوف از [lat],[lng]: بزرگی محلی توپومرکزی در بازة ±3 ساعت از
  /// بیشینة کلی مثبت است و خورشید بالای افق.
  static bool _solarVisible(double jdMax, double lat, double lng) =>
      _localMagnitude(jdMax, lat, lng) > 0.0;

  /// بردار زمینمرکزی جسم (km) از RA/Dec/فاصله.
  static List<double> _geoVec({
    required double raDeg,
    required double decDeg,
    required double distKm,
  }) {
    final a = raDeg * Astronomy.deg2Rad, d = decDeg * Astronomy.deg2Rad;
    final cd = math.cos(d);
    return [
      distKm * cd * math.cos(a),
      distKm * cd * math.sin(a),
      distKm * math.sin(d)
    ];
  }

  /// موقعیت ناظر (km) در چارچوب استوایی هممرکز با زمین — استخر بیضوی میوس
  /// (تختشدگی WGS84).
  static List<double> _observerVec(double jd, double lat, double lng) {
    final lst = Astronomy.lst(jd, lng) * Astronomy.deg2Rad;
    final phi = lat * Astronomy.deg2Rad;
    final u = math.atan(0.99664719 * math.tan(phi));
    final rhoCos = math.cos(u);
    final rhoSin = 0.99664719 * math.sin(u);
    return [
      rhoCos * _earthRadiusKm * math.cos(lst),
      rhoCos * _earthRadiusKm * math.sin(lst),
      rhoSin * _earthRadiusKm,
    ];
  }

  static double _vecAngleDeg(List<double> a, List<double> b) {
    final dot = a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
    final na = math.sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2]);
    final nb = math.sqrt(b[0] * b[0] + b[1] * b[1] + b[2] * b[2]);
    return math.acos((dot / (na * nb)).clamp(-1.0, 1.0)) * Astronomy.rad2Deg;
  }

  /// بزرگی محلی کسوف خورشیدی از دید ناظر — پارالاکس کامل توپومرکزی با
  /// تفاضل برداری موقعیتهای زمینمرکزی ماه/خورشید و بردار ناظر (میوس فصل
  /// 11 به شیوهٔ عناصر بسل): ماه تا ~0.95° جابهجا میشود و کسوف جزئی که
  /// زمینمرکزی بزرگ است میتواند محلی عمیق باشد (یا برعکس). بیشینة
  /// بازة ±3 ساعت با خورشید بالای افق.
  static double _localMagnitude(double jdMax, double lat, double lng) {
    var best = 0.0;
    for (var i = -12; i <= 12; i++) {
      final t = jdMax + i * (15.0 / 1440.0);
      final dt = Astronomy.fromJulianDay(t);
      if (Sun.apparentAltitude(dt, lat, lng) <= 0.0) continue;

      final obs = _observerVec(t, lat, lng);
      final m = Moon.position(t);
      final s = Sun.position(t);
      final mv = _geoVec(raDeg: m.ra, decDeg: m.dec, distKm: m.distanceKm);
      final sv =
          _geoVec(raDeg: s.ra, decDeg: s.dec, distKm: s.distance * _auKm);

      final mTopo = [mv[0] - obs[0], mv[1] - obs[1], mv[2] - obs[2]];
      final sTopo = [sv[0] - obs[0], sv[1] - obs[1], sv[2] - obs[2]];

      final mDist = math.sqrt(
          mTopo[0] * mTopo[0] + mTopo[1] * mTopo[1] + mTopo[2] * mTopo[2]);
      final sDist = math.sqrt(
          sTopo[0] * sTopo[0] + sTopo[1] * sTopo[1] + sTopo[2] * sTopo[2]);
      final sep = _vecAngleDeg(mTopo, sTopo);

      final sunSemi = math.asin(_sunRadiusKm / sDist) * Astronomy.rad2Deg;
      final moonSemi = math.asin(_moonRadiusKm / mDist) * Astronomy.rad2Deg;
      final mag = (sunSemi + moonSemi - sep) / (2 * sunSemi);
      if (mag > best) best = mag;
    }
    return best;
  }

  // ── خسوف ماه (فصل 54) ─────────────────────────────────────────────────

  static EclipseInfo? _computeLunar(double jdOpp, double lat, double lng) {
    final m = Moon.position(jdOpp);
    final s = Sun.position(jdOpp);
    final dSunKm = s.distance * _auKm;

    // محور سایه: خط همخط با بردار خورشید از مرکز زمین. فاصلة عمودی دقیق
    // ماه از این محور با ضرب برداری در فضای سهبعدی — تقریب قبلی
    // (فاصله·sin(عرض دائرةالبروجی)) ضریب عرض خورشید/میل محور را نادیده
    // میگرفت و تا ~2000 کیلومتر خطا داشت (~15٪ بزرگی خسوف).
    final sv = _geoVec(raDeg: s.ra, decDeg: s.dec, distKm: 1.0);
    final mv = _geoVec(raDeg: m.ra, decDeg: m.dec, distKm: m.distanceKm);
    final dot = mv[0] * sv[0] + mv[1] * sv[1] + mv[2] * sv[2];
    // مؤلفة عمود بر محور: |M − (M·û)û| = √(|M|² − (M·û)²)
    final gammaKm = math.sqrt(
        (mv[0] * mv[0] + mv[1] * mv[1] + mv[2] * mv[2] - dot * dot)
            .clamp(0.0, double.infinity));

    // بزرگشدگی اتمسفری سایه‌ها (ضریب 1.02 میوس 54.1 — رؤیتپذیری
    // تاریکی توسط پراکندگی هوا).
    final rUmbra = 1.02 *
        (_earthRadiusKm -
            m.distanceKm * (_sunRadiusKm - _earthRadiusKm) / dSunKm);
    final rPen = 1.02 *
        (_earthRadiusKm +
            m.distanceKm * (_sunRadiusKm + _earthRadiusKm) / dSunKm);

    final magPen = (rPen + _moonRadiusKm - gammaKm) / (2 * _moonRadiusKm);
    final magUmbra = (rUmbra + _moonRadiusKm - gammaKm) / (2 * _moonRadiusKm);
    if (magPen <= 1e-5) return null;

    String type;
    if (magUmbra <= 1e-5) {
      type = 'خسوف نیمسایه';
    } else if (magUmbra < 1.0) {
      type = 'خسوف جزئی';
    } else {
      type = 'خسوف کلی';
    }

    final dt = Astronomy.fromJulianDay(jdOpp);
    final visible = Moon.apparentAltitude(dt, lat, lng) > 0.0;

    return EclipseInfo(
      dateTime: dt.toUtc(),
      kind: EclipseKind.lunar,
      type: type,
      magnitude: magUmbra > 0 ? magUmbra : magPen,
      visibleInIran: visible,
    );
  }
}
