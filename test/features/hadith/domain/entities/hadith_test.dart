import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/hadith/domain/entities/hadith.dart';

void main() {
  group('HadithBook', () {
    test('constructor sets all fields', () {
      const book = HadithBook(
        id: 1,
        titleArabic: 'صحيح البخاري',
        author: 'Imam Bukhari',
        hadithCount: 7000,
      );
      expect(book.id, 1);
      expect(book.titleArabic, 'صحيح البخاري');
      expect(book.author, 'Imam Bukhari');
      expect(book.hadithCount, 7000);
    });

    test('author can be null', () {
      const book = HadithBook(
        id: 2,
        titleArabic: 'سنن أبي داود',
        hadithCount: 5000,
      );
      expect(book.author, isNull);
    });
  });

  group('HadithChapter', () {
    test('constructor sets all fields', () {
      const chapter = HadithChapter(
        id: 1,
        bookId: 1,
        titleArabic: 'كتاب الإيمان',
        chapterIndex: 1,
      );
      expect(chapter.id, 1);
      expect(chapter.bookId, 1);
      expect(chapter.titleArabic, 'كتاب الإيمان');
      expect(chapter.chapterIndex, 1);
    });
  });

  group('Hadith', () {
    test('constructor sets required fields', () {
      const hadith = Hadith(
        id: 1,
        bookId: 1,
        hadithNumber: 1,
        arabic: 'إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ',
      );
      expect(hadith.id, 1);
      expect(hadith.bookId, 1);
      expect(hadith.hadithNumber, 1);
      expect(hadith.arabic, 'إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ');
    });

    test('optional fields default to null', () {
      const hadith = Hadith(
        id: 1,
        bookId: 1,
        hadithNumber: 1,
        arabic: 'نص الحديث',
      );
      expect(hadith.chapterId, isNull);
      expect(hadith.narratorArabic, isNull);
    });

    test('constructor sets all optional fields', () {
      const hadith = Hadith(
        id: 2,
        bookId: 1,
        chapterId: 1,
        hadithNumber: 2,
        arabic: 'نص الحديث الثاني',
        narratorArabic: 'عائشة',
      );
      expect(hadith.chapterId, 1);
      expect(hadith.narratorArabic, 'عائشة');
    });
  });

  group('parseHadithGrade', () {
    test('maps enum names regardless of case/whitespace', () {
      expect(parseHadithGrade('sahih'), HadithGrade.sahih);
      expect(parseHadithGrade('  Hasan '), HadithGrade.hasan);
      expect(parseHadithGrade('DAIF'), HadithGrade.daif);
    });

    test('maps common Arabic spellings', () {
      expect(parseHadithGrade('صحیح'), HadithGrade.sahih);
      expect(parseHadithGrade('صحيح'), HadithGrade.sahih);
      expect(parseHadithGrade('حسن'), HadithGrade.hasan);
      expect(parseHadithGrade('ضعیف'), HadithGrade.daif);
      expect(parseHadithGrade('ضعيف'), HadithGrade.daif);
    });

    test('degrades to unknown instead of throwing', () {
      expect(parseHadithGrade(null), HadithGrade.unknown);
      expect(parseHadithGrade(''), HadithGrade.unknown);
      expect(parseHadithGrade('   '), HadithGrade.unknown);
      expect(parseHadithGrade('garbage'), HadithGrade.unknown);
      expect(parseHadithGrade('موضوع'), HadithGrade.unknown);
    });
  });

  group('HadithGradeExtension', () {
    test('every grade has a Persian label and a color', () {
      for (final g in HadithGrade.values) {
        expect(g.label, isNotEmpty);
        expect(g.colorValue, isNonNegative);
      }
      expect(HadithGrade.sahih.label, 'صحیح');
      expect(HadithGrade.hasan.label, 'حسن');
      expect(HadithGrade.daif.label, 'ضعیف');
      expect(HadithGrade.unknown.label, 'نامشخص');
    });
  });
}
