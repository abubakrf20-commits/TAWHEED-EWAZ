import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/zakat/domain/entities/zakat_input.dart';

void main() {
  group('ZakatInput', () {
    test('constructor sets default values', () {
      const input = ZakatInput();
      expect(input.cashAndBank, 0.0);
      expect(input.goldGrams, 0.0);
      expect(input.goldKarat, 24);
      expect(input.goldPricePerGram24, 0.0);
      expect(input.silverGrams, 0.0);
      expect(input.silverPricePerGram, 0.0);
      expect(input.businessValue, 0.0);
      expect(input.debts, 0.0);
      expect(input.hawlComplete, false);
    });

    test('constructor sets custom values', () {
      const input = ZakatInput(
        cashAndBank: 50000000,
        goldGrams: 100,
        goldKarat: 18,
        goldPricePerGram24: 3000000,
        silverGrams: 500,
        silverPricePerGram: 40000,
        businessValue: 20000000,
        debts: 10000000,
        hawlComplete: true,
      );
      expect(input.cashAndBank, 50000000);
      expect(input.goldGrams, 100);
      expect(input.goldKarat, 18);
      expect(input.goldPricePerGram24, 3000000);
      expect(input.silverGrams, 500);
      expect(input.silverPricePerGram, 40000);
      expect(input.businessValue, 20000000);
      expect(input.debts, 10000000);
      expect(input.hawlComplete, true);
    });

    group('copyWith', () {
      test('creates new object with same field values when no args', () {
        const input = ZakatInput();
        final copy = input.copyWith();
        expect(copy.cashAndBank, input.cashAndBank);
        expect(copy.goldGrams, input.goldGrams);
      });

      test('replaces single field', () {
        const input = ZakatInput();
        final copy = input.copyWith(cashAndBank: 100000);
        expect(copy.cashAndBank, 100000);
        expect(copy.goldGrams, 0);
      });
    });
  });
}
