import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_page_chrome.dart';

void main() {
  group('Qcf4PageChrome juz', () {
    test('boundaries map to the right juz', () {
      expect(Qcf4PageChrome.juzOfPage(1), 1);
      expect(Qcf4PageChrome.juzOfPage(21), 1);
      expect(Qcf4PageChrome.juzOfPage(22), 2);
      expect(Qcf4PageChrome.juzOfPage(50), 3);
      expect(Qcf4PageChrome.juzOfPage(604), 30);
      expect(Qcf4PageChrome.juzOfPage(582), 30);
      expect(Qcf4PageChrome.juzOfPage(581), 29);
    });

    test('juz titles use Arabic ordinals', () {
      expect(Qcf4PageChrome.juzTitleOfPage(1), 'الجزء الأول');
      expect(Qcf4PageChrome.juzTitleOfPage(50), 'الجزء الثالث');
      expect(Qcf4PageChrome.juzTitleOfPage(604), 'الجزء الثلاثون');
    });
  });

  group('Qcf4PageChrome digits', () {
    test('latin converts to Arabic-Indic', () {
      expect(Qcf4PageChrome.toArabicIndic(200), '٢٠٠');
      expect(Qcf4PageChrome.toArabicIndic(50), '٥٠');
      expect(Qcf4PageChrome.toArabicIndic(7), '٧');
    });
  });

  group('Qcf4PageChrome surahMeta', () {
    test('verse count and place', () {
      expect(Qcf4PageChrome.surahMeta(1), (verses: 7, place: 'مكية'));
      expect(Qcf4PageChrome.surahMeta(2), (verses: 286, place: 'مدنية'));
      expect(Qcf4PageChrome.surahMeta(3), (verses: 200, place: 'مدنية'));
    });

    test('unknown surah returns null', () {
      expect(Qcf4PageChrome.surahMeta(0), isNull);
      expect(Qcf4PageChrome.surahMeta(115), isNull);
    });
  });
}
