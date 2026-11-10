import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/utils/arabic_search.dart';

void main() {
  group('normalizeForSearch', () {
    test('strips harakat so bare query matches vocalized text', () {
      expect(
        normalizeForSearch('أَعُوذُ بِكَ مِنَ الْخُبْثِ'),
        contains(normalizeForSearch('اعوذ بك')),
      );
    });

    test('Persian keyboard chars match Arabic text', () {
      // User types ی/ک (Persian) — text uses ي/ك (Arabic).
      final text = normalizeForSearch('إنَّكَ تَعْلَمُ كَيْفَ');
      expect(text, contains(normalizeForSearch('تعلم كيف')));
      expect(
        normalizeForSearch('این یک کلمه'),
        normalizeForSearch('اين يك كلمه'),
      );
    });

    test('Quranic pause marks and tatweel do not break matching', () {
      final marked = normalizeForSearch('قُلْ ۖ رَبِّي ــ يَسْتَغْفِرُ ﴿﴾');
      expect(marked, contains(normalizeForSearch('ربی')));
      expect(marked, isNot(contains('\u06D6')));
      expect(marked, isNot(contains('\u0640')));
    });

    test('hamza carriers and taa marbuta unify', () {
      // ئ → ی keeps pronunciation: برئة matches بریه.
      expect(
        normalizeForSearch('برئةٌ'),
        normalizeForSearch('بریه'),
      );
      // Bare hamza disappears: القرآن matches القرءان.
      expect(
        normalizeForSearch('القرآن الكريم'),
        normalizeForSearch('القرءان الکریم'),
      );
      // ؤ → و.
      expect(
        normalizeForSearch('مؤمنين'),
        normalizeForSearch('مومنین'),
      );
    });

    test(
        'alef maksura joins yeh family',
        () => expect(normalizeForSearch('عَلَى الْعَلِيمِ'),
            contains(normalizeForSearch('علی'))));

    test('whitespace collapses and case folds', () {
      expect(normalizeForSearch('  A   B  '), 'a b');
    });
  });

  group('toAsciiDigits', () {
    test('converts Persian and Arabic-Indic digits', () {
      expect(toAsciiDigits('۱۲۳'), '123');
      expect(toAsciiDigits('٠٤٥'), '045');
      expect(toAsciiDigits('باب ۵'), 'باب 5');
    });
  });
}
