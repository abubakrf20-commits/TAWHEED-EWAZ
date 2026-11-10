/// Raw-SQL DDL for «دفتر مالی» (schema 46) and the user-editable local units.
///
/// Same rules as the stage-1 care tables: no Drift codegen (`build_runner` is
/// not run in this repo), additive only, and every statement is
/// `IF NOT EXISTS` so a half-applied migration is safe to re-run.
///
/// Dates are day-granular `yyyy-MM-dd` strings for the same reason as stage 1:
/// a due date is a calendar day, not an instant that shifts with a timezone.
class FinanceTables {
  FinanceTables._();

  static const List<String> createStatements = [
    '''
    CREATE TABLE IF NOT EXISTS finance_plan (
      id TEXT NOT NULL PRIMARY KEY,
      title TEXT NOT NULL,
      kind TEXT NOT NULL,
      counterparty TEXT NOT NULL DEFAULT '',
      first_due_date TEXT NOT NULL,
      count INTEGER NOT NULL,
      amount REAL NOT NULL,
      interval_months INTEGER NOT NULL DEFAULT 1,
      total_amount REAL,
      note TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS finance_obligation (
      id TEXT NOT NULL PRIMARY KEY,
      kind TEXT NOT NULL,
      direction TEXT NOT NULL,
      title TEXT NOT NULL,
      counterparty TEXT NOT NULL DEFAULT '',
      amount REAL NOT NULL,
      due_date TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      paid_date TEXT,
      paid_amount REAL,
      plan_id TEXT,
      installment_no INTEGER,
      cheque_number TEXT NOT NULL DEFAULT '',
      bank_name TEXT NOT NULL DEFAULT '',
      note TEXT NOT NULL DEFAULT '',
      remind_before_days INTEGER NOT NULL DEFAULT 3,
      attachment_paths TEXT NOT NULL DEFAULT '[]',
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS finance_person (
      id TEXT NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      phone TEXT NOT NULL DEFAULT '',
      note TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS finance_debt_entry (
      id TEXT NOT NULL PRIMARY KEY,
      person_id TEXT NOT NULL,
      direction TEXT NOT NULL,
      amount REAL NOT NULL,
      created_date TEXT NOT NULL,
      due_date TEXT,
      note TEXT NOT NULL DEFAULT '',
      witness_note TEXT NOT NULL DEFAULT '',
      closed INTEGER NOT NULL DEFAULT 0
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS finance_debt_payment (
      id TEXT NOT NULL PRIMARY KEY,
      entry_id TEXT NOT NULL,
      date TEXT NOT NULL,
      amount REAL NOT NULL,
      note TEXT NOT NULL DEFAULT ''
    )
    ''',
    // Editable local units (من، سیر، …). Stored in the database — not in
    // SharedPreferences — so a backup carries the user's own base values.
    '''
    CREATE TABLE IF NOT EXISTS unit_local_override (
      id TEXT NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      category TEXT NOT NULL,
      factor REAL NOT NULL,
      base_unit TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
    ''',
  ];

  static const List<String> indexStatements = [
    'CREATE INDEX IF NOT EXISTS idx_finance_obligation_due ON finance_obligation (due_date, status)',
    'CREATE INDEX IF NOT EXISTS idx_finance_obligation_plan ON finance_obligation (plan_id)',
    'CREATE INDEX IF NOT EXISTS idx_finance_debt_entry_person ON finance_debt_entry (person_id)',
    'CREATE INDEX IF NOT EXISTS idx_finance_debt_payment_entry ON finance_debt_payment (entry_id)',
  ];
}
