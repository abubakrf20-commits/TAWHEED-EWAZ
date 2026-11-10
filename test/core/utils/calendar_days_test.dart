import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/utils/calendar_days.dart';
import 'package:tawheeed/features/tools/moon/domain/services/astronomical_hijri.dart';

void main() {
  group('addCalendarDays', () {
    test('moves by whole days in both directions', () {
      final d = DateTime(2025, 3, 10, 14, 30);
      expect(addCalendarDays(d, 1), DateTime(2025, 3, 11, 14, 30));
      expect(addCalendarDays(d, -1), DateTime(2025, 3, 9, 14, 30));
      expect(addCalendarDays(d, 0), d);
    });

    test('rolls over months and years', () {
      expect(addCalendarDays(DateTime(2025, 1, 31), 1), DateTime(2025, 2));
      expect(addCalendarDays(DateTime(2025, 12, 31), 1), DateTime(2026));
      expect(addCalendarDays(DateTime(2025, 3), -1), DateTime(2025, 2, 28));
    });

    test('a 24-hour step would be wrong on a daylight-saving night', () {
      // Iran had DST until 2022 and many users' devices still do. Whatever
      // the local zone, adding 24 hours to a local midnight is not guaranteed
      // to land on the next calendar day, while `addCalendarDays` is.
      final midnight = DateTime(2025, 6, 15);
      final stepped = addCalendarDays(midnight, 1);
      expect(stepped.year, midnight.year);
      expect(stepped.month, midnight.month);
      expect(stepped.day, midnight.day + 1);
      expect(
        calendarDaysBetween(midnight, stepped),
        1,
      );
    });
  });

  group('calendarDaysBetween', () {
    test('counts days, not elapsed hours', () {
      expect(
        calendarDaysBetween(DateTime(2025), DateTime(2025, 1, 31)),
        30,
      );
      expect(
        calendarDaysBetween(DateTime(2025, 1, 31), DateTime(2025, 2)),
        1,
      );
      expect(
        calendarDaysBetween(DateTime(2025, 2), DateTime(2025, 1, 31)),
        -1,
      );
    });

    test('ignores the time of day on both ends', () {
      expect(
        calendarDaysBetween(
            DateTime(2025, 5, 10, 23, 59), DateTime(2025, 5, 11, 0, 1)),
        1,
      );
    });

    test('a full lunar month is 29 or 30 days, never 28', () {
      // Sampling every day for a year exercises the daylight-saving edge
      // cases in whatever zone the test runs in.
      var start = DateTime(2025);
      for (var i = 0; i < 365; i++) {
        final end = addCalendarDaysFromMidnight(start, 30);
        final days = calendarDaysBetween(start, end);
        expect(days, 30, reason: start.toIso8601String());
        start = addCalendarDaysFromMidnight(start, 1);
      }
    });
  });

  group('calendarDayRange', () {
    test('produces consecutive distinct days', () {
      final days = calendarDayRange(DateTime(2025, 6, 30, 8), 5);
      expect(days.length, 5);
      expect(days.first, DateTime(2025, 6, 30));
      expect(days.last, DateTime(2025, 7, 4));
      expect(days.toSet().length, 5);
    });
  });

  group('astronomical hijri month info', () {
    test('month length is always 29 or 30 days over a whole year', () {
      // The old `difference(...).inDays` measured elapsed time, so a month
      // spanning a "clocks back" night truncated to 28 and the date drifted.
      var day = DateTime(2025);
      for (var i = 0; i < 365; i++) {
        final info = AstronomicalHijri.lunarMonthInfo(day);
        expect(info.monthLength, inInclusiveRange(29, 30),
            reason: day.toIso8601String());
        expect(info.dayInMonth, inInclusiveRange(1, info.monthLength),
            reason: day.toIso8601String());
        day = addCalendarDaysFromMidnight(day, 1);
      }
    });

    test('month boundaries match the Espenak new-moon catalog (NASA)', () {
      // Anchor: Fred Espenak's new-moon catalog (astropixels.com,
      // NASA GSFC): Dec 30 2024 22:27 UT and Jan 29 2025 12:36 UT.
      // Which civil day a conjunction lands on depends on the zone, so
      // the expected monthStart/length are derived from the UT instants
      // plus the local offset — that keeps the anchor honest in every
      // zone while still pinning the algorithm to real astronomy.
      final rajabConjUtc = DateTime.utc(2024, 12, 30, 22, 27);
      final shabanConjUtc = DateTime.utc(2025, 1, 29, 12, 36);
      final conjDay = DateTime(rajabConjUtc.toLocal().year,
          rajabConjUtc.toLocal().month, rajabConjUtc.toLocal().day);
      final nextConjDay = DateTime(shabanConjUtc.toLocal().year,
          shabanConjUtc.toLocal().month, shabanConjUtc.toLocal().day);

      final first = AstronomicalHijri.lunarMonthInfo(
          conjDay.add(const Duration(days: 1)));
      expect(first.monthStart, conjDay.add(const Duration(days: 1)));
      expect(first.dayInMonth, 1);
      expect(first.monthLength,
          nextConjDay.difference(first.monthStart).inDays + 1);
      expect(first.monthLength, inInclusiveRange(29, 30));

      final last = AstronomicalHijri.lunarMonthInfo(nextConjDay);
      expect(last.dayInMonth, last.monthLength);
      expect(last.isConjunctionDay, isTrue);
    });

    test('a month reports the same length on every day of it', () {
      // Resolving the next conjunction from "today" made the length flip
      // mid-month, so the app could show a 30th day in a 29-day month.
      var day = DateTime(2025);
      for (var i = 0; i < 365; i++) {
        final info = AstronomicalHijri.lunarMonthInfo(day);
        final lastDay =
            addCalendarDaysFromMidnight(info.monthStart, info.monthLength - 1);
        for (var d = info.monthStart;
            !d.isAfter(lastDay);
            d = addCalendarDaysFromMidnight(d, 1)) {
          expect(
              AstronomicalHijri.lunarMonthInfo(d).monthLength, info.monthLength,
              reason: d.toIso8601String());
        }
        day = addCalendarDaysFromMidnight(day, 1);
      }
    });

    test('dayInMonth equals the calendar-day count from month start', () {
      // Regression for the DST truncation: the day number must be the count
      // of CALENDAR days since monthStart, not elapsed hours — otherwise a
      // 23-hour "clocks forward" night makes dayInMonth skip or repeat. This
      // holds in every zone because lunarMonthInfo now uses
      // calendarDaysBetween, while the naive `.difference().inDays` would
      // differ on a DST day in a zone that observes it.
      var day = DateTime(2025, 3, 20);
      for (var i = 0; i < 200; i++) {
        final info = AstronomicalHijri.lunarMonthInfo(day);
        expect(
          info.dayInMonth,
          calendarDaysBetween(info.monthStart, day) + 1,
          reason: 'dayInMonth drift on ${day.toIso8601String()}',
        );
        day = addCalendarDaysFromMidnight(day, 1);
      }
    });

    test('the day advances by exactly one across the whole month', () {
      final info = AstronomicalHijri.lunarMonthInfo(DateTime(2025, 6, 15));
      var previous = 0;
      for (var i = 0; i < info.monthLength; i++) {
        final day = addCalendarDaysFromMidnight(info.monthStart, i);
        final dayInfo = AstronomicalHijri.lunarMonthInfo(day);
        expect(dayInfo.dayInMonth, i + 1, reason: day.toIso8601String());
        expect(dayInfo.monthStart, info.monthStart);
        previous = dayInfo.dayInMonth;
      }
      expect(previous, info.monthLength);
    });

    test('the next conjunction is in the future, not the anchor itself', () {
      var day = DateTime(2025);
      for (var i = 0; i < 365; i++) {
        final info = AstronomicalHijri.lunarMonthInfo(day);
        expect(info.nextNewMoon.isAfter(info.monthStart), isTrue,
            reason: day.toIso8601String());
        day = addCalendarDaysFromMidnight(day, 1);
      }
    });
  });
}
