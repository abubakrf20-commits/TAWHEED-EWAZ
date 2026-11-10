# PERSONAL2 — Stage 1 report

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


Branch `personal2/stage1-kids-teacher` · base `release/1.8.0` @ `5b1d5a3`
Spec: the brief «PERSONAL TOOLS SET 2 — STAGE 1 of 3»; map:
`docs/PERSONAL2_INVENTORY.md`.

---

## 1. What shipped

Both tools work end-to-end on the app's own infrastructure. 26 new Dart files
under `lib/features/personal2/` (~12.5k lines) plus the v46 migration, two
identity hues, 13 routes, and 118 new tests (162 with the golden variants).

### Shared kit (`lib/features/personal2/shared/`)

| Piece | File | Notes |
|---|---|---|
| ParentLock | `parent_lock.dart` | `requirePin(context, reason)`; PBKDF2-HMAC-SHA256 **120k iterations computed off the UI isolate** (`Isolate.run`), per-verifier salt, constant-time compare, 5 failures → 30 s lockout **doubling each burst, persisted** so a restart does not reset it. Reuses the vault's PIN: no v2 verifier yet → verifies against `PinLockService` and adopts it. Own secure-storage key (`personal_info.parent_pin_verifier`) because writing a v2 record into the vault's key would make the vault compare a PBKDF2 digest against SHA-256 and reject every correct PIN. No backdoor: clearing the parent lock clears the vault PIN too. |
| ReportRenderer | `report_renderer.dart` | RepaintBoundary → PNG at `pixelRatio ≤ 2`; A4 **and A5** PDF (single- or multi-page) in Vazirmatn with the brand footer; temp files deleted after the share sheet closes. |
| MiniCharts | `mini_charts.dart` | Ring, horizontal bars, 7-bar columns, day strip — `CustomPainter`, RTL, cached `Picture`s keyed on the data, no `saveLayer`/blur/`Opacity`. |
| TemplateStore | `template_store.dart` | Validates `assets/data/*.json`, applies user overrides from `p2_template_override` in place (no reordering), `resetToDefault` = one DELETE. |
| SoftNotifier | `soft_notifier.dart` | Channel `personal2_tools_v1` «یادآوری ابزارهای شخصی»; kids ids **14000–14998**, teacher **15000–15998**, summaries 14999/15999; quiet hours (including the window that crosses midnight — an in-window nudge moves to the window's end, not into the void), daily cap 3, overflow folds into one summary notification. All reminders are opt-in and default OFF; the child is never notified. |
| Mushaf preview | `mushaf_preview.dart` | The brief's `ReaderLaunchOptions(page, previewOnly: true)`, expressed on the existing `quranNavRequestProvider` channel because the mushaf is a shell **tab**, not a route. |

### Part A — «دفتر عادت کودک» (accent `E58A2B`, stars `F2B53A`)

Data (`kids/data/kids_dao.dart`, raw SQL in `personal2_tables.dart`): child,
habit (daily/weekday-mask/one-time), prayer config (bitmask + late factor),
immutable log (dedupe-keyed), immutable star ledger (UNIQUE on
`(reason, ref_id)`), rewards, reward requests (reservations), settings
(dayStart, sibling comparison OFF by default, PIN, reminders, quiet hours).

Pure logic (`kids/domain/kid_logic.dart`): day keys under dayStart (01:30
belongs to yesterday when the day starts at 03:00), schedule evaluation, the
prayer-chip state machine (LOCKED before adhan → NOW in-window →
LATE_AVAILABLE after, if allowed → MISSED at day end; a logged mark always
wins over the clock), late-star rounding **up** so effort is never zero,
balance/reservation maths, idempotent reward approval, streaks that skip
unscheduled days instead of breaking, weekly aggregates, and the soft-tip
selector (lowest completion with ≥3 scheduled days, praise when all high).

Screens: parent home (flat hero, per-child rings, approval badge),
child setup (template picker with star steppers, prayer config, per-child
«حذف همهٔ داده‌ها»), **child mode** (prayer chips from the app's real schedule,
2-column grid, 10 s undo, ≤250 ms celebration honouring reduce-motion),
habits + PIN-gated star adjustments (note required), rewards (PIN-gated
approval, reservation released on cancel), approvals queue (PIN once per
5-minute session, bulk approve), weekly report (7-bar chart, stat chips,
per-habit bars, rule-based tip, sibling comparison only if enabled, image +
PDF share).

### Part B — «دفتر مربی قرآن» (accent `1F7A63`)

Data: class groups, students (phones typed by hand — no contacts permission),
sessions (auto-created when the class meets today; numbering never rewrites
history), attendance (one row per student/session, «همه حاضر»), lesson records
(page/line ranges validated 1–604 / 1–15, grades from the editable scale,
tajweed tags as labels).

Pure logic (`teacher/domain/teacher_logic.dart`): distinct-page unions,
highest page, juz coverage **through the app's own
`getCurrentJuzNumberForPage`** mapper, new-pages-this-month excluding pages
already covered before the period, attendance % with the excused-exclusion
setting, absence streak → «با ولی تماس بگیرید», grade averages that skip
unknown keys, tag counts (stable tie-break), class averages **without
ranking**, next-assignment = the page after the **last** (chronological)
range, and rule-based parent-report paragraphs.

Screens: class home (class chips, session hero, four-button attendance rows,
long-press for profile), lesson sheet (segmented type, validated range,
grade chips, tajweed tags, «صفحهٔ بعد»/«تکرار», **«باز کردن در مصحف» in
preview mode**, «ثبت و شاگرد بعدی» advancing to the next unrecorded student),
student profile (attendance ring, 604-page progress, 30-cell juz strip,
top-mistake bars, recent sessions, `tel:` to the parent), parent report
(toggles → generated text in an **editable** box → cream printed preview →
image/PDF/text), class management (CRUD, archive-not-delete, paste-in import
with preview, CSV roster).

### Registration

Both tools are registered as a new «ابزارهای شخصی» group inside **«اطلاعات
من»** — the section that actually has the list component, the icon style, the
navigation and a real PIN lock — using its existing `_tile`/`_sectionHeader`
and `_openSection`. Nothing was added to Home or «بیشتر», and there is no hub.
All 13 routes are wrapped in `VaultGuard`; the kids tool layers `ParentLock`
on the actions that change a child's stars. Two identity hues
(`kidsHabits`, `teacherLedger`) were added to **both** hue tables and are
pinned by the existing TopicHues↔SectionColors parity test.

> See the inventory's §0 for why this reading was chosen and what the
> alternative («بیشتر» grid) would change — it is two `MoreItem` entries and
> nothing else.

---

## 2. Content & privacy rules honoured

- **No Quran text, tajweed ruling, hadith or fiqh is authored or altered.**
  Quran references are page/line numbers only. Tajweed tags and grade scales
  are editable labels from assets flagged `reviewed: false`. The prayer chips
  read the app's schedule and report states; the UI says the child's mark is a
  self-report and the tool «هیچ حکم شرعی‌ای صادر نمی‌کند».
- **Children/students stay on the device**: local DB only, no analytics, no
  network calls in either tool, no photos (initial avatar + colour), no
  contacts permission (`tel:` only), per-child/per-student «delete everything»,
  rows included in the encrypted app backup, never in cloud sync, PIN and
  lockout state excluded from portable backups.

## 3. Template/rule lists for your review

All in `assets/data/`, all `reviewed: false`, all editable in-app with
reset-to-default:

- **Habit templates** (`habit_templates.json`, 9): مسواک زدن، درس خواندن، کمک
  در خانه، مرتب کردن اتاق، قرآن ۵ دقیقه، سلام و مهربانی، صدقهٔ کوچک، آماده
  کردن کیف مدرسه، به‌موقع خوابیدن — stars 1–2 each.
- **Reward templates** (6): بستنی (10★)، بازی ۳۰ دقیقه (15★)، پارک آخر هفته
  (25★)، فیلم خانواده (30★)، یک شب دیرتر بیدار ماندن (35★)، کتاب جدید (40★).
- **Grade scale** (`grade_scale.json`): عالی=4، خوب=3، متوسط=2، نیاز به
  تمرین=1 (numeric used only for averages).
- **Tajweed tags** (`tajweed_tags.json`, 10): مد، غنه، اخفا، ادغام، قلقله،
  مخارج حروف، صفات حروف، وقف و ابتدا، روانی، حرکات.
- **Prayer windows** used (the brief's fallback definitions — the app has no
  end-of-time field): Fajr→sunrise, Dhuhr→Asr, Asr→Maghrib, Maghrib→Isha,
  Isha→next Fajr (or local midnight when tomorrow's fajr is unavailable).
- **Notification ID ranges**: kids 14000–14999, teacher 15000–15999
  (documented in `SoftNotifier` and pinned by tests); clear of every existing
  range (highest previous base: 13000 care).

## 4. Verification

- `flutter analyze lib test` — **0 errors**; none of the 51 remaining infos
  touch `lib/features/personal2` (all pre-existing elsewhere).
- **personal2 suite: 162 green** — 46 kid logic, 47 teacher logic, 7 v46
  migration (incl. a real 45→46 upgrade over a fixture with live rows), 7
  mushaf preview, 15 SoftNotifier, 38 layout (320/360/412 dp × scale 1.0/1.3,
  RTL), 3 backup round-trip, 6 goldens (day+night, Vazirmatn loaded and
  visually inspected; icons tofu'd exactly like the repo's existing kit
  goldens).
- **Full suite: 5258+ green, 3 failed** — two were project-wide guards my new
  code violated (sheet-radius contract, type-scale guard); both fixed and now
  green. The third (`account_screen_test` encrypted-backup flow) fails on a
  clean checkout of the base branch too — a pre-existing secure-storage
  plugin-channel gap in that test, unrelated to this work.
- Guards now green that were red: `sheet_contract_test` (my sheets inherited
  the theme radius instead of painting 22), `type_scale_guard_test`
  (`20→21`, `22→23`).

### Budgets (the hard rule)

| Metric | Budget | Measured | Verdict |
|---|---|---|---|
| arm64 APK growth | ≤ +1.5 MB | **+538,490 bytes (+0.51 MB)** — 45.74 MB (47,961,333 B, the 1.8.0 baseline) → 46.25 MB (48,499,823 B), `flutter build apk --release --no-pub`, exit 0 | **PASS** |
| Cold start | ≤ baseline +50 ms | not measurable here — no device attached (§6.1) | pending device run |
| First-frame init | nothing before first frame | wake lock + every provider are post-frame/lazy | by construction |
| Per-second work | none | prayer chips refresh on the ticker's minute stream | by construction |

## 5. Bugs found and fixed along the way

1. **`assets/data/` was never declared in pubspec** — the existing
   `care_templates.json` load had been failing into `CareTemplates.empty`
   silently since that feature shipped. Declared the directory.
2. **SoftNotifier id collision** — a `stableSlot` of 999 landed exactly on the
   summary id, so a reminder could silently replace the day's summary. Slot
   space is now one short of each range; a test pins it. (Caught by the test
   on first run: actual 14999.)
3. **Child-mode grid overflow** — 31 px at 320 dp, 16 px more at text scale
   1.3. Aspect 1.32 → 0.9, keeping the brief's 52 dp tile. Caught by the
   layout tests the brief asked for.
4. **Lockout state would have travelled in backups** — `personal2.lock_*` sat
   outside the backup service's sensitive prefix. Renamed under `personal_info.`
   and pinned by a test.
5. **`dart fix` silently broke `'${h.id}|$key'`** into `'h' + '.id'` while
   cleaning lints — caught by the kid-logic unit tests, reverted, and flagged
   here because it is exactly the kind of edit a cleanup pass can sneak in.
6. **Theme-sheet contract** — my sheets painted their own radius 22; the app's
   contract (and its guard test) owns the radius centrally. Fixed by
   inheriting the theme surface.

## 6. Open questions / not done here

1. **Device measurements.** No Android device/emulator is attached to this
   machine, so the cold-start delta (baseline +50 ms) and the 100-student /
   10,000-log scroll check could not be measured on hardware; the release
   build itself succeeds and the APK delta is +0.51 MB of the 1.5 MB budget.
   The `--profile` numbers need a device run.
2. **Registration location** needs your confirmation (inventory §0): the
   brief's «ابزارهای شخصی» section matches «اطلاعات من» on all four required
   properties, but if you meant the «بیشتر» grid, the change is two
   `MoreItem` entries — everything else stands.
3. **SoftNotifier scheduling is built but not yet wired to a periodic
   re-arm pass** (the evening summary / approvals nudge schedule their one
   next fire when settings change; a daily re-arm hook like
   `CareReminderScheduler`'s is the natural stage-2 addition). Nothing fires
   by default, so this is invisible until reminders are switched on.
4. **PDF is single-accent A4/A5** via the shared tool-report util; a
   two-column Persian table layout for the class overview card would be a
   stage-2 nicety.
5. **Pre-existing failures left untouched**: `account_screen_test`'s
   encrypted-backup flow (secure-storage channel), and the 51 analyzer infos
   outside this feature.

## 7. Commits (small, per layer)

- `4f7b0c3` foundation: inventory, v46 tables, shared kit, kid logic (46 tests)
- `a852253` DAOs, teacher logic, preview-only mushaf launch (+54 tests)
- `829e0c0` the seven kids screens
- `b3f791d` teacher screens + registration in the personal tools
- (this commit) guard fixes, re-applied id/throttle fixes, goldens with real
  Persian shaping, backup round-trip tests, docs
