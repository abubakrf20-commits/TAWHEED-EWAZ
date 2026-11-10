import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/prayer/data/daos/prayer_tracker_dao.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_tracker_provider.dart';
import 'package:tawheeed/shared/utils/date_key.dart';
import '../../../../core/database/mock_daos.dart';

/// Holds the initial snapshot until the gate opens, so taps made in the same
/// turn as the first read land while the load is still in flight.
class _GatedPrayerTrackerDao extends MockPrayerTrackerDao {
  Completer<void>? gate;

  @override
  Future<Map<String, int>> getAllAsMap() async {
    final snapshot = await super.getAllAsMap();
    final g = gate;
    if (g != null) await g.future;
    return snapshot;
  }
}

void main() {
  late ProviderContainer container;
  late MockPrayerTrackerDao mockDao;

  setUp(() {
    mockDao = MockPrayerTrackerDao();
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(overrides: [
      prayerTrackerDaoProvider.overrideWithValue(mockDao),
    ]);
  });

  tearDown(() {
    container.dispose();
  });

  test('build returns default state', () async {
    final state = await container.read(prayerTrackerProvider.future);
    expect(state.version, equals(0));
  });

  test('getStatus returns pending by default', () async {
    await container.read(prayerTrackerProvider.future);
    final notifier = container.read(prayerTrackerProvider.notifier);
    expect(notifier.getStatus(FardhPrayer.fajr), equals(PrayerStatus.pending));
    expect(notifier.getStatus(FardhPrayer.dhuhr), equals(PrayerStatus.pending));
    expect(notifier.getStatus(FardhPrayer.isha), equals(PrayerStatus.pending));
  });

  test('setStatus updates prayer status', () async {
    await container.read(prayerTrackerProvider.future);
    final notifier = container.read(prayerTrackerProvider.notifier);
    notifier.setStatus(FardhPrayer.fajr, PrayerStatus.done);
    expect(notifier.getStatus(FardhPrayer.fajr), equals(PrayerStatus.done));
  });

  test(
      'toggleStatus cycles through statuses: pending -> done -> qada -> pending',
      () async {
    await container.read(prayerTrackerProvider.future);
    final notifier = container.read(prayerTrackerProvider.notifier);
    expect(notifier.getStatus(FardhPrayer.asr), equals(PrayerStatus.pending));
    notifier.toggleStatus(FardhPrayer.asr);
    expect(notifier.getStatus(FardhPrayer.asr), equals(PrayerStatus.done));
    notifier.toggleStatus(FardhPrayer.asr);
    expect(notifier.getStatus(FardhPrayer.asr), equals(PrayerStatus.qada));
    notifier.toggleStatus(FardhPrayer.asr);
    expect(notifier.getStatus(FardhPrayer.asr), equals(PrayerStatus.pending));
  });

  test('toggleStatus from reserved missed resets to pending', () async {
    await container.read(prayerTrackerProvider.future);
    final notifier = container.read(prayerTrackerProvider.notifier);
    // missed is never assigned by any writer (DB-index compatibility only);
    // toggling out of it restarts the cycle instead of inventing a state.
    notifier.setStatus(FardhPrayer.fajr, PrayerStatus.missed);
    notifier.toggleStatus(FardhPrayer.fajr);
    expect(notifier.getStatus(FardhPrayer.fajr), equals(PrayerStatus.pending));
  });

  test('toggleSunnah toggles sunnah status in state', () async {
    await container.read(prayerTrackerProvider.future);
    final notifier = container.read(prayerTrackerProvider.notifier);
    notifier.toggleSunnah(SunnahPrayer.fajrRawatib);
    var state = container.read(prayerTrackerProvider).requireValue;
    expect(state.sunnahStatuses[SunnahPrayer.fajrRawatib], isTrue);
    notifier.toggleSunnah(SunnahPrayer.fajrRawatib);
    state = container.read(prayerTrackerProvider).requireValue;
    expect(state.sunnahStatuses[SunnahPrayer.fajrRawatib], isFalse);
  });

  test('toggleDuha toggles duha status in state', () async {
    await container.read(prayerTrackerProvider.future);
    final notifier = container.read(prayerTrackerProvider.notifier);
    notifier.toggleDuha();
    var state = container.read(prayerTrackerProvider).requireValue;
    expect(state.duhaStatus, isTrue);
    notifier.toggleDuha();
    state = container.read(prayerTrackerProvider).requireValue;
    expect(state.duhaStatus, isFalse);
  });

  test('taps made while the initial load is in flight survive it', () async {
    // The widget stays tappable while build() awaits the DB. A tap used to be
    // wiped by the older snapshot the load then assigned; it must be replayed
    // over it instead.
    final dao = _GatedPrayerTrackerDao()..gate = Completer<void>();
    final gatedContainer = ProviderContainer(overrides: [
      prayerTrackerDaoProvider.overrideWithValue(dao),
    ]);
    addTearDown(gatedContainer.dispose);
    gatedContainer.listen(prayerTrackerProvider, (_, __) {});
    final notifier = gatedContainer.read(prayerTrackerProvider.notifier);
    notifier.setStatus(FardhPrayer.fajr, PrayerStatus.done);
    notifier.toggleSunnah(SunnahPrayer.fajrRawatib);
    notifier.toggleDuha();
    dao.gate!.complete();
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(notifier.getStatus(FardhPrayer.fajr), PrayerStatus.done);
    final state = gatedContainer.read(prayerTrackerProvider).requireValue;
    expect(state.sunnahStatuses[SunnahPrayer.fajrRawatib], isTrue);
    expect(state.duhaStatus, isTrue);
    final today = dateKeyOf(DateTime.now());
    expect(notifier.cachedPrayerData['pt_${today}_fajr'],
        PrayerStatus.done.index);
    expect(notifier.cachedPrayerData['pt_${today}_sunnah_fajrRawatib'], 1);
    expect(notifier.cachedPrayerData['pt_${today}_duha'], 1);
    expect(await dao.getForDateAndKey(today, 'fajr'), isNotNull);
  });

  test('countPrayersInRange counts done/qada prayers per day', () async {
    await container.read(prayerTrackerProvider.future);
    final notifier = container.read(prayerTrackerProvider.notifier);
    notifier.setStatus(FardhPrayer.fajr, PrayerStatus.done);
    notifier.setStatus(FardhPrayer.dhuhr, PrayerStatus.qada);
    notifier.toggleSunnah(SunnahPrayer.witr);
    notifier.toggleDuha();
    final today = DateTime.now();
    final key = '${today.year}-${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    final counts = notifier.countPrayersInRange(key, key);
    expect(counts.fardh, equals(2));
    expect(counts.sunnah, equals(1));
    expect(counts.duha, equals(1));
  });

  test('computeStreaks returns 0 when no prayers done', () async {
    await container.read(prayerTrackerProvider.future);
    final notifier = container.read(prayerTrackerProvider.notifier);
    final streaks = notifier.computeStreaks();
    expect(streaks.current, equals(0));
    expect(streaks.longest, equals(0));
  });

  test('computeStreaks counts consecutive fully-prayed days', () async {
    await container.read(prayerTrackerProvider.future);
    // Mark all 5 fardh prayers done for today and yesterday.
    for (final daysAgo in [0, 1]) {
      final date = DateTime.now().subtract(Duration(days: daysAgo));
      final dk = '${date.year}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      for (final p in FardhPrayer.values) {
        mockDao.upsert(PrayerTrackerTableData(
          date: dk,
          prayerKey: p.name,
          value: PrayerStatus.done.index,
        ));
      }
    }
    // Reload so the in-memory cache sees the seeded rows.
    container.invalidate(prayerTrackerProvider);
    await container.read(prayerTrackerProvider.future);
    final streaks =
        container.read(prayerTrackerProvider.notifier).computeStreaks();
    expect(streaks.current, greaterThanOrEqualTo(2));
    expect(streaks.longest, greaterThanOrEqualTo(2));
  });

  test('computeStreaks ignores qada-only days', () async {
    await container.read(prayerTrackerProvider.future);
    // Today: all done. Yesterday: all qada (made up, not on time).
    final now = DateTime.now();
    String dk(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    for (final p in FardhPrayer.values) {
      mockDao.upsert(PrayerTrackerTableData(
        date: dk(now),
        prayerKey: p.name,
        value: PrayerStatus.done.index,
      ));
      mockDao.upsert(PrayerTrackerTableData(
        date: dk(now.subtract(const Duration(days: 1))),
        prayerKey: p.name,
        value: PrayerStatus.qada.index,
      ));
    }
    container.invalidate(prayerTrackerProvider);
    await container.read(prayerTrackerProvider.future);
    final streaks =
        container.read(prayerTrackerProvider.notifier).computeStreaks();
    // Only today counts — yesterday's qada must not extend the streak.
    expect(streaks.current, equals(1));
  });
}
