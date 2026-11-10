import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/utils/latinize_json_digits.dart';

void main() {
  group('latinizeJsonDigits', () {
    test('folds Persian and Arabic-Indic digits in nested values', () {
      final out = latinizeJsonDigits({
        'title': 'مرحله ۴: حلق',
        'steps': ['روز ۸ ذی‌حجه', 'شب ۱۰ ذی‌حجه'],
        'quote': '﴿١﴾ الْحَمْدُ',
        'count': 7,
        'ok': true,
      }) as Map<String, dynamic>;

      expect(out['title'], 'مرحله 4: حلق');
      expect(out['steps'], ['روز 8 ذی‌حجه', 'شب 10 ذی‌حجه']);
      expect(out['quote'], '﴿1﴾ الْحَمْدُ');
      expect(out['count'], 7);
      expect(out['ok'], isTrue);
    });

    test('keeps the Map<String, dynamic> type loaders cast to', () {
      // Mirrors the loaders: the folded result must still cast to
      // Map<String, dynamic>, which a plain map comprehension would break.
      final decoded = jsonDecode('{"a": {"b": "۱"}}');
      final folded = latinizeJsonDigits(decoded);
      expect(folded, isA<Map<String, dynamic>>());
      expect(
          (folded as Map<String, dynamic>)['a'], isA<Map<String, dynamic>>());
      expect(folded['a']['b'], '1');
    });

    test('passes a non-textual tree through unchanged', () {
      final out = latinizeJsonDigits({
        'n': 3.5,
        'l': [1, 2]
      }) as Map<String, dynamic>;
      expect(out['n'], 3.5);
      expect(out['l'], [1, 2]);
    });
  });
}
