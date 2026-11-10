import 'dart:io';

import 'package:drift/drift.dart' hide Column, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/goals/data/daos/goal_dao.dart';

/// Schema v41 (goals phase 2): the six planning columns on `goal_table` —
/// `daily_target`, `priority`, `remind_enabled`, `remind_at`, `linked_type`,
/// `linked_id` — plus the composite index that the default list ordering reads.
///
/// The upgrade is the risk, not the declaration: every install in the field is
/// on v40 with real goals in it, and `ALTER TABLE ADD COLUMN` fails outright if
/// the table has rows and the column has no default. So this file is mostly
/// about data surviving the upgrade.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tawheeed_schema_v41_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<AppDatabase> memoryDb() async =>
      AppDatabase.withConnection(NativeDatabase.memory());

  /// Rebuild `goal_table` in its v40 shape and stamp the file at 40, so the
  /// 40 → 41 migration runs for real on the next open.
  Future<void> downgradeGoalsToV40(AppDatabase db) async {
    await db.customStatement('DROP TABLE goal_table');
    await db.customStatement(
      'CREATE TABLE goal_table ('
      'id TEXT NOT NULL, title TEXT NOT NULL, description TEXT NOT NULL, '
      'category TEXT NOT NULL, start_date TEXT NOT NULL, deadline TEXT NOT NULL, '
      'target_type TEXT NOT NULL, target_number INTEGER NOT NULL, '
      'is_active INTEGER NOT NULL, is_archived INTEGER NOT NULL, '
      'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, '
      'PRIMARY KEY (id))',
    );
    await db.customStatement('DROP INDEX IF EXISTS idx_goal_table_priority');
    await db.customStatement('PRAGMA user_version = 40');
  }

  Future<void> seedV40Goal(
    AppDatabase db, {
    required String id,
    required String title,
    int target = 30,
  }) async {
    await db.customStatement(
      'INSERT INTO goal_table (id, title, description, category, start_date, '
      'deadline, target_type, target_number, is_active, is_archived, '
      'created_at, updated_at) VALUES '
      "('$id', '$title', '', 'hifz', '2026-09-01', '', 'count', $target, 1, 0, 0, 0)",
    );
  }

  Future<void> seedProgress(
      AppDatabase db, String id, String goalId, String date, int amount) async {
    await db.customStatement(
      'INSERT INTO goal_progress_table (id, goal_id, date, amount, created_at) '
      "VALUES ('$id', '$goalId', '$date', $amount, 0)",
    );
  }

  group('schema v41 columns', () {
    test('a fresh database has all six planning columns', () async {
      final db = await memoryDb();
      try {
        final rows =
            await db.customSelect('PRAGMA table_info(goal_table)').get();
        final names = rows.map((r) => r.read<String>('name')).toSet();
        expect(
          names,
          containsAll(<String>{
            'daily_target',
            'priority',
            'remind_enabled',
            'remind_at',
            'linked_type',
            'linked_id',
          }),
        );
      } finally {
        await db.close();
      }
    });

    test('the priority index exists for the default ordering', () async {
      final db = await memoryDb();
      try {
        final rows = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='index' AND "
              "name = 'idx_goal_table_priority'",
            )
            .get();
        expect(rows.map((r) => r.read<String>('name')),
            contains('idx_goal_table_priority'));
      } finally {
        await db.close();
      }
    });

    test('new columns carry the documented defaults', () async {
      final db = await memoryDb();
      try {
        final now = DateTime.now();
        await db.into(db.goalTable).insert(
              GoalTableCompanion.insert(
                id: 'g1',
                title: 'مطالعه',
                createdAt: now,
                updatedAt: now,
              ),
            );
        final g = await (db.select(db.goalTable)
              ..where((t) => t.id.equals('g1')))
            .getSingle();
        // 0 = «the user did not set one», 1 = medium, and the link columns
        // empty. Anything else would silently change how existing goals sort
        // the moment the app updates.
        expect(g.dailyTarget, 0);
        expect(g.priority, 1);
        expect(g.remindEnabled, isFalse);
        expect(g.remindAt, '');
        expect(g.linkedType, '');
        expect(g.linkedId, '');
      } finally {
        await db.close();
      }
    });
  });

  group('v40 → v41 upgrade', () {
    test('existing goals, progress and totals all survive', () async {
      final file = File(p.join(tempDir.path, 'v40_upgrade.sqlite'));

      final legacy = AppDatabase.withConnection(NativeDatabase(file));
      await downgradeGoalsToV40(legacy);
      await seedV40Goal(legacy, id: 'g1', title: 'حفظ جزء');
      await seedV40Goal(legacy, id: 'g2', title: 'مطالعه', target: 10);
      await seedProgress(legacy, 'p1', 'g1', '2026-09-01', 7);
      await seedProgress(legacy, 'p2', 'g1', '2026-09-02', 3);
      await legacy.close();

      final upgraded = AppDatabase.withConnection(NativeDatabase(file));
      try {
        final v = await upgraded
            .customSelect('PRAGMA user_version')
            .getSingle()
            .then((r) => r.read<int>('user_version'));
        expect(v, AppDatabase.currentSchemaVersion);
        expect(v, greaterThanOrEqualTo(41));

        // The rows are still there, with the v40 values untouched...
        final goals = await upgraded.select(upgraded.goalTable).get();
        expect(goals.map((g) => g.id).toSet(), {'g1', 'g2'});
        final g1 = goals.firstWhere((g) => g.id == 'g1');
        expect(g1.title, 'حفظ جزء');
        expect(g1.targetNumber, 30);
        // ...and the new columns read as their defaults, not as null.
        expect(g1.dailyTarget, 0);
        expect(g1.priority, 1);
        expect(g1.remindEnabled, isFalse);
        expect(g1.remindAt, '');
        expect(g1.linkedType, '');
        expect(g1.linkedId, '');

        // Progress is the thing a user would actually miss if the migration
        // rebuilt the table.
        final dao = GoalDao(upgraded);
        expect(await dao.goalTotal('g1'), 10);
        expect((await dao.progressByDay('g1')).keys.toList(),
            ['2026-09-01', '2026-09-02']);

        // The index the default sort depends on was created by the upgrade.
        final idx = await upgraded
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='index' AND "
              "name = 'idx_goal_table_priority'",
            )
            .get();
        expect(idx, isNotEmpty);
      } finally {
        await upgraded.close();
      }
    });

    test('the new columns are writable after the upgrade', () async {
      final file = File(p.join(tempDir.path, 'v40_write.sqlite'));

      final legacy = AppDatabase.withConnection(NativeDatabase(file));
      await downgradeGoalsToV40(legacy);
      await seedV40Goal(legacy, id: 'g1', title: 'حفظ جزء');
      await legacy.close();

      final upgraded = AppDatabase.withConnection(NativeDatabase(file));
      try {
        await (upgraded.update(upgraded.goalTable)
              ..where((t) => t.id.equals('g1')))
            .write(const GoalTableCompanion(
          dailyTarget: Value(1),
          priority: Value(2),
          remindEnabled: Value(true),
          remindAt: Value('09:00'),
          linkedType: Value('note'),
          linkedId: Value('n1'),
        ));
        final g = await (upgraded.select(upgraded.goalTable)
              ..where((t) => t.id.equals('g1')))
            .getSingle();
        expect(g.dailyTarget, 1);
        expect(g.priority, 2);
        expect(g.remindEnabled, isTrue);
        expect(g.remindAt, '09:00');
        expect(g.linkedType, 'note');
        expect(g.linkedId, 'n1');
      } finally {
        await upgraded.close();
      }
    });
  });
}
