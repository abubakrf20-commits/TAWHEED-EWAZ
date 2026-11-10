import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/quran/services/quran_translation_reader.dart';

void main() {
  group('QuranTranslationReader.buildIndex', () {
    test('groups rows by surah and sorts them by verse', () {
      final index = QuranTranslationReader.buildIndex([
        {'surah': 2, 'verse': 3, 'text': 'c'},
        {'surah': 1, 'verse': 2, 'text': 'b'},
        {'surah': 1, 'verse': 1, 'text': 'a'},
      ]);
      expect(index.keys, unorderedEquals([1, 2]));
      expect(index[1]!.map((e) => e.verse), [1, 2]);
      expect(index[1]!.map((e) => e.text), ['a', 'b']);
      expect(index[2]!.single.text, 'c');
    });

    test('skips malformed rows without losing the rest', () {
      final index = QuranTranslationReader.buildIndex([
        {'surah': 0, 'verse': 1, 'text': 'bad surah'},
        {'surah': 115, 'verse': 1, 'text': 'bad surah'},
        {'surah': 1, 'verse': 0, 'text': 'bad verse'},
        'not a map',
        {'surah': 1, 'verse': 1, 'text': 'kept'},
        {'surah': 1, 'verse': 2},
      ]);
      expect(index[1]!.map((e) => e.verse), [1, 2]);
      expect(index[1]!.first.text, 'kept');
      expect(index[1]!.last.text, '');
    });
  });

  group('QuranTranslationReader.lowerBound', () {
    final list = [(verse: 1, text: 'a'), (verse: 3, text: 'c'), (verse: 7, text: 'g')];

    test('finds an exact verse', () {
      expect(QuranTranslationReader.lowerBound(list, 3), 1);
    });

    test('a missing verse resolves to the next one, never the previous', () {
      final i = QuranTranslationReader.lowerBound(list, 4);
      expect(i, 2);
      expect(list[i].verse, 7);
      expect(list[i].text, isNot('c'));
    });

    test('a verse past the end resolves to the list length', () {
      expect(QuranTranslationReader.lowerBound(list, 99), list.length);
    });

    test('a verse before the start resolves to 0', () {
      expect(QuranTranslationReader.lowerBound(list, -1), 0);
    });
  });

  group('QuranTranslationReader bundled fallback', () {
    test('only the Persian file is bundled', () {
      expect(
          QuranTranslationReader.isBundled(
              QuranTranslationReader.persianFileName),
          isTrue);
      expect(
          QuranTranslationReader.isBundled('ku-burhan-muhammad-simple.json'),
          isFalse);
      expect(
          QuranTranslationReader.isBundled('muhammad-saleh-bamoki-simple.json'),
          isFalse);
    });
  });
}
