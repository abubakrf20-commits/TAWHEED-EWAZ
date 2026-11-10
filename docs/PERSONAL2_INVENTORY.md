# PERSONAL2 — Stage 1 inventory & plan

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


Branch: `personal2/stage1-kids-teacher` · base `release/1.8.0` (5b1d5a3)
Scope: «دفتر عادت کودک» (Part A) + «دفتر مربی قرآن» (Part B), no hub page.

Everything below was read out of the working tree; paths and line numbers are
the ones this branch starts from. Nothing in this file changes behaviour — it
is the map the implementation follows.

---

## 0. Open decision (needs your answer — see §9 for both options)

The brief says: register both tools **in the existing «ابزارهای شخصی» section
only** … **nothing added to Home or More**.

There is no screen titled «ابزارهای شخصی». Two candidates exist:

| Candidate | Has its own list component | Icon style | Navigation | Lock | Allowed by "not More"? |
|---|---|---|---|---|---|
| «اطلاعات من» (`PersonalInfoScreen`) | yes (`_tile`, `_sectionHeader`) | yes (tinted squircle + `Icon`) | yes (`_openSection` → `context.push`) | **yes — PIN gate + `VaultGuard`** | yes |
| «ابزارها و پیشرفت» grid in «بیشتر» (`MoreGroup.tools`) | yes (`_GroupArea` grid) | yes (`MoreDuotone` squircle) | yes (`MoreKind.route`) | only a shared session password (`MoreKind.lockedRoute`), no PIN | **no — it lives in More** |

`SectionColors.personalTools` (`lib/core/theme/section_colors.dart:69-71`) is
commented «ابزارهای شخصی — رنگ سِکشن در صفحهٔ «بیشتر»» but is only a **grouping
colour** (same value as `personalProfile`, `0xFF5C6BC0`) and it is unused by any
tile in `kMoreItems`.

**RESOLVED by the user after stage 3:** the tools now live in the
«ابزارها و پیشرفت» grid on the More page as three `MoreItem` entries
(kids-habits, teacher-ledger, shop-ledger) with their own hues and Persian
keywords. `VaultGuard` was removed from their routes — tiles from More open
directly like every other tool (the app's precedent, e878baa); the tools'
sensitive actions keep their internal locks (ParentLock). The vault keeps
only its own data sections. Documented in the move commit `6e3648c`, merged
to release/1.8.0 as `c2fcb6e`.

---

## 1. Personal tools: registry, routes, lock

### 1.1 The section container — «اطلاعات من»
`lib/features/personal_info/presentation/screens/personal_info_screen.dart` (1220 lines)

- Lock state machine: `_locked` (null = loading) + `_lockUnavailable`
  (fail-closed), `_initLockState()` at :48, `_submitPin()` at :66.
  **Five failed attempts → button disabled** (`_maxAttempts = 5`, :105). There
  is no time-based backoff today — the brief's doubling 30 s lockout is new.
- Persian digits are normalised before hashing (`_normalizePin`, :109) via
  `NumberFormat.normalizeDigits`.
- Dashboard sections are built inline in `_buildDashboard()` (:339): a
  `_sectionHeader(icon, title)` (:679) then `_tile(icon, title, subtitle, color,
  onTap)` (:700) per entry. `_tile` = `AppCard(padding 14, borderColor
  color@30%)` + a `color@10%` rounded box behind the icon.
- `_openSection(route)` (:423) = `await context.push(route)` then invalidate
  `personalInfoStatsProvider`.
- `dispose()` (:113) re-locks the session — captured notifier, because
  `ref.read` in `dispose` throws once unmounted (device-proven comment).

### 1.2 The lock service
`lib/features/personal_info/services/pin_lock_service.dart` (206 lines) —
**this is "the personal-tools lock" the brief says to reuse.**

- Verifier = `SHA-256("$salt:$pin")`, random 16-byte salt, stored as JSON
  `{v:1,salt,hash}` in **flutter_secure_storage** (`personal_info.pin_verifier`).
- Constant-time compare: `_constantTimeEquals` (:192).
- Legacy plaintext SharedPreferences verifier is read as a fallback and
  migrated on first successful unlock (:153-180).
- `storage` = `appSecureStorage`; `backup_rules.xml` excludes it and
  `BackupService` filters the `personal_info.` prefix (:146-153 of
  `backup_service.dart`) — so the PIN never travels in a backup.
- **Gap vs brief:** SHA-256, not PBKDF2-HMAC-SHA256 ≥100k iterations, and no
  attempt throttling/backoff, and the hash is computed on the UI isolate.
  Changing the algorithm must keep the existing verifier readable
  (`verifyPin` already tolerates a missing/legacy value), so `ParentLock` gets a
  versioned verifier `{v:2,alg:'pbkdf2-sha256',iter,salt,hash}` in the *same*
  secure-storage key and migrates `v:1` on the next successful unlock.

### 1.3 Session + guards
`lib/features/personal_info/presentation/providers/vault_session.dart` (145 lines)

- `vaultSessionProvider` — bool, unlocked-this-session; locks on
  `paused/hidden/detached` (:28).
- `vaultPinSetProvider` — `FutureProvider<PinLockService.isPinSet()>`.
- `VaultGuard` (:53) wraps every vault sub-route: no PIN → pass; PIN set and
  session locked → `_VaultLocked`; loading/unreadable → spinner (fail-closed).
- Routes are wired in `lib/app/router/app_router.dart:588+`, each as
  `_ambient(const VaultGuard(child: …))`.

### 1.4 Icons
No icon font/registry: tiles take a plain `IconData` (Material) plus a
`TopicHues`/`SectionColors` constant. `MoreDuotone` (`…/more/more_duotone.dart`,
86 lines) derives the «بیشتر» squircle tints from one accent. `IconTile`
(`components/icon_tile.dart`) is the generic one: `IconTile(icon, color,
size=38, iconScale?)`, radius `0.32*size`, fill `accent@14%`, glyph colour from
`dsReadableGlyph`. `DuotoneIconTile(accent, icon, size=28)` is the flat variant.

To add an identity colour: one `static const Color` in
`SectionColors` (`lib/core/theme/section_colors.dart`) **and** the same name in
`TopicHues` (`lib/core/theme/time_theme.dart:127` area) — a parity test pins
every shared name equal between the two tables.

### 1.5 Section page tone
`TimeThemeKit.of(context).palette` (`lib/core/theme/time_theme.dart`):
`pageBg`, `surface`, `surfaceAlt`, `surfaceMuted`, `card`, `elevated`,
`textPrimary/Secondary/Muted`, `outline`, `divider`, `primary/Strong/Soft`,
`secondary(Soft)`, `tertiary(Soft)`, `accent`, `heroTop/Mid/Bottom`, `heroInk`.
Theme presets: `ThemeKind { gold, live, dawn, day, sunset, night }` (:33).
Semantic: `AppTheme.success/warning/danger` + `successBg/warningBg`
(`lib/core/theme/theme.dart:278+`).

---

## 2. Database layer & migration pattern

- **drift 2.34.0**, `AppDatabase` in `lib/core/database/app_database.dart`
  (921 lines), `int get schemaVersion => currentSchemaVersion`, currently
  **45** (:95).
- Tables: 38 Drift `@Table` classes in the `@DriftDatabase(tables: […])` list
  (:52-93) **plus** raw-SQL auxiliary tables with no codegen.
- `MigrationStrategy` (:105): `beforeOpen` sets `PRAGMA foreign_keys = ON`;
  `onCreate` = `createAll()` + idempotent `CREATE … IF NOT EXISTS` for the raw
  tables + indexes + `ANALYZE`; `onUpgrade` = a long `if (from < N)` ladder.
  Raw-SQL blocks are deliberately duplicated in both `onCreate` and `onUpgrade`
  because "onCreate never runs onUpgrade" (comments at :133, :139).
- **Failure policy (critical):** the `onUpgrade` `catch` never drops tables; it
  writes a forensic copy + `app.sqlite.migration_failed` marker so the next
  launch restores the last good snapshot (:600-640). A duplicate-column error
  therefore costs a restore loop, which is why every `ALTER` is
  `PRAGMA table_info`-guarded (v41 :487-500, v44).
- Destructive-in-place pattern: v40 rebuilt `goal_progress_table` with
  `PRAGMA defer_foreign_keys = ON` to add an FK.

### The pattern to copy — `CareTables` (v45)
`lib/features/personal/data/care_tables.dart`: plain `CREATE TABLE IF NOT
EXISTS` + `CREATE INDEX IF NOT EXISTS` strings in one `createStatements` list,
a `allTables` list "so the backup/restore code and the migration test both read
this list", and **no `build_runner`** (explicit project rule: "the project
forbids `build_runner` runs without an explicit request").

⇒ Both new features follow it: `assets/…` no, `lib/features/personal2/data/
personal2_tables.dart`, v46 = one `for (final stmt in Personal2Tables
.createStatements)` in `onCreate` **and** `if (from < 46)` in `onUpgrade`.

- Dates: **epoch milliseconds (UTC)** ints; `null` = never, never `0`.
- DAO: `lib/features/personal/data/care_dao.dart` — `CareDao(AppDatabase db)`,
  `db.customSelect(...).get()`, every method swallow-and-logs via `AppLogger`.
  Provided by `final careDaoProvider = Provider<CareDao>((ref) =>
  CareDao(ref.read(appDatabaseProvider)))`.
- `appDatabaseProvider` = `lib/core/database/database_provider.dart`
  (`Provider<AppDatabase>`, `onDispose(db.close)`).
- Migration tests: `test/core/database/app_database_migration_test.dart`
  (`PRAGMA user_version = N` → open → assert), plus per-version
  `app_database_schema_v39/40/41/42/44_test.dart` and
  `simulate_upgrade_test.dart`. A v46 test follows the same shape.

---

## 3. State management

**flutter_riverpod 3.3.2** everywhere (`Notifier`/`NotifierProvider`,
`Provider`, `FutureProvider`, `ConsumerStatefulWidget`).
Representative: `care_dao.dart` (plain `Provider`), `vault_session.dart`
(`NotifierProvider` with `WidgetsBindingObserver`), `dangi_provider.dart`
(load-state notifier with `loaded`/`loadError`). No bloc, no freezed.

House style for a load-state screen (`dangi_screen.dart:20`):
`!state.loaded ? (loadError != null ? AppErrorDisplay(onRetry:) :
CircularProgressIndicator()) : state.isEmpty ? _EmptyState() : …`, all inside
`Directionality(textDirection: rtl, child: Scaffold(backgroundColor:
Colors.transparent, …))` with a transparent `AppBar`.

---

## 4. Notifications (for `SoftNotifier`)

`lib/shared/services/notification_service.dart` (2086 lines).

- Flutter Local Notifications 22.0.1 + `timezone`.
- ID constants live in `lib/shared/services/notification_ids.dart`;
  `NotificationIds.stableSlot(String key, int space)` = FNV-1a `% space`
  (:193) — the collision-safe way to derive an id from a string.
- **Reserved ranges in use:** 100-131 prayers/tomorrow, 199 test adhan,
  210-222 day-after, 300-304 manual post-prayer, 400-408 daily/quran/friday/
  fasting, 410-431 events+snooze, 432 missed digest, 500-524 pre-adhan,
  600-603 period, 1000-1999 custom reminders, 7000/7400/7900 daily-content
  day bases, 8300 ayam-al-bidh, **13000-13999 `care_due_reminders`**
  (`CareReminderScheduler.idBase = 13000`, `idSpace = 1000`).
- **New ranges for this stage:** kids `14000 + stableSlot(…, 1000)`,
  teacher `15000 + stableSlot(…, 1000)`.
- Channel precedent (personal-tools family, `care_reminder_scheduler.dart:101`):
  channel id `care_due_reminders`, name «یادآوری ابزارهای شخصی». New channel:
  `personal2_tools_v1` / «یادآوری ابزارهای شخصی» (versioned name as required),
  created lazily in an `_ensureChannel()` guarded by try/catch.
- `NotificationService().scheduleExactReminder(id:, title:, body:,
  scheduledTime: tz.TZDateTime, details: AndroidNotificationDetails,
  payload:)`.
- **No quiet-hours support exists** — grep finds none. `SoftNotifier` adds it
  (and the daily cap + one-summary grouping) itself.
- Deep links: payload strings are parsed by feature-local classes (e.g.
  `CareDeepLink`), routed from the shell. Kids/teacher payloads:
  `p2k_<kind>_<id>` / `p2t_<kind>_<id>`.

## 5. Backup & restore

`lib/features/settings/services/backup_service.dart` (1556 lines).

- Table list is read from **`sqlite_master`** at export/import time, not a
  hard-coded list (:1265, :1482) — so **a new table is included automatically**;
  nothing to register. `PRAGMA defer_foreign_keys = ON` guards FK ordering.
- Exclusions are prefix-based: `personal_info.` (vault/PIN) and
  `_excludedPreferenceKeys` (:120-153). PIN state is therefore already excluded;
  `ParentLock` stores its verifier in the *same* secure-storage key so it keeps
  that guarantee for free.
- Portable archives are encrypted/consented at the account layer.
- `wipeAllLocalData()` also enumerates `sqlite_master`, so «delete everything»
  for one child/student must be a targeted `DELETE`, not a wipe.
- Round-trip test: see `test/features/account/**` (`backup*`); the new test adds
  the personal2 tables to that fixture.

## 6. Dates, money, share

- `shamsi_date 1.0.1`. Jalali helpers: `lib/core/utils/jalali_format.dart` —
  `jalaliLabelFa` (`1404/7/3`), `jalaliYmdPadded`, `jalaliYmdShort`,
  `jalaliDayMonth(iso)`. **Latin digits are the product standard.**
- `NumberFormat.normalizeDigits` (`lib/shared/utils/number_format.dart`)
  Persian/Arabic-Indic → ASCII; `groupDigits`, `formatPlain`.
- Share: `lib/shared/services/share_service.dart` — `captureCard` (RepaintBoundary
  → PNG, clamp 2..6), `sharePng(bytes, fileName, text:)`, `shareText`, and the
  brand constants (`channelName`, `channelUrl`, `signatureName`, `logoAsset`).
- PDF: **`pdf 3.13.0` already a dependency** + a shared util
  `lib/features/tools/shared/pdf_report_util.dart` — `pdfVazirFont(bold:)`
  (Vazirmatn TTF, cached), `pdfLogoBytes()`, `buildToolReportPdf(title,
  subtitle, accent, body)` (A4 `MultiPage`, RTL, branded header/footer),
  `shareToolReportPdf(bytes, fileName)`, `pdfRow`, `pdfSection`. **A5 does not
  exist yet** — `ReportRenderer` passes a `PdfPageFormat` through.
- `tel:`/`sms:` → `url_launcher` 6.2.1.

## 7. Prayer schedule (Part A tie-in, read-only)

- `lib/features/prayer/domain/prayer_clock.dart`: `enum PrayerId { fajr,
  sunrise, dhuhr, asr, maghrib, isha }`, `DayTimes.of(id)`,
  `PrayerSchedule{yesterday,today,tomorrow}` (`fromToday(pi.PrayerTimes)`),
  `PrayerSnapshot`, `computeSnapshot(schedule, now, iqamahOffsets)`,
  `PrayerClock extends ValueNotifier<PrayerSnapshot>` (ticker-driven,
  quantised — never per second).
- Providers: `lib/app/state/clock_providers.dart` — `clockTickerProvider`
  (`ClockTicker`, app-lifetime, `minute` notifier), `prayerClockProvider`
  (null until times load), `timePhaseProvider`, and
  `prayerTimesProvider` (`…/prayer/presentation/providers/
  prayer_time_provider.dart`).
- **There is no "end of time" field.** The app's own boundaries are derivable
  from `DayTimes` and already used by `phaseForSchedule` (:101). The brief's
  fallback definitions (Fajr→sunrise, Dhuhr→Asr, Asr→Maghrib, Maghrib→Isha,
  Isha→next Fajr/midnight) are therefore the ones to implement — in a pure,
  unit-tested function, no fiqh text in the UI.
- Prayer boundaries refresh via `clockTicker.minute` — reuse it; add **no**
  per-second timer.

## 8. Quran reader & mushaf metadata (Part B)

- Reader = **shell tab**, not a `GoRoute` (`RouteNames` comment :8-13, and
  `QuranTab` in `lib/features/quran/presentation/screens/quran_tab.dart`).
- Navigation channel: `quranNavRequestProvider` =
  `Provider<ValueNotifier<QuranNavRequest?>>`
  (`lib/app/state/shell_nav.dart:21`), `QuranNavRequest(page, {surah, verse})`.
  `QuranTab._consumeNavRequest` (:49) delivers it to
  `QuranMushafViewState.goToPage(page, surah:, verse:)` with bounded retries.
  ⇒ **`ReaderLaunchOptions(page, previewOnly:true)` does not exist.** The
  preview-only requirement (must not move the user's own last read) needs a new
  nav flag plus suppression in the reader.
- What the reader mutates on open — the exact things `previewOnly` must not
  touch:
  - `SharedPreferences['quran_last_page']`, restored at
    `quran_mushaf_view.dart:686`, written debounced 750 ms from
    `_onPageChanged` → `_flushLastPageSave()` (:883), also flushed on
    `inactive/paused/hidden/detached` and `dispose`.
  - Bookmarks (`quran_bookmark_table`, `QuranBookmarkDao`) and ayah highlights
    (`ayah_highlight_table`) are only written by explicit user actions.
- Mushaf metadata (`lib/features/quran/data/`): `page_data.dart` (604 entries,
  page → `{surah,start,end}`), `juzs.dart` (juz → surah/verse ranges),
  `quran_helpers.dart` — `getPageData(page)`, `getPageNumber(surah, ayah)`,
  `getJuzNumber(surah, ayah)`, `getCurrentJuzNumberForPage(page)`,
  `getJuzStartPage(juz)`, `juzVerseRanges(juz)`, `getSurahName(int)`.
  **No line metadata** (`15 lines/pages`) and no line-range API exist — the
  lesson sheet validates lines 1..15 as plain integers.
- Existing juz-coverage precedent: `lib/features/hifz/**` (`HifzProgress`),
  useful for the 30-cell juz strip.
- Tajweed labels: no existing registry — new `assets/data/tajweed_tags.json`.

## 9. Design system & tests

- Components: `lib/core/design_system/components/` (barrel `components.dart`):
  `AppCard(child, padding, onTap, radius=22, color, borderColor)` — radius 22,
  0.5 dp border, **exactly** the brief's card; `IconTile`, `DuotoneIconTile`,
  `SectionHeader`, `chips.dart`, `segmented_tabs.dart`, `stepper.dart`,
  `setting_row.dart` (switches), `ShareCardShell`/`ShareCardHeader`,
  `ShareCardColors`, `PageHeader`, `FailureView` (`AppErrorDisplay`),
  `SectionPage`, `HeroShell`/`HeroCardShell`, `Ring` (progress ring).
  Empty state: `lib/shared/widgets/app_empty_state.dart` (`AppEmptyState`).
  Tokens: `DsSpacing.page=10, gap=8, rowGap=6`, `mix()`, `dsOnAccent`,
  `dsContentColor`, `dsReadableGlyph`, `dsShadow`.
- `AppCard` and the rest are flat (no gradient/blur/Opacity) — matches the
  brief's performance rules. `_buildHeader` in personal_info *does* use a
  `LinearGradient`; new code must not copy that.
- Fonts: `AppTheme.fontFamily` + `AppTheme.scaledFontSize(context, n)`;
  Vazirmatn/TKT-Tika/Harir/Amiri declared in `pubspec.yaml`.
- Goldens: `flutter test --update-goldens`; 319 PNGs under
  `test/**/goldens/`. Convention (`kit_phase_golden_test.dart`):
  `ThemeKind.dawn/day/sunset/night`, `MaterialApp(theme: AppTheme.light,
  home: Directionality(rtl, …))`, fully static values.
- Existing presets used for "default + one other": day + night.
- Perf docs: `docs/COLD_START_TTI.md`, `docs/BASELINE.md` (cold-start TTI,
  `flutter build apk --release --no-pub`, APK byte count recorded in
  `PROGRESS.md`).
- `PROGRESS.md` is the running log; the 1.8.0 release APK was
  47,961,333 bytes — that is the APK baseline for the ≤1.5 MB budget.

---

## 10. Plan (stage 1)

1. **`docs/PERSONAL2_INVENTORY.md`** — this file.
2. **Shared pieces** (`lib/features/personal2/shared/`), each neutral so
   stage 2/3 can reuse it:
   - `parent_lock.dart` — `ParentLock.requirePin(context, reason)`; PBKDF2 v2
     verifier in secure storage, off-isolate hash, constant-time compare,
     5 → 30 s doubling lockout persisted, never logs the PIN, excluded from
     backup; migrates the existing v1 SHA-256 verifier.
   - `report_renderer.dart` — RepaintBoundary→PNG (ratio ≤2) and
     `pw.Document` PDF (A4/A5) reusing `share_card_shell` + Vazirmatn + the
     logo strip, then `ShareService`/`shareToolReportPdf`; cache file deleted.
   - `mini_charts.dart` — ring / horizontal bars / 7-bar columns / day strip,
     `CustomPainter`, RTL aware, cached `Picture`, `Semantics`.
   - `template_store.dart` — validates `assets/data/*.json`, user overrides in
     `personal2_template_override`.
   - `soft_notifier.dart` — channel `personal2_tools_v1`, ranges 14000/15000,
     quiet hours, daily cap, single summary notification.
3. **Data layer**: `personal2_tables.dart` (raw SQL, v46) + DAOs + providers.
4. **Part A logic** (pure Dart, unit-tested) then **Part A screens** (7).
5. **Part B logic** then **Part B screens** (6), incl. reader preview-only.
6. **Registration** in «اطلاعات من» + routes + `VaultGuard`.
7. **Tests**: unit, widget (320/360/412 dp; 1.0/1.3 scale), goldens (day+night),
   v46 migration, backup round-trip. `flutter analyze` clean.
8. **Measure** APK delta and cold start; STOP + report if over budget.
9. **`docs/PERSONAL2_STAGE1_REPORT.md`** with screenshots, template/rule lists,
   ID ranges, measurements, open questions.
