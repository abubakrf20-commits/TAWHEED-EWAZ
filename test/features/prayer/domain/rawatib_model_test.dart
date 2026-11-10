import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/prayer/domain/entities/prayer_tracker_entities.dart';
import 'package:tawheeed/features/prayer/domain/rawatib_model.dart';

void main() {
  DateTime t(int h, [int m = 0]) => DateTime(2026, 10, 5, h, m);
  final tomorrowFajr = DateTime(2026, 10, 6, 4, 30);
  final spans = rawatibWindows(
    fajr: t(4, 30),
    sunrise: t(6),
    dhuhr: t(13),
    asr: t(16, 30),
    maghrib: t(19, 30),
    isha: t(21),
    tomorrowFajr: tomorrowFajr,
  );

  group('rawatibWindows — the one relevance table', () {
    test('fajr rawatib spans fajr → sunrise', () {
      final s = spans[SunnahPrayer.fajrRawatib];
      expect(s?.start, t(4, 30));
      expect(s?.end, t(6));
    });

    test('both dhuhr rawatibs span dhuhr → asr', () {
      for (final id in [
        SunnahPrayer.dhuhrRawatibBefore,
        SunnahPrayer.dhuhrRawatibAfter,
      ]) {
        final s = spans[id];
        expect(s?.start, t(13));
        expect(s?.end, t(16, 30));
      }
    });

    test('maghrib rawatib spans maghrib → isha', () {
      final s = spans[SunnahPrayer.maghribRawatib];
      expect(s?.start, t(19, 30));
      expect(s?.end, t(21));
    });

    test('isha rawatib spans isha → midnight (same calendar day rollover)', () {
      final s = spans[SunnahPrayer.ishaRawatib];
      expect(s?.start, t(21));
      expect(s?.end, DateTime(2026, 10, 6));
    });

    test('witr spans isha → TOMORROW fajr, crossing midnight', () {
      final s = spans[SunnahPrayer.witr];
      expect(s?.start, t(21));
      expect(s?.end, tomorrowFajr);
    });
  });

  group('rawatibStateAt', () {
    final span = spans[SunnahPrayer.fajrRawatib]!;

    test('upcoming before the window opens', () {
      expect(
        rawatibStateAt(span: span, now: t(3), checked: false),
        RawatibState.upcoming,
      );
    });

    test('suggested inside the window — start inclusive, end exclusive', () {
      expect(
        rawatibStateAt(span: span, now: t(4, 30), checked: false),
        RawatibState.suggested,
      );
      expect(
        rawatibStateAt(span: span, now: t(5), checked: false),
        RawatibState.suggested,
      );
      expect(
        rawatibStateAt(span: span, now: t(6), checked: false),
        RawatibState.past,
      );
    });

    test('past after the window ends unchecked', () {
      expect(
        rawatibStateAt(span: span, now: t(9), checked: false),
        RawatibState.past,
      );
    });

    test('ticking wins everywhere — early, inside, late', () {
      expect(
        rawatibStateAt(span: span, now: t(3), checked: true),
        RawatibState.done,
      );
      expect(
        rawatibStateAt(span: span, now: t(5), checked: true),
        RawatibState.done,
      );
      expect(
        rawatibStateAt(span: span, now: t(9), checked: true),
        RawatibState.done,
      );
    });

    test('witr is still suggested at 23:00 and past only after fajr', () {
      final witr = spans[SunnahPrayer.witr]!;
      expect(
        rawatibStateAt(span: witr, now: t(23), checked: false),
        RawatibState.suggested,
      );
      expect(
        rawatibStateAt(
            span: witr, now: DateTime(2026, 10, 6, 5), checked: false),
        RawatibState.past,
      );
    });
  });
}
