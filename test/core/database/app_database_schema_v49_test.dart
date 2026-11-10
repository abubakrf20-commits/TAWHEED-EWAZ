import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/personal/family_faith/data/family_faith_tables.dart';
import 'package:tawheeed/features/personal/finance/finance_tables.dart';

/// v49 — the stage-3 family tools' tables (صله رحم، قلک، قضایار) plus the
/// «دفتر مالی» ledger and its local-unit overrides.
///
/// The screens and their repositories arrived in this line before their DDL
/// did, so a build could run the pages against a database with no `relative`
/// or `finance_obligation` table at all. This pins what the step must
/// guarantee: a fresh database carries both families, an upgrade from any
/// released version reaches the same shape, and re-running the migration is a
/// no-op (which is what makes a half-finished upgrade retryable).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tawheeed_v49_test');
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

  const familyTables = {
    'relative',
    'relative_contact',
    'savings_goal',
    'savings_deposit',
  };

  const financeTables = [
    'finance_plan',
    'finance_obligation',
    'finance_person',
    'finance_debt_entry',
    'finance_debt_payment',
    'unit_local_override',
  ];

  Future<Set<String>> tableNames(AppDatabase db) async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    return {for (final r in rows) r.read<String>('name')};
  }

  Future<Set<String>> financeTablesOf(AppDatabase db) async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='table' "
            "AND (name LIKE 'finance_%' OR name = 'unit_local_override')")
        .get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  test('v49 is on the ladder and a fresh database has both families',
      () async {
    // The ladder only grows, so a later step must not make this red; the
    // tables themselves are permanent.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(49));
    final file = File(p.join(tempDir.path, 'fresh.sqlite'));
    final db = AppDatabase.withConnection(NativeDatabase(file));
    addTearDown(db.close);

    // Opening runs onCreate, which is where a fresh install gets its DDL.
    await db.customSelect('SELECT 1').get();
    expect(await tableNames(db), containsAll(familyTables));
    expect(await tableNames(db), containsAll(financeTables));
  });

  test('the migration SQL is idempotent, so a half-finished upgrade retries',
      () async {
    final file = File(p.join(tempDir.path, 'retry.sqlite'));
    final db = AppDatabase.withConnection(NativeDatabase(file));
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    // The upgrade path runs these exact statements; running them twice must
    // not throw (they are all IF NOT EXISTS) and must not lose a row.
    for (var pass = 0; pass < 2; pass++) {
      for (final stmt in FamilyFaithTables.createStatements) {
        await db.customStatement(stmt);
      }
      for (final stmt in FamilyFaithTables.indexStatements) {
        await db.customStatement(stmt);
      }
      for (final stmt in FinanceTables.createStatements) {
        await db.customStatement(stmt);
      }
      for (final stmt in FinanceTables.indexStatements) {
        await db.customStatement(stmt);
      }
    }

    await db.customStatement(
        "INSERT INTO relative (id, name, relation_key, created_at) "
        "VALUES ('r1', 'عمه', 'aunt', '2026-11-04')");
    final rows = await db.customSelect('SELECT name FROM relative').get();
    expect(rows.map((r) => r.read<String>('name')), ['عمه']);
    expect(await tableNames(db), containsAll(familyTables));
    expect(await tableNames(db), containsAll(financeTables));
  });

  test('every finance table has the columns its queries read', () async {
    final db = AppDatabase.withConnection(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await financeTablesOf(db), containsAll(financeTables));

    Future<Set<String>> columnsOf(String table) async {
      final rows = await db.customSelect('PRAGMA table_info("$table")').get();
      return rows.map((r) => r.read<String>('name')).toSet();
    }

    expect(
        await columnsOf('finance_obligation'),
        containsAll([
          'id',
          'kind',
          'direction',
          'title',
          'counterparty',
          'amount',
          'paid_amount',
          'due_date',
          'plan_id',
          'paid_date',
          'remind_before_days',
          'status',
          'attachment_paths',
        ]));
    expect(
        await columnsOf('finance_debt_entry'),
        containsAll([
          'id',
          'person_id',
          'direction',
          'amount',
          'created_date',
          'closed',
        ]));
    expect(await columnsOf('unit_local_override'),
        containsAll(['id', 'name', 'category', 'factor', 'base_unit']));
  });

  test('a v45 database gains the ledger tables and keeps its rows', () async {
    final file = File(p.join(tempDir.path, 'v45.sqlite'));

    final build = AppDatabase.withConnection(NativeDatabase(file));
    await build.select(build.appSettingsTable).get();
    await build.close();

    final raw = sqlite3.open(file.path);
    for (final table in financeTables) {
      raw.execute('DROP TABLE IF EXISTS "$table"');
    }
    raw.execute('CREATE TABLE legacy_marker (id TEXT NOT NULL PRIMARY KEY)');
    raw.execute("INSERT INTO legacy_marker (id) VALUES ('kept')");
    raw.execute('PRAGMA user_version = 45');
    raw.close();

    final db = AppDatabase.withConnection(NativeDatabase(file));
    try {
      expect(await financeTablesOf(db), containsAll(financeTables));

      final version = await db
          .customSelect('PRAGMA user_version')
          .getSingle()
          .then((r) => r.read<int>('user_version'));
      expect(version, AppDatabase.currentSchemaVersion);

      final marker =
          await db.customSelect('SELECT id FROM legacy_marker').get();
      expect(marker.single.read<String>('id'), 'kept');
    } finally {
      await db.close();
    }
  });

  test('the ledger rows survive a backup round trip', () async {
    final source = File(p.join(tempDir.path, 'source.sqlite'));
    final db = AppDatabase.withConnection(NativeDatabase(source));
    await db.customStatement(
        'INSERT INTO finance_obligation (id, kind, direction, title, amount, '
        'due_date, created_at) '
        "VALUES ('o1', 'cheque', 'pay', 'چک', 12000000, '2026-10-08', "
        "'2026-09-01')");
    await db.customStatement(
        'INSERT INTO unit_local_override '
        '(id, name, category, factor, base_unit, created_at) '
        "VALUES ('man_tabriz', 'من (تبریز)', 'local', 3000.0, 'g', "
        "'2026-10-01')");

    final copy = File(p.join(tempDir.path, 'copy.sqlite'));
    await db.customStatement('VACUUM INTO ?', [copy.path]);
    await db.close();

    final restored = AppDatabase.withConnection(NativeDatabase(copy));
    try {
      final obligation = await restored
          .customSelect('SELECT title, amount FROM finance_obligation')
          .get();
      expect(obligation.single.read<String>('title'), 'چک');
      expect(obligation.single.read<double>('amount'), 12000000.0);

      final override = await restored
          .customSelect('SELECT factor FROM unit_local_override')
          .get();
      expect(override.single.read<double>('factor'), 3000.0);
    } finally {
      await restored.close();
    }
  });
}
