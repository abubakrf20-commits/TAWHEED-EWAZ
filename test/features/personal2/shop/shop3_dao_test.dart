import 'dart:io';

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
import 'package:tawheeed/features/personal2/shop/domain/shop3_domain.dart';

/// Database tests for the stage-3 flows: purchase posting with moving average,
/// void exactness, supplier FIFO, the cheque state machine with its side
/// effects, cash-day arithmetic and stock-count posting.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase db;
  late ShopDao dao;
  late Shop3Dao dao3;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('shop3_dao_test');
    final file = File(p.join(tempDir.path, 'shop3.sqlite'));
    db = AppDatabase.withConnection(NativeDatabase(file));
    dao = ShopDao(db);
    dao3 = Shop3Dao(db, dao);
    SharedPreferences.setMockInitialValues({});
    await db.customStatement('SELECT 1');
    await dao.ensureSeeded();
    await dao3.ensureExpenseCategoriesSeeded();
  });

  tearDown(() async {
    await db.close();
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds sqlite handles briefly.
    }
  });

  PurchaseLine line(String productId,
      {int qty = 1000, int cost = 1000, bool track = true}) =>
      PurchaseLine(
        productId: productId,
        name: 'کالا $productId',
        qtyMilli: qty,
        unitCost: cost,
        trackStock: track,
      );

  Future<void> seedProduct(String id, {int stock = 0, int avg = 0}) async {
    await dao.saveProduct(
      id: id,
      name: 'کالا $id',
      normalizedName: 'کالا $id',
      sellPrice: 1000,
      buyPrice: avg,
      trackStock: true,
      active: true,
    );
    if (stock > 0 || avg > 0) {
      // Force the cached values for an empty-stock product the test controls.
      await db.customStatement(
        'UPDATE ${ShopTables.product} SET stock_milli_cached = ?, avg_cost = ? '
        'WHERE id = ?',
        [stock, avg, id],
      );
    }
  }

  group('purchase posting', () {
    test('items, movements, cached stock, avg cost and ledger all land',
        () async {
      await seedProduct('p1', stock: 2000, avg: 800);
      final supplier = await _seedSupplier(dao3, 's1');

      final purchase = await dao3.postPurchase(
        lines: [line('p1', qty: 1000, cost: 1100)],
        supplier: supplier,
        extraCostTotal: 300,
        allocateExtras: true,
        paidNow: 500,
        paidMethod: PaymentMethod.cash,
        marginPercent: 30,
      );

      expect(purchase, isNotNull);
      expect(purchase!.number, 'P1');
      // subtotal 1100 + extra 300 = 1400.
      expect(purchase.total, 1400);
      expect(purchase.paid, 500);

      // Landed: (1100 + 300)/1 unit = 1400.
      final items = await dao3.purchaseItems(purchase.id);
      expect(items.single.landedUnitCost, 1400);
      expect(items.single.allocatedExtra, 300);
      expect(items.single.prevAvgCost, 800);
      // (2kg × 800 + 1kg × 1400) / 3kg = 1000.
      expect(items.single.newAvgCost, 1000);

      final product = await dao.product('p1');
      expect(product!.stockMilliCached, 3000);
      expect(product.avgCost, 1000);
      expect(product.buyPriceLast, 1400);

      // Supplier ledger: +1400 (owe) − 500 (paid now).
      expect(await dao3.supplierBalance('s1'), 900);
    });

    test('stock ≤ 0: the landed cost IS the new average', () async {
      await seedProduct('p1', stock: -500, avg: 700);
      final purchase = await dao3.postPurchase(
        lines: [line('p1', qty: 2000, cost: 950)],
        supplier: null,
        extraCostTotal: 0,
        allocateExtras: false,
        paidNow: 0,
        paidMethod: PaymentMethod.cash,
        marginPercent: 0,
      );
      final items = await dao3.purchaseItems(purchase!.id);
      expect(items.single.newAvgCost, 950);
    });

    test('extras allocate proportionally and sum exactly', () async {
      await seedProduct('p1');
      await seedProduct('p2');
      final purchase = await dao3.postPurchase(
        lines: [
          line('p1', qty: 1000, cost: 100000),
          line('p2', qty: 1000, cost: 100000),
        ],
        supplier: null,
        extraCostTotal: 301,
        allocateExtras: true,
        paidNow: 0,
        paidMethod: PaymentMethod.cash,
        marginPercent: 0,
      );
      final items = await dao3.purchaseItems(purchase!.id);
      final sum = items.fold<int>(0, (s, i) => s + i.allocatedExtra);
      expect(sum, 301, reason: 'the books must close to the rial');
    });

    test('overpayment is refused inside the transaction (nothing persists)',
        () async {
      await seedProduct('p1');
      await expectLater(
        dao3.postPurchase(
          lines: [line('p1', qty: 1000, cost: 1000)],
          supplier: null,
          extraCostTotal: 0,
          allocateExtras: false,
          paidNow: 9999,
          paidMethod: PaymentMethod.cash,
          marginPercent: 0,
        ),
        completes,
      );
      // Nothing persisted.
      final purchases = await dao3.recentPurchases();
      expect(purchases, isEmpty);
      expect((await dao.product('p1'))!.stockMilliCached, 0);
    });

    test('void restores stock and supplier balance exactly', () async {
      await seedProduct('p1', stock: 2000, avg: 800);
      final supplier = await _seedSupplier(dao3, 's1');
      final beforeStock = (await dao.product('p1'))!.stockMilliCached;
      final beforeBalance = await dao3.supplierBalance('s1');

      final purchase = await dao3.postPurchase(
        lines: [line('p1', qty: 1000, cost: 1100)],
        supplier: supplier,
        extraCostTotal: 0,
        allocateExtras: false,
        paidNow: 0,
        paidMethod: PaymentMethod.cash,
        marginPercent: 0,
      );
      expect((await dao.product('p1'))!.stockMilliCached, beforeStock + 1000);
      expect(await dao3.supplierBalance('s1'), beforeBalance + 1100);

      expect(
        await dao3.voidPurchase(
            purchaseId: purchase!.id, reason: 'اشتباه در خرید'),
        isTrue,
      );
      expect((await dao.product('p1'))!.stockMilliCached, beforeStock);
      expect(await dao3.supplierBalance('s1'), beforeBalance);

      final doc = await dao3.purchase(purchase.id);
      expect(doc!.status, 'void');
      // Numbering was NOT rolled back.
      final second = await dao3.postPurchase(
        lines: [line('p1', qty: 1000, cost: 1100)],
        supplier: supplier,
        extraCostTotal: 0,
        allocateExtras: false,
        paidNow: 0,
        paidMethod: PaymentMethod.cash,
        marginPercent: 0,
      );
      expect(second!.number, 'P2');
    });
  });

  group('supplier payments', () {
    test('FIFO allocation lands in the ledger', () async {
      await seedProduct('p1');
      final supplier = await _seedSupplier(dao3, 's1');
      final first = await dao3.postPurchase(
        lines: [line('p1', qty: 1000, cost: 1000)],
        supplier: supplier,
        extraCostTotal: 0,
        allocateExtras: false,
        paidNow: 0,
        paidMethod: PaymentMethod.cash,
        marginPercent: 0,
      );
      final second = await dao3.postPurchase(
        lines: [line('p1', qty: 1000, cost: 2000)],
        supplier: supplier,
        extraCostTotal: 0,
        allocateExtras: false,
        paidNow: 0,
        paidMethod: PaymentMethod.cash,
        marginPercent: 0,
      );
      expect(await dao3.supplierBalance('s1'), 3000);

      final allocation = await dao3.paySupplier(
        supplierId: 's1',
        amount: 2500,
        method: PaymentMethod.cash,
      );
      expect(allocation!.slices.first.invoiceId, first!.id);
      expect(allocation.slices.first.amount, 1000);
      expect(allocation.slices.last.invoiceId, second!.id);
      expect(allocation.slices.last.amount, 1500);
      expect(await dao3.supplierBalance('s1'), 500);

      // The open purchases reflect the allocation.
      final open = await dao3.openPurchases('s1');
      expect(open.single.remaining, 500);
    });
  });

  group('cheques', () {
    test('a received cheque as payment reduces the balance at pending',
        () async {
      await seedProduct('p1');
      // Customer with an open credit invoice.
      final customer = await _seedCustomer(dao, 'c1');
      await dao.postSale(
        cart: [
          CartLine(
            productId: 'p1',
            name: 'کالا p1',
            unitName: 'عدد',
            qtyMilli: 1000,
            unitPrice: 5000,
            trackStock: false,
          ),
        ],
        payments: const [],
        customer: customer,
        settingsRow: const ShopSettingsRow(),
        customerBalance: 0,
      );
      expect(await dao.customerBalance('c1'), 5000);

      final chequeId = await dao3.addCheque(
        direction: ChequeDirection.received,
        amount: 5000,
        dueDate: DateTime.now().add(const Duration(days: 10)),
        number: '12345',
        partyId: 'c1',
        asPaymentFor: 'c1',
      );
      expect(chequeId, isNotNull);
      // Balance drops NOW (چک در جریان).
      expect(await dao.customerBalance('c1'), 0);

      // BOUNCE restores it exactly.
      expect(
        await dao3.transitionCheque(
            chequeId: chequeId!, to: ChequeStatus.deposited),
        isTrue,
      );
      expect(
        await dao3.transitionCheque(chequeId: chequeId, to: ChequeStatus.bounced),
        isTrue,
      );
      expect(await dao.customerBalance('c1'), 5000,
          reason: 'the bounce restores the debt exactly');
    });

    test('a bounced ISSUED cheque restores the supplier balance', () async {
      final supplier = await _seedSupplier(dao3, 's1');
      await dao3.paySupplier(
        supplierId: 's1',
        amount: 1000,
        method: PaymentMethod.cash,
      );
      // Balance now −1000 (advance). Take it back via a bounced issued cheque
      // paid to the supplier: record the cheque as a payment first.
      final chequeId = await dao3.addCheque(
        direction: ChequeDirection.issued,
        amount: 1000,
        dueDate: DateTime.now().add(const Duration(days: 5)),
        number: '777',
        partyId: 's1',
        partyType: 'supplier',
      );
      expect(chequeId, isNotNull);
      // The issued cheque paid out: write its ledger effect (what the cheque
      // screen does when issuing a payment).
      await dao.adjustLedgerDirect(
        partyId: 's1',
        signedAmount: -1000,
        kind: 'payment',
        refType: 'cheque',
        refId: chequeId!,
        note: 'پرداخت با چک',
        partyType: 'supplier',
      );
      expect(await dao3.supplierBalance('s1'), -2000);

      expect(
        await dao3.transitionCheque(chequeId: chequeId, to: ChequeStatus.bounced),
        isTrue,
      );
      // The bounce reverses the CHEQUE's −1000 only: back to the pre-cheque
      // −1000 (the cash payment from paySupplier stays).
      expect(await dao3.supplierBalance('s1'), -1000);
    });

    test('illegal transitions are refused by the DAO too', () async {
      final chequeId = await dao3.addCheque(
        direction: ChequeDirection.issued,
        amount: 1000,
        dueDate: DateTime.now(),
      );
      expect(
        await dao3.transitionCheque(
            chequeId: chequeId!, to: ChequeStatus.endorsed),
        isFalse,
        reason: 'issued cheques cannot be endorsed',
      );
      expect(
        await dao3.transitionCheque(chequeId: chequeId, to: ChequeStatus.cleared),
        isTrue,
      );
      // Cleared is terminal.
      expect(
        await dao3.transitionCheque(chequeId: chequeId, to: ChequeStatus.bounced),
        isFalse,
      );
    });

    test('in-flight listing and totals', () async {
      await dao3.addCheque(
        direction: ChequeDirection.received,
        amount: 1000,
        dueDate: DateTime.now(),
      );
      final cleared = await dao3.addCheque(
        direction: ChequeDirection.received,
        amount: 2000,
        dueDate: DateTime.now(),
      );
      await dao3.transitionCheque(chequeId: cleared!, to: ChequeStatus.cleared);

      final inFlight = await dao3.cheques(onlyInFlight: true);
      expect(inFlight, hasLength(1));
      expect(inFlight.single.amount, 1000);
    });
  });

  group('cash day', () {
    test('open defaults to the previous counted cash; close records the diff',
        () async {
      // Yesterday: opened and closed with 100,000 counted.
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yId = 'cash_${cashDayStart(yesterday).millisecondsSinceEpoch}';
      await db.customStatement(
        'INSERT INTO ${Shop3Tables.cashDay} '
        '(id, date, opened_at, opening_cash, closed_at, counted_cash, '
        'expected_cash, difference) '
        'VALUES (?, ?, ?, 90000, ?, 100000, 100000, 0)',
        [
          yId,
          cashDayStart(yesterday).millisecondsSinceEpoch,
          cashDayStart(yesterday).millisecondsSinceEpoch,
          DateTime.now().millisecondsSinceEpoch,
        ],
      );

      final today = await dao3.openCashDay();
      expect(today.openingCash, 100000,
          reason: 'defaults to the previous day counted cash');

      // Close with a 5,000 shortage — recorded, never corrected.
      expect(
        await dao3.closeCashDay(day: DateTime.now(), countedCash: 95000),
        isTrue,
      );
      final closed = await dao3.cashDayToday();
      expect(closed!.countedCash, 95000);
      expect(closed.difference, closed.countedCash! - closed.expectedCash!);
      // Re-closing is refused (the day is frozen).
      expect(
        await dao3.closeCashDay(day: DateTime.now(), countedCash: 1),
        isFalse,
      );
    });
  });

  group('expenses', () {
    test('a cash expense leaves the drawer and lands in the category total',
        () async {
      final categories = await dao3.expenseCategories();
      expect(categories, isNotEmpty);
      final rent = categories.firstWhere((c) => c.name == 'اجاره');

      await dao3.addExpense(
        date: DateTime.now(),
        categoryId: rent.id,
        amount: 250000,
        method: PaymentMethod.cash,
        payee: 'مالک',
      );
      final from = cashDayStart(DateTime.now()).millisecondsSinceEpoch;
      expect(
        await dao3.expenseTotal(fromMs: from, toMs: from + 86400000),
        250000,
      );
      // The drawer saw a −250,000 adjustment row.
      final adjustments = await db.customSelect(
        'SELECT SUM(amount) AS t FROM ${Shop3Tables.cashAdjustment} '
        "WHERE kind = 'expense_out'",
      ).get();
      expect(adjustments.first.read<int>('t'), -250000);
    });
  });

  group('stock count', () {
    test('posting writes adjustment movements and the value impact', () async {
      await seedProduct('p1', stock: 2000, avg: 500);
      await seedProduct('p2', stock: 1000, avg: 300);
      final countId = await dao3.createStockCount();
      expect(countId, isNotNull);

      // Count p1 correctly (no diff) and p2 with a −300 shortage.
      expect(
        await dao3.setCountedQty(
            countId: countId!, productId: 'p1', countedMilli: 2000),
        isTrue,
      );
      expect(
        await dao3.setCountedQty(
            countId: countId, productId: 'p2', countedMilli: 700),
        isTrue,
      );

      final impact = await dao3.postStockCount(countId: countId);
      // p2's shortage: −300 milli × 300 avgCost / 1000 = −90.
      expect(impact, -90);
    });
  });

  group('integrity v2', () {
    test('a consistent database reports nothing', () async {
      await seedProduct('p1');
      final supplier = await _seedSupplier(dao3, 's1');
      await dao3.postPurchase(
        lines: [line('p1', qty: 1000, cost: 1000)],
        supplier: supplier,
        extraCostTotal: 0,
        allocateExtras: false,
        paidNow: 0,
        paidMethod: PaymentMethod.cash,
        marginPercent: 0,
      );
      expect(await dao3.verifyIntegrity3(), isEmpty);
    });
  });
}

Future<ShopSupplier> _seedSupplier(Shop3Dao dao3, String id) async {
  await dao3.saveSupplier(id: id, name: 'تأمین‌کننده $id');
  return (await dao3.supplier(id))!;
}

Future<ShopCustomer> _seedCustomer(ShopDao dao, String id) async {
  await dao.saveCustomer(
    id: id,
    name: 'مشتری $id',
    normalizedName: 'مشتری $id',
    active: true,
  );
  return (await dao.customer(id))!;
}
