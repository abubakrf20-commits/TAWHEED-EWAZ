import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/prayer/data/daos/period_record_dao.dart';
import 'package:tawheeed/features/prayer/presentation/providers/period_provider.dart';
import '../../../../core/database/mock_daos.dart';

void main() {
  const zero = 0;
  late ProviderContainer container;
  late MockPeriodRecordDao mockDao;

  DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime daysAgo(int n) =>
      dayOnly(DateTime.now()).subtract(Duration(days: n));
  DateTime daysAhead(int n) => dayOnly(DateTime.now()).add(Duration(days: n));

  setUp(() {
    mockDao = MockPeriodRecordDao();
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(overrides: [
      periodRecordDaoProvider.overrideWithValue(mockDao),
    ]);
  });

  tearDown(() {
    container.dispose();
  });

  test('build returns default PeriodState when DAO is empty', () async {
    final state = await container.read(periodProvider.future);
    expect(state.records, isEmpty);
    expect(state.defaultPeriodLength, equals(7));
    expect(state.defaultCycleLength, equals(28));
    expect(state.isLocked, isFalse);
    expect(state.notificationsEnabled, isTrue);
  });

  test('build loads records from DAO sorted by startDate descending', () async {
    final earlier = DateTime(2024);
    final later = DateTime(2024, 6, 15);
    await mockDao.insertRecord(PeriodRecordTableCompanion.insert(
      startDate: earlier,
      endDate: Value(DateTime(2024, 1, 7)),
      periodLength: 7,
      createdAt: earlier,
    ));
    await mockDao.insertRecord(PeriodRecordTableCompanion.insert(
      startDate: later,
      endDate: Value(DateTime(2024, 6, 20)),
      periodLength: 5,
      createdAt: later,
    ));
    final state = await container.read(periodProvider.future);
    expect(state.records.length, equals(2));
    expect(state.records[0].startDate, equals(later));
    expect(state.records[1].startDate, equals(earlier));
  });

  test('startPeriod creates a new record and leaves it active', () async {
    await container.read(periodProvider.future);
    final notifier = container.read(periodProvider.notifier);

    final periodStart = daysAgo(1);
    final ok = await notifier.startPeriod(periodStart);
    expect(ok, isTrue);

    final state = container.read(periodProvider).value!;
    expect(state.records.length, equals(1));
    expect(state.records[0].startDate, equals(periodStart));
    expect(state.records[0].endDate, isNull);
  });

  test('startPeriod returns false for double-tap on same start day', () async {
    await container.read(periodProvider.future);
    final notifier = container.read(periodProvider.notifier);

    final day = daysAgo(1);
    expect(await notifier.startPeriod(day), isTrue);
    expect(await notifier.startPeriod(day), isFalse);

    final state = container.read(periodProvider).value!;
    expect(state.records.length, equals(1));
    expect(state.records[0].endDate, isNull);
  });

  test('startPeriod returns false when day is covered by a completed record',
      () async {
    await mockDao.insertRecord(PeriodRecordTableCompanion.insert(
      startDate: daysAgo(20),
      endDate: Value(daysAgo(14)),
      periodLength: 7,
      createdAt: DateTime.now(),
    ));
    await container.read(periodProvider.future);
    final notifier = container.read(periodProvider.notifier);

    final ok = await notifier.startPeriod(daysAgo(16));
    expect(ok, isFalse);
    final state = container.read(periodProvider).value!;
    expect(state.records.length, equals(1));
  });

  test('startPeriod closes previous active record at day − 1', () async {
    await container.read(periodProvider.future);
    final notifier = container.read(periodProvider.notifier);

    final first = daysAgo(10);
    final second = daysAgo(4);
    expect(await notifier.startPeriod(first), isTrue);
    expect(await notifier.startPeriod(second), isTrue);

    final state = container.read(periodProvider).value!;
    expect(state.records.length, equals(2));
    final previous = state.records.firstWhere((r) => r.startDate == first);
    expect(previous.endDate, equals(daysAgo(5)));
    expect(previous.actualLength, equals(6)); // daysAgo(10)..daysAgo(5)
  });

  test('startPeriod with earlier date moves active start, preserving data',
      () async {
    await container.read(periodProvider.future);
    final notifier = container.read(periodProvider.notifier);

    final later = daysAgo(3);
    final earlier = daysAgo(6);
    expect(await notifier.startPeriod(later), isTrue);
    final activeId = container.read(periodProvider).value!.records.first.id;
    await notifier.updateFlow(activeId, PeriodFlow.heavy);
    await notifier.updateSymptoms(activeId, 'سردرد');

    expect(await notifier.startPeriod(earlier), isTrue);

    final state = container.read(periodProvider).value!;
    expect(state.records.length, equals(1));
    final moved = state.records.first;
    expect(moved.startDate, equals(earlier));
    expect(moved.endDate, isNull);
    expect(moved.flowValue, equals(PeriodFlow.heavy));
    expect(moved.symptoms, equals('سردرد'));
  });

  test('endPeriod closes an active period', () async {
    await container.read(periodProvider.future);
    final notifier = container.read(periodProvider.notifier);

    final periodStart = daysAgo(5);
    await notifier.startPeriod(periodStart);

    final periodEnd = daysAgo(2);
    await notifier.endPeriod(periodEnd);

    final state = container.read(periodProvider).value!;
    expect(state.records.length, equals(1));
    expect(state.records[0].endDate, equals(periodEnd));
  });

  test('endPeriod ignores end dates before the start', () async {
    await container.read(periodProvider.future);
    final notifier = container.read(periodProvider.notifier);

    final periodStart = daysAgo(3);
    await notifier.startPeriod(periodStart);
    await notifier.endPeriod(daysAgo(10));

    final state = container.read(periodProvider).value!;
    expect(state.records[0].endDate, isNull);
  });

  test('setRecordEnd shortens a completed record', () async {
    await mockDao.insertRecord(PeriodRecordTableCompanion.insert(
      startDate: daysAgo(10),
      endDate: Value(daysAgo(3)),
      periodLength: 8,
      createdAt: DateTime.now(),
    ));
    await container.read(periodProvider.future);
    final notifier = container.read(periodProvider.notifier);
    final id = container.read(periodProvider).value!.records.first.id;

    await notifier.setRecordEnd(id, daysAgo(5));

    final state = container.read(periodProvider).value!;
    expect(state.records[0].endDate, equals(daysAgo(5)));
    expect(state.records[0].periodLength, equals(6));
  });

  test('setRecordEnd refuses end before start', () async {
    await mockDao.insertRecord(PeriodRecordTableCompanion.insert(
      startDate: daysAgo(10),
      endDate: Value(daysAgo(3)),
      periodLength: 8,
      createdAt: DateTime.now(),
    ));
    await container.read(periodProvider.future);
    final notifier = container.read(periodProvider.notifier);
    final id = container.read(periodProvider).value!.records.first.id;

    await notifier.setRecordEnd(id, daysAgo(30));

    final state = container.read(periodProvider).value!;
    expect(state.records[0].endDate, equals(daysAgo(3)));
  });

  test('extendRecordEnd extends a completed record forward', () async {
    await mockDao.insertRecord(PeriodRecordTableCompanion.insert(
      startDate: daysAgo(10),
      endDate: Value(daysAgo(6)),
      periodLength: 5,
      createdAt: DateTime.now(),
    ));
    await container.read(periodProvider.future);
    final notifier = container.read(periodProvider.notifier);
    final id = container.read(periodProvider).value!.records.first.id;

    await notifier.extendRecordEnd(id, daysAgo(2));

    final state = container.read(periodProvider).value!;
    expect(state.records[0].endDate, equals(daysAgo(2)));
  });

  group('future dates are refused', () {
    test('startPeriod returns false and inserts nothing', () async {
      await container.read(periodProvider.future);
      final notifier = container.read(periodProvider.notifier);

      expect(await notifier.startPeriod(daysAhead(1)), isFalse);
      expect(await notifier.startPeriod(daysAhead(30)), isFalse);

      final state = container.read(periodProvider).value!;
      expect(state.records, isEmpty);
    });

    test('startNifas and startIstihadha share the guard', () async {
      await container.read(periodProvider.future);
      final notifier = container.read(periodProvider.notifier);

      expect(await notifier.startNifas(daysAhead(1)), isFalse);
      expect(await notifier.startIstihadha(daysAhead(1)), isFalse);

      expect(container.read(periodProvider).value!.records, isEmpty);
    });

    test('endPeriod ignores a future end', () async {
      await container.read(periodProvider.future);
      final notifier = container.read(periodProvider.notifier);

      await notifier.startPeriod(daysAgo(3));
      await notifier.endPeriod(daysAhead(2));

      final state = container.read(periodProvider).value!;
      expect(state.records[0].endDate, isNull);
    });

    test('setRecordEnd ignores a future end', () async {
      await mockDao.insertRecord(PeriodRecordTableCompanion.insert(
        startDate: daysAgo(10),
        endDate: Value(daysAgo(3)),
        periodLength: 8,
        createdAt: DateTime.now(),
      ));
      await container.read(periodProvider.future);
      final notifier = container.read(periodProvider.notifier);
      final id = container.read(periodProvider).value!.records.first.id;

      await notifier.setRecordEnd(id, daysAhead(2));

      final state = container.read(periodProvider).value!;
      expect(state.records[0].endDate, equals(daysAgo(3)));
    });

    test('extendRecordEnd ignores a future extension', () async {
      await mockDao.insertRecord(PeriodRecordTableCompanion.insert(
        startDate: daysAgo(10),
        endDate: Value(daysAgo(6)),
        periodLength: 5,
        createdAt: DateTime.now(),
      ));
      await container.read(periodProvider.future);
      final notifier = container.read(periodProvider.notifier);
      final id = container.read(periodProvider).value!.records.first.id;

      await notifier.extendRecordEnd(id, daysAhead(2));

      final state = container.read(periodProvider).value!;
      expect(state.records[0].endDate, equals(daysAgo(6)));
    });

    test('today itself is still recorded', () async {
      await container.read(periodProvider.future);
      final notifier = container.read(periodProvider.notifier);

      expect(await notifier.startPeriod(daysAhead(0)), isTrue);
      expect(container.read(periodProvider).value!.records, hasLength(1));
    });
  });

  test('deleteRecord removes a record', () async {
    await mockDao.insertRecord(PeriodRecordTableCompanion.insert(
      startDate: DateTime(2024),
      endDate: Value(DateTime(2024, 1, 7)),
      periodLength: 7,
      createdAt: DateTime.now(),
    ));
    final existing = (await mockDao.getAllRecords()).first;

    await container.read(periodProvider.future);
    final notifier = container.read(periodProvider.notifier);
    await notifier.deleteRecord(existing.id);

    final state = container.read(periodProvider).value!;
    expect(state.records, isEmpty);
  });

  test('latestRecord returns most recent record', () async {
    final earlier = DateTime(2024);
    final later = DateTime(2024, 6, 15);
    await mockDao.insertRecord(PeriodRecordTableCompanion.insert(
      startDate: earlier,
      endDate: Value(DateTime(2024, 1, 7)),
      periodLength: 7,
      createdAt: earlier,
    ));
    await mockDao.insertRecord(PeriodRecordTableCompanion.insert(
      startDate: later,
      endDate: Value(DateTime(2024, 6, 20)),
      periodLength: 5,
      createdAt: later,
    ));

    await container.read(periodProvider.future);
    final notifier = container.read(periodProvider.notifier);
    expect(notifier.latestRecord!.startDate, equals(later));
  });

  test('latestRecord returns null when no records', () async {
    await container.read(periodProvider.future);
    final notifier = container.read(periodProvider.notifier);
    expect(notifier.latestRecord, isNull);
  });

  test('isDateInPeriod uses completed coverage, not active forever', () async {
    await mockDao.insertRecord(PeriodRecordTableCompanion.insert(
      startDate: daysAgo(10),
      endDate: Value(daysAgo(4)),
      periodLength: 7,
      createdAt: DateTime.now(),
    ));

    await container.read(periodProvider.future);
    final notifier = container.read(periodProvider.notifier);
    expect(notifier.isDateInPeriod(daysAgo(8)), isTrue);
    expect(notifier.isDateInPeriod(daysAgo(2)), isFalse);
    expect(notifier.isDateInPeriod(daysAgo(11)), isFalse);
  });

  test('active hayz record covers today (banner / status agree)', () async {
    await container.read(periodProvider.future);
    final notifier = container.read(periodProvider.notifier);
    await notifier.startPeriod(daysAgo(2));

    expect(notifier.isDateInPeriod(DateTime.now()), isTrue);
    expect(notifier.findRecordForDate(DateTime.now()), isNotNull);
    final status = notifier.getTodayStatus();
    expect(status['status'], equals('haid'));
    expect(status['canPray'], isFalse);
  });

  test('auto-closes abandoned active record past fiqh max on load', () async {
    // Active hayz started 20 days ago → max is 15 days → auto-close at +14.
    await mockDao.insertRecord(PeriodRecordTableCompanion.insert(
      startDate: daysAgo(20),
      periodLength: 7,
      createdAt: DateTime.now(),
    ));
    final state = await container.read(periodProvider.future);
    expect(state.records[0].endDate, isNotNull);
    expect(state.records[0].endDate,
        equals(daysAgo(20).add(const Duration(days: 14))));
    expect(state.records[0].actualLength, equals(15));
  });

  test('active nifas can run up to 60 days before auto-close', () async {
    await mockDao.insertRecord(PeriodRecordTableCompanion.insert(
      startDate: daysAgo(20),
      periodLength: 7,
      createdAt: DateTime.now(),
      recordType: const Value('nifas'),
    ));
    final state = await container.read(periodProvider.future);
    expect(state.records[0].endDate, isNull);
    expect(state.records[0].type, equals(PeriodRecordType.nifas));
  });

  test('getTodayStatus returns unknown when no records', () async {
    await container.read(periodProvider.future);
    final notifier = container.read(periodProvider.notifier);
    final status = notifier.getTodayStatus();
    expect(status['status'], equals('unknown'));
    expect(status['canPray'], isTrue);
  });

  test('recorded hayz is shown even while pregnant', () async {
    await container.read(periodProvider.future);
    final notifier = container.read(periodProvider.notifier);
    await notifier.setPregnant(true);
    await notifier.startPeriod(DateTime.now());

    final status = notifier.getTodayStatus();
    expect(status['status'], equals('haid'));
    expect(status['canPray'], isFalse);
  });

  test('pregnancy banner without a record', () async {
    await container.read(periodProvider.future);
    final notifier = container.read(periodProvider.notifier);
    await notifier.setPregnant(true);

    final status = notifier.getTodayStatus();
    expect(status['status'], equals('pregnant'));
    expect(status['canPray'], isTrue);
  });

  test('setRecovery + verifyRecoveryAnswer is case-insensitive', () async {
    await container.read(periodProvider.future);
    final notifier = container.read(periodProvider.notifier);

    await notifier.setRecovery('نام مادر؟', '  Tehran  ');
    expect(notifier.hasRecovery, isTrue);
    expect(notifier.verifyRecoveryAnswer('tehran'), isTrue);
    expect(notifier.verifyRecoveryAnswer('TEHRAN'), isTrue);
    expect(notifier.verifyRecoveryAnswer('Tehran'), isTrue);
    expect(notifier.verifyRecoveryAnswer('isfahan'), isFalse);
  });

  group('legacy plaintext secrets upgrade on first verify (L3)', () {
    ProviderContainer freshContainer() => ProviderContainer(overrides: [
          periodRecordDaoProvider.overrideWithValue(mockDao),
        ]);

    test('a plaintext PIN verifies once, then prefs hold a salted hash',
        () async {
      SharedPreferences.setMockInitialValues({'period_pin': '1234'});
      final c = freshContainer();
      addTearDown(c.dispose);
      await c.read(periodProvider.future);
      final notifier = c.read(periodProvider.notifier);

      expect(notifier.verifyPin('1234'), isTrue);
      expect(notifier.verifyPin('9999'), isFalse);

      await pumpEventQueue();
      final stored =
          (await SharedPreferences.getInstance()).getString('period_pin');
      expect(stored, startsWith('sha256\$1\$'),
          reason: 'the plaintext PIN must not survive the first unlock');
      // The same PIN keeps unlocking after the upgrade.
      expect(notifier.verifyPin('1234'), isTrue);
      expect(notifier.verifyPin('9999'), isFalse);
    });

    test('a plaintext recovery answer is re-hashed after the first verify',
        () async {
      SharedPreferences.setMockInitialValues({
        'period_recovery_question': 'نام مادر؟',
        'period_recovery_answer': 'tehran',
      });
      final c = freshContainer();
      addTearDown(c.dispose);
      await c.read(periodProvider.future);
      final notifier = c.read(periodProvider.notifier);

      expect(notifier.verifyRecoveryAnswer('Tehran'), isTrue);
      expect(notifier.verifyRecoveryAnswer('isfahan'), isFalse);

      await pumpEventQueue();
      final stored = (await SharedPreferences.getInstance())
          .getString('period_recovery_answer');
      expect(stored, startsWith('sha256\$1\$'));
      expect(notifier.verifyRecoveryAnswer('tehran'), isTrue);
    });
  });

  test(
      'istihadha: Shafi\u{2BC0}i ruling — wudu per prayer, prayer and fast valid',
      () async {
    await mockDao.insertRecord(PeriodRecordTableCompanion.insert(
      startDate: daysAgo(3),
      periodLength: 7,
      createdAt: DateTime.now(),
      recordType: const Value('istihadha'),
    ));
    await container.read(periodProvider.future);
    final notifier = container.read(periodProvider.notifier);

    final status = notifier.getTodayStatus();
    expect(status['status'], equals('istihadha'));
    expect(status['needsGhusl'], isFalse);
    expect(status['canPray'], isTrue);
    expect(status['canFast'], isTrue);
  });

  test('clearAll removes all records', () async {
    await mockDao.insertRecord(PeriodRecordTableCompanion.insert(
      startDate: DateTime(2024),
      endDate: Value(DateTime(2024, 1, 7)),
      periodLength: 7,
      createdAt: DateTime.now(),
    ));
    await container.read(periodProvider.future);
    final notifier = container.read(periodProvider.notifier);
    await notifier.clearAll();
    final state = container.read(periodProvider).value!;
    expect(state.records, isEmpty);
  });

  test('setLocked updates isLocked', () async {
    await container.read(periodProvider.future);
    final notifier = container.read(periodProvider.notifier);
    await notifier.setLocked(true);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('period_locked'), isTrue);
  });

  test('setNotificationsEnabled updates notification setting', () async {
    await container.read(periodProvider.future);
    final notifier = container.read(periodProvider.notifier);
    await notifier.setNotificationsEnabled(false);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('period_notif_enabled'), isFalse);
  });

  test('currentSnapshot exposes the loaded state', () async {
    await container.read(periodProvider.future);
    final notifier = container.read(periodProvider.notifier);
    expect(notifier.currentSnapshot, isNotNull);
    expect(notifier.currentSnapshot!.records, isEmpty);
  });

  test('startPeriod records nifas and istihadha types', () async {
    await container.read(periodProvider.future);
    final notifier = container.read(periodProvider.notifier);

    expect(
        await notifier.startPeriod(daysAgo(30), type: PeriodRecordType.nifas),
        isTrue);
    expect(
        await notifier.startPeriod(daysAgo(20),
            type: PeriodRecordType.istihadha),
        isTrue);

    final state = container.read(periodProvider).value!;
    final nifas = state.records.firstWhere((r) => r.startDate == daysAgo(30));
    final istih = state.records.firstWhere((r) => r.startDate == daysAgo(20));
    expect(nifas.type, equals(PeriodRecordType.nifas));
    expect(istih.type, equals(PeriodRecordType.istihadha));
    // First nifas (30 days ago, max 60) was closed by the second start.
    expect(nifas.endDate, equals(daysAgo(21)));
  });

  test('setPregnant and setPregnancyDueDate persist through prefs', () async {
    await container.read(periodProvider.future);
    final notifier = container.read(periodProvider.notifier);
    final due = DateTime(2024, 10);
    await notifier.setPregnant(true);
    await notifier.setPregnancyDueDate(due);
    var state = container.read(periodProvider).value!;
    expect(state.isPregnant, isTrue);
    expect(state.pregnancyDueDate, equals(due));

    await notifier.setPregnant(false);
    state = container.read(periodProvider).value!;
    expect(state.isPregnant, isFalse);
    expect(state.pregnancyDueDate, isNull);
  });

  test('addRamadanMissedToQada is idempotent and counts Ramadan days only',
      () async {
    final start = DateTime(2024);
    await mockDao.insertRecord(PeriodRecordTableCompanion.insert(
      startDate: start,
      endDate: Value(DateTime(2024, 12, 31)),
      periodLength: 366,
      createdAt: start,
    ));
    await container.read(periodProvider.future);
    final notifier = container.read(periodProvider.notifier);

    final first = await notifier.addRamadanMissedToQada(2024);
    expect(first, greaterThan(0));
    var state = container.read(periodProvider).value!;
    expect(state.qadaFastsOwed, equals(first));

    final second = await notifier.addRamadanMissedToQada(2024);
    expect(second, equals(0));
    state = container.read(periodProvider).value!;
    expect(state.qadaFastsOwed, equals(first));
  });

  test('getMissedFastingDays and addRamadanMissedToQada honor hijriOffset',
      () async {
    // Cover a full Gregorian year; offset only shifts which days count as
    // Ramadan — the methods must accept and forward it (no hard-coded 2).
    await mockDao.insertRecord(PeriodRecordTableCompanion.insert(
      startDate: DateTime(2024),
      endDate: Value(DateTime(2024, 12, 31)),
      periodLength: 366,
      createdAt: DateTime(2024),
    ));
    await container.read(periodProvider.future);
    final notifier = container.read(periodProvider.notifier);

    final a = notifier.getMissedFastingDays(2024, hijriOffset: 1);
    final b = notifier.getMissedFastingDays(2024, hijriOffset: 3);
    expect(a, isNotEmpty);
    expect(b, isNotEmpty);
    // Different offsets → different Ramadan date windows (not just counts).
    expect(a.toSet(), isNot(equals(b.toSet())));

    final added = await notifier.addRamadanMissedToQada(2024, hijriOffset: 1);
    expect(added, equals(a.length));
  });

  group('cycleStats', () {
    Future<void> insertPeriods(List<List<int>> starts) async {
      for (final s in starts) {
        await mockDao.insertRecord(PeriodRecordTableCompanion.insert(
          startDate: DateTime(s[0], s[1], s[2]),
          endDate: Value(DateTime(s[0], s[1], s[2] + 4)),
          periodLength: 5,
          createdAt: DateTime.now(),
        ));
      }
    }

    test('returns null fields with a single record', () async {
      await insertPeriods([
        [2024, 1, 1]
      ]);
      await container.read(periodProvider.future);
      final notifier = container.read(periodProvider.notifier);
      final stats = notifier.cycleStats();
      expect(stats, isNotNull);
      expect(stats!.shortestCycle, isNull);
      expect(stats.longestCycle, isNull);
      expect(stats.regularity, isNull);
      expect(stats.averageCycle, equals(28.0));
    });

    test('computes shortest/longest/average over complete gaps', () async {
      await insertPeriods([
        [2024, 1, 1],
        [2024, 1, 28], // gap 27
        [2024, 2, 26], // gap 29
        [2024, 3, 26], // gap 29
      ]);
      await container.read(periodProvider.future);
      final notifier = container.read(periodProvider.notifier);
      final stats = notifier.cycleStats();
      expect(stats!.shortestCycle, equals(27));
      expect(stats.longestCycle, equals(29));
      expect(stats.averageCycle, closeTo(28.33, 0.01));
      expect(stats.regularity, isNotNull);
      expect(stats.regularity!, greaterThan(0.9)); // very regular
    });

    test('flags irregular cycles with low regularity', () async {
      await insertPeriods([
        [2024, 1, 1],
        [2024, 1, 17], // gap 16 (min counted is >15)
        [2024, 3, 2], // gap 45
      ]);
      await container.read(periodProvider.future);
      final notifier = container.read(periodProvider.notifier);
      final stats = notifier.cycleStats();
      expect(stats!.regularity, isNotNull);
      expect(stats.regularity!, lessThan(0.6));
    });

    test('returns null with no records', () async {
      await container.read(periodProvider.future);
      final notifier = container.read(periodProvider.notifier);
      expect(notifier.cycleStats(), isNull);
    });
  });

  group('periodRegularityLabel', () {
    test('matches UI thresholds and never diverges from PDF', () {
      expect(periodRegularityLabel(null), equals('—'));
      expect(periodRegularityLabel(0.0), equals('نامنظم'));
      expect(periodRegularityLabel(0.59), equals('نامنظم'));
      expect(periodRegularityLabel(0.6), equals('نسبتاً منظم'));
      expect(periodRegularityLabel(0.84), equals('نسبتاً منظم'));
      expect(periodRegularityLabel(0.85), equals('بسیار منظم'));
      expect(periodRegularityLabel(1.0), equals('بسیار منظم'));
    });
  });

  group('maxBleedingDaysFor', () {
    test('fiqh caps per record type', () {
      expect(maxBleedingDaysFor(PeriodRecordType.hayz), equals(15));
      expect(maxBleedingDaysFor(PeriodRecordType.nifas), equals(60));
      expect(maxBleedingDaysFor(PeriodRecordType.istihadha), equals(180));
    });
  });

  group('predict with stale records', () {
    test('wraps cycles so next start is always in the future', () async {
      final periodStart = DateTime(2024, 1, 2);
      await mockDao.insertRecord(PeriodRecordTableCompanion.insert(
        startDate: periodStart,
        endDate: Value(periodStart.add(const Duration(days: 5))),
        periodLength: 6,
        createdAt: DateTime.now(),
      ));
      await container.read(periodProvider.future);
      final notifier = container.read(periodProvider.notifier);

      final p = notifier.predict();
      expect(p, isNotNull);
      expect(p!.daysUntilNextPeriod, greaterThan(0));
      expect(p.daysUntilNextPeriod, lessThanOrEqualTo(28));
      expect(p.nextPeriodStart.isAfter(DateTime.now()), isTrue);
      expect(p.nextPeriodStart.isAfter(periodStart), isTrue);
      expect(
        p.nextPeriodStart.difference(periodStart).inDays % 28,
        zero,
      );
      expect(p.currentDayInCycle,
          allOf(greaterThanOrEqualTo(1), lessThanOrEqualTo(28)));
      expect(p.upcomingPeriodDays, greaterThan(0));
    });
  });

  group('fertile window', () {
    test('predict exposes ovulation = next start - 14 and a 6-day window',
        () async {
      final periodStart = DateTime(2024, 1, 2);
      await mockDao.insertRecord(PeriodRecordTableCompanion.insert(
        startDate: periodStart,
        endDate: Value(periodStart.add(const Duration(days: 5))),
        periodLength: 6,
        createdAt: DateTime.now(),
      ));
      await container.read(periodProvider.future);
      final notifier = container.read(periodProvider.notifier);

      final p = notifier.predict();
      expect(p, isNotNull);
      expect(p!.ovulationDay, isNotNull);
      expect(p.nextPeriodStart.difference(p.ovulationDay).inDays, 14);
      expect(p.ovulationDay.difference(p.fertileStart).inDays, 4);
      expect(p.fertileEnd.difference(p.ovulationDay).inDays, 1);
      expect(p.isFertileDate(p.fertileStart), isTrue);
      expect(p.isFertileDate(p.ovulationDay), isTrue);
      expect(p.isFertileDate(p.fertileEnd), isTrue);
      expect(p.isFertileDate(p.fertileStart.subtract(const Duration(days: 1))),
          isFalse);
      expect(
          p.isFertileDate(p.fertileEnd.add(const Duration(days: 1))), isFalse);
    });

    test('getMonthData marks fertile future days, not months long past',
        () async {
      final periodStart = DateTime.now().subtract(const Duration(days: 10));
      await mockDao.insertRecord(PeriodRecordTableCompanion.insert(
        startDate: periodStart,
        endDate: Value(periodStart.add(const Duration(days: 5))),
        periodLength: 6,
        createdAt: DateTime.now(),
      ));
      await container.read(periodProvider.future);
      final notifier = container.read(periodProvider.notifier);

      final now = DateTime.now();
      final j = Jalali.fromDateTime(now);
      final monthData = notifier.getMonthData(j.year, j.month);
      final fertileDays = monthData.entries
          .where((e) => e.value == PeriodStatus.predictedClean)
          .toList();
      final p = notifier.predict()!;
      expect(fertileDays, isNotEmpty);
      for (final e in fertileDays) {
        final date = Jalali(j.year, j.month, e.key).toDateTime();
        expect(p.isFertileDate(date), isTrue);
      }
    });
  });

  group('reminder date persistence', () {
    test('syncPeriodReminders persists the fire dates', () async {
      final periodStart = DateTime.now().subtract(const Duration(days: 10));
      await mockDao.insertRecord(PeriodRecordTableCompanion.insert(
        startDate: periodStart,
        endDate: Value(periodStart.add(const Duration(days: 5))),
        periodLength: 6,
        createdAt: DateTime.now(),
      ));
      await container.read(periodProvider.future);
      final notifier = container.read(periodProvider.notifier);
      await notifier.syncPeriodReminders();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('next_period_notif'), isNotNull);
      expect(prefs.getString('ghusl_reminder_date'), isNotNull);
      expect(notifier.nextPeriodNotifDate, isNotNull);
      expect(notifier.ghuslReminderDate, isNotNull);
    });
  });

  group('recentCycleGaps', () {
    test('returns valid hayz gaps newest-first', () async {
      final starts = [
        daysAgo(90),
        daysAgo(62), // gap 28
        daysAgo(34), // gap 28
        daysAgo(6), // gap 28
      ];
      for (final s in starts) {
        await mockDao.insertRecord(PeriodRecordTableCompanion.insert(
          startDate: s,
          endDate: Value(s.add(const Duration(days: 4))),
          periodLength: 5,
          createdAt: DateTime.now(),
        ));
      }
      await container.read(periodProvider.future);
      final notifier = container.read(periodProvider.notifier);
      final gaps = notifier.recentCycleGaps();
      expect(gaps.length, equals(3));
      expect(gaps.every((g) => g == 28), isTrue);
    });

    test('empty when no history', () async {
      await container.read(periodProvider.future);
      final notifier = container.read(periodProvider.notifier);
      expect(notifier.recentCycleGaps(), isEmpty);
    });
  });
}
