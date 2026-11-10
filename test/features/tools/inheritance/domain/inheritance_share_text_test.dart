import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/inheritance_share_text.dart';
import 'package:tawheeed/features/tools/inheritance/domain/madhab_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/mandatory_will.dart';

void main() {
  test('inheritanceMoney formats thousands separators', () {
    expect(inheritanceMoney(450000), '450,000');
    expect(inheritanceMoney(1234.5), '1,234.50');
    expect(inheritanceMoney(0), '0');
  });

  test('buildInheritanceShareText contains header, heirs and footer', () {
    final result =
        getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
      estate: 12000,
      wife: 1,
      daughter: 2,
    ));
    final text = buildInheritanceShareText(result: result, estate: 12000);

    expect(text, contains('نتایج تقسیم میراث'));
    expect(text, contains('ترکه: 12,000'));
    expect(text, contains('مذهب / قانون: جمهور'));
    expect(text, contains('سهم هر وارث:'));
    expect(text, contains('همسر'));
    expect(text, contains('دختر (2 نفر)'));
    expect(text, contains('— ساخته شده با برنامهٔ توحید'));
  });

  test('buildInheritanceShareText includes warning lines', () {
    const result = InheritanceResult(
      estate: 100,
      netEstate: 100,
      madhab: Madhab.jumhur,
      shares: [],
      method: 'normal',
      warnings: ['هشدار آزمایشی'],
    );
    final text = buildInheritanceShareText(result: result, estate: 100);
    expect(text, contains('⚠️ هشدار آزمایشی'));
  });

  group('hareAllocate / harePercents (display rounding sums exactly)', () {
    test('percents always sum to 100', () {
      expect(harePercents([1500, 10500]).reduce((a, b) => a + b), 100);
      // 12.5 / 87.5 tie: the leftover unit goes to the lower index.
      expect(harePercents([1500, 10500]), [13, 87]);
      expect(harePercents([1, 1, 1]), [34, 33, 33]);
      expect(harePercents([10]), [100]);
      expect(harePercents([]), isEmpty);
    });

    test('allocated amounts sum exactly to the target total', () {
      final parts = hareAllocate([1, 1, 1], 10000);
      expect(parts.fold<double>(0, (a, b) => a + b), closeTo(10000, 1e-9));
      expect(parts, [3333.34, 3333.33, 3333.33]);
    });

    test('listed amounts in the share text add up to the estate', () {
      final result =
          getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
        estate: 12000,
        wife: 1,
        daughter: 2,
      ));
      final text = buildInheritanceShareText(result: result, estate: 12000);
      // 1500 + 10500 = 12000 exactly (no per-row independent rounding).
      expect(text, contains('1,500'));
      expect(text, contains('10,500'));
    });
  });

  test('UAE is in the mandatory will law list', () {
    final uae = mandatoryWillLaws.where((l) => l.country == 'امارات');
    expect(uae.length, 1, reason: 'UAE law should be present');
    expect(uae.first.codeName, contains('مادهٔ 272'));
    expect(uae.first.capFraction, 1 / 3);
  });
}
