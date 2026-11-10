import 'package:adhan/adhan.dart' as adhan;
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_helpers.dart';

void main() {
  group('formatTime', () {
    test('null returns placeholder', () {
      expect(formatTime(null), '--:--');
    });

    test('pads hour and minute', () {
      expect(formatTime(DateTime(2026, 7, 10, 5, 5)), '05:05');
      expect(formatTime(DateTime(2026, 7, 10, 23, 59)), '23:59');
    });

    test('preserves wall-clock fields from an offset-tagged value', () {
      final offsetTagged = DateTime.utc(2026, 7, 10, 18, 30);
      expect(wallClockTime(offsetTagged), DateTime(2026, 7, 10, 18, 30));
      expect(formatTime(offsetTagged), '18:30');
    });

    test('converts an offset-tagged wall time to the correct epoch', () {
      final wall = DateTime.utc(2026, 7, 10, 18, 30);
      final expected = DateTime.utc(2026, 7, 10, 15).millisecondsSinceEpoch;
      expect(
        wallClockEpochMillis(wall,
            utcOffset: const Duration(hours: 3, minutes: 30)),
        expected,
      );
    });
  });

  group('formatTime12', () {
    test('null returns placeholder', () {
      expect(formatTime12(null), '--:--');
    });

    test('morning uses صبح', () {
      expect(formatTime12(DateTime(2026, 7, 10, 5, 30)), '05:30 صبح');
    });

    test('noon stays 12', () {
      expect(formatTime12(DateTime(2026, 7, 10, 12)), '12:00 بعد از ظهر');
    });

    test('afternoon preserves the wall-clock hour', () {
      expect(
          formatTime12(DateTime.utc(2026, 7, 10, 18, 45)), '06:45 بعد از ظهر');
    });

    test('midnight shows 12', () {
      expect(formatTime12(DateTime.utc(2026, 7, 10)), '12:00 صبح');
    });
  });

  group('formatTimeStr / formatTimeStr12', () {
    test('pads values', () {
      expect(formatTimeStr(5, 5), '05:05');
      expect(formatTimeStr(23, 59), '23:59');
    });

    test('12-hour form', () {
      expect(formatTimeStr12(8, 15), '08:15 صبح');
      expect(formatTimeStr12(13, 0), '01:00 بعد از ظهر');
    });
  });

  group('PrayerTimesX', () {
    final date = DateTime(2026, 7, 10);
    adhan.PrayerTimes make() {
      final coords = adhan.Coordinates(35.6892, 51.3890);
      final params =
          adhan.CalculationMethod.muslim_world_league.getParameters();
      return adhan.PrayerTimes(coords, adhan.DateComponents.from(date), params);
    }

    test('allTimes contains all keys with formatted values', () {
      final pt = make();
      final times = pt.allTimes(adhan.SunnahTimes(pt));
      expect(times['فجر'], isNotNull);
      expect(times['طلوع'], isNotNull);
      expect(times['ظهر'], isNotNull);
      expect(times['عصر'], isNotNull);
      expect(times['مغرب'], isNotNull);
      expect(times['عشاء'], isNotNull);
      expect(times['fajr'], times['فجر']);
    });

    test('isPrayerPassed returns false for past-only names safely', () {
      final pt = make();
      // No prayer is passed yet because everything is in the future relative
      // to this synthetic date only if we test a known past time.
      expect(pt.isPrayerPassed('unknown'), false);
    });
  });

  group('currentPeriodLabel', () {
    // MASTER_REVIEW P1-1: the pre-Fajr window used to be reported as a prayer
    // period, so the dashboard highlighted the wrong row. The label must be
    // one of the seven periods the dashboard maps, and شب/Fajr must be
    // reported for the right windows.
    test('is always one of the seven periods the dashboard can map', () {
      final now = DateTime.now();
      final coords = adhan.Coordinates(35.6892, 51.3890);
      final params =
          adhan.CalculationMethod.muslim_world_league.getParameters();
      final pt =
          adhan.PrayerTimes(coords, adhan.DateComponents.from(now), params);

      const known = [
        'شب',
        'فجر',
        'اشراق و صبح',
        'ظهر',
        'عصر',
        'مغرب',
        'عشاء',
      ];
      final label = pt.currentPeriodLabel;
      expect(known, contains(label), reason: 'unmappable label: $label');

      // Window checks derived from the very same instant.
      if (now.isBefore(pt.wallFajr)) {
        expect(label, 'شب', reason: 'pre-Fajr must be شب, not a prayer');
      } else if (now.isBefore(pt.wallSunrise)) {
        expect(label, 'فجر');
      } else if (now.isBefore(pt.wallDhuhr)) {
        expect(label, 'اشراق و صبح');
      }
    });
  });

  group('nextAdhanFor', () {
    // Fixed times: فجر 04:00، طلوع 05:30، ظهر 12:10، عصر 15:45، مغرب 19:20،
    // عشاء 20:40 — sunrise sits between fajr and dhuhr and must NEVER be the
    // countdown target (the app, widget and preview must agree on the next
    // adhan, not «طلوع آفتاب»).
    final fajr = DateTime(2026, 7, 10, 4);
    final dhuhr = DateTime(2026, 7, 10, 12, 10);
    final asr = DateTime(2026, 7, 10, 15, 45);
    final maghrib = DateTime(2026, 7, 10, 19, 20);
    final isha = DateTime(2026, 7, 10, 20, 40);

    test("night: after isha wraps to tomorrow's fajr", () {
      final (name, time) = nextAdhanFor(
        DateTime(2026, 7, 10, 23, 30),
        fajr,
        dhuhr,
        asr,
        maghrib,
        isha,
      );
      expect(name, 'اذان صبح');
      expect(time, DateTime(2026, 7, 11, 4));
    });

    test('between fajr and sunrise → next is dhuhr, not sunrise', () {
      final (name, time) = nextAdhanFor(
        DateTime(2026, 7, 10, 5), // fajr passed, sunrise (05:30) ahead
        fajr,
        dhuhr,
        asr,
        maghrib,
        isha,
      );
      expect(name, 'اذان ظهر');
      expect(time, dhuhr);
    });

    test('between sunrise and dhuhr → next is dhuhr', () {
      final (name, time) = nextAdhanFor(
        DateTime(2026, 7, 10, 6, 30),
        fajr,
        dhuhr,
        asr,
        maghrib,
        isha,
      );
      expect(name, 'اذان ظهر');
      expect(time, dhuhr);
    });

    test('between dhuhr and asr → next is asr', () {
      final (name, time) = nextAdhanFor(
        DateTime(2026, 7, 10, 13),
        fajr,
        dhuhr,
        asr,
        maghrib,
        isha,
      );
      expect(name, 'اذان عصر');
      expect(time, asr);
    });

    test("before fajr → next is today's fajr", () {
      final (name, time) = nextAdhanFor(
        DateTime(2026, 7, 10, 3),
        fajr,
        dhuhr,
        asr,
        maghrib,
        isha,
      );
      expect(name, 'اذان صبح');
      expect(time, fajr);
    });
  });
}
