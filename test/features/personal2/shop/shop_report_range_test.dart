import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:tawheeed/features/personal2/shop/domain/shop_report_range.dart';

/// The report's window is the only thing every figure depends on: an off-by-one
/// here either double-counts a day in the comparison or silently reports an
/// empty period. These tests pin the boundaries.
void main() {
  group('window bounds', () {
    test('a single day includes the whole last day, not up to midnight', () {
      final day = ShopReportRange.day(DateTime(2026, 10, 5, 15, 40));
      expect(day.from, DateTime(2026, 10, 5));
      expect(day.to, DateTime(2026, 10, 5));
      expect(day.dayCount, 1);
      expect(day.isSingleDay, isTrue);
      // 23:59:59.999 of the same day is inside; the next midnight is not.
      expect(day.contains(DateTime(2026, 10, 5, 23, 59, 59, 999)), isTrue);
      expect(day.contains(DateTime(2026, 10, 6)), isFalse);
      expect(day.toMsExclusive, DateTime(2026, 10, 6).millisecondsSinceEpoch);
    });

    test('7 days is today plus six, not "now minus 168 hours"', () {
      final range =
          ShopReportRange.lastDays(7, now: DateTime(2026, 10, 20, 9, 30));
      expect(range.from, DateTime(2026, 10, 14));
      expect(range.to, DateTime(2026, 10, 20));
      expect(range.dayCount, 7);
      expect(range.isSingleDay, isFalse);
    });

    test('a zero or negative day count still means one day', () {
      expect(
        ShopReportRange.lastDays(0, now: DateTime(2026, 10, 20)).dayCount,
        1,
      );
      expect(
        ShopReportRange.lastDays(-4, now: DateTime(2026, 10, 20)).from,
        DateTime(2026, 10, 20),
      );
    });

    test('the previous window is exactly as long and ends the day before', () {
      final range = ShopReportRange(
        from: DateTime(2026, 10, 8),
        to: DateTime(2026, 10, 14),
      );
      final previous = range.previous;
      expect(previous.dayCount, range.dayCount);
      expect(previous.to, DateTime(2026, 10, 7));
      expect(previous.from, DateTime(2026, 10, 1));
      expect(previous.contains(DateTime(2026, 10, 8)), isFalse);
      expect(previous.previous.to, DateTime(2026, 9, 30));
    });
  });

  group('this Jalali month', () {
    test('starts on the first of the Shamsi month, not 30 days back', () {
      // ۲ مهر ۱۴۰۴ == 2026-09-24. Two days of data, not thirty.
      final now = DateTime(2026, 9, 24, 18);
      final range = ShopReportRange.thisJalaliMonth(now: now);
      expect(range.from, Jalali(Jalali.fromDateTime(now).year,
              Jalali.fromDateTime(now).month)
          .toDateTime());
      expect(range.to, DateTime(2026, 9, 24));
      // Length is today's Shamsi day number, derived not typed: 1..j.day.
      expect(range.dayCount, Jalali.fromDateTime(now).day);
    });

    test('crosses a Jalali month end without leaving the month', () {
      // 31 شهریور ۱۴۰۴ == 2026-09-22; the window must start on 1 شهریور.
      final now = DateTime(2026, 9, 22);
      final range = ShopReportRange.thisJalaliMonth(now: now);
      final j = Jalali.fromDateTime(range.from);
      expect(j.day, 1);
      expect(j.month, Jalali.fromDateTime(now).month);
    });
  });

  group('labelling', () {
    test('one day prints one date, a span prints both', () {
      final day = ShopReportRange.day(DateTime(2026, 9, 24));
      expect(day.label, contains('/'));
      expect(day.label, isNot(contains('تا')));
      final span = ShopReportRange(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 24),
      );
      expect(span.label, contains(' تا '));
    });
  });

  group('presets', () {
    test('every preset but custom resolves to its own window', () {
      final now = DateTime(2026, 10, 20, 8);
      for (final preset in ShopReportPreset.values) {
        final range = preset.rangeAt(now);
        if (preset == ShopReportPreset.custom) {
          expect(range, isNull, reason: 'custom is picked, not computed');
        } else {
          expect(range, isNotNull, reason: preset.name);
          expect(range!.contains(now), isTrue, reason: preset.name);
        }
      }
      expect(
        ShopReportPreset.last7.rangeAt(now)!.dayCount,
        7,
      );
      expect(ShopReportPreset.last30.rangeAt(now)!.dayCount, 30);
      expect(ShopReportPreset.today.rangeAt(now)!.isSingleDay, isTrue);
    });
  });

  group('equality', () {
    test('two windows with the same bounds are the same window', () {
      final a = ShopReportRange(
          from: DateTime(2026, 9, 1), to: DateTime(2026, 9, 30));
      final b = ShopReportRange(
          from: DateTime(2026, 9, 1, 12), to: DateTime(2026, 9, 30, 18));
      // Times of day are normalised by the bounds getters, so equality holds —
      // which is what keeps the provider cache from re-querying on a rebuild.
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });
}
