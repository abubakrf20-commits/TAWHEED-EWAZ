import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/personal/data/care_tables.dart';

const _careTables = [
  'care_asset',
  'care_task',
  'care_record',
  'care_odometer_reading',
  'care_fuel_log',
  'care_bill',
  'care_bill_payment',
  'care_warranty',
  'care_subscription',
];

/// Schema v45 — the personal-tools (خودرو / خانه) tables, added additively.
///
/// The tables are created both by `onCreate` and by `beforeOpen`, and every
/// statement is `IF NOT EXISTS`, so the upgrade path is the one that matters:
/// an install that predates the feature must gain the tables WITHOUT losing a
/// single row of anything else.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tawheeed_v45_test');
  });

  tearDown(() async {
    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        break;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
  });

  Future<Set<String>> careTablesOf(AppDatabase db) async {
    final rows = await db
        .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'care_%'")
        .get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  test('a v44 database gains every care table and keeps its rows', () async {
    final file = File(p.join(tempDir.path, 'v44.sqlite'));

    // 1. Build the current schema, then take the care tables away so the file
    //    looks exactly like the last released version.
    final build = AppDatabase.withConnection(NativeDatabase(file));
    await build.select(build.appSettingsTable).get();
    await build.close();

    final raw = sqlite3.open(file.path);
    for (final table in _careTables) {
      raw.execute('DROP TABLE IF EXISTS "$table"');
    }
    raw.execute(
        'CREATE TABLE legacy_marker (id TEXT NOT NULL PRIMARY KEY)');
    raw.execute("INSERT INTO legacy_marker (id) VALUES ('kept')");
    raw.execute('PRAGMA user_version = 44');
    raw.close();

    // 2. Reopen: the upgrade runs and the tables come back.
    final db = AppDatabase.withConnection(NativeDatabase(file));
    try {
      expect(await careTablesOf(db), containsAll(_careTables));

      final version = await db
          .customSelect('PRAGMA user_version')
          .getSingle()
          .then((r) => r.read<int>('user_version'));
      expect(version, AppDatabase.currentSchemaVersion);

      // A row that existed before the upgrade is still there: the migration
      // adds tables and never rebuilds the file.
      final marker =
          await db.customSelect('SELECT id FROM legacy_marker').get();
      expect(marker.single.read<String>('id'), 'kept');
      expect(await db.select(db.appSettingsTable).get(), isEmpty,
          reason: 'the settings table itself is untouched');
    } finally {
      await db.close();
    }
  });

  test('the migration is retryable: a second open does not fail', () async {
    final file = File(p.join(tempDir.path, 'retry.sqlite'));
    final first = AppDatabase.withConnection(NativeDatabase(file));
    await first.select(first.appSettingsTable).get();
    await first.close();

    final raw = sqlite3.open(file.path);
    raw.execute('PRAGMA user_version = 44');
    // Half-finished migration: only the first table exists.
    raw.execute('DROP TABLE IF EXISTS care_task');
    raw.execute('DROP TABLE IF EXISTS care_record');
    raw.close();

    final db = AppDatabase.withConnection(NativeDatabase(file));
    try {
      expect(await careTablesOf(db), containsAll(_careTables));
    } finally {
      await db.close();
    }
  });

  test('every care table exists on a fresh install with the expected keys',
      () async {
    final db = AppDatabase.withConnection(NativeDatabase.memory());
    try {
      expect(await careTablesOf(db), containsAll(_careTables));

      Future<Set<String>> columnsOf(String table) async {
        final rows =
            await db.customSelect('PRAGMA table_info("$table")').get();
        return rows.map((r) => r.read<String>('name')).toSet();
      }

      expect(await columnsOf('care_asset'),
          containsAll(['id', 'kind', 'name', 'meta', 'archived', 'created_at']));
      expect(
          await columnsOf('care_task'),
          containsAll([
            'id',
            'asset_id',
            'title',
            'template_key',
            'schedule_type',
            'interval_days',
            'interval_km',
            'window_start_month',
            'last_done_date',
            'last_done_km',
            'remind_before_days',
            'active',
          ]));
      expect(await columnsOf('care_bill_payment'),
          containsAll(['id', 'bill_id', 'period_key', 'paid_date', 'amount']));
      expect(await columnsOf('care_warranty'),
          containsAll(['id', 'asset_id', 'expiry_date', 'receipt_paths']));
      expect(await columnsOf('care_subscription'),
          containsAll(['id', 'name', 'amount', 'period', 'next_charge_date']));
    } finally {
      await db.close();
    }
  });

  test('the shipped DDL is idempotent', () async {
    final db = AppDatabase.withConnection(NativeDatabase.memory());
    try {
      for (final stmt in CareTables.createStatements) {
        await db.customStatement(stmt);
      }
      expect(await careTablesOf(db), containsAll(_careTables));
    } finally {
      await db.close();
    }
  });

  test('the care tables survive a wipe/restore round trip', () async {
    // Backup is a whole-file snapshot (`VACUUM INTO`), so every care table
    // travels with it; this pins the assumption that the tables live in the
    // app database rather than in a side file.
    final source = File(p.join(tempDir.path, 'source.sqlite'));
    final db = AppDatabase.withConnection(NativeDatabase(source));
    await db.customStatement(
        'INSERT INTO care_asset (id, kind, name, meta, archived, created_at) '
        "VALUES ('a1', 'car', 'پژو', '{}', 0, '2025-04-01')");
    final copy = File(p.join(tempDir.path, 'copy.sqlite'));
    await db.customStatement('VACUUM INTO ?', [copy.path]);
    await db.close();

    final restored = AppDatabase.withConnection(NativeDatabase(copy));
    try {
      final rows =
          await restored.customSelect('SELECT id FROM care_asset').get();
      expect(rows.single.read<String>('id'), 'a1');
    } finally {
      await restored.close();
    }
  });
}
