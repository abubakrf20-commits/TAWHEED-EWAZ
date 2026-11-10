import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/quran/data/quran_helpers.dart';

void main() {
  group('getHizbStartPage', () {
    test('hizb 1 starts at page 1 and hizb 60 covers the final pages', () {
      expect(getHizbStartPage(1), 1);
      // The local quarters table ends at surah 100, so hizb 60 begins in
      // the last third of the mushaf but still resolves to hizb 60.
      final last = getHizbStartPage(60);
      expect(last, greaterThanOrEqualTo(570));
      expect(getCurrentHizbNumberForPage(last), 60);
    });

    test('hizb boundaries are monotonic', () {
      for (var h = 2; h <= 60; h++) {
        expect(getHizbStartPage(h), greaterThan(getHizbStartPage(h - 1)),
            reason: 'hizb $h should start after hizb ${h - 1}');
      }
    });

    test('rejects out-of-range hizbs', () {
      expect(() => getHizbStartPage(0), throwsA(anything));
      expect(() => getHizbStartPage(61), throwsA(anything));
    });
  });

  group('getCurrentHizbNumberForPage', () {
    test('page 1 is in hizb 1 and page 604 is in hizb 60', () {
      expect(getCurrentHizbNumberForPage(1), 1);
      expect(getCurrentHizbNumberForPage(604), 60);
    });

    test('monotonic across every page', () {
      var prev = 1;
      for (var p = 1; p <= 604; p++) {
        final h = getCurrentHizbNumberForPage(p);
        expect(h, inInclusiveRange(1, 60));
        expect(h, greaterThanOrEqualTo(prev));
        prev = h;
      }
    });

    test('page just before a hizb boundary still reports the previous hizb',
        () {
      // Hizb 2 starts at the page of the 5th quarter ({2,75}).
      final boundary = getHizbStartPage(2);
      expect(boundary, greaterThan(1));
      expect(getCurrentHizbNumberForPage(boundary), 2);
      expect(getCurrentHizbNumberForPage(boundary - 1), 1);
    });
  });

  group('juz ↔ hizb cross-check', () {
    test('every juz start page lands in the matching hizb range', () {
      for (var j = 1; j <= 30; j++) {
        final page = getJuzStartPage(j);
        // Juz j spans hizbs roughly (2j-1)..(2j).
        final h = getCurrentHizbNumberForPage(page);
        expect(h, inInclusiveRange(2 * j - 1, 2 * j),
            reason:
                'juz $j (page $page) should be inside hizbs ${2 * j - 1}..${2 * j}');
      }
    });
  });

  group('juzVerseRanges', () {
    test('juz 1 covers al-Fatiha and the start of al-Baqarah', () {
      final ranges = juzVerseRanges(1);
      expect(ranges[1], (1, 7));
      expect(ranges[2], (1, 141));
    });

    test('juz 30 covers the short surahs', () {
      final ranges = juzVerseRanges(30);
      // Juz 30 starts at surah 78 and runs to the end of the mushaf.
      expect(ranges.keys.first, 78);
      expect(ranges[78], (1, 40));
      expect(ranges.keys.last, 114);
      expect(ranges[114], (1, 6));
    });

    test('every juz has at least one surah and contiguous verses', () {
      for (var j = 1; j <= 30; j++) {
        final ranges = juzVerseRanges(j);
        expect(ranges, isNotEmpty, reason: 'juz $j must have surahs');
        for (final entry in ranges.entries) {
          final (start, end) = entry.value;
          expect(end, greaterThanOrEqualTo(start),
              reason: 'juz $j surah ${entry.key} range');
        }
      }
    });

    test('rejects out-of-range juz numbers', () {
      expect(() => juzVerseRanges(0), throwsA(anything));
      expect(() => juzVerseRanges(31), throwsA(anything));
    });
  });
}
