/// Raw-SQL schema of the stage-3 shop additions («حساب مغازه» part 2),
/// schema version 48.
///
/// Same precedent as v45-v47: plain `CREATE TABLE IF NOT EXISTS`, no codegen,
/// additive only. Sign conventions and the moving-average rule are stated in
/// docs/SHOP_DOMAIN.md — this file is their storage shape.
///
/// Supplier ledger sign: + = the SHOP owes the supplier (documented §Stage3).
/// Posted purchases and cheque rows are IMMUTABLE; void = reversal + audit.
class Shop3Tables {
  Shop3Tables._();

  static const String supplier = 'p2_shop_supplier';
  static const String purchase = 'p2_shop_purchase';
  static const String purchaseItem = 'p2_shop_purchase_item';
  static const String expense = 'p2_shop_expense';
  static const String expenseCategory = 'p2_shop_expense_category';
  static const String recurringExpense = 'p2_shop_recurring_expense';
  static const String cheque = 'p2_shop_cheque';
  static const String cashDay = 'p2_shop_cash_day';
  static const String cashAdjustment = 'p2_shop_cash_adjustment';
  static const String stockCount = 'p2_shop_stock_count';
  static const String stockCountLine = 'p2_shop_stock_count_line';

  static const List<String> allTables = [
    supplier,
    purchase,
    purchaseItem,
    expense,
    expenseCategory,
    recurringExpense,
    cheque,
    cashDay,
    cashAdjustment,
    stockCount,
    stockCountLine,
  ];

  static const List<String> createStatements = [
    // ── Suppliers ──────────────────────────────────────────────────
    'CREATE TABLE IF NOT EXISTS p2_shop_supplier ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'name TEXT NOT NULL, '
        'normalized_name TEXT NOT NULL, '
        'phone TEXT NOT NULL DEFAULT \'\', '
        'address TEXT NOT NULL DEFAULT \'\', '
        'note TEXT NOT NULL DEFAULT \'\', '
        'active INTEGER NOT NULL DEFAULT 1, '
        'created_at INTEGER NOT NULL)',
    'CREATE INDEX IF NOT EXISTS idx_p2_shop_supplier_name '
        'ON p2_shop_supplier (normalized_name)',

    // ── Purchases (posted rows immutable) ──────────────────────────
    // status: posted | void | held. extra_cost_total is allocated to items.
    'CREATE TABLE IF NOT EXISTS p2_shop_purchase ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'number TEXT NOT NULL, '
        'date INTEGER NOT NULL, '
        'supplier_id TEXT, '
        'subtotal INTEGER NOT NULL, '
        'discount_total INTEGER NOT NULL DEFAULT 0, '
        'extra_cost_total INTEGER NOT NULL DEFAULT 0, '
        'total INTEGER NOT NULL, '
        'paid INTEGER NOT NULL DEFAULT 0, '
        'due_date INTEGER, '
        'status TEXT NOT NULL DEFAULT \'posted\', '
        'note TEXT NOT NULL DEFAULT \'\', '
        'void_reason TEXT, '
        'created_at INTEGER NOT NULL)',
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_p2_shop_purchase_number '
        'ON p2_shop_purchase (number)',
    'CREATE INDEX IF NOT EXISTS idx_p2_shop_purchase_date '
        'ON p2_shop_purchase (date)',
    'CREATE INDEX IF NOT EXISTS idx_p2_shop_purchase_supplier '
        'ON p2_shop_purchase (supplier_id, date)',

    'CREATE TABLE IF NOT EXISTS p2_shop_purchase_item ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'purchase_id TEXT NOT NULL, '
        'product_id TEXT, '
        'name_snapshot TEXT NOT NULL, '
        'qty_milli INTEGER NOT NULL, '
        'unit_cost INTEGER NOT NULL, '
        'discount INTEGER NOT NULL DEFAULT 0, '
        'line_total INTEGER NOT NULL, '
        'allocated_extra INTEGER NOT NULL DEFAULT 0, '
        'landed_unit_cost INTEGER NOT NULL DEFAULT 0, '
        'prev_avg_cost INTEGER NOT NULL DEFAULT 0, '
        'new_avg_cost INTEGER NOT NULL DEFAULT 0)',
    'CREATE INDEX IF NOT EXISTS idx_p2_shop_pitem_purchase '
        'ON p2_shop_purchase_item (purchase_id)',
    'CREATE INDEX IF NOT EXISTS idx_p2_shop_pitem_product '
        'ON p2_shop_purchase_item (product_id)',

    // ── Expenses ───────────────────────────────────────────────────
    'CREATE TABLE IF NOT EXISTS p2_shop_expense ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'date INTEGER NOT NULL, '
        'category_id INTEGER, '
        'amount INTEGER NOT NULL, '
        'method TEXT NOT NULL DEFAULT \'cash\', '
        'payee TEXT NOT NULL DEFAULT \'\', '
        'note TEXT NOT NULL DEFAULT \'\', '
        'attachment_path TEXT, '
        'recurring_rule_id TEXT, '
        'created_at INTEGER NOT NULL)',
    'CREATE INDEX IF NOT EXISTS idx_p2_shop_expense_date '
        'ON p2_shop_expense (date)',
    'CREATE INDEX IF NOT EXISTS idx_p2_shop_expense_category '
        'ON p2_shop_expense (category_id, date)',

    'CREATE TABLE IF NOT EXISTS p2_shop_expense_category ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'name TEXT NOT NULL, '
        'active INTEGER NOT NULL DEFAULT 1, '
        'sort INTEGER NOT NULL DEFAULT 0)',

    // ── Recurring expenses (generate REMINDERS, never auto-posts) ──
    // day_of_month is a Jalali day (1..31); month-end safe in Dart.
    'CREATE TABLE IF NOT EXISTS p2_shop_recurring_expense ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'category_id INTEGER, '
        'amount INTEGER NOT NULL, '
        'day_of_month INTEGER NOT NULL, '
        'method TEXT NOT NULL DEFAULT \'cash\', '
        'note TEXT NOT NULL DEFAULT \'\', '
        'last_reminded_key TEXT NOT NULL DEFAULT \'\', '
        'active INTEGER NOT NULL DEFAULT 1)',

    // ── Cheques ────────────────────────────────────────────────────
    // direction: received | issued.
    // status: pending | deposited | cleared | bounced | cancelled | endorsed.
    // party_type mirrors payment: customer (received) | supplier (issued).
    'CREATE TABLE IF NOT EXISTS p2_shop_cheque ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'direction TEXT NOT NULL, '
        'number TEXT NOT NULL DEFAULT \'\', '
        'bank TEXT NOT NULL DEFAULT \'\', '
        'amount INTEGER NOT NULL, '
        'due_date INTEGER NOT NULL, '
        'party_type TEXT NOT NULL DEFAULT \'customer\', '
        'party_id TEXT, '
        'status TEXT NOT NULL DEFAULT \'pending\', '
        'status_changed_at INTEGER, '
        'cleared_date INTEGER, '
        'endorsed_to_supplier_id TEXT, '
        'note TEXT NOT NULL DEFAULT \'\', '
        'image_path TEXT, '
        'payment_id TEXT, '
        'created_at INTEGER NOT NULL)',
    'CREATE INDEX IF NOT EXISTS idx_p2_shop_cheque_due '
        'ON p2_shop_cheque (due_date, direction)',
    'CREATE INDEX IF NOT EXISTS idx_p2_shop_cheque_party '
        'ON p2_shop_cheque (party_type, party_id)',

    // ── Cash register ──────────────────────────────────────────────
    // One row per Jalali day; expected_cash is COMPUTED at read time from
    // the immutable rows — the column caches the last computation for the
    // dashboard and is verified by verifyIntegrity.
    'CREATE TABLE IF NOT EXISTS p2_shop_cash_day ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'date INTEGER NOT NULL, '
        'opened_at INTEGER, '
        'opening_cash INTEGER NOT NULL DEFAULT 0, '
        'closed_at INTEGER, '
        'counted_cash INTEGER, '
        'expected_cash INTEGER, '
        'difference INTEGER, '
        'note TEXT NOT NULL DEFAULT \'\')',
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_p2_shop_cash_day_date '
        'ON p2_shop_cash_day (date)',

    // kind: owner_withdrawal | owner_deposit | other.
    'CREATE TABLE IF NOT EXISTS p2_shop_cash_adjustment ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'cash_day_id TEXT, '
        'date INTEGER NOT NULL, '
        'kind TEXT NOT NULL, '
        'amount INTEGER NOT NULL, '
        'note TEXT NOT NULL DEFAULT \'\', '
        'created_at INTEGER NOT NULL)',
    'CREATE INDEX IF NOT EXISTS idx_p2_shop_cash_adj_date '
        'ON p2_shop_cash_adjustment (date)',

    // ── Stock count (انبارگردانی) ──────────────────────────────────
    // scope: all | category. status: open | posted.
    'CREATE TABLE IF NOT EXISTS p2_shop_stock_count ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'date INTEGER NOT NULL, '
        'scope TEXT NOT NULL DEFAULT \'all\', '
        'category_id INTEGER, '
        'status TEXT NOT NULL DEFAULT \'open\', '
        'note TEXT NOT NULL DEFAULT \'\', '
        'value_impact INTEGER, '
        'created_at INTEGER NOT NULL)',

    'CREATE TABLE IF NOT EXISTS p2_shop_stock_count_line ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'count_id TEXT NOT NULL, '
        'product_id TEXT NOT NULL, '
        'system_qty_milli INTEGER NOT NULL, '
        'counted_qty_milli INTEGER)',
    'CREATE INDEX IF NOT EXISTS idx_p2_shop_count_line '
        'ON p2_shop_stock_count_line (count_id)',
  ];
}
