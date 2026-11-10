import 'package:adhan/adhan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Phase-6 audit — prayer-time TIMEZONE resolution.
///
/// Commit 357bc4d ("resolve prayer times in the device's real timezone") fixed
/// a religious-impact bug: `settings.timezone` was frozen at `Asia/Tehran`
/// because the only adoption path read `DateTime.now().timeZoneName`, which is
/// never a valid Olson id on Android. Every consumer (repo, home widget,
/// notifications, offline cache) keys off that one zone, so a user in Dubai
/// (+4:00) or Kabul (+4:30) saw times skewed by the gap to Tehran (+3:30).
///
/// The fix has two halves, both exercised here at the same layer the repo
/// implements them (`PrayerRepositoryImpl._getTzLocation` +
/// `_offsetForDate`), because that logic is pure `timezone`-package resolution
/// and needs no secure storage, GPS or network:
///
///   1. honour `settings.timezone` (the device's real Olson zone), falling back
///      to Tehran ONLY when the id does not parse;
///   2. resolve the offset FOR THE TARGET DATE, not for "now", so a date across
///      a DST boundary is not shifted by an hour.
///
/// [resolveOffset] is a verbatim mirror of those two private methods.
void main() {
  tzdata.initializeTimeZones();

  /// Mirror of `_getTzLocation`: honour the stored zone, Tehran on parse error.
  tz.Location resolveLocation(String? stored) {
    final name = stored ?? 'Asia/Tehran';
    try {
      return tz.getLocation(name);
    } catch (_) {
      return tz.getLocation('Asia/Tehran');
    }
  }

  /// Mirror of `_offsetForDate`: the zone's offset ON [date], not on now().
  Duration resolveOffset(String? stored, DateTime date) =>
      tz.TZDateTime.from(date, resolveLocation(stored)).timeZoneOffset;

  final winter = DateTime(2026, 1, 15);
  final summer = DateTime(2026, 7, 15);

  group('Tehran (the frozen default) is stable year-round — no DST', () {
    test('always +3:30 in winter and summer', () {
      expect(resolveOffset('Asia/Tehran', winter),
          const Duration(hours: 3, minutes: 30));
      expect(resolveOffset('Asia/Tehran', summer),
          const Duration(hours: 3, minutes: 30));
    });
  });

  group('real foreign zones resolve to their own clock, not Tehran', () {
    test('Gulf / Afghanistan / Pakistan / Turkey offsets', () {
      expect(resolveOffset('Asia/Dubai', winter), const Duration(hours: 4));
      expect(resolveOffset('Asia/Kabul', winter),
          const Duration(hours: 4, minutes: 30));
      expect(resolveOffset('Asia/Karachi', winter), const Duration(hours: 5));
      expect(
          resolveOffset('Europe/Istanbul', winter), const Duration(hours: 3));
    });

    test('none of them accidentally equal Tehran (+3:30)', () {
      for (final zone in [
        'Asia/Dubai',
        'Asia/Kabul',
        'Asia/Karachi',
        'Europe/Istanbul'
      ]) {
        expect(resolveOffset(zone, winter),
            isNot(const Duration(hours: 3, minutes: 30)),
            reason: '$zone must not be pinned to Tehran');
      }
    });
  });

  group('offset is per-DATE, so DST zones shift correctly across the year', () {
    test('London: GMT in winter, BST (+1) in summer', () {
      expect(resolveOffset('Europe/London', winter), Duration.zero);
      expect(resolveOffset('Europe/London', summer), const Duration(hours: 1));
    });

    test('New York: EST (-5) in winter, EDT (-4) in summer', () {
      expect(
          resolveOffset('America/New_York', winter), const Duration(hours: -5));
      expect(
          resolveOffset('America/New_York', summer), const Duration(hours: -4));
    });

    test('a non-DST zone does not move between the two dates', () {
      expect(resolveOffset('Asia/Dubai', winter),
          resolveOffset('Asia/Dubai', summer));
      expect(resolveOffset('Asia/Tehran', winter),
          resolveOffset('Asia/Tehran', summer));
    });
  });

  group(
      'invalid Olson id falls back to Tehran (never throws, never freezes wrong)',
      () {
    test('Android-style timeZoneName abbreviations do not resolve', () {
      // These are what `DateTime.now().timeZoneName` returns on Android and
      // what poisoned the old adoption path; `tz.getLocation` must reject them.
      for (final bogus in ['PST', 'IRST', 'GMT+03:30', 'Iran Standard Time']) {
        expect(() => tz.getLocation(bogus), throwsA(anything),
            reason: '$bogus is not a valid Olson id');
      }
    });

    test('resolveLocation swallows the bad id and returns Tehran', () {
      expect(resolveLocation('IRST').name, 'Asia/Tehran');
      expect(resolveLocation(null).name, 'Asia/Tehran');
      expect(resolveLocation('Asia/Kabul').name, 'Asia/Kabul');
    });
  });

  group('end-to-end: a frozen Tehran zone skews a Dubai user by exactly 30 min',
      () {
    test('dhuhr wall clock differs by the zone gap for identical coordinates',
        () {
      // Fixed Dubai coordinates and a fixed date; the ONLY variable is the zone
      // the offset is taken from. Solar noon (UTC) is identical, so local dhuhr
      // differs by exactly the 30-minute gap between +4:00 and +3:30 — the
      // concrete error users abroad reported before 357bc4d.
      final dubai = Coordinates(25.2048, 55.2708);
      final date = DateComponents(2026, 3, 21);
      final params = CalculationMethod.muslim_world_league.getParameters();

      PrayerTimes dhuhrUnder(String zone) => PrayerTimes(
            dubai,
            date,
            params,
            utcOffset:
                resolveOffset(zone, DateTime(date.year, date.month, date.day)),
          );

      final correct = dhuhrUnder('Asia/Dubai');
      final frozen = dhuhrUnder('Asia/Tehran');

      int minutes(DateTime t) => t.hour * 60 + t.minute;
      expect(minutes(correct.dhuhr) - minutes(frozen.dhuhr), 30,
          reason: 'Dubai (+4:00) dhuhr must be 30 min later on the wall clock '
              'than the same instant rendered on Tehran (+3:30) time; a frozen '
              'zone collapses this to 0');
      expect(minutes(correct.dhuhr), isNot(minutes(frozen.dhuhr)),
          reason: 'the two zones must not render the same wall-clock dhuhr');
    });
  });
}
