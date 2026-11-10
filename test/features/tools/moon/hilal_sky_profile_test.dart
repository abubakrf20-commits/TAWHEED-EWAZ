import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/moon/domain/services/astronomy/astronomy.dart';
import 'package:tawheeed/features/tools/moon/domain/services/astronomy/hilal_sky_profile.dart';

const tehranLat = 35.6892;
const tehranLng = 51.389;

void main() {
  group('HilalSkyProfile.sweep', () {
    test('sweep covers sunset±window with plausible altitudes', () {
      final samples = HilalSkyProfile.sweep(
        date: DateTime(2024, 3, 11), // شب رؤیت هلال رمضان ۱۴۴۵
        lat: tehranLat,
        lng: tehranLng,
      );
      expect(samples, isNotEmpty);
      // First sample is 30 min before sunset: sun still above horizon.
      expect(samples.first.sunAlt, greaterThan(0));
      // Some sample after sunset: sun below.
      expect(samples.any((s) => s.sunAlt < 0), isTrue);
      // Monotonic times.
      for (var i = 1; i < samples.length; i++) {
        expect(samples[i].time.isAfter(samples[i - 1].time), isTrue);
      }
      // Moon above the horizon for most of the evening (lag > 0 that night).
      final above = samples.where((s) => s.moonAlt > 0).length;
      expect(above, greaterThan(samples.length ~/ 2));
      // Altitudes bounded by physical limits.
      for (final s in samples) {
        expect(s.moonAlt, inInclusiveRange(-90, 90));
        expect(s.sunAlt, inInclusiveRange(-90, 90));
        expect(s.moonAz, inInclusiveRange(0, 360));
      }
    });

    test('sweep ends no later than sunset + 3h', () {
      final samples = HilalSkyProfile.sweep(
          date: DateTime(2024, 3, 11), lat: tehranLat, lng: tehranLng);
      final sunsetIdx = samples.indexWhere((s) => s.sunAlt <= 0);
      expect(sunsetIdx, greaterThan(0));
      final sunset = samples[sunsetIdx].time;
      final span = samples.last.time.difference(sunset);
      expect(span, lessThanOrEqualTo(const Duration(hours: 3, minutes: 5)));
    });

    test('polar day → empty sweep', () {
      // Midsummer at 78°N: no sunset.
      final samples = HilalSkyProfile.sweep(
        date: DateTime(2024, 6, 21),
        lat: 78.2,
        lng: 15.6,
      );
      expect(samples, isEmpty);
    });
  });

  group('HilalSkyProfile.horizonFix', () {
    test('fix at best time: moon up, sun just below horizon', () {
      final fix = HilalSkyProfile.horizonFix(
          date: DateTime(2024, 3, 11), lat: tehranLat, lng: tehranLng);
      expect(fix, isNotNull);
      expect(fix!.moonAlt, greaterThan(0));
      expect(fix.sunAlt, lessThan(0));
      expect(fix.sunAlt, greaterThan(-10));
      expect(fix.moonAz, inInclusiveRange(0, 360));
      expect(fix.relAz, inInclusiveRange(-180, 180));
      // Age of the crescent that evening was ~28–34 h (see hilal tests).
      expect(fix.ageHours, inInclusiveRange(20, 40));
    });

    test('relAz consistent with |moonAz − sunAz| wrapped', () {
      final fix = HilalSkyProfile.horizonFix(
          date: DateTime(2024, 3, 11), lat: tehranLat, lng: tehranLng);
      expect(fix, isNotNull);
      final raw = fix!.moonAz - fix.sunAz;
      final wrapped = raw > 180
          ? raw - 360
          : raw < -180
              ? raw + 360
              : raw;
      expect(fix.relAz, closeTo(wrapped, 1e-9));
    });

    test('parallax matches the moon geometry (0.5°–1.05°)', () {
      final fix = HilalSkyProfile.horizonFix(
          date: DateTime(2024, 3, 11), lat: tehranLat, lng: tehranLng);
      expect(fix!.parallax, inInclusiveRange(0.5, 1.05));
    });
  });

  group('regression: JD round trip unchanged', () {
    test('julianDay/fromJulianDay stability for sweep samples', () {
      final t = DateTime.utc(2024, 3, 11, 14, 40);
      final jd = Astronomy.julianDay(t);
      final back = Astronomy.fromJulianDay(jd);
      expect(back.difference(t).inSeconds.abs(), lessThan(2));
    });
  });
}
