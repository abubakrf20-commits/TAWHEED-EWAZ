// Adjoining string literals build the SQL: one rule per line keeps each
// table readable in review.
// ignore_for_file: no_adjacent_strings_in_list
/// Raw-SQL schema of the personal-tools set 2 («دفتر عادت کودک» +
/// «دفتر مربی قرآن»), schema version 46.
///
/// Deliberately NOT Drift `@Table` classes, for the same reason as
/// [CareTables]: the project forbids `build_runner` runs without an explicit
/// request. Every statement is `CREATE … IF NOT EXISTS`, so a fresh install and
/// an upgrade from any released version converge on the same shape, and the
/// access layer is plain `customSelect`/`customStatement`.
///
/// Conventions inherited from the rest of the database:
///  • dates are epoch milliseconds (UTC) ints; `null` means "never", never 0;
///  • every list that the migration, the backup code and the tests must agree
///    on lives here ([allTables]) rather than being re-typed;
///  • no foreign keys — the personal2 tables are independent by design so a
///    delete of one child/student can never cascade into another tool's rows.
///
/// CHILD/STUDENT PRIVACY: these tables hold names, birth years and learning
/// notes only. No photos, no network-derived values, nothing that leaves the
/// device. A per-child «delete everything» is a targeted DELETE over
/// [kidsOwnedTables] + [teacherOwnedByStudent].
class Personal2Tables {
  Personal2Tables._();

  // ── Part A — «دفتر عادت کودک» ─────────────────────────────────────
  static const String kid = 'p2_kid';
  static const String kidHabit = 'p2_kid_habit';
  static const String kidPrayerConfig = 'p2_kid_prayer_config';
  static const String kidLog = 'p2_kid_log';
  static const String kidStarTxn = 'p2_kid_star_txn';
  static const String kidReward = 'p2_kid_reward';
  static const String kidRewardRequest = 'p2_kid_reward_request';
  static const String kidSettings = 'p2_kid_settings';

  // ── Part B — «دفتر مربی قرآن» ─────────────────────────────────────
  static const String classGroup = 'p2_class_group';
  static const String student = 'p2_student';
  static const String session = 'p2_session';
  static const String attendance = 'p2_attendance';
  static const String lessonRecord = 'p2_lesson_record';
  static const String teacherSettings = 'p2_teacher_settings';

  // ── Shared ────────────────────────────────────────────────────────
  /// Editable template overrides (TemplateStore). One row per overridden key.
  static const String templateOverride = 'p2_template_override';

  /// Every table this feature owns. The migration test and the backup
  /// round-trip test read this list, so a table cannot exist in one and be
  /// missing in the other.
  static const List<String> allTables = [
    kid,
    kidHabit,
    kidPrayerConfig,
    kidLog,
    kidStarTxn,
    kidReward,
    kidRewardRequest,
    kidSettings,
    classGroup,
    student,
    session,
    attendance,
    lessonRecord,
    teacherSettings,
    templateOverride,
  ];

  /// Tables owned by the kids tool only — «delete everything» for a child.
  static const List<String> kidsOwnedTables = [
    kid,
    kidHabit,
    kidPrayerConfig,
    kidLog,
    kidStarTxn,
    kidReward,
    kidRewardRequest,
    kidSettings,
  ];

  /// Tables owned by the teacher tool only.
  static const List<String> teacherOwnedTables = [
    classGroup,
    student,
    session,
    attendance,
    lessonRecord,
    teacherSettings,
  ];

  static const List<String> createStatements = [
    // ── Kids: children ─────────────────────────────────────────────
    'CREATE TABLE IF NOT EXISTS p2_kid ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'name TEXT NOT NULL, '
        'birth_year INTEGER, '
        'color_key TEXT NOT NULL DEFAULT \'orange\', '
        'created_at INTEGER NOT NULL, '
        'archived INTEGER NOT NULL DEFAULT 0)',

    // ── Kids: habits ───────────────────────────────────────────────
    // schedule_type: daily | weekdays | one_time.
    // weekday_mask: bit 0 = Saturday … bit 6 = Friday (the app's Persian week
    // starts on شنبه). Only meaningful when schedule_type = 'weekdays'.
    'CREATE TABLE IF NOT EXISTS p2_kid_habit ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'kid_id TEXT NOT NULL, '
        'template_key TEXT, '
        'title TEXT NOT NULL, '
        'icon_key TEXT NOT NULL DEFAULT \'star\', '
        'stars INTEGER NOT NULL DEFAULT 1, '
        'schedule_type TEXT NOT NULL DEFAULT \'daily\', '
        'weekday_mask INTEGER NOT NULL DEFAULT 127, '
        'start_date INTEGER, '
        'end_date INTEGER, '
        'requires_approval INTEGER NOT NULL DEFAULT 0, '
        'active INTEGER NOT NULL DEFAULT 1, '
        'sort INTEGER NOT NULL DEFAULT 0)',
    'CREATE INDEX IF NOT EXISTS idx_p2_kid_habit_kid ON p2_kid_habit (kid_id, active, sort)',

    // ── Kids: prayer habit config (one row per child) ──────────────
    // enabled_prayers is a 5-char bitmask '10101' ordered fajr,dhuhr,asr,
    // maghrib, isha (sunrise is never a prayer).
    'CREATE TABLE IF NOT EXISTS p2_kid_prayer_config ('
        'kid_id TEXT NOT NULL PRIMARY KEY, '
        'enabled_prayers TEXT NOT NULL DEFAULT \'11111\', '
        'stars_per_prayer INTEGER NOT NULL DEFAULT 2, '
        'late_allowed INTEGER NOT NULL DEFAULT 1, '
        'late_stars_factor REAL NOT NULL DEFAULT 0.5, '
        'requires_approval INTEGER NOT NULL DEFAULT 0)',

    // ── Kids: immutable habit/prayer log ───────────────────────────
    // Exactly one of habit_id / prayer_key is set.
    // status: pending | approved | rejected | undone.
    //
    // `dedupe_key` is `child|day|habit|prayer` with empty strings for the
    // absent half. It exists because SQLite treats NULLs as *distinct* in a
    // UNIQUE index: keying the index on (kid_id, day_key, habit_id,
    // prayer_key) would let the same prayer be marked twice, and the whole
    // point of the row is that one thing happens once per day.
    'CREATE TABLE IF NOT EXISTS p2_kid_log ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'kid_id TEXT NOT NULL, '
        'day_key TEXT NOT NULL, '
        'date INTEGER NOT NULL, '
        'habit_id TEXT, '
        'prayer_key TEXT, '
        'dedupe_key TEXT NOT NULL, '
        'status TEXT NOT NULL DEFAULT \'approved\', '
        'stars INTEGER NOT NULL DEFAULT 0, '
        'late INTEGER NOT NULL DEFAULT 0, '
        'created_at INTEGER NOT NULL, '
        'decided_at INTEGER)',
    'CREATE INDEX IF NOT EXISTS idx_p2_kid_log_kid_date ON p2_kid_log (kid_id, date)',
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_p2_kid_log_once ON p2_kid_log (dedupe_key)',

    // ── Kids: star ledger (immutable; balance = SUM(delta)) ────────
    'CREATE TABLE IF NOT EXISTS p2_kid_star_txn ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'kid_id TEXT NOT NULL, '
        'day_key TEXT NOT NULL, '
        'date INTEGER NOT NULL, '
        'delta INTEGER NOT NULL, '
        'reason TEXT NOT NULL, '
        'ref_id TEXT, '
        'note TEXT NOT NULL DEFAULT \'\', '
        'created_at INTEGER NOT NULL)',
    'CREATE INDEX IF NOT EXISTS idx_p2_kid_star_txn_kid_date ON p2_kid_star_txn (kid_id, date)',
    // Idempotent reward approval: one ledger row per reward request.
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_p2_kid_star_txn_ref ON p2_kid_star_txn (reason, ref_id)',

    // ── Kids: rewards ──────────────────────────────────────────────
    // kid_id null = available to every child of the account.
    'CREATE TABLE IF NOT EXISTS p2_kid_reward ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'kid_id TEXT, '
        'template_key TEXT, '
        'title TEXT NOT NULL, '
        'icon_key TEXT NOT NULL DEFAULT \'gift\', '
        'cost_stars INTEGER NOT NULL, '
        'weekly_limit INTEGER, '
        'active INTEGER NOT NULL DEFAULT 1, '
        'sort INTEGER NOT NULL DEFAULT 0)',
    'CREATE INDEX IF NOT EXISTS idx_p2_kid_reward_kid ON p2_kid_reward (kid_id, active, sort)',

    'CREATE TABLE IF NOT EXISTS p2_kid_reward_request ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'kid_id TEXT NOT NULL, '
        'reward_id TEXT NOT NULL, '
        'status TEXT NOT NULL DEFAULT \'requested\', '
        'stars INTEGER NOT NULL, '
        'created_at INTEGER NOT NULL, '
        'decided_at INTEGER)',
    'CREATE INDEX IF NOT EXISTS idx_p2_kid_reward_req_kid ON p2_kid_reward_request (kid_id, status, created_at)',

    // ── Kids: settings (single row, id = 'kids') ───────────────────
    // day_start_minutes: minutes after local midnight that start a new day
    // (default 0 = midnight). Stored per tool, not per child.
    'CREATE TABLE IF NOT EXISTS p2_kid_settings ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'day_start_minutes INTEGER NOT NULL DEFAULT 0, '
        'show_sibling_comparison INTEGER NOT NULL DEFAULT 0, '
        'parent_pin_enabled INTEGER NOT NULL DEFAULT 0, '
        'evening_summary_enabled INTEGER NOT NULL DEFAULT 0, '
        'evening_summary_minutes INTEGER NOT NULL DEFAULT 1200, '
        'approvals_nudge_enabled INTEGER NOT NULL DEFAULT 0, '
        'quiet_start_minutes INTEGER NOT NULL DEFAULT 1320, '
        'quiet_end_minutes INTEGER NOT NULL DEFAULT 420)',

    // ── Teacher: class groups ──────────────────────────────────────
    'CREATE TABLE IF NOT EXISTS p2_class_group ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'name TEXT NOT NULL, '
        'place TEXT NOT NULL DEFAULT \'\', '
        'weekdays_mask INTEGER NOT NULL DEFAULT 127, '
        'start_minutes INTEGER, '
        'duration_min INTEGER, '
        'archived INTEGER NOT NULL DEFAULT 0, '
        'created_at INTEGER NOT NULL)',
    'CREATE INDEX IF NOT EXISTS idx_p2_class_group_archived ON p2_class_group (archived, created_at)',

    // ── Teacher: students ──────────────────────────────────────────
    'CREATE TABLE IF NOT EXISTS p2_student ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'class_id TEXT NOT NULL, '
        'name TEXT NOT NULL, '
        'birth_year INTEGER, '
        'parent_name TEXT NOT NULL DEFAULT \'\', '
        'parent_phone TEXT NOT NULL DEFAULT \'\', '
        'note TEXT NOT NULL DEFAULT \'\', '
        'active INTEGER NOT NULL DEFAULT 1, '
        'joined_at INTEGER NOT NULL)',
    'CREATE INDEX IF NOT EXISTS idx_p2_student_class ON p2_student (class_id, active)',

    // ── Teacher: sessions ──────────────────────────────────────────
    // The `session` keyword is fine as an identifier in SQLite but is avoided
    // in table names to keep every statement readable.
    'CREATE TABLE IF NOT EXISTS p2_session ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'class_id TEXT NOT NULL, '
        'day_key TEXT NOT NULL, '
        'date INTEGER NOT NULL, '
        'number INTEGER NOT NULL DEFAULT 1, '
        'note TEXT NOT NULL DEFAULT \'\', '
        'created_at INTEGER NOT NULL, '
        'closed INTEGER NOT NULL DEFAULT 0)',
    'CREATE INDEX IF NOT EXISTS idx_p2_session_class_date ON p2_session (class_id, date)',
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_p2_session_once ON p2_session (class_id, day_key)',

    // ── Teacher: attendance ────────────────────────────────────────
    // status: present | absent | late | excused.
    'CREATE TABLE IF NOT EXISTS p2_attendance ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'session_id TEXT NOT NULL, '
        'student_id TEXT NOT NULL, '
        'status TEXT NOT NULL, '
        'note TEXT NOT NULL DEFAULT \'\', '
        'created_at INTEGER NOT NULL)',
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_p2_attendance_once ON p2_attendance (session_id, student_id)',
    'CREATE INDEX IF NOT EXISTS idx_p2_attendance_student ON p2_attendance (student_id)',

    // ── Teacher: lesson records ────────────────────────────────────
    // type: recitation | hifz | review | tajweed.
    // Pages 1..604, lines 1..15 — validated in Dart, not in SQL, so the
    // metadata (604/15) stays one constant in the domain layer.
    // tajweed_tags is a JSON array of tag keys.
    'CREATE TABLE IF NOT EXISTS p2_lesson_record ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'session_id TEXT NOT NULL, '
        'student_id TEXT NOT NULL, '
        'day_key TEXT NOT NULL, '
        'date INTEGER NOT NULL, '
        'type TEXT NOT NULL, '
        'page_start INTEGER NOT NULL, '
        'page_end INTEGER NOT NULL, '
        'line_start INTEGER, '
        'line_end INTEGER, '
        'grade_key TEXT, '
        'mistake_count INTEGER NOT NULL DEFAULT 0, '
        'tajweed_tags TEXT NOT NULL DEFAULT \'[]\', '
        'note TEXT NOT NULL DEFAULT \'\', '
        'next_page_start INTEGER, '
        'next_page_end INTEGER, '
        'next_line_start INTEGER, '
        'next_line_end INTEGER, '
        'created_at INTEGER NOT NULL)',
    'CREATE INDEX IF NOT EXISTS idx_p2_lesson_student_date ON p2_lesson_record (student_id, date)',
    'CREATE INDEX IF NOT EXISTS idx_p2_lesson_session ON p2_lesson_record (session_id)',

    // ── Teacher: settings (single row, id = 'teacher') ─────────────
    'CREATE TABLE IF NOT EXISTS p2_teacher_settings ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'class_name TEXT NOT NULL DEFAULT \'\', '
        'mosque_name TEXT NOT NULL DEFAULT \'\', '
        'teacher_name TEXT NOT NULL DEFAULT \'\', '
        'excused_excluded INTEGER NOT NULL DEFAULT 1, '
        'absence_streak_alert INTEGER NOT NULL DEFAULT 1, '
        'reminders_enabled INTEGER NOT NULL DEFAULT 0, '
        'class_start_reminder INTEGER NOT NULL DEFAULT 1, '
        'unrecorded_reminder INTEGER NOT NULL DEFAULT 1, '
        'weekly_summary INTEGER NOT NULL DEFAULT 0, '
        'quiet_start_minutes INTEGER NOT NULL DEFAULT 1320, '
        'quiet_end_minutes INTEGER NOT NULL DEFAULT 420)',

    // ── Shared: template overrides ────────────────────────────────
    'CREATE TABLE IF NOT EXISTS p2_template_override ('
        'template_key TEXT NOT NULL PRIMARY KEY, '
        'kind TEXT NOT NULL, '
        'payload TEXT NOT NULL, '
        'updated_at INTEGER NOT NULL)',
  ];
}
