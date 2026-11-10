import 'dart:io';

import 'package:drift/drift.dart' hide Column, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/goals/data/daos/goal_dao.dart';

/// Schema v40 (goals phase 1): `goal_progress_table.goal_id` becomes a real
/// foreign key with ON DELETE CASCADE, plus the `(goal_id, date)` and
/// `(is_archived, is_active)` indexes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tawheeed_schema_v40_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<AppDatabase> memoryDb() async =>
      AppDatabase.withConnection(NativeDatabase.memory());

  Future<void> seedGoal(AppDatabase db, String id) async {
    final now = DateTime.now();
    await db.into(db.goalTable).insert(
          GoalTableCompanion.insert(
            id: id,
            title: 'هدف $id',
            category: const Value('hifz'),
            targetNumber: const Value(30),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> seedProgress(
    AppDatabase db,
    String id,
    String goalId,
    String date,
  ) async {
    await db.into(db.goalProgressTable).insert(
          GoalProgressTableCompanion.insert(
            id: id,
            goalId: goalId,
            date: date,
            amount: const Value(1),
            createdAt: DateTime.now(),
          ),
        );
  }

  group('schema v40 (goals phase 1)', () {
    test('fresh database reports the current schema version', () async {
      final db = await memoryDb();
      try {
        final v = await db
            .customSelect('PRAGMA user_version')
            .getSingle()
            .then((r) => r.read<int>('user_version'));
        // Tracks the constant rather than a literal: pinning it to 40 made the
        // test fail on the next migration for a reason that says nothing about
        // v40. The `>= 40` half is what actually asserts v40 exists.
        expect(v, AppDatabase.currentSchemaVersion);
        expect(v, greaterThanOrEqualTo(40));
      } finally {
        await db.close();
      }
    });

    test('the v40 indexes exist', () async {
      final db = await memoryDb();
      try {
        final rows = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='index' AND "
              "(name = 'idx_goal_progress_goal_date' OR "
              " name = 'idx_goal_table_archived_active')",
            )
            .get();
        final names = rows.map((r) => r.read<String>('name')).toSet();
        expect(
          names,
          containsAll(<String>{
            'idx_goal_progress_goal_date',
            'idx_goal_table_archived_active',
          }),
        );
      } finally {
        await db.close();
      }
    });

    test('deleting a goal cascades to its progress rows', () async {
      final db = await memoryDb();
      try {
        await db.customStatement('PRAGMA foreign_keys = ON');
        await seedGoal(db, 'g1');
        await seedProgress(db, 'p1', 'g1', '2026-09-01');

        await (db.delete(db.goalTable)..where((g) => g.id.equals('g1'))).go();

        expect(await db.select(db.goalProgressTable).get(), isEmpty);
      } finally {
        await db.close();
      }
    });

    test('a progress row for a missing goal is rejected', () async {
      final db = await memoryDb();
      try {
        await db.customStatement('PRAGMA foreign_keys = ON');
        // No parent row. Before v40 this inserted happily and nothing in the
        // app would ever clean it up.
        await expectLater(
          seedProgress(db, 'orphan', 'no-such-goal', '2026-09-01'),
          throwsA(isA<Exception>()),
        );
      } finally {
        await db.close();
      }
    });

    test('progress rows survive an unrelated goal being deleted', () async {
      final db = await memoryDb();
      try {
        await db.customStatement('PRAGMA foreign_keys = ON');
        await seedGoal(db, 'g1');
        await seedGoal(db, 'g2');
        await seedProgress(db, 'p1', 'g1', '2026-09-01');
        await seedProgress(db, 'p2', 'g2', '2026-09-01');

        await (db.delete(db.goalTable)..where((g) => g.id.equals('g1'))).go();

        final rows = await db.select(db.goalProgressTable).get();
        expect(rows.map((r) => r.id), ['p2']);
      } finally {
        await db.close();
      }
    });
  });

  group('v39 → v40 upgrade', () {
    /// Rewind the goals tables to their v39 shape: identical columns, but
    /// `goal_id` has no foreign key. A v39 database is what every existing
    /// install is actually holding, so this is the path that has to be safe.
    Future<void> downgradeGoalsToV39(AppDatabase db) async {
      await db.customStatement('DROP TABLE goal_progress_table');
      await db.customStatement(
        'CREATE TABLE goal_progress_table ('
        'id TEXT NOT NULL, goal_id TEXT NOT NULL, date TEXT NOT NULL, '
        'amount INTEGER NOT NULL, created_at INTEGER NOT NULL, '
        'PRIMARY KEY (id))',
      );
      await db.customStatement('PRAGMA user_version = 39');
    }

    test('logged progress survives and the FK becomes enforced', () async {
      final file = File(p.join(tempDir.path, 'v39_upgrade.sqlite'));

      // Build a v39-shaped database with data in it.
      final legacy = AppDatabase.withConnection(NativeDatabase(file));
      await downgradeGoalsToV39(legacy);
      await legacy.customStatement(
        'INSERT INTO goal_table (id, title, description, category, '
        'start_date, deadline, target_type, target_number, is_active, '
        'is_archived, created_at, updated_at) VALUES '
        "('g1', 'حفظ جزء', '', 'hifz', '2026-09-01', '', 'count', 30, 1, 0, "
        '0, 0)',
      );
      await legacy.customStatement(
        'INSERT INTO goal_progress_table (id, goal_id, date, amount, '
        "created_at) VALUES ('p1', 'g1', '2026-09-01', 7, 0)",
      );
      // An orphan row from the world before the constraint existed. The
      // migration is expected to clean these up, not carry them forward.
      await legacy.customStatement(
        'INSERT INTO goal_progress_table (id, goal_id, date, amount, '
        "created_at) VALUES ('p-orphan', 'gone', '2026-09-01', 3, 0)",
      );
      await legacy.close();

      // Reopen the same file: the 39 → 40 migration now runs for real.
      final upgraded = AppDatabase.withConnection(NativeDatabase(file));
      try {
        final v = await upgraded
            .customSelect('PRAGMA user_version')
            .getSingle()
            .then((r) => r.read<int>('user_version'));
        expect(v, AppDatabase.currentSchemaVersion,
            reason: 'the upgrade must stamp the new version');
        expect(v, greaterThanOrEqualTo(40));

        // The point of the exercise: a user's logged progress is not data we
        // are free to throw away to gain a constraint.
        expect(await GoalDao(upgraded).goalTotal('g1'), 7);
        final kept = await upgraded.select(upgraded.goalProgressTable).get();
        expect(kept.map((r) => r.id), ['p1']);

        // And the constraint is now live, not merely declared.
        await upgraded.customStatement('PRAGMA foreign_keys = ON');
        await expectLater(
          seedProgress(upgraded, 'p2', 'no-such-goal', '2026-09-02'),
          throwsA(isA<Exception>()),
        );

        // The cascade works after an upgrade too.
        await seedProgress(upgraded, 'p3', 'g1', '2026-09-02');
        await (upgraded.delete(upgraded.goalTable)
              ..where((g) => g.id.equals('g1')))
            .go();
        expect(
            await upgraded.select(upgraded.goalProgressTable).get(), isEmpty);
      } finally {
        await upgraded.close();
      }
    });
  });
}
