# PERSONAL TOOLS — status and phased plan

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


Updated: 2026-11-05, branch `move/stage3-tools` (base `release/1.8.0`).

User decision behind this document: the personal tools are **not** a section of
«اطلاعات من». They live in «ابزارها و پیشرفت» (the More page), with that
section's own tiles, its own lock (`VaultGuard`), and **no hub page**. Every
tool has to be complete — not "reachable and half-built" — and designed with
the app's flat kit.

Every row below was verified against the working tree on the date above. The
older reports (`PERSONAL_AUDIT/00_TRACEABILITY.md`, `01_GAPS.md`,
`CHECKPOINT.md`) described the tree *before* stages 1–3 landed and are now
historical; this file replaces them as the queue.

**Section moves after this scan (2026-11-09).** کفاره و فدیه، صله رحم، دفتر مربی قرآن و
دفتر عادت کودک now live in «عبادات و مناسک», and قضایار was retired from the registry.
The live split is **53 = 18/12/3/15/5** (`docs/SECTIONS_1_9_0.md`); the tile column
below records where each tool sat on the scan date, not where it sits now.

## 1. What exists

| Tool | Tile in «ابزارها و پیشرفت» | Screens | Engine | Tests | Goldens | Reminders | Backup |
|---|---|---|---|---|---|---|---|
| خودرو | **added `0006bb2`** | `car_screen`, `care_history_screen`, 3 sheet files | `care_engine` (status, prediction, seasonal) | 323 personal tests | `care_golden_test` | `CareReminderScheduler` 13000+ | yes (sqlite_master) |
| خانه | **added `0006bb2`** | `home_care_screen` (4 tabs) | same engine | same | same | same | yes |
| دفتر مالی (چک/قسط + دَین) | `finance` | `finance_screen` + 4 sheet/widget files | `finance_engine` (plans, totals, net balances) | `finance_*` | `finance/goldens` | `FinanceReminderScheduler` **17000+** | yes |
| صله رحم | `relatives` | `relatives_screen` + sheets | `relative_models` (due/soon/overdue, birthdays) | `relative_*` | in `family_faith/goldens` | `FamilyReminderScheduler` **17400+** | yes |
| کفاره و فدیه | `kaffara` | `kaffara_screen` | `kaffara_models` (data-driven, `reviewed` gate) | `kaffara_engine_test` | same | — | yes |
| قلک | `savings` | `savings_screen` + sheets | `savings_models` (ETA, milestones) | `savings_*` | same | `SavingsReminderScheduler` **17900+** | yes |
| قضایار | `qaza` | `qaza_screen` + sheets | `qaza_models` | `qaza_*` | same | `QazaReminderScheduler` **17800+** | yes |
| حساب مغازه | `shop-ledger` | 14 screens | `shop_domain` / `shop3_domain` | 105 shop tests | `shop/goldens` | `ShopReminders` 16000+ | yes |
| دفتر عادت کودک | `kids-habits` | 7 screens | `kid_logic` | 46 tests | in `personal2_golden_test` | `SoftNotifier` 14000+ | yes |
| دفتر مربی قرآن | `teacher-ledger` | 5 screens | `teacher_logic` | 47 tests | same | `SoftNotifier` 15000+ | yes |
| تبدیل واحد (inside ماشین حساب) | already in `calculator` | `unit_converter_view` | `unit_conversion` + `units.json` | 12 + 8 tests | — | — | yes (user bases) |

### Fixed in phase 0 (`0006bb2`)

1. **خودرو/خانه had no door.** Routes and screens existed; nothing pushed
   either path, so the entire care engine was unreachable (audit P0-1). Both
   are tiles now, still behind the router's `VaultGuard`.
2. **Two palettes for one tool.** The More tile for «صله رحم» was brown while
   its screen is rose; «کفاره» was dark red outside and amber inside.
   `lib/core/theme/tool_identity.dart` is now the single source of the eight
   identity hues; `TopicHues` and the three feature style files read it.
3. **Notification ids overlapped.** دفتر مالی used the kids block (14000+),
   صله رحم the teacher block (15000+), قضایار/قلک the shop block (16000+), so
   one tool's reminder replaced another's. Blocks are now disjoint
   (13000 care, 14000 kids, 15000 teacher, 16000 shop, 17000 finance,
   17400 relatives, 17800 qaza, 17900 savings) and
   `test/features/personal/notification_range_map_test.dart` pins the table.
4. Stale assertion repaired: the care-templates test demanded a per-file
   pubspec line while the fix declared the whole `assets/data/` directory.

## 2. Gaps that remain (the actual queue)

| id | Severity | Gap | Evidence |
|---|---|---|---|
| ~~**G-2**~~ | ~~P1~~ | **DONE `963c0a9`** — the shop report now has a Jalali window (today / 7 / 30 / this Jalali month / arbitrary range), the five figures with previous-window comparison, drill-down lists behind net sales, each payment method and each top product, a slow-movers sheet, and the full CSV ZIP. | 26 new tests: `shop_report_range_test`, `shop_report_dao_test`, `shop_report_tab_test` |
| ~~**G-3**~~ | ~~P1~~ | **DONE `445fdbd`** — the banner is driven by the pack's own Jalali windows; it names the missing count, says «در پنجره / N روز تا پنجره / پنجرهٔ امسال گذشت», and disappears when the pack is complete and closed. | 12 `care_season_plan_test` cases + 2 banner tests |
| ~~**G-4**~~ | ~~P1~~ | **DONE `f582e6a`** — the report switches between هفت روز and سی روز over the same roll-up; chart ticks become day numbers and every share/PDF title follows the period. | `kid_report_window_test` |
| ~~**G-5**~~ | ~~P1~~ | **DONE `f582e6a` + `43f2b53`** — kids evening summary (7 nights, per-night keys, quiet hours respected) and teacher class-start / unrecorded-lesson / Friday review all schedule through `SoftNotifier`, each with a settings sheet. Writing the tests caught a real bug: day keys were built from Gregorian numbers, so every key read 2648-…; both helpers now use `Jalali.fromDateTime`. | `kid_evening_summary_test`, `teacher_reminders_test` |
| ~~**G-6**~~ | ~~P2~~ | **DONE `01ba249`** — «تنظیم پیش‌فرض‌ها» edits both asset kinds' intervals as override rows (`care_template` kind), with «بازگردانی» back to the shipped suggestion. | `care_template_overrides_test` |
| **G-7** | P2 (content) | **Kaffara ships its empty state** because both rules are `reviewed:false`. Correct behaviour, not a bug; the full inventory + review checklist is now `docs/KAFFARA_CONTENT.md`. Still needs your decision. | that doc |
| **G-8** | P2 (device) | No `--profile` pass on a low-end phone: no Android device is attached to this machine, so every claim so far is test/golden/binary proof. | — |
| **G-9** | P3 | Design sweep per tool: spacing/type-scale/empty-state consistency across the eight screens and their sheets (flat, radius 22, duotone tiles, no gradients). | visual review in each phase |

Non-gaps worth recording so nobody "fixes" them again: `RECORD_AUDIO` stays for
the notes recorder; `flutter_svg` is a declared-but-unused dependency awaiting
approval; the removed prompter/tilawa family must not return.

## 3. Phases

Each phase ends with `flutter analyze lib test`, the phase's own tests, the
quality gate, and a commit that names the gap id. Release APKs are built in
phase 6 only.

**Phase 1 — shop report (G-2). ✅ DONE `963c0a9`.** Custom Jalali range picker (today / 7 / 30 /
this Jalali month / arbitrary range), figures with previous-period comparison,
drill-down lists (sales, returns, each payment method, each top product),
slow-movers screen with tied-up money, full CSV ZIP. *Done when* a range can be
picked in Jalali, every figure opens its rows, slow movers match a seeded
fixture, the ZIP opens with every table + README, and DAO/domain/widget tests
pass.

**Phase 2 — home seasonal packs (G-3). ✅ DONE `445fdbd`.** The banner is driven
by the pack's own Jalali windows instead of a month table: it names the count of
missing tasks, says «در پنجره / N روز تا پنجره / پنجرهٔ امسال گذشت», offers
«افزودن», and disappears once the pack is complete and its window closed
(`care_engine/care_season_plan.dart`). *Done when* the pack adds only the tasks
that do not exist yet and the status matches the Jalali window — 12 unit cases +
2 banner tests cover exactly those borders.

**Phase 3 — the switches that lie (G-4, G-5). ✅ DONE `f582e6a` + `43f2b53`.**
The kids report switches between هفت روز and سی روز over the same roll-up
(chart ticks become day numbers, shares and the PDF title follow the window);
the kids evening summary schedules 7 nights with per-night keys and respects
quiet hours; the teacher sheet schedules class start, unrecorded lesson and the
Friday review — all through `SoftNotifier` (kids 14000+, teacher 15000+).
*Done when* each toggle produces and cancels a real pending notification and
the monthly report shares like the weekly one — `kid_report_window_test`,
`kid_evening_summary_test`, `teacher_reminders_test` prove it. Writing them
caught a real bug: day keys were built from Gregorian numbers (2026 → two keys
per Gregorian year); both helpers now derive from `Jalali.fromDateTime`.

**Phase 4 — care templates editor (G-6) + car/home design pass (G-9). ✅ DONE
`01ba249`.** «تنظیم پیش‌فرض‌ها» in both car and home edits the two numbers a
suggestion is made of (روز / کیلومتر), stores them as override rows of kind
`care_template` (the existing `p2_template_override` table, so no schema bump and
no rewrite of the asset), and «بازگردانی» deletes the row so the shipped value
returns. `CareTemplate.copyWith` keeps the identity keys intact, and
`careTemplatesProvider` merges the overrides before the list is built. 8 tests +
a test that the sheet really opens; 4 goldens re-recorded.

**Phase 5 — per-tool completion review (G-9, G-7). ✅ reviewed 2026-11-05.**
Verified against the screens, not against the old audit:

- **دفتر مالی** — two tabs (تعهدها / دَین), per-item detail page, edit, delete with
  undo, paid history, currency-aware amounts, reminder scheduler 17000+.
- **صله رحم** — add/edit sheet (name, relation, phone, interval, birthday, note),
  call/message actions, gift-idea sheet with saved ideas, gentle reminder settings,
  delete with undo.
- **قضایار** — editable counts, settings sheet (witr + after-prayer nudge), reset,
  no fabricated numbers.
- **کفاره** — compute → copy → «افزودن به دفتر مالی» → «ثبت پرداخت», and nothing
  at all until a rule is `reviewed` (see `docs/KAFFARA_CONTENT.md`).
- **قلک** — goals sheet, deposit sheet, ETA + milestones + monthly-needed on the
  detail screen, reminder settings, delete.
- **تبدیل واحد** — lives in ماشین حساب (`calculator_tool_panels.dart`) over
  `unit_conversion.dart` + `units.json`, with user-editable bases.

No functional gap was found in those six; the only open item is G-7 content.

**Phase 6 — verification and release. ✅ DONE `04d9a7d`.** Full suite, strict
gate, guards, and a release APK from a clean detached worktree with the four
gitignored files copied in. The full run found four regressions of my own that
no feature test could see (three raw font sizes, two 22 dp sheet radii, one
Material time picker, one Material date picker) — all fixed in `04d9a7d`, after
which `type_scale_guard`, `sheet_contract` and `latin_digits_guard` are green.
APK: `app-release.apk` 49,995,444 B (47.7 MB), sha1 `4c919b82…`, version
`1.8.0+10017`, ABI splits disabled by design in `build.gradle`, binary proof
12/12 strings found / 3/3 mojibake forms absent. The on-device pass (G-8) is
still impossible here: no Android device is attached.

**Phase 7 — docs. ✅ DONE.** This file, `PROGRESS.md`, and the delivery report
`docs/PERSONAL_TOOLS_DELIVERY.md` (what shipped per tool, the new files, the
release numbers, and the two items only the user can close: G-7 content and the
G-8 device pass).

## 4. Content the user must supply or approve

1. **Kaffara/fidya rules** — every rule is `reviewed:false` today, so the tool
   correctly shows «این حکم هنوز در برنامه موجود نیست». Ship-ready text and
   numbers must come from the user, not from the model.
2. **Care template defaults** — the intervals in `care_templates.json` are
   suggestions (shown with «پیشنهادی») and are now editable in-app per device;
   the shipped numbers still need your review before release notes call them
   authoritative.
3. **Local units** — the five defaults (من تبریز، سیر، مثقال، نخود، خروار) ship
   flagged unverified; anything else is a typed base, never a guess.
