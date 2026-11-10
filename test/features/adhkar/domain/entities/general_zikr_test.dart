import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/adhkar/domain/entities/general_zikr.dart';

void main() {
  group('GeneralZikr', () {
    test('constructor sets required fields', () {
      final zikr = GeneralZikr(id: '1', arabicText: 'سبحان الله');
      expect(zikr.id, '1');
      expect(zikr.arabicText, 'سبحان الله');
    });

    test('constructor sets default values', () {
      final zikr = GeneralZikr(id: '1', arabicText: 'الحمد لله');
      expect(zikr.targetCount, 100);
      expect(zikr.isDefault, true);
      expect(zikr.isEnabled, true);
      expect(zikr.currentCount, 0);
    });

    test('constructor sets custom values', () {
      final zikr = GeneralZikr(
        id: '2',
        arabicText: 'الله أكبر',
        targetCount: 33,
        isDefault: false,
        isEnabled: false,
        currentCount: 10,
      );
      expect(zikr.targetCount, 33);
      expect(zikr.isDefault, false);
      expect(zikr.isEnabled, false);
      expect(zikr.currentCount, 10);
    });

    test('currentCount is mutable', () {
      final zikr = GeneralZikr(id: '1', arabicText: 'سبحان الله');
      zikr.currentCount = 5;
      expect(zikr.currentCount, 5);
    });

    test('isEnabled is mutable', () {
      final zikr = GeneralZikr(id: '1', arabicText: 'سبحان الله');
      zikr.isEnabled = false;
      expect(zikr.isEnabled, false);
    });

    group('copyWith', () {
      test('creates new object with same field values when no args', () {
        final zikr = GeneralZikr(id: '1', arabicText: 'الحمد لله');
        final copy = zikr.copyWith();
        expect(copy.id, zikr.id);
        expect(copy.arabicText, zikr.arabicText);
      });

      test('replaces single field', () {
        final zikr = GeneralZikr(id: '1', arabicText: 'الحمد لله');
        final copy = zikr.copyWith(targetCount: 33);
        expect(copy.targetCount, 33);
        expect(copy.arabicText, 'الحمد لله');
      });
    });
  });
}
