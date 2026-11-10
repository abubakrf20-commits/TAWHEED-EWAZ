import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/hadeeth_enc/domain/entities/hadeeth_enc_hadith.dart';

void main() {
  group('HadeethEncHadith.fromRow', () {
    test('maps all columns with proper trimming', () {
      final h = HadeethEncHadith.fromRow({
        'id': 1751,
        'title_ar': '  متن عربی  ',
        'title': '  ترجمه عنوان  ',
        'text_ar': '  حدیث عربی  ',
        'text': '  حدیث فارسی  ',
        'explanation': '  شرح  ',
        'benefits': '  منافع  ',
        'grade': ' [صحیح است] ',
        'takhrij': ' [متفق علیه] ',
        'link': ' https://hadeethenc.com/fa/browse/hadith/1751 ',
        'category': ' فقه عبادات ',
      });
      expect(h.id, 1751);
      expect(h.titleAr, 'متن عربی');
      expect(h.title, 'ترجمه عنوان');
      expect(h.textAr, 'حدیث عربی');
      expect(h.text, 'حدیث فارسی');
      expect(h.explanation, 'شرح');
      expect(h.benefits, 'منافع');
      expect(h.grade, '[صحیح است]');
      expect(h.takhrij, '[متفق علیه]');
      expect(h.link, 'https://hadeethenc.com/fa/browse/hadith/1751');
      expect(h.category, 'فقه عبادات');
    });

    test('null values become empty strings', () {
      final h = HadeethEncHadith.fromRow({
        'id': 1,
        'text_ar': 'عربی',
        'text': 'فارسی',
        'title_ar': null,
        'title': null,
        'explanation': null,
        'benefits': null,
        'grade': null,
        'takhrij': null,
        'link': null,
      });
      expect(h.titleAr, '');
      expect(h.title, '');
      expect(h.explanation, '');
      expect(h.benefits, '');
      expect(h.grade, '');
      expect(h.takhrij, '');
    });

    test('sequence is parsed when present and null when absent', () {
      final withSeq = HadeethEncHadith.fromRow({
        'id': 1751,
        'text_ar': 'عربی',
        'text': 'فارسی',
        'sequence': 42,
      });
      expect(withSeq.sequence, 42);

      final withoutSeq = HadeethEncHadith.fromRow({
        'id': 1751,
        'text_ar': 'عربی',
        'text': 'فارسی',
      });
      expect(withoutSeq.sequence, isNull);
    });
  });
}
