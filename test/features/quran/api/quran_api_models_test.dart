import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/quran/api/quran_api_models.dart';

void main() {
  group('QuranApiModels', () {
    test(
        'QuranVerse derives chapterId from verse_key when chapter_id is missing (prelive)',
        () {
      final verse = QuranVerse.fromJson({
        'id': 7,
        'verse_number': 255,
        'verse_key': '2:255',
        'page_number': 42,
        'words': <Map<String, dynamic>>[],
      });
      expect(verse.chapterId, 2);
      expect(verse.verseNumber, 255);
      expect(verse.pageNumber, 42);
      // Round-trip keeps the derived chapter.
      final restored = QuranVerse.fromJson(verse.toJson());
      expect(restored.chapterId, 2);
    });

    test('QuranVerse round-trips through toJson', () {
      final verse = QuranVerse.fromJson({
        'id': 1,
        'chapter_id': 1,
        'verse_number': 1,
        'verse_key': '1:1',
        'page_number': 1,
        'words': [
          {
            'id': 1,
            'position': 1,
            'char_type_name': 'word',
            'page_number': 1,
            'line_number': 2,
            'code_v2': '&#xfb51;',
          },
        ],
      });
      final json = verse.toJson();
      expect(json['verse_key'], '1:1');
      expect((json['words'] as List), hasLength(1));
      final back = QuranVerse.fromJson(json);
      expect(back.words.single.glyphV2, String.fromCharCode(0xfb51));
    });

    test('ChapterReciter parses the Quran Foundation shape (nested names)', () {
      final r = ChapterReciter.fromJson({
        'id': 7,
        'name': 'Mishari Rashid al-`Afasy',
        'translated_name': {'name': 'مشاری راشد العفاسی'},
        'style': {'name': 'Murattal'},
        'qirat': {'name': 'Hafs'},
      });
      expect(r.id, 7);
      expect(r.displayName, 'مشاری راشد العفاسی');
      expect(r.subtitle, contains('Murattal'));
      expect(r.subtitle, contains('Hafs'));
    });

    test(
        'ChapterReciter parses the public legacy shape (reciter_name, plain style)',
        () {
      final r = ChapterReciter.fromJson({
        'id': 3,
        'reciter_name': 'Abdul Basit',
        'style': 'Murattal',
        'translated_name': {'name': 'عبدالباسط'},
      });
      expect(r.name, 'Abdul Basit');
      expect(r.displayName, 'عبدالباسط');
      expect(r.style, 'Murattal');
    });

    test('ChapterReciter round-trips through toJson', () {
      final r = ChapterReciter.fromJson({
        'id': 5,
        'name': 'Saad Al-Ghamdi',
        'translated_name': {'name': 'سعد الغامدی'},
        'style': {'name': 'Murattal'},
      });
      final back = ChapterReciter.fromJson(r.toJson());
      expect(back.id, r.id);
      expect(back.name, r.name);
      expect(back.translatedName, r.translatedName);
      expect(back.style, r.style);
    });
  });
}
