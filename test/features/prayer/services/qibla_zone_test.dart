import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/prayer/services/qibla_math.dart';
import 'package:tawheeed/features/prayer/services/qibla_zone.dart';

void main() {
  group('resolveQiblaZone — nearest-city ladder', () {
    test('Tehran coordinates resolve to Asia/Tehran', () {
      final z = resolveQiblaZone(lat: 35.6892, lng: 51.3890, settingsTimezone: 'Europe/Paris');
      expect(z.zoneId, 'Asia/Tehran');
    });

    test('Sydney coordinates resolve to its own IANA zone', () {
      final z = resolveQiblaZone(lat: -33.8688, lng: 151.2093, settingsTimezone: 'Asia/Tehran');
      expect(z.zoneId, 'Australia/Sydney');
    });

    test('far-away coordinates fall back to the settings zone', () {
      final z = resolveQiblaZone(lat: 0.0, lng: 0.0, settingsTimezone: 'Europe/London');
      expect(z.zoneId, 'Europe/London');
    });

    test('nothing resolvable falls back to the device offset', () {
      final z = resolveQiblaZone(lat: 0.0, lng: 0.0, settingsTimezone: null);
      expect(z.zoneId, isNull);
      final off =
          z.offsetMinutesForWallDate(DateTime(2026, 8, 21));
      expect(off, DateTime(2026, 8, 21, 12).timeZoneOffset.inMinutes);
    });
  });

  group('ResolvedQiblaZone — DST and odd offsets', () {
    final london = qiblaZoneById('Europe/London');
    final sydney = qiblaZoneById('Australia/Sydney');
    final kathmandu = qiblaZoneById('Asia/Kathmandu');

    test('London: +60 in July, 0 in December', () {
      expect(
          london.offsetMinutesForWallDate(DateTime(2026, 7, 21)), 60);
      expect(
          london.offsetMinutesForWallDate(DateTime(2026, 12, 21)), 0);
    });

    test('Sydney: +660 in January (AEDT), +600 in June (AEST)', () {
      expect(
          sydney.offsetMinutesForWallDate(DateTime(2026, 1, 15)), 660);
      expect(
          sydney.offsetMinutesForWallDate(DateTime(2026, 6, 15)), 600);
    });

    test('Kathmandu: the +05:45 zone', () {
      expect(
          kathmandu.offsetMinutesForWallDate(DateTime(2026, 8, 21)), 345);
    });

    test('wallOf converts an instant onto the zone clock', () {
      // 12:00 UTC on 2026-08-21 = 12:30 Tehran (legacy +3:30 summer… Iran has
      // no DST since 2022 — +210 all year) = 13:00 London (BST).
      final instant = DateTime.utc(2026, 8, 21, 12);
      expect(london.wallOf(instant).hour, 13);
      final tehran = qiblaZoneById('Asia/Tehran');
      expect(tehran.wallOf(instant).minute, 30);
    });
  });

  group('computeSolarEvents — times on the TARGET location clock', () {
    /// B1 evidence: on a Tehran-coordinate device, sunrise must print as
    /// Tehran wall time (~06:06), never the UTC fields (02:36) the old
    /// always-zero offset produced.
    test('Tehran in summer: sunrise ≈ 06:xx, solar noon ≈ 11:5x', () {
      final zone = qiblaZoneById('Asia/Tehran');
      final off = zone.offsetMinutesForWallDate(DateTime(2026, 8, 21));
      final e = computeSolarEvents(
          lat: 35.6892, lng: 51.3890, date: DateTime(2026, 8, 21),
          tzOffsetMinutes: off);
      expect(e.sunrise, isNotNull);
      // 2026-08-21 Tehran: sunrise 06:07 ± acceptance window; the OLD bug
      // printed 02:36 (UTC fields), so hour must be 5..7.
      expect(e.sunrise!.hour, inInclusiveRange(5, 7));
      expect(e.solarNoon, isNotNull);
      // Solar noon in Tehran in late August ≈ 11:54–12:04 — the old bug
      // printed 08:24 (UTC fields).
      expect(e.solarNoon!.hour, inInclusiveRange(11, 12));
      expect(e.sunrise!.isBefore(e.sunset!), isTrue);
      expect(e.maxElevation, greaterThan(60));
    });

    test('London in July (BST +60): sunrise in the past-5 wall hour', () {
      final zone = qiblaZoneById('Europe/London');
      final off = zone.offsetMinutesForWallDate(DateTime(2026, 7, 21));
      final e = computeSolarEvents(
          lat: 51.5074, lng: -0.1278, date: DateTime(2026, 7, 21),
          tzOffsetMinutes: off);
      expect(e.sunrise, isNotNull);
      // London 2026-07-21 sunrise ≈ 05:10 BST, sunset ≈ 21:0x.
      expect(e.sunrise!.hour, inInclusiveRange(5, 5));
      expect(e.sunset!.hour, inInclusiveRange(20, 21));
    });

    test('London in December (GMT +0): late sunrise, early sunset', () {
      final zone = qiblaZoneById('Europe/London');
      final off = zone.offsetMinutesForWallDate(DateTime(2026, 12, 21));
      final e = computeSolarEvents(
          lat: 51.5074, lng: -0.1278, date: DateTime(2026, 12, 21),
          tzOffsetMinutes: off);
      expect(e.sunrise, isNotNull);
      // London winter solstice sunrise ≈ 08:04, sunset ≈ 15:53 — DST-blind
      // code (fixed +60) would print 07:04 / 14:53.
      expect(e.sunrise!.hour, inInclusiveRange(8, 8));
      expect(e.sunset!.hour, inInclusiveRange(15, 15));
    });

    test('Kathmandu (+05:45): solar noon within window, morning hours correct',
        () {
      final zone = qiblaZoneById('Asia/Kathmandu');
      final off = zone.offsetMinutesForWallDate(DateTime(2026, 8, 21));
      final e = computeSolarEvents(
          lat: 27.7172, lng: 85.3240, date: DateTime(2026, 8, 21),
          tzOffsetMinutes: off);
      expect(e.sunrise, isNotNull);
      // Kathmandu 2026-08-21 sunrise ≈ 05:47 NPT (+5:45) — a mod-1440 or
      // zero-offset bug prints misleading hours.
      expect(e.sunrise!.hour, inInclusiveRange(5, 6));
      expect(e.solarNoon!.hour, inInclusiveRange(11, 13));
      expect(e.sunrise!.isBefore(e.sunset!), isTrue);
    });

    test('Sydney in January (+600): southern summer SolarNoon ≈ 13:0x', () {
      final zone = qiblaZoneById('Australia/Sydney');
      final off = zone.offsetMinutesForWallDate(DateTime(2026, 1, 15));
      final e = computeSolarEvents(
          lat: -33.8688, lng: 151.2093, date: DateTime(2026, 1, 15),
          tzOffsetMinutes: off);
      expect(e.sunrise, isNotNull);
      // Sydney 2026-01-15 sunrise ≈ 05:52 AEDT, noon ≈ 13:04.
      expect(e.sunrise!.hour, inInclusiveRange(5, 6));
      expect(e.solarNoon!.hour, inInclusiveRange(12, 13));
      expect(e.maxElevation, greaterThan(70));
    });

    test('round-trip (southern): moment wall − zone offset equals the UTC instant',
        () {
      // Cape Town (−33.92, 18.42) gets BOTH daylight moments in summer — its
      // sun walks the azimuth BOTH ways through the day. Sydney never does
      // (its qibla is WNW, outside the sun's daylight azimuth range).
      final zone = qiblaZoneById('Africa/Johannesburg');
      final off = zone.offsetMinutesForWallDate(DateTime(2026, 1, 15));
      const lat = -33.9249, lng = 18.4241;
      final times = qiblaSunShadowTimes(
        lat: lat,
        lng: lng,
        qiblaBearing: qiblaBearingDeg(lat, lng),
        date: DateTime(2026, 1, 15),
        now: DateTime(2026, 1, 15),
        tzOffsetMinutes: off,
      );
      expect(times, isNotEmpty);
      final wall = times.first.time;
      final expectedInstant = wall.subtract(Duration(minutes: off));
      expect(times.first.utcInstant,
          DateTime.utc(expectedInstant.year, expectedInstant.month,
              expectedInstant.day, expectedInstant.hour,
              expectedInstant.minute, expectedInstant.second));
    });
  });

  group('qiblaSunShadowTimes — statuses across zones use true instants', () {
    test('wall clock ≠ device clock: the countdown never inverts', () {
      // A Tehran location computed on a device-independent basis: the moment's
      // wall time and the "now" reference are both resolved in the SAME zone,
      // so the status matches what a wall-vs-wall comparison on that zone
      // would give.
      final zone = qiblaZoneById('Asia/Tehran');
      final off = zone.offsetMinutesForWallDate(DateTime(2026, 8, 22));
      final nowWall = DateTime(2026, 8, 22, 9, 30);
      final nowInstant = DateTime.utc(2026, 8, 22, 9, 30)
          .subtract(const Duration())
          .add(const Duration()); // placeholder, replaced below
      // True instant of the Tehran wall 09:30:
      final realNow = DateTime.utc(2026, 8, 22, 6);
      expect(nowWall.subtract(Duration(minutes: off)), isNotNull);
      final times = qiblaSunShadowTimes(
        lat: 35.6892,
        lng: 51.3890,
        qiblaBearing: qiblaBearingDeg(35.6892, 51.3890),
        date: nowWall,
        now: realNow,
        tzOffsetMinutes: off,
      );
      // 09:30 Tehran wall = 06:00 UTC; the ~09:45:54 wall moment is ahead
      // (06:15:54 UTC) → upcoming, not "passed" (a UTC-vs-wall comparison
      // would wrongly declare it past at 09:30 device-UTC).
      expect(times.first.status, SunShadowStatus.upcoming);
      expect((nowInstant).isUtc, isTrue);
    });
  });

  group('isNightTime — respects the resolved zone', () {
    test('Tehran noon wall is day / midnight wall is night (+3:30 zone)',
        () {
      final zone = qiblaZoneById('Asia/Tehran');
      final off = zone.offsetMinutesForWallDate(DateTime(2026, 8, 21));
      expect(isNightTime(35.6892, 51.3890, DateTime(2026, 8, 21, 12),
          tzOffsetMinutes: off), isFalse);
      expect(isNightTime(35.6892, 51.3890, DateTime(2026, 8, 21),
          tzOffsetMinutes: off), isTrue);
    });

    test('Kathmandu noon wall (14:00 real UTC era) is day', () {
      final zone = qiblaZoneById('Asia/Kathmandu');
      final off = zone.offsetMinutesForWallDate(DateTime(2026, 8, 21));
      expect(isNightTime(27.7172, 85.3240, DateTime(2026, 8, 21, 12),
          tzOffsetMinutes: off), isFalse);
    });
  });

  group('B5 — sun-sign azimuth consistency at the computed instant', () {
    /// At each computed "shadow toward Qibla" moment the sun must sit exactly
    /// 180° opposite the Qibla bearing (the shadow then points TO the Kaaba,
    /// as the instruction promises); at the "sun in Qibla" moment the azimuth
    /// equals the bearing. Tolerance 0.5° per the master task.
    final cities = <(String, double, double, String)>[
      ('Tehran', 35.6892, 51.3890, 'Asia/Tehran'),
      ('London', 51.5074, -0.1278, 'Europe/London'),
      ('New York', 40.7128, -74.0060, 'America/New_York'),
      ('Kathmandu', 27.7172, 85.3240, 'Asia/Kathmandu'),
    ];

    double azDelta(double a, double b) {
      final d = (a - b).abs() % 360;
      return d > 180 ? 360 - d : d;
    }

    for (final (name, lat, lng, zoneId) in cities) {
      test('$name: azimuth matches its target within 0.5°', () {
        final zone = qiblaZoneById(zoneId);
        for (final probeDay in [
          DateTime(2026, 3, 21),
          DateTime(2026, 8, 21),
          DateTime(2026, 12, 21),
        ]) {
          final bearing = qiblaBearingDeg(lat, lng);
          final off = zone.offsetMinutesForWallDate(probeDay);
          final times = qiblaSunShadowTimes(
            lat: lat,
            lng: lng,
            qiblaBearing: bearing,
            date: probeDay,
            now: probeDay,
            tzOffsetMinutes: off,
          );
          for (final m in times.where((m) => m.day == SunShadowDay.today)) {
            final target = m.shadowTowardQibla
                ? (bearing + 180) % 360
                : bearing % 360;
            final (el, az) = currentSolarPosition(
              lat: lat,
              lng: lng,
              when: m.time,
              tzOffsetMinutes: off,
            );
            expect(el, greaterThan(0),
                reason: '$name $probeDay: moment ${m.time} below horizon');
            expect(azDelta(az, target), lessThan(0.5),
                reason:
                    '$name $probeDay: az $az vs target $target at ${m.time}');
          }
        }
      });
    }
  });
}
