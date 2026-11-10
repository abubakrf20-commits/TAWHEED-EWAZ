import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/prayer/domain/entities/qibla_direction.dart';

void main() {
  group('QiblaDirection', () {
    test('constructor sets all fields', () {
      const location = QiblaLocation(latitude: 21.4225, longitude: 39.8262);
      const direction = QiblaDirection(
        bearing: 156.5,
        distanceKm: 1234.5,
        location: location,
        locationSource: 'gps',
      );
      expect(direction.bearing, 156.5);
      expect(direction.distanceKm, 1234.5);
      expect(direction.location.latitude, 21.4225);
      expect(direction.location.longitude, 39.8262);
      expect(direction.locationSource, 'gps');
    });
  });
}
