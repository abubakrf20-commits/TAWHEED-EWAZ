/// Raw-SQL DDL for the stage-3 personal tools (schema 47):
/// «صله رحم» and «قلک».
///
/// Same rules as the stage-1/2 tables: no Drift codegen (`build_runner` is not
/// run in this repo), additive only, and every statement is `IF NOT EXISTS` so
/// a half-applied migration is safe to re-run.
///
/// «کفاره و فدیه» owns **no** table: it computes from `assets/data/
/// kaffara_rules.json` and its only write is an obligation in the finance
/// ledger, which already has a table and a backup path.
///
/// Dates are day-granular `yyyy-MM-dd` strings — a contact day, a deposit day
/// and a qaza day are calendar days, not instants that shift with a timezone.
class FamilyFaithTables {
  FamilyFaithTables._();

  static const List<String> createStatements = [
    // ── صله رحم ────────────────────────────────────────────────────────────
    '''
    CREATE TABLE IF NOT EXISTS relative (
      id TEXT NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      relation_key TEXT NOT NULL,
      relation_label TEXT NOT NULL DEFAULT '',
      phone TEXT NOT NULL DEFAULT '',
      birthday TEXT,
      note TEXT NOT NULL DEFAULT '',
      gift_note TEXT NOT NULL DEFAULT '',
      gift_audience TEXT NOT NULL DEFAULT 'all',
      interval_days INTEGER NOT NULL DEFAULT 30,
      last_contact_at TEXT,
      snooze_until TEXT,
      muted INTEGER NOT NULL DEFAULT 0,
      archived INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS relative_contact (
      id TEXT NOT NULL PRIMARY KEY,
      relative_id TEXT NOT NULL,
      date TEXT NOT NULL,
      kind TEXT NOT NULL,
      note TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL
    )
    ''',
    // ── قلک ────────────────────────────────────────────────────────────────
    '''
    CREATE TABLE IF NOT EXISTS savings_goal (
      id TEXT NOT NULL PRIMARY KEY,
      title TEXT NOT NULL,
      target_amount REAL NOT NULL,
      target_date TEXT,
      icon_key TEXT NOT NULL DEFAULT 'savings',
      accent_key TEXT NOT NULL DEFAULT 'gold',
      note TEXT NOT NULL DEFAULT '',
      remind_weekly INTEGER NOT NULL DEFAULT 0,
      archived INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS savings_deposit (
      id TEXT NOT NULL PRIMARY KEY,
      goal_id TEXT NOT NULL,
      date TEXT NOT NULL,
      amount REAL NOT NULL,
      note TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL
    )
    ''',
  ];

  static const List<String> indexStatements = [
    'CREATE INDEX IF NOT EXISTS idx_relative_active ON relative (archived, last_contact_at)',
    'CREATE INDEX IF NOT EXISTS idx_relative_contact_relative ON relative_contact (relative_id, date)',
    'CREATE INDEX IF NOT EXISTS idx_savings_deposit_goal ON savings_deposit (goal_id, date)',
  ];

  /// Tables the backup/restore round trip must include. Restore copies the
  /// intersection of table names generically, so this list exists for tests
  /// and for the report. «کفاره و فدیه» owns none: it keeps no state of its
  /// own, only the finance obligation it writes.
  static const List<String> tableNames = [
    'relative',
    'relative_contact',
    'savings_goal',
    'savings_deposit',
  ];
}
