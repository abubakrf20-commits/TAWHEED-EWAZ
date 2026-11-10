import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/date_converter/domain/entities/converted_date.dart';

void main() {
  group('ConvertedDate', () {
    test('constructor sets all fields', () {
      const date = ConvertedDate(
        year: 1448,
        month: 1,
        day: 1,
        monthName: 'محرم',
        weekday: 'پنجشنبه',
        type: CalendarType.hijri,
      );
      expect(date.year, 1448);
      expect(date.month, 1);
      expect(date.day, 1);
      expect(date.monthName, 'محرم');
      expect(date.weekday, 'پنجشنبه');
      expect(date.type, CalendarType.hijri);
    });

    group('formatted', () {
      test('returns correct format for hijri', () {
        const date = ConvertedDate(
          year: 1448,
          month: 1,
          day: 15,
          monthName: 'محرم',
          weekday: 'شنبه',
          type: CalendarType.hijri,
        );
        expect(date.formatted, '15 محرم 1448');
      });

      test('returns correct format for gregorian', () {
        const date = ConvertedDate(
          year: 2026,
          month: 7,
          day: 10,
          monthName: 'July',
          weekday: 'Friday',
          type: CalendarType.gregorian,
        );
        expect(date.formatted, '10 July 2026');
      });
    });
  });

  group('CalendarType', () {
    test('has all values', () {
      expect(CalendarType.values.length, 3);
      expect(
          CalendarType.values,
          containsAll([
            CalendarType.hijri,
            CalendarType.shamsi,
            CalendarType.gregorian,
          ]));
    });
  });

  group('ConversionResult', () {
    test('constructor sets all fields', () {
      const hijri = ConvertedDate(
        year: 1448,
        month: 1,
        day: 1,
        monthName: 'محرم',
        weekday: 'پنجشنبه',
        type: CalendarType.hijri,
      );
      const shamsi = ConvertedDate(
        year: 1405,
        month: 4,
        day: 19,
        monthName: 'تیر',
        weekday: 'پنجشنبه',
        type: CalendarType.shamsi,
      );
      const gregorian = ConvertedDate(
        year: 2026,
        month: 7,
        day: 10,
        monthName: 'July',
        weekday: 'Friday',
        type: CalendarType.gregorian,
      );
      const result = ConversionResult(
        hijri: hijri,
        shamsi: shamsi,
        gregorian: gregorian,
        weekday: 'پنجشنبه',
        dayOfYear: 191,
        daysInMonth: 31,
        daysUntilMonthEnd: 21,
      );
      expect(result.hijri.year, 1448);
      expect(result.shamsi.year, 1405);
      expect(result.gregorian.year, 2026);
      expect(result.weekday, 'پنجشنبه');
      expect(result.dayOfYear, 191);
      expect(result.daysInMonth, 31);
      expect(result.daysUntilMonthEnd, 21);
    });
  });
}
