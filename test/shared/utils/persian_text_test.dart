import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/shared/utils/persian_text.dart';

void main() {
  group('spacedZwnj', () {
    test('turns نیم‌فاصله into a regular space', () {
      expect(spacedZwnj('خوش\u200Cاخلاق\u200Cترین'), 'خوش اخلاق ترین');
    });

    test('leaves text without نیم‌فاصله unchanged', () {
      expect(spacedZwnj('پیامبر صلی الله'), 'پیامبر صلی الله');
      expect(spacedZwnj(''), '');
    });

    test('removes every نیم‌فاصله, not just the first', () {
      const input = 'الف\u200Cب\u200Cپ\u200Cت';
      expect(spacedZwnj(input).contains('\u200C'), isFalse);
      expect(spacedZwnj(input), 'الف ب پ ت');
    });
  });
}
