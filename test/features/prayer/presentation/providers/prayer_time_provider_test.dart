import 'dart:async';

import 'package:adhan/adhan.dart' as adhan;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/prayer/data/repositories/prayer_repository_impl.dart';
import 'package:tawheeed/features/prayer/domain/entities/prayer_info.dart'
    as pi;
import 'package:tawheeed/features/prayer/domain/repositories/prayer_repository.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_time_provider.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/domain/repositories/settings_writer.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/shared/models/day_time.dart';

class _MockSettings extends Settings {
  @override
  Future<AppSettings> build() async => const AppSettings();
}

/// One scripted answer of [loadPrayerTimes]: a result, optionally withheld
/// behind a gate so a test can pin the moment it lands.
class _Step {
  const _Step({this.times, this.error = '', this.gate});

  final pi.PrayerTimes? times;
  final String error;
  final Completer<void>? gate;
}

/// [PrayerRepository] whose cached read and refresh are scripted per call.
class _FakeRepo implements PrayerRepository {
  _FakeRepo({this.cached, List<_Step>? steps}) : _steps = steps ?? const [];

  pi.PrayerTimes? cached;
  final List<_Step> _steps;
  Completer<void>? cachedGate;
  Object? cachedError;

  int cachedCalls = 0;
  int loadCalls = 0;

  pi.PrayerTimes? _lastTimes;
  String _error = '';

  @override
  Future<pi.PrayerTimes?> loadCachedTimes({AppSettings? settings}) async {
    cachedCalls++;
    if (cachedGate != null) await cachedGate!.future;
    if (cachedError != null) throw cachedError!;
    _lastTimes = cached;
    return cached;
  }

  @override
  Future<PrayerResult> loadPrayerTimes({
    required AppSettings? settings,
    SettingsWriter? writer,
    bool forceRefresh = false,
  }) async {
    final step = loadCalls < _steps.length
        ? _steps[loadCalls]
        : const _Step();
    loadCalls++;
    if (step.gate != null) await step.gate!.future;
    _lastTimes = step.times;
    _error = step.error;
    return PrayerResult(
        prayerTimes: step.times, cityName: '', error: step.error);
  }

  @override
  String get error => _error;
  @override
  pi.PrayerTimes? get cachedPrayerTimes => _lastTimes;
  @override
  bool get loading => false;
  @override
  String get cityName => '';
  @override
  double? get altitude => null;
  @override
  List<int> get elevationAdjustments => const [0, 0];
  @override
  adhan.PrayerTimes? get adhanTimes => null;
  @override
  adhan.SunnahTimes? get sunnahTimes => null;
  @override
  adhan.Coordinates? get coordinates => null;
  @override
  adhan.CalculationParameters? get calculationParams => null;
  @override
  adhan.CalculationParameters? get effectiveParams => null;
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
  Future<void> setAltitude(double? altitude) async {}
  @override
  void Function() listenCityName(void Function() cb) => () {};
  @override
  pi.PrayerTimes? prayerTimesForDate(DateTime date, {AppSettings? settings}) =>
      null;
}

/// Prayer times with a distinguishable fajr minute per scenario.
pi.PrayerTimes _times(int fajrMinute) => pi.PrayerTimes(
      date: DateTime(2026, 10, 21),
      fajr: pi.PrayerInfo(
          name: 'fajr',
          arabicName: 'فجر',
          time: DayTime(hour: 4, minute: fajrMinute)),
      shorouq: const pi.PrayerInfo(
          name: 'shorouq',
          arabicName: 'طلوع',
          time: DayTime(hour: 6, minute: 0)),
      duhr: const pi.PrayerInfo(
          name: 'duhr', arabicName: 'ظهر', time: DayTime(hour: 12, minute: 0)),
      asr: const pi.PrayerInfo(
          name: 'asr', arabicName: 'عصر', time: DayTime(hour: 15, minute: 0)),
      maghrib: const pi.PrayerInfo(
          name: 'maghrib',
          arabicName: 'مغرب',
          time: DayTime(hour: 18, minute: 0)),
      isha: const pi.PrayerInfo(
          name: 'isha', arabicName: 'عشاء', time: DayTime(hour: 19, minute: 30)),
    );

Future<ProviderContainer> _container(_FakeRepo repo) async {
  final container = ProviderContainer(overrides: [
    prayerRepositoryProvider.overrideWithValue(repo),
    settingsProvider.overrideWith(_MockSettings.new),
  ]);
  addTearDown(container.dispose);
  // Settings resolve before the prayer notifier exists: the provider watches
  // the relevant-settings key, and its null → value flip legitimately rebuilds
  // the notifier. Letting it happen first keeps each scripted step single-use.
  await container.read(settingsProvider.future);
  // A listener keeps the async notifier observed across the background land.
  container.listen(prayerTimesProvider, (_, __) {});
  return container;
}

void main() {
  test('paints the saved times first, then publishes the fresh fix', () async {
    final cached = _times(30);
    final fresh = _times(45);
    final background = Completer<void>();
    final repo = _FakeRepo(cached: cached, steps: [
      _Step(times: fresh, gate: background),
    ]);
    final container = await _container(repo);

    // The first future resolves with the cached times while the location
    // pipeline is still running — this is the whole point of the fix.
    final first = await container.read(prayerTimesProvider.future);
    expect(first!.fajr.time.minute, 30);
    expect(repo.loadCalls, 1, reason: 'the background refresh has started');

    // Release the refresh; its publish must land in the provider state.
    background.complete();
    await pumpEventQueue();
    expect(container.read(prayerTimesProvider).value!.fajr.time.minute, 45);
  });

  test('a slow background refresh never overwrites a newer reload', () async {
    final background = Completer<void>();
    final repo = _FakeRepo(cached: _times(10), steps: [
      _Step(times: _times(20), gate: background),
      _Step(times: _times(55)),
    ]);
    final container = await _container(repo);
    await container.read(prayerTimesProvider.future);

    // A user reload lands first (call 2), then the older refresh completes.
    await container.read(prayerTimesProvider.notifier).reload();
    background.complete();
    await pumpEventQueue();

    expect(container.read(prayerTimesProvider).value!.fajr.time.minute, 55,
        reason: 'the stale generation must be discarded');
  });

  test('the repository error reaches the notice and a retry clears it',
      () async {
    const failure = 'خطا در دریافت موقعیت';
    final retryGate = Completer<void>();
    final repo = _FakeRepo(cached: _times(30), steps: [
      _Step(times: _times(30), error: failure),
      _Step(times: _times(30), gate: retryGate),
    ]);
    final container = await _container(repo);
    await container.read(prayerTimesProvider.future);
    await pumpEventQueue();

    expect(container.read(prayerLocationNoticeProvider).value, failure);

    // Starting a reload wipes the stale notice before the calculation runs…
    final pending = container.read(prayerTimesProvider.notifier).reload();
    expect(container.read(prayerLocationNoticeProvider).value, '');

    // …and a clean result keeps it empty.
    retryGate.complete();
    await pending;
    expect(container.read(prayerLocationNoticeProvider).value, '');
  });

  test('a failed cached read still lets the fresh calculation land', () async {
    final repo = _FakeRepo(cached: _times(30), steps: [
      _Step(times: _times(50)),
    ])
      ..cachedError = StateError('cache unreadable');
    final container = await _container(repo);

    // The throw is swallowed; build returns null rather than an AsyncError.
    await container.read(prayerTimesProvider.future);
    await pumpEventQueue();
    expect(container.read(prayerTimesProvider).value!.fajr.time.minute, 50);
  });
}
