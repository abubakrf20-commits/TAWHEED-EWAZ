import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/prayer/data/iran_cities.dart';
import 'package:tawheeed/features/prayer/data/place_index.dart';
import 'package:tawheeed/features/prayer/data/world_cities.dart';

/// Guards the offline place tables that make prayer times usable outside Iran.
void main() {
  group('world city table', () {
    test('is large, in range and free of duplicate names', () {
      expect(worldCities.length, greaterThanOrEqualTo(200));
      final seen = <String>{};
      for (final city in worldCities) {
        expect(city.lat, inInclusiveRange(-90, 90), reason: city.name);
        expect(city.lng, inInclusiveRange(-180, 180), reason: city.name);
        expect(city.name.trim(), isNotEmpty);
        expect(city.country.trim(), isNotEmpty);
        expect(seen.add(city.name), isTrue,
            reason: 'duplicate name ${city.name} makes offline lookup '
                'ambiguous');
      }
    });

    test('covers every inhabited continent', () {
      for (final name in const [
        'مکه',
        'قاهره',
        'استانبول',
        'لاگوس',
        'نئی‌دهلی',
        'جاکارتا',
        'توکیو',
        'لندن',
        'مسکو',
        'نیویورک',
        'سائوپائولو',
        'سیدنی',
        'کیپ‌تاون',
      ]) {
        expect(PlaceIndex.findUnique(name)?.name, name,
            reason: '$name should resolve offline');
      }
    });

    test('anchor coordinates match the real places', () {
      // Loose enough to allow a city-centre choice, tight enough to catch a
      // swapped or mistyped pair: 0.5° is ~55 km and ~2 minutes of prayer time.
      const anchors = {
        'مکه': (21.42, 39.83),
        'مدینه': (24.47, 39.61),
        'استانبول': (41.01, 28.98),
        'لندن': (51.51, -0.13),
        'نیویورک': (40.71, -74.01),
        'سیدنی': (-33.87, 151.21),
        'جاکارتا': (-6.21, 106.85),
        'ریکیاویک': (64.15, -21.94),
      };
      anchors.forEach((name, expected) {
        final place = PlaceIndex.findUnique(name)!;
        expect(place.lat, closeTo(expected.$1, 0.5), reason: name);
        expect(place.lng, closeTo(expected.$2, 0.5), reason: name);
      });
    });
  });

  group('PlaceIndex', () {
    test('drops Iranian rows whose coordinates belong to another country', () {
      // A handful of village rows in the bundled Iran table carry points that
      // are not in Iran at all (Malta, Casablanca, Astana…). Returning one of
      // those would compute times for the wrong latitude, so the index filters
      // them and the caller falls back to GPS/geocoding instead.
      expect(PlaceIndex.outOfRegionIranEntries(), greaterThan(0),
          reason: 'the guard test should still see the known-bad rows');
      for (final province in iranProvinces) {
        for (final city in province.cities) {
          final present = PlaceIndex.places
              .any((p) => p.name == city.name && p.lat == city.lat);
          if (!present) {
            final insideIran = city.lat >= 25.0 &&
                city.lat <= 39.8 &&
                city.lng >= 44.0 &&
                city.lng <= 63.4;
            expect(insideIran, isFalse,
                reason: '${city.name} (${city.lat}, ${city.lng}) was filtered '
                    'but is inside Iran');
          }
        }
      }
    });

    test('search ranks exact before prefix before substring', () {
      final hits = PlaceIndex.search('لندن');
      expect(hits.first.name, 'لندن');
      expect(PlaceIndex.search('ته').first.name, startsWith('ته'));
      expect(PlaceIndex.search(''), isEmpty);
    });

    test('findUnique refuses to guess between same-named places', () {
      // هرات is both an Iranian village (Fars) and Herat in Afghanistan; the
      // picker must show both rather than silently pick one.
      expect(PlaceIndex.findUnique('هرات'), isNull);
      expect(PlaceIndex.search('هرات').length, greaterThanOrEqualTo(2));
    });

    test('resolves a typed name with ZWNJ, tatweel and Latin case', () {
      expect(PlaceIndex.findUnique('تهران‌')?.country, 'ایران');
      expect(PlaceIndex.findUnique('  لندن ')?.country, 'انگلستان');
      expect(PlaceIndex.normalize('london'), PlaceIndex.normalize('LONDON'));
      expect(PlaceIndex.normalize('ل\u0640ندن'), PlaceIndex.normalize('لندن'));
    });

    test('folds Arabic/Persian letter, harakat and digit variants', () {
      // The two letters whose Arabic and Persian code points differ.
      expect(PlaceIndex.normalize('يوسف'), PlaceIndex.normalize('یوسف'));
      expect(PlaceIndex.normalize('كابل'), PlaceIndex.normalize('کابل'));
      // Harakat and superscript alif are stripped.
      expect(PlaceIndex.normalize('تِهْران'), PlaceIndex.normalize('تهران'));
      expect(PlaceIndex.normalize('مكّه'), PlaceIndex.normalize('مکه'));
      // Arabic-Indic and Extended/Persian digits fold onto Latin.
      expect(PlaceIndex.normalize('۱۲۳'), PlaceIndex.normalize('123'));
      expect(PlaceIndex.normalize('١٢٣'), PlaceIndex.normalize('123'));
      // …and a query in the other orthography still resolves the real place.
      expect(PlaceIndex.findUnique('مكّه')?.name, 'مکه');
    });

    test('nearest works outside Iran', () {
      final nigeria = PlaceIndex.nearest(6.60, 3.40, maxDistanceKm: 40);
      expect(nigeria?.place.name, 'لاگوس');
      expect(nigeria?.distanceKm, lessThan(20));

      final midOcean = PlaceIndex.nearest(0.0, -140.0, maxDistanceKm: 150);
      expect(midOcean, isNull, reason: 'nowhere near a bundled place');
    });

    test('distance is symmetric and monotonic', () {
      final a = PlaceIndex.distanceKm(35.6892, 51.3890, 21.4225, 39.8262);
      final b = PlaceIndex.distanceKm(21.4225, 39.8262, 35.6892, 51.3890);
      expect(a, closeTo(b, 0.001));
      // Tehran–Mecca is roughly 1,800 km; a wrong formula shows up fast.
      expect(a, inInclusiveRange(1600, 2000));
    });
  });
}
