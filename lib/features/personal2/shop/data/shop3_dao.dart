import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/features/personal2/shop/data/shop3_tables.dart';
import 'package:tawheeed/features/personal2/shop/data/shop_dao.dart';
import 'package:tawheeed/features/personal2/shop/data/shop_tables.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop3_domain.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_domain.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_period_report.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_report_range.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Row models for the stage-3 tables.
class ShopSupplier {
  const ShopSupplier({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.note,
    required this.active,
  });

  final String id;
  final String name;
  final String phone;
  final String address;
  final String note;
  final bool active;
}

class ShopPurchase {
  const ShopPurchase({
    required this.id,
    required this.number,
    required this.date,
    required this.supplierId,
    required this.subtotal,
    required this.discountTotal,
    required this.extraCostTotal,
    required this.total,
    required this.paid,
    required this.dueDate,
    required this.status,
    required this.voidReason,
  });

  final String id;
  final String number;
  final DateTime date;
  final String? supplierId;
  final int subtotal;
  final int discountTotal;
  final int extraCostTotal;
  final int total;
  final int paid;
  final DateTime? dueDate;
  final String status;
  final String? voidReason;

  bool get isPosted => status == 'posted';
}

class ShopPurchaseItem {
  const ShopPurchaseItem({
    required this.id,
    required this.purchaseId,
    required this.productId,
    required this.nameSnapshot,
    required this.qtyMilli,
    required this.unitCost,
    required this.discount,
    required this.lineTotal,
    required this.allocatedExtra,
    required this.landedUnitCost,
    required this.prevAvgCost,
    required this.newAvgCost,
  });

  final String id;
  final String purchaseId;
  final String? productId;
  final String nameSnapshot;
  final int qtyMilli;
  final int unitCost;
  final int discount;
  final int lineTotal;
  final int allocatedExtra;
  final int landedUnitCost;
  final int prevAvgCost;
  final int newAvgCost;
}

class ShopExpense {
  const ShopExpense({
    required this.id,
    required this.date,
    required this.categoryId,
    required this.amount,
    required this.method,
    required this.payee,
    required this.note,
  });

  final String id;
  final DateTime date;
  final int? categoryId;
  final int amount;
  final PaymentMethod method;
  final String payee;
  final String note;
}

class ShopCheque {
  const ShopCheque({
    required this.id,
    required this.direction,
    required this.number,
    required this.bank,
    required this.amount,
    required this.dueDate,
    required this.partyType,
    required this.partyId,
    required this.status,
    required this.note,
    required this.paymentId,
  });

  final String id;
  final ChequeDirection direction;
  final String number;
  final String bank;
  final int amount;
  final DateTime dueDate;
  final String partyType;
  final String? partyId;
  final ChequeStatus status;
  final String note;

  /// The payment row this cheque created when taken as payment (null when it
  /// was not, or when the reversal has removed it).
  final String? paymentId;

  bool get inFlight =>
      status == ChequeStatus.pending || status == ChequeStatus.deposited;
}

class CashDayRow {
  const CashDayRow({
    required this.id,
    required this.date,
    required this.openedAt,
    required this.openingCash,
    required this.closedAt,
    required this.countedCash,
    required this.expectedCash,
    required this.difference,
    required this.note,
  });

  final String id;
  final DateTime date;
  final DateTime? openedAt;
  final int openingCash;
  final DateTime? closedAt;
  final int? countedCash;
  final int? expectedCash;
  final int? difference;
  final String note;

  bool get isOpen => closedAt == null;
}

class Shop3Dao {
  Shop3Dao(this.db, this._dao);

  final AppDatabase db;
  final ShopDao _dao;

  static const String _purchaseCounterKey = 'shop3_purchase_number';

  static DateTime _date(Object? v) =>
      DateTime.fromMillisecondsSinceEpoch((v as int?) ?? 0);

  /// Row → invoice, matching `ShopDao._invoice` (kept local: that mapper is
  /// private to its library, and this DAO is a separate one).
  static ShopInvoice _invoiceRow(dynamic r) => ShopInvoice(
        id: r.read<String>('id'),
        number: r.read<String>('number'),
        date: _date(r.read<int>('date')),
        kind: r.read<String>('kind'),
        customerId: r.readNullable<String>('customer_id'),
        subtotal: r.read<int>('subtotal'),
        discountTotal: r.read<int>('discount_total'),
        roundingAdj: r.read<int>('rounding_adj'),
        total: r.read<int>('total'),
        status: r.read<String>('status'),
        note: r.read<String>('note'),
        voidOf: r.readNullable<String>('void_of'),
        returnOf: r.readNullable<String>('return_of'),
        voidReason: r.readNullable<String>('void_reason'),
        createdAt: _date(r.read<int>('created_at')),
      );

  static String _id(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';
  static int _seq = 0;

  // ── Suppliers ────────────────────────────────────────────────────────

  Future<List<ShopSupplier>> suppliers({String? search}) async {
    try {
      final where = StringBuffer('WHERE active = 1');
      final vars = <Variable<Object>>[];
      if (search != null && search.trim().isNotEmpty) {
        where.write(' AND normalized_name LIKE ?');
        vars.add(Variable.withString('${search.trim().toLowerCase()}%'));
      }
      final rows = await db.customSelect(
        'SELECT * FROM ${Shop3Tables.supplier} $where '
        'ORDER BY normalized_name ASC',
        variables: vars,
      ).get();
      return [for (final r in rows) _supplier(r)];
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'suppliers read failed: $e');
      return const [];
    }
  }

  Future<ShopSupplier?> supplier(String id) async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${Shop3Tables.supplier} WHERE id = ?',
        variables: [Variable.withString(id)],
      ).get();
      if (rows.isEmpty) return null;
      return _supplier(rows.first);
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'supplier read failed: $e');
      return null;
    }
  }

  Future<bool> saveSupplier({
    required String id,
    required String name,
    String phone = '',
    String address = '',
    String note = '',
  }) async {
    if (name.trim().isEmpty) return false;
    try {
      final existing = await db.customSelect(
        'SELECT id FROM ${Shop3Tables.supplier} WHERE id = ?',
        variables: [Variable.withString(id)],
      ).get();
      if (existing.isEmpty) {
        await db.customStatement(
          'INSERT INTO ${Shop3Tables.supplier} '
          '(id, name, normalized_name, phone, address, note, active, created_at) '
          'VALUES (?, ?, ?, ?, ?, ?, 1, ?)',
          [
            id,
            name.trim(),
            name.trim(),
            phone.trim(),
            address.trim(),
            note.trim(),
            DateTime.now().millisecondsSinceEpoch,
          ],
        );
      } else {
        await db.customStatement(
          'UPDATE ${Shop3Tables.supplier} SET name = ?, normalized_name = ?, '
          'phone = ?, address = ?, note = ? WHERE id = ?',
          [
            name.trim(),
            name.trim(),
            phone.trim(),
            address.trim(),
            note.trim(),
            id,
          ],
        );
      }
      return true;
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'supplier save failed: $e');
      return false;
    }
  }

  /// The supplier's balance: SUM of their ledger entries (+ = WE owe THEM).
  Future<int> supplierBalance(String supplierId) async {
    try {
      final rows = await db.customSelect(
        'SELECT COALESCE(SUM(signed_amount), 0) AS total FROM '
        '${ShopTables.ledgerEntry} WHERE party_type = ? AND party_id = ?',
        variables: [
          Variable.withString('supplier'),
          Variable.withString(supplierId),
        ],
      ).get();
      return rows.first.read<int>('total');
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'supplier balance read failed: $e');
      return 0;
    }
  }

  Future<List<OpenPurchase>> openPurchases(String supplierId) async {
    try {
      final rows = await db.customSelect(
        'SELECT p.id, p.number, p.date, p.due_date, p.total, '
        'COALESCE((SELECT SUM(le.signed_amount) FROM '
        '${ShopTables.ledgerEntry} le WHERE le.ref_type = ? '
        'AND le.ref_id = p.id AND le.signed_amount < 0), 0) AS paid '
        'FROM ${Shop3Tables.purchase} p '
        'WHERE p.supplier_id = ? AND p.status = ?',
        variables: [
          Variable.withString('purchase'),
          Variable.withString(supplierId),
          Variable.withString('posted'),
        ],
      ).get();
      final out = <OpenPurchase>[];
      for (final r in rows) {
        // The purchase entry wrote +total (we owe); payments wrote −. The
        // remaining = total + paid (paid is negative-summed).
        final remaining = r.read<int>('total') + r.read<int>('paid');
        if (remaining > 0) {
          out.add(OpenPurchase(
            purchaseId: r.read<String>('id'),
            number: r.read<String>('number'),
            date: _date(r.read<int>('date')),
            dueDate: r.readNullable<int>('due_date') == null
                ? null
                : _date(r.read<int>('due_date')),
            remaining: remaining,
          ));
        }
      }
      return out;
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'open purchases read failed: $e');
      return const [];
    }
  }

  // ── Purchases: THE transaction ───────────────────────────────────────

  /// Posts a purchase. ONE transaction: number, purchase + items with landed
  /// costs and avg-cost before/after, stock movements (+qty) with the cached
  /// update, the payment (if any), the ledger entry for the credit portion,
  /// and the audit row.
  Future<ShopPurchase?> postPurchase({
    required List<PurchaseLine> lines,
    required ShopSupplier? supplier,
    required int extraCostTotal,
    required bool allocateExtras,
    required int paidNow,
    required PaymentMethod paidMethod,
    DateTime? dueDate,
    String note = '',
    required int marginPercent,
  }) async {
    final usable = [for (final l in lines) if (l.qtyMilli > 0) l];
    if (usable.isEmpty) {
      AppLogger.warning('Shop3Dao', 'purchase refused: empty cart');
      return null;
    }
    if (paidNow < 0) {
      AppLogger.warning('Shop3Dao', 'purchase refused: negative payment');
      return null;
    }
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final purchaseId = _id('pur');

    try {
      return await db.transaction<ShopPurchase?>(() async {
        // 1. Number from the shop's own counter (a separate one so purchase
        //    numbers never interleave with sale numbers).
        final counterRow = await db.customSelect(
          'SELECT next_invoice_number FROM ${ShopTables.settings} WHERE id = ?',
          variables: [Variable.withString(_purchaseCounterKey)],
        ).get();
        var next = 1;
        if (counterRow.isEmpty) {
          await db.customStatement(
            'INSERT INTO ${ShopTables.settings} (id, next_invoice_number) '
            'VALUES (?, 2)',
            [_purchaseCounterKey],
          );
        } else {
          next = counterRow.first.read<int>('next_invoice_number');
          await db.customStatement(
            'UPDATE ${ShopTables.settings} SET next_invoice_number = ? '
            'WHERE id = ?',
            [next + 1, _purchaseCounterKey],
          );
        }
        final number = 'P$next';

        // 2. Totals.
        final subtotal = usable.fold<int>(0, (s, l) => s + l.lineTotal + l.discount);
        final discountTotal = usable.fold<int>(0, (s, l) => s + l.discount);
        final total = subtotal - discountTotal + extraCostTotal;
        if (paidNow > total) {
          throw const _PostingFailure('پرداخت بیشتر از مبلغ خرید است.');
        }

        // 3. Extra-cost allocation.
        final allocations = allocateExtras
            ? allocateExtraCosts(extraCostTotal, usable)
            : List<int>.filled(usable.length, 0);

        // 4. Header.
        await db.customStatement(
          'INSERT INTO ${Shop3Tables.purchase} '
          '(id, number, date, supplier_id, subtotal, discount_total, '
          'extra_cost_total, total, paid, due_date, status, note, '
          'void_reason, created_at) '
          "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'posted', ?, NULL, ?)",
          [
            purchaseId,
            number,
            nowMs,
            supplier?.id,
            subtotal,
            discountTotal,
            extraCostTotal,
            total,
            paidNow,
            dueDate?.millisecondsSinceEpoch,
            note,
            nowMs,
          ],
        );

        // 5. Items: landed cost, avg-cost before/after, stock movement.
        for (var i = 0; i < usable.length; i++) {
          final line = usable[i];
          final extra = allocations[i];
          final landed = landedUnitCost(
            lineTotal: line.lineTotal,
            allocatedExtra: extra,
            qtyMilli: line.qtyMilli,
          );

          int prevAvg = 0;
          int stock = 0;
          if (line.trackStock) {
            final product = await _dao.product(line.productId);
            prevAvg = product?.avgCost ?? 0;
            stock = product?.stockMilliCached ?? 0;
          }
          final newAvg = avgCostAfterPurchase(
            currentStockMilli: stock,
            currentAvgCost: prevAvg,
            inboundQtyMilli: line.qtyMilli,
            landedUnitCost: landed,
          );

          await db.customStatement(
            'INSERT INTO ${Shop3Tables.purchaseItem} '
            '(id, purchase_id, product_id, name_snapshot, qty_milli, '
            'unit_cost, discount, line_total, allocated_extra, '
            'landed_unit_cost, prev_avg_cost, new_avg_cost) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [
              _id('pi'),
              purchaseId,
              line.productId,
              line.name,
              line.qtyMilli,
              line.unitCost,
              line.discount,
              line.lineTotal,
              extra,
              landed,
              prevAvg,
              newAvg,
            ],
          );

          if (line.trackStock) {
            await db.customStatement(
              'INSERT INTO ${ShopTables.stockMovement} '
              '(id, product_id, date, type, qty_milli, unit_cost, ref_type, '
              'ref_id, note, created_at) '
              "VALUES (?, ?, ?, 'purchase', ?, ?, 'purchase', ?, '', ?)",
              [
                _id('mv'),
                line.productId,
                nowMs,
                line.qtyMilli,
                landed,
                purchaseId,
                nowMs,
              ],
            );
            await db.customStatement(
              'UPDATE ${ShopTables.product} SET avg_cost = ?, '
              'buy_price_last = ?, stock_milli_cached = ? WHERE id = ?',
              [newAvg, landed, stock + line.qtyMilli, line.productId],
            );
          }
        }

        // 6. Payment at purchase (cash/card/transfer/cheque-issued).
        if (paidNow > 0) {
          await db.customStatement(
            'INSERT INTO ${ShopTables.payment} '
            '(id, date, direction, method, amount, party_type, party_id, '
            'invoice_id, note, created_at) '
            "VALUES (?, ?, 'out', ?, ?, ?, ?, NULL, ?, ?)",
            [
              _id('pay'),
              nowMs,
              paidMethod.wire,
              paidNow,
              supplier != null ? 'supplier' : 'none',
              supplier?.id,
              'خرید $number',
              nowMs,
            ],
          );
        }

        // 7. Ledger: +total (we owe), −paid now.
        if (supplier != null) {
          await _ledger(
            partyId: supplier.id,
            dateMs: nowMs,
            kind: 'purchase',
            signedAmount: total,
            refType: 'purchase',
            refId: purchaseId,
            note: number,
          );
          if (paidNow > 0) {
            await _ledger(
              partyId: supplier.id,
              dateMs: nowMs,
              kind: 'payment',
              signedAmount: -paidNow,
              refType: 'purchase',
              refId: purchaseId,
              note: 'پرداخت هنگام خرید',
            );
          }
        }

        // 8. Audit.
        await _audit(
          action: 'post_purchase',
          entity: 'purchase',
          refId: purchaseId,
          details: {
            'number': number,
            'total': total,
            'paid': paidNow,
            'supplier': supplier?.id,
          },
        );

        return await purchase(purchaseId);
      });
    } on _PostingFailure catch (e) {
      AppLogger.warning('Shop3Dao', 'purchase refused: ${e.message}');
      return null;
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'purchase post failed: $e');
      return null;
    }
  }

  /// Voids a posted purchase: stock out at the POSTED landed cost, supplier
  /// balance reversed, audit row. One transaction.
  Future<bool> voidPurchase({
    required String purchaseId,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) return false;
    try {
      return await db.transaction<bool>(() async {
        final rows = await db.customSelect(
          'SELECT * FROM ${Shop3Tables.purchase} WHERE id = ?',
          variables: [Variable.withString(purchaseId)],
        ).get();
        if (rows.isEmpty || rows.first.read<String>('status') != 'posted') {
          return false;
        }
        final items = await purchaseItems(purchaseId);
        final nowMs = DateTime.now().millisecondsSinceEpoch;

        await db.customStatement(
          'UPDATE ${Shop3Tables.purchase} SET status = ?, void_reason = ? '
          'WHERE id = ? AND status = ?',
          ['void', reason.trim(), purchaseId, 'posted'],
        );

        for (final item in items) {
          if (item.productId == null) continue;
          final product = await _dao.product(item.productId!);
          if (product == null || !product.trackStock) continue;
          // Stock OUT at the posted landed cost — the exact reversal of the
          // +qty movement the posting wrote.
          await db.customStatement(
            'INSERT INTO ${ShopTables.stockMovement} '
            '(id, product_id, date, type, qty_milli, unit_cost, ref_type, '
            'ref_id, note, created_at) '
            "VALUES (?, ?, ?, 'purchase', ?, ?, 'void_purchase', ?, ?, ?)",
            [
              _id('mv'),
              item.productId,
              nowMs,
              -item.qtyMilli,
              item.landedUnitCost,
              purchaseId,
              reason.trim(),
              nowMs,
            ],
          );
          await db.customStatement(
            'UPDATE ${ShopTables.product} SET stock_milli_cached = ? '
            'WHERE id = ?',
            [product.stockMilliCached - item.qtyMilli, item.productId],
          );
        }

        // Reverse every ledger entry referencing this purchase.
        final entries = await db.customSelect(
          'SELECT * FROM ${ShopTables.ledgerEntry} '
          "WHERE ref_type = 'purchase' AND ref_id = ?",
          variables: [Variable.withString(purchaseId)],
        ).get();
        for (final e in entries) {
          await _ledger(
            partyId: e.read<String>('party_id'),
            dateMs: nowMs,
            kind: 'purchase',
            signedAmount: -e.read<int>('signed_amount'),
            refType: 'void_purchase',
            refId: purchaseId,
            note: 'ابطال: ${reason.trim()}',
          );
        }

        await _audit(
          action: 'void_purchase',
          entity: 'purchase',
          refId: purchaseId,
          details: {'reason': reason.trim()},
        );
        return true;
      });
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'void purchase failed: $e');
      return false;
    }
  }

  /// «برگشت از خرید» — a return document referencing the original purchase.
  ///
  /// Quantity is capped at what was purchased (a return cannot exceed the
  /// purchase), stock leaves at the CURRENT average cost (SHOP_DOMAIN.md
  /// §Stage3), and the supplier's balance drops by the return value. One
  /// transaction, one audit row, its own PR-number.
  Future<ShopPurchase?> purchaseReturn({
    required String originalPurchaseId,
    required List<({String productId, int qtyMilli})> lines,
    required String reason,
  }) async {
    if (lines.isEmpty || reason.trim().isEmpty) return null;
    try {
      return await db.transaction<ShopPurchase?>(() async {
        final originalRows = await db.customSelect(
          'SELECT * FROM ${Shop3Tables.purchase} WHERE id = ?',
          variables: [Variable.withString(originalPurchaseId)],
        ).get();
        if (originalRows.isEmpty ||
            originalRows.first.read<String>('status') != 'posted') {
          return null;
        }
        final original = originalRows.first;
        final supplierId = original.readNullable<String>('supplier_id');
        final nowMs = DateTime.now().millisecondsSinceEpoch;

        // Cap each line at the purchased quantity (previous returns count).
        final originalNumber = original.read<String>('number');
        final capped =
            <({String productId, String name, int qtyMilli, int avgCost})>[];
        for (final line in lines) {
          final purchased = await db.customSelect(
            'SELECT COALESCE(SUM(qty_milli), 0) AS n FROM '
            '${Shop3Tables.purchaseItem} WHERE purchase_id = ? '
            'AND product_id = ?',
            variables: [
              Variable.withString(originalPurchaseId),
              Variable.withString(line.productId),
            ],
          ).get();
          final purchasedQty = purchased.first.read<int>('n');
          // Prior returns of THIS purchase: their movements reference the
          // return document, whose note carries «برگشت از خرید <number>».
          final returned = await db.customSelect(
            'SELECT COALESCE(SUM(sm.qty_milli), 0) AS n FROM '
            '${ShopTables.stockMovement} sm '
            'JOIN ${Shop3Tables.purchase} pr ON pr.id = sm.ref_id '
            "WHERE sm.type = 'purchase_return' AND pr.note LIKE ? "
            'AND sm.product_id = ?',
            variables: [
              Variable.withString('برگشت از خرید $originalNumber%'),
              Variable.withString(line.productId),
            ],
          ).get();
          final returnedQty = returned.first.read<int>('n').abs();
          final product = await _dao.product(line.productId);
          if (product == null) continue;
          // A return cannot exceed purchased − already returned.
          final remaining = purchasedQty - returnedQty;
          final qty = line.qtyMilli.clamp(0, remaining < 0 ? 0 : remaining);
          if (qty <= 0) continue;
          capped.add((
            productId: line.productId,
            name: product.name,
            qtyMilli: qty,
            avgCost: product.avgCost,
          ));
        }
        if (capped.isEmpty) return null;

        // Number from the same P-counter.
        final counterRow = await db.customSelect(
          'SELECT next_invoice_number FROM ${ShopTables.settings} WHERE id = ?',
          variables: [Variable.withString(_purchaseCounterKey)],
        ).get();
        final next = counterRow.isEmpty
            ? 1
            : counterRow.first.read<int>('next_invoice_number');
        await db.customStatement(
          'UPDATE ${ShopTables.settings} SET next_invoice_number = ? '
          'WHERE id = ?',
          [next + 1, _purchaseCounterKey],
        );
        final number = 'PR$next';

        final totalValue = capped.fold<int>(
            0, (s, l) => s + roundHalfUpDiv(l.qtyMilli * l.avgCost, 1000));

        final returnId = _id('prt');
        await db.customStatement(
          'INSERT INTO ${Shop3Tables.purchase} '
          '(id, number, date, supplier_id, subtotal, discount_total, '
          'extra_cost_total, total, paid, due_date, status, note, '
          'void_reason, created_at) '
          "VALUES (?, ?, ?, ?, ?, 0, 0, ?, 0, NULL, 'posted', ?, NULL, ?)",
          [
            returnId,
            number,
            nowMs,
            supplierId,
            totalValue,
            totalValue,
            'برگشت از خرید ${original.read<String>('number')}: ${reason.trim()}',
            nowMs,
          ],
        );
        // Mark the return kind on the note (kind column is sale-oriented; the
        // PR prefix + note carry the semantics for the list UI).

        for (final line in capped) {
          // Stock OUT at the current average cost.
          await db.customStatement(
            'INSERT INTO ${ShopTables.stockMovement} '
            '(id, product_id, date, type, qty_milli, unit_cost, ref_type, '
            "ref_id, note, created_at) "
            "VALUES (?, ?, ?, 'purchase_return', ?, ?, 'purchase_return', ?, ?, ?)",
            [
              _id('mv'),
              line.productId,
              nowMs,
              -line.qtyMilli,
              line.avgCost,
              returnId,
              reason.trim(),
              nowMs,
            ],
          );
          final stockRows = await db.customSelect(
            'SELECT stock_milli_cached AS s FROM ${ShopTables.product} '
            'WHERE id = ?',
            variables: [Variable.withString(line.productId)],
          ).get();
          final currentStock =
              stockRows.isEmpty ? 0 : stockRows.first.read<int>('s');
          await db.customStatement(
            'UPDATE ${ShopTables.product} SET stock_milli_cached = ? '
            'WHERE id = ?',
            [currentStock - line.qtyMilli, line.productId],
          );
        }

        if (supplierId != null) {
          // The shop owes LESS: a negative ledger entry (documented sign).
          await _ledger(
            partyId: supplierId,
            dateMs: nowMs,
            kind: 'purchase',
            signedAmount: -totalValue,
            refType: 'purchase_return',
            refId: returnId,
            note: 'برگشت از خرید $number',
          );
        }

        await _audit(
          action: 'purchase_return',
          entity: 'purchase',
          refId: returnId,
          details: {
            'original': originalPurchaseId,
            'value': totalValue,
            'reason': reason.trim(),
          },
        );

        return await purchase(returnId);
      });
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'purchase return failed: $e');
      return null;
    }
  }

  Future<ShopPurchase?> purchase(String id) async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${Shop3Tables.purchase} WHERE id = ?',
        variables: [Variable.withString(id)],
      ).get();
      if (rows.isEmpty) return null;
      return _purchase(rows.first);
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'purchase read failed: $e');
      return null;
    }
  }

  Future<List<ShopPurchase>> recentPurchases({int limit = 50}) async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${Shop3Tables.purchase} ORDER BY date DESC LIMIT ?',
        variables: [Variable.withInt(limit)],
      ).get();
      return [for (final r in rows) _purchase(r)];
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'purchases read failed: $e');
      return const [];
    }
  }

  Future<List<ShopPurchaseItem>> purchaseItems(String purchaseId) async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${Shop3Tables.purchaseItem} WHERE purchase_id = ? '
        'ORDER BY id ASC',
        variables: [Variable.withString(purchaseId)],
      ).get();
      return [for (final r in rows) _purchaseItem(r)];
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'purchase items read failed: $e');
      return const [];
    }
  }

  /// Pays a supplier: FIFO preview via the shared allocator, then one
  /// transaction (payment row + ledger slices + advance).
  Future<AllocationResult?> paySupplier({
    required String supplierId,
    required int amount,
    required PaymentMethod method,
    String note = '',
    String? chequeId,
  }) async {
    if (amount <= 0) return null;
    try {
      final open = await openPurchases(supplierId);
      final allocation = allocateSupplierPayment(
          payment: amount, openPurchases: open);
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await db.transaction(() async {
        await db.customStatement(
          'INSERT INTO ${ShopTables.payment} '
          '(id, date, direction, method, amount, party_type, party_id, '
          'invoice_id, note, created_at) '
          "VALUES (?, ?, 'out', ?, ?, 'supplier', ?, NULL, ?, ?)",
          [
            _id('pay'),
            nowMs,
            method.wire,
            amount,
            supplierId,
            note,
            nowMs,
          ],
        );
        for (final slice in allocation.slices) {
          await _ledger(
            partyId: supplierId,
            dateMs: nowMs,
            kind: 'payment',
            signedAmount: -slice.amount,
            refType: 'purchase',
            refId: slice.invoiceId,
            note: 'تسویه ${slice.invoiceNumber}',
          );
        }
        if (allocation.advance > 0) {
          await _ledger(
            partyId: supplierId,
            dateMs: nowMs,
            kind: 'payment',
            signedAmount: -allocation.advance,
            refType: '',
            refId: null,
            note: 'پیش‌پرداخت',
          );
        }
        await _audit(
          action: 'pay_supplier',
          entity: 'supplier',
          refId: supplierId,
          details: {'amount': amount, 'method': method.wire},
        );
      });
      return allocation;
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'pay supplier failed: $e');
      return null;
    }
  }

  // ── Cheques ──────────────────────────────────────────────────────────

  /// Records a cheque. When [asPaymentFor] is set (a received cheque taken
  /// from a customer), the payment + ledger entry are written NOW at pending
  /// — «چک در جریان».
  Future<String?> addCheque({
    required ChequeDirection direction,
    required int amount,
    required DateTime dueDate,
    String number = '',
    String bank = '',
    String? partyId,
    String partyType = 'customer',
    String note = '',
    String? asPaymentFor,
  }) async {
    if (amount <= 0) return null;
    final id = _id('chk');
    try {
      String? paymentId;
      await db.transaction(() async {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        await db.customStatement(
          'INSERT INTO ${Shop3Tables.cheque} '
          '(id, direction, number, bank, amount, due_date, party_type, '
          'party_id, status, status_changed_at, note, payment_id, created_at) '
          "VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?, NULL, ?)",
          [
            id,
            direction.wire,
            number,
            bank,
            amount,
            dueDate.millisecondsSinceEpoch,
            partyType,
            partyId,
            nowMs,
            note,
            nowMs,
          ],
        );

        // A received cheque taken as payment: the customer's balance drops
        // NOW; the money is «چک در جریان» until cleared/bounced.
        if (direction == ChequeDirection.received && asPaymentFor != null) {
          paymentId = _id('pay');
          await db.customStatement(
            'INSERT INTO ${ShopTables.payment} '
            '(id, date, direction, method, amount, party_type, party_id, '
            'invoice_id, note, created_at) '
            "VALUES (?, ?, 'in', 'cheque', ?, 'customer', ?, NULL, ?, ?)",
            [
              paymentId,
              nowMs,
              amount,
              asPaymentFor,
              'چک شماره $number',
              nowMs,
            ],
          );
          await _dao.adjustLedgerDirect(
            partyId: asPaymentFor,
            signedAmount: -amount,
            kind: 'payment',
            refType: 'cheque',
            refId: id,
            note: 'چک در جریان $number',
          );
        }

        await _audit(
          action: 'add_cheque',
          entity: 'cheque',
          refId: id,
          details: {
            'direction': direction.wire,
            'amount': amount,
            'asPayment': asPaymentFor != null,
          },
        );
      });
      return id;
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'add cheque failed: $e');
      return null;
    }
  }

  /// One legal transition, with its side effects. Returns false for illegal
  /// moves (the state machine is closed).
  Future<bool> transitionCheque({
    required String chequeId,
    required ChequeStatus to,
    String note = '',
    String? endorsedToSupplierId,
  }) async {
    try {
      return await db.transaction<bool>(() async {
        final rows = await db.customSelect(
          'SELECT * FROM ${Shop3Tables.cheque} WHERE id = ?',
          variables: [Variable.withString(chequeId)],
        ).get();
        if (rows.isEmpty) return false;
        final r = rows.first;
        final direction = ChequeDirection.fromWire(r.read<String>('direction'));
        final from = ChequeStatus.fromWire(r.read<String>('status'));
        if (!canTransition(direction: direction, from: from, to: to)) {
          return false;
        }
        final amount = r.read<int>('amount');
        final partyId = r.readNullable<String>('party_id');
        final paymentId = r.readNullable<String>('payment_id');
        final chequeNumber = r.read<String>('number');
        final nowMs = DateTime.now().millisecondsSinceEpoch;

        final effect = effectOf(
          direction: direction,
          to: to,
          wasUsedAsPayment: paymentId != null,
        );

        await db.customStatement(
          'UPDATE ${Shop3Tables.cheque} SET status = ?, '
          'status_changed_at = ?, cleared_date = ?, '
          'endorsed_to_supplier_id = ?, note = ? WHERE id = ?',
          [
            to.wire,
            nowMs,
            to == ChequeStatus.cleared ? nowMs : null,
            to == ChequeStatus.endorsed ? endorsedToSupplierId : null,
            note.isEmpty ? r.read<String>('note') : note,
            chequeId,
          ],
        );

        switch (effect) {
          case ChequeEffect.reverseCustomerPayment:
          case ChequeEffect.reverseCustomerPaymentCancel:
            // The customer's cheque bounced/cancelled: their payment reverses
            // exactly (balance restored), flagged.
            if (partyId != null) {
              await _dao.adjustLedgerDirect(
                partyId: partyId,
                signedAmount: amount,
                kind: 'adjustment',
                refType: 'cheque',
                refId: chequeId,
                note: 'برگشت چک $chequeNumber',
              );
              // Mark the original payment row as reversed by deleting the
              // linkage (the payment row itself stays for the audit trail).
              await db.customStatement(
                'UPDATE ${Shop3Tables.cheque} SET payment_id = NULL '
                'WHERE id = ?',
                [chequeId],
              );
            }
          case ChequeEffect.reverseSupplierPayment:
            // An issued cheque bounced: the supplier is owed again.
            if (partyId != null) {
              await _dao.adjustLedgerDirect(
                partyId: partyId,
                signedAmount: amount,
                kind: 'adjustment',
                refType: 'cheque',
                refId: chequeId,
                note: 'برگشت چک صادره $chequeNumber',
                partyType: 'supplier',
              );
            }
          case ChequeEffect.stateOnly:
            break;
        }

        await _audit(
          action: 'cheque_${to.wire}',
          entity: 'cheque',
          refId: chequeId,
          details: {
            'from': from.wire,
            'amount': amount,
            'note': note,
            'endorsedTo': endorsedToSupplierId,
          },
        );
        return true;
      });
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'cheque transition failed: $e');
      return false;
    }
  }

  Future<List<ShopCheque>> cheques({
    ChequeDirection? direction,
    bool onlyInFlight = false,
  }) async {
    try {
      final where = StringBuffer('WHERE 1=1');
      final vars = <Variable<Object>>[];
      if (direction != null) {
        where.write(' AND direction = ?');
        vars.add(Variable.withString(direction.wire));
      }
      if (onlyInFlight) {
        where.write(" AND status IN ('pending', 'deposited')");
      }
      final rows = await db.customSelect(
        'SELECT * FROM ${Shop3Tables.cheque} $where '
        'ORDER BY due_date ASC',
        variables: vars,
      ).get();
      return [for (final r in rows) _cheque(r)];
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'cheques read failed: $e');
      return const [];
    }
  }

  // ── Expenses ─────────────────────────────────────────────────────────

  Future<void> ensureExpenseCategoriesSeeded() async {
    try {
      final rows = await db
          .customSelect('SELECT COUNT(*) AS n FROM ${Shop3Tables.expenseCategory}')
          .get();
      if (rows.first.read<int>('n') > 0) return;
      for (var i = 0; i < defaultExpenseCategories.length; i++) {
        await db.customStatement(
          'INSERT INTO ${Shop3Tables.expenseCategory} (name, active, sort) '
          'VALUES (?, 1, ?)',
          [defaultExpenseCategories[i], i],
        );
      }
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'expense categories seed failed: $e');
    }
  }

  Future<List<({int id, String name})>> expenseCategories() async {
    try {
      final rows = await db.customSelect(
        'SELECT id, name FROM ${Shop3Tables.expenseCategory} '
        'WHERE active = 1 ORDER BY sort ASC',
      ).get();
      return [
        for (final r in rows) (id: r.read<int>('id'), name: r.read<String>('name')),
      ];
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'expense categories read failed: $e');
      return const [];
    }
  }

  Future<bool> addExpense({
    required DateTime date,
    int? categoryId,
    required int amount,
    required PaymentMethod method,
    String payee = '',
    String note = '',
    String? recurringRuleId,
  }) async {
    if (amount <= 0) return false;
    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await db.transaction(() async {
        await db.customStatement(
          'INSERT INTO ${Shop3Tables.expense} '
          '(id, date, category_id, amount, method, payee, note, '
          'recurring_rule_id, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            _id('exp'),
            date.millisecondsSinceEpoch,
            categoryId,
            amount,
            method.wire,
            payee,
            note,
            recurringRuleId,
            nowMs,
          ],
        );
        // Cash expenses leave the drawer immediately.
        if (method == PaymentMethod.cash) {
          await db.customStatement(
            'INSERT INTO ${Shop3Tables.cashAdjustment} '
            '(id, cash_day_id, date, kind, amount, note, created_at) '
            "VALUES (?, NULL, ?, 'expense_out', ?, ?, ?)",
            [
              _id('cja'),
              date.millisecondsSinceEpoch,
              -amount,
              note.isEmpty ? payee : note,
              nowMs,
            ],
          );
        }
        await _audit(
          action: 'add_expense',
          entity: 'expense',
          refId: '',
          details: {'amount': amount, 'method': method.wire},
        );
      });
      return true;
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'expense add failed: $e');
      return false;
    }
  }

  Future<List<ShopExpense>> expenses({
    required int fromMs,
    required int toMs,
    int? categoryId,
  }) async {
    try {
      final where =
          StringBuffer('WHERE date >= ? AND date <= ?');
      final vars = <Variable<Object>>[
        Variable.withInt(fromMs),
        Variable.withInt(toMs),
      ];
      if (categoryId != null) {
        where.write(' AND category_id = ?');
        vars.add(Variable.withInt(categoryId));
      }
      final rows = await db.customSelect(
        'SELECT * FROM ${Shop3Tables.expense} $where ORDER BY date DESC',
        variables: vars,
      ).get();
      return [for (final r in rows) _expense(r)];
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'expenses read failed: $e');
      return const [];
    }
  }

  Future<int> expenseTotal({required int fromMs, required int toMs}) async {
    try {
      final rows = await db.customSelect(
        'SELECT COALESCE(SUM(amount), 0) AS total FROM '
        '${Shop3Tables.expense} WHERE date >= ? AND date <= ?',
        variables: [Variable.withInt(fromMs), Variable.withInt(toMs)],
      ).get();
      return rows.first.read<int>('total');
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'expense total read failed: $e');
      return 0;
    }
  }

  // ── Cash register ────────────────────────────────────────────────────

  /// Opens (or returns) today's cash day, seeded from the previous day's
  /// counted cash.
  Future<CashDayRow> openCashDay({int? openingCash}) async {
    final dayStart = cashDayStart(DateTime.now());
    final dayMs = dayStart.millisecondsSinceEpoch;
    final dayId = 'cash_$dayMs';
    try {
      final existing = await db.customSelect(
        'SELECT * FROM ${Shop3Tables.cashDay} WHERE id = ?',
        variables: [Variable.withString(dayId)],
      ).get();
      if (existing.isNotEmpty) return _cashDay(existing.first);

      var opening = openingCash ?? 0;
      if (openingCash == null) {
        // Default: the previous day's counted cash.
        final prev = await db.customSelect(
          'SELECT counted_cash FROM ${Shop3Tables.cashDay} '
          'WHERE date < ? AND counted_cash IS NOT NULL '
          'ORDER BY date DESC LIMIT 1',
          variables: [Variable.withInt(dayMs)],
        ).get();
        if (prev.isNotEmpty) {
          opening = prev.first.read<int>('counted_cash');
        }
      }
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await db.customStatement(
        'INSERT INTO ${Shop3Tables.cashDay} '
        '(id, date, opened_at, opening_cash, note) VALUES (?, ?, ?, ?, \'\')',
        [
          dayId,
          dayMs,
          nowMs,
          opening,
        ],
      );
      await _audit(
        action: 'open_cash_day',
        entity: 'cash_day',
        refId: dayId,
        details: {'opening': opening},
      );
      final rows = await db.customSelect(
        'SELECT * FROM ${Shop3Tables.cashDay} WHERE id = ?',
        variables: [Variable.withString(dayId)],
      ).get();
      return _cashDay(rows.first);
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'open cash day failed: $e');
      rethrow;
    }
  }

  /// Computes expected cash for a day from the immutable rows: opening +
  /// cash-in (sales cash + customer cash receipts) − cash-out (supplier cash
  /// + cash expenses) ± adjustments.
  Future<int> expectedCashForDay(DateTime day) async {
    final from = cashDayStart(day).millisecondsSinceEpoch;
    final to = from + const Duration(days: 1).inMilliseconds - 1;
    final cashDay = await _cashDayFor(day);
    final opening = cashDay?.openingCash ?? 0;

    Future<int> sum(String sql, List<Variable<Object>> vars) async {
      final rows = await db.customSelect(sql, variables: vars).get();
      return rows.first.read<int>('t');
    }

    // Cash IN: sale payments (direction in, method cash) + customer receipts.
    final cashIn = await sum(
      'SELECT COALESCE(SUM(amount), 0) AS t FROM ${ShopTables.payment} '
      "WHERE date >= ? AND date <= ? AND direction = 'in' AND method = 'cash'",
      [Variable.withInt(from), Variable.withInt(to)],
    );
    // Cash OUT: supplier payments.
    final cashOut = await sum(
      'SELECT COALESCE(SUM(amount), 0) AS t FROM ${ShopTables.payment} '
      "WHERE date >= ? AND date <= ? AND direction = 'out' AND method = 'cash'",
      [Variable.withInt(from), Variable.withInt(to)],
    );
    // Adjustments (owner withdraw/deposit/other + expense rows I record).
    final adjustments = await sum(
      'SELECT COALESCE(SUM(amount), 0) AS t FROM '
      '${Shop3Tables.cashAdjustment} WHERE date >= ? AND date <= ?',
      [Variable.withInt(from), Variable.withInt(to)],
    );

    return expectedCash(
      openingCash: opening,
      cashIn: cashIn,
      cashOut: cashOut,
      adjustments: adjustments,
    );
  }

  /// Closes the day: records counted cash and the difference — never an
  /// auto-correction.
  Future<bool> closeCashDay({
    required DateTime day,
    required int countedCash,
    String note = '',
  }) async {
    try {
      // A closed day is frozen: check BEFORE updating, because a raw
      // UPDATE reports nothing about rows affected and a second close would
      // silently overwrite the recorded difference.
      final existing = await _cashDayFor(day);
      if (existing == null || !existing.isOpen) return false;
      final expected = await expectedCashForDay(day);
      final dayId = 'cash_${cashDayStart(day).millisecondsSinceEpoch}';
      final diff = cashDifference(
          countedCash: countedCash, expectedCash: expected);
      await db.customStatement(
        'UPDATE ${Shop3Tables.cashDay} SET closed_at = ?, counted_cash = ?, '
        'expected_cash = ?, difference = ?, note = ? '
        'WHERE id = ? AND closed_at IS NULL',
        [
          DateTime.now().millisecondsSinceEpoch,
          countedCash,
          expected,
          diff,
          note,
          dayId,
        ],
      );
      await _audit(
        action: 'close_cash_day',
        entity: 'cash_day',
        refId: dayId,
        details: {'counted': countedCash, 'expected': expected, 'diff': diff},
      );
      return true;
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'close cash day failed: $e');
      return false;
    }
  }

  Future<CashDayRow?> _cashDayFor(DateTime day) async {
    final dayId = 'cash_${cashDayStart(day).millisecondsSinceEpoch}';
    final rows = await db.customSelect(
      'SELECT * FROM ${Shop3Tables.cashDay} WHERE id = ?',
      variables: [Variable.withString(dayId)],
    ).get();
    if (rows.isEmpty) return null;
    return _cashDay(rows.first);
  }

  Future<CashDayRow?> cashDayToday() async => _cashDayFor(DateTime.now());

  Future<List<CashDayRow>> cashDayHistory({int limit = 30}) async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${Shop3Tables.cashDay} ORDER BY date DESC LIMIT ?',
        variables: [Variable.withInt(limit)],
      ).get();
      return [for (final r in rows) _cashDay(r)];
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'cash history read failed: $e');
      return const [];
    }
  }

  // ── Stock count ──────────────────────────────────────────────────────

  /// Creates an open count with one line per in-scope tracked product.
  Future<String?> createStockCount({int? categoryId}) async {
    final id = _id('cnt');
    try {
      final products = await _dao.products(limit: 100000);
      final scoped = categoryId == null
          ? products.where((p) => p.trackStock && p.active)
          : products.where((p) =>
              p.trackStock && p.active && p.categoryId == categoryId);
      if (scoped.isEmpty) return null;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await db.transaction(() async {
        await db.customStatement(
          'INSERT INTO ${Shop3Tables.stockCount} '
          '(id, date, scope, category_id, status, note, created_at) '
          "VALUES (?, ?, ?, ?, 'open', '', ?)",
          [
            id,
            nowMs,
            categoryId == null ? 'all' : 'category',
            categoryId,
            nowMs,
          ],
        );
        for (final p in scoped) {
          await db.customStatement(
            'INSERT INTO ${Shop3Tables.stockCountLine} '
            '(id, count_id, product_id, system_qty_milli, counted_qty_milli) '
            'VALUES (?, ?, ?, ?, NULL)',
            [_id('cl'), id, p.id, p.stockMilliCached],
          );
        }
        await _audit(
          action: 'create_stock_count',
          entity: 'stock_count',
          refId: id,
          details: {'lines': scoped.length},
        );
      });
      return id;
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'stock count create failed: $e');
      return null;
    }
  }

  /// Records one counted quantity.
  Future<bool> setCountedQty({
    required String countId,
    required String productId,
    required int countedMilli,
  }) async {
    try {
      await db.customStatement(
        'UPDATE ${Shop3Tables.stockCountLine} SET counted_qty_milli = ? '
        'WHERE count_id = ? AND product_id = ?',
        [countedMilli, countId, productId],
      );
      return true;
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'counted qty set failed: $e');
      return false;
    }
  }

  /// Posts the count: adjustment movements for the differences + cached
  /// updates + the value impact — one transaction, after confirmation.
  Future<int?> postStockCount({required String countId}) async {
    try {
      return await db.transaction<int?>(() async {
        final countRows = await db.customSelect(
          'SELECT * FROM ${Shop3Tables.stockCount} WHERE id = ?',
          variables: [Variable.withString(countId)],
        ).get();
        if (countRows.isEmpty ||
            countRows.first.read<String>('status') != 'open') {
          return null;
        }
        final lines = await db.customSelect(
          'SELECT * FROM ${Shop3Tables.stockCountLine} WHERE count_id = ? '
          'AND counted_qty_milli IS NOT NULL',
          variables: [Variable.withString(countId)],
        ).get();
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        var valueImpact = 0;
        var adjusted = 0;

        for (final line in lines) {
          final productId = line.read<String>('product_id');
          final counted = line.read<int>('counted_qty_milli');
          final system = line.read<int>('system_qty_milli');
          final diff = counted - system;
          if (diff == 0) continue;
          final product = await _dao.product(productId);
          if (product == null) continue;

          await db.customStatement(
            'INSERT INTO ${ShopTables.stockMovement} '
            '(id, product_id, date, type, qty_milli, unit_cost, ref_type, '
            'ref_id, note, created_at) '
            "VALUES (?, ?, ?, 'adjustment', ?, ?, 'stock_count', ?, "
            "'انبارگردانی', ?)",
            [
              _id('mv'),
              productId,
              nowMs,
              diff,
              product.avgCost,
              countId,
              nowMs,
            ],
          );
          await db.customStatement(
            'UPDATE ${ShopTables.product} SET stock_milli_cached = ? '
            'WHERE id = ?',
            [counted, productId],
          );
          valueImpact += roundHalfUpDiv(diff * product.avgCost, 1000);
          adjusted++;
        }

        await db.customStatement(
          'UPDATE ${Shop3Tables.stockCount} SET status = ?, value_impact = ? '
          'WHERE id = ?',
          ['posted', valueImpact, countId],
        );
        await _audit(
          action: 'post_stock_count',
          entity: 'stock_count',
          refId: countId,
          details: {'adjusted': adjusted, 'valueImpact': valueImpact},
        );
        return valueImpact;
      });
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'stock count post failed: $e');
      return null;
    }
  }

  // ── Extended integrity ───────────────────────────────────────────────

  /// Stage-3 additions to the integrity check: supplier balances have their
  /// ledger rows, cheque states are consistent, cash days close arithmetically.
  Future<List<IntegrityMismatch>> verifyIntegrity3() async {
    final problems = <IntegrityMismatch>[];
    try {
      // Credit purchases (supplier set) must have their ledger entry.
      final orphans = await db.customSelect(
        'SELECT p.number FROM ${Shop3Tables.purchase} p '
        'WHERE p.status = ? AND p.supplier_id IS NOT NULL '
        'AND NOT EXISTS (SELECT 1 FROM ${ShopTables.ledgerEntry} le '
        "WHERE le.ref_type = 'purchase' AND le.ref_id = p.id "
        'AND le.signed_amount > 0)',
        variables: [Variable.withString('posted')],
      ).get();
      for (final r in orphans) {
        problems.add(IntegrityMismatch(
          description: 'خرید اعتباری بدون سطر دفتر',
          details: 'خرید ${r.read<String>('number')}',
        ));
      }

      // Cheques: a payment-linked cheque must still have its payment row.
      final brokenCheques = await db.customSelect(
        'SELECT c.id FROM ${Shop3Tables.cheque} c '
        'WHERE c.payment_id IS NOT NULL AND c.status = ? '
        'AND NOT EXISTS (SELECT 1 FROM ${ShopTables.payment} p '
        'WHERE p.id = c.payment_id)',
        variables: [Variable.withString('pending')],
      ).get();
      for (final r in brokenCheques) {
        problems.add(IntegrityMismatch(
          description: 'چک در جریان بدون پرداختِ مرتبط',
          details: 'چک ${r.read<String>('id')}',
        ));
      }
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'integrity3 failed: $e');
      problems.add(IntegrityMismatch(
        description: 'بررسی سلامت داده‌ها ممکن نشد',
        details: '$e',
      ));
    }
    return problems;
  }

  // ── Reports (stage 3) ────────────────────────────────────────────────

  /// The whole «گزارش» tab for [range], in one pass over the immutable rows.
  ///
  /// Every figure is a SQL aggregate over *posted* rows, so a voided invoice
  /// is out of every number at once and the report can never disagree with
  /// the books. `cogs` is the Σ of the item cost snapshots — the cost the
  /// shop actually paid for the units sold — which is why gross profit here
  /// is reproducible months later, after any price edit.
  ///
  /// Returns null only when the database refuses the query; the caller shows
  /// the «بارگذاری ممکن نشد» state instead of a screen of zeros, because a
  /// report full of zeros reads like a real answer.
  Future<ShopPeriodReport?> periodReport(ShopReportRange range) async {
    try {
      final fromMs = range.fromMs;
      final toMs = range.toMsExclusive;

      Future<int> scalar(String sql, List<Variable<Object>> vars) async {
        final rows = await db.customSelect(sql, variables: vars).get();
        return rows.first.read<int>('v');
      }

      final grossSales = await scalar(
        'SELECT COALESCE(SUM(total), 0) AS v FROM ${ShopTables.invoice} '
        "WHERE date >= ? AND date < ? AND status = 'posted' AND kind = 'sale'",
        [Variable.withInt(fromMs), Variable.withInt(toMs)],
      );
      final returnRows = await db.customSelect(
        'SELECT COUNT(*) AS n, COALESCE(SUM(total), 0) AS v FROM '
        '${ShopTables.invoice} WHERE date >= ? AND date < ? '
        "AND status = 'posted' AND kind = 'sale_return'",
        variables: [Variable.withInt(fromMs), Variable.withInt(toMs)],
      ).get();
      final returnTotal = returnRows.first.read<int>('v');
      final returnCount = returnRows.first.read<int>('n');
      final discountTotal = await scalar(
        'SELECT COALESCE(SUM(discount_total), 0) AS v FROM '
        '${ShopTables.invoice} WHERE date >= ? AND date < ? '
        "AND status = 'posted' AND kind = 'sale'",
        [Variable.withInt(fromMs), Variable.withInt(toMs)],
      );
      final invoiceRows = await db.customSelect(
        'SELECT COUNT(*) AS n FROM ${ShopTables.invoice} '
        "WHERE date >= ? AND date < ? AND status = 'posted' AND kind = 'sale'",
        variables: [Variable.withInt(fromMs), Variable.withInt(toMs)],
      ).get();
      final invoiceCount = invoiceRows.first.read<int>('n');

      // COGS: the cost snapshots of the units that actually left the shelf.
      // Sale lines only — a return invoice's lines must not subtract twice,
      // the return's total is already in `returnTotal`.
      final cogs = await scalar(
        'SELECT COALESCE(SUM(i.qty_milli * i.unit_cost_snapshot / 1000), 0) '
        'AS v FROM ${ShopTables.invoiceItem} i JOIN ${ShopTables.invoice} v '
        'ON v.id = i.invoice_id WHERE v.date >= ? AND v.date < ? '
        "AND v.status = 'posted' AND v.kind = 'sale'",
        [Variable.withInt(fromMs), Variable.withInt(toMs)],
      );

      final expenseTotal =
          await this.expenseTotal(fromMs: fromMs, toMs: toMs - 1);

      // Payment mix of money received in the window: a sale already inside
      // `grossSales` that has not been paid is «نسیه» — the stage-2 tab showed
      // that remainder as a method, and dropping it here would make the bars
      // add up to less than the sales figure above them.
      final mixRows = await db.customSelect(
        'SELECT method, COALESCE(SUM(amount), 0) AS total FROM '
        '${ShopTables.payment} WHERE date >= ? AND date < ? '
        "AND direction = 'in' GROUP BY method",
        variables: [Variable.withInt(fromMs), Variable.withInt(toMs)],
      ).get();
      final paid = <PaymentMethod, int>{};
      for (final r in mixRows) {
        paid[PaymentMethod.fromWire(r.read<String>('method'))] =
            r.read<int>('total');
      }
      final byMethod = <PaymentMethod, int>{};
      for (final entry in paid.entries) {
        if (entry.value > 0) byMethod[entry.key] = entry.value;
      }
      final paidTotal = paid.values.fold<int>(0, (s, v) => s + v);
      final netSales = grossSales - returnTotal - discountTotal;
      final unpaid = netSales - paidTotal;
      if (unpaid > 0) byMethod[PaymentMethod.other] = unpaid;

      final topRows = await db.customSelect(
        'SELECT i.name_snapshot AS name, SUM(i.qty_milli) AS qty, '
        'SUM(i.line_total) AS total, '
        'SUM(i.qty_milli * i.unit_cost_snapshot / 1000) AS cost '
        'FROM ${ShopTables.invoiceItem} i JOIN ${ShopTables.invoice} v '
        'ON v.id = i.invoice_id WHERE v.date >= ? AND v.date < ? '
        "AND v.status = 'posted' AND v.kind = 'sale' "
        'GROUP BY i.name_snapshot ORDER BY total DESC LIMIT 8',
        variables: [Variable.withInt(fromMs), Variable.withInt(toMs)],
      ).get();
      final topProducts = [
        for (final r in topRows)
          ShopProductSale(
            name: r.read<String>('name'),
            qtyMilli: r.read<int>('qty'),
            total: r.read<int>('total'),
            cost: r.read<int>('cost'),
          ),
      ];

      // The previous window, same length, to say «۲۳٪ بیشتر از دورهٔ پیش».
      final previous = range.previous;
      final previousInvoices = await db.customSelect(
        'SELECT COUNT(*) AS n, COALESCE(SUM(total), 0) AS gross, '
        'COALESCE(SUM(CASE WHEN kind = \'sale_return\' THEN total ELSE 0 END), 0) '
        'AS returns, COALESCE(SUM(discount_total), 0) AS discount FROM '
        '${ShopTables.invoice} WHERE date >= ? AND date < ? '
        "AND status = 'posted'",
        variables: [
          Variable.withInt(previous.fromMs),
          Variable.withInt(previous.toMsExclusive),
        ],
      ).get();
      final prev = previousInvoices.first;
      final prevGross = prev.read<int>('gross');
      final prevReturns = prev.read<int>('returns');
      final prevDiscount = prev.read<int>('discount');

      return ShopPeriodReport(
        range: range,
        figures: ReportFigures(
          grossSales: grossSales,
          returnTotal: returnTotal,
          discountTotal: discountTotal,
          cogs: cogs,
          expenseTotal: expenseTotal,
        ),
        invoiceCount: invoiceCount,
        returnCount: returnCount,
        byMethod: byMethod,
        topProducts: topProducts,
        previousNetSales: prevGross - prevReturns - prevDiscount,
        hasPreviousData: prev.read<int>('n') > 0,
      );
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'period report failed: $e');
      return null;
    }
  }

  /// Products that sold nothing inside [range] but are still on the shelf.
  ///
  /// `track_stock = 1` and `stock_milli_cached > 0` keep services and empty
  /// shelves out of the list — «کندگرد» means dead money, and a product with
  /// no stock is not holding any. `last_sold_at` is maintained by the posting
  /// path; a null one means it has never sold.
  Future<List<ShopSlowMover>> slowMovers(
    ShopReportRange range, {
    int limit = 100,
  }) async {
    try {
      final rows = await db.customSelect(
        'SELECT id, name, stock_milli_cached AS stock, last_sold_at, '
        'sell_price, avg_cost FROM ${ShopTables.product} '
        'WHERE active = 1 AND track_stock = 1 AND stock_milli_cached > 0 '
        'AND (last_sold_at IS NULL OR last_sold_at < ?) '
        'ORDER BY (last_sold_at IS NOT NULL), last_sold_at, '
        'stock_milli_cached * avg_cost DESC LIMIT ?',
        variables: [Variable.withInt(range.fromMs), Variable.withInt(limit)],
      ).get();
      return [
        for (final r in rows)
          ShopSlowMover(
            id: r.read<String>('id'),
            name: r.read<String>('name'),
            stockMilli: r.read<int>('stock'),
            lastSoldAtMs: r.read<int?>('last_sold_at'),
            sellPrice: r.read<int>('sell_price'),
            avgCost: r.read<int>('avg_cost'),
          ),
      ];
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'slow movers read failed: $e');
      return const [];
    }
  }

  /// Invoices inside [range], newest first, for the tab's drill-down lists.
  ///
  /// [productName] narrows to the invoices that sold that product, and
  /// [method]/`creditOnly` narrow to one payment method (the mix bar's tap).
  /// The item and payment joins are EXISTS rather than joins so one invoice
  /// cannot appear twice in the list.
  Future<List<ShopInvoice>> rangeInvoices(
    ShopReportRange range, {
    String? productName,
    PaymentMethod? method,
    bool creditOnly = false,
    bool includeReturns = true,
    int limit = 300,
  }) async {
    try {
      final where = StringBuffer('WHERE v.status = ? AND v.date >= ? '
          'AND v.date < ?');
      final vars = <Variable<Object>>[
        Variable.withString('posted'),
        Variable.withInt(range.fromMs),
        Variable.withInt(range.toMsExclusive),
      ];
      if (!includeReturns) where.write(" AND v.kind = 'sale'");
      if (productName != null) {
        where.write(' AND EXISTS (SELECT 1 FROM ${ShopTables.invoiceItem} i '
            'WHERE i.invoice_id = v.id AND i.name_snapshot = ?)');
        vars.add(Variable.withString(productName));
      }
      if (creditOnly) {
        // Nothing came in for this invoice: not fully paid.
        where.write(' AND v.total > (SELECT COALESCE(SUM(p.amount), 0) '
            'FROM ${ShopTables.payment} p WHERE p.invoice_id = v.id '
            "AND p.direction = 'in')");
      } else if (method != null) {
        where.write(' AND EXISTS (SELECT 1 FROM ${ShopTables.payment} p '
            'WHERE p.invoice_id = v.id AND p.direction = ? '
            'AND p.method = ?)');
        vars
          ..add(Variable.withString('in'))
          ..add(Variable.withString(method.wire));
      }
      vars.add(Variable.withInt(limit));
      final rows = await db.customSelect(
        'SELECT * FROM ${ShopTables.invoice} v $where '
        'ORDER BY v.date DESC, v.number DESC LIMIT ?',
        variables: vars,
      ).get();
      return [for (final r in rows) _invoiceRow(r)];
    } catch (e) {
      AppLogger.warning('Shop3Dao', 'range invoices read failed: $e');
      return const [];
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────

  Future<void> _ledger({
    required String partyId,
    required int dateMs,
    required String kind,
    required int signedAmount,
    required String refType,
    required String? refId,
    required String note,
  }) async {
    await db.customStatement(
      'INSERT INTO ${ShopTables.ledgerEntry} '
      '(id, party_type, party_id, date, kind, signed_amount, ref_type, '
      'ref_id, note, created_at) '
      "VALUES (?, 'supplier', ?, ?, ?, ?, ?, ?, ?, ?)",
      [
        _id('le'),
        partyId,
        dateMs,
        kind,
        signedAmount,
        refType,
        refId,
        note,
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  Future<void> _audit({
    required String action,
    required String entity,
    required String refId,
    required Map<String, Object?> details,
  }) async {
    await db.customStatement(
      'INSERT INTO ${ShopTables.auditLog} '
      '(id, ts, action, entity, ref_id, details_json) VALUES (?, ?, ?, ?, ?, ?)',
      [
        _id('aud'),
        DateTime.now().millisecondsSinceEpoch,
        action,
        entity,
        refId,
        jsonEncode(details),
      ],
    );
  }

  static ShopSupplier _supplier(dynamic r) => ShopSupplier(
        id: r.read<String>('id'),
        name: r.read<String>('name'),
        phone: r.read<String>('phone'),
        address: r.read<String>('address'),
        note: r.read<String>('note'),
        active: r.read<int>('active') == 1,
      );

  static ShopPurchase _purchase(dynamic r) => ShopPurchase(
        id: r.read<String>('id'),
        number: r.read<String>('number'),
        date: _date(r.read<int>('date')),
        supplierId: r.readNullable<String>('supplier_id'),
        subtotal: r.read<int>('subtotal'),
        discountTotal: r.read<int>('discount_total'),
        extraCostTotal: r.read<int>('extra_cost_total'),
        total: r.read<int>('total'),
        paid: r.read<int>('paid'),
        dueDate: r.readNullable<int>('due_date') == null
            ? null
            : _date(r.read<int>('due_date')),
        status: r.read<String>('status'),
        voidReason: r.readNullable<String>('void_reason'),
      );

  static ShopPurchaseItem _purchaseItem(dynamic r) => ShopPurchaseItem(
        id: r.read<String>('id'),
        purchaseId: r.read<String>('purchase_id'),
        productId: r.readNullable<String>('product_id'),
        nameSnapshot: r.read<String>('name_snapshot'),
        qtyMilli: r.read<int>('qty_milli'),
        unitCost: r.read<int>('unit_cost'),
        discount: r.read<int>('discount'),
        lineTotal: r.read<int>('line_total'),
        allocatedExtra: r.read<int>('allocated_extra'),
        landedUnitCost: r.read<int>('landed_unit_cost'),
        prevAvgCost: r.read<int>('prev_avg_cost'),
        newAvgCost: r.read<int>('new_avg_cost'),
      );

  static ShopExpense _expense(dynamic r) => ShopExpense(
        id: r.read<String>('id'),
        date: _date(r.read<int>('date')),
        categoryId: r.readNullable<int>('category_id'),
        amount: r.read<int>('amount'),
        method: PaymentMethod.fromWire(r.read<String>('method')),
        payee: r.read<String>('payee'),
        note: r.read<String>('note'),
      );

  static ShopCheque _cheque(dynamic r) => ShopCheque(
        id: r.read<String>('id'),
        direction: ChequeDirection.fromWire(r.read<String>('direction')),
        number: r.read<String>('number'),
        bank: r.read<String>('bank'),
        amount: r.read<int>('amount'),
        dueDate: _date(r.read<int>('due_date')),
        partyType: r.read<String>('party_type'),
        partyId: r.readNullable<String>('party_id'),
        status: ChequeStatus.fromWire(r.read<String>('status')),
        note: r.read<String>('note'),
        paymentId: r.readNullable<String>('payment_id'),
      );

  static CashDayRow _cashDay(dynamic r) => CashDayRow(
        id: r.read<String>('id'),
        date: _date(r.read<int>('date')),
        openedAt: r.readNullable<int>('opened_at') == null
            ? null
            : _date(r.read<int>('opened_at')),
        openingCash: r.read<int>('opening_cash'),
        closedAt: r.readNullable<int>('closed_at') == null
            ? null
            : _date(r.read<int>('closed_at')),
        countedCash: r.readNullable<int>('counted_cash'),
        expectedCash: r.readNullable<int>('expected_cash'),
        difference: r.readNullable<int>('difference'),
        note: r.read<String>('note'),
      );
}

class _PostingFailure implements Exception {
  const _PostingFailure(this.message);
  final String message;

  @override
  String toString() => '_PostingFailure: $message';
}

final shop3DaoProvider = Provider<Shop3Dao>(
  (ref) => Shop3Dao(ref.read(appDatabaseProvider), ref.read(shopDaoProvider)),
);
