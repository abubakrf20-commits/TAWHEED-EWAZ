import 'dart:math' as math;

import 'package:adhan/adhan.dart';

/// Independent NOAA low-precision solar-position reference — a deliberately
/// different code path from adhan's Astronomical Algorithms, so prayer-time
/// tests assert the engine against something other than itself.
///
/// Two coordinate systems:
///   * [referenceTimes] — minutes of LOCAL MEAN TIME day (offset = 4 min ×
///     lng), which removes timezone data from the assertion entirely.
///   * [utcNoonMinutes] / [utcEventMinutes] — minutes of UTC day, for
///     real-zone tests that combine NOAA astronomy with a tz-database offset.

({int fajr, int sunrise, int dhuhr, int asr, int maghrib, int isha})
    referenceTimes({
  required double lat,
  required double lng,
  required DateComponents date,
  double fajrAngle = -18.0,
  double ishaAngle = -17.0,
}) {
  // LMT minute = UTC minute + 4 min per degree east.
  int lmt(double utcMinutes) =>
      ((utcMinutes + 4.0 * lng).round() % 1440 + 1440) % 1440;

  final asrAlt = asrAltitudeDeg(lat, solarDeclination(fractionalYear(date)));

  return (
    fajr: lmt(utcEventMinutes(
        lat: lat, lng: lng, date: date, altDeg: fajrAngle, beforeNoon: true)),
    sunrise: lmt(utcEventMinutes(
        lat: lat, lng: lng, date: date, altDeg: -0.8333, beforeNoon: true)),
    dhuhr: lmt(utcNoonMinutes(lng: lng, date: date) + 1), // MWL +1 adjustment
    asr: lmt(utcEventMinutes(
        lat: lat, lng: lng, date: date, altDeg: asrAlt, beforeNoon: false)),
    maghrib: lmt(utcEventMinutes(
        lat: lat, lng: lng, date: date, altDeg: -0.8333, beforeNoon: false)),
    isha: lmt(utcEventMinutes(
        lat: lat, lng: lng, date: date, altDeg: ishaAngle, beforeNoon: false)),
  );
}

/// NOAA's fractional year [g] in radians for [date].
double fractionalYear(DateComponents date) {
  final yearLength = isLeapYear(date.year) ? 366 : 365;
  final dayOfYear = DateTime(date.year, date.month, date.day)
          .difference(DateTime(date.year))
          .inDays +
      1;
  return 2 * math.pi * (dayOfYear - 1) / yearLength;
}

/// NOAA equation of time (minutes) from the fractional year [g] (radians).
double equationOfTimeMinutes(double g) =>
    229.18 *
    (0.000075 +
        0.001868 * math.cos(g) -
        0.032077 * math.sin(g) -
        0.014615 * math.cos(2 * g) -
        0.040849 * math.sin(2 * g));

/// NOAA solar declination (radians) from the fractional year [g] (radians).
double solarDeclination(double g) =>
    0.006918 -
    0.399912 * math.cos(g) +
    0.070257 * math.sin(g) -
    0.006758 * math.cos(2 * g) +
    0.000907 * math.sin(2 * g) -
    0.002697 * math.cos(3 * g) +
    0.001480 * math.sin(3 * g);

bool isLeapYear(int year) =>
    (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);

/// Hour angle (degrees) for the sun to reach altitude [altDeg] at latitude
/// [latDeg] with declination [declRad]. |cosH| > 1 means the event does not
/// occur; tests cap latitude ≤ ~44° for −18° so every angle stays reachable.
double hourAngleDeg(double latDeg, double declRad, double altDeg) {
  final latR = latDeg * math.pi / 180.0;
  final altR = altDeg * math.pi / 180.0;
  final cosH = (math.sin(altR) - math.sin(latR) * math.sin(declRad)) /
      (math.cos(latR) * math.cos(declRad));
  return math.acos(cosH.clamp(-1.0, 1.0)) * 180.0 / math.pi;
}

/// Shafi Asr (shadow factor 1) altitude in degrees: the shadow equals the
/// object height plus its noon shadow.
double asrAltitudeDeg(double latDeg, double declRad) {
  final latR = latDeg * math.pi / 180.0;
  return math.atan(1.0 / (1.0 + math.tan((latR - declRad).abs()))) *
      180.0 /
      math.pi;
}

/// Solar noon (WITHOUT method adjustments) in minutes of UTC day.
double utcNoonMinutes({required double lng, required DateComponents date}) =>
    720.0 - equationOfTimeMinutes(fractionalYear(date)) - 4.0 * lng;

/// A solar event at altitude [altDeg] in minutes of UTC day.
double utcEventMinutes({
  required double lat,
  required double lng,
  required DateComponents date,
  required double altDeg,
  required bool beforeNoon,
}) {
  final ha = hourAngleDeg(lat, solarDeclination(fractionalYear(date)), altDeg);
  return utcNoonMinutes(lng: lng, date: date) +
      (beforeNoon ? -4.0 * ha : 4.0 * ha);
}
