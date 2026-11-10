/// Raw-SQL DDL for the personal-tools care tables.
///
/// Deliberately NOT Drift-generated table classes: the repository forbids
/// `build_runner`/codegen unless asked, and these tables are additive with no
/// relations to the generated ones. The project already uses this pattern for
/// task completion history ([TaskAuxTables]). `IF NOT EXISTS` makes every
/// statement safe to re-run, so a half-finished migration is retryable.
///
/// Dates are day-granular and stored as `yyyy-MM-dd` (not UTC instants): a due
/// date is a calendar day, and storing it as an instant shifts it across a
/// timezone change. See docs/CARE_ENGINE.md.
class CareTables {
  CareTables._();

  static const List<String> createStatements = [
    '''
    CREATE TABLE IF NOT EXISTS care_asset (
      id TEXT NOT NULL PRIMARY KEY,
      kind TEXT NOT NULL,
      name TEXT NOT NULL,
      meta TEXT NOT NULL DEFAULT '{}',
      archived INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS care_task (
      id TEXT NOT NULL PRIMARY KEY,
      asset_id TEXT NOT NULL,
      title TEXT NOT NULL,
      template_key TEXT NOT NULL DEFAULT '',
      category_key TEXT NOT NULL DEFAULT '',
      icon_key TEXT NOT NULL DEFAULT '',
      schedule_type TEXT NOT NULL,
      interval_days INTEGER,
      interval_km INTEGER,
      window_start_month INTEGER,
      window_start_day INTEGER,
      window_end_month INTEGER,
      window_end_day INTEGER,
      last_done_date TEXT,
      last_done_km INTEGER,
      first_due_date TEXT,
      first_due_km INTEGER,
      remind_before_days INTEGER NOT NULL DEFAULT 7,
      remind_before_km INTEGER NOT NULL DEFAULT 500,
      notes TEXT NOT NULL DEFAULT '',
      active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS care_record (
      id TEXT NOT NULL PRIMARY KEY,
      asset_id TEXT NOT NULL,
      task_id TEXT,
      title TEXT NOT NULL DEFAULT '',
      date TEXT NOT NULL,
      odometer_km INTEGER,
      cost REAL,
      note TEXT NOT NULL DEFAULT '',
      attachment_paths TEXT NOT NULL DEFAULT '[]'
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS care_odometer_reading (
      id TEXT NOT NULL PRIMARY KEY,
      asset_id TEXT NOT NULL,
      date TEXT NOT NULL,
      km INTEGER NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS care_fuel_log (
      id TEXT NOT NULL PRIMARY KEY,
      asset_id TEXT NOT NULL,
      date TEXT NOT NULL,
      liters REAL NOT NULL,
      price_per_liter REAL,
      total_cost REAL,
      odometer_km INTEGER NOT NULL,
      full_tank INTEGER NOT NULL DEFAULT 1
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS care_bill (
      id TEXT NOT NULL PRIMARY KEY,
      asset_id TEXT NOT NULL,
      type TEXT NOT NULL,
      title TEXT NOT NULL,
      recurrence TEXT NOT NULL,
      due_day INTEGER NOT NULL,
      custom_days INTEGER,
      first_due_date TEXT,
      expected_amount REAL,
      active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      attachment_paths TEXT NOT NULL DEFAULT '[]'
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS care_bill_payment (
      id TEXT NOT NULL PRIMARY KEY,
      bill_id TEXT NOT NULL,
      period_key TEXT NOT NULL,
      paid_date TEXT NOT NULL,
      amount REAL,
      note TEXT NOT NULL DEFAULT ''
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS care_warranty (
      id TEXT NOT NULL PRIMARY KEY,
      asset_id TEXT NOT NULL,
      item_name TEXT NOT NULL,
      store TEXT NOT NULL DEFAULT '',
      serial TEXT NOT NULL DEFAULT '',
      purchase_date TEXT NOT NULL,
      months INTEGER NOT NULL,
      expiry_date TEXT NOT NULL,
      receipt_paths TEXT NOT NULL DEFAULT '[]',
      notes TEXT NOT NULL DEFAULT ''
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS care_subscription (
      id TEXT NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      amount REAL NOT NULL,
      period TEXT NOT NULL,
      next_charge_date TEXT NOT NULL,
      category TEXT NOT NULL DEFAULT '',
      active INTEGER NOT NULL DEFAULT 1
    )
    ''',
    // Indexes — every hot read is scoped by asset, due date or period.
    'CREATE INDEX IF NOT EXISTS idx_care_task_asset ON care_task (asset_id, active)',
    'CREATE INDEX IF NOT EXISTS idx_care_record_asset_date ON care_record (asset_id, date)',
    'CREATE INDEX IF NOT EXISTS idx_care_record_task ON care_record (task_id)',
    'CREATE INDEX IF NOT EXISTS idx_care_reading_asset_date ON care_odometer_reading (asset_id, date)',
    'CREATE INDEX IF NOT EXISTS idx_care_fuel_asset_date ON care_fuel_log (asset_id, date)',
    'CREATE INDEX IF NOT EXISTS idx_care_bill_asset ON care_bill (asset_id, active)',
    'CREATE INDEX IF NOT EXISTS idx_care_payment_bill_period ON care_bill_payment (bill_id, period_key)',
    'CREATE INDEX IF NOT EXISTS idx_care_warranty_asset ON care_warranty (asset_id, expiry_date)',
    'CREATE INDEX IF NOT EXISTS idx_care_subscription_active ON care_subscription (active, next_charge_date)',
    '''
    CREATE TABLE IF NOT EXISTS care_habit (
      id TEXT NOT NULL PRIMARY KEY,
      kid_id TEXT NOT NULL,
      title TEXT NOT NULL,
      icon_key TEXT NOT NULL,
      color_hex TEXT NOT NULL,
      target_count INTEGER NOT NULL,
      unit TEXT NOT NULL DEFAULT '',
      start_date TEXT,
      end_date TEXT,
      active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS habit_completion (
      id TEXT NOT NULL PRIMARY KEY,
      habit_id TEXT NOT NULL,
      date TEXT NOT NULL,
      count INTEGER NOT NULL DEFAULT 1,
      notes TEXT NOT NULL DEFAULT '',
      created_at TEXT
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS care_reward (
      id TEXT NOT NULL PRIMARY KEY,
      kid_id TEXT NOT NULL,
      title TEXT NOT NULL,
      icon_key TEXT NOT NULL,
      cost_points INTEGER NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      redeemed_at TEXT
    )
    ''',
    'CREATE INDEX IF NOT EXISTS idx_care_habit_kid ON care_habit (kid_id, active)',
    'CREATE INDEX IF NOT EXISTS idx_habit_completion_habit ON habit_completion (habit_id, date)',
    'CREATE INDEX IF NOT EXISTS idx_care_reward_kid ON care_reward (kid_id)',
  ];

  /// Tables the backup/restore round trip must include. Restore copies the
  /// intersection of table names generically, so this list exists for tests
  /// and for the report.
  static const List<String> tableNames = [
    'care_asset',
    'care_task',
    'care_record',
    'care_odometer_reading',
    'care_fuel_log',
    'care_bill',
    'care_bill_payment',
    'care_warranty',
    'care_subscription',
    'care_habit',
    'habit_completion',
    'care_reward',
  ];
}
