import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/personal2/shop/data/shop_tables.dart';
import 'package:tawheeed/features/settings/services/backup_service.dart';

/// The shop tables travel in the app backup and come back intact — including
/// Persian names, immutable invoices and the ledger whose SUM is the balance.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  const pkgChannel = MethodChannel('dev.fluttercommunity.plus/package_info');
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('shop_backup_test');
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pkgChannel, (call) async {
      if (call.method == 'getAll') {
        return <String, dynamic>{
          'appName': 'توحید',
          'packageName': 'com.tawheeed',
          'version': '1.2.3',
          'buildNumber': '45',
          'buildSignature': '',
        };
      }
      return null;
    });
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pkgChannel, null);
    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        break;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
  });

  Future<File> seedShopDatabase(String fileName) async {
    final file = File(p.join(tempDir.path, fileName));
    if (file.existsSync()) file.deleteSync();
    final db = AppDatabase.withConnection(NativeDatabase(file));
    try {
      await db.customStatement('SELECT 1'); // v47 tables via onCreate
      // The settings row (what ensureSeeded does in production).
      await db.customStatement(
        'INSERT OR IGNORE INTO ${ShopTables.settings} (id) VALUES (?)',
        ['shop'],
      );
      // A product with a barcode and an opening movement.
      await db.customStatement(
        'INSERT INTO ${ShopTables.product} '
        '(id, name, normalized_name, sell_price, buy_price_last, avg_cost, '
        'track_stock, active, stock_milli_cached, created_at) '
        "VALUES ('p1', 'چای احمد', 'چای احمد', 250000, 200000, 200000, "
        "1, 1, 5000, 1700000000000)",
      );
      await db.customStatement(
        'INSERT INTO ${ShopTables.productBarcode} (product_id, barcode) '
        "VALUES ('p1', '6274123390')",
      );
      await db.customStatement(
        'INSERT INTO ${ShopTables.stockMovement} '
        "(id, product_id, date, type, qty_milli, unit_cost, created_at) "
        "VALUES ('m1', 'p1', 1700000000000, 'opening', 5000, 200000, 0)",
      );
      // A customer with a credit sale and its ledger entry.
      await db.customStatement(
        'INSERT INTO ${ShopTables.customer} '
        "(id, name, normalized_name, created_at) "
        "VALUES ('c1', 'حاج رضا', 'حاج رضا', 1700000000000)",
      );
      await db.customStatement(
        'INSERT INTO ${ShopTables.invoice} '
        "(id, number, date, kind, customer_id, subtotal, total, status, created_at) "
        "VALUES ('i1', '1', 1700000000000, 'sale', 'c1', 500000, 500000, "
        "'posted', 0)",
      );
      await db.customStatement(
        'INSERT INTO ${ShopTables.invoiceItem} '
        "(id, invoice_id, product_id, name_snapshot, unit_snapshot, "
        "qty_milli, unit_price, line_total, unit_cost_snapshot) "
        "VALUES ('it1', 'i1', 'p1', 'چای احمد', 'عدد', 2000, 250000, "
        "500000, 200000)",
      );
      await db.customStatement(
        'INSERT INTO ${ShopTables.ledgerEntry} '
        "(id, party_type, party_id, date, kind, signed_amount, ref_type, "
        "ref_id, created_at) "
        "VALUES ('le1', 'customer', 'c1', 1700000000000, 'invoice', 500000, "
        "'invoice', 'i1', 0)",
      );
    } finally {
      await db.close();
    }
    return file;
  }

  test('shop rows survive export → restore with Persian text intact',
      () async {
    await seedShopDatabase('app.sqlite');

    final archiveFile =
        await BackupService().exportBackup(directory: tempDir.path);
    final archive = ZipDecoder().decodeBytes(await archiveFile.readAsBytes());
    final dbEntry = archive.firstWhere((f) => f.name == 'app.sqlite');
    final unzipped = File(p.join(tempDir.path, 'unzipped.sqlite'))
      ..writeAsBytesSync(dbEntry.content as List<int>);

    final check = AppDatabase.withConnection(NativeDatabase(unzipped));
    try {
      await check.customStatement('SELECT 1');
      final product = await check.customSelect(
        'SELECT name FROM ${ShopTables.product} WHERE id = ?',
        variables: [const Variable<String>('p1')],
      ).get();
      expect(product.single.read<String>('name'), 'چای احمد');
      final barcode = await check.customSelect(
        'SELECT barcode FROM ${ShopTables.productBarcode} WHERE product_id = ?',
        variables: [const Variable<String>('p1')],
      ).get();
      expect(barcode.single.read<String>('barcode'), '6274123390');
    } finally {
      await check.close();
    }

    // Restore onto a fresh database.
    final target = File(p.join(tempDir.path, 'target.sqlite'));
    final fresh = AppDatabase.withConnection(NativeDatabase(target));
    try {
      await fresh.customStatement('SELECT 1');
      final outcome = await BackupService().restoreBackup(
        archiveFile.path,
        database: fresh,
      );
      expect(outcome.restoredTables, greaterThan(0));

      final invoice = await fresh.customSelect(
        'SELECT total, status FROM ${ShopTables.invoice} WHERE id = ?',
        variables: [const Variable<String>('i1')],
      ).get();
      expect(invoice.single.read<int>('total'), 500000);
      expect(invoice.single.read<String>('status'), 'posted');

      final customer = await fresh.customSelect(
        'SELECT name FROM ${ShopTables.customer} WHERE id = ?',
        variables: [const Variable<String>('c1')],
      ).get();
      expect(customer.single.read<String>('name'), 'حاج رضا');

      // The balance invariant survives the round trip: SUM(ledger) == 500000.
      final balance = await fresh.customSelect(
        'SELECT COALESCE(SUM(signed_amount), 0) AS total FROM '
        '${ShopTables.ledgerEntry} WHERE party_type = ? AND party_id = ?',
        variables: [
          const Variable<String>('customer'),
          const Variable<String>('c1'),
        ],
      ).get();
      expect(balance.single.read<int>('total'), 500000);
    } finally {
      await fresh.close();
    }
  });
}
