import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/calculator/domain/unit_conversion.dart';

/// Unit tests for the converter's new categories and the local-unit rule.
void main() {
  group('area and speed (new categories)', () {
    test('area: 1 hectare = 10,000 m²', () {
      expect(
        convertUnits(
          category: UnitCategory.area,
          value: 1,
          from: 'هکتار',
          to: 'متر مربع',
          localBasesKg: const {},
        ),
        10000,
      );
    });

    test('area: 1 jrib = 4046.8564224 m²', () {
      expect(
        convertUnits(
          category: UnitCategory.area,
          value: 1,
          from: 'جریب',
          to: 'متر مربع',
          localBasesKg: const {},
        ),
        closeTo(4046.8564224, 1e-9),
      );
    });

    test('speed: 36 km/h = 10 m/s', () {
      expect(
        convertUnits(
          category: UnitCategory.speed,
          value: 36,
          from: 'کیلومتر بر ساعت',
          to: 'متر بر ثانیه',
          localBasesKg: const {},
        ),
        10,
      );
    });

    test('speed: 1 knot = 1852 m/h exactly', () {
      expect(
        convertUnits(
          category: UnitCategory.speed,
          value: 1,
          from: 'گره (ناتیکال)',
          to: 'متر بر ثانیه',
          localBasesKg: const {},
        ),
        closeTo(1852 / 3600, 1e-12),
      );
    });
  });

  group('local units (محلی ★)', () {
    test('the five shipped defaults convert against each other', () {
      final bases = {
        for (final u in defaultLocalUnits) u.name: u.defaultBaseKg,
      };
      // 1 من = 40 سیر (3 kg / 0.075 kg).
      expect(
        convertUnits(
          category: UnitCategory.local,
          value: 1,
          from: 'من (تبریز)',
          to: 'سیر',
          localBasesKg: bases,
        ),
        40,
      );
      // 1 خروار = 100 من (300 / 3).
      expect(
        convertUnits(
          category: UnitCategory.local,
          value: 1,
          from: 'خروار',
          to: 'من (تبریز)',
          localBasesKg: bases,
        ),
        100,
      );
      // 1 مثقال = 24 نخود.
      expect(
        convertUnits(
          category: UnitCategory.local,
          value: 1,
          from: 'مثقال',
          to: 'نخود',
          localBasesKg: bases,
        ),
        24,
      );
    });

    test('local units bridge into kilograms', () {
      final bases = {
        for (final u in defaultLocalUnits) u.name: u.defaultBaseKg,
      };
      expect(
        convertUnits(
          category: UnitCategory.local,
          value: 2,
          from: 'من (تبریز)',
          to: 'کیلوگرم',
          localBasesKg: bases,
        ),
        6,
      );
    });

    test('an unset base returns null — never a guess (the brief\'s rule)', () {
      expect(
        convertUnits(
          category: UnitCategory.local,
          value: 1,
          from: 'قپان',
          to: 'من (تبریز)',
          localBasesKg: {'من (تبریز)': 3},
        ),
        isNull,
        reason: 'قپان has no base: the UI must show «مبنا را وارد کنید»',
      );
    });

    test('an edited base changes the conversion (editability is real)', () {
      // The user corrects their من to 2.5 kg.
      final edited = {
        'من (تبریز)': 2.5,
        'سیر': 0.075,
      };
      expect(
        convertUnits(
          category: UnitCategory.local,
          value: 1,
          from: 'من (تبریز)',
          to: 'سیر',
          localBasesKg: edited,
        ),
        closeTo(2.5 / 0.075, 1e-9),
      );
    });
  });

  group('formatUnitValue (6 significant digits)', () {
    test('drops trailing zeros', () {
      expect(formatUnitValue(1.500), '1.5');
      expect(formatUnitValue(2.0), '2');
    });

    test('six significant digits then round', () {
      expect(formatUnitValue(1 / 3), '0.333333');
      expect(formatUnitValue(1234567.0), '1234567');
      expect(formatUnitValue(0.000192), '0.000192');
    });

    test('extremes go exponential', () {
      expect(formatUnitValue(1e20), contains('e'));
      expect(formatUnitValue(1e-15), contains('e'));
    });
  });

  test('every shipped local unit has a positive base', () {
    for (final u in defaultLocalUnits) {
      expect(u.defaultBaseKg, greaterThan(0), reason: u.name);
    }
    expect(defaultLocalUnits, hasLength(5),
        reason: 'the brief ships exactly the five documented units');
  });
}
