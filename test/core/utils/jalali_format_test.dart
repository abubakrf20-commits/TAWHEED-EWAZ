import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/utils/jalali_format.dart';

void main() {
  final samples = [
    DateTime(2026, 3, 21), // Nowruz window
    DateTime(2026, 12, 5), // single-digit Jalali month/day
    DateTime(2025, 6, 15),
    DateTime(2026),
    DateTime(2024, 2, 29),
  ];

  group('jalaliLabelFa', () {
    test('Latin digits, unpadded d/m/y shape', () {
      for (final d in samples) {
        final j = Jalali.fromDateTime(d);
        expect(jalaliLabelFa(d), '${j.day}/${j.month}/${j.year}',
            reason: 'date $d');
        // Structure: Latin digits only, two separators, no padding.
        expect(
          jalaliLabelFa(d),
          matches(RegExp(r'^\d{1,2}/\d{1,2}/\d{4}$')),
          reason: 'shape for $d',
        );
      }
    });

    test('single-digit day stays single-digit (unpadded like the old helper)',
        () {
      // Find a date whose Jalali day is < 10.
      for (final d in samples) {
        final j = Jalali.fromDateTime(d);
        if (j.day < 10) {
          final dayPart = jalaliLabelFa(d).split('/').first;
          expect(dayPart.length, 1, reason: 'day ${j.day} must not pad');
        }
      }
    });
  });

  group('jalaliYmdPadded', () {
    test('Latin zero-padded day/month (reminder-card shape)', () {
      for (final d in samples) {
        final j = Jalali.fromDateTime(d);
        final expected =
            '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
        expect(jalaliYmdPadded(d), expected, reason: 'date $d');
        expect(jalaliYmdPadded(d), matches(RegExp(r'^\d{4}/\d{2}/\d{2}$')));
      }
    });
  });

  group('jalaliYmdShort', () {
    test('Latin unpadded day/month (expenses/tasks shape)', () {
      for (final d in samples) {
        final j = Jalali.fromDateTime(d);
        expect(jalaliYmdShort(j), '${j.year}/${j.month}/${j.day}',
            reason: 'date $d');
        expect(
          jalaliYmdShort(j),
          isNot(matches(RegExp(r'/0\d/'))),
          reason: 'must not zero-pad the month for $d',
        );
      }
    });
  });

  group('jalaliDayMonth', () {
    test('converts the stored Gregorian ISO to dd/mm/Jalali', () {
      // Nowruz 1405 is 21 March 2026 — a fixed, verifiable anchor.
      final j = Jalali.fromDateTime(DateTime(2026, 3, 21));
      expect(j.year, 1405);
      expect(j.month, 1);
      expect(j.day, 1);
      expect(jalaliDayMonth('2026-03-21'), '01/01/1405');
    });

    test('pads day and month to two digits', () {
      final out = jalaliDayMonth('2026-03-21');
      expect(RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(out), isTrue, reason: out);
    });

    test('passes through values it cannot parse', () {
      for (final bad in ['', 'not a date', '1403/07/15']) {
        expect(jalaliDayMonth(bad), bad);
      }
    });

    test('never shows raw Gregorian digits for a real date', () {
      final out = jalaliDayMonth('2026-10-06');
      expect(out.contains('2026'), isFalse,
          reason: 'year must read as Jalali, not the stored Gregorian');
    });
  });
}
