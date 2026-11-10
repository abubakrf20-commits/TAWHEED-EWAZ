import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/prayer/data/prayer_method_by_country.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings_options.dart';

void main() {
  group('countryOfCity', () {
    test('maps a bundled world city to its country label', () {
      expect(countryOfCity('مکه'), 'عربستان');
      expect(countryOfCity('قاهره'), 'مصر');
      expect(countryOfCity('استانبول'), 'ترکیه');
      expect(countryOfCity('لندن'), 'انگلستان');
      expect(countryOfCity('پاریس'), 'فرانسه');
    });

    test('an Iranian town is recognised from the province table', () {
      expect(countryOfCity('تهران'), 'ایران');
      expect(countryOfCity('اصفهان'), 'ایران');
      // A town only the Iran table holds (not in worldCities).
      expect(countryOfCity('مراغه'), 'ایران');
    });

    test('unknown, empty and null names yield null', () {
      expect(countryOfCity(null), isNull);
      expect(countryOfCity(''), isNull);
      expect(countryOfCity('دهکدهٔ ناشناخته'), isNull);
    });

    test('a name in both tables is disambiguated by the nearest position', () {
      // «احمدآباد» is an Iranian town (32.3577, 53.9922) and an Indian city
      // (23.0225, 72.5714) — hundreds of km apart.
      expect(countryOfCity('احمدآباد', lat: 32.3577, lng: 53.9922), 'ایران');
      expect(countryOfCity('احمدآباد', lat: 23.0225, lng: 72.5714), 'هند');
      // With no position, the world table's entry wins (documented fallback).
      expect(countryOfCity('احمدآباد'), 'هند');
    });
  });

  group('calculationMethodForCity', () {
    test('named-method countries resolve to their method', () {
      expect(calculationMethodForCity('مکه'),
          CalculationMethodOption.ummAlQura);
      expect(calculationMethodForCity('دبی'), CalculationMethodOption.dubai);
      expect(calculationMethodForCity('دوحه'), CalculationMethodOption.qatar);
      expect(
          calculationMethodForCity('کویت'), CalculationMethodOption.kuwait);
      expect(calculationMethodForCity('قاهره'),
          CalculationMethodOption.egyptian);
      expect(
          calculationMethodForCity('آنکارا'), CalculationMethodOption.turkey);
      expect(
          calculationMethodForCity('کراچی'), CalculationMethodOption.karachi);
      expect(calculationMethodForCity('نیویورک'),
          CalculationMethodOption.northAmerica);
      expect(calculationMethodForCity('تورنتو'),
          CalculationMethodOption.northAmerica);
      // JAKIM / Kemenag apply the Singapore method's 20°/18° pair.
      expect(calculationMethodForCity('کوالالامپور'),
          CalculationMethodOption.singapore);
      expect(calculationMethodForCity('جاکارتا'),
          CalculationMethodOption.singapore);
      expect(
          calculationMethodForCity('پاریس'), CalculationMethodOption.france);
      expect(calculationMethodForCity('مسکو'), CalculationMethodOption.russia);
    });

    test('Iran maps to MWL by the user decision (2026-10-13)', () {
      expect(calculationMethodForCity('تهران'),
          CalculationMethodOption.muslimWorldLeague);
      expect(calculationMethodForCity('مراغه'),
          CalculationMethodOption.muslimWorldLeague);
    });

    test('the picked position decides a shared name', () {
      // A user in the Iranian احمدآباد must not get India's Karachi method.
      expect(
        calculationMethodForCity('احمدآباد', lat: 32.3577, lng: 53.9922),
        CalculationMethodOption.muslimWorldLeague,
      );
      expect(
        calculationMethodForCity('احمدآباد', lat: 23.0225, lng: 72.5714),
        CalculationMethodOption.karachi,
      );
    });

    test('a position never changes a name unique to one table', () {
      expect(
        calculationMethodForCity('مکه', lat: 0, lng: 0),
        CalculationMethodOption.ummAlQura,
      );
      expect(
        calculationMethodForCity('تهران', lat: 0, lng: 0),
        CalculationMethodOption.muslimWorldLeague,
      );
    });

    test('a country without a named method falls back to MWL', () {
      expect(calculationMethodForCity('لندن'),
          CalculationMethodOption.muslimWorldLeague);
      expect(calculationMethodForCity('دهکدهٔ ناشناخته'),
          CalculationMethodOption.muslimWorldLeague);
      expect(calculationMethodForCity(null),
          CalculationMethodOption.muslimWorldLeague);
    });
  });
}
