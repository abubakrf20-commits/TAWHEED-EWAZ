import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/personal2/shop/data/shop3_dao.dart';
import 'package:tawheeed/features/personal2/shop/data/shop_dao.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop3_domain.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_domain.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_report_range.dart';

/// One complete shop day through the REAL posting paths — not rows written by
/// hand — and then the report compared with a number worked out on paper.
///
/// The point is the cross-check: purchase → credit sale → receipt → cheque →
/// stock count → expense, every figure asserted twice, once as the accounting
/// identity the shopkeeper would write down and once as what [Shop3Dao]
/// answers.
///
/// The hand column:
///   purchase        100 × 30,000 + 50 × 20,000 = 4,000,000  (1,500,000 paid)
///   cash sale        20 × 45,000               =   900,000
///   credit sale      10 × 45,000 + 5 × 32,000  =   610,000  (100,000 paid)
///   receipt                                     =   300,000
///   cheque received as payment                  =   210,000
///   stock count      2 units of oil missing     =   −60,000 in stock value
///   expense (rent)                              =    50,000
///
///   sales       = 900,000 + 610,000             = 1,510,000
///   COGS        = 30 × 30,000 + 5 × 20,000      = 1,000,000
///   gross       = 1,510,000 − 1,000,000         =   510,000
///   net         =   510,000 −    50,000         =   460,000
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase db;
  late ShopDao dao;
  late Shop3Dao dao3;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('shop_cycle_test');
    final file = File(p.join(tempDir.path, 'shop.sqlite'));
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
      // Windows keeps sqlite handles briefly; the OS reclaims the temp dir.
    }
  });

  Future<ShopProduct> product(
    String id, {
    required String name,
    required int sell,
    required int buy,
  }) async {
    final ok = await dao.saveProduct(
      id: id,
      name: name,
      normalizedName: name,
      sellPrice: sell,
      buyPrice: buy,
      trackStock: true,
      minStockMilli: 5000,
      active: true,
    );
    expect(ok, isTrue, reason: 'product $id must save');
    final saved = await dao.product(id);
    expect(saved, isNotNull);
    return saved!;
  }

  test('a full shop cycle matches the hand-written profit', () async {
    // ── The catalogue ───────────────────────────────────────────────────
    var oil = await product('oil', name: 'روغن', sell: 45000, buy: 30000);
    var filter =
        await product('filter', name: 'فیلتر', sell: 32000, buy: 20000);
    expect(oil.stockMilliCached, 0, reason: 'nothing on the shelf yet');
    expect(oil.avgCost, 0);

    final supplierSaved = await dao3.saveSupplier(
      id: 'sup1',
      name: 'پخش عمده',
      phone: '02100000000',
    );
    expect(supplierSaved, isTrue);
    final supplier = await dao3.supplier('sup1');
    expect(supplier, isNotNull);

    final customerSaved = await dao.saveCustomer(
      id: 'c1',
      name: 'حاج رضا',
      normalizedName: 'حاج رضا',
      phone: '09120000000',
      active: true,
    );
    expect(customerSaved, isTrue);
    final customer = await dao.customer('c1');
    expect(customer, isNotNull);

    // ── 1. Purchase: 100 oil @30,000 + 50 filters @20,000 ───────────────
    // 4,000,000 total, 1,500,000 paid at the counter, 2,500,000 on credit.
    final purchase = await dao3.postPurchase(
      lines: [
        const PurchaseLine(
          productId: 'oil',
          name: 'روغن',
          qtyMilli: 100000,
          unitCost: 30000,
        ),
        const PurchaseLine(
          productId: 'filter',
          name: 'فیلتر',
          qtyMilli: 50000,
          unitCost: 20000,
        ),
      ],
      supplier: supplier,
      extraCostTotal: 0,
      allocateExtras: false,
      paidNow: 1500000,
      paidMethod: PaymentMethod.cash,
      marginPercent: 0,
    );
    expect(purchase, isNotNull);
    expect(purchase!.total, 4000000);
    expect(purchase.paid, 1500000);
    expect(purchase.number, 'P1');

    oil = (await dao.product('oil'))!;
    filter = (await dao.product('filter'))!;
    expect(oil.stockMilliCached, 100000, reason: '100 units arrived');
    expect(oil.avgCost, 30000, reason: 'landed cost IS the first average');
    expect(filter.stockMilliCached, 50000);
    expect(filter.avgCost, 20000);
    expect(await dao3.supplierBalance('sup1'), 2500000);

    // ── 2. Cash sale: 20 oil @45,000 ────────────────────────────────────
    final cashSale = await dao.postSale(
      cart: [
        CartLine(
          productId: 'oil',
          name: 'روغن',
          unitName: 'عدد',
          qtyMilli: 20000,
          unitPrice: 45000,
          avgCost: oil.avgCost,
        ),
      ],
      payments: const [SalePayment(method: PaymentMethod.cash, amount: 900000)],
      settingsRow: await dao.settings(),
      customerBalance: 0,
    );
    expect(cashSale.invoice.total, 900000);
    expect(cashSale.items.single.unitCostSnapshot, 30000);

    // ── 3. Credit sale: 10 oil @45,000 + 5 filters @32,000, 100,000 down ─
    oil = (await dao.product('oil'))!;
    filter = (await dao.product('filter'))!;
    final creditSale = await dao.postSale(
      cart: [
        CartLine(
          productId: 'oil',
          name: 'روغن',
          unitName: 'عدد',
          qtyMilli: 10000,
          unitPrice: 45000,
          avgCost: oil.avgCost,
        ),
        CartLine(
          productId: 'filter',
          name: 'فیلتر',
          unitName: 'عدد',
          qtyMilli: 5000,
          unitPrice: 32000,
          avgCost: filter.avgCost,
        ),
      ],
      payments: const [SalePayment(method: PaymentMethod.cash, amount: 100000)],
      customer: customer,
      settingsRow: await dao.settings(),
      customerBalance: await dao.customerBalance('c1'),
    );
    expect(creditSale.invoice.total, 610000);
    expect(await dao.customerBalance('c1'), 510000);

    oil = (await dao.product('oil'))!;
    filter = (await dao.product('filter'))!;
    expect(oil.stockMilliCached, 70000, reason: '100 − 20 − 10');
    expect(filter.stockMilliCached, 45000, reason: '50 − 5');

    // ── 4. Receipt: 300,000 cash, FIFO onto the one open invoice ────────
    final receipt = await dao.receivePayment(
      customerId: 'c1',
      amount: 300000,
      method: PaymentMethod.cash,
      date: DateTime.now(),
    );
    expect(receipt, isNotNull);
    expect(receipt!.allocated, 300000);
    expect(receipt.advance, 0);
    expect(receipt.slices.single.invoiceId, creditSale.invoice.id);
    expect(await dao.customerBalance('c1'), 210000);

    // ── 5. Cheque: the remaining 210,000, received and then cleared ─────
    final chequeId = await dao3.addCheque(
      direction: ChequeDirection.received,
      amount: 210000,
      dueDate: DateTime.now().add(const Duration(days: 7)),
      number: '4521',
      bank: 'ملت',
      partyId: 'c1',
      asPaymentFor: 'c1',
    );
    expect(chequeId, isNotNull);
    expect(await dao.customerBalance('c1'), 0,
        reason: 'a received cheque settles the debt while it is in flight');

    expect(
      await dao3.transitionCheque(
        chequeId: chequeId!,
        to: ChequeStatus.deposited,
      ),
      isTrue,
    );
    expect(
      await dao3.transitionCheque(
        chequeId: chequeId,
        to: ChequeStatus.cleared,
      ),
      isTrue,
    );
    final cheques = await dao3.cheques(direction: ChequeDirection.received);
    expect(cheques.single.status, ChequeStatus.cleared);
    expect(cheques.single.amount, 210000);
    expect(await dao.customerBalance('c1'), 0,
        reason: 'clearing changes no money — it was already booked');

    // ── 6. Stock count: two units of oil are simply gone ────────────────
    final countId = await dao3.createStockCount();
    expect(countId, isNotNull);
    await dao3.setCountedQty(
      countId: countId!,
      productId: 'oil',
      countedMilli: 68000,
    );
    await dao3.setCountedQty(
      countId: countId,
      productId: 'filter',
      countedMilli: 45000,
    );
    final impact = await dao3.postStockCount(countId: countId);
    expect(impact, -60000, reason: '−2 × 30,000');

    oil = (await dao.product('oil'))!;
    filter = (await dao.product('filter'))!;
    expect(oil.stockMilliCached, 68000);
    expect(filter.stockMilliCached, 45000,
        reason: 'an exact count writes no adjustment');

    // ── 7. Expense: the day's rent ──────────────────────────────────────
    final rent = await dao3.addExpense(
      date: DateTime.now(),
      amount: 50000,
      method: PaymentMethod.cash,
      payee: 'اجاره',
    );
    expect(rent, isTrue);

    // ── 8. The report, against the hand column ──────────────────────────
    final report = await dao3.periodReport(
      ShopReportRange.day(DateTime.now()),
    );
    expect(report, isNotNull, reason: 'the report query must not fail');
    final figures = report!.figures;

    expect(figures.grossSales, 1510000);
    expect(figures.returnTotal, 0);
    expect(figures.discountTotal, 0);
    expect(figures.netSales, 1510000);
    expect(figures.cogs, 1000000);
    expect(figures.grossProfit, 510000);
    expect(figures.expenseTotal, 50000);
    expect(figures.netProfit, 460000, reason: 'the hand-written net profit');

    expect(report.invoiceCount, 2);
    expect(report.returnCount, 0);
    expect(report.averageTicket, 755000);
    expect(report.hasPreviousData, isFalse);
    expect(report.salesChangePercent, isNull);

    // Money received today: 900,000 + 100,000 + 300,000 cash, 210,000 cheque.
    expect(report.byMethod[PaymentMethod.cash], 1300000);
    expect(report.byMethod[PaymentMethod.cheque], 210000);
    expect(report.byMethod[PaymentMethod.other], isNull,
        reason: 'every rial of the invoices was settled today');

    expect(report.topProducts.map((r) => r.name), ['روغن', 'فیلتر']);
    expect(report.topProducts.first.total, 1350000);
    expect(report.topProducts.first.cost, 900000);
    expect(report.topProducts.first.profit, 450000);
    expect(report.topProducts.last.total, 160000);
    expect(report.topProducts.last.cost, 100000);
    expect(report.topProducts.last.profit, 60000);

    // ── 9. The books still close ────────────────────────────────────────
    expect(await dao.verifyIntegrity(), isEmpty);
    expect(await dao3.verifyIntegrity3(), isEmpty);

    // The count is a stock-truth correction, not a profit event: it moved the
    // shelf value down by 60,000 while COGS stayed on the sale snapshots.
    expect(
      ReportFigures.stockValuation([
        (stockMilli: oil.stockMilliCached, avgCost: oil.avgCost),
        (stockMilli: filter.stockMilliCached, avgCost: filter.avgCost),
      ]),
      2940000,
      reason: '68 × 30,000 + 45 × 20,000',
    );
    expect(
      ReportFigures.potentialSalesValue([
        (stockMilli: oil.stockMilliCached, sellPrice: oil.sellPrice),
        (stockMilli: filter.stockMilliCached, sellPrice: filter.sellPrice),
      ]),
      4500000,
      reason: '68 × 45,000 + 45 × 32,000',
    );
  });
}
