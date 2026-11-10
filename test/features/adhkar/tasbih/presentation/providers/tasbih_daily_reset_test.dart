import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/shared/utils/date_key.dart';
import 'package:tawheeed/features/worship/data/daos/daily_status_dao.dart';
import 'package:tawheeed/features/adhkar/tasbih/data/daos/tasbih_dao.dart';
import 'package:tawheeed/features/adhkar/tasbih/presentation/providers/tasbih_daily_reset.dart';
import 'package:tawheeed/features/adhkar/tasbih/presentation/providers/tasbih_provider.dart';
import '../../../../../core/database/mock_daos.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late MockTasbihDao mockDao;

  setUp(() {
    mockDao = MockTasbihDao();
    container = ProviderContainer(overrides: [
      tasbihDaoProvider.overrideWithValue(mockDao),
      dailyStatusDaoProvider.overrideWithValue(MockDailyStatusDao()),
    ]);
  });

  tearDown(() {
    container.dispose();
  });

  Future<void> seedCount(String id, int count, {int lifetime = 0}) async {
    await mockDao.upsertTasbih(TasbihTableData(
      id: id,
      dhikrText: id,
      count: count,
      target: 33,
      totalLifetimeCount: lifetime,
      createdAt: DateTime(2024),
      isDefault: false,
      isEnabled: true,
    ));
  }

  // Every predicate case below is judged at a fixed instant — 14:00 — so the
  // outcome never depends on when the suite runs (the clock-branching version
  // of these tests asserted one thing before 15:00 and the opposite after).
  final twoPm = DateTime(2026, 10, 23, 14);
  final dayBefore = dateKeyOf(DateTime(2026, 10, 22));

  // The provider tests run against the real clock, so their "previous day" is
  // derived rather than hard-coded.
  String yesterdayKey() =>
      dateKeyOf(DateTime.now().subtract(const Duration(days: 1)));

  group('the one shared reset decision', () {
    test('auto-reset off leaves the counters alone', () async {
      SharedPreferences.setMockInitialValues({
        tasbihLastActiveDateKey: dayBefore,
        'azkar_autoReset': false,
      });

      expect(await tasbihResetDecision(twoPm), isNull);
      expect(await isTasbihDailyResetOverdue(twoPm), isFalse);
    });

    test('a day already stamped is never reset twice', () async {
      SharedPreferences.setMockInitialValues({
        tasbihLastActiveDateKey: dateKeyOf(twoPm),
      });

      expect(await tasbihResetDecision(twoPm), isNull);
      expect(await isTasbihDailyResetOverdue(twoPm), isFalse);
    });

    test('a reset boundary still ahead does not fire', () async {
      SharedPreferences.setMockInitialValues({
        tasbihLastActiveDateKey: dayBefore,
        'azkar_resetHour': 15,
      });

      expect(await tasbihResetDecision(twoPm), isNull);
      expect(await isTasbihDailyResetOverdue(twoPm), isFalse);
    });

    test('a boundary that has passed fires and carries both halves', () async {
      SharedPreferences.setMockInitialValues({
        tasbihLastActiveDateKey: dayBefore,
        'azkar_resetHour': 12,
        'azkar_resetMinute': 30,
      });

      final decision = await tasbihResetDecision(twoPm);

      expect(decision, isNotNull);
      // The reset consumes exactly these two values: the key to stamp and the
      // boundary that invalidates earlier counts. Spellings that re-derive
      // them per caller are the drift this single source closes.
      expect(decision!.today, equals(dateKeyOf(twoPm)));
      expect(decision.deadline, equals(DateTime(2026, 10, 23, 12, 30)));
      expect(await isTasbihDailyResetOverdue(twoPm), isTrue);
    });

    test('the boundary minute itself counts as passed', () async {
      SharedPreferences.setMockInitialValues({
        tasbihLastActiveDateKey: dayBefore,
        'azkar_resetHour': 14,
      });

      expect(await isTasbihDailyResetOverdue(twoPm), isTrue,
          reason: 'at the boundary the new day has begun');
    });

    test('a custom boundary is honoured, not midnight', () async {
      // The settings notifier loads `azkar_resetHour` asynchronously, so a
      // fresh read answers 0 and would zero the counters nine hours early.
      SharedPreferences.setMockInitialValues({
        tasbihLastActiveDateKey: dayBefore,
        'azkar_resetHour': 21,
      });

      expect(await isTasbihDailyResetOverdue(twoPm), isFalse);
    });
  });

  group('the provider consumes that decision', () {
    test('daily reset zeroes yesterday counts on new day (default settings)',
        () async {
      SharedPreferences.setMockInitialValues({
        tasbihLastActiveDateKey: yesterdayKey(),
      });
      await seedCount('1', 50, lifetime: 500);
      await seedCount('2', 7, lifetime: 200);

      final tasbihs = await container.read(tasbihProvider.future);

      expect(tasbihs.length, equals(2));
      for (final t in tasbihs) {
        expect(t.currentCount, equals(0), reason: 'count must reset on new day');
        expect(t.totalLifetimeCount, greaterThan(0),
            reason: 'lifetime must be preserved');
      }
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(tasbihLastActiveDateKey),
          equals(dateKeyOf(DateTime.now())));
    });

    test('after the reset the same instant is no longer overdue', () async {
      SharedPreferences.setMockInitialValues({
        tasbihLastActiveDateKey: yesterdayKey(),
      });
      await seedCount('1', 50, lifetime: 500);

      await container.read(tasbihProvider.future);

      // The round trip proves both halves agree on the key AND its format: the
      // provider stamped what the shared predicate reads.
      expect(await isTasbihDailyResetOverdue(DateTime.now()), isFalse);
      expect(await tasbihResetDecision(DateTime.now()), isNull);
    });

    test('daily reset does NOT zero when autoReset is disabled', () async {
      SharedPreferences.setMockInitialValues({
        tasbihLastActiveDateKey: yesterdayKey(),
        'azkar_autoReset': false,
      });
      await seedCount('1', 50, lifetime: 500);

      final tasbihs = await container.read(tasbihProvider.future);

      expect(tasbihs.first.currentCount, equals(50),
          reason: 'autoReset off must keep yesterday count');
    });

    test('a boundary already passed today zeroes the counts', () async {
      // Hour = now, minute = 0 — never in the future, whatever the clock says.
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        tasbihLastActiveDateKey: yesterdayKey(),
        'azkar_autoReset': true,
        'azkar_resetHour': now.hour,
        'azkar_resetMinute': 0,
      });
      await seedCount('1', 50, lifetime: 500);

      final tasbihs = await container.read(tasbihProvider.future);

      expect(tasbihs.first.currentCount, equals(0));

      // The reset must mark the app as editor at the BOUNDARY, not at the
      // instant it happened to run: a widget tap after the boundary is one of
      // today's taps and has to win the next merge instead of being discarded.
      await Future<void>(() {}); // the marker is written fire-and-forget
      final deadline = DateTime(now.year, now.month, now.day, now.hour);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt('tasbih_widget_last_changed_at'),
        equals(deadline.millisecondsSinceEpoch),
        reason: 'the marker is the reset boundary, not the execution time',
      );
    });

    test('a boundary still ahead today keeps the counts AND the stamp',
        () async {
      // minute = now.minute + 1 puts the boundary after `now` at any hour,
      // including the 23:59 wrap into the next day.
      final now = DateTime.now();
      final yesterday = yesterdayKey();
      SharedPreferences.setMockInitialValues({
        tasbihLastActiveDateKey: yesterday,
        'azkar_autoReset': true,
        'azkar_resetHour': now.hour,
        'azkar_resetMinute': now.minute + 1,
      });
      await seedCount('1', 50, lifetime: 500);

      final tasbihs = await container.read(tasbihProvider.future);

      expect(tasbihs.first.currentCount, equals(50),
          reason: 'an unreached boundary must not zero today');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(tasbihLastActiveDateKey), equals(yesterday),
          reason: 'skipping the reset must not consume the day — the boot '
              'timer re-checks it later and has to still see it as overdue');
      expect(await isTasbihDailyResetOverdue(now), isFalse,
          reason: 'the predicate and the provider must agree on the skip');
    });
  });
}
