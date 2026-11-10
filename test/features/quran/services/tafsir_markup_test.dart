import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/quran/services/tafsir_markup.dart';

void main() {
  group('TafsirMarkup', () {
    test('plain text takes the no-op path', () {
      const text = 'خداوند در این آیه به بندگانش دستور می‌دهد. 5 < 6 هم بی‌اثر است.';
      expect(TafsirMarkup.hasMarkup(text), isFalse);
      final runs = TafsirMarkup.parse(text);
      expect(runs, hasLength(1));
      expect(runs.single.kind, TafsirRunKind.plain);
      expect(runs.single.text, text);
      expect(TafsirMarkup.strip(text), text);
    });

    test('a verse span becomes a verse run between plain runs', () {
      const text = 'خداوند می‌فرماید '
          '<span class="arabic uthmani">إِنَّا أَعْطَيْنَاكَ الْكَوْثَرَ</span>'
          ' و این نعمتی بزرگ است.';
      final runs = TafsirMarkup.parse(text);
      expect(runs.map((r) => r.kind), [
        TafsirRunKind.plain,
        TafsirRunKind.verse,
        TafsirRunKind.plain,
      ]);
      expect(runs[1].text, 'إِنَّا أَعْطَيْنَاكَ الْكَوْثَرَ');
      expect(TafsirMarkup.strip(text), contains('إِنَّا أَعْطَيْنَاكَ الْكَوْثَرَ'));
      expect(TafsirMarkup.strip(text), isNot(contains('<')));
      expect(TafsirMarkup.strip(text), isNot(contains('span')));
    });

    test('a saw span becomes a honorific run', () {
      const text = 'از پیامبر <span class="saw">صلى الله عليه وسلم</span> روایت شده است.';
      final runs = TafsirMarkup.parse(text);
      expect(runs[1].kind, TafsirRunKind.honorific);
      expect(runs[1].text, 'صلى الله عليه وسلم');
    });

    test('only recognised span tags are stripped; a bare < survives', () {
      const text = 'a < b و <b>bold</b> هم متن است.';
      final runs = TafsirMarkup.parse(text);
      expect(runs, hasLength(1));
      expect(runs.single.text, text);
    });

    test('adjacent runs of the same kind merge', () {
      const text = 'A <span class="saw">x</span><span class="saw">y</span> B';
      final runs = TafsirMarkup.parse(text);
      expect(runs.map((r) => r.kind), [
        TafsirRunKind.plain,
        TafsirRunKind.honorific,
        TafsirRunKind.plain,
      ]);
      expect(runs[1].text, 'xy');
    });

    test('parse is lossless — stripping every tag keeps all characters', () {
      const text = 'قبل <span class="arabic uthmani">آية</span> بین '
          '<span class="saw">صلى الله عليه وسلم</span> بعد';
      expect(TafsirMarkup.strip(text), 'قبل آية بین صلى الله عليه وسلم بعد');
    });
  });
}
