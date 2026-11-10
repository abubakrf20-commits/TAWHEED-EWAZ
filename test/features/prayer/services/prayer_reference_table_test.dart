import 'package:adhan/adhan.dart';
import 'package:flutter_test/flutter_test.dart';

import 'noaa_solar_reference.dart';

/// Phase-6 audit — prayer times vs an INDEPENDENT reference table.
///
/// `prayer_worldwide_times_test.dart` already cross-checks Dhuhr against NOAA's
/// equation of time for every offline place. This file closes the remaining gap:
/// the prayer-DEFINING angles (Fajr −18°, sunrise/maghrib −0.833°, Isha −17°,
/// Asr shadow ratio) are verified at three representative latitudes against a
/// from-scratch NOAA solar-position solver, so the engine is checked against
/// something other than itself.
///
/// Latitudes are kept ≤ 41°N so astronomical Fajr/Isha exist on every test date
/// (above ~48°N the summer sun never reaches −18°, and adhan's high-latitude rule
/// intentionally deviates from pure twilight — out of scope for this reference).
///
/// Times are compared under LOCAL MEAN TIME (`utcOffset = 4 min × longitude`),
/// which removes timezone data from the assertion entirely: under LMT, solar
/// noon is 12:00 − EoT and every event is noon ± (hour-angle × 4 min).
void main() {
  /// Muslim World League: Fajr 18°, Isha 17°, Dhuhr +1 min, Shafi Asr.
  CalculationParameters mwl() {
    final p = CalculationMethod.muslim_world_league.getParameters();
    p.madhab = Madhab.shafi;
    return p;
  }

  /// Three latitudes spanning the app's core range: tropical, mid, high-mid.
  const places = [
    (name: 'مکه', lat: 21.4225, lng: 39.8262),
    (name: 'تهران', lat: 35.6892, lng: 51.3890),
    (name: 'استانبول', lat: 41.0082, lng: 28.9784),
  ];

  /// Two equinoxes and two solstices — the seasonal extremes of declination.
  final dates = [
    DateComponents(2026, 3, 20),
    DateComponents(2026, 6, 21),
    DateComponents(2026, 9, 22),
    DateComponents(2026, 12, 21),
  ];

  int minutesOfDay(DateTime t) => t.hour * 60 + t.minute;

  for (final place in places) {
    group('${place.name} (${place.lat}°N)', () {
      for (final date in dates) {
        test('${date.year}-${date.month}-${date.day} matches NOAA reference',
            () {
          final lmt = Duration(minutes: (place.lng * 4).round());
          final engine = PrayerTimes(
            Coordinates(place.lat, place.lng),
            date,
            mwl(),
            utcOffset: lmt,
          );

          final ref =
              referenceTimes(lat: place.lat, lng: place.lng, date: date);

          // Dhuhr carries the method's own +1 min adjustment; the rest are the
          // raw solar events. Tolerances absorb the ~1 min gap between NOAA's
          // low-precision series and adhan's full Astronomical Algorithms.
          final checks = <String, (int actual, int expected, int tol)>{
            'fajr': (minutesOfDay(engine.fajr), ref.fajr, 4),
            'sunrise': (minutesOfDay(engine.sunrise), ref.sunrise, 3),
            'dhuhr': (minutesOfDay(engine.dhuhr), ref.dhuhr, 3),
            'asr': (minutesOfDay(engine.asr), ref.asr, 4),
            'maghrib': (minutesOfDay(engine.maghrib), ref.maghrib, 3),
            'isha': (minutesOfDay(engine.isha), ref.isha, 4),
          };

          final failures = <String>[];
          checks.forEach((name, c) {
            final drift = (c.$1 - c.$2).abs();
            if (drift > c.$3) {
              failures.add('$name: engine ${c.$1} vs reference ${c.$2} '
                  '(drift $drift > ${c.$3})');
            }
          });

          expect(failures, isEmpty,
              reason:
                  '${place.name} on ${date.year}-${date.month}-${date.day}:\n'
                  '${failures.join('\n')}');
        });
      }
    });
  }
}
