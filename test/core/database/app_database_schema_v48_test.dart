import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/personal2/shop/data/shop3_tables.dart';

/// v48 — the stage-3 tables: fresh shape, the real 47→48 upgrade with live
/// rows, INTEGER money, and the backup name filter.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tawheeed_v48_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<Set<String>> tableNames(AppDatabase db) async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    return {for (final r in rows) r.read<String>('name')};
  }

  test('schemaVersion is at least 48 and a fresh database has every shop stage-3 table',
      () async {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(48));
    final file = File(p.join(tempDir.path, 'fresh.sqlite'));
    final db = AppDatabase.withConnection(NativeDatabase(file));
    try {
      await db.customStatement('SELECT 1');
      final names = await tableNames(db);
      for (final table in Shop3Tables.allTables) {
        expect(names, contains(table), reason: 'missing $table');
      }
    } finally {
      await db.close();
    }
  });

  test('the stage-3 hot indexes exist', () async {
    final file = File(p.join(tempDir.path, 'idx.sqlite'));
    final db = AppDatabase.withConnection(NativeDatabase(file));
    try {
      await db.customStatement('SELECT 1');
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name LIKE 'idx_p2_shop_%'",
          )
          .get();
      final names = {for (final r in rows) r.read<String>('name')};
      expect(names, contains('idx_p2_shop_purchase_number'));
      expect(names, contains('idx_p2_shop_purchase_date'));
      expect(names, contains('idx_p2_shop_purchase_supplier'));
      expect(names, contains('idx_p2_shop_pitem_product'));
      expect(names, contains('idx_p2_shop_expense_date'));
      expect(names, contains('idx_p2_shop_cheque_due'));
      expect(names, contains('idx_p2_shop_cash_day_date'));
      expect(names, contains('idx_p2_shop_supplier_name'));
    } finally {
      await db.close();
    }
  });

  test('a v47 database keeps its rows and gains every stage-3 table',
      () async {
    final file = File(p.join(tempDir.path, 'v47.sqlite'));
    final old = sqlite3.open(file.path);
    try {
      old.execute('''
        CREATE TABLE app_settings_table (
          id TEXT NOT NULL PRIMARY KEY,
          calculation_method INTEGER NOT NULL,
          asr_method INTEGER NOT NULL,
          use_location INTEGER NOT NULL,
          has_location INTEGER NOT NULL
        );
        INSERT INTO app_settings_table
          (id, calculation_method, asr_method, use_location, has_location)
          VALUES ('app', 1, 0, 0, 0);
        CREATE TABLE p2_shop_product (
          id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL,
          normalized_name TEXT NOT NULL, category_id INTEGER, unit_id INTEGER,
          sell_price INTEGER NOT NULL DEFAULT 0,
          buy_price_last INTEGER NOT NULL DEFAULT 0,
          avg_cost INTEGER NOT NULL DEFAULT 0, min_stock_milli INTEGER,
          track_stock INTEGER NOT NULL DEFAULT 1,
          active INTEGER NOT NULL DEFAULT 1, note TEXT NOT NULL DEFAULT '',
          stock_milli_cached INTEGER NOT NULL DEFAULT 0,
          is_favorite INTEGER NOT NULL DEFAULT 0, last_sold_at INTEGER,
          created_at INTEGER NOT NULL
        );
        INSERT INTO p2_shop_product (id, name, normalized_name, created_at)
          VALUES ('p1', 'چای', 'چای', 1700000000000);
      ''');
      old.execute('PRAGMA user_version = 47;');
    } finally {
      old.dispose();
    }

    final db = AppDatabase.withConnection(NativeDatabase(file));
    try {
      await db.customStatement('SELECT 1'); // runs 47 → 48 (and on to 49)
      expect(db.schemaVersion, greaterThanOrEqualTo(48));
      final names = await tableNames(db);
      for (final table in Shop3Tables.allTables) {
        expect(names, contains(table), reason: 'missing $table');
      }
      // The v47 row survived.
      final product = await db.customSelect(
        'SELECT name FROM p2_shop_product WHERE id = ?',
        variables: [const Variable<String>('p1')],
      ).get();
      expect(product.single.read<String>('name'), 'چای');
    } finally {
      await db.close();
    }
  });

  test('money and quantity columns are INTEGER, never REAL (stage 3)', () {
    final sql = Shop3Tables.createStatements.join('\n');
    for (final column in [
      'unit_cost',
      'qty_milli',
      'line_total',
      'allocated_extra',
      'landed_unit_cost',
      'prev_avg_cost',
      'new_avg_cost',
      'subtotal',
      'discount_total',
      'extra_cost_total',
      'total',
      'paid',
      'amount',
      'opening_cash',
      'counted_cash',
      'expected_cash',
      'difference',
      'value_impact',
      'system_qty_milli',
      'counted_qty_milli',
    ]) {
      for (final match in RegExp('$column [A-Z]+').allMatches(sql)) {
        expect(match.group(0), contains('INTEGER'),
            reason: '$column must be INTEGER (got "${match.group(0)}")');
      }
    }
  });

  test('every stage-3 table name survives the backup name filter', () {
    for (final table in Shop3Tables.allTables) {
      expect(RegExp(r'^[A-Za-z0-9_]+$').hasMatch(table), isTrue,
          reason: '$table would never be backed up');
    }
  });
}
