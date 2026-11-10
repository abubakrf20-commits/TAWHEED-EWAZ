import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/calculator/data/units/local_unit.dart';
import 'package:tawheeed/features/tools/calculator/data/units/unit_converter.dart';
import 'package:tawheeed/features/tools/calculator/data/units/unit_models.dart';

UnitsCatalog shipped() =>
    UnitsCatalog.parse(File('assets/data/units.json').readAsStringSync());

void main() {
  const engine = UnitConverterEngine();
  final catalog = shipped();

  group('shipped units.json', () {
    test('parses every category', () {
      expect(
        catalog.categories.map((c) => c.id).toList(),
        ['length', 'mass', 'area', 'volume', 'temperature', 'speed', 'local'],
      );
    });

    test('every category except temperature has at least two units', () {
      for (final category in catalog.categories) {
        if (category.isTemperature) continue;
        expect(category.units.length, greaterThanOrEqualTo(2),
            reason: '${category.id} needs at least two units');
      }
    });

    test('temperature has three scales and no factors', () {
      final t = catalog.categoryById('temperature')!;
      expect(t.isTemperature, isTrue);
      expect(t.units.map((u) => u.id).toList(), ['c', 'f', 'k']);
      expect(t.units.every((u) => u.factor == 1), isTrue);
    });

    test('every non-temperature factor is positive', () {
      for (final category in catalog.categories) {
        if (category.isTemperature) continue;
        for (final unit in category.units) {
          expect(unit.factor, greaterThan(0),
              reason: '${category.id}/${unit.id}');
        }
      }
    });

    test('the five local defaults ship unverified, exactly as specified', () {
      final local = catalog.categoryById('local')!;
      expect(local.isLocal, isTrue);
      final defaults = local.units.where((u) => u.factor != 1);
      final localOnes = defaults.where((u) => u.id != 'kg_local');
      expect(localOnes.every((u) => !u.verified), isTrue);
      final factors = {
        for (final u in local.units) u.id: u.factor,
      };
      expect(factors['man_tabriz'], 3000); // 3 kg
      expect(factors['sir'], 75);
      expect(factors['mesghal'], 4.608);
      expect(factors['nokhod'], 0.192);
      expect(factors['kharvar'], 300000); // 300 kg = 100 من تبریز
    });

    test('خروار is exactly 100 من تبریز', () {
      final local = catalog.categoryById('local')!;
      final man = local.unitById('man_tabriz')!.factor;
      final kharvar = local.unitById('kharvar')!.factor;
      expect(kharvar, man * 100);
    });

    test('the region note is present for the UI', () {
      expect(catalog.note.contains('منطقه'), isTrue);
      expect(catalog.localNote.contains('قابل ویرایش'), isTrue);
    });
  });

  group('conversion', () {
    double? run(String categoryId, String from, String to, double value,
            {List<LocalUnit> locals = const []}) =>
        engine.convert(
          category: catalog.categoryById(categoryId)!,
          fromId: from,
          toId: to,
          value: value,
          localUnits: locals,
        );

    test('length: 1 m = 100 cm and back', () {
      expect(run('length', 'm', 'cm', 1), 100);
      expect(run('length', 'cm', 'm', 100), 1);
      expect(run('length', 'km', 'mm', 1), 1000000);
    });

    test('mass: 1 kg = 1000 g; 1 lb = 453.59237 g', () {
      expect(run('mass', 'kg', 'g', 1), 1000);
      expect(run('mass', 'lb', 'g', 1), closeTo(453.59237, 1e-6));
    });

    test('area: 10,000 m² = 1 hectare', () {
      expect(run('area', 'm2', 'ha', 10000), 1);
      expect(run('area', 'km2', 'm2', 1), 1000000);
    });

    test('volume: 1 L = 1000 mL; 1 gallon (UK) > 1 gallon (US)', () {
      expect(run('volume', 'l', 'ml', 1), 1000);
      expect(
        run('volume', 'gal_uk', 'l', 1)!,
        greaterThan(run('volume', 'gal_us', 'l', 1)!),
      );
    });

    test('speed: 3.6 km/h = 1 m/s', () {
      expect(run('speed', 'kmh', 'mps', 3.6), closeTo(1, 1e-9));
      expect(run('speed', 'mps', 'kmh', 1), closeTo(3.6, 1e-9));
    });

    test('temperature uses formulas, not factors', () {
      expect(run('temperature', 'c', 'f', 100), 212);
      expect(run('temperature', 'f', 'c', 32), 0);
      expect(run('temperature', 'c', 'k', 0), closeTo(273.15, 1e-9));
      expect(run('temperature', 'k', 'c', 273.15), closeTo(0, 1e-9));
      expect(run('temperature', 'f', 'k', 32), closeTo(273.15, 1e-9));
      expect(run('temperature', 'c', 'c', 21), 21);
    });

    test('temperature accepts negatives', () {
      expect(run('temperature', 'c', 'f', -40), -40);
    });

    test('a negative length is refused', () {
      expect(run('length', 'm', 'cm', -1), isNull);
    });

    test('an unknown unit is refused instead of guessed', () {
      expect(run('length', 'nope', 'cm', 1), isNull);
    });

    test('local: 1 من (تبریز) = 3000 گم and the reverse', () {
      expect(run('local', 'man_tabriz', 'g', 1), 3000);
      expect(run('local', 'g', 'man_tabriz', 3000), 1);
    });

    test('local: خروار ↔ من (تبریز) is 100', () {
      expect(run('local', 'kharvar', 'man_tabriz', 1), 100);
    });

    test('a user override replaces the shipped base', () {
      const override = LocalUnit(
        id: 'man_tabriz',
        name: 'من (تبریز)',
        factor: 5000,
        baseUnit: 'گرم',
        isUserEdited: true,
      );
      expect(
        run('local', 'man_tabriz', 'g', 1, locals: const [override]),
        5000,
      );
    });

    test('a user-added unit converts against the base', () {
      const zar = LocalUnit(
        id: 'zar',
        name: 'ذرع',
        factor: 1040,
        baseUnit: 'گرم',
        isUserEdited: true,
      );
      expect(run('local', 'zar', 'g', 2, locals: const [zar]), 2080);
      // and it appears in the picker list
      final units = engine.unitsOf(
        catalog.categoryById('local')!,
        const [zar],
      );
      expect(units.any((u) => u.id == 'zar'), isTrue);
    });
  });

  group('display', () {
    test('6 significant digits, no float noise', () {
      expect(formatConvertedValue(0.30000000000000004), '0.3');
      expect(formatConvertedValue(1 / 3), '0.333333');
      expect(formatConvertedValue(2.5), '2.5');
    });

    test('thousands are separated', () {
      expect(formatConvertedValue(1234567), '1,234,570'); // 6 significant digits
      expect(formatConvertedValue(1234.5), '1,234.5');
    });

    test('persian digits swap only the digits', () {
      expect(formatConvertedValue(1234.5, persianDigits: true), '۱,۲۳۴.۵');
      expect(toPersianDigits('1404/07/10'), '۱۴۰۴/۰۷/۱۰');
    });

    test('negative values keep their sign', () {
      expect(formatConvertedValue(-2.5), '-2.5');
    });

    test('very small values fall back to exponent form', () {
      expect(formatConvertedValue(0.0000001).contains('e'), isTrue);
    });
  });

  group('rounding helper', () {
    test('rounds to significant digits', () {
      expect(roundToSignificant(1.23456789, 4), 1.235);
      expect(roundToSignificant(0.000123456, 3), 0.000123);
      expect(roundToSignificant(0, 6), 0);
    });
  });
}
