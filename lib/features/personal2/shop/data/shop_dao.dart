import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/features/personal2/shop/data/shop_tables.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_domain.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// ─────────────────────────────────────────────────────────────────
/// Row models (light, immutable; the DB is raw SQL so these are hand-mapped)
/// ─────────────────────────────────────────────────────────────────

class ShopProduct {
  const ShopProduct({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.unitId,
    required this.sellPrice,
    required this.buyPriceLast,
    required this.avgCost,
    required this.minStockMilli,
    required this.trackStock,
    required this.active,
    required this.note,
    required this.stockMilliCached,
    required this.isFavorite,
    this.lastSoldAt,
  });

  final String id;
  final String name;
  final int? categoryId;
  final int? unitId;
  final int sellPrice;
  final int buyPriceLast;
  final int avgCost;
  final int? minStockMilli;
  final bool trackStock;
  final bool active;
  final String note;
  final int stockMilliCached;
  final bool isFavorite;
  final DateTime? lastSoldAt;
}

class ShopCustomer {
  const ShopCustomer({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.note,
    required this.creditLimit,
    required this.active,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final String address;
  final String note;
  final int? creditLimit;
  final bool active;
  final DateTime createdAt;
}

class ShopInvoice {
  const ShopInvoice({
    required this.id,
    required this.number,
    required this.date,
    required this.kind,
    required this.customerId,
    required this.subtotal,
    required this.discountTotal,
    required this.roundingAdj,
    required this.total,
    required this.status,
    required this.note,
    required this.voidOf,
    required this.returnOf,
    required this.voidReason,
    required this.createdAt,
  });

  final String id;
  final String number;
  final DateTime date;
  final String kind; // sale | sale_return
  final String? customerId;
  final int subtotal;
  final int discountTotal;
  final int roundingAdj;
  final int total;
  final String status; // posted | void | held
  final String note;
  final String? voidOf;
  final String? returnOf;
  final String? voidReason;
  final DateTime createdAt;

  bool get isPosted => status == 'posted';
  bool get isVoid => status == 'void';
  bool get isReturn => kind == 'sale_return';
}

class ShopInvoiceItem {
  const ShopInvoiceItem({
    required this.id,
    required this.invoiceId,
    required this.productId,
    required this.nameSnapshot,
    required this.unitSnapshot,
    required this.qtyMilli,
    required this.unitPrice,
    required this.discount,
    required this.lineTotal,
    required this.unitCostSnapshot,
  });

  final String id;
  final String invoiceId;
  final String? productId;
  final String nameSnapshot;
  final String unitSnapshot;
  final int qtyMilli;
  final int unitPrice;
  final int discount;
  final int lineTotal;
  final int unitCostSnapshot;
}

class ShopSettingsRow {
  const ShopSettingsRow({
    this.shopName = '',
    this.phone = '',
    this.address = '',
    this.invoicePrefix = '',
    this.nextInvoiceNumber = 1,
    this.roundingStep = 0,
    this.allowNegativeStock = true,
    this.creditLimitMode = CreditLimitMode.warn,
    this.allowPriceEdit = true,
    this.lowStockDefault = 3,
    this.hideBalances = false,
    this.receiptFooterText = '',
    this.logoPath,
    this.beepOnScan = true,
    this.vibrateOnScan = true,
    this.remindersEnabled = false,
    this.lowStockSummary = true,
    this.overdueSummary = false,
    this.summaryMinutes = 1260,
    this.quietStartMinutes = 1320,
    this.quietEndMinutes = 420,
  });

  final String shopName;
  final String phone;
  final String address;
  final String invoicePrefix;
  final int nextInvoiceNumber;
  final int roundingStep;
  final bool allowNegativeStock;
  final CreditLimitMode creditLimitMode;
  final bool allowPriceEdit;
  final int lowStockDefault;
  final bool hideBalances;
  final String receiptFooterText;
  final String? logoPath;
  final bool beepOnScan;
  final bool vibrateOnScan;
  final bool remindersEnabled;
  final bool lowStockSummary;
  final bool overdueSummary;
  final int summaryMinutes;
  final int quietStartMinutes;
  final int quietEndMinutes;

  /// A tolerable copy: the settings row has 22 fields and the settings screen
  /// edits a few at a time. Named `copyWith2` because drift's generated code
  /// owns `copyWith` on table classes and a same-named member here invites a
  /// shadowing bug.
  ShopSettingsRow copyWith2({
    String? shopName,
    String? phone,
    String? address,
    String? invoicePrefix,
    int? nextInvoiceNumber,
    int? roundingStep,
    bool? allowNegativeStock,
    CreditLimitMode? creditLimitMode,
    bool? allowPriceEdit,
    int? lowStockDefault,
    bool? hideBalances,
    String? receiptFooterText,
    String? logoPath,
    bool? beepOnScan,
    bool? vibrateOnScan,
    bool? remindersEnabled,
    bool? lowStockSummary,
    bool? overdueSummary,
    int? summaryMinutes,
    int? quietStartMinutes,
    int? quietEndMinutes,
  }) =>
      ShopSettingsRow(
        shopName: shopName ?? this.shopName,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        invoicePrefix: invoicePrefix ?? this.invoicePrefix,
        nextInvoiceNumber: nextInvoiceNumber ?? this.nextInvoiceNumber,
        roundingStep: roundingStep ?? this.roundingStep,
        allowNegativeStock: allowNegativeStock ?? this.allowNegativeStock,
        creditLimitMode: creditLimitMode ?? this.creditLimitMode,
        allowPriceEdit: allowPriceEdit ?? this.allowPriceEdit,
        lowStockDefault: lowStockDefault ?? this.lowStockDefault,
        hideBalances: hideBalances ?? this.hideBalances,
        receiptFooterText: receiptFooterText ?? this.receiptFooterText,
        logoPath: logoPath ?? this.logoPath,
        beepOnScan: beepOnScan ?? this.beepOnScan,
        vibrateOnScan: vibrateOnScan ?? this.vibrateOnScan,
        remindersEnabled: remindersEnabled ?? this.remindersEnabled,
        lowStockSummary: lowStockSummary ?? this.lowStockSummary,
        overdueSummary: overdueSummary ?? this.overdueSummary,
        summaryMinutes: summaryMinutes ?? this.summaryMinutes,
        quietStartMinutes: quietStartMinutes ?? this.quietStartMinutes,
        quietEndMinutes: quietEndMinutes ?? this.quietEndMinutes,
      );
}

class LedgerRow {
  const LedgerRow({
    required this.id,
    required this.partyId,
    required this.date,
    required this.kind,
    required this.signedAmount,
    required this.refType,
    required this.refId,
    required this.note,
  });

  final String id;
  final String partyId;
  final DateTime date;
  final String kind;
  final int signedAmount;
  final String refType;
  final String? refId;
  final String note;
}

/// A mismatch found by [ShopDao.verifyIntegrity].
class IntegrityMismatch {
  const IntegrityMismatch({required this.description, required this.details});

  final String description;
  final String details;

  @override
  String toString() => '$description: $details';
}

/// The result of a posting: the invoice as stored, for the receipt.
class PostedInvoice {
  const PostedInvoice({required this.invoice, required this.items});

  final ShopInvoice invoice;
  final List<ShopInvoiceItem> items;
}

/// Thrown inside the posting transaction to roll everything back — and by the
/// atomicity test deliberately.
class PostingException implements Exception {
  const PostingException(this.message);
  final String message;

  @override
  String toString() => 'PostingException: $message';
}

/// ─────────────────────────────────────────────────────────────────
/// The DAO
/// ─────────────────────────────────────────────────────────────────

/// Raw-SQL access to the shop tables.
///
/// THE rule: every multi-row write (posting, void, return, payment with
/// allocations, bulk price change) runs inside ONE `db.transaction`, so a
/// failure mid-way leaves nothing half-written — pinned by the atomicity test.
class ShopDao {
  ShopDao(this.db);

  final AppDatabase db;

  static const String settingsId = 'shop';

  static DateTime _date(Object? v) => DateTime.fromMillisecondsSinceEpoch(
      (v as int?) ?? 0);

  /// Monotonic id factory. A microsecond stamp alone collided inside tight
  /// loops (two price-change rows in the same microsecond), so the counter
  /// disambiguates ids minted within the same run.
  int _seq = 0;
  String _id(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  // ── Settings & seed ──────────────────────────────────────────────────

  Future<ShopSettingsRow> settings() async {
    const fallback = ShopSettingsRow();
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${ShopTables.settings} WHERE id = ?',
        variables: [Variable.withString(settingsId)],
      ).get();
      if (rows.isEmpty) return fallback;
      final r = rows.first;
      return ShopSettingsRow(
        shopName: r.read<String>('shop_name'),
        phone: r.read<String>('phone'),
        address: r.read<String>('address'),
        invoicePrefix: r.read<String>('invoice_prefix'),
        nextInvoiceNumber: r.read<int>('next_invoice_number'),
        roundingStep: r.read<int>('rounding_step'),
        allowNegativeStock: r.read<int>('allow_negative_stock') == 1,
        creditLimitMode:
            CreditLimitMode.fromWire(r.read<String>('credit_limit_mode')),
        allowPriceEdit: r.read<int>('allow_price_edit') == 1,
        lowStockDefault: r.read<int>('low_stock_default'),
        hideBalances: r.read<int>('hide_balances') == 1,
        receiptFooterText: r.read<String>('receipt_footer_text'),
        logoPath: r.readNullable<String>('logo_path'),
        beepOnScan: r.read<int>('beep_on_scan') == 1,
        vibrateOnScan: r.read<int>('vibrate_on_scan') == 1,
        remindersEnabled: r.read<int>('reminders_enabled') == 1,
        lowStockSummary: r.read<int>('low_stock_summary') == 1,
        overdueSummary: r.read<int>('overdue_summary') == 1,
        summaryMinutes: r.read<int>('summary_minutes'),
        quietStartMinutes: r.read<int>('quiet_start_minutes'),
        quietEndMinutes: r.read<int>('quiet_end_minutes'),
      );
    } catch (e) {
      AppLogger.warning('ShopDao', 'settings read failed: $e');
      return fallback;
    }
  }

  Future<void> saveSettings(ShopSettingsRow s) async {
    await db.customStatement(
      'INSERT OR REPLACE INTO ${ShopTables.settings} '
      '(id, shop_name, phone, address, invoice_prefix, next_invoice_number, '
      'rounding_step, allow_negative_stock, credit_limit_mode, '
      'allow_price_edit, low_stock_default, hide_balances, '
      'receipt_footer_text, logo_path, beep_on_scan, vibrate_on_scan, '
      'reminders_enabled, low_stock_summary, overdue_summary, '
      'summary_minutes, quiet_start_minutes, quiet_end_minutes) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        settingsId,
        s.shopName,
        s.phone,
        s.address,
        s.invoicePrefix,
        s.nextInvoiceNumber,
        s.roundingStep,
        s.allowNegativeStock ? 1 : 0,
        s.creditLimitMode.wire,
        s.allowPriceEdit ? 1 : 0,
        s.lowStockDefault,
        s.hideBalances ? 1 : 0,
        s.receiptFooterText,
        s.logoPath,
        s.beepOnScan ? 1 : 0,
        s.vibrateOnScan ? 1 : 0,
        s.remindersEnabled ? 1 : 0,
        s.lowStockSummary ? 1 : 0,
        s.overdueSummary ? 1 : 0,
        s.summaryMinutes,
        s.quietStartMinutes,
        s.quietEndMinutes,
      ],
    );
  }

  /// Seeds the default units AND the settings row (idempotent) on first open.
  ///
  /// The settings row must exist before the FIRST sale: the poster reads
  /// `next_invoice_number` from it inside the transaction, and a missing row
  /// made every invoice allocate number «1» — the second post died on the
  /// number's UNIQUE index (caught by the numbering test).
  Future<void> ensureSeeded() async {
    try {
      await db.customStatement(
        'INSERT OR IGNORE INTO ${ShopTables.settings} (id) VALUES (?)',
        [settingsId],
      );
      final existing = await db
          .customSelect('SELECT COUNT(*) AS n FROM ${ShopTables.unit}')
          .get();
      if (existing.first.read<int>('n') > 0) return;
      const units = [
        ('عدد', 'عدد', 0),
        ('کیلوگرم', 'kg', 1),
        ('گرم', 'g', 1),
        ('بسته', 'بسته', 0),
        ('کارتن', 'کارتن', 0),
        ('لیتر', 'L', 1),
        ('متر', 'm', 1),
      ];
      for (final (name, symbol, fraction) in units) {
        await db.customStatement(
          'INSERT INTO ${ShopTables.unit} (name, symbol, allow_fraction) '
          'VALUES (?, ?, ?)',
          [name, symbol, fraction],
        );
      }
    } catch (e) {
      AppLogger.warning('ShopDao', 'seed failed: $e');
    }
  }

  /// id → display symbol for every unit. Lets the product list and the POS
  /// cart label quantities with the real unit (kg, L, بسته…) instead of the
  /// old hardcoded «عدد». Falls back to an empty map on an older install
  /// where the unit table has not been created yet.
  Future<Map<int, String>> unitSymbols() async {
    try {
      final rows = await db
          .customSelect('SELECT id, symbol FROM ${ShopTables.unit}')
          .get();
      return {
        for (final r in rows) r.read<int>('id'): r.read<String>('symbol'),
      };
    } catch (e) {
      AppLogger.warning('ShopDao', 'unitSymbols failed: $e');
      return const {};
    }
  }

  // ── Products ─────────────────────────────────────────────────────────

  Future<List<ShopProduct>> products({
    bool onlyActive = false,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final where = StringBuffer('WHERE 1=1');
      final vars = <Variable<Object>>[];
      if (onlyActive) {
        where.write(' AND active = 1');
      }
      if (search != null && search.trim().isNotEmpty) {
        where.write(' AND normalized_name LIKE ?');
        vars.add(Variable.withString('${search.trim().toLowerCase()}%'));
      }
      vars.add(Variable.withInt(limit));
      vars.add(Variable.withInt(offset));
      final rows = await db.customSelect(
        'SELECT * FROM ${ShopTables.product} $where '
        'ORDER BY is_favorite DESC, normalized_name ASC LIMIT ? OFFSET ?',
        variables: vars,
      ).get();
      return [for (final r in rows) _product(r)];
    } catch (e) {
      AppLogger.warning('ShopDao', 'products read failed: $e');
      return const [];
    }
  }

  Future<ShopProduct?> product(String id) async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${ShopTables.product} WHERE id = ?',
        variables: [Variable.withString(id)],
      ).get();
      if (rows.isEmpty) return null;
      return _product(rows.first);
    } catch (e) {
      AppLogger.warning('ShopDao', 'product read failed: $e');
      return null;
    }
  }

  Future<ShopProduct?> productByBarcode(String barcode) async {
    final normalized = barcode.trim();
    if (normalized.isEmpty) return null;
    try {
      final rows = await db.customSelect(
        'SELECT p.* FROM ${ShopTables.product} p '
        'JOIN ${ShopTables.productBarcode} b ON b.product_id = p.id '
        'WHERE b.barcode = ?',
        variables: [Variable.withString(normalized)],
      ).get();
      if (rows.isEmpty) return null;
      return _product(rows.first);
    } catch (e) {
      AppLogger.warning('ShopDao', 'barcode lookup failed: $e');
      return null;
    }
  }

  /// Saves a product. [openingStockMilli]/[openingCost] write the opening
  /// movement (and set avgCost) in the same transaction as the insert.
  Future<bool> saveProduct({
    required String id,
    required String name,
    required String normalizedName,
    int? categoryId,
    int? unitId,
    required int sellPrice,
    required int buyPrice,
    int? minStockMilli,
    required bool trackStock,
    required bool active,
    String note = '',
    int openingStockMilli = 0,
    int openingCost = 0,
    List<String> barcodes = const [],
  }) async {
    try {
      await db.transaction(() async {
        final existing = await db.customSelect(
          'SELECT avg_cost FROM ${ShopTables.product} WHERE id = ?',
          variables: [Variable.withString(id)],
        ).get();
        final isNew = existing.isEmpty;
        var avgCost = isNew ? 0 : existing.first.read<int>('avg_cost');

        if (isNew) {
          await db.customStatement(
            'INSERT INTO ${ShopTables.product} '
            '(id, name, normalized_name, category_id, unit_id, sell_price, '
            'buy_price_last, avg_cost, min_stock_milli, track_stock, active, '
            'note, stock_milli_cached, is_favorite, created_at) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?, 0, 0, ?)',
            [
              id,
              name,
              normalizedName,
              categoryId,
              unitId,
              sellPrice,
              buyPrice,
              minStockMilli,
              trackStock ? 1 : 0,
              active ? 1 : 0,
              note,
              DateTime.now().millisecondsSinceEpoch,
            ],
          );
        } else {
          await db.customStatement(
            'UPDATE ${ShopTables.product} SET name = ?, normalized_name = ?, '
            'category_id = ?, unit_id = ?, sell_price = ?, buy_price_last = ?, '
            'min_stock_milli = ?, track_stock = ?, active = ?, note = ? '
            'WHERE id = ?',
            [
              name,
              normalizedName,
              categoryId,
              unitId,
              sellPrice,
              buyPrice,
              minStockMilli,
              trackStock ? 1 : 0,
              active ? 1 : 0,
              note,
              id,
            ],
          );
        }

        // Opening stock: one movement + cached update + avgCost, atomically.
        if (isNew && openingStockMilli != 0) {
          final now = DateTime.now().millisecondsSinceEpoch;
          await db.customStatement(
            'INSERT INTO ${ShopTables.stockMovement} '
            '(id, product_id, date, type, qty_milli, unit_cost, ref_type, '
            'note, created_at) '
            "VALUES (?, ?, ?, 'opening', ?, ?, '', '', ?)",
            [
              _id('mv'),
              id,
              now,
              openingStockMilli,
              openingCost,
              now,
            ],
          );
          avgCost = avgCostAfter(
            currentStockMilli: 0,
            currentAvgCost: 0,
            inboundQtyMilli: openingStockMilli,
            inboundUnitCost: openingCost,
          );
          await db.customStatement(
            'UPDATE ${ShopTables.product} SET avg_cost = ?, '
            'stock_milli_cached = ? WHERE id = ?',
            [avgCost, openingStockMilli, id],
          );
        }

        // Barcodes: replace the set (UNIQUE index is the backstop).
        if (barcodes.isNotEmpty) {
          await db.customStatement(
            'DELETE FROM ${ShopTables.productBarcode} WHERE product_id = ?',
            [id],
          );
          for (final b in barcodes) {
            if (b.trim().isEmpty) continue;
            await db.customStatement(
              'INSERT INTO ${ShopTables.productBarcode} (product_id, barcode) '
              'VALUES (?, ?)',
              [id, b.trim()],
            );
          }
        }
      });
      return true;
    } catch (e) {
      AppLogger.warning('ShopDao', 'product save failed: $e');
      return false;
    }
  }

  Future<bool> setProductFavorite(String productId, bool favorite) async {
    try {
      await db.customStatement(
        'UPDATE ${ShopTables.product} SET is_favorite = ? WHERE id = ?',
        [favorite ? 1 : 0, productId],
      );
      return true;
    } catch (e) {
      AppLogger.warning('ShopDao', 'favorite failed: $e');
      return false;
    }
  }

  /// Low-stock products for the dashboard alert (indexed, paginated).
  Future<List<ShopProduct>> lowStockProducts({int limit = 20}) async {
    try {
      final settingsRow = await settings();
      final rows = await db.customSelect(
        'SELECT * FROM ${ShopTables.product} WHERE active = 1 '
        'AND track_stock = 1 AND '
        'stock_milli_cached <= COALESCE(min_stock_milli, ? * 1000) '
        'ORDER BY stock_milli_cached ASC LIMIT ?',
        variables: [
          Variable.withInt(settingsRow.lowStockDefault),
          Variable.withInt(limit),
        ],
      ).get();
      return [for (final r in rows) _product(r)];
    } catch (e) {
      AppLogger.warning('ShopDao', 'low stock read failed: $e');
      return const [];
    }
  }

  // ── Customers ────────────────────────────────────────────────────────

  Future<List<ShopCustomer>> customers({
    bool onlyActive = false,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final where = StringBuffer('WHERE 1=1');
      final vars = <Variable<Object>>[];
      if (onlyActive) where.write(' AND active = 1');
      if (search != null && search.trim().isNotEmpty) {
        where.write(' AND normalized_name LIKE ?');
        vars.add(Variable.withString('${search.trim().toLowerCase()}%'));
      }
      vars.add(Variable.withInt(limit));
      vars.add(Variable.withInt(offset));
      final rows = await db.customSelect(
        'SELECT * FROM ${ShopTables.customer} $where '
        'ORDER BY normalized_name ASC LIMIT ? OFFSET ?',
        variables: vars,
      ).get();
      return [for (final r in rows) _customer(r)];
    } catch (e) {
      AppLogger.warning('ShopDao', 'customers read failed: $e');
      return const [];
    }
  }

  Future<ShopCustomer?> customer(String id) async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${ShopTables.customer} WHERE id = ?',
        variables: [Variable.withString(id)],
      ).get();
      if (rows.isEmpty) return null;
      return _customer(rows.first);
    } catch (e) {
      AppLogger.warning('ShopDao', 'customer read failed: $e');
      return null;
    }
  }

  Future<bool> saveCustomer({
    required String id,
    required String name,
    required String normalizedName,
    String phone = '',
    String address = '',
    String note = '',
    int? creditLimit,
    required bool active,
  }) async {
    try {
      final existing = await db.customSelect(
        'SELECT id FROM ${ShopTables.customer} WHERE id = ?',
        variables: [Variable.withString(id)],
      ).get();
      if (existing.isEmpty) {
        await db.customStatement(
          'INSERT INTO ${ShopTables.customer} '
          '(id, name, normalized_name, phone, address, note, credit_limit, '
          'active, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            id,
            name,
            normalizedName,
            phone,
            address,
            note,
            creditLimit,
            active ? 1 : 0,
            DateTime.now().millisecondsSinceEpoch,
          ],
        );
      } else {
        await db.customStatement(
          'UPDATE ${ShopTables.customer} SET name = ?, normalized_name = ?, '
          'phone = ?, address = ?, note = ?, credit_limit = ?, active = ? '
          'WHERE id = ?',
          [
            name,
            normalizedName,
            phone,
            address,
            note,
            creditLimit,
            active ? 1 : 0,
            id,
          ],
        );
      }
      return true;
    } catch (e) {
      AppLogger.warning('ShopDao', 'customer save failed: $e');
      return false;
    }
  }

  /// The customer's balance: SUM of their ledger entries (+ = owes).
  Future<int> customerBalance(String customerId) async {
    try {
      final rows = await db.customSelect(
        'SELECT COALESCE(SUM(signed_amount), 0) AS total FROM '
        '${ShopTables.ledgerEntry} WHERE party_type = ? AND party_id = ?',
        variables: [
          Variable.withString('customer'),
          Variable.withString(customerId),
        ],
      ).get();
      return rows.first.read<int>('total');
    } catch (e) {
      AppLogger.warning('ShopDao', 'balance read failed: $e');
      return 0;
    }
  }

  /// The customer's open invoices with remaining credit portions.
  ///
  /// remaining = +credit-entry − SUM(negative entries referencing the invoice)
  /// — the ledger is the single source (SHOP_DOMAIN.md §4).
  Future<List<OpenInvoice>> openInvoices(String customerId) async {
    try {
      final rows = await db.customSelect(
        'SELECT i.id, i.number, i.date, i.total, i.status, '
        'COALESCE((SELECT SUM(le.signed_amount) FROM '
        '${ShopTables.ledgerEntry} le WHERE le.ref_type = ? '
        'AND le.ref_id = i.id AND le.signed_amount < 0), 0) AS paid '
        'FROM ${ShopTables.invoice} i '
        'WHERE i.customer_id = ? AND i.kind = ? AND i.status = ?',
        variables: [
          Variable.withString('invoice'),
          Variable.withString(customerId),
          Variable.withString('sale'),
          Variable.withString('posted'),
        ],
      ).get();
      final out = <OpenInvoice>[];
      for (final r in rows) {
        final total = r.read<int>('total');
        final paid = r.read<int>('paid');
        final remaining = total + paid; // paid is negative-summed
        if (remaining > 0) {
          out.add(OpenInvoice(
            invoiceId: r.read<String>('id'),
            number: r.read<String>('number'),
            date: _date(r.read<int>('date')),
            remaining: remaining,
          ));
        }
      }
      return out;
    } catch (e) {
      AppLogger.warning('ShopDao', 'open invoices read failed: $e');
      return const [];
    }
  }

  /// Ledger timeline for one party, newest first.
  Future<List<LedgerRow>> ledger(String customerId,
      {int limit = 200}) async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${ShopTables.ledgerEntry} '
        'WHERE party_type = ? AND party_id = ? '
        'ORDER BY date DESC, created_at DESC LIMIT ?',
        variables: [
          Variable.withString('customer'),
          Variable.withString(customerId),
          Variable.withInt(limit),
        ],
      ).get();
      return [
        for (final r in rows)
          LedgerRow(
            id: r.read<String>('id'),
            partyId: r.read<String>('party_id'),
            date: _date(r.read<int>('date')),
            kind: r.read<String>('kind'),
            signedAmount: r.read<int>('signed_amount'),
            refType: r.read<String>('ref_type'),
            refId: r.readNullable<String>('ref_id'),
            note: r.read<String>('note'),
          ),
      ];
    } catch (e) {
      AppLogger.warning('ShopDao', 'ledger read failed: $e');
      return const [];
    }
  }

  // ── Invoices ─────────────────────────────────────────────────────────

  Future<ShopInvoice?> invoice(String id) async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${ShopTables.invoice} WHERE id = ?',
        variables: [Variable.withString(id)],
      ).get();
      if (rows.isEmpty) return null;
      return _invoice(rows.first);
    } catch (e) {
      AppLogger.warning('ShopDao', 'invoice read failed: $e');
      return null;
    }
  }

  Future<List<ShopInvoiceItem>> invoiceItems(String invoiceId) async {
    try {
      // Item ids are monotonic microsecond stamps, so ordering by id IS the
      // insertion order — there is no separate ordinal column to drift.
      final rows = await db.customSelect(
        'SELECT * FROM ${ShopTables.invoiceItem} WHERE invoice_id = ? '
        'ORDER BY id ASC',
        variables: [Variable.withString(invoiceId)],
      ).get();
      return [for (final r in rows) _item(r)];
    } catch (e) {
      AppLogger.warning('ShopDao', 'items read failed: $e');
      return const [];
    }
  }

  /// Recent invoices (dashboard «آخرین تراکنش‌ها» and the report tab).
  Future<List<ShopInvoice>> recentInvoices(
      {int limit = 20, int? fromMs, int? toMs}) async {
    try {
      final where = StringBuffer('WHERE 1=1');
      final vars = <Variable<Object>>[];
      if (fromMs != null) {
        where.write(' AND date >= ?');
        vars.add(Variable.withInt(fromMs));
      }
      if (toMs != null) {
        where.write(' AND date <= ?');
        vars.add(Variable.withInt(toMs));
      }
      vars.add(Variable.withInt(limit));
      final rows = await db.customSelect(
        'SELECT * FROM ${ShopTables.invoice} $where '
        'ORDER BY date DESC LIMIT ?',
        variables: vars,
      ).get();
      return [for (final r in rows) _invoice(r)];
    } catch (e) {
      AppLogger.warning('ShopDao', 'recent invoices read failed: $e');
      return const [];
    }
  }

  // ── THE TRANSACTION: postSale ────────────────────────────────────────

  /// Posts a sale. Every write below runs in ONE transaction; any failure —
  /// including a deliberately injected one in the atomicity test — leaves the
  /// database exactly as it was.
  Future<PostedInvoice> postSale({
    required List<CartLine> cart,
    required List<SalePayment> payments,
    ShopCustomer? customer,
    required ShopSettingsRow settingsRow,
    required int customerBalance,
    bool ignoreCreditLimitWarn = false,
  }) async {
    // Pure validation first (no writes to roll back).
    final evaluation = evaluateSale(
      lines: cart,
      payments: payments,
      roundingStep: settingsRow.roundingStep,
      creditMode: settingsRow.creditLimitMode,
      hasCustomer: customer != null,
      customerBalance: customerBalance,
      customerCreditLimit: customer?.creditLimit,
    );
    if (evaluation.problem != null) {
      throw PostingException(evaluation.problem!);
    }
    if (evaluation.verdict == CreditVerdict.blockedOverLimit) {
      throw const PostingException('سقف اعتبار این مشتری پر است و ثبت مسدود شد.');
    }
    if (evaluation.verdict == CreditVerdict.warnOverLimit &&
        !ignoreCreditLimitWarn) {
      throw const PostingException('CONFIRM_CREDIT_WARN');
    }
    final credit = evaluation.creditPortion;
    if (credit > 0 &&
        settingsRow.creditLimitMode != CreditLimitMode.off &&
        customer == null) {
      throw const PostingException('برای فروش نسیه مشتری الزامی است.');
    }

    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final invoiceId = _id('inv');

    return await db.transaction<PostedInvoice>(() async {
      // 1. Allocate the number inside the transaction.
      final numberRow = await db.customSelect(
        'SELECT next_invoice_number, invoice_prefix FROM '
        '${ShopTables.settings} WHERE id = ?',
        variables: [Variable.withString(settingsId)],
      ).get();
      final next = numberRow.isEmpty ? 1 : numberRow.first.read<int>('next_invoice_number');
      final prefix = numberRow.isEmpty
          ? settingsRow.invoicePrefix
          : numberRow.first.read<String>('invoice_prefix');
      final number = '$prefix$next';
      await db.customStatement(
        'UPDATE ${ShopTables.settings} SET next_invoice_number = ? '
        'WHERE id = ?',
        [next + 1, settingsId],
      );

      // 2. The invoice header (arithmetic from the pure evaluation).
      await db.customStatement(
        'INSERT INTO ${ShopTables.invoice} '
        '(id, number, date, kind, customer_id, subtotal, discount_total, '
        'rounding_adj, total, status, note, void_of, return_of, void_reason, '
        'created_at) '
        "VALUES (?, ?, ?, 'sale', ?, ?, ?, ?, ?, 'posted', '', NULL, NULL, "
        'NULL, ?)',
        [
          invoiceId,
          number,
          nowMs,
          customer?.id,
          evaluation.subtotal,
          evaluation.discountTotal,
          evaluation.roundingAdj,
          evaluation.total,
          nowMs,
        ],
      );

      // 3. Items with cost snapshots, stock movements, cached updates.
      for (final line in evaluation.lines) {
        final lineTotal = line.lineTotal;
        await db.customStatement(
          'INSERT INTO ${ShopTables.invoiceItem} '
          '(id, invoice_id, product_id, name_snapshot, unit_snapshot, '
          'qty_milli, unit_price, discount, line_total, unit_cost_snapshot) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            _id('it'),
            invoiceId,
            line.productId,
            line.name,
            line.unitName,
            line.qtyMilli,
            line.unitPrice,
            line.discount,
            lineTotal,
            line.avgCost,
          ],
        );

        if (line.trackStock) {
          final current = await _stockOf(line.productId);
          if (!settingsRow.allowNegativeStock && current - line.qtyMilli < 0) {
            throw PostingException('موجودی «${line.name}» کافی نیست.');
          }
          final after = current - line.qtyMilli;
          await db.customStatement(
            'INSERT INTO ${ShopTables.stockMovement} '
            '(id, product_id, date, type, qty_milli, unit_cost, ref_type, '
            'ref_id, note, created_at) '
            "VALUES (?, ?, ?, 'sale', ?, ?, ?, ?, '', ?)",
            [
              _id('mv'),
              line.productId,
              nowMs,
              -line.qtyMilli,
              line.avgCost,
              'invoice',
              invoiceId,
              nowMs,
            ],
          );
          await db.customStatement(
            'UPDATE ${ShopTables.product} SET stock_milli_cached = ?, '
            'last_sold_at = ? WHERE id = ?',
            [after, nowMs, line.productId],
          );
        }
      }

      // 4. Payments (cash at the counter) — recorded with the invoice ref so
      //    the open-remaining derivation stays in one table.
      for (final p in payments) {
        if (p.amount <= 0) continue;
        await db.customStatement(
          'INSERT INTO ${ShopTables.payment} '
          '(id, date, direction, method, amount, party_type, party_id, '
          'invoice_id, note, created_at) '
          "VALUES (?, ?, 'in', ?, ?, ?, ?, ?, '', ?)",
          [
            _id('pay'),
            nowMs,
            p.method.wire,
            p.amount,
            customer != null ? 'customer' : 'none',
            customer?.id,
            invoiceId,
            nowMs,
          ],
        );
        if (customer != null) {
          await _insertLedger(
            partyId: customer.id,
            dateMs: nowMs,
            kind: 'payment',
            signedAmount: -p.amount,
            refType: 'invoice',
            refId: invoiceId,
            note: '',
          );
        }
      }

      // 5. The invoice itself on the customer's ledger: the FULL total (+).
      //    Each payment above already wrote its own −amount, so the balance is
      //    the invoice minus what was paid at the counter. Booking only the
      //    credit portion here subtracted the down-payment a second time — a
      //    100,000 payment on a 610,000 credit sale left 410,000 owing instead
      //    of 510,000 — and it also broke `openInvoices`, which derives the
      //    remaining credit as `total + Σ(negative ledger rows)`.
      if (customer != null && evaluation.total > 0) {
        await _insertLedger(
          partyId: customer.id,
          dateMs: nowMs,
          kind: 'invoice',
          signedAmount: evaluation.total,
          refType: 'invoice',
          refId: invoiceId,
          note: number,
        );
      }

      // 6. Audit.
      await _audit(
        action: 'post_sale',
        entity: 'invoice',
        refId: invoiceId,
        details: {
          'number': number,
          'total': evaluation.total,
          'credit': credit,
          'customer': customer?.id,
        },
      );

      final saved = await invoice(invoiceId);
      final items = await invoiceItems(invoiceId);
      if (saved == null) {
        throw const PostingException('post-read failed');
      }
      return PostedInvoice(invoice: saved, items: items);
    });
  }

  /// Voids a posted invoice: exact reversals, status change, audit — one
  /// transaction. The original rows are never edited or deleted.
  Future<bool> voidInvoice({
    required String invoiceId,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) return false;
    try {
      return await db.transaction<bool>(() async {
        final inv = await invoice(invoiceId);
        if (inv == null || !inv.isPosted || inv.isReturn) return false;
        final items = await invoiceItems(invoiceId);
        final nowMs = DateTime.now().millisecondsSinceEpoch;

        await db.customStatement(
          'UPDATE ${ShopTables.invoice} SET status = ?, void_reason = ? '
          'WHERE id = ? AND status = ?',
          ['void', reason.trim(), invoiceId, 'posted'],
        );

        // Reversing stock movements (+qty back).
        for (final item in items) {
          if (item.productId == null) continue;
          final prod = await product(item.productId!);
          if (prod == null || !prod.trackStock) continue;
          await db.customStatement(
            'INSERT INTO ${ShopTables.stockMovement} '
            '(id, product_id, date, type, qty_milli, unit_cost, ref_type, '
            'ref_id, note, created_at) '
            "VALUES (?, ?, ?, 'sale', ?, ?, ?, ?, ?, ?)",
            [
              _id('mv'),
              item.productId,
              nowMs,
              item.qtyMilli, // exact reversal: sale was −qty
              item.unitCostSnapshot,
              'void',
              invoiceId,
              reason.trim(),
              nowMs,
            ],
          );
          final after = prod.stockMilliCached + item.qtyMilli;
          await db.customStatement(
            'UPDATE ${ShopTables.product} SET stock_milli_cached = ? '
            'WHERE id = ?',
            [after, item.productId],
          );
        }

        // Reversing ledger entries: negate every entry that references this
        // invoice, so the customer's balance returns to its prior value
        // EXACTLY (invariant 4).
        final entries = await db.customSelect(
          'SELECT * FROM ${ShopTables.ledgerEntry} '
          "WHERE ref_type = 'invoice' AND ref_id = ?",
          variables: [Variable.withString(invoiceId)],
        ).get();
        for (final e in entries) {
          await _insertLedger(
            partyId: e.read<String>('party_id'),
            dateMs: nowMs,
            kind: 'invoice',
            signedAmount: -e.read<int>('signed_amount'),
            refType: 'void',
            refId: invoiceId,
            note: 'ابطال: ${reason.trim()}',
          );
        }

        await _audit(
          action: 'void_invoice',
          entity: 'invoice',
          refId: invoiceId,
          details: {'reason': reason.trim()},
        );
        return true;
      });
    } catch (e) {
      AppLogger.warning('ShopDao', 'void failed: $e');
      return false;
    }
  }

  /// Receives a payment from a customer with FIFO allocation. The preview the
  /// UI shows is exactly [allocateFifo]'s output over [openInvoices].
  Future<AllocationResult?> receivePayment({
    required String customerId,
    required int amount,
    required PaymentMethod method,
    required DateTime date,
    String note = '',
  }) async {
    if (amount <= 0) return null;
    try {
      final open = await openInvoices(customerId);
      final allocation = allocateFifo(payment: amount, openInvoices: open);
      final nowMs = date.millisecondsSinceEpoch;

      await db.transaction(() async {
        // One payment row (the money), then one ledger entry per slice
        // (the bookkeeping), plus the advance when money is left over.
        await db.customStatement(
          'INSERT INTO ${ShopTables.payment} '
          '(id, date, direction, method, amount, party_type, party_id, '
          'invoice_id, note, created_at) '
          "VALUES (?, ?, 'in', ?, ?, 'customer', ?, NULL, ?, ?)",
          [
            _id('pay'),
            nowMs,
            method.wire,
            amount,
            customerId,
            note,
            nowMs,
          ],
        );
        for (final slice in allocation.slices) {
          await _insertLedger(
            partyId: customerId,
            dateMs: nowMs,
            kind: 'payment',
            signedAmount: -slice.amount,
            refType: 'invoice',
            refId: slice.invoiceId,
            note: 'تسویه ${slice.invoiceNumber}',
          );
        }
        if (allocation.advance > 0) {
          await _insertLedger(
            partyId: customerId,
            dateMs: nowMs,
            kind: 'payment',
            signedAmount: -allocation.advance,
            refType: '',
            refId: null,
            note: 'پیش‌پرداخت',
          );
        }
        await _audit(
          action: 'receive_payment',
          entity: 'customer',
          refId: customerId,
          details: {
            'amount': amount,
            'method': method.wire,
            'advance': allocation.advance,
          },
        );
      });
      return allocation;
    } catch (e) {
      AppLogger.warning('ShopDao', 'receive payment failed: $e');
      return null;
    }
  }

  /// A write-off («بخشش مانده»): an explicit ledger entry with a required
  /// note — the balance is never edited in place.
  Future<bool> writeOff({
    required String customerId,
    required int amount,
    required String note,
  }) async {
    if (amount <= 0 || note.trim().isEmpty) return false;
    try {
      await db.transaction(() async {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        await _insertLedger(
          partyId: customerId,
          dateMs: nowMs,
          kind: 'writeoff',
          signedAmount: -amount,
          refType: '',
          refId: null,
          note: note.trim(),
        );
        await _audit(
          action: 'writeoff',
          entity: 'customer',
          refId: customerId,
          details: {'amount': amount, 'note': note.trim()},
        );
      });
      return true;
    } catch (e) {
      AppLogger.warning('ShopDao', 'writeoff failed: $e');
      return false;
    }
  }

  /// An explicit balance adjustment (either direction) with a required note.
  Future<bool> adjustBalance({
    required String customerId,
    required int signedAmount,
    required String note,
  }) async {
    if (signedAmount == 0 || note.trim().isEmpty) return false;
    try {
      await db.transaction(() async {
        await _insertLedger(
          partyId: customerId,
          dateMs: DateTime.now().millisecondsSinceEpoch,
          kind: 'adjustment',
          signedAmount: signedAmount,
          refType: '',
          refId: null,
          note: note.trim(),
        );
        await _audit(
          action: 'adjust_balance',
          entity: 'customer',
          refId: customerId,
          details: {'amount': signedAmount, 'note': note.trim()},
        );
      });
      return true;
    } catch (e) {
      AppLogger.warning('ShopDao', 'adjust failed: $e');
      return false;
    }
  }

  /// A customer's opening balance: an `opening` ledger entry dated [date].
  Future<bool> openingBalance({
    required String customerId,
    required int signedAmount,
    required DateTime date,
  }) async {
    if (signedAmount == 0) return true;
    try {
      await db.transaction(() async {
        await _insertLedger(
          partyId: customerId,
          dateMs: date.millisecondsSinceEpoch,
          kind: 'opening',
          signedAmount: signedAmount,
          refType: '',
          refId: null,
          note: 'افتتاحیه',
        );
        await _audit(
          action: 'opening_balance',
          entity: 'customer',
          refId: customerId,
          details: {'amount': signedAmount},
        );
      });
      return true;
    } catch (e) {
      AppLogger.warning('ShopDao', 'opening balance failed: $e');
      return false;
    }
  }

  /// A raw ledger insert for cross-feature flows (the stage-3 cheque bounce
  /// writes its reversal inside the Shop3Dao transaction — the insert itself
  /// must exist on THIS dao because the table is stage-2's).
  Future<void> adjustLedgerDirect({
    required String partyId,
    required int signedAmount,
    required String kind,
    required String refType,
    required String? refId,
    required String note,
    String partyType = 'customer',
  }) async {
    await db.customStatement(
      'INSERT INTO ${ShopTables.ledgerEntry} '
      '(id, party_type, party_id, date, kind, signed_amount, ref_type, '
      'ref_id, note, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        'le_${DateTime.now().microsecondsSinceEpoch}_${++_ledgerSeq}',
        partyType,
        partyId,
        DateTime.now().millisecondsSinceEpoch,
        kind,
        signedAmount,
        refType,
        refId,
        note,
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  static int _ledgerSeq = 0;

  // ── Held carts ───────────────────────────────────────────────────────

  Future<bool> holdCart({
    required List<CartLine> cart,
    String? customerId,
    String note = '',
  }) async {
    if (cart.isEmpty) return false;
    try {
      await db.customStatement(
        'INSERT INTO ${ShopTables.heldCart} '
        '(id, items_json, customer_id, note, created_at) VALUES (?, ?, ?, ?, ?)',
        [
          _id('cart'),
          jsonEncode([
            for (final l in cart)
              {
                'productId': l.productId,
                'name': l.name,
                'unitName': l.unitName,
                'qtyMilli': l.qtyMilli,
                'unitPrice': l.unitPrice,
                'discount': l.discount,
                'trackStock': l.trackStock,
                'avgCost': l.avgCost,
              }
          ]),
          customerId,
          note,
          DateTime.now().millisecondsSinceEpoch,
        ],
      );
      return true;
    } catch (e) {
      AppLogger.warning('ShopDao', 'hold cart failed: $e');
      return false;
    }
  }

  Future<List<({String id, List<CartLine> cart, String? customerId, String note, DateTime createdAt})>>
      heldCarts() async {
    try {
      final rows = await db.customSelect(
        'SELECT * FROM ${ShopTables.heldCart} ORDER BY created_at DESC',
      ).get();
      return [
        for (final r in rows)
          (
            id: r.read<String>('id'),
            cart: _decodeCart(r.read<String>('items_json')),
            customerId: r.readNullable<String>('customer_id'),
            note: r.read<String>('note'),
            createdAt: _date(r.read<int>('created_at')),
          ),
      ];
    } catch (e) {
      AppLogger.warning('ShopDao', 'held carts read failed: $e');
      return const [];
    }
  }

  Future<bool> deleteHeldCart(String id) async {
    try {
      await db.customStatement(
        'DELETE FROM ${ShopTables.heldCart} WHERE id = ?',
        [id],
      );
      return true;
    } catch (e) {
      AppLogger.warning('ShopDao', 'delete held cart failed: $e');
      return false;
    }
  }

  static List<CartLine> _decodeCart(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) return const [];
      return [
        for (final e in decoded)
          if (e is Map)
            CartLine(
              productId: (e['productId'] as String?) ?? '',
              name: (e['name'] as String?) ?? '',
              unitName: (e['unitName'] as String?) ?? '',
              qtyMilli: (e['qtyMilli'] as num?)?.toInt() ?? 0,
              unitPrice: (e['unitPrice'] as num?)?.toInt() ?? 0,
              discount: (e['discount'] as num?)?.toInt() ?? 0,
              trackStock: e['trackStock'] == true,
              avgCost: (e['avgCost'] as num?)?.toInt() ?? 0,
            ),
      ];
    } catch (e) {
      AppLogger.warning('ShopDao', 'cart decode failed: $e');
      return const [];
    }
  }

  /// «پاک‌کردن داده‌های مغازه»: one transaction, shop tables only. The
  /// settings row survives (the shop's identity), everything transactional
  /// goes. Called only behind ParentLock + a typed confirmation.
  Future<bool> wipeShopData() async {
    try {
      await db.transaction(() async {
        for (final table in [
          ShopTables.invoiceItem,
          ShopTables.invoice,
          ShopTables.payment,
          ShopTables.ledgerEntry,
          ShopTables.stockMovement,
          ShopTables.heldCart,
          ShopTables.priceChange,
          ShopTables.auditLog,
          ShopTables.productBarcode,
          ShopTables.product,
          ShopTables.customer,
        ]) {
          await db.customStatement('DELETE FROM $table');
        }
        // Numbering restarts at 1 with a clean ledger.
        await db.customStatement(
          'UPDATE ${ShopTables.settings} SET next_invoice_number = 1',
        );
        await _audit(
          action: 'wipe_shop_data',
          entity: 'shop',
          refId: '',
          details: {},
        );
      });
      return true;
    } catch (e) {
      AppLogger.warning('ShopDao', 'wipe failed: $e');
      return false;
    }
  }

  // ── Integrity (recompute, report — never auto-fix) ───────────────────

  /// Recomputes stock and balances from the movements/ledger and reports
  /// mismatches. Never fixes anything without the user confirming.
  Future<List<IntegrityMismatch>> verifyIntegrity() async {
    final problems = <IntegrityMismatch>[];
    try {
      // Stock: cached vs SUM(movements).
      final stockRows = await db.customSelect(
        'SELECT p.id, p.name, p.stock_milli_cached AS cached, '
        'COALESCE((SELECT SUM(m.qty_milli) FROM '
        '${ShopTables.stockMovement} m WHERE m.product_id = p.id), 0) '
        'AS computed FROM ${ShopTables.product} p WHERE p.track_stock = 1',
      ).get();
      for (final r in stockRows) {
        final cached = r.read<int>('cached');
        final computed = r.read<int>('computed');
        if (cached != computed) {
          problems.add(IntegrityMismatch(
            description: 'موجودی ناسازگار',
            details: '${r.read<String>('name')}: ثبت‌شده $cached، '
                'محاسبه‌شده $computed',
          ));
        }
      }

      // Balances: the ledger IS the balance, so the check here is that no
      // posted sale invoice lacks its ledger entry (a crash between writes
      // cannot happen inside one transaction — this catches external edits).
      final orphanRows = await db.customSelect(
        'SELECT i.id, i.number FROM ${ShopTables.invoice} i '
        'WHERE i.status = ? AND i.kind = ? AND i.customer_id IS NOT NULL '
        'AND NOT EXISTS (SELECT 1 FROM ${ShopTables.ledgerEntry} le '
        "WHERE le.ref_type = 'invoice' AND le.ref_id = i.id "
        'AND le.signed_amount > 0)',
        variables: [Variable.withString('posted'), Variable.withString('sale')],
      ).get();
      for (final r in orphanRows) {
        problems.add(IntegrityMismatch(
          description: 'فروش اعتباری بدون سطر دفتر',
          details: 'فاکتور ${r.read<String>('number')}',
        ));
      }
    } catch (e) {
      AppLogger.warning('ShopDao', 'integrity check failed: $e');
      problems.add(IntegrityMismatch(
        description: 'بررسی سلامت داده‌ها ممکن نشد',
        details: '$e',
      ));
    }
    return problems;
  }

  // ── Bulk price change (with undo) ────────────────────────────────────

  /// Applies a percent/amount change to a selection and records the batch so
  /// «_undo» can restore every old price exactly.
  Future<String?> applyBulkPriceChange({
    required List<({String productId, int oldSell, int oldBuy})> items,
    required int deltaPerUnit,
    required bool percent,
    required int roundingStep,
  }) async {
    if (items.isEmpty) return null;
    final batchId = _id('pb');
    try {
      await db.transaction(() async {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        for (final item in items) {
          // One definition of the arithmetic: the sheet's preview calls the
          // same function, so what the shopkeeper approves is what is written
          // (rounding step included — it used to be accepted and ignored).
          final newSell = bulkPriceAfter(
            price: item.oldSell,
            delta: deltaPerUnit,
            percent: percent,
            roundingStep: roundingStep,
          );
          final newBuy = bulkPriceAfter(
            price: item.oldBuy,
            delta: deltaPerUnit,
            percent: percent,
            roundingStep: roundingStep,
          );
          if (newSell < 0 || newBuy < 0) continue;
          await db.customStatement(
            'UPDATE ${ShopTables.product} SET sell_price = ?, '
            'buy_price_last = ? WHERE id = ?',
            [newSell, newBuy, item.productId],
          );
          await db.customStatement(
            'INSERT INTO ${ShopTables.priceChange} '
            '(id, batch_id, product_id, old_sell_price, new_sell_price, '
            'old_buy_price, new_buy_price, applied_at) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            [
              _id('pc'),
              batchId,
              item.productId,
              item.oldSell,
              newSell,
              item.oldBuy,
              newBuy,
              nowMs,
            ],
          );
        }
        await _audit(
          action: 'bulk_price_change',
          entity: 'product',
          refId: batchId,
          details: {'count': items.length, 'delta': deltaPerUnit,
              'percent': percent},
        );
      });
      return batchId;
    } catch (e) {
      AppLogger.warning('ShopDao', 'bulk price change failed: $e');
      return null;
    }
  }

  /// Undoes a whole price-change batch: restores every old price.
  Future<bool> undoBulkPriceChange(String batchId) async {
    try {
      await db.transaction(() async {
        final rows = await db.customSelect(
          'SELECT * FROM ${ShopTables.priceChange} WHERE batch_id = ?',
          variables: [Variable.withString(batchId)],
        ).get();
        for (final r in rows) {
          await db.customStatement(
            'UPDATE ${ShopTables.product} SET sell_price = ?, '
            'buy_price_last = ? WHERE id = ?',
            [
              r.read<int>('old_sell_price'),
              r.read<int>('old_buy_price'),
              r.read<String>('product_id'),
            ],
          );
        }
        await db.customStatement(
          'DELETE FROM ${ShopTables.priceChange} WHERE batch_id = ?',
          [batchId],
        );
        await _audit(
          action: 'undo_price_change',
          entity: 'product',
          refId: batchId,
          details: {'count': rows.length},
        );
      });
      return true;
    } catch (e) {
      AppLogger.warning('ShopDao', 'undo price change failed: $e');
      return false;
    }
  }

  // ── Audit ────────────────────────────────────────────────────────────

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

  Future<void> _insertLedger({
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
      "VALUES (?, 'customer', ?, ?, ?, ?, ?, ?, ?, ?)",
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

  Future<int> _stockOf(String productId) async {
    final rows = await db.customSelect(
      'SELECT stock_milli_cached FROM ${ShopTables.product} WHERE id = ?',
      variables: [Variable.withString(productId)],
    ).get();
    return rows.isEmpty ? 0 : rows.first.read<int>('stock_milli_cached');
  }

  // ── Row mappers ──────────────────────────────────────────────────────

  /// Public row mapper for widgets that run their own indexed queries
  /// (the POS favorites strip reads directly from the product table).
  static ShopProduct productFromRow(dynamic r) => _product(r);

  static ShopProduct _product(dynamic r) => ShopProduct(
        id: r.read<String>('id'),
        name: r.read<String>('name'),
        categoryId: r.readNullable<int>('category_id'),
        unitId: r.readNullable<int>('unit_id'),
        sellPrice: r.read<int>('sell_price'),
        buyPriceLast: r.read<int>('buy_price_last'),
        avgCost: r.read<int>('avg_cost'),
        minStockMilli: r.readNullable<int>('min_stock_milli'),
        trackStock: r.read<int>('track_stock') == 1,
        active: r.read<int>('active') == 1,
        note: r.read<String>('note'),
        stockMilliCached: r.read<int>('stock_milli_cached'),
        isFavorite: r.read<int>('is_favorite') == 1,
        lastSoldAt: (r.readNullable<int>('last_sold_at')) == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                r.read<int>('last_sold_at')),
      );

  static ShopCustomer _customer(dynamic r) => ShopCustomer(
        id: r.read<String>('id'),
        name: r.read<String>('name'),
        phone: r.read<String>('phone'),
        address: r.read<String>('address'),
        note: r.read<String>('note'),
        creditLimit: r.readNullable<int>('credit_limit'),
        active: r.read<int>('active') == 1,
        createdAt: _date(r.read<int>('created_at')),
      );

  static ShopInvoice _invoice(dynamic r) => ShopInvoice(
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

  static ShopInvoiceItem _item(dynamic r) => ShopInvoiceItem(
        id: r.read<String>('id'),
        invoiceId: r.read<String>('invoice_id'),
        productId: r.readNullable<String>('product_id'),
        nameSnapshot: r.read<String>('name_snapshot'),
        unitSnapshot: r.read<String>('unit_snapshot'),
        qtyMilli: r.read<int>('qty_milli'),
        unitPrice: r.read<int>('unit_price'),
        discount: r.read<int>('discount'),
        lineTotal: r.read<int>('line_total'),
        unitCostSnapshot: r.read<int>('unit_cost_snapshot'),
      );
}

final shopDaoProvider = Provider<ShopDao>(
  (ref) => ShopDao(ref.read(appDatabaseProvider)),
);
