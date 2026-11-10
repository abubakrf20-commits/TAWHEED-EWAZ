import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/worship/data/daos/daily_status_dao.dart';
import 'package:tawheeed/features/worship/data/evaluation_data_loader.dart';
import 'package:tawheeed/features/worship/data/evaluation_reset_backup.dart';
import 'package:tawheeed/features/adhkar/data/daos/azkar_status_dao.dart';
import 'package:tawheeed/features/adhkar/tasbih/data/daos/tasbih_dao.dart';
import 'package:tawheeed/features/adhkar/tasbih/presentation/providers/tasbih_daily_reset.dart'
    show tasbihLastActiveDateKey;
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/worship/presentation/providers/evaluation_provider.dart';
import 'package:tawheeed/features/adhkar/tasbih/presentation/providers/tasbih_provider.dart';
import 'package:tawheeed/features/prayer/data/daos/prayer_tracker_dao.dart';
import 'package:tawheeed/features/prayer/data/daos/period_record_dao.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/shared/utils/date_key.dart';
import 'package:tawheeed/features/home/services/widget_sync.dart';
import 'package:tawheeed/features/home/services/widget_sync_provider.dart';
import '../../../../core/database/mock_daos.dart';

class _MockSettings extends Settings {
  @override
  Future<AppSettings> build() async => const AppSettings();

  @override
  Future<void> patch(AppSettings Function(AppSettings) updater) async {}
}

/// A DAO whose range delete fails, so the "nothing was cleared" path is
/// reachable.
class _FailingDeleteDao extends MockDailyStatusDao {
  @override
  Future<int> deleteCategoriesInDateRange(
      List<String> categories, String startDate, String endDate) async {
    throw StateError('database is locked');
  }
}

/// Records whether the widget mirror was told to clear. The real
/// [WidgetSync.clearEvaluationState] drops the home-screen widgets' native
/// mirror of today's tasbih total / per-zikr counts / prayer marks; if that
/// call ever regresses out of `Evaluation.resetRange`, the next widget→app
/// sync (10 s retry timer / app resume) re-imports the mirror and
/// resurrects a reset a few seconds later. This mock is the regression guard.
class _MockWidgetSync extends WidgetSync {
  bool cleared = false;
  int clearCallCount = 0;

  @override
  Future<void> clearEvaluationState() async {
    cleared = true;
    clearCallCount++;
  }
}

Future<ProviderContainer> _container({MockDailyStatusDao? dao}) async {
  final container = ProviderContainer(overrides: [
    azkarStatusDaoProvider.overrideWithValue(MockAzkarStatusDao()),
    tasbihDaoProvider.overrideWithValue(MockTasbihDao()),
    dailyStatusDaoProvider.overrideWithValue(dao ?? MockDailyStatusDao()),
    prayerTrackerDaoProvider.overrideWithValue(MockPrayerTrackerDao()),
    periodRecordDaoProvider.overrideWithValue(MockPeriodRecordDao()),
    settingsProvider.overrideWith(_MockSettings.new),
  ]);
  addTearDown(container.dispose);
  // The screen keeps the evaluation alive by watching it; a bare read lets
  // Riverpod dispose it between awaits and the reset tests read the state
  // more than once.
  container.listen(evaluationProvider, (_, __) {});
  await container.read(tasbihProvider.future);
  return container;
}

String _daysAgo(int days) =>
    dateKeyOf(DateTime.now().subtract(Duration(days: days)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Directory? _backupTemp;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Every resetRange writes its undo snapshot here; production resolves the
    // documents directory, tests resolve a fresh temp one.
    _backupTemp = await Directory.systemTemp.createTemp('eval_backup_test');
    final temp = _backupTemp!;
    backupDirectoryResolver = () async => temp;
  });

  tearDown(() async {
    backupDirectoryResolver = null;
    // Best-effort: Windows keeps the directory handle open briefly.
    try {
      await _backupTemp?.delete(recursive: true);
    } catch (_) {}
    _backupTemp = null;
  });

  group('resetRange — daily', () {
    test('clears today\'s records and keeps every other day\'s', () async {
      final dao = MockDailyStatusDao();
      final today = dateKeyOf(DateTime.now());
      await dao.set('worship', today, 'quran', 1);
      await dao.set('worship_score', today, '', 40);
      await dao.set(frozenScoreCategory, today, 'total', 40);
      await dao.set('tasbih_daily', today, '', 33);
      await dao.set('tasbih_daily_zikr1', today, '', 33);
      // Yesterday belongs to another range — it must survive a daily reset.
      await dao.set('worship', _daysAgo(1), 'quran', 1);
      await dao.set('worship_score', _daysAgo(1), '', 40);
      await dao.set(frozenScoreCategory, _daysAgo(1), 'total', 40);
      // Global rows a range reset has no business touching.
      await dao.set(frozenMetaCategory, '', 'frozen_schema', 1);
      await dao.set(evalResetCategory, _daysAgo(9), 'at', 1);

      final container = await _container(dao: dao);
      await container.read(evaluationProvider.future);

      final notifier = container.read(evaluationProvider.notifier);
      final now = DateTime.now();
      expect(await notifier.resetRange(now, now), isNotNull);

      expect(await dao.getAllForDate('worship', today), isEmpty);
      expect(await dao.getAllForDate('worship_score', today), isEmpty);
      expect(await dao.getAllForDate(frozenScoreCategory, today), isEmpty);
      expect(await dao.getValue('tasbih_daily', today, ''), isNull);
      expect(await dao.getValue('tasbih_daily_zikr1', today, ''), isNull);

      // Untouched: another day's history is not this reset's to erase.
      expect(await dao.getValue('worship_score', _daysAgo(1), ''), 40);
      expect(await dao.getValue(frozenMetaCategory, '', 'frozen_schema'), 1);
      expect(await dao.getAllForCategory(evalResetCategory), hasLength(1));
    });

    test('the score really falls to zero — prayers and azkar included',
        () async {
      // THE reported bug (2026-11-05): the old global reset deleted only the
      // evaluation's own rows, so today's score re-derived itself from the
      // surviving prayer/azkar/tasbih records and the reset read as dead.
      final dailyDao = MockDailyStatusDao();
      final ptDao = MockPrayerTrackerDao();
      final azkarDao = MockAzkarStatusDao();
      final today = dateKeyOf(DateTime.now());
      await dailyDao.set('worship_score', today, '', 25);
      await dailyDao.set('tasbih_daily', today, '', 33);
      for (final p in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
        await ptDao.upsert(PrayerTrackerTableData(
            date: today,
            prayerKey: p,
            value: prayerStatusDoneIndex));
      }
      await azkarDao.setStatus(ZikrStatusRecordTableData(
          id: 'z1', statusIndex: 1, date: today));

      final container = ProviderContainer(overrides: [
        azkarStatusDaoProvider.overrideWithValue(azkarDao),
        tasbihDaoProvider.overrideWithValue(MockTasbihDao()),
        dailyStatusDaoProvider.overrideWithValue(dailyDao),
        prayerTrackerDaoProvider.overrideWithValue(ptDao),
        periodRecordDaoProvider.overrideWithValue(MockPeriodRecordDao()),
        settingsProvider.overrideWith(_MockSettings.new),
      ]);
      addTearDown(container.dispose);
      container.listen(evaluationProvider, (_, __) {});
      await container.read(tasbihProvider.future);
      final before = await container.read(evaluationProvider.future);
      final notifier = container.read(evaluationProvider.notifier);
      expect(before.dailyScore, greaterThan(0));

      final now = DateTime.now();
      expect(await notifier.resetRange(now, now), isNotNull);

      // The rebuild after the reset reads the emptied tables: no source is
      // left to re-derive today's score from.
      final state = await container.read(evaluationProvider.future);
      expect(state.dailyScore, 0);
      expect(await ptDao.getAllForDate(today), isEmpty);
      expect(await azkarDao.getStatusesForDate(today), isEmpty);
    });

    test('writes an undo snapshot, and restoring it puts the day back',
        () async {
      final dao = MockDailyStatusDao();
      final today = dateKeyOf(DateTime.now());
      await dao.set('worship', today, 'quran', 1);
      await dao.set('worship_score', today, '', 40);
      final container = await _container(dao: dao);
      await container.read(evaluationProvider.future);

      final notifier = container.read(evaluationProvider.notifier);
      final now = DateTime.now();
      final path = await notifier.resetRange(now, now);
      expect(path, isNotNull);
      expect(await dao.getValue('worship_score', today, ''), isNull);

      expect(await notifier.restoreFromBackup(path!), isTrue);
      expect(await dao.getValue('worship', today, 'quran'), 1);
      expect(await dao.getValue('worship_score', today, ''), 40);
    });

    test('a failed reset offers no undo path', () async {
      final dao = _FailingDeleteDao();
      final container = await _container(dao: dao);
      await container.read(evaluationProvider.future);

      final notifier = container.read(evaluationProvider.notifier);
      final now = DateTime.now();
      // Null return — no snackbar may offer «بازگردانی» for a reset that
      // never happened.
      expect(await notifier.resetRange(now, now), isNull);
    });

    test('a day reset zeroes the tasbih session dials, keeps lifetime',
        () async {
      final tasbihDao = MockTasbihDao();
      await tasbihDao.upsertTasbih(TasbihTableData(
        id: 'zikr1',
        dhikrText: 'ذکر آزمایشی',
        count: 47,
        target: 100,
        totalLifetimeCount: 500,
        createdAt: DateTime.now(),
        isDefault: false,
        isEnabled: true,
      ));
      // Stamp the daily auto-reset as already run for today, or the tasbih
      // provider's own load zeroes the 47 taps before the reset under test
      // ever runs — and the test would pass for the wrong reason.
      SharedPreferences.setMockInitialValues({
        tasbihLastActiveDateKey: dateKeyOf(DateTime.now()),
      });

      final container = ProviderContainer(overrides: [
        azkarStatusDaoProvider.overrideWithValue(MockAzkarStatusDao()),
        tasbihDaoProvider.overrideWithValue(tasbihDao),
        dailyStatusDaoProvider.overrideWithValue(MockDailyStatusDao()),
        prayerTrackerDaoProvider.overrideWithValue(MockPrayerTrackerDao()),
        periodRecordDaoProvider.overrideWithValue(MockPeriodRecordDao()),
        settingsProvider.overrideWith(_MockSettings.new),
      ]);
      addTearDown(container.dispose);
      container.listen(evaluationProvider, (_, __) {});
      final items = await container.read(tasbihProvider.future);
      expect(items.single.currentCount, 47);

      final notifier = container.read(evaluationProvider.notifier);
      final now = DateTime.now();
      await notifier.resetRange(now, now);

      final after = await container.read(tasbihProvider.future);
      expect(after.single.currentCount, 0);
      // The lifetime total is the tasbih section's own record: unchanged.
      expect(after.single.totalLifetimeCount, 500);
    });

    test('keeps the lifetime tasbih total while clearing the daily rows',
        () async {
      // The lifetime count lives in the tasbih table, not daily_status — the
      // reset never reaches it.
      final dao = MockDailyStatusDao();
      final today = dateKeyOf(DateTime.now());
      await dao.set('tasbih_daily', today, '', 33);
      await dao.set('tasbih_daily_zikr1', today, '', 33);

      final container = await _container(dao: dao);
      final before = (await container.read(evaluationProvider.future))
          .totalLifetimeTasbih;

      final notifier = container.read(evaluationProvider.notifier);
      final now = DateTime.now();
      await notifier.resetRange(now, now);

      expect(await dao.getValue('tasbih_daily', today, ''), isNull);
      expect(await dao.getValue('tasbih_daily_zikr1', today, ''), isNull);
      // The lifetime total is the tasbih section's own record: unchanged.
      final after =
          (await container.read(evaluationProvider.future)).totalLifetimeTasbih;
      expect(after, before);
    });
  });

  group('resetRange — weekly and monthly', () {
    test('a weekly reset clears the trailing 7 days only', () async {
      final dao = MockDailyStatusDao();
      await dao.set('worship_score', _daysAgo(0), '', 10);
      await dao.set('worship_score', _daysAgo(6), '', 10);
      await dao.set('worship_score', _daysAgo(7), '', 10);
      await dao.set('worship_score', _daysAgo(30), '', 10);

      final container = await _container(dao: dao);
      await container.read(evaluationProvider.future);
      final notifier = container.read(evaluationProvider.notifier);

      final now = DateTime.now();
      expect(
          await notifier.resetRange(
              now.subtract(const Duration(days: 6)), now),
          isNotNull);

      expect(await dao.getValue('worship_score', _daysAgo(0), ''), isNull);
      expect(await dao.getValue('worship_score', _daysAgo(6), ''), isNull);
      // Outside the trailing window: untouched.
      expect(await dao.getValue('worship_score', _daysAgo(7), ''), 10);
      expect(await dao.getValue('worship_score', _daysAgo(30), ''), 10);
    });

    test('a monthly reset clears only the given month\'s range', () async {
      final dao = MockDailyStatusDao();
      final now = DateTime.now();
      final firstOfMonth = DateTime(now.year, now.month, 2);
      final lastOfMonth = DateTime(now.year, now.month + 1, 0);
      await dao.set('worship_score', dateKeyOf(firstOfMonth), '', 10);
      await dao.set('worship_score', dateKeyOf(lastOfMonth), '', 10);
      await dao.set(
          'worship_score',
          dateKeyOf(DateTime(now.year, now.month)
              .subtract(const Duration(days: 1))),
          '',
          10);

      final container = await _container(dao: dao);
      await container.read(evaluationProvider.future);
      final notifier = container.read(evaluationProvider.notifier);

      expect(
          await notifier.resetRange(firstOfMonth, lastOfMonth), isNotNull);

      expect(await dao.getValue('worship_score', dateKeyOf(firstOfMonth), ''),
          isNull);
      expect(await dao.getValue('worship_score', dateKeyOf(lastOfMonth), ''),
          isNull);
      // The last day of the previous month survives a this-month reset.
      expect(
          await dao.getValue(
              'worship_score',
              dateKeyOf(DateTime(now.year, now.month)
                  .subtract(const Duration(days: 1))),
              ''),
          10);
    });
  });

  group('resetRange — failure', () {
    test('a failed delete reports false and clears nothing', () async {
      final dao = _FailingDeleteDao();
      final today = dateKeyOf(DateTime.now());
      await dao.set('worship', today, 'quran', 1);
      await dao.set('worship_score', today, '', 40);

      final container = await _container(dao: dao);
      await container.read(evaluationProvider.future);

      final notifier = container.read(evaluationProvider.notifier);
      final now = DateTime.now();
      expect(await notifier.resetRange(now, now), isNull);

      // The rows are still there — a screen that looks reset while the data
      // survived is the outcome to avoid.
      expect(await dao.getAllForCategory('worship'), isNotEmpty);
      expect(await dao.getAllForCategory('worship_score'), isNotEmpty);
    });
  });

  group('resetImpactForRange', () {
    test('counts only the days inside the range', () async {
      final dao = MockDailyStatusDao();
      // Today is deliberately left out of the seeds: its score is always
      // recomputed live from the current records, so a seeded `worship_score`
      // row for it would be overwritten by the build either way.
      await dao.set('worship_score', _daysAgo(1), '', 20);
      await dao.set('worship_score', _daysAgo(2), '', 30);
      // Outside the week: must not be quoted as at risk by a weekly reset.
      await dao.set('worship_score', _daysAgo(9), '', 99);
      // A zero-score row is a day the reader touched and scored nothing on;
      // it must not be counted as history the reset destroys.
      await dao.set('worship_score', _daysAgo(4), '', 0);

      final container = await _container(dao: dao);
      await container.read(evaluationProvider.future);

      final now = DateTime.now();
      final impact = container
          .read(evaluationProvider.notifier)
          .resetImpactForRange(now.subtract(const Duration(days: 6)), now);
      expect(impact.days, 2);
      expect(impact.points, 50);
    });

    test('measures the best streak inside the range only', () async {
      final dao = MockDailyStatusDao();
      // A 2-day streak inside the range, a longer one outside it.
      await dao.set('worship_score', _daysAgo(1), '', 10);
      await dao.set('worship_score', _daysAgo(2), '', 10);
      await dao.set('worship_score', _daysAgo(4), '', 10);
      await dao.set('worship_score', _daysAgo(5), '', 10);
      await dao.set('worship_score', _daysAgo(6), '', 10);

      final container = await _container(dao: dao);
      await container.read(evaluationProvider.future);

      final now = DateTime.now();
      final impact = container
          .read(evaluationProvider.notifier)
          .resetImpactForRange(now.subtract(const Duration(days: 2)), now);
      expect(impact.bestStreak, 2);
    });

    test('is all zeroes on a fresh install', () async {
      final container = await _container();
      await container.read(evaluationProvider.future);

      final now = DateTime.now();
      final impact = container
          .read(evaluationProvider.notifier)
          .resetImpactForRange(now.subtract(const Duration(days: 6)), now);
      expect(impact.days, 0);
      expect(impact.points, 0);
      expect(impact.bestStreak, 0);
    });
  });

  group('resetRange — widget mirror (resurrection guard)', () {
    Future<ProviderContainer> _containerWithWidgetMock(
        _MockWidgetSync mock) async {
      final container = ProviderContainer(overrides: [
        azkarStatusDaoProvider.overrideWithValue(MockAzkarStatusDao()),
        tasbihDaoProvider.overrideWithValue(MockTasbihDao()),
        dailyStatusDaoProvider.overrideWithValue(MockDailyStatusDao()),
        prayerTrackerDaoProvider.overrideWithValue(MockPrayerTrackerDao()),
        periodRecordDaoProvider.overrideWithValue(MockPeriodRecordDao()),
        settingsProvider.overrideWith(_MockSettings.new),
        widgetSyncProvider.overrideWithValue(mock),
      ]);
      addTearDown(container.dispose);
      container.listen(evaluationProvider, (_, __) {});
      await container.read(tasbihProvider.future);
      return container;
    }

    test('resets covering today → clears the home-screen widget mirror',
        () async {
      // THE resurrection guard (2026-11-06): the daily-reset fix clears the
      // widgets' native mirror of today's tasbih total / per-zikr counts /
      // prayer «خواندم» marks. If this call is removed, the 10 s widget→app
      // sync re-imports the mirror and the reset comes back a few seconds
      // later.
      final mock = _MockWidgetSync();
      final container = await _containerWithWidgetMock(mock);
      await container.read(evaluationProvider.future);
      final notifier = container.read(evaluationProvider.notifier);
      final now = DateTime.now();
      await notifier.resetRange(now, now);
      // The mirror clear is fire-and-forget inside resetRange; flush the
      // microtask queue so the mock's body has run before we assert.
      await Future<void>.delayed(Duration.zero);
      expect(mock.cleared, isTrue);
      expect(mock.clearCallCount, 1);
    });

    test('range excluding today → leaves the widget mirror untouched',
        () async {
      // Yesterday-only reset must NOT clear today's widget mirror — the
      // mirror only reflects today, and clearing it for an unrelated past-day
      // reset would wipe today's live widget state for no reason.
      final mock = _MockWidgetSync();
      final container = await _containerWithWidgetMock(mock);
      await container.read(evaluationProvider.future);
      final notifier = container.read(evaluationProvider.notifier);
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await notifier.resetRange(yesterday, yesterday);
      await Future<void>.delayed(Duration.zero);
      expect(mock.cleared, isFalse);
    });
  });
}

/// `PrayerStatus.done` sits at index 1 in
/// `lib/features/prayer/domain/entities/prayer_tracker_entities.dart`.
const int prayerStatusDoneIndex = 1;
