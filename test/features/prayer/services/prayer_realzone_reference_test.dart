import 'package:adhan/adhan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'noaa_solar_reference.dart';

/// Real-zone end-to-end regression — the complement of the LMT reference
/// table (`prayer_reference_table_test.dart` strips timezone data via LMT).
///
/// This file asserts the FULL user-visible path: the engine's per-date offset
/// plumbing inside real tz-database zones — DST on both hemispheres,
/// quarter-hour zones (+5:45, +12:45), and the changeover day itself, where a
/// midnight-anchored per-date offset lands on the wrong side of a 02:00/03:00
/// transition and shifts the whole day by an hour.
void main() {
  tzdata.initializeTimeZones();

  /// Muslim World League: Fajr 18°, Isha 17°, Dhuhr +1 min, Shafi Asr.
  CalculationParameters mwl() {
    final p = CalculationMethod.muslim_world_league.getParameters();
    p.madhab = Madhab.shafi;
    return p;
  }

  int minutesOfDay(DateTime t) => t.hour * 60 + t.minute;

  test('representative zones carry their expected offsets at local noon', () {
    Duration offsetAt(String zone, int y, int m, int d) =>
        tz.TZDateTime(tz.getLocation(zone), y, m, d, 12).timeZoneOffset;
    expect(
        offsetAt('Australia/Sydney', 2026, 1, 15), const Duration(hours: 11));
    expect(
        offsetAt('Australia/Sydney', 2026, 6, 21), const Duration(hours: 10));
    // Changeover day (2026-10-04 02:00 → 03:00): noon is already +11 — exactly
    // why the per-date offset must anchor at noon, not local midnight.
    expect(
        offsetAt('Australia/Sydney', 2026, 10, 4), const Duration(hours: 11));
    expect(offsetAt('America/Los_Angeles', 2026, 1, 15),
        const Duration(hours: -8));
    expect(offsetAt('America/Los_Angeles', 2026, 7, 15),
        const Duration(hours: -7));
    expect(
        offsetAt('America/Los_Angeles', 2026, 3, 8), const Duration(hours: -7));
    expect(offsetAt('Asia/Kabul', 2026, 3, 21),
        const Duration(hours: 4, minutes: 30));
    expect(offsetAt('Asia/Kathmandu', 2026, 3, 21),
        const Duration(hours: 5, minutes: 45));
    expect(offsetAt('Pacific/Chatham', 2026, 1, 15),
        const Duration(hours: 13, minutes: 45));
    expect(offsetAt('Pacific/Chatham', 2026, 7, 15),
        const Duration(hours: 12, minutes: 45));
  });

  const cases = [
    (
      name: 'سیدنی',
      lat: -33.8688,
      lng: 151.2093,
      zone: 'Australia/Sydney',
      dates: [
        (2026, 6, 21),
        (2026, 10, 3),
        (2026, 10, 4),
        (2026, 10, 5),
        (2026, 12, 21)
      ],
    ),
    (
      name: 'لس‌آنجلس',
      lat: 34.0522,
      lng: -118.2437,
      zone: 'America/Los_Angeles',
      dates: [
        (2026, 1, 15),
        (2026, 3, 7),
        (2026, 3, 8),
        (2026, 3, 9),
        (2026, 7, 15)
      ],
    ),
    (
      name: 'دبی',
      lat: 25.2048,
      lng: 55.2708,
      zone: 'Asia/Dubai',
      dates: [(2026, 3, 21)],
    ),
    (
      name: 'کابل',
      lat: 34.5553,
      lng: 69.2075,
      zone: 'Asia/Kabul',
      dates: [(2026, 3, 21)],
    ),
    (
      name: 'کاتماندو',
      lat: 27.7172,
      lng: 85.3240,
      zone: 'Asia/Kathmandu',
      dates: [(2026, 3, 21)],
    ),
    (
      name: 'جزیرهٔ چاتم',
      lat: -43.9597,
      lng: -176.5483,
      zone: 'Pacific/Chatham',
      dates: [(2026, 1, 15), (2026, 7, 15)],
    ),
  ];

  for (final c in cases) {
    group('${c.name} (${c.zone})', () {
      for (final (y, m, d) in c.dates) {
        test('$y-$m-$d matches the NOAA reference on the real zone clock', () {
          final offset =
              tz.TZDateTime(tz.getLocation(c.zone), y, m, d, 12).timeZoneOffset;
          final date = DateComponents(y, m, d);
          final pt = PrayerTimes(
            Coordinates(c.lat, c.lng),
            date,
            mwl(),
            utcOffset: offset,
          );

          final asrAlt =
              asrAltitudeDeg(c.lat, solarDeclination(fractionalYear(date)));
          // UTC reference minutes rendered on the zone's wall clock.
          int wall(double utcMinutes) =>
              ((utcMinutes + offset.inMinutes).round() % 1440 + 1440) % 1440;

          final checks = <String, (int actual, int expected, int tol)>{
            'fajr': (
              minutesOfDay(pt.fajr),
              wall(utcEventMinutes(
                  lat: c.lat,
                  lng: c.lng,
                  date: date,
                  altDeg: -18.0,
                  beforeNoon: true)),
              4,
            ),
            'sunrise': (
              minutesOfDay(pt.sunrise),
              wall(utcEventMinutes(
                  lat: c.lat,
                  lng: c.lng,
                  date: date,
                  altDeg: -0.8333,
                  beforeNoon: true)),
              3,
            ),
            'dhuhr': (
              minutesOfDay(pt.dhuhr),
              wall(utcNoonMinutes(lng: c.lng, date: date) + 1), // MWL +1
              3,
            ),
            'asr': (
              minutesOfDay(pt.asr),
              wall(utcEventMinutes(
                  lat: c.lat,
                  lng: c.lng,
                  date: date,
                  altDeg: asrAlt,
                  beforeNoon: false)),
              4,
            ),
            'maghrib': (
              minutesOfDay(pt.maghrib),
              wall(utcEventMinutes(
                  lat: c.lat,
                  lng: c.lng,
                  date: date,
                  altDeg: -0.8333,
                  beforeNoon: false)),
              3,
            ),
            'isha': (
              minutesOfDay(pt.isha),
              wall(utcEventMinutes(
                  lat: c.lat,
                  lng: c.lng,
                  date: date,
                  altDeg: -17.0,
                  beforeNoon: false)),
              4,
            ),
          };

          final failures = <String>[];
          checks.forEach((name, c2) {
            final drift = (c2.$1 - c2.$2).abs();
            if (drift > c2.$3) {
              failures.add('$name: engine ${c2.$1} vs reference ${c2.$2} '
                  '(drift $drift > ${c2.$3})');
            }
          });

          expect(failures, isEmpty,
              reason: '${c.name} on $y-$m-$d (zone offset $offset):\n'
                  '${failures.join('\n')}');
        });
      }
    });
  }

  test(
      'Sydney DST start (2026-10-04): dhuhr wall clock shifts +60 min at the changeover',
      () {
    DateTime dhuhrOn(int d) {
      final offset =
          tz.TZDateTime(tz.getLocation('Australia/Sydney'), 2026, 10, d, 12)
              .timeZoneOffset;
      return PrayerTimes(
        Coordinates(-33.8688, 151.2093),
        DateComponents(2026, 10, d),
        mwl(),
        utcOffset: offset,
      ).dhuhr;
    }

    final before = minutesOfDay(dhuhrOn(3));
    final during = minutesOfDay(dhuhrOn(4));
    final after = minutesOfDay(dhuhrOn(5));
    // The whole clock moves on the changeover, so solar noon's wall time
    // legitimately jumps by one hour — a ~0 jump means the engine used the
    // pre-DST offset for the whole day (the old midnight-anchored bug).
    expect(during - before, inInclusiveRange(57, 63),
        reason: 'dhuhr must shift +60 at the changeover: '
            'Oct 3 $before vs Oct 4 $during');
    expect((after - during).abs(), lessThanOrEqualTo(3),
        reason: 'dhuhr must drift normally after the changeover: '
            'Oct 4 $during vs Oct 5 $after');
  });

  test(
      'Los Angeles DST start (2026-03-08): dhuhr wall clock shifts +60 min at the changeover',
      () {
    DateTime dhuhrOn(int d) {
      final offset =
          tz.TZDateTime(tz.getLocation('America/Los_Angeles'), 2026, 3, d, 12)
              .timeZoneOffset;
      return PrayerTimes(
        Coordinates(34.0522, -118.2437),
        DateComponents(2026, 3, d),
        mwl(),
        utcOffset: offset,
      ).dhuhr;
    }

    final before = minutesOfDay(dhuhrOn(7));
    final during = minutesOfDay(dhuhrOn(8));
    final after = minutesOfDay(dhuhrOn(9));
    expect(during - before, inInclusiveRange(57, 63),
        reason: 'dhuhr must shift +60 at the changeover: '
            'Mar 7 $before vs Mar 8 $during');
    expect((after - during).abs(), lessThanOrEqualTo(3),
        reason: 'dhuhr must drift normally after the changeover: '
            'Mar 8 $during vs Mar 9 $after');
  });
}
