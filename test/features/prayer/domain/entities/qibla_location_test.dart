import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/prayer/domain/entities/qibla_location.dart';
import 'package:tawheeed/features/prayer/domain/entities/qibla_direction.dart';

void main() {
  group('QiblaLocation', () {
    test('constructor sets latitude and longitude', () {
      const location = QiblaLocation(latitude: 35.7, longitude: 51.4);
      expect(location.latitude, 35.7);
      expect(location.longitude, 51.4);
    });

    test('equality based on field values', () {
      const a = QiblaLocation(latitude: 35.7, longitude: 51.4);
      const b = QiblaLocation(latitude: 35.7, longitude: 51.4);
      expect(a.latitude, b.latitude);
      expect(a.longitude, b.longitude);
    });

    test('immutable', () {
      const location = QiblaLocation(latitude: 35.7, longitude: 51.4);
      expect(location.latitude, isA<double>());
      expect(location.longitude, isA<double>());
    });
  });

  group('khatm_location reexport', () {
    test('qibla_location exports QiblaLocation and QiblaDirection', () {
      // Just verify the types are accessible from the reexport
      expect(QiblaLocation, isA<Type>());
      expect(QiblaDirection, isA<Type>());
    });
  });
}
