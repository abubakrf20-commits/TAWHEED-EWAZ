import 'package:geolocator/geolocator.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Shared GPS acquisition with the app-wide high→low accuracy fallback.
///
/// Tries [accuracy] (12s time limit) and, on any failure, retries once with
/// [fallbackAccuracy] (8s). Used by the qibla screen and prayer repository;
/// onboarding and the map picker keep their single-attempt flows because their
/// error UX differs (inline snack / form validation).
Future<Position> getCurrentPositionWithFallback({
  String logTag = 'LocationFlow',
  LocationAccuracy accuracy = LocationAccuracy.high,
  Duration timeLimit = const Duration(seconds: 12),
  LocationAccuracy fallbackAccuracy = LocationAccuracy.low,
  Duration fallbackTimeLimit = const Duration(seconds: 8),
}) async {
  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        timeLimit: timeLimit,
      ),
    );
  } catch (e) {
    AppLogger.warning(logTag, e.toString());
    return await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: fallbackAccuracy,
        timeLimit: fallbackTimeLimit,
      ),
    );
  }
}
