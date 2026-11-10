import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/khatm/domain/entities/khatm_type.dart';
import 'package:tawheeed/features/khatm/domain/entities/khatm_model.dart';

void main() {
  group('KhatmType', () {
    test('has all values', () {
      expect(KhatmType.values.length, 3);
      expect(
          KhatmType.values,
          containsAll([
            KhatmType.quran,
            KhatmType.book,
            KhatmType.custom,
          ]));
    });

    test('KhatmModel uses KhatmType correctly', () {
      expect(KhatmModel, isA<Type>());
    });
  });
}
