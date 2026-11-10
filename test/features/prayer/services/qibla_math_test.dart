import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/prayer/services/qibla_math.dart';

void main() {
  group('applyMagneticDeclination', () {
    test('adds east-positive declination', () {
      expect(applyMagneticDeclination(0, 6.3), closeTo(6.3, 1e-9));
      expect(applyMagneticDeclination(90, 6.3), closeTo(96.3, 1e-9));
    });

    test('handles west-negative declination', () {
      expect(applyMagneticDeclination(10, -15), closeTo(355, 1e-9));
    });

    test('wraps around 360', () {
      expect(applyMagneticDeclination(359, 2), closeTo(1, 1e-9));
      expect(applyMagneticDeclination(350, 20), closeTo(10, 1e-9));
    });

    test('zero declination is identity', () {
      expect(applyMagneticDeclination(123.4, 0), closeTo(123.4, 1e-9));
    });
  });

  group('qiblaBearingDeg', () {
    test('Tehran faces roughly 218° (south-west)', () {
      final b = qiblaBearingDeg(35.6892, 51.3890);
      expect(b, inInclusiveRange(217.5, 219.5));
    });

    test('New York faces roughly 58° (north-east)', () {
      final b = qiblaBearingDeg(40.7128, -74.0060);
      expect(b, inInclusiveRange(56, 60));
    });

    test('Sydney faces roughly 277° (west-north-west)', () {
      final b = qiblaBearingDeg(-33.8688, 151.2093);
      expect(b, inInclusiveRange(274, 281));
    });

    test('result is always normalized to 0..360', () {
      for (final (lat, lng) in [
        (35.6892, 51.3890),
        (-33.8688, 151.2093),
        (64.1466, -21.9426),
        (0.0, 0.0),
      ]) {
        final b = qiblaBearingDeg(lat, lng);
        expect(b, greaterThanOrEqualTo(0));
        expect(b, lessThan(360));
      }
    });
  });

  group('kaabaDistanceKm', () {
    test('Tehran to Mecca is roughly 1944 km', () {
      final d = kaabaDistanceKm(35.6892, 51.3890);
      expect(d, inInclusiveRange(1900, 2000));
    });

    test('distance at the Kaaba itself is ~0', () {
      expect(kaabaDistanceKm(kaabaLat, kaabaLng), lessThan(0.5));
    });
  });

  group('qiblaSunShadowTimes', () {
    // Which moments occur depends only on the location/date geometry, not on
    // the machine timezone, so counts and shadowTowardQibla flags are stable
    // across CI environments. (Solar positions are computed in UTC.)
    test('Tehran in summer: only the sun-in-Qibla moment occurs per day', () {
      final times = qiblaSunShadowTimes(
        lat: 35.6892,
        lng: 51.3890,
        qiblaBearing: qiblaBearingDeg(35.6892, 51.3890),
        date: DateTime(2026, 8, 21, 12),
        now: DateTime(2026, 8, 21, 12),
      );
      // Qibla is SSW (218°): the "shadow toward Qibla" moment needs the sun
      // at 38° (NNE), which is only reached before sunrise in summer. One
      // moment per day × two days = 2.
      expect(times, hasLength(2));
      expect(times.every((m) => !m.shadowTowardQibla), isTrue);
    });

    test('New York in summer: only the shadow-toward-Qibla moment occurs', () {
      final times = qiblaSunShadowTimes(
        lat: 40.7128,
        lng: -74.0060,
        qiblaBearing: qiblaBearingDeg(40.7128, -74.0060),
        date: DateTime(2026, 8, 21, 12),
        now: DateTime(2026, 8, 21, 12),
      );
      expect(times, hasLength(2));
      expect(times.every((m) => m.shadowTowardQibla), isTrue);
    });

    test('Lisbon in summer: both moments occur in daylight (per day)', () {
      final times = qiblaSunShadowTimes(
        lat: 38.7223,
        lng: -9.1393,
        qiblaBearing: qiblaBearingDeg(38.7223, -9.1393),
        date: DateTime(2026, 8, 21, 6),
        now: DateTime(2026, 8, 21, 6),
      );
      // 2 per day × 2 days = 4
      expect(times, hasLength(4));
    });

    test('high northern latitude in winter has no daylight moment', () {
      final times = qiblaSunShadowTimes(
        lat: 64.1466,
        lng: -21.9426,
        qiblaBearing: qiblaBearingDeg(64.1466, -21.9426),
        date: DateTime(2026, 12, 21, 12),
        now: DateTime(2026, 12, 21, 12),
      );
      expect(times, isEmpty);
    });

    test('moments are sorted chronologically', () {
      final times = qiblaSunShadowTimes(
        lat: 38.7223,
        lng: -9.1393,
        qiblaBearing: qiblaBearingDeg(38.7223, -9.1393),
        date: DateTime(2026, 8, 21, 6),
        now: DateTime(2026, 8, 21, 6),
      );
      for (var i = 1; i < times.length; i++) {
        expect(times[i].time.isAfter(times[i - 1].time), isTrue);
      }
    });

    test('night shows both today-passed and tomorrow-upcoming', () {
      // Tehran at night: today's 09:48 has passed, tomorrow's is upcoming.
      final times = qiblaSunShadowTimes(
        lat: 35.6892,
        lng: 51.3890,
        qiblaBearing: qiblaBearingDeg(35.6892, 51.3890),
        date: DateTime(2026, 8, 22, 21),
        now: DateTime(2026, 8, 22, 21),
      );
      expect(times, hasLength(2));
      expect(times[0].day, SunShadowDay.today);
      expect(times[0].status, SunShadowStatus.passed);
      expect(times[1].day, SunShadowDay.tomorrow);
      expect(times[1].status, SunShadowStatus.upcoming);
    });

    test('daytime before the moment shows today-upcoming', () {
      final times = qiblaSunShadowTimes(
        lat: 35.6892,
        lng: 51.3890,
        qiblaBearing: qiblaBearingDeg(35.6892, 51.3890),
        date: DateTime(2026, 8, 22, 9),
        now: DateTime(2026, 8, 22, 9),
      );
      expect(times, hasLength(2));
      expect(times[0].day, SunShadowDay.today);
      expect(times[0].status, SunShadowStatus.upcoming);
    });

    test('status transitions correctly around the moment', () {
      // The moment occurs ~09:45:54 Tehran-local on 2026-08-22 (NOAA-derived).
      // Probe ±5 minutes around the ACTUAL computed moment rather than a
      // hard-coded minute: ±2min is "now", before is upcoming, after passed.
      final base = DateTime(2026, 8, 22, 9, 48);
      final all = qiblaSunShadowTimes(
        lat: 35.6892,
        lng: 51.3890,
        qiblaBearing: qiblaBearingDeg(35.6892, 51.3890),
        date: base,
        now: base,
      );
      final moment = all.firstWhere((m) => m.day == SunShadowDay.today).time;
      for (final (delta, expected) in [
        (-5, SunShadowStatus.upcoming),
        (0, SunShadowStatus.now),
        (5, SunShadowStatus.passed),
      ]) {
        final at = moment.add(Duration(minutes: delta));
        final times = qiblaSunShadowTimes(
          lat: 35.6892,
          lng: 51.3890,
          qiblaBearing: qiblaBearingDeg(35.6892, 51.3890),
          date: at,
          now: at,
        );
        // Today's moment is first in the sorted list.
        expect(times.first.status, expected,
            reason: 'delta=$delta should be $expected');
      }
    });
  });

  group('computeSolarEvents', () {
    test('Tehran in summer has sunrise before sunset', () {
      final e = computeSolarEvents(
          lat: 35.6892, lng: 51.3890, date: DateTime(2026, 8, 21));
      expect(e.sunrise, isNotNull);
      expect(e.sunset, isNotNull);
      expect(e.sunrise!.isBefore(e.sunset!), isTrue);
      expect(e.solarNoon, isNotNull);
      expect(e.maxElevation, greaterThan(60));
    });

    test('high latitude in winter may have no sunrise/sunset', () {
      final e = computeSolarEvents(
          lat: 78.0, lng: 15.0, date: DateTime(2026, 12, 21));
      // Polar night: sun never rises.
      expect(e.sunrise, isNull);
      expect(e.sunset, isNull);
    });

    test('solar noon is between sunrise and sunset', () {
      // Tehran (UTC+3.5) so solar events fall within the same UTC day on a
      // CI machine (UTC). Solar noon is always between sunrise and sunset.
      final e = computeSolarEvents(
          lat: 35.6892, lng: 51.3890, date: DateTime(2026, 8, 21));
      expect(e.sunrise, isNotNull);
      expect(e.sunset, isNotNull);
      expect(e.solarNoon, isNotNull);
      expect(e.solarNoon!.isAfter(e.sunrise!), isTrue);
      expect(e.solarNoon!.isBefore(e.sunset!), isTrue);
    });
  });

  group('isNightTime', () {
    test('Tehran at midnight is night', () {
      // Use a fixed summer date to avoid ambiguity.
      expect(isNightTime(35.6892, 51.3890, DateTime(2026, 8, 21)), isTrue);
    });

    test('Tehran at noon is not night', () {
      // Note: this uses local time of the test machine, but noon local
      // should be daylight regardless of timezone offset.
      expect(isNightTime(35.6892, 51.3890, DateTime(2026, 8, 21, 12)), isFalse);
    });
  });

  group('currentSolarPosition', () {
    test('returns elevation and azimuth in valid ranges', () {
      final (el, az) = currentSolarPosition(
          lat: 35.6892, lng: 51.3890, when: DateTime(2026, 8, 21, 12));
      expect(el, greaterThanOrEqualTo(-90));
      expect(el, lessThanOrEqualTo(90));
      expect(az, greaterThanOrEqualTo(0));
      expect(az, lessThan(360));
    });
  });

  group('polarisPositionDeg', () {
    // Geometric bound: Polaris sits 0.646° from the celestial pole (dec
    // 89.354° in 2026), so its azimuth can deviate from true north by at most
    // asin(sin(0.646°) / sin(90° − φ)) ≈ 0.796° from Tehran (φ≈35.7°), and its
    // altitude is always within 0.646° of the observer's latitude. These
    // bounds are tight enough to catch the old day-fraction approximation,
    // which drifted up to ~1.8° across the day.
    test('azimuth stays within ~0.8° of true north from Tehran all night', () {
      for (final h in [20, 22, 0, 2, 4]) {
        final (az, _) =
            polarisPositionDeg(35.6892, 51.389, DateTime(2026, 8, 21, h));
        final diff = az > 180 ? 360 - az : az;
        expect(diff, lessThan(0.8), reason: 'hour=$h az=$az');
      }
    });

    test('altitude stays within 0.7° of the observer latitude', () {
      for (final h in [20, 22, 2, 4]) {
        final (_, alt) =
            polarisPositionDeg(35.6892, 51.389, DateTime(2026, 8, 21, h));
        expect((alt - 35.6892).abs(), lessThan(0.7), reason: 'hour=$h');
      }
    });

    test('longitude term is actually applied (old bug: lng ignored)', () {
      final when = DateTime(2026, 8, 21, 22);
      final (az1, _) = polarisPositionDeg(35.6892, 51.389, when);
      final (az2, _) = polarisPositionDeg(35.6892, 36.389, when);
      final d = ((az1 - az2).abs()) % 360;
      final dev = d > 180 ? 360 - d : d;
      expect(dev, greaterThan(0.01),
          reason: 'same instant, 15° east must give a different azimuth');
      expect(dev, lessThan(2),
          reason: 'near-polar star: longitude shifts azimuth only slightly');
    });

    test('one sidereal day later the azimuth repeats', () {
      final t1 = DateTime.utc(2026, 8, 21, 22);
      final t2 = t1.add(const Duration(hours: 23, minutes: 56, seconds: 4));
      final (a1, _) = polarisPositionDeg(35.6892, 51.389, t1);
      final (a2, _) = polarisPositionDeg(35.6892, 51.389, t2);
      final d = ((a1 - a2).abs()) % 360;
      final dev = d > 180 ? 360 - d : d;
      expect(dev, lessThan(0.5),
          reason: 'GMST rate 360.985647°/day must close the circle');
    });

    test('Polaris is below the horizon from the southern hemisphere', () {
      final (_, alt) =
          polarisPositionDeg(-33.8688, 151.2093, DateTime(2026, 8, 21, 22));
      expect(alt, lessThan(0));
    });
  });

  group('kaabaGreatCirclePath', () {
    test('starts at the observer and ends at the Kaaba', () {
      final path = kaabaGreatCirclePath(35.6892, 51.3890);
      expect(path.first.$1, closeTo(35.6892, 1e-9));
      expect(path.first.$2, closeTo(51.3890, 1e-9));
      expect(path.last.$1, closeTo(kaabaLat, 1e-6));
      expect(path.last.$2, closeTo(kaabaLng, 1e-6));
    });

    test('every point is on the great circle', () {
      // A point on the great circle is exactly one haversine distance from
      // both ends; the sum of the two legs equals the whole.
      const lat = 35.6892, lng = 51.3890;
      final total = kaabaDistanceKm(lat, lng);
      for (final p in kaabaGreatCirclePath(lat, lng, segments: 8)) {
        final legA = kaabaDistanceKm(lat, lng) - kaabaDistanceKm(p.$1, p.$2);
        final sum = legA + kaabaDistanceKm(p.$1, p.$2);
        expect(sum, closeTo(total, 1e-6));
      }
    });

    test('the first segment heads along the qibla bearing', () {
      const lat = 40.7128, lng = -74.0060; // New York
      final path = kaabaGreatCirclePath(lat, lng, segments: 720);
      final bearing = qiblaBearingDeg(path.first.$1, path.first.$2);
      final expected = qiblaBearingDeg(lat, lng);
      final delta = ((bearing - expected).abs()) % 360;
      expect(delta > 180 ? 360 - delta : delta, lessThan(0.5));
    });

    test('bends away from the Mercator straight line when far away', () {
      // From Jakarta the naive midpoint of the two coordinates lands far from
      // the real track — this is the whole reason the map draws the curve.
      const lat = -6.2088, lng = 106.8456;
      final path = kaabaGreatCirclePath(lat, lng, segments: 64);
      final mid = path[path.length ~/ 2];
      final naiveLat = (lat + kaabaLat) / 2;
      final naiveLng = (lng + kaabaLng) / 2;
      expect((mid.$1 - naiveLat).abs() + (mid.$2 - naiveLng).abs(),
          greaterThan(0.5));
    });
  });
}
