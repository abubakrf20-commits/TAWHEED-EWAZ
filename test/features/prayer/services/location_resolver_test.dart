import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:tawheeed/features/prayer/services/location_resolver.dart';

Placemark placemark({
  String? locality,
  String? subLocality,
  String? subAdministrativeArea,
}) {
  return Placemark(
    name: '',
    street: '',
    isoCountryCode: 'IR',
    country: 'ایران',
    postalCode: '',
    administrativeArea: '',
    subAdministrativeArea: subAdministrativeArea ?? '',
    locality: locality ?? '',
    subLocality: subLocality ?? '',
    thoroughfare: '',
    subThoroughfare: '',
  );
}

void main() {
  group('pickOnlineName', () {
    test('nominatim village wins and is marked small level', () {
      final result = LocationResolver.pickOnlineName(
        system: placemark(locality: 'تهران'),
        nominatim: {'village': 'شیرگاه', 'county': 'سوادکوه شمالی'},
      );
      expect(result, isNotNull);
      expect(result!.name, 'شیرگاه');
      expect(result.isSmallLevel, isTrue);
    });

    test('nominatim town wins over device locality', () {
      final result = LocationResolver.pickOnlineName(
        system: placemark(locality: 'ساری'),
        nominatim: {'town': 'کامیاران'},
      );
      expect(result!.name, 'کامیاران');
      expect(result.isSmallLevel, isTrue);
    });

    test('device subLocality (محله) wins over city-level names', () {
      final result = LocationResolver.pickOnlineName(
        system: placemark(subLocality: 'محله آزادی', locality: 'تهران'),
        nominatim: {'city': 'تهران'},
      );
      expect(result!.name, 'محله آزادی');
      expect(result.isSmallLevel, isTrue);
    });

    test('nominatim city beats device locality', () {
      final result = LocationResolver.pickOnlineName(
        system: placemark(locality: 'تهران'),
        nominatim: {'city': 'مشهد'},
      );
      expect(result!.name, 'مشهد');
      expect(result.isSmallLevel, isFalse);
    });

    test('device locality used when no smaller level exists', () {
      final result = LocationResolver.pickOnlineName(
        system: placemark(locality: 'کرج'),
        nominatim: {'county': 'البرز'},
      );
      expect(result!.name, 'کرج');
      expect(result.isSmallLevel, isFalse);
    });

    test('municipality/county fallback', () {
      final result = LocationResolver.pickOnlineName(
        system: placemark(subAdministrativeArea: 'استان فارس'),
        nominatim: {'municipality': 'شیراز'},
      );
      expect(result!.name, 'شیراز');
      expect(result.isSmallLevel, isFalse);
    });

    test('subAdministrativeArea as last resort', () {
      final result = LocationResolver.pickOnlineName(
        system: placemark(subAdministrativeArea: 'استان فارس'),
        nominatim: null,
      );
      expect(result!.name, 'استان فارس');
      expect(result.isSmallLevel, isFalse);
    });

    test('returns null when nothing is available', () {
      expect(
        LocationResolver.pickOnlineName(system: null, nominatim: null),
        isNull,
      );
    });

    test('empty nominatim values are skipped', () {
      final result = LocationResolver.pickOnlineName(
        system: placemark(locality: 'تهران'),
        nominatim: {'village': '  ', 'town': ''},
      );
      expect(result!.name, 'تهران');
    });
  });

  group('resolveFinalName', () {
    test('small-level online name always wins (the tapped place itself)', () {
      final result = LocationResolver.resolveFinalName(
        onlineName: 'شیرگاه',
        onlineIsSmallLevel: true,
        nearestCityName: 'سوادکوه شمالی',
        nearestCityDistanceKm: 2.0,
      );
      expect(result, 'شیرگاه');
    });

    test('matching offline city within radius keeps canonical offline name',
        () {
      final result = LocationResolver.resolveFinalName(
        onlineName: 'تهران',
        onlineIsSmallLevel: false,
        nearestCityName: 'تهران',
        nearestCityDistanceKm: 1.5,
      );
      expect(result, 'تهران');
    });

    test('names compared with ZWNJ normalization', () {
      final result = LocationResolver.resolveFinalName(
        onlineName: 'بستان\u200cآباد',
        onlineIsSmallLevel: false,
        nearestCityName: 'بستان‌آباد',
        nearestCityDistanceKm: 0.8,
      );
      expect(result, 'بستان‌آباد');
    });

    test('offline city beyond radius does not replace online name', () {
      final result = LocationResolver.resolveFinalName(
        onlineName: 'تهران',
        onlineIsSmallLevel: false,
        nearestCityName: 'تهران',
        nearestCityDistanceKm: 12.0,
      );
      expect(result, 'تهران');
    });

    test('mismatched names keep the online name even close by', () {
      final result = LocationResolver.resolveFinalName(
        onlineName: 'ری',
        onlineIsSmallLevel: false,
        nearestCityName: 'تهران',
        nearestCityDistanceKm: 3.0,
      );
      expect(result, 'ری');
    });

    test('null online name falls back to nearest offline city', () {
      final result = LocationResolver.resolveFinalName(
        onlineName: null,
        onlineIsSmallLevel: false,
        nearestCityName: 'ساری',
        nearestCityDistanceKm: 40.0,
      );
      expect(result, 'ساری');
    });
  });

  group('normalizeName', () {
    test('strips ZWNJ and whitespace', () {
      expect(LocationResolver.normalizeName(' بستان\u200cآباد '), 'بستانآباد');
      expect(LocationResolver.normalizeName('شهر  قدس'), 'شهرقدس');
    });
  });
}
