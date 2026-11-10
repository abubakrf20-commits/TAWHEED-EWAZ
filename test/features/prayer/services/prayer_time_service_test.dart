import 'package:adhan/adhan.dart' as adhan;
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/prayer/domain/entities/prayer_info.dart';
import 'package:tawheeed/features/prayer/domain/repositories/prayer_repository.dart';
import 'package:tawheeed/features/prayer/services/prayer_time_service.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/domain/repositories/settings_writer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  adhan.PrayerTimes buildTimes() {
    final coords = adhan.Coordinates(35.6892, 51.3890);
    final params = adhan.CalculationMethod.tehran.getParameters();
    return adhan.PrayerTimes(
        coords, adhan.DateComponents.from(DateTime(2026, 6)), params);
  }

  test('cachedTimes mirrors the repo prayer times', () {
    final times = buildTimes();
    final service = PrayerTimeService(_FakeRepo(adhanTimes: times));
    final cached = service.cachedTimes;
    expect(cached, isNotNull);
    expect(cached!.fajr, times.fajr);
    expect(cached.sunrise, times.sunrise);
    expect(cached.dhuhr, times.dhuhr);
    expect(cached.asr, times.asr);
    expect(cached.maghrib, times.maghrib);
    expect(cached.isha, times.isha);
  });

  test('cachedTimes is null when the repo has no times', () {
    final service = PrayerTimeService(_FakeRepo());
    expect(service.cachedTimes, isNull);
    expect(service.fajr, isNull);
    expect(service.maghrib, isNull);
  });

  test('single-prayer getters delegate to the repo', () {
    final times = buildTimes();
    final service = PrayerTimeService(_FakeRepo(adhanTimes: times));
    expect(service.fajr, times.fajr);
    expect(service.sunrise, times.sunrise);
    expect(service.dhuhr, times.dhuhr);
    expect(service.asr, times.asr);
    expect(service.maghrib, times.maghrib);
    expect(service.isha, times.isha);
  });

  test('currentPeriodLabel falls back to فجر without times', () {
    final service = PrayerTimeService(_FakeRepo());
    expect(service.currentPeriodLabel, 'فجر');
  });

  test('status getters delegate to the repo', () {
    final service = PrayerTimeService(_FakeRepo(
      error: 'boom',
      loading: true,
      cityName: 'تهران',
      altitude: 1200,
    ));
    expect(service.error, 'boom');
    expect(service.loading, isTrue);
    expect(service.cityName, 'تهران');
    expect(service.altitude, 1200);
  });

  test('formatTime delegates to the shared helper', () {
    final service = PrayerTimeService(_FakeRepo());
    expect(service.formatTime(DateTime(2026, 1, 1, 6, 5)), '06:05');
  });
}

class _FakeRepo implements PrayerRepository {
  _FakeRepo({
    this.adhanTimes,
    this.error = '',
    this.loading = false,
    this.cityName = '',
    this.altitude,
  });

  @override
  final adhan.PrayerTimes? adhanTimes;
  @override
  final String error;
  @override
  final bool loading;
  @override
  final String cityName;
  @override
  final double? altitude;

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
  PrayerTimes? get cachedPrayerTimes => null;

  @override
  Future<void> setAltitude(double? altitude) async {}
  @override
  void invalidateCache() {}
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  void Function() listenCityName(void Function() cb) => () {};
  @override
  Future<PrayerResult> loadPrayerTimes({
    required AppSettings? settings,
    SettingsWriter? writer,
    bool forceRefresh = false,
  }) async =>
      const PrayerResult();
  @override
  Future<PrayerTimes?> loadCachedTimes({AppSettings? settings}) async => null;
  @override
  Future<String?> forceRefreshLocation({
    required AppSettings? settings,
    SettingsWriter? writer,
  }) async =>
      null;
  @override
  PrayerTimes? prayerTimesForDate(DateTime date, {AppSettings? settings}) =>
      null;
}
