import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'package:tawheeed/core/database/app_database.dart';

/// Schema v42: the standalone-attachments feature was never shipped — no
/// screen ever read `attachment_table` — so the schema, its DAO/repo surface
/// and the table itself are removed. These tests pin the drop on all three
/// paths that can encounter the table: fresh install, an upgrade from a
/// database that has it (v36..v41), and one that does not (pre-v36 / fixtures).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tawheeed_v42_test');
  });

  tearDown(() async {
    // Windows can hold a just-closed sqlite file open for a while; never let
    // cleanup fail an already-green test.
    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        break;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
  });

  group('schema v42 (attachment_table dropped)', () {
    test(
        'fresh database reports the current schemaVersion and has no attachment_table',
        () async {
      final db = AppDatabase.withConnection(NativeDatabase.memory());
      try {
        final v = await db
            .customSelect('PRAGMA user_version')
            .getSingle()
            .then((r) => r.read<int>('user_version'));
        expect(v, AppDatabase.currentSchemaVersion);

        final rows = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' "
              "AND name = 'attachment_table'",
            )
            .get();
        expect(rows, isEmpty);
      } finally {
        await db.close();
      }
    });

    test('upgrade from v41 with legacy rows drops the table and keeps data',
        () async {
      final file = File(p.join(tempDir.path, 'v41.sqlite'));
      final setup = sqlite3.open(file.path);
      // The v36..v41 layout of the table (matches the v36 createTable call —
      // it never changed after introduction).
      setup.execute('''
        CREATE TABLE attachment_table (
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT NOT NULL DEFAULT '',
          file_path TEXT NOT NULL,
          mime_type TEXT NOT NULL DEFAULT '',
          size_bytes INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        )
      ''');
      // A goal that must survive the upgrade untouched.
      setup.execute('''
        CREATE TABLE goal_table (
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT NOT NULL
        )
      ''');
      setup.execute(
          "INSERT INTO attachment_table VALUES ('a1', 'old', '/x/y.png', 'image/png', 3, 1)");
      setup.execute("INSERT INTO goal_table VALUES ('g1', 'قرآن')");
      setup.execute('PRAGMA user_version = 41');
      setup.close();

      final db = AppDatabase.withConnection(NativeDatabase(file));
      try {
        final v = await db
            .customSelect('PRAGMA user_version')
            .getSingle()
            .then((r) => r.read<int>('user_version'));
        expect(v, AppDatabase.currentSchemaVersion);

        final rows = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' "
              "AND name = 'attachment_table'",
            )
            .get();
        expect(rows, isEmpty,
            reason: 'the legacy table must be dropped on upgrade');

        final goals = await db.customSelect('SELECT * FROM goal_table').get();
        expect(goals, hasLength(1),
            reason: 'sibling data must survive the drop');
      } finally {
        await db.close();
      }
    });

    test('upgrade from a pre-v36 database without the table succeeds',
        () async {
      final file = File(p.join(tempDir.path, 'v35.sqlite'));
      final setup = sqlite3.open(file.path);
      // Minimal pre-v36 fixture: the v40 goal-progress rebuild and the v41
      // goal ALTERs both probe goal tables, so they must exist here, and the
      // v37 voice-note migration ALTERs note_table (existing since v6).
      setup.execute('CREATE TABLE note_table (id TEXT NOT NULL PRIMARY KEY)');
      // goal_table in its pre-v41 shape: the v40 indexes reference the two
      // flags, the six v41 columns land via guarded ALTERs.
      setup.execute('''
        CREATE TABLE goal_table (
          id TEXT NOT NULL PRIMARY KEY,
          is_archived INTEGER NOT NULL DEFAULT 0,
          is_active INTEGER NOT NULL DEFAULT 1
        )
      ''');
      setup.execute('''
        CREATE TABLE goal_progress_table (
          id TEXT NOT NULL PRIMARY KEY,
          goal_id TEXT NOT NULL,
          date TEXT NOT NULL,
          amount INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        )
      ''');
      // The progress row's parent must exist, or the orphan sweep deletes
      // it before the v40 rebuild ever copies it.
      setup.execute("INSERT INTO goal_table (id) VALUES ('g1')");
      setup.execute(
          "INSERT INTO goal_progress_table VALUES ('gp1', 'g1', '2026-01-01', 5, 1)");
      setup.execute('PRAGMA user_version = 35');
      setup.close();

      final db = AppDatabase.withConnection(NativeDatabase(file));
      try {
        final v = await db
            .customSelect('PRAGMA user_version')
            .getSingle()
            .then((r) => r.read<int>('user_version'));
        expect(v, AppDatabase.currentSchemaVersion);

        final rows = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' "
              "AND name = 'attachment_table'",
            )
            .get();
        expect(rows, isEmpty);

        // The v40 rebuild preserved the progress rows (FK shape swap only).
        final gp =
            await db.customSelect('SELECT * FROM goal_progress_table').get();
        expect(gp, hasLength(1));
      } finally {
        await db.close();
      }
    });
  });
}
