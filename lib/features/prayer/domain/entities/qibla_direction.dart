class QiblaLocation {
  final double latitude;
  final double longitude;

  const QiblaLocation({required this.latitude, required this.longitude});
}

class QiblaDirection {
  final double bearing;
  final double distanceKm;
  final QiblaLocation location;
  final String locationSource;

  const QiblaDirection({
    required this.bearing,
    required this.distanceKm,
    required this.location,
    required this.locationSource,
  });
}
