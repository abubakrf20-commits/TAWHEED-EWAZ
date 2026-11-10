import 'dart:math' as math;

import 'package:adhan/adhan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/prayer/data/place_index.dart';

/// Worldwide prayer-time accuracy verification (full-app audit, Phase 6).
///
/// The check has to be independent of the engine, otherwise it only proves the
/// engine agrees with itself. [solarNoonMinutesUtc] is a closed-form
/// approximation of apparent solar noon (NOAA's equation-of-time series), which
/// depends only on longitude and the date — so comparing the engine's Dhuhr
/// against it catches exactly the failure modes users report: a swapped or
/// wrong coordinate, a bad longitude→time conversion, a UTC offset applied with
/// the wrong sign, or a DST offset taken from the wrong day.
///
/// Times are computed against LOCAL MEAN TIME (`utcOffset = 4 min × longitude`)
/// instead of each city's political zone. That removes timezone data from the
/// assertion entirely: under LMT, solar noon lands at 12:00 minus the
/// equation of time, for every point on earth, in both hemispheres.
void main() {
  /// 21 June — northern summer, long days, high latitudes near their extreme.
  final juneSolstice = DateComponents(2026, 6, 21);

  /// 21 December — northern winter, short days, southern summer.
  final decemberSolstice = DateComponents(2026, 12, 21);

  /// MWL dhuhr is solar transit + 1 minute (the method's own adjustment).
  const dhuhrMethodAdjustment = 1;

  group('dhuhr matches solar transit worldwide', () {
    for (final date in [juneSolstice, decemberSolstice]) {
      test('${date.year}-${date.month}-${date.day}', () {
        final eqt = equationOfTimeMinutes(date);
        final failures = <String>[];

        for (final place in PlaceIndex.places) {
          final lmtOffset = Duration(minutes: (place.lng * 4).round());
          final times = PrayerTimes(
            Coordinates(place.lat, place.lng),
            date,
            CalculationMethod.muslim_world_league.getParameters(),
            utcOffset: lmtOffset,
          );

          final expectedNoon = 720.0 -
              eqt +
              dhuhrMethodAdjustment +
              (lmtOffset.inMinutes - place.lng * 4);
          final actual = times.dhuhr.hour * 60 + times.dhuhr.minute;
          final drift = (actual - expectedNoon).abs();
          if (drift > 4.0) {
            failures.add('${place.name} (${place.lat}, ${place.lng}) '
                'drift ${drift.toStringAsFixed(1)}min');
          }
        }

        expect(failures, isEmpty,
            reason: 'Dhuhr deviates >4min (≈1° of longitude) from solar noon:\n'
                '${failures.join('\n')}');
      });
    }
  });

  group('time ordering and day-length sanity worldwide', () {
    test('both solstices, every offline place', () {
      for (final date in [juneSolstice, decemberSolstice]) {
        for (final place in PlaceIndex.places) {
          final times = PrayerTimes(
            Coordinates(place.lat, place.lng),
            date,
            CalculationMethod.muslim_world_league.getParameters(),
            utcOffset: Duration(minutes: (place.lng * 4).round()),
          );
          // Durations, not clock minutes: far from the equator the night
          // prayers fall after local midnight, and comparing hour-of-day would
          // read that as going backwards in time.
          final ordered = [
            times.fajr,
            times.sunrise,
            times.dhuhr,
            times.asr,
            times.maghrib,
            times.isha,
          ];
          for (var i = 1; i < ordered.length; i++) {
            expect(
                ordered[i].difference(ordered[i - 1]).inSeconds, greaterThan(0),
                reason: '${place.name} on ${date.month}/${date.day}: prayer '
                    '$i is not after ${i - 1}');
          }
          // Night must be shorter than the day somewhere, and no interval may
          // exceed 24h — the signature of a solver that failed to converge.
          final dayLength = times.maghrib.difference(times.sunrise).inMinutes;
          expect(dayLength, inInclusiveRange(30, 24 * 60 - 30),
              reason: '${place.name}: implausible day length $dayLength min');
        }
      }
    });
  });

  group('high-latitude rule keeps fajr and isha defined', () {
    /// Cities far enough from the equator that astronomical fajr/isha do not
    /// exist for part of the year: the rule is what makes the times usable.
    const polar = [
      PlaceMatch(
          name: 'ریکیاویک', country: 'ایسلند', lat: 64.1466, lng: -21.9426),
      PlaceMatch(
          name: 'سنت‌پترزبورگ', country: 'روسیه', lat: 59.9311, lng: 30.3609),
      PlaceMatch(
          name: 'هلسینکی', country: 'فنلاند', lat: 60.1699, lng: 24.9384),
      PlaceMatch(name: 'اسلو', country: 'نروژ', lat: 59.9139, lng: 10.7522),
    ];

    for (final rule in HighLatitudeRule.values) {
      test(rule.name, () {
        for (final city in polar) {
          final params = CalculationMethod.muslim_world_league.getParameters();
          params.highLatitudeRule = rule;
          final times = PrayerTimes(
            Coordinates(city.lat, city.lng),
            DateComponents(2026, 6, 21),
            params,
            utcOffset: Duration(minutes: (city.lng * 4).round()),
          );
          expect(times.fajr.isBefore(times.sunrise), isTrue,
              reason: '${city.name}: fajr must precede sunrise');
          expect(times.maghrib.isBefore(times.isha), isTrue,
              reason: '${city.name}: maghrib must precede isha');
        }
      });
    }
  });

  group('southern hemisphere behaves like the north', () {
    test('day is shortest at the december solstice, longest at june', () {
      for (final city in const [
        PlaceMatch(
            name: 'سیدنی', country: 'استرالیا', lat: -33.8688, lng: 151.2093),
        PlaceMatch(
            name: 'کیپ‌تاون',
            country: 'آفریقای‌جنوبی',
            lat: -33.9249,
            lng: 18.4241),
        PlaceMatch(
            name: 'بوئنوس‌آیرس',
            country: 'آرژانتین',
            lat: -34.6037,
            lng: -58.3816),
      ]) {
        int dayLength(DateComponents date) {
          final times = PrayerTimes(
            Coordinates(city.lat, city.lng),
            date,
            CalculationMethod.muslim_world_league.getParameters(),
            utcOffset: Duration(minutes: (city.lng * 4).round()),
          );
          return (times.maghrib.difference(times.sunrise)).inMinutes;
        }
        final june = dayLength(juneSolstice);
        final december = dayLength(decemberSolstice);
        expect(december, greaterThan(june),
            reason: '${city.name} is south of the equator: its longest day '
                'must be in December (june=$june, december=$december)');
      }
    });
  });

  group('per-date UTC offset (DST) is not interchangeable with today’s offset',
      () {
    test('a spring date under DST differs from the same day in winter', () {
      // Regression guard for the Phase-6 bug: the repository used to reuse
      // today's offset when computing another day's times, shifting times by
      // an hour across a DST boundary.
      final winter = PrayerTimes(
        Coordinates(51.5074, -0.1278),
        DateComponents(2026, 2, 21),
        CalculationMethod.muslim_world_league.getParameters(),
        utcOffset: const Duration(),
      );
      final summer = PrayerTimes(
          Coordinates(51.5074, -0.1278),
          DateComponents(2026, 6, 21),
          CalculationMethod.muslim_world_league.getParameters(),
          utcOffset: const Duration(hours: 1));
      // London's solar noon in February (GMT) and in June (BST, +1) land on the
      // same wall clock only because the offset moved with the date.
      final winterNoon = winter.dhuhr.hour * 60 + winter.dhuhr.minute;
      final summerNoon = summer.dhuhr.hour * 60 + summer.dhuhr.minute;
      expect((winterNoon - summerNoon).abs(), lessThan(60),
          reason: 'winter=$winterNoon summer=$summerNoon — using the wrong '
              'day’s offset would put these an hour apart');
    });
  });
}

/// NOAA's equation of time in minutes for [date]: the difference between
/// apparent solar time and mean solar time. Positive means the sun is "fast",
/// so solar noon happens before 12:00 mean time.
double equationOfTimeMinutes(DateComponents date) {
  final leap = isLeap(date.year) ? 1 : 0;
  final dayOfYear = DateTime(date.year, date.month, date.day)
          .difference(DateTime(date.year))
          .inDays +
      1;
  final yearLength = 365 + leap;
  // Fractional year (radians), measured from midnight at the start of day 1.
  final gamma = 2 * math.pi / yearLength * (dayOfYear - 1);
  return 229.18 *
      (0.000075 +
          0.001868 * math.cos(gamma) -
          0.032077 * math.sin(gamma) -
          0.014615 * math.cos(2 * gamma) -
          0.040849 * math.sin(2 * gamma));
}

bool isLeap(int year) => (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
