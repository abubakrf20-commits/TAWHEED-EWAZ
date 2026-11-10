import 'package:flutter/services.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Local magnetic declination via Android's `GeomagneticField` (World Magnetic
/// Model), exposed through the project's own `com.tawheeed/magnetic_declination`
/// MethodChannel handled in `MainActivity.kt`.
///
/// This replaces the unmaintained `magnetic_declination` package with the same
/// native calculation, so the app no longer depends on a third-party plugin
/// that applies the legacy Kotlin Gradle Plugin.
class MagneticDeclinationService {
  MagneticDeclinationService._();
  static final _instance = MagneticDeclinationService._();
  factory MagneticDeclinationService() => _instance;

  static const _channel = MethodChannel('com.tawheeed/magnetic_declination');

  /// Magnetic declination in degrees (east positive) at the given location and
  /// time. Returns `null` when the native side is unavailable or fails, so the
  /// caller can distinguish "declination is genuinely ~0°" from "no value" —
  /// the latter must NOT be silently treated as 0° (up to ~20° error).
  Future<double?> calculateDeclination({
    required double latitude,
    required double longitude,
    double altitude = 0,
    required DateTime date,
  }) async {
    try {
      final timestamp = date.millisecondsSinceEpoch ~/ 1000; // seconds
      final result =
          await _channel.invokeMethod<double>('calculateDeclination', {
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
        'timestamp': timestamp,
      });
      return result;
    } on PlatformException catch (e) {
      AppLogger.warning(
          'MagneticDeclinationService', e.message ?? 'declination failed');
      return null;
    } on MissingPluginException {
      AppLogger.warning('MagneticDeclinationService', 'channel unavailable');
      return null;
    }
  }
}
