import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/khatm/data/khatm_search_index.dart';

/// «سورهٔ کهف در کدام جزء است؟» — the one lookup the ختم page actually needs,
/// since its grid is thirty numbers and the reader thinks in surah names.
void main() {
  group('juzsOf', () {
    test('a short surah sits in one juz', () {
      // الفاتحة opens the mushaf, so it is juz 1.
      expect(KhatmSearchIndex.juzsOf(1), [1]);
    });

    test('a long surah spans the juzs it really spans', () {
      // الكهف runs across juz 15 (with الإسراء) and 16 (with مریم and طه).
      expect(KhatmSearchIndex.juzsOf(18), [15, 16]);
    });

    test('الناس closes the mushaf in juz 30', () {
      expect(KhatmSearchIndex.juzsOf(114), [30]);
    });

    test('a number outside the mushaf yields nothing rather than throwing', () {
      expect(KhatmSearchIndex.juzsOf(0), isEmpty);
      expect(KhatmSearchIndex.juzsOf(115), isEmpty);
    });
  });

  group('entries', () {
    test('every surah is indexed exactly once', () {
      final entries = KhatmSearchIndex.entries();
      expect(entries.length, 114);
      expect(entries.first.title, contains('الفاتحة'));
      expect(entries.last.title, contains('الناس'));
    });

    test('each card names the juz, the place and the verse count', () {
      final kahf = KhatmSearchIndex.entries()
          .firstWhere((e) => e.title.contains('الكهف'));
      // One «جزء» for the list, Persian digits, comma-separated: «جزء ۱۵، ۱۶».
      expect(kahf.body, contains('جزء ۱۵، ۱۶'));
      expect(kahf.body, contains('مکی'));
      expect(kahf.body, contains('۱۱۰ آیه'));
    });

    test('the transliteration is searchable, not just the Arabic name', () {
      final kahf = KhatmSearchIndex.entries()
          .firstWhere((e) => e.title.contains('الكهف'));
      expect(kahf.body.toLowerCase(), contains('kahf'));
    });

    test('no entry claims a tab — this page has no tab strip', () {
      for (final entry in KhatmSearchIndex.entries()) {
        expect(entry.tab, isNull);
        expect(entry.tabLabel, isNull);
      }
    });

    test('the index is built once and reused', () {
      expect(
        identical(KhatmSearchIndex.entries(), KhatmSearchIndex.entries()),
        isTrue,
      );
    });

    test('every surah resolves to at least one juz', () {
      // A gap here would print a card with no answer, which is the one thing
      // the index exists to avoid.
      for (var n = 1; n <= 114; n++) {
        expect(KhatmSearchIndex.juzsOf(n), isNotEmpty, reason: 'surah $n');
      }
    });
  });
}
