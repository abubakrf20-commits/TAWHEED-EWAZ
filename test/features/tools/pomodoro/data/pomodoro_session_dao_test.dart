import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/tools/pomodoro/data/daos/pomodoro_session_dao.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late PomodoroSessionDao dao;

  setUp(() {
    db = AppDatabase.withConnection(NativeDatabase.memory());
    dao = PomodoroSessionDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// A stable point inside the *current local day*.
  ///
  /// Day-bucketing queries ([PomodoroSessionDao.todayMinutes] and
  /// [PomodoroSessionDao.last7DaysTotals]) re-read the real clock, so anchoring
  /// to `DateTime.now()` makes them non-deterministic: a run that starts just
  /// before midnight inserts "today" rows that belong to yesterday by the time
  /// the query executes. Local noon keeps every offset used below on the same
  /// calendar day as the query. The DAO applies no upper time bound, so a
  /// noon-anchored row still counts in the running total.
  DateTime localNoon() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 12);
  }

  test('inserts a session and lists recent ones newest-first', () async {
    final now = DateTime.now();
    await dao.insert(
        startedAt: now.subtract(const Duration(hours: 2)),
        durationMinutes: 25,
        mode: 'classic',
        focusType: 'قرآن');
    await dao.insert(
        startedAt: now.subtract(const Duration(minutes: 30)),
        durationMinutes: 5,
        mode: 'countdown',
        focusType: 'کار');

    final recent = await dao.recentSessions();
    expect(recent, hasLength(2));
    expect(recent.first.mode, 'countdown');
    expect(recent.first.durationMinutes, 5);
    expect(recent.last.focusType, 'قرآن');
  });

  test('recentSessions honours the limit', () async {
    final now = DateTime.now();
    for (var i = 0; i < 12; i++) {
      await dao.insert(
          startedAt: now.subtract(Duration(minutes: i)),
          durationMinutes: 1,
          mode: 'classic',
          focusType: 'عمومی');
    }
    expect(await dao.recentSessions(), hasLength(10));
  });

  test('todayMinutes sums only sessions started today', () async {
    final base = localNoon();
    await dao.insert(
        startedAt: base.subtract(const Duration(minutes: 10)),
        durationMinutes: 25,
        mode: 'classic',
        focusType: 'قرآن');
    await dao.insert(
        startedAt: base.subtract(const Duration(minutes: 2)),
        durationMinutes: 5,
        mode: 'classic',
        focusType: 'مطالعه');
    // دیروز نباید در مجموع امروز بیاید
    await dao.insert(
        startedAt: base.subtract(const Duration(days: 1, hours: 2)),
        durationMinutes: 25,
        mode: 'classic',
        focusType: 'قرآن');

    expect(await dao.todayMinutes(), 30);
  });

  test('last7DaysTotals buckets by local day with today last', () async {
    final base = localNoon();
    await dao.insert(
        startedAt: base,
        durationMinutes: 10,
        mode: 'classic',
        focusType: 'قرآن');
    await dao.insert(
        startedAt: base.subtract(const Duration(days: 1)),
        durationMinutes: 25,
        mode: 'classic',
        focusType: 'کار');
    await dao.insert(
        startedAt: base.subtract(const Duration(days: 6)),
        durationMinutes: 50,
        mode: 'classic',
        focusType: 'حدیث');
    // خارج از بازهٔ هفت روزه نباید دیده شود
    await dao.insert(
        startedAt: base.subtract(const Duration(days: 8)),
        durationMinutes: 99,
        mode: 'classic',
        focusType: 'عمومی');

    final totals = await dao.last7DaysTotals();
    expect(totals, hasLength(7));
    expect(totals.last, 10); // امروز
    expect(totals[5], 25); // دیروز
    expect(totals[0], 50); // ۶ روز قبل
    expect(totals.fold<int>(0, (a, b) => a + b), 85);
  });

  test('clearAll empties the history', () async {
    await dao.insert(
        startedAt: DateTime.now(),
        durationMinutes: 25,
        mode: 'classic',
        focusType: 'قرآن');
    await dao.clearAll();
    expect(await dao.recentSessions(), isEmpty);
    expect(await dao.todayMinutes(), 0);
  });
}
