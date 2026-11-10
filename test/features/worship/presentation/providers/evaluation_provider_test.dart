import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/worship/data/daos/daily_status_dao.dart';
import 'package:tawheeed/features/adhkar/data/daos/azkar_status_dao.dart';
import 'package:tawheeed/features/adhkar/data/azkar_data.dart';
import 'package:tawheeed/features/adhkar/domain/entities/zikr_item.dart';
import 'package:tawheeed/features/adhkar/tasbih/data/daos/tasbih_dao.dart';
import 'package:tawheeed/features/worship/presentation/providers/evaluation_provider.dart';
import 'package:tawheeed/features/adhkar/tasbih/presentation/providers/tasbih_provider.dart';
import 'package:tawheeed/features/prayer/data/daos/prayer_tracker_dao.dart';
import 'package:tawheeed/features/prayer/data/daos/period_record_dao.dart';
import 'package:tawheeed/features/prayer/domain/entities/prayer_tracker_entities.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/shared/utils/date_key.dart';
import '../../../../core/database/mock_daos.dart';

class _MockSettings extends Settings {
  AppSettings settings;
  _MockSettings({this.settings = const AppSettings()});

  @override
  Future<AppSettings> build() async => settings;

  @override
  Future<void> patch(AppSettings Function(AppSettings) updater) async {
    settings = updater(settings);
  }
}

/// Create a container and resolve all async dependencies so disposal won't
/// trigger pending-future errors.
Future<ProviderContainer> _createResolvedContainer({
  MockAzkarStatusDao? statusDao,
  MockTasbihDao? tasbihDao,
  MockDailyStatusDao? dailyStatusDao,
  MockPrayerTrackerDao? prayerTrackerDao,
  MockPeriodRecordDao? periodDao,
  AppSettings customSettings = const AppSettings(),
}) async {
  final container = ProviderContainer(overrides: [
    azkarStatusDaoProvider.overrideWithValue(statusDao ?? MockAzkarStatusDao()),
    tasbihDaoProvider.overrideWithValue(tasbihDao ?? MockTasbihDao()),
    dailyStatusDaoProvider
        .overrideWithValue(dailyStatusDao ?? MockDailyStatusDao()),
    // evaluationProvider reads the prayer tracker for prayer points; use the
    // in-memory mock instead of the real Drift DB.
    prayerTrackerDaoProvider
        .overrideWithValue(prayerTrackerDao ?? MockPrayerTrackerDao()),
    // evaluationProvider also reads period (hayz) records for period-day
    // recognition; default mock has no records.
    periodRecordDaoProvider
        .overrideWithValue(periodDao ?? MockPeriodRecordDao()),
    // evaluationProvider reads the settings provider for user-configurable
    // worship points; default AppSettings keeps the existing point scheme.
    settingsProvider
        .overrideWith(() => _MockSettings(settings: customSettings)),
  ]);
  // Pre-resolve dependency futures to avoid _Completer.completeError on dispose
  await container.read(tasbihProvider.future);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EvaluationProvider', () {
    test('build returns the default EvaluationState', () async {
      SharedPreferences.setMockInitialValues({});
      final container = await _createResolvedContainer();
      addTearDown(container.dispose);
      final state = await container.read(evaluationProvider.future);
      expect(state.worshipItems, isNotEmpty);
      expect(state.dailyScore, equals(0));
      expect(state.monthlyScore, equals(0));
      expect(state.weeklyScore, equals(0));
      expect(state.currentStreak, equals(0));
    });

    test('build loads default worship items', () async {
      SharedPreferences.setMockInitialValues({});
      final container = await _createResolvedContainer();
      addTearDown(container.dispose);
      final state = await container.read(evaluationProvider.future);
      expect(state.worshipItems.length, greaterThan(0));
      expect(state.worshipItems.any((w) => w.id == 'quran'), isTrue);
      expect(state.worshipItems.any((w) => w.id == 'sadaqa'), isTrue);
      expect(state.worshipItems.any((w) => w.id == 'tahajjud'), isTrue);
      // The four step-by-step checklists (نماز / وضو / غسل / تیمم) register
      // these ids through StepChecklistCard. They were absent, so every
      // completed checklist was a silent no-op; they are real items now.
      expect(state.worshipItems.any((w) => w.id == 'wudu'), isTrue);
      expect(state.worshipItems.any((w) => w.id == 'ghusl'), isTrue);
      expect(state.worshipItems.any((w) => w.id == 'tayammum'), isTrue);
      expect(state.worshipItems.any((w) => w.id == 'prayer'), isTrue);
    });

    test('toggleWorship toggles worship item and updates score', () async {
      SharedPreferences.setMockInitialValues({});
      final container = await _createResolvedContainer();
      addTearDown(container.dispose);
      await container.read(evaluationProvider.future);
      final notifier = container.read(evaluationProvider.notifier);
      notifier.toggleWorship('quran');
      final state = container.read(evaluationProvider).requireValue;
      final quran = state.worshipItems.firstWhere((w) => w.id == 'quran');
      expect(quran.done, isTrue);
      expect(state.dailyScore, greaterThan(0));
    });

    test('a completed checklist registers its worship item', () async {
      SharedPreferences.setMockInitialValues({});
      final daily = MockDailyStatusDao();
      final container = await _createResolvedContainer(dailyStatusDao: daily);
      addTearDown(container.dispose);
      await container.read(evaluationProvider.future);
      final notifier = container.read(evaluationProvider.notifier);

      // StepChecklistCard calls exactly this when all steps are checked.
      notifier.toggleWorship('wudu');
      final state = container.read(evaluationProvider).requireValue;
      expect(state.worshipItems.firstWhere((w) => w.id == 'wudu').done, isTrue,
          reason: 'the wudu checklist sync must land on a real item');
      expect(state.dailyScore, greaterThan(0));
      expect(
          await daily.getValue('worship', dateKeyOf(DateTime.now()), 'wudu'), 1,
          reason: 'the registration must persist, not only repaint');
    });

    test('performanceRating returns correct rating based on monthly score',
        () async {
      SharedPreferences.setMockInitialValues({});
      final container = await _createResolvedContainer();
      addTearDown(container.dispose);
      await container.read(evaluationProvider.future);
      final notifier = container.read(evaluationProvider.notifier);
      expect(notifier.performanceRating, equals('نیاز به تلاش بیشتر'));
    });

    test('addCustomWorshipItem adds a new custom worship item', () async {
      SharedPreferences.setMockInitialValues({});
      final container = await _createResolvedContainer();
      addTearDown(container.dispose);
      await container.read(evaluationProvider.future);
      final notifier = container.read(evaluationProvider.notifier);
      notifier.addCustomWorshipItem('My Custom', Icons.star, 30);
      final state = container.read(evaluationProvider).requireValue;
      expect(state.worshipItems.any((w) => w.id.startsWith('custom_')), isTrue);
    });

    test('custom worship items survive provider recreation from settings',
        () async {
      SharedPreferences.setMockInitialValues({});
      const trickyLabel = 'قرائت قرآن، تلاوت: ویژه';
      const settings = AppSettings(
        customWorshipItems: [
          {
            'id': 'custom_x',
            'label': trickyLabel,
            'iconName': 'star',
            'points': 30
          },
        ],
      );
      final container =
          await _createResolvedContainer(customSettings: settings);
      addTearDown(container.dispose);
      final state = await container.read(evaluationProvider.future);
      final custom =
          state.worshipItems.firstWhere((w) => w.id.startsWith('custom_'));
      expect(custom.label, equals(trickyLabel));
      // Points are capped at the per-item max of 5.
      expect(custom.points, equals(5));
    });

    test('weeklyScore excludes future dates', () async {
      SharedPreferences.setMockInitialValues({});
      final daily = MockDailyStatusDao();
      final now = DateTime.now();
      final future = now.add(const Duration(days: 1));
      final futureKey =
          '${future.year}-${future.month.toString().padLeft(2, '0')}-${future.day.toString().padLeft(2, '0')}';
      await daily.set('worship_score', futureKey, '', 100);
      final container = await _createResolvedContainer(dailyStatusDao: daily);
      addTearDown(container.dispose);
      final state = await container.read(evaluationProvider.future);
      expect(state.weeklyScore, equals(0));
    });

    test('weeklyScore and weeklyPoints include the trailing 7 days', () async {
      SharedPreferences.setMockInitialValues({});
      final daily = MockDailyStatusDao();
      final now = DateTime.now();
      String keyOf(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      await daily.set('worship_score',
          keyOf(now.subtract(const Duration(days: 1))), '', 60);
      await daily.set('worship_score',
          keyOf(now.subtract(const Duration(days: 3))), '', 40);
      final container = await _createResolvedContainer(dailyStatusDao: daily);
      addTearDown(container.dispose);
      await container.read(evaluationProvider.future);
      final notifier = container.read(evaluationProvider.notifier);
      expect(notifier.weeklyPoints(), equals(100));
      // Default items only, each worth the 5-point per-item max: nine items
      // (quran, sadaqa, tahajjud, fasting, good_deeds + the four checklists
      // prayer / wudu / ghusl / tayammum), so 9×5 = 45.
      // dailyMaxScore also includes prayer points (85) + adhkar (20) + tasbih (10).
      expect(notifier.dailyMaxScore, equals(85 + 45 + 30));
    });

    test('custom worship points from settings drive the daily max', () async {
      SharedPreferences.setMockInitialValues({});
      // Custom scheme: fardh=20, sunnah=8, duha=10, worship multiplier=2x.
      final container = await _createResolvedContainer(
        customSettings: const AppSettings(
            fardhPoint: 20,
            sunnahPoint: 8,
            duhaPoint: 10,
            worshipMultiplier: 2),
      );
      addTearDown(container.dispose);
      await container.read(evaluationProvider.future);
      final notifier = container.read(evaluationProvider.notifier);
      // Prayer max: 5 fardh×20 + 6 sunnah×8 + duha 10 = 100 + 48 + 10 = 158.
      // Worship max: the 9 defaults are each capped at 5, so 9×5 = 45 — the
      // ×2 multiplier cannot push a single item past the 5-point cap.
      // + adhkar 20 + tasbih 10 = 30.
      expect(notifier.dailyMaxScore, equals(158 + 45 + 30));
      // Worship items themselves carry the capped points.
      final items = container.read(evaluationProvider).value!.worshipItems;
      expect(items.firstWhere((w) => w.id == 'quran').points, equals(5));
    });

    test('totalSkipped counts skipped azkar records', () async {
      SharedPreferences.setMockInitialValues({});
      final statusDao = MockAzkarStatusDao();
      final todayKey =
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
      await statusDao.setStatus(
          ZikrStatusRecordTableData(id: 'a', statusIndex: 2, date: todayKey));
      await statusDao.setStatus(
          ZikrStatusRecordTableData(id: 'b', statusIndex: 2, date: todayKey));
      await statusDao.setStatus(
          ZikrStatusRecordTableData(id: 'c', statusIndex: 1, date: todayKey));
      final container = await _createResolvedContainer(statusDao: statusDao);
      addTearDown(container.dispose);
      final state = await container.read(evaluationProvider.future);
      expect(state.totalSkipped, equals(2));
      expect(state.totalCompleted, equals(1));
    });

    test('dailyAverage is based on the current month only', () async {
      SharedPreferences.setMockInitialValues({});
      final daily = MockDailyStatusDao();
      final old = DateTime(DateTime.now().year - 1, 1, 15);
      final oldKey =
          '${old.year}-${old.month.toString().padLeft(2, '0')}-${old.day.toString().padLeft(2, '0')}';
      await daily.set('worship_score', oldKey, '', 90);
      final container = await _createResolvedContainer(dailyStatusDao: daily);
      addTearDown(container.dispose);
      await container.read(evaluationProvider.future);
      final notifier = container.read(evaluationProvider.notifier);
      expect(notifier.dailyAverage, equals(0));
      expect(notifier.dailyAverage, equals(notifier.monthlyAverage));
    });

    test('weeklyBestWorst reports the real weekday names', () async {
      SharedPreferences.setMockInitialValues({});
      final daily = MockDailyStatusDao();
      final now = DateTime.now();
      String keyOf(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final threeDaysAgo = now.subtract(const Duration(days: 3));
      await daily.set('worship_score', keyOf(threeDaysAgo), '', 100);
      final container = await _createResolvedContainer(dailyStatusDao: daily);
      addTearDown(container.dispose);
      await container.read(evaluationProvider.future);
      final notifier = container.read(evaluationProvider.notifier);
      final names = {
        1: 'دوشنبه',
        2: 'سه‌شنبه',
        3: 'چهارشنبه',
        4: 'پنجشنبه',
        5: 'جمعه',
        6: 'شنبه',
        7: 'یکشنبه',
      };
      final result = notifier.weeklyBestWorst;
      expect(result['bestDay'], equals(names[threeDaysAgo.weekday]));
      expect(result['bestScore'], equals(100));
    });

    test('dailyScore includes prayer points for completed prayers', () async {
      SharedPreferences.setMockInitialValues({});
      final ptDao = MockPrayerTrackerDao();
      final today = DateTime.now();
      final todayKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      // Mark all 5 fardh prayers as done + 6 sunnah + duha.
      for (final name in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
        await ptDao.upsert(PrayerTrackerTableData(
            date: todayKey, prayerKey: name, value: PrayerStatus.done.index));
      }
      for (final name in [
        'fajrRawatib',
        'dhuhrRawatibBefore',
        'dhuhrRawatibAfter',
        'maghribRawatib',
        'ishaRawatib',
        'witr'
      ]) {
        await ptDao.upsert(PrayerTrackerTableData(
            date: todayKey, prayerKey: 'sunnah_$name', value: 1));
      }
      await ptDao.upsert(
          PrayerTrackerTableData(date: todayKey, prayerKey: 'duha', value: 1));
      final container = await _createResolvedContainer(prayerTrackerDao: ptDao);
      addTearDown(container.dispose);
      final state = await container.read(evaluationProvider.future);
      // 5 fardh×10 + 6 sunnah×5 + duha×5 = 85 prayer points on top of the
      // worship-checklist score (0 here since no worship items are done).
      expect(state.dailyScore, greaterThanOrEqualTo(85));
    });

    test('past prayer-only days still count into weekly/monthly score',
        () async {
      SharedPreferences.setMockInitialValues({});
      final ptDao = MockPrayerTrackerDao();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayKey =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      // Prayed all 5 fardh yesterday but did NOT touch the worship checklist,
      // so no `worship_score` row exists for that day.
      for (final name in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
        await ptDao.upsert(PrayerTrackerTableData(
            date: yesterdayKey,
            prayerKey: name,
            value: PrayerStatus.done.index));
      }
      final container = await _createResolvedContainer(prayerTrackerDao: ptDao);
      addTearDown(container.dispose);
      await container.read(evaluationProvider.future);
      final notifier = container.read(evaluationProvider.notifier);
      // Yesterday's 5 fardh = 50 prayer points must appear in the weekly total
      // even though no worship_score row was persisted for that day.
      expect(notifier.weeklyPoints(), greaterThanOrEqualTo(50));
      expect(notifier.getScoreForDate(yesterday), greaterThanOrEqualTo(50));
    });

    test('period days are recognized but never auto-count prayers or fasting',
        () async {
      SharedPreferences.setMockInitialValues({});
      final periodDao = MockPeriodRecordDao();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      // Active period that started yesterday (default length 7) covers today.
      await periodDao.upsertRecord(PeriodRecordTableData(
        id: 1,
        startDate: today.subtract(const Duration(days: 1)),
        periodLength: 7,
        createdAt: DateTime.now(),
      ));
      final container = await _createResolvedContainer(periodDao: periodDao);
      addTearDown(container.dispose);
      final state = await container.read(evaluationProvider.future);
      final notifier = container.read(evaluationProvider.notifier);
      final todayKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      // Period-day recognition is kept for statistics and calendar UI ...
      expect(notifier.isPeriodDay(todayKey), isTrue);
      expect(notifier.periodDaysInRange(todayKey, todayKey), equals(1));
      // ... but scoring is manual (e9acafc removed auto-counting): with no
      // prayer records or fasting toggles the period day awards nothing.
      expect(state.dailyScore, 0);
      expect(notifier.countFastingInRange(todayKey, todayKey), equals(0));
      expect(notifier.weeklyPoints(), 0);
    });

    test('active period longer than its stored length still covers today',
        () async {
      SharedPreferences.setMockInitialValues({});
      final periodDao = MockPeriodRecordDao();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      // Active record started 10 days ago with periodLength 7 — inside the
      // 15-day hayz cap, so PeriodRecordX.coversDate floors it at today. The
      // evaluation key set must use the same rule or the daily banner and the
      // weekly «معاف» count disagree.
      await periodDao.upsertRecord(PeriodRecordTableData(
        id: 1,
        startDate: today.subtract(const Duration(days: 10)),
        periodLength: 7,
        createdAt: DateTime.now(),
      ));
      final container = await _createResolvedContainer(periodDao: periodDao);
      addTearDown(container.dispose);
      await container.read(evaluationProvider.future);
      final notifier = container.read(evaluationProvider.notifier);
      final todayKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final start = today.subtract(const Duration(days: 10));
      final startKey =
          '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
      expect(notifier.isPeriodDay(todayKey), isTrue);
      expect(notifier.periodDaysInRange(startKey, todayKey), equals(11));
    });

    test('period day still scores when prayers are recorded manually',
        () async {
      SharedPreferences.setMockInitialValues({});
      final periodDao = MockPeriodRecordDao();
      final ptDao = MockPrayerTrackerDao();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      // Active period that started yesterday (default length 7) covers today.
      await periodDao.upsertRecord(PeriodRecordTableData(
        id: 1,
        startDate: today.subtract(const Duration(days: 1)),
        periodLength: 7,
        createdAt: DateTime.now(),
      ));
      final todayKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      // All 5 fardh prayers recorded manually despite the period day.
      for (final name in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
        await ptDao.upsert(PrayerTrackerTableData(
            date: todayKey, prayerKey: name, value: PrayerStatus.done.index));
      }
      final container = await _createResolvedContainer(
          periodDao: periodDao, prayerTrackerDao: ptDao);
      addTearDown(container.dispose);
      final state = await container.read(evaluationProvider.future);
      // 5 fardh ×10 = 50 — explicit registration on a period day still counts.
      expect(state.dailyScore, greaterThanOrEqualTo(50));
      final notifier = container.read(evaluationProvider.notifier);
      expect(notifier.isPeriodDay(todayKey), isTrue);
      expect(notifier.weeklyPoints(), greaterThanOrEqualTo(50));
    });

    test('completed period record is respected and future days excluded',
        () async {
      SharedPreferences.setMockInitialValues({});
      final periodDao = MockPeriodRecordDao();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      // Period that ENDED yesterday: today must NOT be a period day.
      await periodDao.upsertRecord(PeriodRecordTableData(
        id: 1,
        startDate: today.subtract(const Duration(days: 5)),
        endDate: today.subtract(const Duration(days: 1)),
        periodLength: 5,
        createdAt: DateTime.now(),
      ));
      final container = await _createResolvedContainer(periodDao: periodDao);
      addTearDown(container.dispose);
      await container.read(evaluationProvider.future);
      final notifier = container.read(evaluationProvider.notifier);
      final todayKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      expect(notifier.isPeriodDay(todayKey), isFalse);
      expect(notifier.countFastingInRange(todayKey, todayKey), equals(0));
    });

    group('frozen history scores', () {
      String dateKey(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      test('past score keeps adhkar points and ignores later point changes',
          () async {
        SharedPreferences.setMockInitialValues({});
        AzkarData.setTestData(const [
          ZikrItem(
              id: 'm1',
              title: 't',
              arabicText: 'a',
              translation: '',
              source: '',
              period: PrayerPeriod.morningAzkar),
          ZikrItem(
              id: 'm2',
              title: 't',
              arabicText: 'a',
              translation: '',
              source: '',
              period: PrayerPeriod.morningAzkar),
        ]);
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final yKey = dateKey(yesterday);

        // Yesterday: full morning adhkar done + worship_score 20.
        final statusDao = MockAzkarStatusDao();
        await statusDao.setStatus(
            ZikrStatusRecordTableData(id: 'm1', statusIndex: 1, date: yKey));
        await statusDao.setStatus(
            ZikrStatusRecordTableData(id: 'm2', statusIndex: 1, date: yKey));
        final dailyDao = MockDailyStatusDao();
        await dailyDao.set('worship_score', yKey, '', 20);

        final c1 = await _createResolvedContainer(
            statusDao: statusDao, dailyStatusDao: dailyDao);
        addTearDown(c1.dispose);
        await c1.read(evaluationProvider.future);
        // 20 worship + 10 morning adhkar (default points).
        expect(c1.read(evaluationProvider.notifier).getScoreForDate(yesterday),
            equals(30));

        // Rebuild with wildly different point settings: the frozen past
        // must not move (pre-fix it recomputed to 20 + 999 = 1019).
        final c2 = await _createResolvedContainer(
          statusDao: statusDao,
          dailyStatusDao: dailyDao,
          customSettings: const AppSettings(adhkarPoint: 999, fardhPoint: 999),
        );
        addTearDown(c2.dispose);
        await c2.read(evaluationProvider.future);
        expect(c2.read(evaluationProvider.notifier).getScoreForDate(yesterday),
            equals(30));
      });

      test('explicit past-day edit re-scores and freezes the new value',
          () async {
        SharedPreferences.setMockInitialValues({});
        AzkarData.setTestData(const [
          ZikrItem(
              id: 'm1',
              title: 't',
              arabicText: 'a',
              translation: '',
              source: '',
              period: PrayerPeriod.morningAzkar),
        ]);
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final yKey = dateKey(yesterday);

        // Yesterday: morning adhkar done, no worship toggles yet.
        final statusDao = MockAzkarStatusDao();
        await statusDao.setStatus(
            ZikrStatusRecordTableData(id: 'm1', statusIndex: 1, date: yKey));
        final dailyDao = MockDailyStatusDao();

        final container = await _createResolvedContainer(
            statusDao: statusDao, dailyStatusDao: dailyDao);
        addTearDown(container.dispose);
        await container.read(evaluationProvider.future);
        final notifier = container.read(evaluationProvider.notifier);
        // Only the 10 morning-adhkar points so far.
        expect(notifier.getScoreForDate(yesterday), isNull);

        // Toggling a worship item for the past date scores it with current
        // points (quran = 5) on top of the adhkar 10, then freezes 15.
        notifier.toggleWorshipForDate('quran', yesterday);
        expect(notifier.getScoreForDate(yesterday), equals(15));

        // Rebuild with different points: the edited past stays frozen
        // (pre-fix it recomputed to 5 + 999 = 1004).
        final c2 = await _createResolvedContainer(
          statusDao: statusDao,
          dailyStatusDao: dailyDao,
          customSettings: const AppSettings(adhkarPoint: 999),
        );
        addTearDown(c2.dispose);
        await c2.read(evaluationProvider.future);
        expect(c2.read(evaluationProvider.notifier).getScoreForDate(yesterday),
            equals(15));
      });
    });

    group('streaks', () {
      String dateKey(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      Future<ProviderContainer> containerWithScores(
          Map<int, int> daysAgoToScore) async {
        SharedPreferences.setMockInitialValues({});
        final dailyDao = MockDailyStatusDao();
        final now = DateTime.now();
        for (final e in daysAgoToScore.entries) {
          await dailyDao.set('worship_score',
              dateKey(now.subtract(Duration(days: e.key))), '', e.value);
        }
        final c = await _createResolvedContainer(dailyStatusDao: dailyDao);
        addTearDown(c.dispose);
        // Evaluation is auto-dispose: without a listener the state may be
        // torn down between the awaited build and the reads below
        // (`requireValue` on AsyncLoading). Hold a subscription so these
        // tests are deterministic regardless of scheduling.
        c.listen(evaluationProvider, (_, __) {});
        // A watched dependency may emit right after the first build, kicking
        // off a second build while the awaited future already resolved.
        // Wait for settled data before interacting with the notifier.
        for (var i = 0; i < 100; i++) {
          final s = c.read(evaluationProvider);
          if (s is AsyncData<EvaluationState>) break;
          if (s is AsyncError<EvaluationState>) throw s.error;
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        await c.read(evaluationProvider.future);
        return c;
      }

      test('today missing does not break an active streak', () async {
        // Scores on -1, -2, -3; today untouched.
        final c = await containerWithScores({1: 10, 2: 10, 3: 10});
        expect(c.read(evaluationProvider).value!.currentStreak, equals(3));
      });

      test('a gap day breaks the streak', () async {
        // Missing -3 splits the run: only -1, -2 count.
        final c = await containerWithScores({1: 10, 2: 10, 4: 10});
        expect(c.read(evaluationProvider).value!.currentStreak, equals(2));
      });

      test('today score extends the streak', () async {
        final c = await containerWithScores({1: 10, 2: 10});
        // A seeded today row would be overwritten by the live recompute in
        // build(), so earn today for real through the notifier instead.
        c.read(evaluationProvider.notifier).toggleWorship('quran');
        expect(c.read(evaluationProvider).value!.currentStreak, equals(3));
      });

      test('best streak is the longest run in the window', () async {
        // Run of 3 (days -10..-8) beats run of 2 (days -2..-1).
        final c =
            await containerWithScores({1: 10, 2: 10, 8: 10, 9: 10, 10: 10});
        final state = c.read(evaluationProvider).value!;
        expect(state.currentStreak, equals(2));
        expect(state.bestStreak, equals(3));
      });

      test('empty history means zero streaks', () async {
        final c = await containerWithScores({});
        final state = c.read(evaluationProvider).value!;
        expect(state.currentStreak, equals(0));
        expect(state.bestStreak, equals(0));
      });
    });
  });
}
