import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/utils/hijri_utils.dart';

/// The grid cell paints `HijriUtils.hijriFromGreg(..., offset: userOffset).day`
/// (see calendar_screen). The bidh predicate must agree with exactly that
/// displayed day — these tests are the regression net for the old bug where
/// the flag came from the raw astronomical lunar age and disagreed by ±1 day.
void main() {
  const bidhDays = {13, 14, 15};

  int displayedDay(DateTime d, int offset) =>
      HijriUtils.hijriFromGreg(d.year, d.month, d.day, offset: offset).day;

  group('ایام البیض — تک‌منبع بر پایهٔ روزِ نمایش‌داده‌شده', () {
    test('برای هر روز و آفست: علامت البیض دقیقاً روزِ 13/14/15 نمایشی است', () {
      // ~2 Hijri years of Gregorian days, tested at 3 offsets.
      final start = DateTime(2024);
      for (final offset in const [0, 2, -1]) {
        for (var i = 0; i < 680; i++) {
          final d = start.add(Duration(days: i));
          expect(HijriUtils.isAyamAlBidh(d, offset: offset),
              bidhDays.contains(displayedDay(d, offset)),
              reason:
                  '$d (offset $offset) — displayed day ${displayedDay(d, offset)}');
        }
      }
    });

    test('آفست غیرصفر، علامت البیض را هم‌راستا با روزِ نمایشی جابه‌جا میکند',
        () {
      final start = DateTime(2024, 3);
      var dayChanged = false;
      var flagChanged = false;
      for (var i = 0; i < 360; i++) {
        final d = start.add(Duration(days: i));
        // +1 offset shifts the tabular display by exactly +1 day, so the
        // marked set must shift by exactly one Gregorian day — coupling that
        // must never silently break.
        expect(HijriUtils.isAyamAlBidh(d, offset: 1),
            HijriUtils.isAyamAlBidh(d.add(const Duration(days: 1))),
            reason: 'offset shift must move the marking with the date: $d');
        if (displayedDay(d, 1) != displayedDay(d, 0)) dayChanged = true;
        if (HijriUtils.isAyamAlBidh(d, offset: 1) !=
            HijriUtils.isAyamAlBidh(d)) {
          flagChanged = true;
        }
      }
      expect(dayChanged, isTrue,
          reason: 'offset must actually move the display');
      expect(flagChanged, isTrue,
          reason: 'a shifted display must drag the bidh marking along');
    });

    test('روزِ 15 با آفست 0 البیض است؛ همان تاریخ با آفست +1 دیگر البیض نیست',
        () {
      final g = HijriUtils.hijriToGreg(1446, 2, 15);
      expect(displayedDay(g, 0), 15);
      expect(HijriUtils.isAyamAlBidh(g), isTrue);
      expect(displayedDay(g, 1), 16);
      expect(HijriUtils.isAyamAlBidh(g, offset: 1), isFalse);
    });
  });
}
