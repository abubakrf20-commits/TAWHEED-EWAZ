import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/personal2/data/personal2_tables.dart';

/// v46 — the personal-tools set 2 tables.
///
/// Two things are pinned here:
///  • a fresh install has every table the feature's code reads;
///  • an upgrade from any released version reaches the same shape, by
///    pretending the database is at that version and opening it again.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tawheeed_v46_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<AppDatabase> openDb(String name) {
    final file = File(p.join(tempDir.path, name));
    if (file.existsSync()) file.deleteSync();
    return Future.value(AppDatabase.withConnection(NativeDatabase(file)));
  }

  Future<Set<String>> tableNames(AppDatabase db) async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    return {for (final r in rows) r.read<String>('name')};
  }

  test('schemaVersion is at least 46 (v46 tables are permanent)', () async {
    final db = await openDb('v46.sqlite');
    try {
      // v47/v48/v49 added tables on top; the version only grows. The v46
      // personal2 tables are permanent, so pin their presence, not the number.
      expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(46));
      expect(db.schemaVersion, AppDatabase.currentSchemaVersion);
    } finally {
      await db.close();
    }
  });

  test('a fresh database has every personal2 table', () async {
    final db = await openDb('fresh.sqlite');
    try {
      await db.customStatement('SELECT 1'); // force onCreate
      final names = await tableNames(db);
      for (final table in Personal2Tables.allTables) {
        expect(names, contains(table), reason: 'missing $table');
      }
    } finally {
      await db.close();
    }
  });

  test('the indexes that make the hot queries fast exist', () async {
    final db = await openDb('indexes.sqlite');
    try {
      await db.customStatement('SELECT 1');
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name LIKE 'idx_p2_%'",
          )
          .get();
      final names = {for (final r in rows) r.read<String>('name')};
      expect(names, contains('idx_p2_kid_log_kid_date'));
      expect(names, contains('idx_p2_lesson_student_date'));
      expect(names, contains('idx_p2_attendance_once'));
      // The log dedupe index is load-bearing: without it a prayer could be
      // marked twice in one day.
      expect(names, contains('idx_p2_kid_log_once'));
      // And the reward ledger's idempotency guard.
      expect(names, contains('idx_p2_kid_star_txn_ref'));
    } finally {
      await db.close();
    }
  });

  test('a v45 database keeps its data and gains every personal2 table',
      () async {
    // Built the way the repo's other upgrade tests do it: the PREVIOUS schema
    // is recreated with raw sqlite3 plus real user rows, user_version is set to
    // 45, and the CURRENT build opens it. That is the only honest way to run
    // the ladder — reopening a current-schema file with a rewound
    // user_version would replay `addColumn` steps against columns that
    // already exist and fail for a reason no real device can hit.
    final file = File(p.join(tempDir.path, 'v45.sqlite'));
    final old = sqlite3.open(file.path);
    try {
      // The minimum of v45 that the upgrade path touches, with real data.
      old.execute('''
        CREATE TABLE app_settings_table (
          id TEXT NOT NULL PRIMARY KEY,
          calculation_method INTEGER NOT NULL,
          asr_method INTEGER NOT NULL,
          use_location INTEGER NOT NULL,
          has_location INTEGER NOT NULL,
          friday_prayer_time TEXT,
          quran_theme_mode TEXT NOT NULL DEFAULT 'light'
        );
        INSERT INTO app_settings_table
          (id, calculation_method, asr_method, use_location, has_location)
          VALUES ('app', 1, 0, 0, 0);
      ''');
      // A v45 personal-care row, to prove an upgrade does not disturb the
      // neighbouring feature's data.
      old.execute('''
        CREATE TABLE care_asset (
          id TEXT NOT NULL PRIMARY KEY, kind TEXT NOT NULL, name TEXT NOT NULL,
          meta TEXT NOT NULL DEFAULT '{}', archived INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        );
        INSERT INTO care_asset (id, kind, name, created_at)
          VALUES ('a1', 'car', 'پراید', 1700000000000);
      ''');
      old.execute('PRAGMA user_version = 45;');
    } finally {
      old.dispose();
    }

    final db = AppDatabase.withConnection(NativeDatabase(file));
    try {
      await db.customStatement('SELECT 1'); // runs the upgrade ladder
      // The version grew past 46 (v47-v49 added more tools' tables); the
      // v46 tables are permanent so their presence is what the test pins.
      expect(db.schemaVersion, greaterThanOrEqualTo(46));

      final names = await tableNames(db);
      for (final table in Personal2Tables.allTables) {
        expect(names, contains(table), reason: 'missing $table');
      }

      // The existing data survived.
      final asset = await db
          .customSelect('SELECT name FROM care_asset WHERE id = ?',
              variables: [Variable.withString('a1')])
          .get();
      expect(asset.single.read<String>('name'), 'پراید');

      // And the new tables are usable immediately.
      await db.customStatement(
        'INSERT INTO ${Personal2Tables.kid} '
        "(id, name, color_key, created_at, archived) "
        "VALUES ('k1', 'سارا', 'orange', 0, 0)",
      );
      final kid = await db.customSelect('SELECT name FROM p2_kid').get();
      expect(kid.single.read<String>('name'), 'سارا');
    } finally {
      await db.close();
    }
  });

  test('the log dedupe index really refuses a second identical mark', () async {
    final db = await openDb('dedupe.sqlite');
    try {
      await db.customStatement('SELECT 1');
      Future<void> insert(String dedupe) => db.customStatement(
            'INSERT INTO ${Personal2Tables.kidLog} '
            '(id, kid_id, day_key, date, dedupe_key, status, stars, late, created_at) '
            "VALUES (?, 'k1', 'd1', 0, ?, 'approved', 2, 0, 0)",
            ['id_$dedupe', dedupe],
          );
      await insert('k1|d1||fajr');
      await expectLater(insert('k1|d1||fajr'), throwsA(anything));
    } finally {
      await db.close();
    }
  });

  test('the star ledger refuses two rows for the same reward request', () async {
    final db = await openDb('ledger.sqlite');
    try {
      await db.customStatement('SELECT 1');
      Future<void> insert(String id) => db.customStatement(
            'INSERT INTO ${Personal2Tables.kidStarTxn} '
            '(id, kid_id, day_key, date, delta, reason, ref_id, note, created_at) '
            "VALUES (?, 'k1', 'd1', 0, -10, 'reward', 'req1', '', 0)",
            [id],
          );
      await insert('txn_a');
      await expectLater(insert('txn_b'), throwsA(anything));
    } finally {
      await db.close();
    }
  });

  test('every personal2 table is reachable by the backup export query', () async {
    // BackupService enumerates sqlite_master, so the only thing worth pinning
    // is that no personal2 table is a virtual/system table it would skip, and
    // that the names contain no quote (the export interpolates them).
    for (final table in Personal2Tables.allTables) {
      expect(table.contains('"'), isFalse);
      expect(RegExp(r'^[A-Za-z0-9_]+$').hasMatch(table), isTrue,
          reason: '$table would not survive the backup name filter');
    }
  });
}
