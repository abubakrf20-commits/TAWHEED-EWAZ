import 'dart:math' as math;

/// Elevation (horizon-dip) correction for visibility-based prayer times.
///
/// The `adhan` package computes sunrise/maghrib for an observer at sea level:
/// the sun's apparent disk must reach −0.833° below the astronomical horizon
/// (0.267° semi-diameter + 0.566° mean refraction). An observer standing at
/// altitude h sees the horizon *dropped* by the dip angle
///
///     dip = arccos(R / (R + h))
///
/// so the sun becomes visible earlier at dawn and disappears later at dusk.
/// The effect is ≈ 1° per 1000 m, i.e. about ±4 minutes per kilometre —
/// exactly the gap users notice versus apps that apply the correction
/// (e.g. official Institute of Geophysics times for Tehran ≈ +4 min maghrib).
///
/// Only sunrise and maghrib are corrected (they are visual events). Fajr,
/// isha, dhuhr and asr are angle/shadow based and conventionally keep their
/// standard definitions regardless of elevation.
abstract final class ElevationCorrection {
  /// Mean Earth radius in meters.
  static const double _earthRadiusM = 6371000.0;

  /// Standard sunset/sunrise depression: disk semi-diameter + refraction.
  static const double _standardSunAngle = 0.833;

  /// Dip of the apparent horizon seen from [altitudeMeters] above sea level,
  /// in degrees. Zero at or below sea level.
  static double horizonDipDegrees(double altitudeMeters) {
    if (altitudeMeters <= 0) return 0;
    final ratio = _earthRadiusM / (_earthRadiusM + altitudeMeters);
    return math.acos(ratio.clamp(0.0, 1.0)) * 180.0 / math.pi;
  }

  /// Apparent (top-of-disk) solar altitude in degrees at [timeUtc] for
  /// [latDeg]/[lngDeg].
  ///
  /// Uses the PrayTimes.org solar model (the same class of equations behind
  /// mainstream prayer-time engines), so altitudes solved here are consistent
  /// with how the `adhan` package itself defines its horizon events.
  /// Accuracy ≈ 0.01° ≈ a couple of seconds near the horizon.
  ///
  /// [timeUtc] must be a UTC DateTime.
  static double solarAltitudeDeg(
      DateTime timeUtc, double latDeg, double lngDeg) {
    final jd = _julianDay(timeUtc) - lngDeg / (15.0 * 24.0);
    final d = jd - 2451545.0; // days since J2000.0

    final gRad = _rad(_norm360(357.529 + 0.98560028 * d));
    final qDeg = _norm360(280.459 + 0.98564736 * d);
    final lRad = _rad(
        _norm360(qDeg + 1.915 * math.sin(gRad) + 0.020 * math.sin(2 * gRad)));
    final eRad = _rad(23.439 - 0.00000036 * d);

    // Right ascension in degrees, normalized to [0, 360).
    final raDeg = _norm360(
        _deg(math.atan2(math.cos(eRad) * math.sin(lRad), math.cos(lRad))));
    // Equation of time in degrees, wrapped to (−180, 180].
    final eqtDeg = _wrap180(qDeg - raDeg);
    // Declination.
    final declRad = math.asin(math.sin(eRad) * math.sin(lRad));

    // Hour angle east/west of local solar meridian.
    final uHours = timeUtc.hour +
        timeUtc.minute / 60.0 +
        (timeUtc.second + timeUtc.millisecond / 1000.0) / 3600.0;
    final hourAngleRad =
        _rad(_wrap180(15.0 * (uHours - 12.0) + lngDeg + eqtDeg));

    final phiRad = _rad(latDeg);
    final sinAlt = math.sin(phiRad) * math.sin(declRad) +
        math.cos(phiRad) * math.cos(declRad) * math.cos(hourAngleRad);
    return _deg(math.asin(sinAlt.clamp(-1.0, 1.0)));
  }

  /// Minute adjustments to add to the adhan package's sunrise/maghrib so they
  /// match an observer at [altitudeMeters]. Returns null when no correction
  /// is meaningful (altitude ≤ 0 or the solver failed to converge).
  ///
  /// [maghribAngle] is the active method's fixed Maghrib depression angle, if
  /// any (e.g. Tehran's 4.5°). When it is non-null, Maghrib is an
  /// absolute-altitude criterion rather than a visual horizon event, so
  /// horizon dip does not shift it and the Maghrib adjustment stays 0 —
  /// otherwise the solver would pull Tehran's official Maghrib back to
  /// geometric sunset and discard the method's definition.
  static ({int sunriseMinutes, int maghribMinutes})? computeAdjustments({
    required DateTime uncorrectedSunrise,
    required DateTime uncorrectedMaghrib,
    required double latitude,
    required double longitude,
    required double altitudeMeters,
    double? maghribAngle,
  }) {
    final dip = horizonDipDegrees(altitudeMeters);
    if (dip < 0.005) return null; // < ~30 m — below meaningful threshold

    final targetAlt = -_standardSunAngle - dip;

    final correctedSunrise = _solveCrossing(
      seed: uncorrectedSunrise.toUtc(),
      targetAltDeg: targetAlt,
      latitude: latitude,
      longitude: longitude,
    );

    final sunriseMin =
        correctedSunrise.difference(uncorrectedSunrise).inSeconds / 60.0;

    // Sanity guard: dip physics bounds the shift well under ±30 min even on
    // Everest. A wildly wrong result means the solver diverged — bail out.
    if (sunriseMin.abs() > 30) return null;

    if (maghribAngle != null) {
      // Angle-defined Maghrib (e.g. Tehran −4.5°): the observer's altitude
      // does not change when the sun reaches a fixed depression, so leave it.
      return (
        sunriseMinutes: sunriseMin.round(),
        maghribMinutes: 0,
      );
    }

    final correctedMaghrib = _solveCrossing(
      seed: uncorrectedMaghrib.toUtc(),
      targetAltDeg: targetAlt,
      latitude: latitude,
      longitude: longitude,
    );
    final maghribMin =
        correctedMaghrib.difference(uncorrectedMaghrib).inSeconds / 60.0;
    if (maghribMin.abs() > 30) return null;

    return (
      sunriseMinutes: sunriseMin.round(),
      maghribMinutes: maghribMin.round(),
    );
  }

  /// Newton iteration from [seed] towards the moment the sun crosses
  /// [targetAltDeg] (works for both the upward dawn crossing and the downward
  /// dusk crossing — the slope carries the direction automatically).
  static DateTime _solveCrossing({
    required DateTime seed,
    required double targetAltDeg,
    required double latitude,
    required double longitude,
  }) {
    var t = seed;
    for (var i = 0; i < 4; i++) {
      final alt = solarAltitudeDeg(t, latitude, longitude);
      final diff = targetAltDeg - alt;
      if (diff.abs() < 0.001) break; // < ~5 s precision reached

      // Numeric slope of altitude vs time (degrees per minute).
      const stepMin = 2.0;
      final altPlus = solarAltitudeDeg(
          t.add(const Duration(minutes: 2)), latitude, longitude);
      final altMinus = solarAltitudeDeg(
          t.subtract(const Duration(minutes: 2)), latitude, longitude);
      final slopePerMin = (altPlus - altMinus) / (2 * stepMin);
      if (slopePerMin.abs() < 1e-6) break; // polar edge case — give up safely

      final deltaMin = diff / slopePerMin;
      if (deltaMin.abs() > 60) break; // diverged — keep last sane estimate
      t = t.add(Duration(milliseconds: (deltaMin * 60000).round()));
    }
    return t;
  }

  static double _julianDay(DateTime utc) =>
      utc.millisecondsSinceEpoch / 86400000.0 + 2440587.5;

  static double _rad(double d) => d * math.pi / 180.0;
  static double _deg(double r) => r * 180.0 / math.pi;
  static double _norm360(double x) => x - 360.0 * (x / 360.0).floorToDouble();

  /// Wraps an angle to (−180, 180].
  static double _wrap180(double x) {
    final n = _norm360(x);
    return n > 180 ? n - 360 : n;
  }
}
