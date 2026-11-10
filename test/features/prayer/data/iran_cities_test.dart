import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/prayer/data/iran_cities.dart';

/// Same Haversine distance used by the resolver (km).
double _distance(double lat1, double lng1, double lat2, double lng2) {
  const earthRadius = 6371.0;
  double degToRad(double deg) => deg * pi / 180.0;
  final dLat = degToRad(lat2 - lat1);
  final dLng = degToRad(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(degToRad(lat1)) * cos(degToRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a));
}

IranCity? _nearestCity(double lat, double lng) {
  IranCity? nearest;
  var min = double.infinity;
  for (final province in iranProvinces) {
    for (final city in province.cities) {
      final d = _distance(lat, lng, city.lat, city.lng);
      if (d < min) {
        min = d;
        nearest = city;
      }
    }
  }
  return nearest;
}

void main() {
  group('iran_cities coverage', () {
    test('list is substantially larger than the original curated list', () {
      final total =
          iranProvinces.fold<int>(0, (sum, p) => sum + p.cities.length);
      expect(total, greaterThan(800),
          reason: 'the offline list should now include small towns');
    });

    test('every province is present', () {
      expect(iranProvinces.length, 31);
    });

    test('no duplicate city names within the same province', () {
      for (final province in iranProvinces) {
        final names = province.cities.map((c) => c.name).toList();
        expect(names.toSet().length, names.length,
            reason: 'duplicate city in ${province.name}: $names');
      }
    });

    String strip(String s) => s.replaceAll(' ', '').replaceAll('\u200c', '');

    test('small towns resolve to their own names within 15 km', () {
      // (city, latitude, longitude) — real coordinates of smaller towns that
      // were missing or wrongly resolved before the list was expanded.
      const targets = [
        ('نقده', 36.9557, 45.3878),
        ('کامیاران', 34.7946, 46.9353),
        ('مینودشت', 37.1500, 55.3667),
        ('رودبار', 36.8167, 49.4167),
        ('املش', 37.0833, 50.1833),
        ('شیرگاه', 36.3017, 52.8814),
        ('دماوند', 35.7183, 52.0650),
        ('ملارد', 35.6657, 50.9792),
        ('اسدآباد', 34.7833, 48.1167),
        ('گلوگاه', 36.7167, 53.8167),
        ('بستان آباد', 37.8500, 46.8333),
        ('اشنویه', 37.0333, 45.0833),
        ('لالی', 32.3333, 49.0833),
        ('کنگان', 27.8370, 52.0620),
        ('چابهار', 25.2919, 60.6431),
      ];
      for (final (name, lat, lng) in targets) {
        final nearest = _nearestCity(lat, lng);
        expect(nearest, isNotNull, reason: 'no city found near $name');
        expect(_distance(lat, lng, nearest!.lat, nearest.lng), lessThan(15.0),
            reason: 'nearest to $name was ${nearest.name} '
                '(${_distance(lat, lng, nearest.lat, nearest.lng).toStringAsFixed(1)} km)');
        expect(strip(nearest.name), contains(strip(name)),
            reason: 'nearest to $name resolved as ${nearest.name}');
      }
    });

    test('all coordinates are valid ranges', () {
      for (final province in iranProvinces) {
        for (final city in province.cities) {
          expect(city.lat, inInclusiveRange(-90, 90),
              reason: '${city.name} lat out of range');
          expect(city.lng, inInclusiveRange(-180, 180),
              reason: '${city.name} lng out of range');
        }
      }
    });
  });
}
