import 'package:adhan/adhan.dart' as adhan;
import 'package:tawheeed/features/prayer/domain/entities/prayer_info.dart'
    as pi;
import 'package:tawheeed/features/prayer/domain/repositories/prayer_repository.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_helpers.dart'
    as ph;
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/domain/repositories/settings_writer.dart';

/// Cached prayer times (kept for backward compatibility with call sites).
class CachedPrayerTimes {
  final DateTime fajr;
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;

  const CachedPrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });
}

/// Thin, stateless facade over [PrayerRepository].
///
/// Kept so the 26 existing call sites (and the typed `PrayerTimeService`
/// parameter used by [DailyNotificationScheduler]) continue to compile while
/// the real logic lives in the repository. All state is read from the repo.
class PrayerTimeService {
  final PrayerRepository _repo;

  PrayerTimeService(this._repo);

  adhan.PrayerTimes? get prayerTimes => _repo.adhanTimes;
  adhan.SunnahTimes? get sunnahTimes => _repo.sunnahTimes;
  adhan.Coordinates? get coordinates => _repo.coordinates;
  adhan.CalculationParameters? get calculationParams => _repo.calculationParams;

  /// Parameters behind [_repo]'s displayed times — use for anything that
  /// recomputes (notifications, widget) so all surfaces agree.
  adhan.CalculationParameters? get effectiveParams => _repo.effectiveParams;

  /// Horizon-dip minutes the repository baked in: `[sunrise, maghrib]`.
  List<int> get elevationAdjustments => _repo.elevationAdjustments;

  CachedPrayerTimes? get cachedTimes {
    final pt = _repo.adhanTimes;
    if (pt == null) return null;
    return CachedPrayerTimes(
      fajr: pt.fajr,
      sunrise: pt.sunrise,
      dhuhr: pt.dhuhr,
      asr: pt.asr,
      maghrib: pt.maghrib,
      isha: pt.isha,
    );
  }

  String get error => _repo.error;
  bool get loading => _repo.loading;
  String get cityName => _repo.cityName;

  /// Prayer times for a specific local [date] (same location/params as today,
  /// including elevation correction). Null when no coordinates are resolved.
  pi.PrayerTimes? prayerTimesForDate(DateTime date, {AppSettings? settings}) =>
      _repo.prayerTimesForDate(date, settings: settings);

  /// Altitude above sea level in meters (null when unknown).
  double? get altitude => _repo.altitude;

  /// Persist a resolved altitude (used by the map picker).
  Future<void> setAltitude(double? altitude) => _repo.setAltitude(altitude);

  /// Listen for city name changes (e.g. after background geocoding resolves).
  void Function() listenCityName(void Function() cb) =>
      _repo.listenCityName(cb);

  DateTime? get fajr => _repo.adhanTimes?.fajr;
  DateTime? get sunrise => _repo.adhanTimes?.sunrise;
  DateTime? get dhuhr => _repo.adhanTimes?.dhuhr;
  DateTime? get asr => _repo.adhanTimes?.asr;
  DateTime? get maghrib => _repo.adhanTimes?.maghrib;
  DateTime? get isha => _repo.adhanTimes?.isha;

  String get currentPeriodLabel =>
      _repo.adhanTimes?.currentPeriodLabel ?? 'فجر';

  Future<void> loadPrayerTimes({
    AppSettings? settings,
    SettingsWriter? writer,
    bool forceRefresh = false,
  }) async {
    await _repo.loadPrayerTimes(
      settings: settings,
      writer: writer,
      forceRefresh: forceRefresh,
    );
  }

  Future<String?> forceRefreshLocation({
    AppSettings? settings,
    SettingsWriter? writer,
  }) =>
      _repo.forceRefreshLocation(settings: settings, writer: writer);

  Future<bool> isLocationServiceEnabled() => _repo.isLocationServiceEnabled();

  void invalidateCache() => _repo.invalidateCache();

  String formatTime(DateTime? time) => ph.formatTime(time);
  String formatTime12(DateTime? time) => ph.formatTime12(time);
  String formatTimeStr(int hour, int minute) => ph.formatTimeStr(hour, minute);
  String formatTimeStr12(int hour, int minute) =>
      ph.formatTimeStr12(hour, minute);

  DateTime? getNextPrayerTime() => _repo.adhanTimes?.getNextPrayerTime();
  String? get nextPrayerName => _repo.adhanTimes?.nextPrayerName;
  Duration? getTimeUntilNextPrayer() =>
      _repo.adhanTimes?.getTimeUntilNextPrayer();
  bool isPrayerPassed(String prayerName) =>
      _repo.adhanTimes?.isPrayerPassed(prayerName) ?? false;
  Map<String, String> get allTimes =>
      _repo.adhanTimes?.allTimes(_repo.sunnahTimes) ?? {};
}
