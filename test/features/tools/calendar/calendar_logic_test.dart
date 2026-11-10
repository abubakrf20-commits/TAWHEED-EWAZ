import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/features/tools/calendar/presentation/widgets/calendar_widgets.dart';
import 'package:tawheeed/shared/utils/hijri_utils.dart';

void main() {
  group('Hijri accuracy', () {
    test('Dhu al-Hijjah (month 12) has 30 days in the tabular algorithm', () {
      expect(HijriUtils.hijriMonthLength(12), 30);
    });

    test('Dhu al-Hijjah has 29 days in a common year, 30 in a leap year', () {
      // 1447 is a common year (30 Dhu al-Hijjah 1447 does not exist),
      // 1448 is a leap year.
      expect(HijriUtils.isHijriLeapYear(1447), isFalse);
      expect(HijriUtils.isHijriLeapYear(1448), isTrue);
      expect(HijriUtils.hijriMonthLength(12, year: 1447), 29);
      expect(HijriUtils.hijriMonthLength(12, year: 1448), 30);
    });

    test('month lengths alternate 30/29 except month 12', () {
      for (var m = 1; m <= 12; m++) {
        final expected = (m == 12 || m.isOdd) ? 30 : 29;
        expect(HijriUtils.hijriMonthLength(m), expected, reason: 'month $m');
      }
    });

    test('hijriFromGreg round-trips through hijriToJd when no offset', () {
      final d = DateTime(2026, 8, 2);
      final h = HijriUtils.hijriFromGreg(d.year, d.month, d.day);
      final jd = HijriUtils.hijriToJd(h.year, h.month, h.day);
      final g = HijriUtils.jdToGreg(jd);
      expect(DateTime(g.year, g.month, g.day), DateTime(2026, 8, 2));
    });

    test('hijriOffset shifts the forward hijri label only', () {
      final d = DateTime(2026, 8, 2);
      final h0 = HijriUtils.hijriFromGreg(d.year, d.month, d.day);
      final h2 = HijriUtils.hijriFromGreg(d.year, d.month, d.day, offset: 2);
      final g2 = HijriUtils.hijriToGreg(h2.year, h2.month, h2.day);
      expect(g2.difference(d).inDays, 2);
      expect(h2.day - h0.day, 2);
    });
  });

  group('Jalali accuracy', () {
    test('Esfand (month 12) has 30 days in a leap year', () {
      // 1403 is a leap year (Nowruz 1403 = 20 March 2024).
      expect(Jalali(1403, 12).isLeapYear(), isTrue);
      expect(Jalali(1403, 12).monthLength, 30);
    });

    test('Esfand has 29 days in a common year', () {
      expect(Jalali(1402, 12).isLeapYear(), isFalse);
      expect(Jalali(1402, 12).monthLength, 29);
    });

    test('first six Jalali months are 31 days, next five are 30', () {
      for (var m = 1; m <= 6; m++) {
        expect(Jalali(1404, m).monthLength, 31, reason: 'month $m');
      }
      for (var m = 7; m <= 11; m++) {
        expect(Jalali(1404, m).monthLength, 30, reason: 'month $m');
      }
    });

    test('grid days round-trip through Gregorian conversion', () {
      // For the whole of Farvardin, every Jalali day converts back to itself.
      for (var d = 1; d <= 31; d++) {
        final j = Jalali(1404, 1, d);
        final g = j.toDateTime();
        final back = Jalali.fromDateTime(g);
        expect(back.month, 1, reason: 'day $d');
        expect(back.day, d, reason: 'day $d');
      }
    });
  });

  group('Occasions', () {
    test('Hijri occasions resolve for Ashura and Eid al-Fitr', () {
      final ashura = occasionsForDay(CalendarKind.hijri, 1, 10);
      expect(ashura.map((e) => e.label), contains('روزه عاشورا (سنت)'));
      final fitr = occasionsForDay(CalendarKind.hijri, 10, 1);
      expect(fitr.map((e) => e.label), contains('عید فطر'));
    });

    test('only hijri (Sunni) occasions exist; no jalali or Shiite entries', () {
      expect(kCalendarOccasions, isNotEmpty);
      for (final o in kCalendarOccasions) {
        expect(o.kind, CalendarKind.hijri, reason: o.label);
      }
      final labels = kCalendarOccasions.map((e) => e.label).join();
      expect(labels, isNot(contains('نوروز')));
      expect(labels, isNot(contains('یلدا')));
      expect(labels, isNot(contains('سده')));
      expect(labels, isNot(contains('غدیر')));
      expect(labels, isNot(contains('مبعث')));
      expect(labels, isNot(contains('امام')));
    });

    test('sunnah fasts (Tasu\'a, Ashura, first of Rajab/Shaban) are present',
        () {
      final labels = kCalendarOccasions.map((e) => e.label).join();
      expect(labels, contains('تاسوعا'));
      expect(labels, contains('عاشورا'));
      expect(labels, contains('اول رجب'));
      expect(labels, contains('اول شعبان'));
    });

    test('all occasions have valid month/day ranges', () {
      for (final o in kCalendarOccasions) {
        expect(o.month, inInclusiveRange(1, 12), reason: o.label);
        expect(o.day, inInclusiveRange(1, 31), reason: o.label);
      }
    });

    test('no duplicate (kind, month, day, label) entries', () {
      final seen = <String>{};
      for (final o in kCalendarOccasions) {
        final key = '${o.kind.name}:${o.month}/${o.day}:${o.label}';
        expect(seen.add(key), isTrue, reason: 'duplicate $key');
      }
    });
  });
}
