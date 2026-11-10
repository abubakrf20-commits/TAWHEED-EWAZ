import 'package:adhan/adhan.dart' as adhan;
import 'package:flutter_test/flutter_test.dart';

/// Golden sanity checks for the prayer engine (the `adhan` package) with the
/// exact inputs the app feeds it (see `PrayerRepository._getCalculationParams`).
///
/// These are wide-window guards, not minute-exact goldens: they pin the
/// engine's qualitative behavior (ordering, sane Tehran equinox times, and —
/// critically — that the high-latitude rule actually moves Fajr/Isha at high
/// latitudes, which is what the new `highLatitudeRule` setting drives).
void main() {
  adhan.PrayerTimes timesFor(
    double lat,
    double lng,
    int year,
    int month,
    int day, {
    adhan.HighLatitudeRule rule = adhan.HighLatitudeRule.middle_of_the_night,
    Duration utcOffset = const Duration(hours: 3, minutes: 30),
  }) {
    final params = adhan.CalculationMethod.muslim_world_league.getParameters();
    params.madhab = adhan.Madhab.shafi;
    params.highLatitudeRule = rule;
    return adhan.PrayerTimes(
      adhan.Coordinates(lat, lng),
      adhan.DateComponents(year, month, day),
      params,
      utcOffset: utcOffset,
    );
  }

  int minutes(DateTime t) => t.hour * 60 + t.minute;

  group('Tehran equinox (2026-03-21, MWL, +3:30)', () {
    final pt = timesFor(35.6892, 51.3890, 2026, 3, 21);

    test('prayers are strictly ordered', () {
      final ordered = [
        pt.fajr,
        pt.sunrise,
        pt.dhuhr,
        pt.asr,
        pt.maghrib,
        pt.isha,
      ].map(minutes).toList();
      for (var i = 1; i < ordered.length; i++) {
        expect(ordered[i], greaterThan(ordered[i - 1]));
      }
    });

    test('times fall in sane equinox windows', () {
      // Wide ±60min windows around the known Tehran equinox times — tight
      // enough to catch sign/unit bugs, loose enough for engine updates.
      expect(minutes(pt.fajr), inInclusiveRange(3 * 60 + 30, 5 * 60 + 30));
      expect(minutes(pt.sunrise), inInclusiveRange(5 * 60, 7 * 60));
      expect(minutes(pt.dhuhr), inInclusiveRange(11 * 60, 13 * 60));
      expect(minutes(pt.asr), inInclusiveRange(14 * 60 + 30, 16 * 60 + 30));
      expect(minutes(pt.maghrib), inInclusiveRange(17 * 60, 19 * 60 + 30));
      expect(minutes(pt.isha), inInclusiveRange(18 * 60, 20 * 60 + 30));
    });
  });

  group('high-latitude rule effect (Stockholm 59.33N, 2026-06-21, +2:00)', () {
    adhan.PrayerTimes stockholm(adhan.HighLatitudeRule rule) => timesFor(
          59.33,
          18.06,
          2026,
          6,
          21,
          rule: rule,
          utcOffset: const Duration(hours: 2),
        );

    test('seventh-of-night moves Fajr/Isha vs middle-of-night', () {
      final middle = stockholm(adhan.HighLatitudeRule.middle_of_the_night);
      final seventh = stockholm(adhan.HighLatitudeRule.seventh_of_the_night);
      // Near white nights the two rules must visibly disagree; if they ever
      // agree here, the setting wired to the engine is a no-op.
      final fajrDiff = (minutes(middle.fajr) - minutes(seventh.fajr)).abs();
      final ishaDiff = (minutes(middle.isha) - minutes(seventh.isha)).abs();
      expect(fajrDiff + ishaDiff, greaterThan(30));
    });

    test('middle-of-night still orders correctly at high latitude', () {
      final pt = stockholm(adhan.HighLatitudeRule.middle_of_the_night);
      // NOTE: compare full DateTimes, not wall-clock minutes — near white
      // nights Isha lands after midnight (next day), so minute-of-day
      // comparison against Maghrib is meaningless.
      expect(pt.fajr.isBefore(pt.sunrise), isTrue);
      expect(pt.maghrib.isBefore(pt.isha), isTrue);
    });
  });
}
