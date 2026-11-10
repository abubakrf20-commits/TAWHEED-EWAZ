import 'package:drift/drift.dart' hide Column, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/goals/data/daos/goal_dao.dart';

void main() {
  late AppDatabase db;
  late GoalDao dao;

  setUp(() async {
    db = AppDatabase.withConnection(NativeDatabase.memory());
    // Drift runs `onCreate` through `beforeOpen`, so these are the real
    // tables, the real foreign key and the real v40 indexes — not a
    // hand-rolled schema. Stated explicitly because the cascade and the
    // orphan-rejection assertions below are only meaningful while the
    // constraint is actually being enforced.
    await db.customStatement('PRAGMA foreign_keys = ON');
    dao = GoalDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  GoalTableCompanion goalEntry(
    String id, {
    bool archived = false,
    String deadline = '',
    String targetType = 'count',
    int targetNumber = 30,
    bool active = true,
  }) {
    final now = DateTime.now();
    return GoalTableCompanion(
      id: Value(id),
      title: Value('هدف $id'),
      category: const Value('hifz'),
      startDate: const Value(''),
      deadline: Value(deadline),
      targetType: Value(targetType),
      targetNumber: Value(targetNumber),
      isActive: Value(active),
      isArchived: Value(archived),
      createdAt: Value(now),
      updatedAt: Value(now),
    );
  }

  GoalProgressTableCompanion progressEntry(
    String goalId,
    String date,
    int amount, {
    String? id,
  }) {
    return GoalProgressTableCompanion(
      // An explicit, readable id. The original used a zero-width space
      // (U+200B) to force uniqueness when (goal, date, amount) repeated —
      // invisible, and it made the whole file look broken. Callers now pass a
      // real id or let the counter suffix it.
      id: Value(id ?? '${goalId}_${date}_$amount'),
      goalId: Value(goalId),
      date: Value(date),
      amount: Value(amount),
      createdAt: Value(DateTime.now()),
    );
  }

  test('getGoals hides archived by default and shows them when asked',
      () async {
    await dao.upsertGoal(goalEntry('g1'));
    await dao.upsertGoal(goalEntry('g2', archived: true));

    final visible = await dao.getGoals();
    expect(visible, hasLength(1));
    expect(visible.single.id, 'g1');

    final all = await dao.getGoals(includeArchived: true);
    expect(all, hasLength(2));
  });

  test('deleting a goal cascades its progress rows at the database level',
      () async {
    // A real goal so the FK holds. The old version of this test inserted
    // progress for goals that never existed — it passed only BECAUSE there was
    // no foreign key, and adding the FK would have broken it.
    await dao.upsertGoal(goalEntry('g1'));
    await dao.addProgress(progressEntry('g1', '2026-09-01', 5));
    expect(await dao.progressByDay('g1'), isNotEmpty);

    await dao.deleteGoal('g1');

    expect(await dao.getGoal('g1'), isNull);
    // The cascade removed the child rows; nothing in the app layer does this.
    expect(await dao.progressByDay('g1'), isEmpty);
  });

  test('the foreign key rejects a progress row for a missing goal', () async {
    // Enforced by the schema, so the orphan path is closed at the source
    // rather than trusted to every caller.
    await expectLater(
      dao.addProgress(progressEntry('ghost', '2026-09-01', 1)),
      throwsA(isA<Exception>()),
    );
  });

  test('progressOn sums only the requested day', () async {
    await dao.upsertGoal(goalEntry('g1'));
    await dao.addProgress(progressEntry('g1', '2026-09-01', 2, id: 'a'));
    await dao.addProgress(progressEntry('g1', '2026-09-01', 3, id: 'b'));
    await dao.addProgress(progressEntry('g1', '2026-09-02', 4, id: 'c'));

    expect(await dao.progressOn('g1', '2026-09-01'), 5);
    expect(await dao.progressOn('g1', '2026-09-02'), 4);
    expect(await dao.progressOn('g1', '2026-09-03'), 0);
  });

  test('goalTotal sums every progress row of the goal', () async {
    await dao.upsertGoal(goalEntry('g1'));
    await dao.addProgress(progressEntry('g1', '2026-09-01', 10, id: 'a'));
    await dao.addProgress(progressEntry('g1', '2026-09-02', 15, id: 'b'));
    expect(await dao.goalTotal('g1'), 25);
  });

  test('goalTotal is zero for a goal with no progress', () async {
    await dao.upsertGoal(goalEntry('g1'));
    expect(await dao.goalTotal('g1'), 0);
  });

  test('totalsByGoal returns every goal in one pass', () async {
    await dao.upsertGoal(goalEntry('g1'));
    await dao.upsertGoal(goalEntry('g2'));
    await dao.addProgress(progressEntry('g1', '2026-09-01', 7, id: 'a'));
    await dao.addProgress(progressEntry('g1', '2026-09-02', 3, id: 'b'));
    await dao.addProgress(progressEntry('g2', '2026-09-01', 9, id: 'c'));

    final totals = await dao.totalsByGoal(['g1', 'g2']);
    expect(totals['g1'], 10);
    expect(totals['g2'], 9);
    // A goal with no rows is simply absent, not zero.
    await dao.upsertGoal(goalEntry('g3'));
    final withEmpty = await dao.totalsByGoal(['g1', 'g3']);
    expect(withEmpty.containsKey('g3'), isFalse);
    expect(withEmpty['g1'], 10);
  });

  test('totalsByGoal on an empty id list does no work', () async {
    expect(await dao.totalsByGoal([]), isEmpty);
  });

  test('progressByDay groups and orders oldest first', () async {
    await dao.upsertGoal(goalEntry('g1'));
    await dao.addProgress(progressEntry('g1', '2026-09-02', 4, id: 'b'));
    await dao.addProgress(progressEntry('g1', '2026-09-01', 2, id: 'a'));
    await dao.addProgress(progressEntry('g1', '2026-09-01', 3, id: 'c'));
    await dao.addProgress(progressEntry('g1', '2026-09-03', 5, id: 'd'));

    final byDay = await dao.progressByDay('g1');
    expect(byDay, {'2026-09-01': 5, '2026-09-02': 4, '2026-09-03': 5});
    expect(byDay.keys.toList(), ['2026-09-01', '2026-09-02', '2026-09-03']);
  });

  test('progressByDay honours from and to bounds', () async {
    await dao.upsertGoal(goalEntry('g1'));
    await dao.addProgress(progressEntry('g1', '2026-09-01', 1, id: 'a'));
    await dao.addProgress(progressEntry('g1', '2026-09-02', 2, id: 'b'));
    await dao.addProgress(progressEntry('g1', '2026-09-03', 3, id: 'c'));

    final window =
        await dao.progressByDay('g1', from: '2026-09-02', to: '2026-09-03');
    expect(window, {'2026-09-02': 2, '2026-09-03': 3});
  });

  group('positiveDaysByGoal', () {
    test('returns only days with a positive amount, ordered oldest first',
        () async {
      await dao.upsertGoal(goalEntry('g1'));
      await dao.addProgress(progressEntry('g1', '2026-09-03', 5, id: 'a'));
      await dao.addProgress(progressEntry('g1', '2026-09-01', 2, id: 'b'));
      await dao.addProgress(progressEntry('g1', '2026-09-02', 0, id: 'zero'));

      // The zero row is the whole point: a streak counts days with progress,
      // and a day that recorded nothing must not be listed as active.
      final days = await dao.positiveDaysByGoal(['g1']);
      expect(days['g1'], ['2026-09-01', '2026-09-03']);
    });

    test('collapses several positive rows on one day into one entry', () async {
      await dao.upsertGoal(goalEntry('g1'));
      await dao.addProgress(progressEntry('g1', '2026-09-01', 1, id: 'a'));
      await dao.addProgress(progressEntry('g1', '2026-09-01', 4, id: 'b'));
      await dao.addProgress(progressEntry('g1', '2026-09-01', 6, id: 'c'));

      final days = await dao.positiveDaysByGoal(['g1']);
      expect(days['g1'], ['2026-09-01']);
    });

    test('keeps goals separate and omits the ones with no progress', () async {
      await dao.upsertGoal(goalEntry('g1'));
      await dao.upsertGoal(goalEntry('g2'));
      await dao.upsertGoal(goalEntry('g3'));
      await dao.addProgress(progressEntry('g1', '2026-09-01', 1, id: 'a'));
      await dao.addProgress(progressEntry('g2', '2026-09-02', 1, id: 'b'));
      // g3 has no rows at all.

      final days = await dao.positiveDaysByGoal(['g1', 'g2', 'g3']);
      expect(days.keys.toSet(), {'g1', 'g2'});
      expect(days['g1'], ['2026-09-01']);
      expect(days['g2'], ['2026-09-02']);
    });

    test('an empty id list does no work', () async {
      expect(await dao.positiveDaysByGoal([]), isEmpty);
    });
  });

  group('progressEntries', () {
    test('returns the raw rows, newest day first', () async {
      await dao.upsertGoal(goalEntry('g1'));
      await dao.addProgress(progressEntry('g1', '2026-09-01', 2, id: 'a'));
      await dao.addProgress(progressEntry('g1', '2026-09-03', 5, id: 'b'));
      await dao.addProgress(progressEntry('g1', '2026-09-02', 3, id: 'c'));

      final rows = await dao.progressEntries('g1');
      // Contrast with progressByDay, which collapses each day into a sum: the
      // history needs the rows themselves to offer edit and delete.
      expect(rows.map((r) => r.id), ['b', 'c', 'a']);
      expect(rows.map((r) => r.amount), [5, 3, 2]);
    });

    test('does not mix another goal’s rows in', () async {
      await dao.upsertGoal(goalEntry('g1'));
      await dao.upsertGoal(goalEntry('g2'));
      await dao.addProgress(progressEntry('g1', '2026-09-01', 2, id: 'a'));
      await dao.addProgress(progressEntry('g2', '2026-09-01', 9, id: 'b'));

      final rows = await dao.progressEntries('g1');
      expect(rows.map((r) => r.id), ['a']);
    });

    test('respects the limit', () async {
      await dao.upsertGoal(goalEntry('g1'));
      for (var i = 0; i < 5; i++) {
        await dao.addProgress(
            progressEntry('g1', '2026-09-0${i + 1}', i + 1, id: 'p$i'));
      }
      expect((await dao.progressEntries('g1', limit: 3)).length, 3);
    });
  });

  test('addProgress is idempotent for a repeated id', () async {
    await dao.upsertGoal(goalEntry('g1'));
    await dao.addProgress(progressEntry('g1', '2026-09-01', 1, id: 'same'));
    // A bare insert threw SqliteException on the second write; upsert makes
    // the deterministic boolean id safe to write twice.
    await dao.addProgress(progressEntry('g1', '2026-09-01', 1, id: 'same'));
    expect(await dao.progressOn('g1', '2026-09-01'), 1);
  });

  test('updateProgress corrects an amount in place', () async {
    await dao.upsertGoal(goalEntry('g1'));
    await dao.addProgress(progressEntry('g1', '2026-09-01', 4, id: 'a'));
    await dao.updateProgress('a', 6);
    expect(await dao.progressOn('g1', '2026-09-01'), 6);
  });

  test('setArchived flips only the flag', () async {
    await dao.upsertGoal(goalEntry('g1'));
    final before = await dao.getGoal('g1');
    expect(before!.isArchived, isFalse);

    await dao.setArchived('g1', true);

    final after = await dao.getGoal('g1');
    expect(after!.isArchived, isTrue);
    // Everything else must survive the flip.
    expect(after.title, before.title);
    expect(after.targetNumber, before.targetNumber);
    expect(after.category, before.category);
  });

  test('active goals sort above inactive ones', () async {
    await dao.upsertGoal(goalEntry('g1', active: false));
    await dao.upsertGoal(goalEntry('g2'));
    final all = await dao.getGoals();
    expect(all.first.id, 'g2');
  });
}
