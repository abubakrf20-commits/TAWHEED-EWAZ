import 'package:adhan/adhan.dart' as adhan;
import 'package:tawheeed/features/prayer/domain/entities/prayer_info.dart'
    as pi;
import 'package:tawheeed/features/prayer/domain/repositories/prayer_repository.dart';
import 'package:tawheeed/features/prayer/services/prayer_time_service.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/domain/repositories/settings_writer.dart';

/// Minimal fake [PrayerRepository] returning fixed adhan times (or none).
///
/// Only [adhanTimes] (and the trivial getters) are implemented; every async
/// call is a no-op so providers like `prayerTimesProvider` resolve cleanly
/// without touching location or network.
class FakePrayerRepository implements PrayerRepository {
  FakePrayerRepository(this.times);
  final adhan.PrayerTimes? times;

  @override
  adhan.PrayerTimes? get adhanTimes => times;
  @override
  adhan.SunnahTimes? get sunnahTimes => null;
  @override
  adhan.Coordinates? get coordinates => null;
  @override
  adhan.CalculationParameters? get calculationParams => null;
  @override
  adhan.CalculationParameters? get effectiveParams => null;
  @override
  List<int> get elevationAdjustments => const [0, 0];
  @override
  String get error => '';
  @override
  bool get loading => false;
  @override
  String get cityName => '';
  @override
  double? get altitude => null;
  @override
  Future<void> setAltitude(double? altitude) async {}
  @override
  pi.PrayerTimes? get cachedPrayerTimes => null;
  @override
  void invalidateCache() {}
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<String?> forceRefreshLocation({
    required AppSettings? settings,
    SettingsWriter? writer,
  }) async =>
      null;
  @override
  Future<PrayerResult> loadPrayerTimes({
    required AppSettings? settings,
    SettingsWriter? writer,
    bool forceRefresh = false,
  }) async =>
      const PrayerResult();
  @override
  Future<pi.PrayerTimes?> loadCachedTimes({AppSettings? settings}) async =>
      null;
  @override
  void Function() listenCityName(void Function() cb) => () {};
  @override
  pi.PrayerTimes? prayerTimesForDate(DateTime date, {AppSettings? settings}) =>
      null;
}

/// Builds a [PrayerTimeService] wrapping [FakePrayerRepository].
PrayerTimeService fakePrayerService({adhan.PrayerTimes? times}) =>
    PrayerTimeService(FakePrayerRepository(times));

/// Computes adhan prayer times for [date] at Mecca with the Muslim World
/// League parameters (same source as the real repository's default).
adhan.PrayerTimes prayerTimesFor(DateTime date) {
  final coords = adhan.Coordinates(21.3891, 39.8579); // Mecca
  final params = adhan.CalculationMethod.muslim_world_league.getParameters();
  return adhan.PrayerTimes(
      coords, adhan.DateComponents(date.year, date.month, date.day), params);
}
