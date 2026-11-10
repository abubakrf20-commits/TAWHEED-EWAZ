import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_config.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_models.dart';

/// Representative snippet drawn from the real `pages/001.json` of the
/// MohamadHajjRabee/quran-qcf4 dataset, covering every word type the reader
/// must understand (surah_header, word, end) plus defensive-parse branches.
const String _pageOneJson = '''
{
  "page": 1,
  "font": "QCF4_Hafs_01",
  "surahs": [
    {"id": 1, "name": "Al-Fatihah", "name_arabic": "الفاتحة",
     "verse_start": 1, "verse_end": 7}
  ],
  "lines": [
    {"line": 1, "words": [
      {"code": 61696, "char": "\\uF100", "font": "QCF4_QBSML",
       "text": "سُورَةُ االفَاتِحَةِ", "type": "surah_header", "sura": 1}
    ]},
    {"line": 2, "words": [
      {"code": 61696, "char": "\\uF100", "font": "QCF4_Hafs_01",
       "text": "بِسْمِ", "type": "word", "verse_key": "1:1", "position": 1},
      {"code": 61699, "char": "\\uF103", "font": "QCF4_Hafs_01",
       "text": "الرَّحِيمِ", "type": "word", "verse_key": "1:1", "position": 4},
      {"code": 61700, "char": "\\uF104", "font": "QCF4_Hafs_01",
       "text": "V1", "type": "end", "verse_key": "1:1", "position": 5}
    ]},
    {"line": 3, "words": [
      {"code": 61701, "char": "\\uF105", "font": "QCF4_Hafs_01",
       "text": "الْحَمْدُ", "type": "word", "verse_key": "1:2", "position": 1},
      {"code": 61705, "char": "\\uF109", "font": "QCF4_Hafs_01",
       "text": "V2", "type": "end", "verse_key": "1:2", "position": 5},
      {"code": 61748, "char": "\\uF134", "font": "QCF4_Hafs_01",
       "text": "۞", "type": "quarter", "verse_key": "1:2"}
    ]}
  ]
}
''';

void main() {
  group('Qcf4Config urls', () {
    test('page JSON url zero-pads three digits', () {
      expect(Qcf4Config.pageJsonUrl(1), endsWith('/pages/001.json'));
      expect(Qcf4Config.pageJsonUrl(604), endsWith('/pages/604.json'));
      expect(Qcf4Config.pageJsonUrl(1), startsWith(Qcf4Config.dataBase));
    });

    test('font TTF file name appends _W for Hafs but not QBSML', () {
      expect(Qcf4Config.fontTtfFileName('QCF4_Hafs_01'), 'QCF4_Hafs_01_W.ttf');
      expect(Qcf4Config.fontTtfFileName('QCF4_Hafs_47'), 'QCF4_Hafs_47_W.ttf');
      expect(Qcf4Config.fontTtfFileName('QCF4_QBSML'), 'QCF4_QBSML.ttf');
    });

    test('font url points at jsDelivr fonts (TTF)', () {
      expect(Qcf4Config.fontTtfUrl('QCF4_Hafs_01'),
          '${Qcf4Config.fontCdnBase}/fonts/QCF4_Hafs_01_W.ttf');
      expect(Qcf4Config.fontTtfUrl('QCF4_QBSML'),
          '${Qcf4Config.fontCdnBase}/fonts/QCF4_QBSML.ttf');
    });
  });

  group('Qcf4Page parsing', () {
    late Qcf4Page page;
    setUp(() {
      page = Qcf4Page.decode(_pageOneJson)!;
    });

    test('decodes page, font and surahs', () {
      expect(page.page, 1);
      expect(page.font, 'QCF4_Hafs_01');
      expect(page.surahs, hasLength(1));
      final surah = page.surahs.first;
      expect(surah.id, 1);
      expect(surah.nameArabic, 'الفاتحة');
      expect(surah.verseStart, 1);
      expect(surah.verseEnd, 7);
    });

    test('detects centered surah header line', () {
      expect(page.lines, hasLength(3));
      final header = page.lines[0].words.single;
      expect(header.isCentered, isTrue);
      expect(header.type, 'surah_header');
      expect(header.isQuranicWord, isFalse);
      expect(header.font, 'QCF4_QBSML');
    });

    test('classifies quranic words with verse keys and positions', () {
      final line2 = page.lines[1].words;
      expect(line2, hasLength(3));

      final bism = line2[0];
      expect(bism.isQuranicWord, isTrue);
      expect(bism.isCentered, isFalse);
      expect(bism.verseKey, '1:1');
      expect(bism.position, 1);

      final rahim = line2[1];
      expect(rahim.verseKey, '1:1');
      expect(rahim.position, 4);
      expect(rahim.text, 'الرَّحِيمِ');
    });

    test('recognizes end glyph as inline (not centered)', () {
      final end = page.lines[1].words[2];
      expect(end.type, 'end');
      expect(end.text, 'V1');
      expect(end.isCentered, isFalse);
      expect(end.isQuranicWord, isFalse);
    });

    test('quarter marker stays inline rather than full-width centered', () {
      final quarter = page.lines[2].words[2];
      expect(quarter.type, 'quarter');
      expect(quarter.isCentered, isFalse);
      expect(quarter.verseKey, '1:2');
    });

    test('round-trips through encode/decode without data loss', () {
      final encoded = page.encode();
      final restored = Qcf4Page.decode(encoded)!;
      expect(restored.toJson(), page.toJson());
      expect(restored.page, 1);
      expect(restored.lines, hasLength(3));
      expect(restored.lines[1].words[2].type, 'end');
    });
  });

  group('Qcf4Page defensive parsing', () {
    test('tolerates missing optional fields', () {
      final page = Qcf4Page.decode('''
      {"page": 9, "font": "QCF4_Hafs_02", "lines": [
        {"line": 1, "words": [
          {"char": "\\uF200", "font": "QCF4_Hafs_02", "type": "word"}
        ]}
      ]}
      ''')!;
      expect(page.surahs, isEmpty);
      final word = page.lines.single.words.single;
      expect(word.verseKey, isNull);
      expect(word.position, isNull);
      expect(word.isQuranicWord, isFalse); // no verse key -> not highlightable
      expect(word.isCentered, isFalse);
    });

    test('returns null for non-json and for non-object json', () {
      expect(Qcf4Page.decode('not json'), isNull);
      expect(Qcf4Page.decode('[1,2]'), isNull);
    });
  });
}
