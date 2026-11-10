import 'dart:math';

/// Pure math for the Qibla compass — no Flutter imports, unit-testable.
///
/// Contains the great-circle bearing/distance to the Kaaba, the correction
/// from magnetic to true north, and the daily "sun shadow" moments used by
/// many Qibla apps as a calibration-free fallback.

const double kaabaLat = 21.4225;
const double kaabaLng = 39.8262;

// Polaris epoch-2026 position (J2000 + precession to 2026: dec 89°21′, RA 2h36m).
const double polarisRaDeg = 39.36;
const double polarisDecDeg = 89.354;

double _norm360(double deg) {
  var v = deg % 360;
  if (v < 0) v += 360;
  return v;
}

double _degToRad(double deg) => deg * pi / 180;

/// Which day a sun-shadow moment belongs to, relative to "now".
enum SunShadowDay { today, tomorrow }

/// Whether a sun-shadow moment is in the future (actionable) or already
/// passed today (informational only).
enum SunShadowStatus { upcoming, now, passed }

/// Correct a heading measured against **magnetic** north to **true**
/// (geographic) north using the local magnetic [declination] in degrees
/// (east positive, west negative).
double applyMagneticDeclination(double magneticHeading, double declination) {
  return (magneticHeading + declination + 360) % 360;
}

/// Initial great-circle bearing (degrees, 0..360, clockwise from true north)
/// from ([lat], [lng]) toward the Kaaba.
double qiblaBearingDeg(double lat, double lng) {
  final lat1 = lat * pi / 180;
  final lng1 = lng * pi / 180;
  const lat2 = kaabaLat * pi / 180;
  const lng2 = kaabaLng * pi / 180;
  final dLng = lng2 - lng1;
  final y = sin(dLng) * cos(lat2);
  final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);
  return (atan2(y, x) * 180 / pi + 360) % 360;
}

/// Haversine great-circle distance (km) from ([lat], [lng]) to the Kaaba.
double kaabaDistanceKm(double lat, double lng) {
  const R = 6371.0;
  final lat1 = lat * pi / 180;
  final lng1 = lng * pi / 180;
  const lat2 = kaabaLat * pi / 180;
  const lng2 = kaabaLng * pi / 180;
  final dLat = lat2 - lat1;
  final dLon = lng2 - lng1;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

/// Points along the great circle from ([lat], [lng]) to the Kaaba — the path
/// to draw on a map.
///
/// A two-point polyline is a straight line in *Mercator* space, not on the
/// Earth: from Jakarta, New York or Cape Town it visibly leaves the bearing the
/// compass shows, so the map contradicted the dial. Spherical interpolation
/// gives the true track, and [segments] is enough for it to read as a curve at
/// the zooms this card uses.
List<(double, double)> kaabaGreatCirclePath(
  double lat,
  double lng, {
  int segments = 64,
}) {
  final lat1 = lat * pi / 180;
  final lng1 = lng * pi / 180;
  const lat2 = kaabaLat * pi / 180;
  const lng2 = kaabaLng * pi / 180;

  // Angular distance between the endpoints.
  final cosD = sin(lat1) * sin(lat2) + cos(lat1) * cos(lat2) * cos(lng2 - lng1);
  final d = acos(cosD.clamp(-1.0, 1.0));
  if (d < 1e-9) return [(lat, lng), (kaabaLat, kaabaLng)];

  final points = <(double, double)>[];
  for (var i = 0; i <= segments; i++) {
    final f = i / segments;
    final a = sin((1 - f) * d) / sin(d);
    final b = sin(f * d) / sin(d);
    final x = a * cos(lat1) * cos(lng1) + b * cos(lat2) * cos(lng2);
    final y = a * cos(lat1) * sin(lng1) + b * cos(lat2) * sin(lng2);
    final z = a * sin(lat1) + b * sin(lat2);
    points.add((
      atan2(z, sqrt(x * x + y * y)) * 180 / pi,
      atan2(y, x) * 180 / pi,
    ));
  }
  return points;
}

/// One daily moment when the sun and the Qibla line up. When
/// [shadowTowardQibla] is true the shadow of a vertical object points exactly
/// toward the Kaaba; otherwise the sun itself is exactly in the Qibla
/// direction (the shadow points the other way).
///
/// [day] is relative to [qiblaSunShadowTimes]'s reference [now];
/// [status] tells the UI whether this moment is upcoming/now/passed.
class SunShadowMoment {
  /// Wall time in the scanned zone — the value the UI prints.
  final DateTime time;

  /// The moment as a true UTC instant — the value the countdown/status math
  /// must use when "now" lives in a different zone than [time].
  final DateTime utcInstant;
  final bool shadowTowardQibla;
  final SunShadowDay day;
  final SunShadowStatus status;

  const SunShadowMoment({
    required this.time,
    required this.utcInstant,
    required this.shadowTowardQibla,
    required this.day,
    required this.status,
  });
}

/// Finds the moments on [date] (wall time in [tzOffsetMinutes]) when a vertical
/// object's shadow points toward the Qibla, plus the opposite moment when the
/// sun is exactly in the Qibla direction. Only moments with the sun above the
/// horizon are returned, sorted chronologically.
///
/// [date] is the zone's WALL calendar date (its y/m/d fields); [tzOffsetMinutes]
/// is that zone's UTC offset for the scanned date (noon-anchored, as the
/// prayer repository resolves it). When null, the DEVICE's zone is used — the
/// pre-1.7.2 behaviour and what the default tests exercise.
///
/// Searches both [date] (today) and the next day so that when the user opens
/// the compass at night they still see tomorrow's actionable moment, clearly
/// tagged as belonging to tomorrow. Moments from today that have already
/// passed are kept (as [SunShadowStatus.passed]) for reference.
///
/// Some cities never get a daylight moment for one of the two cases (e.g.
/// Tehran's Qibla is SSW, so the "shadow toward Qibla" moment falls before
/// sunrise); only the moments that actually occur are returned.
List<SunShadowMoment> qiblaSunShadowTimes({
  required double lat,
  required double lng,
  required double qiblaBearing,
  required DateTime date,
  DateTime? now,
  int? tzOffsetMinutes,
}) {
  final reference = now ?? DateTime.now();
  final nowInstant = reference.toUtc();
  final result = <SunShadowMoment>[];

  // Scan today and tomorrow. Today's already-passed moments are kept so the
  // user can see "the moment passed at 09:48 today" instead of an empty card.
  for (final dayOffset in [0, 1]) {
    final day = DateTime(date.year, date.month, date.day)
        .add(Duration(days: dayOffset));
    final moments = _sunShadowMomentsOnDay(
      lat: lat,
      lng: lng,
      qiblaBearing: qiblaBearing,
      date: day,
      tzOffsetMinutes: tzOffsetMinutes,
    );
    for (final m in moments) {
      final status = _statusFor(m, reference, nowInstant);
      result.add(SunShadowMoment(
        time: m.time,
        utcInstant: m.utcInstant,
        shadowTowardQibla: m.shadowTowardQibla,
        day: dayOffset == 0 ? SunShadowDay.today : SunShadowDay.tomorrow,
        status: status,
      ));
    }
  }

  result.sort((a, b) => a.time.compareTo(b.time));
  return result;
}

SunShadowStatus _statusFor(
    SunShadowMoment m, DateTime now, DateTime nowInstant) {
  // Duration across zone offsets must come from TRUE instants, never from
  // wall minutes of two different zones.
  final diff = m.utcInstant.difference(nowInstant).inMinutes;
  if (diff.abs() <= 2) return SunShadowStatus.now;
  if (diff > 2) return SunShadowStatus.upcoming;
  return SunShadowStatus.passed;
}

/// Computes the raw daylight sun-shadow moments on a single [date]
/// (wall minutes of [date]'s zone).
List<SunShadowMoment> _sunShadowMomentsOnDay({
  required double lat,
  required double lng,
  required double qiblaBearing,
  required DateTime date,
  required int? tzOffsetMinutes,
}) {
  final toward = (qiblaBearing + 180) % 360; // shadow → Qibla
  final away = qiblaBearing % 360; // sun → Qibla
  final result = <SunShadowMoment>[];

  // UTC offset for this wall date (per-date, noon-anchored by the caller)
  // so the solar position runs on true solar time in THAT zone.
  // Legacy device-zone fallback when the caller has no resolved zone. The
  // old expression `base.difference(base.toUtc())` was always 0 (toUtc() is
  // the SAME instant, so their difference is zero by definition) — which is
  // how every printed time silently became UTC. timeZoneOffset of a
  // NOON-anchored instant is the real per-date offset.
  final offsetMinutes = tzOffsetMinutes ??
      DateTime(date.year, date.month, date.day, 12)
          .timeZoneOffset
          .inMinutes; // legacy: device zone

  double? prevAz;
  double prevEl = -90;
  for (var m = 0; m < 1440; m++) {
    // RAW utc minutes (NOT mod 1440): wall 00:00 in a +03:30 zone is 20:30
    // UTC of the PREVIOUS day, and the mod used to +24h-shift every jd for
    // those minutes — silently wrong solar positions for eastern zones.
    final utcMinuteRaw = m - offsetMinutes;
    final (el, az) =
        _solarPosition(lat, lng, date.year, date.month, date.day, utcMinuteRaw);
    if (prevAz == null) {
      prevAz = az;
      prevEl = el;
      continue;
    }
    // Unwrap continuously so the azimuth track stays monotonic through the
    // 0/360 wrap: shortest-path angular delta. The old
    // observer's sun (in the northern sky) walks its azimuth BACKWARD through
    // north at noon, and every small decrease used to inflate the track by a
    // full turn, so southern cities never got sun-sign moments at all.
    var delta = az - prevAz;
    while (delta > 180) {
      delta -= 360;
    }
    while (delta < -180) {
      delta += 360;
    }
    final curAz = prevAz + delta;
    for (final (target, shadowToward) in [
      (away - 360, false),
      (toward - 360, true),
      (away, false),
      (toward, true),
      (away + 360, false),
      (toward + 360, true),
    ]) {
      // Crossed within this minute, in EITHER track direction: southern
      // observers' azimuth DECREASES through the moment.
      if ((prevAz - target) * (curAz - target) <= 0 &&
          (curAz - prevAz).abs() > 1e-12) {
        final t =
            (target - prevAz) / (curAz - prevAz); // 0..1 within the minute
        final crossingEl = prevEl + (el - prevEl) * t;
        if (crossingEl > 0) {
          final seconds = ((m - 1) * 60 + t * 60).round();
          final time = DateTime(date.year, date.month, date.day)
              .add(Duration(seconds: seconds));
          // True UTC instant of the wall moment: wall − zone offset. The
          // countdown/status math must never subtract wall times of two
          // different zones.
          final wallToUtc = time.subtract(Duration(minutes: offsetMinutes));
          final instantUtc = DateTime.utc(
              wallToUtc.year,
              wallToUtc.month,
              wallToUtc.day,
              wallToUtc.hour,
              wallToUtc.minute,
              time.second,
              time.millisecond,
              time.microsecond);
          final dup = result.any(
              (r) => r.time == time && r.shadowTowardQibla == shadowToward);
          if (!dup) {
            result.add(SunShadowMoment(
              time: time,
              utcInstant: instantUtc,
              shadowTowardQibla: shadowToward,
              day: SunShadowDay.today,
              status: SunShadowStatus.upcoming,
            ));
          }
        }
      }
    }
    prevAz = curAz;
    prevEl = el;
  }
  result.sort((a, b) => a.time.compareTo(b.time));
  return result;
}

/// Solar elevation (degrees) and azimuth (degrees clockwise from true north)
/// for a given location and time — NOAA solar calculator algorithm.
///
/// [utcMinuteRaw] is the UTC minute offset from the START of the given
/// calendar date's midnight UTC — continuous value (may be negative or
/// exceed 1440 for zones whose civil day crosses a UTC date boundary), so
/// the Julian day must NOT clamp it with a mod 1440.
///
/// Replaces the earlier Spencer single-sum formula whose declination error
/// (up to ~0.35°) shifted the sun-shadow Qibla moments by up to ~1 minute.
(double, double) _solarPosition(
    double lat, double lng, int year, int month, int day, int utcMinuteRaw) {
  // Julian day at the given UTC minute.
  final jd0 = _jdn(year, month, day) - 0.5;
  final jd = jd0 + utcMinuteRaw / 1440.0;
  final t = (jd - 2451545.0) / 36525.0;

  // Geometric mean longitude / anomaly of the sun (degrees).
  final l0 = _norm360(280.46646 + t * (36000.76983 + t * 0.0003032));
  final m = 357.52911 + t * (35999.05029 - 0.0001537 * t);
  final mr = _degToRad(m);
  // Equation of center.
  final c = sin(mr) * (1.914602 - t * (0.004817 + 0.000014 * t)) +
      sin(2 * mr) * (0.019993 - 0.000101 * t) +
      sin(3 * mr) * 0.000289;
  final trueLong = l0 + c;
  // Apparent longitude (aberration + nutation).
  final omega = 125.04 - 1934.136 * t;
  final lambda =
      _degToRad(trueLong - 0.00569 - 0.00478 * sin(_degToRad(omega)));
  // Obliquity of the ecliptic.
  final seconds = 21.448 - t * (46.8150 + t * (0.00059 - t * 0.001813));
  final eps0 = 23.0 + 26.0 / 60 + seconds / 3600;
  final eps = _degToRad(eps0 + 0.00256 * cos(_degToRad(omega)));
  // Solar declination.
  final decl = asin(sin(eps) * sin(lambda));

  // Equation of time (minutes) — NOAA var-y form:
  // E = y·sin(2L0) − 2e·sin(M) + 4e·y·sin(M)·cos(2L0) − 0.5y²·sin(4L0) − 1.25e²·sin(2M)
  final y = pow(tan(eps / 2), 2).toDouble();
  const e = 0.016708634; // Earth's orbital eccentricity
  final eotMinutes = 4 *
      _degToRad(
        y * sin(2 * _degToRad(l0)) -
            2 * e * sin(mr) +
            4 * e * y * sin(mr) * cos(2 * _degToRad(l0)) -
            0.5 * y * y * sin(4 * _degToRad(l0)) -
            1.25 * e * e * sin(2 * mr),
      );

  // True solar time (MINUTES 0..1440 — mod 1440, not mod 360!) → hour angle.
  final tst = (utcMinuteRaw + 4 * lng + eotMinutes) % 1440.0;
  final h = _degToRad(tst / 4 - 180);

  final latR = _degToRad(lat);
  final sinEl = sin(latR) * sin(decl) + cos(latR) * cos(decl) * cos(h);
  final el = asin(sinEl.clamp(-1.0, 1.0));
  final az = (atan2(sin(h), cos(h) * sin(latR) - tan(decl) * cos(latR)) + pi) %
      (2 * pi);
  return (el * 180 / pi, az * 180 / pi);
}

/// Julian day number (integer day, noon-based) for a Gregorian date.
int _jdn(int year, int month, int day) {
  final a = (14 - month) ~/ 12;
  final y = year + 4800 - a;
  final m = month + 12 * a - 3;
  return day +
      (153 * m + 2) ~/ 5 +
      365 * y +
      y ~/ 4 -
      y ~/ 100 +
      y ~/ 400 -
      32045;
}

/// Solar event times for a given location and date.
/// Returns null for events that don't occur (e.g. polar day/night).
class SolarEvents {
  final DateTime? sunrise;
  final DateTime? sunset;
  final DateTime? solarNoon;
  final double? maxElevation;

  const SolarEvents({
    this.sunrise,
    this.sunset,
    this.solarNoon,
    this.maxElevation,
  });
}

/// Computes sunrise, sunset, solar noon, and max solar elevation for a given
/// location and date. [date] is the zone's WALL calendar date; [tzOffsetMinutes]
/// is that zone's UTC offset for the date (noon-anchored) — null falls back to
/// the DEVICE's zone (legacy behaviour, what the default tests exercise).
/// All returned times are wall times of that zone. Uses the NOAA-style
/// approximation: finds the hour angle where solar elevation crosses -0.833°
/// (accounts for atmospheric refraction + solar disk radius).
SolarEvents computeSolarEvents({
  required double lat,
  required double lng,
  required DateTime date,
  int? tzOffsetMinutes,
}) {
  final base = DateTime(date.year, date.month, date.day);
  final offsetMinutes = tzOffsetMinutes ??
      DateTime(date.year, date.month, date.day, 12).timeZoneOffset.inMinutes;
  DateTime? sunrise;
  DateTime? sunset;
  double maxEl = -90;
  int? noonMin;
  double noonEl = -90;

  double? prevEl;
  int? prevMin;
  for (var m = 0; m < 1440; m++) {
    // RAW utc minutes — see _sunShadowMomentsOnDay; the mod 1440 used to
    // +24h-shift the Julian day for every wall minute before the zone offset,
    // i.e. every morning in eastern zones (Auckland +12/+13, Kathmandu +5:45).
    final utcMinuteRaw = m - offsetMinutes;
    final (el, _) =
        _solarPosition(lat, lng, date.year, date.month, date.day, utcMinuteRaw);
    if (el > maxEl) {
      maxEl = el;
      noonMin = m;
      noonEl = el;
    }
    if (prevEl != null && prevMin != null) {
      // Sunrise: crossing -0.833° from below to above (first ascending crossing)
      if (sunrise == null && prevEl < -0.833 && el >= -0.833) {
        final t = (-0.833 - prevEl) / (el - prevEl);
        final seconds = ((prevMin) * 60 + t * 60).round();
        sunrise = base.add(Duration(seconds: seconds));
      }
      // Sunset: crossing -0.833° from above to below, but only AFTER the
      // sun has risen and reached its peak (noonMin). This avoids catching
      // the early-morning descending crossing from the previous night.
      if (noonMin != null &&
          m > noonMin &&
          sunset == null &&
          prevEl >= -0.833 &&
          el < -0.833) {
        final t = (-0.833 - prevEl) / (el - prevEl);
        final seconds = ((prevMin) * 60 + t * 60).round();
        sunset = base.add(Duration(seconds: seconds));
      }
    }
    prevEl = el;
    prevMin = m;
  }

  return SolarEvents(
    sunrise: sunrise,
    sunset: sunset,
    solarNoon: noonMin != null ? base.add(Duration(minutes: noonMin)) : null,
    maxElevation: noonEl == -90 ? null : noonEl,
  );
}

/// The current solar elevation and azimuth at the given location and time.
///
/// [when] is wall time in [tzOffsetMinutes]' zone (null = the DEVICE's zone,
/// the legacy behaviour); the returned position uses true solar time there.
(double, double) currentSolarPosition({
  required double lat,
  required double lng,
  required DateTime when,
  int? tzOffsetMinutes,
}) {
  // Legacy device-zone fallback — see _sunShadowMomentsOnDay for why this is
  // timeZoneOffset of a NOON anchor and not difference(base.toUtc()).
  final offsetMinutes = tzOffsetMinutes ??
      DateTime(when.year, when.month, when.day, 12).timeZoneOffset.inMinutes;
  final utcMinuteRaw = when.hour * 60 + when.minute - offsetMinutes;
  return _solarPosition(
      lat, lng, when.year, when.month, when.day, utcMinuteRaw);
}

/// Whether the sun is currently below the horizon at the given location.
/// [when] is wall time in [tzOffsetMinutes]' zone (null = the DEVICE's zone).
bool isNightTime(double lat, double lng, DateTime when,
    {int? tzOffsetMinutes}) {
  final (el, _) = currentSolarPosition(
      lat: lat, lng: lng, when: when, tzOffsetMinutes: tzOffsetMinutes);
  return el < -0.833;
}

/// Azimuth (degrees clockwise from true north) and altitude of Polaris — the
/// night-sky fallback for finding true north without a calibrated compass.
///
/// Uses proper Local Sidereal Time (GMST with the J2000 polynomial + longitude)
/// instead of the previous day-fraction approximation, which lacked the
/// GMST-at-0h offset (~280.46°) and the longitude term and drifted up to ~1.8°
/// across the day — enough to matter when aiming a bearing off a star.
(double, double) polarisPositionDeg(double lat, double lng, DateTime when) {
  final jd = when.toUtc().millisecondsSinceEpoch / 86400000 + 2440587.5;
  final t = (jd - 2451545.0) / 36525.0;
  // GMST in degrees (IAU 1982 polynomial — good to ~0.1s for this use).
  final gmst =
      280.46061837 + 360.98564736629 * (jd - 2451545.0) + 0.000387933 * t * t;
  final lst = _norm360(gmst + lng);
  final ha = _degToRad(_norm360(lst - polarisRaDeg));
  final decR = _degToRad(polarisDecDeg);
  final latR = _degToRad(lat);
  final sinAlt = sin(latR) * sin(decR) + cos(latR) * cos(decR) * cos(ha);
  final alt = asin(sinAlt.clamp(-1.0, 1.0));
  final cosAz = (sin(decR) - sin(alt) * sin(latR)) / (cos(alt) * cos(latR));
  var az = acos(cosAz.clamp(-1.0, 1.0)) * 180 / pi;
  if (sin(ha) > 0) az = 360 - az;
  return (_norm360(az), alt * 180 / pi);
}
