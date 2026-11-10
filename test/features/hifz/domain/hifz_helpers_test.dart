import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/hifz/domain/hifz_helpers.dart';

void main() {
  group('en — Latin digits', () {
    test('renders numbers unchanged (Latin digits are the standard)', () {
      expect(en(0), '0');
      expect(en(7), '7');
      expect(en(604), '604');
      expect(en(114), '114');
    });
  });

  group('pageForAyah', () {
    test('known boundaries of the 604-page Mushaf', () {
      expect(pageForAyah(1, 1), 1);
      expect(pageForAyah(2, 1), 2);
      expect(pageForAyah(2, 6), 3);
      expect(pageForAyah(2, 141), 21);
      expect(pageForAyah(2, 142), 22);
      expect(pageForAyah(18, 1), 293);
      expect(pageForAyah(36, 1), 440);
      expect(pageForAyah(67, 1), 562);
      expect(pageForAyah(114, 1), 604);
    });

    test('invalid input returns 0', () {
      expect(pageForAyah(0, 1), 0);
      expect(pageForAyah(115, 1), 0);
      expect(pageForAyah(2, 0), 0);
    });
  });

  group('pagesForRange', () {
    test('within one surah', () {
      expect(pagesForRange(2, 1, 2, 6), 2); // pages 2-3
      expect(pagesForRange(2, 1, 2, 141), 20); // pages 2-21
      expect(pagesForRange(18, 1, 18, 1), 1);
    });

    test('across surahs', () {
      expect(pagesForRange(1, 1, 2, 5), 2); // pages 1-2
      expect(pagesForRange(2, 141, 2, 142), 2); // pages 21-22
    });

    test('invalid range returns 0', () {
      expect(pagesForRange(2, 5, 2, 3), 0); // reversed within surah
      expect(pagesForRange(3, 1, 2, 1), 0); // reversed surahs
    });

    test('a valid range with unknown page lookup still counts 1 page', () {
      // Ayah 8 does not exist in surah 1, so the boundary lookup is unknown,
      // but the range itself is valid and counts at least one page.
      expect(pagesForRange(1, 1, 1, 8), 1);
    });
  });

  group('uniquePagesOf', () {
    test('counts each distinct page once across repeated/overlapping ranges',
        () {
      final ranges = [
        (sFrom: 2, aFrom: 1, sTo: 2, aTo: 6), // pages 2-3
        (sFrom: 2, aFrom: 1, sTo: 2, aTo: 6), // exact repeat
        (sFrom: 2, aFrom: 141, sTo: 2, aTo: 142), // pages 21-22
        (sFrom: 18, aFrom: 1, sTo: 18, aTo: 1), // page 293
      ];
      expect(uniquePagesOf(ranges), 5); // 2, 3, 21, 22, 293
    });

    test('partially overlapping ranges are merged', () {
      final ranges = [
        (sFrom: 2, aFrom: 1, sTo: 2, aTo: 141), // pages 2-21
        (sFrom: 2, aFrom: 141, sTo: 2, aTo: 142), // pages 21-22
      ];
      expect(uniquePagesOf(ranges), 21); // pages 2-22
    });

    test('skips invalid ranges and counts unknown pages once each', () {
      final ranges = [
        (sFrom: 2, aFrom: 5, sTo: 2, aTo: 3), // reversed → invalid
        (sFrom: 0, aFrom: 1, sTo: 2, aTo: 5), // surah 0 → invalid
        (sFrom: 1, aFrom: 1, sTo: 1, aTo: 8), // valid, unknown page → +1
        (sFrom: 2, aFrom: 1, sTo: 2, aTo: 6), // pages 2-3
      ];
      expect(uniquePagesOf(ranges), 3); // pages 2, 3 + 1 fallback
    });

    test('empty list is zero', () {
      expect(uniquePagesOf(const []), 0);
    });
  });

  group('isRangeValid', () {
    test('accepts ordered ranges', () {
      expect(isRangeValid(2, 1, 2, 5), isTrue);
      expect(isRangeValid(2, 286, 3, 1), isTrue);
    });

    test('rejects reversed or out-of-bounds ranges', () {
      expect(isRangeValid(2, 5, 2, 3), isFalse);
      expect(isRangeValid(3, 1, 2, 1), isFalse);
      expect(isRangeValid(0, 1, 2, 1), isFalse);
      expect(isRangeValid(2, 0, 2, 1), isFalse);
    });
  });

  group('rangeLabel', () {
    test('single surah', () {
      expect(rangeLabel(2, 1, 2, 5), 'البقرة 1 تا 5');
      expect(rangeLabel(2, 1, 2, 1), 'البقرة 1');
    });

    test('across surahs', () {
      expect(rangeLabel(2, 286, 3, 1), 'البقرة 286 تا آل عمران 1');
    });
  });

  group('unionOfLessons', () {
    test('merges ranges into the outer bounds', () {
      final u = unionOfLessons([
        (sFrom: 2, aFrom: 1, sTo: 2, aTo: 5),
        (sFrom: 2, aFrom: 141, sTo: 3, aTo: 10),
      ])!;
      expect(u.sFrom, 2);
      expect(u.aFrom, 1);
      expect(u.sTo, 3);
      expect(u.aTo, 10);
    });

    test('returns null for an empty list', () {
      expect(unionOfLessons(const []), isNull);
    });
  });

  group('surahNameAr', () {
    test('returns Arabic names', () {
      expect(surahNameAr(1), 'الفاتحة');
      expect(surahNameAr(2), 'البقرة');
      expect(surahNameAr(114), 'الناس');
    });

    test('returns empty for out of range', () {
      expect(surahNameAr(0), '');
      expect(surahNameAr(115), '');
    });
  });
}
