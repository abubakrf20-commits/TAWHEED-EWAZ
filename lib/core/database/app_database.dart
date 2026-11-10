import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:meta/meta.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/features/settings/data/tables/settings_table.dart';
import 'package:tawheeed/features/adhkar/data/tables/azkar_status_table.dart';
import 'package:tawheeed/features/adhkar/tasbih/data/tables/tasbih_table.dart';
import 'package:tawheeed/features/adhkar/tasbih/data/tables/tasbih_dhikr_table.dart';
import 'package:tawheeed/features/adhkar/tasbih/data/tables/tasbih_settings_table.dart';
import 'package:tawheeed/features/adhkar/duas/data/tables/dua_table.dart';
import 'package:tawheeed/features/books/data/tables/book_table.dart';
import 'package:tawheeed/features/books/data/tables/book_bookmark_table.dart';
import 'package:tawheeed/features/notes/data/tables/note_table.dart';
import 'package:tawheeed/features/khatm/data/tables/khatm_table.dart';
import 'package:tawheeed/features/reminders/data/tables/reminder_table.dart';
import 'package:tawheeed/features/worship/data/tables/daily_status_table.dart';
import 'package:tawheeed/features/prayer/data/tables/period_record_table.dart';
import 'package:tawheeed/features/prayer/data/tables/prayer_tracker_table.dart';
import 'package:tawheeed/features/goals/data/tables/goal_table.dart';
import 'package:tawheeed/features/goals/data/tables/goal_progress_table.dart';
import 'package:tawheeed/features/personal_info/data/tables/personal_profile_table.dart';
import 'package:tawheeed/features/personal_info/data/tables/identity_document_table.dart';
import 'package:tawheeed/features/personal_info/data/tables/credential_table.dart';
import 'package:tawheeed/features/personal_info/data/tables/asset_table.dart';
import 'package:tawheeed/features/personal_info/data/tables/insurance_table.dart';
import 'package:tawheeed/features/personal_info/data/tables/emergency_contact_table.dart';
import 'package:tawheeed/features/personal_info/data/tables/expiry_item_table.dart';
import 'package:tawheeed/features/tasks/data/tables/task_table.dart';
import 'package:tawheeed/features/tasks/data/tables/task_aux_tables.dart';
import 'package:tawheeed/features/expenses/data/tables/expense_table.dart';
import 'package:tawheeed/features/hifz/data/tables/hafiz_table.dart';
import 'package:tawheeed/features/hifz/data/tables/hifz_lesson_table.dart';
import 'package:tawheeed/features/hifz/data/tables/hifz_review_table.dart';
import 'package:tawheeed/features/tools/calculator/data/tables/calculator_record_table.dart';
import 'package:tawheeed/features/tools/dongi/data/tables/dangi_group_table.dart';
import 'package:tawheeed/features/tools/dongi/data/tables/dangi_member_table.dart';
import 'package:tawheeed/features/tools/dongi/data/tables/dangi_expense_table.dart';
import 'package:tawheeed/features/tools/pomodoro/data/tables/pomodoro_session_table.dart';
import 'package:tawheeed/features/dorar_hadith/data/tables/favorite_dorar_hadith_table.dart';

import 'package:tawheeed/features/quran/data/tables/audio_download_table.dart';
import 'package:tawheeed/features/quran/data/tables/quran_bookmark_table.dart';
import 'package:tawheeed/features/quran/data/tables/ayah_highlight_table.dart';
import 'package:tawheeed/features/personal/data/care_tables.dart';
import 'package:tawheeed/features/personal/finance/finance_tables.dart';
import 'package:tawheeed/features/personal/family_faith/data/family_faith_tables.dart';
import 'package:tawheeed/features/personal2/data/personal2_tables.dart';
import 'package:tawheeed/features/personal2/shop/data/shop3_tables.dart';
import 'package:tawheeed/features/personal2/shop/data/shop_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    AppSettingsTable,
    ZikrStatusRecordTable,
    TasbihTable,
    TasbihDhikrTable,
    TasbihSettingsTable,
    DuaTable,
    BookTable,
    BookBookmarkTable,
    NoteTable,
    KhatmTable,
    ReminderTable,
    PeriodRecordTable,
    PrayerTrackerTable,
    DailyStatusTable,
    AudioDownloadTable,
    TasksTable,
    ExpenseTable,
    HafizTable,
    HifzLessonTable,
    HifzReviewTable,
    CalculatorRecordTable,
    DangiGroupTable,
    DangiMemberTable,
    DangiExpenseTable,
    QuranBookmarkTable,
    AyahHighlightTable,
    ExpenseBudgetTable,
    PomodoroSessionTable,
    GoalTable,
    GoalProgressTable,
    PersonalProfileTable,
    IdentityDocumentTable,
    CredentialTable,
    AssetTable,
    InsuranceTable,
    EmergencyContactTable,
    ExpiryItemTable,
    FavoriteDorarHadithTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  static const int currentSchemaVersion = 50;

  AppDatabase() : super(_openConnection());

  AppDatabase.withConnection(super.executor);

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          // Enforce referential integrity declared by Drift tables. SQLite
          // ships with FKs OFF by default — without this, any future FK is
          // silently unenforced. (Audit 3.1-3)
          await customStatement('PRAGMA foreign_keys = ON');
        },
        onCreate: (m) async {
          await m.createAll();
          // v45: «خودرو» و «خانه» — the personal care engine. Raw SQL like
          // [TaskAuxTables] (no codegen); IF NOT EXISTS, so a fresh install
          // and every upgrade path converge on the same shape.
          for (final stmt in CareTables.createStatements) {
            await customStatement(stmt);
          }
          // v46: personal-tools set 2 — same raw-SQL, IF NOT EXISTS shape, so a
          // fresh install matches every upgrade path.
          for (final stmt in Personal2Tables.createStatements) {
            await customStatement(stmt);
          }
          // v47: the shop core («حساب مغازه») — same raw-SQL, IF NOT EXISTS
          // shape, so a fresh install matches every upgrade path.
          for (final stmt in ShopTables.createStatements) {
            await customStatement(stmt);
          }
          // v48: shop stage 3 (suppliers, purchases, cheques, cash, expenses,
          // stock count) — same raw-SQL, IF NOT EXISTS shape.
          for (final stmt in Shop3Tables.createStatements) {
            await customStatement(stmt);
          }
          // v49: the personal ledger («دفتر مالی» — plans, obligations, the
          // debt book and the local-unit overrides) and the stage-3 family
          // tools (صله رحم، قلک، قضایار). Both are additive raw SQL with
          // IF NOT EXISTS, so a fresh install and every upgrade path converge
          // on the same shape.
          for (final stmt in FinanceTables.createStatements) {
            await customStatement(stmt);
          }
          for (final stmt in FinanceTables.indexStatements) {
            await customStatement(stmt);
          }
          for (final stmt in FamilyFaithTables.createStatements) {
            await customStatement(stmt);
          }
          for (final stmt in FamilyFaithTables.indexStatements) {
            await customStatement(stmt);
          }
          // Orphan cleanup (Audit 3.1-1): the schema has no FKs, so removals
          // in parent tables (dangi groups, tasbih rows) left child rows
          // behind forever. Idempotent, runs on every create/upgrade.
          await _cleanupOrphanRows();
          // Raw-SQL auxiliary tables (no Drift codegen): task completion
          // history + subtasks. IF NOT EXISTS → safe to re-run.
          for (final stmt in TaskAuxTables.createStatements) {
            await customStatement(stmt);
          }
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_reminder_enabled ON reminder_table (is_enabled, hour, minute)');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_audio_surah_verse_reciter ON audio_download_table (surah, verse, reciter_key)');
          // v38 audit indexes must exist on fresh databases too (onCreate
          // never runs onUpgrade).
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_expense_date ON expense_table (date)');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_identity_doc_profile ON identity_document_table (profile_id)');
          // v40 goals indexes must exist on fresh databases too (onCreate
          // never runs onUpgrade). The FK itself comes from createAll(),
          // since the table declaration now carries it.
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_goal_progress_goal_date ON goal_progress_table (goal_id, date)');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_goal_table_archived_active ON goal_table (is_archived, is_active)');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_goal_table_priority ON goal_table (is_archived, is_active, priority)');
          await customStatement('ANALYZE');
        },
        onUpgrade: (m, from, to) async {
          try {
            await _cleanupOrphanRows();
            if (from < 2) {
              await m.createTable(audioDownloadTable);
            }
            // v32 (out of chronological order on purpose): task completion
            // history + subtasks. Deliberately placed away from the v31
            // blocks below so this hunk stays independent in review.
            if (from < 32) {
              // Raw SQL, IF NOT EXISTS — safe to re-run, needs no codegen.
              for (final stmt in TaskAuxTables.createStatements) {
                await customStatement(stmt);
              }
            }
            if (from < 3) {
              await m.createTable(tasksTable);
            }
            if (from < 4) {
              await m.addColumn(tasbihTable, tasbihTable.totalLifetimeCount);
            }
            if (from < 5) {
              await m.addColumn(tasksTable, tasksTable.completedAt);
            }
            if (from < 6) {
              await customStatement(
                  'CREATE INDEX IF NOT EXISTS idx_reminder_enabled ON reminder_table (is_enabled, hour, minute)');
              await customStatement(
                  'CREATE INDEX IF NOT EXISTS idx_audio_surah_verse_reciter ON audio_download_table (surah, verse, reciter_key)');
            }
            if (from < 7) {
              await m.createTable(bookBookmarkTable);
            }
            if (from < 8) {
              await m.addColumn(
                  reminderTable, reminderTable.specificDate as GeneratedColumn);
            }
            if (from < 9) {
              await m.createTable(expenseTable);
              await m.createTable(calculatorRecordTable);
            }
            if (from < 10) {
              await m.addColumn(
                  reminderTable, reminderTable.prayerRef as GeneratedColumn);
              await m.addColumn(reminderTable,
                  reminderTable.prayerOffsetMinutes as GeneratedColumn);
            }
            if (from < 11) {
              await m.addColumn(periodRecordTable,
                  periodRecordTable.symptoms as GeneratedColumn);
              await m.addColumn(periodRecordTable,
                  periodRecordTable.notes as GeneratedColumn);
            }
            if (from < 12) {
              await m.createTable(prayerTrackerTable);
            }
            if (from < 13) {
              await m.createTable(dailyStatusTable);
            }
            if (from < 14) {
              await m.addColumn(
                  tasbihTable, tasbihTable.isDefault as GeneratedColumn);
              await m.addColumn(
                  tasbihTable, tasbihTable.isEnabled as GeneratedColumn);
            }
            if (from < 15) {
              await m.addColumn(
                  bookTable, bookTable.startedAt as GeneratedColumn);
              await m.addColumn(
                  bookTable, bookTable.completedAt as GeneratedColumn);
            }
            if (from < 16) {
              await m.addColumn(
                  khatmTable, khatmTable.dailyRead as GeneratedColumn);
            }
            if (from < 17) {
              await m.createTable(hafizTable);
              await m.createTable(hifzLessonTable);
              await m.createTable(hifzReviewTable);
            } else if (from < 21) {
              // Only add quality column if the table already existed (from < 21 but >= 17)
              await m.addColumn(hifzLessonTable, hifzLessonTable.quality);
            }
            if (from < 18) {
              // NOTE: createTable uses the CURRENT table definition, which
              // already includes the `category` column. Therefore the 19
              // addColumn below must NOT run when we just created the table
              // (it would fail with "duplicate column name: category").
              await m.createTable(dangiGroupTable);
              await m.createTable(dangiMemberTable);
              await m.createTable(dangiExpenseTable);
            } else if (from < 19) {
              await m.addColumn(dangiExpenseTable, dangiExpenseTable.category);
            }
            if (from < 22) {
              // Flashcard feature removed — drop the orphaned tables.
              await customStatement(
                  'DROP TABLE IF EXISTS flashcard_deck_table');
              await customStatement(
                  'DROP TABLE IF EXISTS flashcard_card_table');
              await customStatement(
                  'DROP TABLE IF EXISTS flashcard_state_table');
              await customStatement(
                  'DROP TABLE IF EXISTS flashcard_review_table');
            }
            if (from < 23) {
              // Evaluation worship scoring now lives in the settings row
              // (previously half in SharedPreferences under `eval_*` keys).
              // All columns carry a DEFAULT so the ALTER succeeds on rows
              // that already exist.
              await m.addColumn(appSettingsTable, appSettingsTable.fardhPoint);
              await m.addColumn(appSettingsTable, appSettingsTable.sunnahPoint);
              await m.addColumn(appSettingsTable, appSettingsTable.duhaPoint);
              await m.addColumn(appSettingsTable, appSettingsTable.adhkarPoint);
              await m.addColumn(appSettingsTable, appSettingsTable.tasbihPoint);
              await m.addColumn(
                  appSettingsTable, appSettingsTable.worshipMultiplier);
              await m.addColumn(
                  appSettingsTable, appSettingsTable.excludedWorship);
              await m.addColumn(
                  appSettingsTable, appSettingsTable.customWorshipItems);
              await m.addColumn(
                  appSettingsTable, appSettingsTable.hiddenWorshipItems);
            }
            if (from < 24) {
              await m.createTable(quranBookmarkTable);
            }
            if (from < 25) {
              // Elevation (horizon-dip) correction toggle for sunrise/maghrib.
              await m.addColumn(
                  appSettingsTable, appSettingsTable.elevationCorrection);
            }
            if (from < 26) {
              // Elevation correction now ships OFF by default — reset any
              // value stored while it briefly defaulted to ON, so the user
              // makes an explicit opt-in.
              await customStatement(
                  'UPDATE app_settings_table SET elevation_correction = 0');
            }
            if (from < 27) {
              // Per-task due-date reminder (tasks): an enabled flag plus the
              // local time ("HH:mm") the one-shot notification should fire.
              await m.addColumn(
                  tasksTable, tasksTable.remindEnabled as GeneratedColumn);
              await m.addColumn(
                  tasksTable, tasksTable.remindAt as GeneratedColumn);
            }
            if (from < 28) {
              // Expenses: recurring entries (pattern + next due date) and the
              // per-category monthly budgets table.
              await m.addColumn(
                  expenseTable, expenseTable.isRecurring as GeneratedColumn);
              await m.addColumn(
                  expenseTable, expenseTable.recurringType as GeneratedColumn);
              await m.addColumn(
                  expenseTable, expenseTable.nextDueDate as GeneratedColumn);
              await m.createTable(expenseBudgetTable);
            }
            if (from < 29) {
              // Notes: folder grouping column ('' = no folder).
              await m.addColumn(noteTable, noteTable.folder as GeneratedColumn);
            }
            if (from < 30) {
              // Pomodoro: completed focus-session history.
              await m.createTable(pomodoroSessionTable);
            }
            if (from < 31) {
              // Prayer: high-latitude rule for Fajr/Isha (0 = middle of
              // the night, the previous hardcoded behavior).
              await m.addColumn(appSettingsTable,
                  appSettingsTable.highLatitudeRule as GeneratedColumn);
            }
            if (from < 33) {
              // Dangi: per-expense consumer amounts moved from a
              // SharedPreferences side-store into the expense row itself
              // (JSON column) so they survive backup/restore and are always
              // applied in settlement/reports. Default `{}` = legacy equal
              // split; the old key is migrated once on first load.
              //
              // NOTE: when upgrading from < 18 the dangi tables were just
              // (re)created above with the CURRENT definition, which already
              // includes consumersJson — skipping avoids the "duplicate
              // column name" error. On any newer database the table predates
              // this column, so a plain addColumn is safe (the dangi tables
              // have existed since schema 18).
              if (from >= 18) {
                await m.addColumn(
                    dangiExpenseTable, dangiExpenseTable.consumersJson);
              }
            }
            if (from < 34) {
              // Period (دوره ماهانه): distinguish حیض / نفاس / استحاضه and
              // record bleeding intensity + istihadha subtype. The table has
              // existed since before schema 11 (which already added columns to
              // it), so a plain addColumn is safe for every upgrade path.
              await m.addColumn(
                  periodRecordTable, periodRecordTable.recordType);
              await m.addColumn(periodRecordTable, periodRecordTable.flow);
              await m.addColumn(
                  periodRecordTable, periodRecordTable.istihadhaType);
            }
            if (from < 35) {
              // v35: «هدف‌گذاری» — goals + per-day progress entries.
              await m.createTable(goalTable);
              await m.createTable(goalProgressTable);
            }
            if (from < 36) {
              // v36: «اطلاعات من» — personal vault (profiles, documents,
              // credentials, assets, insurance, emergency contacts, expiry
              // items, attachments). Voice-note columns land in v37 below.
              await m.createTable(personalProfileTable);
              await m.createTable(identityDocumentTable);
              await m.createTable(credentialTable);
              await m.createTable(assetTable);
              await m.createTable(insuranceTable);
              await m.createTable(emergencyContactTable);
              await m.createTable(expiryItemTable);
            }
            if (from < 37) {
              // v37: voice notes — an audio attachment on a worship note.
              // Both columns default to empty/0, so every existing row stays
              // valid and no note needs to be rewritten.
              await m.addColumn(noteTable, noteTable.audioPath);
              await m.addColumn(noteTable, noteTable.audioDurationMs);
            }
            if (from < 38) {
              // v38 (Audit 3.1 fixes): (a) indexes on the two hot filter
              // columns — expense.date (monthly report/chart scans) and
              // identity_document.profile_id (per-profile document lookup);
              // (b) ANALYZE so the planner uses them from the first launch.
              // Guarded: upgrade fixtures and pre-v9 oddities may lack the
              // table/column, and a failed migration here would trigger the
              // whole snapshot-restore loop for zero reason — skipping an
              // index is always the safer outcome.
              if (await _columnExists('expense_table', 'date')) {
                await customStatement(
                    'CREATE INDEX IF NOT EXISTS idx_expense_date ON expense_table (date)');
              } else {
                AppLogger.warning('AppDatabase',
                    'v38: skipped idx_expense_date (expense_table.date missing)');
              }
              if (await _columnExists(
                  'identity_document_table', 'profile_id')) {
                await customStatement(
                    'CREATE INDEX IF NOT EXISTS idx_identity_doc_profile ON identity_document_table (profile_id)');
              } else {
                AppLogger.warning('AppDatabase',
                    'v38: skipped idx_identity_doc_profile (table missing)');
              }
              await customStatement('ANALYZE');
            }
            if (from < 39) {
              // v39 (Audit 8.12): permanent colored ayah highlights for
              // the Mushaf reader. New table, so create-if-missing is
              // enough; the unique index keeps one row per ayah.
              await m.createTable(ayahHighlightTable);
            }
            if (from < 40) {
              // v40 (goals hardening): (a) a real foreign key from
              // goal_progress_table.goal_id to goal_table.id with ON DELETE
              // CASCADE, and (b) the two indexes the goals list needs.
              //
              // SQLite cannot add a constraint to an existing table, so the
              // child table is rebuilt: create the new shape, copy the rows,
              // drop the old table, rename. That copy is the delicate part:
              // `PRAGMA foreign_keys` is a NO-OP inside a transaction (which
              // is where onUpgrade runs), but `defer_foreign_keys` IS
              // settable there and pushes the FK checks to COMMIT. Without
              // it, a single pre-existing orphan row aborts the whole
              // migration, and the failure path above would mark the DB
              // dirty and restore a backup on the next launch.
              //
              // Orphans are deleted outright rather than copied: they point
              // at goals that no longer exist, so they are unreachable
              // garbage which still counts toward `SUM(amount)` for a goal id
              // that has no row. See [_cleanupOrphanRows].
              await customStatement('PRAGMA defer_foreign_keys = ON');
              // Belt and braces: [_cleanupOrphanRows] already ran at the top
              // of onUpgrade and includes this same statement, but it catches
              // per-statement errors and carries on. If that sweep failed
              // silently, one surviving orphan would abort the whole migration
              // at COMMIT — which is the failure that marks the database dirty
              // and restores a backup on the next launch. Cheap to be certain.
              await customStatement(
                'DELETE FROM goal_progress_table WHERE goal_id NOT IN '
                '(SELECT id FROM goal_table)',
              );
              await customStatement(
                'CREATE TABLE goal_progress_table_v40 ('
                'id TEXT NOT NULL, '
                'goal_id TEXT NOT NULL '
                'REFERENCES goal_table(id) ON DELETE CASCADE, '
                'date TEXT NOT NULL, '
                'amount INTEGER NOT NULL DEFAULT 0, '
                'created_at INTEGER NOT NULL, '
                'PRIMARY KEY (id))',
              );
              await customStatement(
                'INSERT INTO goal_progress_table_v40 '
                '(id, goal_id, date, amount, created_at) '
                'SELECT id, goal_id, date, amount, created_at '
                'FROM goal_progress_table',
              );
              await customStatement('DROP TABLE goal_progress_table');
              await customStatement(
                'ALTER TABLE goal_progress_table_v40 '
                'RENAME TO goal_progress_table',
              );
              // The two hot goals queries: SUM per goal for the list, and
              // the per-day sum on the detail screen. Both are now index
              // seeks instead of full scans of every progress row ever
              // written.
              await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_goal_progress_goal_date '
                'ON goal_progress_table (goal_id, date)',
              );
              await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_goal_table_archived_active '
                'ON goal_table (is_archived, is_active)',
              );
            }

            if (from < 41) {
              // v41 (goals phase 2): the six columns the feature set needs.
              // All of them are additive with a default, so this is a handful
              // of ALTER TABLEs rather than the table rebuild v40 needed —
              // an existing user's goals are never rewritten here, and the
              // new columns land as the documented default rather than NULL
              // or a random value.
              //
              // Each is ADD COLUMN with a NOT NULL DEFAULT, which SQLite
              // accepts by rewriting existing rows logically (no table copy),
              // so this is cheap even for a large goals table.
              //
              // The "if not present" check is load-bearing, not defensive
              // padding. Any install older than the goals feature reaches
              // this point through the `createTable(goalTable)` branch above,
              // which builds the table from the *current* Drift definition —
              // already including these six columns. An unconditional
              // ALTER then dies with "duplicate column name", fails the whole
              // migration, marks the database dirty and restores a backup.
              // It is also what makes a half-finished migration retryable.
              final existingColumns = (await customSelect(
                'PRAGMA table_info(goal_table)',
              ).get())
                  .map((r) => r.read<String>('name'))
                  .toSet();
              for (final column in <(String, String)>[
                ('daily_target', 'daily_target INTEGER NOT NULL DEFAULT 0'),
                ('priority', 'priority INTEGER NOT NULL DEFAULT 1'),
                ('remind_enabled', 'remind_enabled INTEGER NOT NULL DEFAULT 0'),
                ('remind_at', "remind_at TEXT NOT NULL DEFAULT ''"),
                ('linked_type', "linked_type TEXT NOT NULL DEFAULT ''"),
                ('linked_id', "linked_id TEXT NOT NULL DEFAULT ''"),
              ]) {
                if (existingColumns.contains(column.$1)) continue;
                await customStatement(
                  'ALTER TABLE goal_table ADD COLUMN ${column.$2}',
                );
              }
              await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_goal_table_priority '
                'ON goal_table (is_archived, is_active, priority)',
              );
            }
            if (from < 42) {
              // v42: drop the never-shipped standalone-attachments table.
              // The feature only ever existed as a schema + DAO/repo surface
              // (no screen ever read it), so there is no data to migrate:
              // any row it might hold would reference a file nothing
              // displays. DROP IF EXISTS keeps upgrade fixtures and pre-v36
              // databases alive - an unknown-table error aborts the whole
              // migration and triggers the snapshot-restore loop.
              await customStatement('DROP TABLE IF EXISTS attachment_table');
            }
            if (from < 43) {
              // v43: المفضلةٔ جستجوی احادیث (دorar.net) — جدول تازه، بدون
              // دادهٔ قبلی برای مهاجرت.
              await m.createTable(favoriteDorarHadithTable);
            }
            if (from < 44) {
              // v44: the two settings columns that entered the table
              // definition and never got a migration step —
              // `friday_prayer_time` (`55cc89e`, which left
              // [currentSchemaVersion] alone, so onUpgrade never ran for it)
              // and `quran_theme_mode` (`4f0cd47`, the commit that introduced
              // this migration strategy, which never ALTERed the settings
              // table either).
              //
              // A fresh install never noticed: onCreate builds the table from
              // the CURRENT definition. Every install whose database predates
              // those commits had neither column, and because Drift names
              // every column in its generated SELECT and UPDATE, each settings
              // read AND write died with "no such column: friday_prayer_time".
              // The notifier catches that and reverts its own state, so the
              // whole Settings page rendered the factory defaults with no
              // control responding — the reported «ظاهر برنامه / تم برنامه /
              // اندازه فونت / صدای اذان قفل است».
              //
              // PRAGMA-guarded, exactly like the v41 goal columns: the ALTER
              // must be skipped where the column already exists (fresh
              // installs included), since a duplicate-column error would abort
              // the whole migration and trip the snapshot-restore path.
              final existing = (await customSelect(
                'PRAGMA table_info(app_settings_table)',
              ).get())
                  .map((r) => r.read<String>('name'))
                  .toSet();
              if (existing.isEmpty) {
                // No settings table at all (a pre-v1 or hand-made database):
                // build it from the current definition instead of ALTERing a
                // table that is not there.
                await m.createTable(appSettingsTable);
              } else {
                if (!existing.contains('friday_prayer_time')) {
                  // Nullable in the definition, so no DEFAULT is required.
                  await customStatement(
                    'ALTER TABLE app_settings_table '
                    'ADD COLUMN friday_prayer_time TEXT',
                  );
                }
                if (!existing.contains('quran_theme_mode')) {
                  // NOT NULL needs a DEFAULT for the rows already present;
                  // 'light' is the entity's own default value.
                  await customStatement(
                    'ALTER TABLE app_settings_table '
                    "ADD COLUMN quran_theme_mode TEXT NOT NULL DEFAULT 'light'",
                  );
                }
              }
            }
            if (from < 45) {
              // v45: the personal care tables (car + home). Additive only —
              // they hold no data on an upgrade, so CREATE IF NOT EXISTS is
              // the whole migration, and re-running it is a no-op.
              for (final stmt in CareTables.createStatements) {
                await customStatement(stmt);
              }
            }
            if (from < 46) {
              // v46: personal-tools set 2 (child habits + Quran teacher
              // ledger). Additive only — the tables are empty on upgrade, so
              // CREATE IF NOT EXISTS is the whole migration and re-running it
              // is a no-op. Same raw-SQL precedent as v45's CareTables, which
              // also keeps `build_runner` out of the loop.
              for (final stmt in Personal2Tables.createStatements) {
                await customStatement(stmt);
              }
            }
            if (from < 47) {
              // v47: the shop core («حساب مغازه»). Additive only — CREATE IF
              // NOT EXISTS is the whole migration and re-running it is a
              // no-op, exactly like v46 above.
              for (final stmt in ShopTables.createStatements) {
                await customStatement(stmt);
              }
            }
            if (from < 48) {
              // v48: shop stage 3. Additive only, no-op on re-run.
              for (final stmt in Shop3Tables.createStatements) {
                await customStatement(stmt);
              }
            }
            if (from < 49) {
              // v49: the personal ledger («دفتر مالی») and the stage-3 family
              // tools — relatives + contact log, savings goals + deposits,
              // qaza counters + log. Additive only, IF NOT EXISTS, so a
              // half-finished migration is retryable and an install that only
              // ever had the screens gets its tables.
              //
              // The family/faith line numbered its own schema differently (it
              // called finance v46 and the family tools v47), so an install
              // coming from that build reaches 49 with v46/v47 already marked
              // done and would never create the kids/teacher and shop tables
              // those numbers hold here. Every statement is IF NOT EXISTS, so
              // converging all three sets in this block costs nothing on the
              // normal path and closes that upgrade hole.
              for (final stmt in Personal2Tables.createStatements) {
                await customStatement(stmt);
              }
              for (final stmt in ShopTables.createStatements) {
                await customStatement(stmt);
              }
              for (final stmt in Shop3Tables.createStatements) {
                await customStatement(stmt);
              }
              for (final stmt in FinanceTables.createStatements) {
                await customStatement(stmt);
              }
              for (final stmt in FinanceTables.indexStatements) {
                await customStatement(stmt);
              }
              for (final stmt in FamilyFaithTables.createStatements) {
                await customStatement(stmt);
              }
              for (final stmt in FamilyFaithTables.indexStatements) {
                await customStatement(stmt);
              }
            }
            if (from < 50) {
              // v50: attachment_paths on care_bill (receipt photos for bills).
              // PRAGMA-guarded like v44 — skip when the column already exists.
              final existingBill = (await customSelect(
                'PRAGMA table_info(care_bill)',
              ).get())
                  .map((r) => r.read<String>('name'))
                  .toSet();
              if (existingBill.isNotEmpty &&
                  !existingBill.contains('attachment_paths')) {
                await customStatement(
                  'ALTER TABLE care_bill '
                  'ADD COLUMN attachment_paths TEXT NOT NULL DEFAULT \'[]\'',
                );
              }
            }
            if (from < 51) {
              // v51: habit tables for the kid habit tracker.
              for (final stmt in CareTables.createStatements
                  .where((s) => s.contains('care_habit') ||
                      s.contains('habit_completion') ||
                      s.contains('care_reward'))) {
                await customStatement(stmt);
              }
            }
          } catch (e, st) {
            // Migration failed. NEVER drop and recreate the tables here — that
            // silently destroys every byte of user data, and combined with the
            // marker restore in [_openConnection] it turns any buggy migration
            // into a per-launch wipe loop (restore backup → migrate → fail →
            // wipe → marker → next launch repeats). This exact bug erased all
            // user data on every app open (schema 15→16 addColumn of a NOT
            // NULL column).
            //
            // Instead: preserve the failing file for forensic recovery, write
            // the marker so the NEXT launch restores the last known-good
            // snapshot (taken before the migration ran) and retries the
            // migration, and surface the error loudly.
            try {
              final dir = await getApplicationDocumentsDirectory();
              final file = File(p.join(dir.path, 'app.sqlite'));
              if (await file.exists()) {
                await _forensicCopy(dir, file);
              }
              final marker =
                  File(p.join(dir.path, 'app.sqlite.migration_failed'));
              await marker.writeAsString(
                DateTime.now().toIso8601String(),
                flush: true,
              );
            } catch (backupErr) {
              AppLogger.warning(
                  'AppDatabase', 'pre-rollback backup copy failed: $backupErr');
            }
            AppLogger.error('AppDatabase migration failed', e, st);
            rethrow;
          }
        },
      );

  /// True when [table] exists and has a [column] (PRAGMA table_info).
  /// Used by raw-SQL migrations that must not assume a table is present.
  Future<bool> _columnExists(String table, String column) async {
    try {
      final rows = await customSelect('PRAGMA table_info($table)').get();
      return rows.any((r) => r.read<String>('name') == column);
    } catch (_) {
      // PRAGMA unavailable (pre-v9 oddity / transient lock): treat the
      // column as missing — the caller safely skips that index.
      return false;
    }
  }

  /// Removes child rows whose parent no longer exists (Audit 3.1-1).
  /// The schema predates FKs, so deletes in parent tables left orphans.
  /// Covers the parent→child relations that actually delete parents:
  /// dangi group → members/expenses, tasbih → per-tasbih dhikr rows,
  /// personal profile → identity documents (Audit 3.1-2: documents outlived
  /// their profile forever). Idempotent; safe on fresh databases (no-op).
  /// Never throws.
  Future<void> _cleanupOrphanRows() async {
    const statements = [
      'DELETE FROM dangi_member_table WHERE group_id NOT IN (SELECT id FROM dangi_group_table)',
      'DELETE FROM dangi_expense_table WHERE group_id NOT IN (SELECT id FROM dangi_group_table)',
      'DELETE FROM tasbih_dhikr_table WHERE tasbih_id NOT IN (SELECT id FROM tasbih_table)',
      // Audit 3.1-2: identity documents of deleted profiles.
      'DELETE FROM identity_document_table WHERE profile_id NOT IN (SELECT id FROM personal_profile_table)',
      // v40: goal progress of deleted goals. The FK added in v40 prevents new
      // orphans, but this sweep also runs BEFORE that rebuild copies the rows
      // across, so pre-existing orphans do not abort the migration.
      'DELETE FROM goal_progress_table WHERE goal_id NOT IN (SELECT id FROM goal_table)',
    ];
    for (final stmt in statements) {
      try {
        await customStatement(stmt);
      } catch (e) {
        // Table may not exist on a very old DB mid-upgrade — fine.
        AppLogger.warning('AppDatabase', 'orphan cleanup skipped: $e');
      }
    }
  }

  /// Test seam: [cleanupOrphanRowsForTest] exposes the sweep so tests can
  /// exercise it without forcing a schema upgrade.
  @visibleForTesting
  Future<void> cleanupOrphanRowsForTest() => _cleanupOrphanRows();

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'app.sqlite'));
      final backup = File(p.join(dir.path, 'app.sqlite.backup'));
      final failedMarker =
          File(p.join(dir.path, 'app.sqlite.migration_failed'));

      // Recover from a failed migration (or a missing database file) using the
      // last known-good snapshot taken at a previous launch.
      if (await failedMarker.exists()) {
        await recoverFromFailedMigration(dir, file, backup, failedMarker);
      } else if (!(await file.exists()) && await backup.exists()) {
        try {
          await backup.copy(file.path);
        } catch (e) {
          AppLogger.warning(
              'AppDatabase', 'restore from last-known-good backup failed: $e');
        }
      }

      // Safety net: snapshot the database before any migration runs this
      // launch, so a failed migration can be rolled back automatically on the
      // next launch without losing recorded stats. Three rotating generations
      // are kept (a single backup proved too fragile); the copy is skipped
      // when the database is byte-identical-by-heuristic (same length, not
      // modified after the latest snapshot) to avoid pointless startup I/O.
      if (await file.exists()) {
        try {
          await _rotateSnapshot(dir, file, backup);
        } catch (e) {
          AppLogger.warning('AppDatabase', 'pre-migration snapshot failed: $e');
        }
      }

      // The database runs on its own isolate (drift's
      // [NativeDatabase.createInBackground]): every statement used to execute
      // on the UI isolate, so a slow SELECT — or a burst of writes during a
      // screen transition — could drop a frame. Only the file work above stays
      // on the UI isolate; the handle and all queries live on the worker.
      //
      // Deliberately NOT `readPool`/WAL here: this database holds the user's
      // own rows (a handful of reads, one writer), so extra read isolates buy
      // no concurrency; and WAL would let committed rows sit in
      // `app.sqlite-wal` while [_rotateSnapshot] copies `app.sqlite` alone —
      // the recovery snapshot could silently lose the most recent writes.
      //
      // Audit 4.3-2: the WorkManager isolate opens the same file while the UI
      // side may be mid-write. SQLite's default busy handler is 0ms → immediate
      // SQLITE_BUSY errors in the background sync. Give both sides a 5s retry
      // window instead.
      return NativeDatabase.createInBackground(
        file,
        setup: (db) {
          db.execute('PRAGMA busy_timeout = 5000');
        },
      );
    });
  }

  /// Number of snapshot generations kept: `app.sqlite.backup` (latest, the
  /// only one the recovery path reads) plus `.backup.1` and `.backup.2`.
  static const int _snapshotGenerations = 3;

  /// Rotates snapshots and stores a fresh copy as `app.sqlite.backup`.
  /// Skipped when [file] looks unchanged since the last snapshot. Never throws.
  static Future<void> _rotateSnapshot(
      Directory dir, File file, File backup) async {
    try {
      if (await backup.exists()) {
        final dbStat = await file.stat();
        final backupStat = await backup.stat();
        // بدون تغییر = هم‌حجم و قدیمی‌تر، به‌علاوه هش سبک سر/ته فایل. هش اینجا
        // لازم است چون تغییرات delete+insert متوازن می‌توانند هم‌حجم باشند؛
        // صرف‌نظر کردن از snapshot یعنی نقطه بازیابی گم می‌شود.
        if (dbStat.size == backupStat.size &&
            !dbStat.modified.isAfter(backupStat.modified) &&
            await _sameContentProbe(file, backup, dbStat.size)) {
          return;
        }
        // Shift backup.1 -> backup.2 (dropping the old .2), backup -> backup.1.
        // Delete-before-rename: File.rename onto an existing path fails on
        // some platforms (Windows), so removals are explicit.
        final second = File(p.join(dir.path, 'app.sqlite.backup.2'));
        if (await second.exists()) await second.delete();
        final first = File(p.join(dir.path, 'app.sqlite.backup.1'));
        if (await first.exists()) {
          await first.rename(second.path);
        }
        await backup.rename(first.path);
      }
      await file.copy(backup.path);
    } catch (e) {
      AppLogger.warning('AppDatabase', 'snapshot rotation failed: $e');
    }
  }

  /// Cheap content probe: SHA-256 over the first and last 4 KiB (or the whole
  /// file when smaller). Two balanced delete/insert changes can keep the size
  /// identical but never both ends of the file.
  static Future<bool> _sameContentProbe(File a, File b, int size) async {
    const probe = 4 * 1024;
    RandomAccessFile? ra;
    RandomAccessFile? rb;
    try {
      ra = await a.open();
      rb = await b.open();
      final headLen = size < probe ? size : probe;
      final tailLen = size < probe * 2 ? size - headLen : probe;
      final ah = await ra.read(headLen);
      final bh = await rb.read(headLen);
      if (!sha256BytesEqual(ah, bh)) return false;
      if (tailLen > 0) {
        await ra.setPosition(size - tailLen);
        await rb.setPosition(size - tailLen);
        final at = await ra.read(tailLen);
        final bt = await rb.read(tailLen);
        if (!sha256BytesEqual(at, bt)) return false;
      }
      return true;
    } catch (e) {
      // Read failure → assume changed (extra snapshot is the safe side).
      AppLogger.warning('AppDatabase', 'content probe failed: $e');
      return false;
    } finally {
      try {
        await ra?.close();
      } catch (e) {
        AppLogger.warning('AppDatabase', 'probe close A failed: $e');
      }
      try {
        await rb?.close();
      } catch (e) {
        AppLogger.warning('AppDatabase', 'probe close B failed: $e');
      }
    }
  }

  static bool sha256BytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    return sha256.convert(a).toString() == sha256.convert(b).toString();
  }

  /// Keeps only the newest [_snapshotGenerations] `app.sqlite.corrupt.*`
  /// forensic copies; a deterministic migration failure used to pile them up
  /// forever. Never throws.
  static Future<void> _pruneCorruptCopies(Directory dir) async {
    try {
      final corrupt = <File>[];
      final forensic = _forensicDir(dir);
      if (await forensic.exists()) {
        await for (final entity in forensic.list()) {
          if (entity is File) corrupt.add(entity);
        }
      }
      if (corrupt.length <= _snapshotGenerations) return;
      corrupt.sort((a, b) => a.path.compareTo(b.path));
      for (var i = 0; i < corrupt.length - _snapshotGenerations; i++) {
        try {
          await corrupt[i].delete();
        } catch (e) {
          AppLogger.warning('AppDatabase', 'corrupt copy delete failed: $e');
        }
      }
    } catch (e) {
      AppLogger.warning('AppDatabase', 'corrupt copy prune failed: $e');
    }
  }

  /// Directory holding forensic copies of databases that failed to migrate.
  ///
  /// These live in a subdirectory on purpose: Android backup rules match exact
  /// paths and have no wildcards, so timestamped `app.sqlite.corrupt.<ms>`
  /// files sitting in the documents root could never be excluded and every one
  /// of them (a full copy of the user's data) was uploaded to the cloud. One
  /// excluded directory covers them all.
  static Directory _forensicDir(Directory dir) =>
      Directory(p.join(dir.path, 'database_diagnostics'));

  /// Copies [file] into the forensic directory and prunes old generations.
  /// Returns the copy, or null when it could not be written. Never throws.
  static Future<File?> _forensicCopy(Directory dir, File file) async {
    try {
      final target = _forensicDir(dir);
      if (!await target.exists()) await target.create(recursive: true);
      final copy = File(p.join(
        target.path,
        'app.sqlite.${DateTime.now().millisecondsSinceEpoch}.sqlite',
      ));
      await file.copy(copy.path);
      await _pruneCorruptCopies(dir);
      return copy;
    } catch (e) {
      AppLogger.warning('AppDatabase', 'forensic copy failed: $e');
      return null;
    }
  }

  /// Rolls a database back to the pre-migration snapshot after a migration
  /// failed, then clears the marker so the next launch retries.
  ///
  /// Properties that the old inline version lacked:
  ///  * the restore is atomic — the snapshot lands on a temp file and is
  ///    renamed over `app.sqlite`, so a crash mid-copy can never leave a
  ///    truncated database behind;
  ///  * the half-migrated file is preserved as a forensic copy before being
  ///    replaced, so nothing is destroyed if the snapshot itself turns out to
  ///    be unusable;
  ///  * the marker is deleted only after a successful restore. Without a
  ///    snapshot there is nothing to roll back to, so the marker stays and the
  ///    condition is retried (and logged) instead of silently keeping a
  ///    half-migrated database and dropping the only recovery signal.
  ///
  /// Never throws: a failure here must not block the launch. Public so the
  /// behaviour is covered by tests rather than only by inspection.
  static Future<void> recoverFromFailedMigration(
    Directory dir,
    File file,
    File backup,
    File marker,
  ) async {
    try {
      if (!await backup.exists()) {
        // Nothing to roll back to. Keep the marker: the next launch may find a
        // snapshot (e.g. after a successful copy that we could not verify).
        AppLogger.error(
          'AppDatabase',
          'a previous migration failed and no snapshot is available; '
              'keeping the current database and the marker for a later retry',
        );
        return;
      }

      if (await file.exists()) {
        await _forensicCopy(dir, file);
      }

      final temp = File(p.join(dir.path, 'app.sqlite.restore.tmp'));
      if (await temp.exists()) await temp.delete();
      await backup.copy(temp.path);
      if (await file.exists()) await file.delete();
      await temp.rename(file.path);
      await marker.delete();
      AppLogger.warning('AppDatabase',
          'recovered from a failed migration using the last-known-good snapshot');
    } catch (e) {
      AppLogger.warning(
          'AppDatabase', 'recovery from failed-migration marker failed: $e');
    }
  }
}
