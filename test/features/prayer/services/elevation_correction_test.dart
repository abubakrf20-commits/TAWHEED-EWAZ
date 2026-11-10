import 'package:flutter_test/flutter_test.dart';
import 'package:adhan/adhan.dart' as adhan;
import 'package:tawheeed/features/prayer/services/elevation_correction.dart';

void main() {
  group('horizonDipDegrees', () {
    test('zero at sea level or below', () {
      expect(ElevationCorrection.horizonDipDegrees(0), 0);
      expect(ElevationCorrection.horizonDipDegrees(-100), 0);
    });

    test('grows with altitude (~1°/km)', () {
      final dip500 = ElevationCorrection.horizonDipDegrees(500);
      final dip1000 = ElevationCorrection.horizonDipDegrees(1000);
      final dip2000 = ElevationCorrection.horizonDipDegrees(2000);
      expect(dip500, greaterThan(0));
      expect(dip1000, greaterThan(dip500));
      expect(dip2000, greaterThan(dip1000));
      // Physics: dip = arccos(R/(R+h)) → 1000 m ≈ 1.015°.
      expect(dip1000, closeTo(1.015, 0.01));
      // Monotone concave: doubling altitude less than doubles the dip.
      expect(dip2000 / dip1000, lessThan(1.5));
    });
  });

  group('solarAltitudeDeg consistency with the adhan engine', () {
    final coords = adhan.Coordinates(35.6892, 51.3890); // Tehran
    final params = adhan.CalculationMethod.muslim_world_league.getParameters();
    final pt = adhan.PrayerTimes(
      coords,
      adhan.DateComponents(2026, 6, 21),
      params,
    );

    // At the engine's own sunrise/sunset moments, our independent solar model
    // must see the sun at ≈ −0.833° (disk + refraction). This cross-checks
    // declination/EoT signs — a wrong sign would be off by tens of degrees.
    // Tolerance covers adhan's whole-minute rounding and its slightly
    // different refraction formula (observed residual ≈ ±0.08°).
    test('sunrise sits at −0.833°', () {
      final alt = ElevationCorrection.solarAltitudeDeg(
          pt.sunrise.toUtc(), 35.6892, 51.3890);
      expect(alt, closeTo(-0.833, 0.12));
    });

    test('sunset sits at −0.833°', () {
      final alt = ElevationCorrection.solarAltitudeDeg(
          pt.maghrib.toUtc(), 35.6892, 51.3890);
      expect(alt, closeTo(-0.833, 0.12));
    });

    test('noon is high above horizon', () {
      final alt = ElevationCorrection.solarAltitudeDeg(
          pt.dhuhr.toUtc(), 35.6892, 51.3890);
      expect(alt, greaterThan(70)); // Tehran in late June: ~76°
    });
  });

  group('computeAdjustments', () {
    final coords = adhan.Coordinates(35.6892, 51.3890); // Tehran ~1200 m
    final params = adhan.CalculationMethod.muslim_world_league.getParameters();
    final pt = adhan.PrayerTimes(
      coords,
      adhan.DateComponents(2026, 3, 20),
      params,
    );

    test('null at sea level', () {
      final r = ElevationCorrection.computeAdjustments(
        uncorrectedSunrise: pt.sunrise,
        uncorrectedMaghrib: pt.maghrib,
        latitude: 35.6892,
        longitude: 51.3890,
        altitudeMeters: 0,
      );
      expect(r, isNull);
    });

    test('Tehran at ~1200 m: sunrise earlier, maghrib later (~±4 min)', () {
      final r = ElevationCorrection.computeAdjustments(
        uncorrectedSunrise: pt.sunrise,
        uncorrectedMaghrib: pt.maghrib,
        latitude: 35.6892,
        longitude: 51.3890,
        altitudeMeters: 1200,
      );
      expect(r, isNotNull);
      expect(r!.sunriseMinutes, lessThan(-2)); // earlier
      expect(r.sunriseMinutes, greaterThan(-7));
      expect(r.maghribMinutes, greaterThan(2)); // later
      expect(r.maghribMinutes, lessThan(7));
      expect(r.maghribMinutes, closeTo(-r.sunriseMinutes, 1));
    });

    test('angle-defined maghrib (Tehran −4.5°) is left untouched', () {
      // Regression for the elevation override: Tehran defines Maghrib by a
      // fixed depression angle, not the visual horizon, so horizon dip must
      // NOT pull it back to sunset. Sunrise still gets corrected.
      final tehranParams = adhan.CalculationMethod.tehran.getParameters();
      expect(tehranParams.maghribAngle, 4.5);
      final tehranPt = adhan.PrayerTimes(
        coords,
        adhan.DateComponents(2026, 3, 20),
        tehranParams,
      );

      final r = ElevationCorrection.computeAdjustments(
        uncorrectedSunrise: tehranPt.sunrise,
        uncorrectedMaghrib: tehranPt.maghrib,
        latitude: 35.6892,
        longitude: 51.3890,
        altitudeMeters: 1200,
        maghribAngle: tehranParams.maghribAngle,
      )!;

      expect(r.maghribMinutes, 0); // official Maghrib preserved
      expect(r.sunriseMinutes, lessThan(-2)); // sunrise still corrected

      // And the preserved Maghrib genuinely sits at the method's −4.5° angle,
      // confirming we skipped an angle event rather than a no-op call.
      final altSet = ElevationCorrection.solarAltitudeDeg(
          tehranPt.maghrib.toUtc(), 35.6892, 51.3890);
      expect(altSet, closeTo(-4.5, 0.2));

      // Contrast: with the same inputs but the default (visual) Maghrib,
      // elevation still applies a non-zero correction.
      final visual = ElevationCorrection.computeAdjustments(
        uncorrectedSunrise: tehranPt.sunrise,
        uncorrectedMaghrib: tehranPt.maghrib,
        latitude: 35.6892,
        longitude: 51.3890,
        altitudeMeters: 1200,
      )!;
      expect(visual.maghribMinutes, isNot(0));
    });

    test('solved times actually sit on the dipped horizon', () {
      const alt = 1200.0;
      final dip = ElevationCorrection.horizonDipDegrees(alt);
      final target = -0.833 - dip;
      final r = ElevationCorrection.computeAdjustments(
        uncorrectedSunrise: pt.sunrise,
        uncorrectedMaghrib: pt.maghrib,
        latitude: 35.6892,
        longitude: 51.3890,
        altitudeMeters: alt,
      )!;
      final newSunrise = pt.sunrise.add(Duration(minutes: r.sunriseMinutes));
      final newMaghrib = pt.maghrib.add(Duration(minutes: r.maghribMinutes));
      final altRise = ElevationCorrection.solarAltitudeDeg(
          newSunrise.toUtc(), 35.6892, 51.3890);
      final altSet = ElevationCorrection.solarAltitudeDeg(
          newMaghrib.toUtc(), 35.6892, 51.3890);
      // Rounding to whole minutes leaves ≤ ~0.15° residual.
      expect(altRise, closeTo(target, 0.15));
      expect(altSet, closeTo(target, 0.15));
    });

    test('user maghrib offset still applies alongside the dip correction', () {
      // Regression guard for «تنظیم اذان کار نمی‌کند وقتی تصحیح فعال است»:
      // the dip delta must ADD to the user's manual offsets, not replace them.
      final params =
          adhan.CalculationMethod.muslim_world_league.getParameters();
      final coords = adhan.Coordinates(35.6892, 51.3890);
      final date = adhan.DateComponents(2026, 3, 20);

      // Raw times without any adjustment.
      final raw = adhan.PrayerTimes(coords, date, params);
      // User's own offset alone.
      params.adjustments = adhan.PrayerAdjustments(maghrib: 2);
      final offsetOnly = adhan.PrayerTimes(coords, date, params);
      expect(offsetOnly.maghrib.difference(raw.maghrib).inMinutes, 2);
      // Dip correction on TOP of the user's offset.
      params.adjustments.sunrise += -4;
      params.adjustments.maghrib += 4;
      final both = adhan.PrayerTimes(coords, date, params);
      expect(both.maghrib.difference(raw.maghrib).inMinutes, 6);
      expect(both.sunrise.difference(raw.sunrise).inMinutes, -4);
    });
  });
}
