import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/personal2/shop/data/shop_dao.dart';
import 'package:tawheeed/features/personal2/shop/data/shop_tables.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_domain.dart';

/// Database-level tests for the shop core: posting atomicity, the invariants
/// over real rows, void exactness, FIFO payments on live data, and the
/// v47 migration.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase db;
  late ShopDao dao;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('shop_dao_test');
    final file = File(p.join(tempDir.path, 'shop.sqlite'));
    db = AppDatabase.withConnection(NativeDatabase(file));
    dao = ShopDao(db);
    SharedPreferences.setMockInitialValues({});
    await db.customStatement('SELECT 1');
    await dao.ensureSeeded();
  });

  tearDown(() async {
    await db.close();
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds sqlite handles briefly; the OS reclaims the temp dir.
    }
  });

  ShopSettingsRow settings({
    int roundingStep = 0,
    CreditLimitMode creditMode = CreditLimitMode.off,
    bool allowNegativeStock = true,
  }) =>
      ShopSettingsRow(
        roundingStep: roundingStep,
        creditLimitMode: creditMode,
        allowNegativeStock: allowNegativeStock,
      );

  CartLine line(String productId,
      {int qty = 2000,
      int price = 1000,
      bool track = true,
      int avgCost = 0,
      String name = 'کالا'}) =>
      CartLine(
        productId: productId,
        name: name,
        unitName: 'عدد',
        qtyMilli: qty,
        unitPrice: price,
        trackStock: track,
        avgCost: avgCost,
      );

  Future<void> seedProduct(
    String id, {
    int opening = 10000,
    int cost = 400,
    int sell = 1000,
    String? barcode,
    bool track = true,
  }) async {
    await dao.saveProduct(
      id: id,
      name: 'کالا $id',
      normalizedName: 'کالا $id',
      sellPrice: sell,
      buyPrice: cost,
      trackStock: track,
      active: true,
      openingStockMilli: opening,
      openingCost: cost,
      barcodes: barcode == null ? const [] : [barcode],
    );
  }

  Future<ShopCustomer> seedCustomer(String id,
      {String? barcode, int? limit}) async {
    await dao.saveCustomer(
      id: id,
      name: 'مشتری $id',
      normalizedName: 'مشتری $id',
      creditLimit: limit,
      active: true,
    );
    return (await dao.customer(id))!;
  }

  group('posting atomicity', () {
    test('a failure mid-transaction persists NOTHING', () async {
      await seedProduct('p1');
      // Post a good sale first so there IS state to protect.
      final good = await dao.postSale(
        cart: [line('p1', qty: 1000)],
        payments: [const SalePayment(method: PaymentMethod.cash, amount: 1000)],
        settingsRow: settings(),
        customerBalance: 0,
      );
      expect(good.invoice.isPosted, isTrue);

      final beforeProducts = await dao.products();
      final beforeInvoices = await dao.recentInvoices();

      // A cart whose product row will be made to disappear mid-transaction:
      // the movement insert succeeds, the cached-stock UPDATE hits a missing
      // row... actually the cleanest injection is a listener-free trick: use
      // a product id that passes cart validation but whose row is deleted
      // inside the transaction is not reachable from outside — so instead
      // drive the failure through a bad settings row (missing) which makes
      // the number allocation fail.
      await db.customStatement('DELETE FROM ${ShopTables.settings}');

      await expectLater(
        dao.postSale(
          cart: [line('p1')],
          payments: const [],
          settingsRow: settings(),
          customerBalance: 0,
        ),
        throwsA(isA<PostingException>()),
      );

      // Nothing changed: same product rows, same invoice count, and the
      // in-flight invoice id never landed.
      final afterProducts = await dao.products();
      final afterInvoices = await dao.recentInvoices();
      expect(afterProducts.length, beforeProducts.length);
      expect(afterInvoices.length, beforeInvoices.length);

      // And the first sale's numbers are untouched.
      final stock = (await dao.product('p1'))!.stockMilliCached;
      expect(stock, 10000 - 1000);
    });

    test('posting writes invoice, items, movement, cached stock, audit', () async {
      await seedProduct('p1', opening: 10000, cost: 400, sell: 1000);
      final posted = await dao.postSale(
        cart: [line('p1', qty: 2500, price: 1000, avgCost: 400)],
        payments: [const SalePayment(method: PaymentMethod.cash, amount: 2500)],
        settingsRow: settings(),
        customerBalance: 0,
      );

      expect(posted.invoice.total, 2500);
      expect(posted.items.single.qtyMilli, 2500);
      expect(posted.items.single.unitCostSnapshot, 400);

      final product = await dao.product('p1');
      expect(product!.stockMilliCached, 7500);

      // Cached stock equals the movement sum (invariant 1).
      final movements = await db.customSelect(
        'SELECT COALESCE(SUM(qty_milli), 0) AS s FROM '
        '${ShopTables.stockMovement} WHERE product_id = ?',
        variables: [Variable.withString('p1')],
      ).get();
      expect(movements.first.read<int>('s'), product.stockMilliCached);

      // An audit row exists for the posting.
      final audit = await db.customSelect(
        "SELECT COUNT(*) AS n FROM ${ShopTables.auditLog} WHERE action = 'post_sale'",
      ).get();
      expect(audit.first.read<int>('n'), 1);
    });

    test('invoice numbers allocate inside the transaction and only increase',
        () async {
      await seedProduct('p1');
      final first = await dao.postSale(
        cart: [line('p1', qty: 1000)],
        payments: [const SalePayment(method: PaymentMethod.cash, amount: 1000)],
        settingsRow: settings(),
        customerBalance: 0,
      );
      final second = await dao.postSale(
        cart: [line('p1', qty: 1000)],
        payments: [const SalePayment(method: PaymentMethod.cash, amount: 1000)],
        settingsRow: settings(),
        customerBalance: 0,
      );
      expect(second.invoice.number, isNot(first.invoice.number));

      final s = await dao.settings();
      expect(s.nextInvoiceNumber, greaterThan(1));
    });

    test('credit without a customer is refused even past the pure layer',
        () async {
      await seedProduct('p1');
      await expectLater(
        dao.postSale(
          cart: [line('p1')],
          payments: const [],
          settingsRow: settings(creditMode: CreditLimitMode.warn),
          customerBalance: 0,
        ),
        throwsA(isA<PostingException>()),
      );
    });

    test('block mode refuses a sale over the limit; warn needs confirmation',
        () async {
      await seedProduct('p1');
      final customer = await seedCustomer('c1', limit: 1000);

      // Block mode: throws outright.
      await expectLater(
        dao.postSale(
          cart: [line('p1', qty: 1000, price: 5000)],
          payments: const [],
          customer: customer,
          settingsRow: settings(creditMode: CreditLimitMode.block),
          customerBalance: await dao.customerBalance('c1'),
        ),
        throwsA(isA<PostingException>()),
      );

      // Warn mode: first call throws the CONFIRM sentinel, the confirmed
      // retry goes through.
      await expectLater(
        dao.postSale(
          cart: [line('p1', qty: 1000, price: 5000)],
          payments: const [],
          customer: customer,
          settingsRow: settings(creditMode: CreditLimitMode.warn),
          customerBalance: await dao.customerBalance('c1'),
        ),
        throwsA(predicate(
            (e) => e is PostingException && e.message == 'CONFIRM_CREDIT_WARN')),
      );
      final ok = await dao.postSale(
        cart: [line('p1', qty: 1000, price: 5000)],
        payments: const [],
        customer: customer,
        settingsRow: settings(creditMode: CreditLimitMode.warn),
        customerBalance: await dao.customerBalance('c1'),
        ignoreCreditLimitWarn: true,
      );
      expect(ok.invoice.total, 5000);
      expect(await dao.customerBalance('c1'), 5000);
    });
  });

  group('void exactness', () {
    test('void restores stock and balance exactly and never reuses the number',
        () async {
      await seedProduct('p1', opening: 5000, cost: 400);
      final customer = await seedCustomer('c1');
      final beforeStock = (await dao.product('p1'))!.stockMilliCached;
      final beforeBalance = await dao.customerBalance('c1');

      final posted = await dao.postSale(
        cart: [line('p1', qty: 2000, price: 3000, avgCost: 400)],
        payments: const [],
        customer: customer,
        settingsRow: settings(),
        customerBalance: beforeBalance,
      );
      expect((await dao.product('p1'))!.stockMilliCached, beforeStock - 2000);
      expect(await dao.customerBalance('c1'), beforeBalance + 6000);

      final voided = await dao.voidInvoice(
        invoiceId: posted.invoice.id,
        reason: 'اشتباه در ثبت',
      );
      expect(voided, isTrue);

      // Stock and balance are EXACTLY what they were before the sale.
      expect((await dao.product('p1'))!.stockMilliCached, beforeStock);
      expect(await dao.customerBalance('c1'), beforeBalance);

      // The original rows still exist, marked void — never deleted.
      final doc = await dao.invoice(posted.invoice.id);
      expect(doc!.isVoid, isTrue);
      expect(doc.voidReason, 'اشتباه در ثبت');
      expect((await dao.invoiceItems(posted.invoice.id)), hasLength(1));

      // Numbering was not rolled back.
      final s = await dao.settings();
      expect(s.nextInvoiceNumber, 2);
    });

    test('voiding twice is a no-op the second time', () async {
      await seedProduct('p1');
      final posted = await dao.postSale(
        cart: [line('p1', qty: 1000)],
        payments: [const SalePayment(method: PaymentMethod.cash, amount: 1000)],
        settingsRow: settings(),
        customerBalance: 0,
      );
      expect(
        await dao.voidInvoice(invoiceId: posted.invoice.id, reason: 'اول'),
        isTrue,
      );
      expect(
        await dao.voidInvoice(invoiceId: posted.invoice.id, reason: 'دوم'),
        isFalse,
        reason: 'already void — a second void would double the reversal',
      );
    });

    test('an empty reason is refused (the audit needs it)', () async {
      await seedProduct('p1');
      final posted = await dao.postSale(
        cart: [line('p1', qty: 1000)],
        payments: [const SalePayment(method: PaymentMethod.cash, amount: 1000)],
        settingsRow: settings(),
        customerBalance: 0,
      );
      expect(await dao.voidInvoice(invoiceId: posted.invoice.id, reason: '  '),
          isFalse);
    });
  });

  group('FIFO payments on live data', () {
    test('allocation preview matches what lands in the ledger', () async {
      await seedProduct('p1');
      final customer = await seedCustomer('c1');

      // Two credit sales, oldest first.
      final first = await dao.postSale(
        cart: [line('p1', qty: 1000, price: 1000)],
        payments: const [],
        customer: customer,
        settingsRow: settings(),
        customerBalance: 0,
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final second = await dao.postSale(
        cart: [line('p1', qty: 1000, price: 2000)],
        payments: const [],
        customer: customer,
        settingsRow: settings(),
        customerBalance: await dao.customerBalance('c1'),
      );
      expect(await dao.customerBalance('c1'), 3000);

      // The preview: 3,500 pays the 1,000 invoice fully, then 2,500 of the
      // 2,000 invoice... no: 2,000 max. 1000 + 2000 = 3000, so 3500 →
      // 1000 + 2000 + 500 advance.
      final open = await dao.openInvoices('c1');
      final preview = allocateFifo(payment: 3500, openInvoices: open);
      expect(preview.slices.first.invoiceId, first.invoice.id);
      expect(preview.slices.first.amount, 1000);
      expect(preview.slices.last.invoiceId, second.invoice.id);
      expect(preview.slices.last.amount, 2000);
      expect(preview.advance, 500);

      final landed = await dao.receivePayment(
        customerId: 'c1',
        amount: 3500,
        method: PaymentMethod.cash,
        date: DateTime.now(),
      );
      expect(landed!.slices, hasLength(2));
      expect(landed.advance, 500);

      // Balance is now −500 (بستانکار) — the advance.
      expect(await dao.customerBalance('c1'), -500);

      // No invoice remains open.
      expect(await dao.openInvoices('c1'), isEmpty);
    });

    test('a write-off needs a note and reduces the balance', () async {
      await seedProduct('p1');
      final customer = await seedCustomer('c1');
      await dao.postSale(
        cart: [line('p1', qty: 1000, price: 1000)],
        payments: const [],
        customer: customer,
        settingsRow: settings(),
        customerBalance: 0,
      );
      expect(await dao.writeOff(customerId: 'c1', amount: 200, note: ''), false,
          reason: 'note required');
      expect(
        await dao.writeOff(customerId: 'c1', amount: 200, note: 'بخشش بخشی از بدهی'),
        isTrue,
      );
      expect(await dao.customerBalance('c1'), 800);
    });

    test('aging buckets come from live open invoices', () async {
      await seedProduct('p1');
      final customer = await seedCustomer('c1');
      await dao.postSale(
        cart: [line('p1', qty: 1000, price: 1000)],
        payments: const [],
        customer: customer,
        settingsRow: settings(),
        customerBalance: 0,
      );
      final open = await dao.openInvoices('c1');
      final buckets = agingBucketsOf(openInvoices: open, now: DateTime.now());
      // Just posted: everything sits in the 0-30 bucket.
      expect(buckets.first, 1000);
      expect(buckets[3], 0);
    });
  });

  group('products and barcodes', () {
    test('barcode lookup is exact and duplicates are refused by the index',
        () async {
      await seedProduct('p1', barcode: '1234567890');
      await seedProduct('p2');

      final found = await dao.productByBarcode('1234567890');
      expect(found!.id, 'p1');
      expect(await dao.productByBarcode(' 1234567890 '), isNotNull,
          reason: 'lookup trims');
      expect(await dao.productByBarcode('nope'), isNull);

      // The UNIQUE index refuses a second product with the same barcode even
      // if the caller bypasses the UI check.
      await expectLater(
        dao.saveProduct(
          id: 'p3',
          name: 'x',
          normalizedName: 'x',
          sellPrice: 1,
          buyPrice: 1,
          trackStock: false,
          active: true,
          barcodes: ['1234567890'],
        ),
        completes,
      );
      // saveProduct swallows the constraint (swallow-and-log contract) and the
      // barcode was NOT written for p3.
      final dup = await db.customSelect(
        'SELECT COUNT(*) AS n FROM ${ShopTables.productBarcode} '
        "WHERE barcode = '1234567890'",
      ).get();
      expect(dup.first.read<int>('n'), 1);
      expect(await dao.productByBarcode('1234567890'), isNotNull);
      final p3barcodes = await db.customSelect(
        "SELECT COUNT(*) AS n FROM ${ShopTables.productBarcode} WHERE product_id = 'p3'",
      ).get();
      expect(p3barcodes.first.read<int>('n'), 0,
          reason: 'the failing insert rolled the barcode set back');
    });

    test('opening stock writes the movement and sets the average cost',
        () async {
      await seedProduct('p1', opening: 10000, cost: 750);
      final product = await dao.product('p1');
      expect(product!.stockMilliCached, 10000);
      expect(product.avgCost, 750);

      final movements = await db.customSelect(
        "SELECT type, qty_milli FROM ${ShopTables.stockMovement} WHERE product_id = 'p1'",
      ).get();
      expect(movements.single.read<String>('type'), 'opening');
      expect(movements.single.read<int>('qty_milli'), 10000);
    });
  });

  group('bulk price change with undo', () {
    test('applies to the selection and undo restores exactly', () async {
      await seedProduct('p1', sell: 1000, cost: 400);
      await seedProduct('p2', sell: 2000, cost: 800);

      final batch = await dao.applyBulkPriceChange(
        items: [
          (productId: 'p1', oldSell: 1000, oldBuy: 400),
          (productId: 'p2', oldSell: 2000, oldBuy: 800),
        ],
        deltaPerUnit: 10,
        percent: true,
        roundingStep: 0,
      );
      expect(batch, isNotNull);
      expect((await dao.product('p1'))!.sellPrice, 1100);
      expect((await dao.product('p2'))!.sellPrice, 2200);

      expect(await dao.undoBulkPriceChange(batch!), isTrue);
      expect((await dao.product('p1'))!.sellPrice, 1000);
      expect((await dao.product('p1'))!.buyPriceLast, 400);
      expect((await dao.product('p2'))!.sellPrice, 2000);
    });

    test('the shop rounding step is honoured, not just accepted', () async {
      await seedProduct('p3', sell: 1250, cost: 400);

      final batch = await dao.applyBulkPriceChange(
        items: [
          (productId: 'p3', oldSell: 1250, oldBuy: 400),
        ],
        deltaPerUnit: 10,
        percent: true,
        roundingStep: 100,
      );
      expect(batch, isNotNull);
      // 1,375 → 1,400 and 440 → 400: snapped to the 100 step, half-up.
      expect((await dao.product('p3'))!.sellPrice, 1400);
      expect((await dao.product('p3'))!.buyPriceLast, 400);
    });
  });

  group('integrity', () {
    test('a consistent database reports no mismatches', () async {
      await seedProduct('p1');
      final customer = await seedCustomer('c1');
      await dao.postSale(
        cart: [line('p1')],
        payments: const [],
        customer: customer,
        settingsRow: settings(),
        customerBalance: 0,
      );
      expect(await dao.verifyIntegrity(), isEmpty);
    });

    test('a tampered cached stock is reported, not silently fixed', () async {
      await seedProduct('p1');
      await db.customStatement(
        'UPDATE ${ShopTables.product} SET stock_milli_cached = 999999 '
        "WHERE id = 'p1'",
      );
      final problems = await dao.verifyIntegrity();
      expect(problems, hasLength(1));
      expect(problems.single.description, contains('موجودی'));
    });

    test('a posted credit sale without its ledger row is reported', () async {
      await seedProduct('p1');
      final customer = await seedCustomer('c1');
      final posted = await dao.postSale(
        cart: [line('p1', qty: 1000, price: 1000)],
        payments: const [],
        customer: customer,
        settingsRow: settings(),
        customerBalance: 0,
      );
      // Simulate an external edit (not possible through the DAO): drop the
      // ledger entry.
      await db.customStatement(
        'DELETE FROM ${ShopTables.ledgerEntry} WHERE ref_id = ?',
        [posted.invoice.id],
      );
      final problems = await dao.verifyIntegrity();
      expect(problems, hasLength(1));
      expect(problems.single.description, contains('دفتر'));
    });
  });

  group('held carts', () {
    test('hold, list, decode and delete round-trip', () async {
      await dao.holdCart(cart: [line('p1', qty: 1500, price: 3000)],
          customerId: 'c1', note: 'مشتری رفت عطاری');
      final held = await dao.heldCarts();
      expect(held, hasLength(1));
      expect(held.single.cart.single.qtyMilli, 1500);
      expect(held.single.cart.single.unitPrice, 3000);
      expect(held.single.customerId, 'c1');

      expect(await dao.deleteHeldCart(held.single.id), isTrue);
      expect(await dao.heldCarts(), isEmpty);
    });
  });
}
