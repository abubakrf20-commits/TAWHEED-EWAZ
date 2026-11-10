import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/personal2/shop/data/shop_tables.dart';

/// v47 — the shop core's schema: fresh installs and the real 46→current
/// upgrade, plus the indexes the performance budget depends on and the backup
/// name filter.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tawheeed_v47_test');
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

  test('a fresh database is on the current schema and has every shop table',
      () async {
    // The shop tables landed at v47; the schema has moved on since (v49 adds
    // the ledger and the family tools), so the assertion follows the ladder
    // instead of pinning the number the shop tables happened to arrive with.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(47));
    final file = File(p.join(tempDir.path, 'fresh.sqlite'));
    final db = AppDatabase.withConnection(NativeDatabase(file));
    try {
      await db.customStatement('SELECT 1');
      expect(db.schemaVersion, AppDatabase.currentSchemaVersion);
      final names = await tableNames(db);
      for (final table in ShopTables.allTables) {
        expect(names, contains(table), reason: 'missing $table');
      }
    } finally {
      await db.close();
    }
  });

  test('the indexes the budget depends on exist', () async {
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
      // The hot paths per the brief: barcode, normalizedName,
      // productId/date, customerId/date, invoice number/date.
      expect(names, contains('idx_p2_shop_barcode_product'));
      expect(names, contains('idx_p2_shop_product_name'));
      expect(names, contains('idx_p2_shop_move_product_date'));
      expect(names, contains('idx_p2_shop_ledger_party_date'));
      expect(names, contains('idx_p2_shop_invoice_number'));
      expect(names, contains('idx_p2_shop_invoice_date'));
      expect(names, contains('idx_p2_shop_invoice_customer'));
    } finally {
      await db.close();
    }
  });

  test('a v46 database keeps its data and gains every shop table', () async {
    final file = File(p.join(tempDir.path, 'v46.sqlite'));
    final old = sqlite3.open(file.path);
    try {
      // The previous schema's minimum, with live rows the upgrade must keep.
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
        CREATE TABLE p2_kid (
          id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, birth_year INTEGER,
          color_key TEXT NOT NULL DEFAULT 'orange', created_at INTEGER NOT NULL,
          archived INTEGER NOT NULL DEFAULT 0
        );
        INSERT INTO p2_kid (id, name, created_at)
          VALUES ('k1', 'سارا', 1700000000000);
      ''');
      old.execute('PRAGMA user_version = 46;');
    } finally {
      old.dispose();
    }

    final db = AppDatabase.withConnection(NativeDatabase(file));
    try {
      await db.customStatement('SELECT 1'); // runs the 46 → current ladder
      expect(db.schemaVersion, AppDatabase.currentSchemaVersion);

      final names = await tableNames(db);
      for (final table in ShopTables.allTables) {
        expect(names, contains(table), reason: 'missing $table');
      }

      // The v46 stage's data survived untouched.
      final kid = await db.customSelect(
        'SELECT name FROM p2_kid WHERE id = ?',
        variables: [const Variable<String>('k1')],
      ).get();
      expect(kid.single.read<String>('name'), 'سارا');

      // And the shop tables are immediately usable.
      await db.customStatement(
        "INSERT INTO p2_shop_product (id, name, normalized_name, sell_price, "
        "created_at) VALUES ('p1', 'چای', 'چای', 50000, 0)",
      );
      final product = await db.customSelect(
        'SELECT name FROM p2_shop_product WHERE id = ?',
        variables: [const Variable<String>('p1')],
      ).get();
      expect(product.single.read<String>('name'), 'چای');
    } finally {
      await db.close();
    }
  });

  test('money and quantity columns are INTEGER, never REAL', () {
    // The accounting rule: no floating point for money or quantity. Reading
    // the CREATE statements is the honest check — a REAL column would compile
    // and only bite at runtime.
    final sql = ShopTables.createStatements.join('\n');
    for (final column in [
      'sell_price',
      'buy_price_last',
      'avg_cost',
      'unit_cost',
      'qty_milli',
      'subtotal',
      'discount_total',
      'rounding_adj',
      'total',
      'line_total',
      'unit_price',
      'amount',
      'signed_amount',
      'credit_limit',
      'min_stock_milli',
      'stock_milli_cached',
    ]) {
      for (final match in RegExp('$column [A-Z]+').allMatches(sql)) {
        expect(match.group(0), contains('INTEGER'),
            reason: '$column must be INTEGER (got "${match.group(0)}")');
      }
    }
  });

  test('every shop table name survives the backup name filter', () {
    for (final table in ShopTables.allTables) {
      expect(table.contains('"'), isFalse);
      expect(RegExp(r'^[A-Za-z0-9_]+$').hasMatch(table), isTrue,
          reason: '$table would never be backed up');
    }
  });
}
