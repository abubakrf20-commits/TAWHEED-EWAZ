import 'package:adhan/adhan.dart' as adhan;
import 'package:tawheeed/features/prayer/domain/entities/prayer_info.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/domain/repositories/settings_writer.dart';

/// Result of loading prayer times.
class PrayerResult {
  final PrayerTimes? prayerTimes;
  final String? cityName;
  final String? error;

  const PrayerResult({
    this.prayerTimes,
    this.cityName,
    this.error,
  });
}

/// Abstract interface for prayer time data access.
abstract class PrayerRepository {
  /// Load prayer times for today based on settings and location.
  Future<PrayerResult> loadPrayerTimes({
    required AppSettings? settings,
    SettingsWriter? writer,
    bool forceRefresh = false,
  });

  /// Fast, network-free rehydration of today's times: recomputes from the
  /// saved coordinates when present, otherwise restores today's date-keyed
  /// cache. Never prompts for permission and never touches GPS, so the first
  /// frame can paint instead of waiting on the location pipeline.
  Future<PrayerTimes?> loadCachedTimes({AppSettings? settings});

  /// Force refresh location and recalculate prayer times.
  Future<String?> forceRefreshLocation({
    required AppSettings? settings,
    SettingsWriter? writer,
  });

  /// Check if location services are enabled.
  Future<bool> isLocationServiceEnabled();

  /// Invalidate cached prayer times (e.g., when settings change).
  void invalidateCache();

  /// Get cached (domain) prayer times if available.
  PrayerTimes? get cachedPrayerTimes;

  /// Compute prayer times for a specific local [date] using the last resolved
  /// location and calculation parameters (same pipeline as today's times,
  /// including elevation correction). Returns null when no coordinates are
  /// available.
  PrayerTimes? prayerTimesForDate(DateTime date, {AppSettings? settings});

  /// Get current city name.
  String get cityName;

  /// Altitude above sea level in meters of the last resolved location
  /// (`null` when unknown, e.g. still loading or offline).
  double? get altitude;

  /// Update the persisted altitude (e.g. after picking a point on the map).
  Future<void> setAltitude(double? altitude);

  /// Register a callback for location-info changes (city name / altitude).
  /// Returns a dispose function.
  void Function() listenCityName(void Function() cb);

  /// Raw adhan prayer times (for notifications / scheduler).
  adhan.PrayerTimes? get adhanTimes;

  /// Sunnah times (middle / last third of the night).
  adhan.SunnahTimes? get sunnahTimes;

  /// Resolved coordinates used for the last calculation.
  adhan.Coordinates? get coordinates;

  /// Calculation parameters used for the last calculation.
  adhan.CalculationParameters? get calculationParams;

  /// Parameters that produced [adhanTimes], horizon-dip correction included.
  /// Anything recomputing times for another day (notifications, the home
  /// widget) must use this, or its azan will ring at different clock times
  /// than the screen the user looked at.
  adhan.CalculationParameters? get effectiveParams;

  /// `[sunriseMinutes, maghribMinutes]` applied by the last elevation pass;
  /// `[0, 0]` when the correction is off or unavailable.
  List<int> get elevationAdjustments;

  /// Last error message (empty when no error).
  String get error;

  /// Whether a load is currently in progress.
  bool get loading;
}
