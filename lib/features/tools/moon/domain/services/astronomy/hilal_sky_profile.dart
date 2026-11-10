import 'astronomy.dart';
import 'hilal_visibility.dart';
import 'moon_position.dart';
import 'rise_set.dart';
import 'sun_position.dart';

/// A single sample of the sighting sweep: local time + topocentric altitudes.
class SkySample {
  /// Local civil time of the sample.
  final DateTime time;

  /// Topocentric moon altitude incl. full parallax (deg, no refraction).
  final double moonAlt;

  /// Moon azimuth (deg clockwise from true north, topocentric).
  final double moonAz;

  /// Geometric sun altitude (deg).
  final double sunAlt;

  const SkySample({
    required this.time,
    required this.moonAlt,
    required this.moonAz,
    required this.sunAlt,
  });
}

/// Horizon geometry at one sighting moment.
class HorizonFix {
  /// Moon azimuth (deg from north, clockwise) at [time].
  final double moonAz;

  /// Moon topocentric altitude (deg, WITH refraction — what the eye sees).
  final double moonAlt;

  /// Sun azimuth (deg from north, clockwise).
  final double sunAz;

  /// Sun altitude (deg, geometric).
  final double sunAlt;

  /// Relative azimuth (moon − sun) in [−180, 180]: negative → crescent horns
  /// point toward the right-hand side when facing the moon (northern
  /// hemisphere rule of thumb); the tilt of the crescent on the horizon.
  final double relAz;

  /// ARCL (sun-moon elongation, deg).
  final double arcl;

  /// Moon parallax (deg) at the fix — for the observer log.
  final double parallax;

  /// Moon age (hours) at the fix.
  final double ageHours;

  const HorizonFix({
    required this.moonAz,
    required this.moonAlt,
    required this.sunAz,
    required this.sunAlt,
    required this.relAz,
    required this.arcl,
    required this.parallax,
    required this.ageHours,
  });
}

/// Builds the evening sighting profile for one date/location: sweeps the
/// window from 30 min before sunset to moonset (or +3 h if the moon sets
/// very late / never that evening), sampling the topocentric moon and sun.
class HilalSkyProfile {
  HilalSkyProfile._();

  /// Sweep from [date] evening. Returns samples sorted by time; empty when
  /// the sun never sets (polar day) — no sighting window exists.
  static List<SkySample> sweep({
    required DateTime date,
    required double lat,
    required double lng,
    int stepMinutes = 4,
  }) {
    final sunset = RiseSet.sunset(date, lat, lng);
    if (sunset == null) return const [];
    final moonset = RiseSet.moonset(date, lat, lng);
    final hasEvening = moonset != null && moonset.isAfter(sunset);

    // End of the usable window: moonset, capped at sunset + 3h (beyond that
    // the crescent is trivially easy — the interesting part is near sunset).
    var end = sunset.add(const Duration(hours: 3));
    if (hasEvening && moonset.isBefore(end)) end = moonset;

    final samples = <SkySample>[];
    var t = sunset.subtract(const Duration(minutes: 30));
    while (t.isBefore(end)) {
      final jd = Astronomy.julianDay(t);
      final topo = Moon.topocentricEquatorial(jd: jd, lat: lat, lng: lng);
      final lst = Astronomy.lst(jd, lng);
      final mh = Astronomy.equatorialToHorizontal(
          Astronomy.hourAngle(lst, topo.ra), topo.dec, lat);
      final sun = Sun.geometricAltitude(t, lat, lng);
      samples.add(SkySample(
        time: t,
        moonAlt: mh.alt,
        moonAz: mh.az,
        sunAlt: sun,
      ));
      t = t.add(Duration(minutes: stepMinutes));
    }
    return samples;
  }

  /// Horizon fix at the Yallop best sighting time (sunset + 4/9·lag) for
  /// [date]; null when there is no usable evening (polar day / moonset
  /// before sunset).
  static HorizonFix? horizonFix({
    required DateTime date,
    required double lat,
    required double lng,
  }) {
    final data = HilalVisibility.atSunset(date: date, lat: lat, lng: lng);
    if (data == null || data.moonset == null) return null;
    if (!data.moonset!.isAfter(data.sunset)) return null;

    final t = data.bestTime;
    final jd = Astronomy.julianDay(t);
    final topo = Moon.topocentricEquatorial(jd: jd, lat: lat, lng: lng);
    final lst = Astronomy.lst(jd, lng);
    final mh = Astronomy.equatorialToHorizontal(
        Astronomy.hourAngle(lst, topo.ra), topo.dec, lat);
    final sun = Sun.position(jd);
    final sh = Astronomy.equatorialToHorizontal(
        Astronomy.hourAngle(lst, sun.ra), sun.dec, lat);

    // Relative azimuth normalized to (−180, 180].
    var rel = (mh.az - sh.az) % 360;
    if (rel > 180) rel -= 360;
    if (rel < -180) rel += 360;

    return HorizonFix(
      moonAz: mh.az,
      moonAlt: mh.alt + Astronomy.refraction(mh.alt),
      sunAz: sh.az,
      sunAlt: sh.alt,
      relAz: rel,
      arcl: data.arcl,
      parallax: data.moonParallaxDeg,
      ageHours: data.ageHoursAtBest,
    );
  }
}
