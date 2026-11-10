/// Raw-SQL schema of «حساب مغازه» (personal-tools set 2, stage 2), schema
/// version 47.
///
/// Same precedent as v45/v46: plain `CREATE TABLE IF NOT EXISTS`, no codegen,
/// additive only. See docs/SHOP_DOMAIN.md for the invariants these tables
/// carry — this file is the storage shape of that contract.
///
/// MONEY is an integer in the app's smallest displayed unit; QUANTITY is an
/// integer in milli-units. No REAL column ever holds money or quantity.
///
/// Posted rows are IMMUTABLE: nothing UPDATEs an invoice's amounts or DELETEs
/// a ledger entry. Corrections are void (reversal) + re-issue, and every
/// posted/voided document writes an audit row.
class ShopTables {
  ShopTables._();

  static const String settings = 'p2_shop_settings';
  static const String unit = 'p2_shop_unit';
  static const String category = 'p2_shop_category';
  static const String product = 'p2_shop_product';
  static const String productBarcode = 'p2_shop_product_barcode';
  static const String stockMovement = 'p2_shop_stock_movement';
  static const String customer = 'p2_shop_customer';
  static const String invoice = 'p2_shop_invoice';
  static const String invoiceItem = 'p2_shop_invoice_item';
  static const String payment = 'p2_shop_payment';
  static const String ledgerEntry = 'p2_shop_ledger_entry';
  static const String heldCart = 'p2_shop_held_cart';
  static const String auditLog = 'p2_shop_audit_log';
  static const String priceChange = 'p2_shop_price_change';

  static const List<String> allTables = [
    settings,
    unit,
    category,
    product,
    productBarcode,
    stockMovement,
    customer,
    invoice,
    invoiceItem,
    payment,
    ledgerEntry,
    heldCart,
    auditLog,
    priceChange,
  ];

  static const List<String> createStatements = [
    // ── Settings (single row, id = 'shop') ─────────────────────────
    // rounding_step: 0 = none, else 10 | 100 | 1000.
    // credit_limit_mode: off | warn | block.
    'CREATE TABLE IF NOT EXISTS p2_shop_settings ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'shop_name TEXT NOT NULL DEFAULT \'\', '
        'phone TEXT NOT NULL DEFAULT \'\', '
        'address TEXT NOT NULL DEFAULT \'\', '
        'invoice_prefix TEXT NOT NULL DEFAULT \'\', '
        'next_invoice_number INTEGER NOT NULL DEFAULT 1, '
        'rounding_step INTEGER NOT NULL DEFAULT 0, '
        'allow_negative_stock INTEGER NOT NULL DEFAULT 1, '
        'credit_limit_mode TEXT NOT NULL DEFAULT \'warn\', '
        'allow_price_edit INTEGER NOT NULL DEFAULT 1, '
        'low_stock_default INTEGER NOT NULL DEFAULT 3, '
        'hide_balances INTEGER NOT NULL DEFAULT 0, '
        'receipt_footer_text TEXT NOT NULL DEFAULT \'\', '
        'logo_path TEXT, '
        'beep_on_scan INTEGER NOT NULL DEFAULT 1, '
        'vibrate_on_scan INTEGER NOT NULL DEFAULT 1, '
        'reminders_enabled INTEGER NOT NULL DEFAULT 0, '
        'low_stock_summary INTEGER NOT NULL DEFAULT 1, '
        'overdue_summary INTEGER NOT NULL DEFAULT 0, '
        'summary_minutes INTEGER NOT NULL DEFAULT 1260, '
        'quiet_start_minutes INTEGER NOT NULL DEFAULT 1320, '
        'quiet_end_minutes INTEGER NOT NULL DEFAULT 420)',

    // ── Units & categories (seeded with defaults, user-editable) ───
    'CREATE TABLE IF NOT EXISTS p2_shop_unit ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'name TEXT NOT NULL, '
        'symbol TEXT NOT NULL, '
        'allow_fraction INTEGER NOT NULL DEFAULT 0)',
    'CREATE TABLE IF NOT EXISTS p2_shop_category ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'name TEXT NOT NULL)',

    // ── Products ───────────────────────────────────────────────────
    'CREATE TABLE IF NOT EXISTS p2_shop_product ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'name TEXT NOT NULL, '
        'normalized_name TEXT NOT NULL, '
        'category_id INTEGER, '
        'unit_id INTEGER, '
        'sell_price INTEGER NOT NULL DEFAULT 0, '
        'buy_price_last INTEGER NOT NULL DEFAULT 0, '
        'avg_cost INTEGER NOT NULL DEFAULT 0, '
        'min_stock_milli INTEGER, '
        'track_stock INTEGER NOT NULL DEFAULT 1, '
        'active INTEGER NOT NULL DEFAULT 1, '
        'note TEXT NOT NULL DEFAULT \'\', '
        'stock_milli_cached INTEGER NOT NULL DEFAULT 0, '
        'is_favorite INTEGER NOT NULL DEFAULT 0, '
        'last_sold_at INTEGER, '
        'created_at INTEGER NOT NULL)',
    'CREATE INDEX IF NOT EXISTS idx_p2_shop_product_name '
        'ON p2_shop_product (normalized_name)',
    'CREATE INDEX IF NOT EXISTS idx_p2_shop_product_active '
        'ON p2_shop_product (active, normalized_name)',

    // ── Barcodes (UNIQUE — the duplicate check has a backstop) ─────
    'CREATE TABLE IF NOT EXISTS p2_shop_product_barcode ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'product_id TEXT NOT NULL, '
        'barcode TEXT NOT NULL UNIQUE)',
    'CREATE INDEX IF NOT EXISTS idx_p2_shop_barcode_product '
        'ON p2_shop_product_barcode (product_id)',

    // ── Stock movements (immutable; stock = SUM) ───────────────────
    // type: opening | sale | sale_return | adjustment | purchase |
    //       purchase_return. qty is SIGNED (+ in, − out).
    'CREATE TABLE IF NOT EXISTS p2_shop_stock_movement ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'product_id TEXT NOT NULL, '
        'date INTEGER NOT NULL, '
        'type TEXT NOT NULL, '
        'qty_milli INTEGER NOT NULL, '
        'unit_cost INTEGER NOT NULL DEFAULT 0, '
        'ref_type TEXT NOT NULL DEFAULT \'\', '
        'ref_id TEXT, '
        'note TEXT NOT NULL DEFAULT \'\', '
        'created_at INTEGER NOT NULL)',
    'CREATE INDEX IF NOT EXISTS idx_p2_shop_move_product_date '
        'ON p2_shop_stock_movement (product_id, date)',
    'CREATE INDEX IF NOT EXISTS idx_p2_shop_move_ref '
        'ON p2_shop_stock_movement (ref_type, ref_id)',

    // ── Customers ──────────────────────────────────────────────────
    'CREATE TABLE IF NOT EXISTS p2_shop_customer ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'name TEXT NOT NULL, '
        'normalized_name TEXT NOT NULL, '
        'phone TEXT NOT NULL DEFAULT \'\', '
        'address TEXT NOT NULL DEFAULT \'\', '
        'note TEXT NOT NULL DEFAULT \'\', '
        'credit_limit INTEGER, '
        'active INTEGER NOT NULL DEFAULT 1, '
        'created_at INTEGER NOT NULL)',
    'CREATE INDEX IF NOT EXISTS idx_p2_shop_customer_name '
        'ON p2_shop_customer (normalized_name)',

    // ── Invoices (posted rows immutable) ───────────────────────────
    // kind: sale | sale_return. status: posted | void | held.
    'CREATE TABLE IF NOT EXISTS p2_shop_invoice ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'number TEXT NOT NULL, '
        'date INTEGER NOT NULL, '
        'kind TEXT NOT NULL DEFAULT \'sale\', '
        'customer_id TEXT, '
        'subtotal INTEGER NOT NULL, '
        'discount_total INTEGER NOT NULL DEFAULT 0, '
        'rounding_adj INTEGER NOT NULL DEFAULT 0, '
        'total INTEGER NOT NULL, '
        'status TEXT NOT NULL DEFAULT \'posted\', '
        'note TEXT NOT NULL DEFAULT \'\', '
        'void_of TEXT, '
        'return_of TEXT, '
        'void_reason TEXT, '
        'created_at INTEGER NOT NULL)',
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_p2_shop_invoice_number '
        'ON p2_shop_invoice (number)',
    'CREATE INDEX IF NOT EXISTS idx_p2_shop_invoice_date '
        'ON p2_shop_invoice (date)',
    'CREATE INDEX IF NOT EXISTS idx_p2_shop_invoice_customer '
        'ON p2_shop_invoice (customer_id, date)',

    'CREATE TABLE IF NOT EXISTS p2_shop_invoice_item ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'invoice_id TEXT NOT NULL, '
        'product_id TEXT, '
        'name_snapshot TEXT NOT NULL, '
        'unit_snapshot TEXT NOT NULL DEFAULT \'\', '
        'qty_milli INTEGER NOT NULL, '
        'unit_price INTEGER NOT NULL, '
        'discount INTEGER NOT NULL DEFAULT 0, '
        'line_total INTEGER NOT NULL, '
        'unit_cost_snapshot INTEGER NOT NULL DEFAULT 0)',
    'CREATE INDEX IF NOT EXISTS idx_p2_shop_item_invoice '
        'ON p2_shop_invoice_item (invoice_id)',
    'CREATE INDEX IF NOT EXISTS idx_p2_shop_item_product '
        'ON p2_shop_invoice_item (product_id)',

    // ── Payments ───────────────────────────────────────────────────
    // direction: in | out. method: cash | card | transfer | cheque | other.
    // party_type: customer | supplier | none. Stage 3 adds cheque details.
    'CREATE TABLE IF NOT EXISTS p2_shop_payment ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'date INTEGER NOT NULL, '
        'direction TEXT NOT NULL, '
        'method TEXT NOT NULL, '
        'amount INTEGER NOT NULL, '
        'party_type TEXT NOT NULL DEFAULT \'none\', '
        'party_id TEXT, '
        'invoice_id TEXT, '
        'note TEXT NOT NULL DEFAULT \'\', '
        'created_at INTEGER NOT NULL)',
    'CREATE INDEX IF NOT EXISTS idx_p2_shop_payment_date '
        'ON p2_shop_payment (date)',
    'CREATE INDEX IF NOT EXISTS idx_p2_shop_payment_party '
        'ON p2_shop_payment (party_type, party_id, date)',
    'CREATE INDEX IF NOT EXISTS idx_p2_shop_payment_invoice '
        'ON p2_shop_payment (invoice_id)',

    // ── Ledger (immutable; balance = SUM; + = party owes shop) ─────
    // kind: invoice | payment | adjustment | writeoff | opening.
    'CREATE TABLE IF NOT EXISTS p2_shop_ledger_entry ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'party_type TEXT NOT NULL DEFAULT \'customer\', '
        'party_id TEXT NOT NULL, '
        'date INTEGER NOT NULL, '
        'kind TEXT NOT NULL, '
        'signed_amount INTEGER NOT NULL, '
        'ref_type TEXT NOT NULL DEFAULT \'\', '
        'ref_id TEXT, '
        'note TEXT NOT NULL DEFAULT \'\', '
        'created_at INTEGER NOT NULL)',
    'CREATE INDEX IF NOT EXISTS idx_p2_shop_ledger_party_date '
        'ON p2_shop_ledger_entry (party_type, party_id, date)',
    'CREATE INDEX IF NOT EXISTS idx_p2_shop_ledger_ref '
        'ON p2_shop_ledger_entry (ref_type, ref_id)',

    // ── Held carts (POS «نگه‌داشتن سبد») ───────────────────────────
    'CREATE TABLE IF NOT EXISTS p2_shop_held_cart ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'items_json TEXT NOT NULL, '
        'customer_id TEXT, '
        'note TEXT NOT NULL DEFAULT \'\', '
        'created_at INTEGER NOT NULL)',

    // ── Audit log (every posted/voided document) ───────────────────
    'CREATE TABLE IF NOT EXISTS p2_shop_audit_log ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'ts INTEGER NOT NULL, '
        'action TEXT NOT NULL, '
        'entity TEXT NOT NULL, '
        'ref_id TEXT, '
        'details_json TEXT NOT NULL DEFAULT \'{}\')',
    'CREATE INDEX IF NOT EXISTS idx_p2_shop_audit_ts '
        'ON p2_shop_audit_log (ts)',

    // ── Bulk price changes (batch = one undo) ──────────────────────
    'CREATE TABLE IF NOT EXISTS p2_shop_price_change ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'batch_id TEXT NOT NULL, '
        'product_id TEXT NOT NULL, '
        'old_sell_price INTEGER NOT NULL, '
        'new_sell_price INTEGER NOT NULL, '
        'old_buy_price INTEGER NOT NULL DEFAULT 0, '
        'new_buy_price INTEGER NOT NULL DEFAULT 0, '
        'applied_at INTEGER NOT NULL)',
    'CREATE INDEX IF NOT EXISTS idx_p2_shop_price_batch '
        'ON p2_shop_price_change (batch_id)',
  ];
}
