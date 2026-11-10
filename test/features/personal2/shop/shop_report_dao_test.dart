import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/personal2/shop/data/shop3_dao.dart';
import 'package:tawheeed/features/personal2/shop/data/shop3_tables.dart';
import 'package:tawheeed/features/personal2/shop/data/shop_dao.dart';
import 'package:tawheeed/features/personal2/shop/data/shop_tables.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_domain.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_report_range.dart';
import 'package:tawheeed/features/personal2/shop/services/shop_export.dart';

/// The report only reads, so these tests write the rows a posted invoice leaves
/// behind — explicit dates make the windows deterministic (posting always uses
/// "now"). Every assertion is an exact integer: the report is an accounting
/// view, and a rounded total is a wrong total.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase db;
  late ShopDao dao;
  late Shop3Dao dao3;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('shop_report_test');
    final file = File(p.join(tempDir.path, 'shop.sqlite'));
    db = AppDatabase.withConnection(NativeDatabase(file));
    dao = ShopDao(db);
    dao3 = Shop3Dao(db, dao);
    SharedPreferences.setMockInitialValues({});
    await db.customStatement('SELECT 1');
    await dao.ensureSeeded();
  });

  tearDown(() async {
    await db.close();
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows keeps sqlite handles briefly; the OS reclaims the temp dir.
    }
  });

  int ms(DateTime d) => d.millisecondsSinceEpoch;

  Future<void> product(
    String id, {
    String? name,
    int stock = 0,
    int avgCost = 0,
    int? lastSoldAtMs,
    bool track = true,
    bool active = true,
  }) =>
      db.customStatement(
        'INSERT INTO ${ShopTables.product} (id, name, normalized_name, '
        'sell_price, avg_cost, track_stock, active, stock_milli_cached, '
        'last_sold_at, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          id,
          name ?? 'کالا $id',
          name ?? 'کالا $id',
          1000,
          avgCost,
          track ? 1 : 0,
          active ? 1 : 0,
          stock,
          lastSoldAtMs,
          ms(DateTime(2026, 1, 1)),
        ],
      );

  Future<void> invoice(
    String id, {
    required DateTime date,
    int total = 0,
    int discount = 0,
    String kind = 'sale',
    String status = 'posted',
  }) =>
      db.customStatement(
        'INSERT INTO ${ShopTables.invoice} (id, number, date, kind, subtotal, '
        'discount_total, rounding_adj, total, status, note, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?, \'\', ?)',
        [
          id,
          id.toUpperCase(),
          ms(date),
          kind,
          total + discount,
          discount,
          total,
          status,
          ms(date),
        ],
      );

  Future<void> item(
    String invoiceId, {
    required String name,
    int qtyMilli = 1000,
    int unitPrice = 1000,
    int unitCost = 0,
    int? lineTotal,
  }) =>
      db.customStatement(
        'INSERT INTO ${ShopTables.invoiceItem} (id, invoice_id, product_id, '
        'name_snapshot, unit_snapshot, qty_milli, unit_price, discount, '
        'line_total, unit_cost_snapshot) VALUES (?, ?, NULL, ?, \'عدد\', ?, ?, '
        '0, ?, ?)',
        [
          '${invoiceId}_$name',
          invoiceId,
          name,
          qtyMilli,
          unitPrice,
          lineTotal ?? (qtyMilli * unitPrice ~/ 1000),
          unitCost,
        ],
      );

  Future<void> payment(
    String invoiceId, {
    required DateTime date,
    required int amount,
    String method = 'cash',
  }) =>
      db.customStatement(
        'INSERT INTO ${ShopTables.payment} (id, date, direction, method, '
        'amount, party_type, invoice_id, note, created_at) '
        'VALUES (?, ?, \'in\', ?, ?, \'customer\', ?, \'\', ?)',
        [
          'pay_$invoiceId',
          ms(date),
          method,
          amount,
          invoiceId,
          ms(date),
        ],
      );

  Future<void> expense(DateTime date, int amount) =>
      db.customStatement(
        'INSERT INTO ${Shop3Tables.expense} (id, date, amount, method, payee, '
        'note, created_at) VALUES (?, ?, ?, \'cash\', \'\', \'\', ?)',
        ['exp_${ms(date)}_$amount', ms(date), amount, ms(date)],
      );

  /// A window of 1..5 October 2026, and its previous window (26..30 Sep).
  final range = ShopReportRange(
    from: DateTime(2026, 10, 1),
    to: DateTime(2026, 10, 5),
  );

  test('figures are the accounting view of the window', () async {
    await invoice('s1', date: DateTime(2026, 10, 1), total: 90000);
    await item('s1',
        name: 'روغن', qtyMilli: 2000, unitPrice: 50000, unitCost: 40000);
    await payment('s1', date: DateTime(2026, 10, 1), amount: 90000);

    await invoice('s2',
        date: DateTime(2026, 10, 4), total: 50000, discount: 5000);
    await item('s2',
        name: 'فیلتر', qtyMilli: 1000, unitPrice: 55000, unitCost: 30000);

    // A return inside the same window, and one outside it.
    await invoice('r1',
        date: DateTime(2026, 10, 5), total: 10000, kind: 'sale_return');
    await invoice('r0',
        date: DateTime(2026, 9, 20), total: 7000, kind: 'sale_return');

    // A voided invoice must not reach a single number.
    await invoice('v1',
        date: DateTime(2026, 10, 2), total: 999999, status: 'void');
    await item('v1', name: 'باطل', qtyMilli: 1000, unitPrice: 999999);

    // An expense inside the window, and one outside it.
    await expense(DateTime(2026, 10, 3), 15000);
    await expense(DateTime(2026, 9, 29), 8000);

    final report = await dao3.periodReport(range);
    expect(report, isNotNull);
    final figures = report!.figures;

    // gross = 90,000 + 50,000; returns = 10,000; discount = 5,000
    expect(figures.grossSales, 140000);
    expect(figures.returnTotal, 10000);
    expect(figures.discountTotal, 5000);
    expect(figures.netSales, 125000);
    // COGS = 2 × 40,000 + 1 × 30,000, from the snapshots only.
    expect(figures.cogs, 110000);
    expect(figures.grossProfit, 15000);
    expect(figures.expenseTotal, 15000);
    expect(figures.netProfit, 0);

    expect(report.invoiceCount, 2, reason: 'sale invoices only');
    expect(report.returnCount, 1);
    expect(report.averageTicket, 62500);
  });

  test('payment mix shows the sale that has no payment as نسیه', () async {
    await invoice('s1', date: DateTime(2026, 10, 1), total: 60000);
    await payment('s1', date: DateTime(2026, 10, 1), amount: 40000);
    await invoice('s2', date: DateTime(2026, 10, 2), total: 20000);
    await payment('s2',
        date: DateTime(2026, 10, 2), amount: 20000, method: 'card');

    final report = await dao3.periodReport(range);
    expect(report!.byMethod[PaymentMethod.cash], 40000);
    expect(report.byMethod[PaymentMethod.card], 20000);
    // net sales 80,000 − paid 60,000.
    expect(report.byMethod[PaymentMethod.other], 20000);
  });

  test('comparison uses the equally long previous window', () async {
    // Current window: 125,000 net (see the shape above, simplified here).
    await invoice('c1', date: DateTime(2026, 10, 2), total: 150000);
    // Previous window: 26..30 Sep, i.e. five days before 1 Oct.
    await invoice('p1', date: DateTime(2026, 9, 26), total: 100000);
    await invoice('p2', date: DateTime(2026, 9, 20), total: 700000,
        kind: 'sale_return');
    // …but a sale outside the previous window must not count.
    await invoice('p3', date: DateTime(2026, 9, 25), total: 500000);

    final report = await dao3.periodReport(range);
    expect(report!.previousNetSales, 100000);
    expect(report.hasPreviousData, isTrue);
    expect(report.salesChangePercent, 50);
  });

  test('an empty previous window reports no percentage at all', () async {
    await invoice('c1', date: DateTime(2026, 10, 2), total: 150000);
    final report = await dao3.periodReport(range);
    expect(report!.hasPreviousData, isFalse);
    expect(report.salesChangePercent, isNull);
    expect(report.previousNetSales, 0);
  });

  test('top products rank by money and carry their own cost', () async {
    await invoice('s1', date: DateTime(2026, 10, 1), total: 160000);
    await item('s1',
        name: 'روغن', qtyMilli: 2000, unitPrice: 60000, unitCost: 40000);
    await item('s1',
        name: 'فیلتر', qtyMilli: 1000, unitPrice: 40000, unitCost: 30000);
    final report = await dao3.periodReport(range);
    final top = report!.topProducts;
    expect(top.first.name, 'روغن');
    expect(top.first.total, 120000);
    expect(top.first.cost, 80000);
    expect(top.first.profit, 40000);
    expect(top.last.total, 40000);
  });

  test('slow movers are stock that did not sell inside the window', () async {
    await product('old', stock: 5000, avgCost: 2000,
        lastSoldAtMs: ms(DateTime(2026, 9, 1)));
    await product('new', stock: 3000, avgCost: 1000,
        lastSoldAtMs: ms(DateTime(2026, 10, 3)));
    await product('never', stock: 2000, avgCost: 1500);
    await product('empty', stock: 0, avgCost: 900);
    await product('service', stock: 4000, avgCost: 500, track: false);
    await product('archived', stock: 4000, avgCost: 500, active: false);

    final movers = await dao3.slowMovers(range);
    final ids = movers.map((m) => m.id).toList();
    expect(ids, containsAll(<String>['old', 'never']));
    expect(ids, isNot(contains('new')), reason: 'it sold in the window');
    expect(ids, isNot(contains('empty')), reason: 'no stock, no dead money');
    expect(ids, isNot(contains('service')), reason: 'services hold no stock');
    expect(ids, isNot(contains('archived')), reason: 'archived products hide');

    final old = movers.firstWhere((m) => m.id == 'old');
    expect(old.tiedUpValue, 10000); // 5 × 2,000
    expect(old.idleDays(DateTime(2026, 10, 5)), 34);
    final never = movers.firstWhere((m) => m.id == 'never');
    expect(never.idleDays(DateTime(2026, 10, 5)), isNull);
    expect(never.tiedUpValue, 3000);
  });

  test('drill-downs narrow to the rows behind each figure', () async {
    await invoice('s1', date: DateTime(2026, 10, 1), total: 60000);
    await item('s1', name: 'روغن', qtyMilli: 1000, unitPrice: 60000);
    await payment('s1', date: DateTime(2026, 10, 1), amount: 60000);

    await invoice('s2', date: DateTime(2026, 10, 2), total: 40000);
    await item('s2', name: 'فیلتر', qtyMilli: 1000, unitPrice: 40000);

    await invoice('r1',
        date: DateTime(2026, 10, 3), total: 5000, kind: 'sale_return');

    final salesOnly = await dao3.rangeInvoices(range, includeReturns: false);
    expect(salesOnly.map((i) => i.id), ['s2', 's1'],
        reason: 'newest first, no return');

    final withReturns = await dao3.rangeInvoices(range);
    expect(withReturns.map((i) => i.id), contains('r1'));

    final byProduct = await dao3.rangeInvoices(range, productName: 'روغن');
    expect(byProduct.map((i) => i.id), ['s1']);

    final byMethod =
        await dao3.rangeInvoices(range, method: PaymentMethod.card);
    expect(byMethod, isEmpty, reason: 's1 was cash');

    final credit = await dao3.rangeInvoices(range, creditOnly: true);
    expect(credit.map((i) => i.id), containsAll(<String>['s2', 'r1']));
    expect(credit.map((i) => i.id), isNot(contains('s1')));
  });

  test('the CSV archive holds every shop table and a README', () async {
    // The archive builder is exercised here rather than in a widget test: it
    // reads the same database the report reads, and a missing table in a
    // backup is the kind of bug you discover when you need the backup.
    await product('p1', name: 'روغن', stock: 1000, avgCost: 500);
    await invoice('s1', date: DateTime(2026, 10, 1), total: 60000);
    await item('s1', name: 'روغن', qtyMilli: 1000, unitPrice: 60000);

    final bytes = await ShopCsvArchive.build(db);
    final archive = ZipDecoder().decodeBytes(bytes);
    final names = archive.files.map((f) => f.name).toList();
    expect(names, contains('README.txt'));
    for (final table in [...ShopTables.allTables, ...Shop3Tables.allTables]) {
      expect(names, contains('$table.csv'), reason: '$table missing');
    }
    final productFile =
        archive.files.firstWhere((f) => f.name == '${ShopTables.product}.csv');
    final raw = productFile.content as List<int>;
    // Excel on Windows reads a BOM-less Persian CSV as CP1256 gibberish, so the
    // three bytes have to be in the file itself — `utf8.decode` strips them,
    // which is why this asserts on the bytes and not on the string.
    expect(raw.take(3), [0xEF, 0xBB, 0xBF],
        reason: 'Excel needs the BOM to read Persian');
    final products = utf8.decode(raw);
    expect(products, contains('روغن'));
  });
}
