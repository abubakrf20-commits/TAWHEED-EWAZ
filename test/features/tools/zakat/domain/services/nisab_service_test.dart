import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/tools/zakat/domain/services/nisab_service.dart';

void main() {
  group('NisabService', () {
    test('نصاب طلا = 85 × قیمت هر گرم', () {
      expect(NisabService.nisabByGold(1000), 85000);
      expect(NisabService.goldNisabGrams, 85);
    });

    test('نصاب نقره = 595 × قیمت هر گرم', () {
      expect(NisabService.nisabBySilver(1000), 595000);
      expect(NisabService.silverNisabGrams, 595);
    });
  });
}
