# 03 — PART 2 MIGRATION PLAN (ordered waves, authorization list, gates)

**Base:** `release/1.8.0` @ `dccdcfd`, worktree `final-map`, branch `final/map`.
PART 1 produced **no code change**. This is the execution order for PART 2 ("make the
whole app one consistent professional design"), with the exact inputs: the surface
tables in `00_…COVERAGE.md` §A–§M, the graded defects in `01_FINDINGS.md`, and the rules
in `02_DESIGN_CONTRACT.md`. PART 3 (repair/harden/verify) and PART 4 (release) consume
`04_VERIFICATION_PLAN.md`.

**Wave rule.** One wave = one reviewable unit = its own commit(s), its own verification
run, its own rollback line. Never mix a design migration with a logic fix, a protected-file
edit, or a formatting sweep in the same commit.

---

## 0. Wave 0 — make the gate honest (must be first, ~1 h)

The suite is **red at base**: 6 failures (`05_BASELINE.md` §2). A red suite cannot certify
a migration, so fix it before touching design.

| # | Task | File | Change | Evidence it is fixed |
|---|---|---|---|---|
| 0.1 | `F-01` type-scale red | `adhkar/tasbih/presentation/widgets/tasbih_counter_widget.dart:1276` | `fontSize: 9.5` → `AppTheme.scaledFontSize(context, 10)` (or the nearest semantic step); do not edit the guard | `flutter test test/core/theme/type_scale_guard_test.dart` green |
| 0.2 | `F-01` 5 home golden reds | `test/features/home/presentation/screens/home_golden_test.dart:166` + the hero stub | the harness freezes only `second`, so the hero prints the real wall-clock **minute** → freeze `minute` too, then re-pin the 5 full-page baselines (verify the diff is *only* the minute text) | `flutter test test/features/home` green; baseline diff explained line-by-line |
| 0.3 | `F-35` failures dir | `test/features/home/presentation/screens/failures/` (18 PNGs) | delete after 0.2; confirm gitignore covers any regeneration | dir gone |
| 0.4 | New enforcement tool | `tools/design_consistency.py` (new) | reproduce the `00_…COVERAGE.md` marker table (kit/timetheme/AppColors/hard-coded colours/raw sizes/BoxShadow≥10/`Opacity(`/`TextDirection.ltr`) with an explicit allowlist; exits non-zero on growth outside the allowlist | run it: numbers match `00` §0 exactly |
| 0.5 | `F-15` CI robustness | `dart_test.yaml` | make the `network` tag opt-in (or excluded by a default preset) so an offline run is green | two consecutive `flutter test` runs without network |
| 0.6 | `F-20`/`F-21` lint debt | `test/core/database/mock_daos.dart:255,260` + the 134 `avoid_redundant_argument_values` etc. | fix the two `override_on_non_overriding_member` warnings; leave the info-level lints to a single mechanical pass **after** 0.2's baselines are re-pinned | `flutter analyze` = 0 errors / 0 warnings |

**Exit gate 0:** `flutter analyze` 0/0 · `quality_check.py --strict` 7/7 zero ·
`flutter test` **all green** · the 6 baseline reds accounted for individually.
Without this gate, every later wave would be certified against a noisy signal.

## 1. Wave 1 — the share/viewer family (worst colour+size offenders, all D1)

Rationale: highest defect density, lowest risk (pushed screens, few state machines), and
they establish the `SimplePage`/`ReportGauge` recipes the rest of the app reuses.

**Progress 2026-10-12 — the six cream share cards are DONE** (`00b18bc` + `c57e51f`):
`ShareCardPalette` is now the single source for the export palette, and
`prayer_times_share_screen`, `adhkar_share_screen`, `dua_share_screen`,
`quran_ayah_share_screen`, `quran_tafsir_share_screen` and
`dua_from_quran_share_screen` are each at **0 raw colours / 0 raw sizes** (every
removed colour value was verified byte-identical to its palette entry, so the
exported PNGs do not change). Ratchet budgets: raw_colour 714 → 653, raw_size
598 → 561. Still open in this wave: `yaqeen_lesson_screen` (17/21),
`book_reader_screen` (15/4), the ketabkhaneh library and `reading_stats_screen`.

| Surface | File(s) | Debt | Template |
|---|---|---|---|
| Prayer-times share | `prayer/presentation/screens/prayer_times_share_screen.dart` | D1 · **18 colours / 12 sizes** | SpecializedViewer |
| Yaqeen lesson | `yaqeen/…/yaqeen_lesson_screen.dart` | D1 · 17 colours / 21 sizes | SimplePage |
| Book reader | `books/…/book_reader_screen.dart` | D1 · 15 colours | SimplePage |
| Adhkar share | `adhkar/…/adhkar_share_screen.dart` | D1 · 13 colours | SpecializedViewer |
| Dua share | `adhkar/duas/…/dua_share_screen.dart` | D1 · 13 colours | SpecializedViewer |
| Ayah / tafsir share | `quran/mushaf/quran_ayah_share_screen.dart`, `quran_tafsir_share_screen.dart` | D1 | SimplePage |
| Dua-from-Quran (+share) | `dua_from_quran_screen.dart`, `…_share_screen.dart` | D1 | ListCard |
| Ketabkhaneh library | `ketabkhaneh_screen.dart` | D2 · 12 colours / 8 sizes | ListCard |
| Reading stats | `reading_stats_screen.dart` | D1 | ReportGauge |

**Guard for every share surface:** the share **text/footer** must keep using
`ShareService.appLine` (`quality_check` gate 4) and the rendered widget must stay
export-safe (the share-image path renders off-screen — verify with the existing share tests).
**Exit gate 1:** these files drop to 0 raw colours / 0 off-scale sizes in
`design_consistency.py`; share tests + goldens green; the produced share image is
inspected once on device (`adb` pull or share to a local target).

## 2. Wave 2 — the daily core (prayer, qibla, period, adhkar)

| Surface | File(s) | Debt | Notes |
|---|---|---|---|
| Prayer guide (7 tabs) | `prayer/…/screens/prayer_screen.dart` | D1 · 3 colours / 2 sizes | SimplePage |
| City picker + calc sheets | `prayer/…/widgets/city_picker_sheet.dart`, `prayer_calc_widgets.dart` | D1 | SheetDialog |
| Prayer & adhan settings | `prayer_settings_screen.dart` (1230 LOC) | D2 | SettingsRows; **split the file first** (F-13/F-17) so the diff is reviewable |
| Qibla | `qibla_screen.dart` (1692) + `qibla_compass_card.dart`, `qibla_info_card.dart` | D1 · 14 sizes · the **only** `Opacity(` in lib (L1620) | SpecializedViewer; keep the compass painter + the “compass approximate” banner (E-2) |
| Period | `period_screen.dart` + 7 part files (protected) | D1 | SpecializedViewer; **logic untouched** (the audit's C-2/D-2 invariants) |
| Battery guide, map picker | `battery_optimization_screen.dart`, `map_picker_screen.dart` | D2/D1 | SimplePage |
| Adhkar tab + tasbih | `azkar_tasbih_tab.dart` (523), `tasbih_counter_widget.dart` (1379), `azkar_list_widget.dart` (479), `zikr_card.dart`, `tasbih_widget_preview.dart` | D2/D1 | Task #6 of the repo's open list; **keep the counter's behaviour tests** and the click-sound fix; do not resurrect the removed `_createMember(double volume)` signature |
| Tasbih dialogs | inside `azkar_tasbih_tab.dart` | legacy | SheetDialog |

**Exit gate 2:** the adhan/prayer-time widget tests + the 257 prayer-time correctness
tests still pass unchanged (any failure here is a **stop-and-investigate**, not a
re-pin); qibla declination tests unchanged; `Opacity(` count = 0.

## 3. Wave 3 — the tools (highest single-file offenders)

| Surface | File(s) | Debt | Notes |
|---|---|---|---|
| Zakat | `tools/zakat/…/zakat_screen.dart` (1849) | D2 · **28 colours** (largest offender) | ReportGauge; **the fiqh table (J-1/F-02) is out of scope** — colours/layout only, no calculation change |
| Inheritance | `tools/inheritance/**` (`calculator_tab` 1806, `madhab_calculator` 1488, `pie_chart` 28 colours) | **COLOUR DONE** (2026-10-13: 111 literals in 13 files → one allowlisted `inheritance_palette.dart`, every replacement proved value-identical, both goldens unchanged); the layout recipe (SpecializedViewer) is D1 and **any re-pin must be deliberate** |
| Inheritance — the pitfall | `inheritance_palette.dart` `series` | — | The donut paints slice *i* with `series[i % series.length]`, so the list's ORDER is load-bearing: it must stay `[fard, AppTheme.success, accent, AppTheme.warning, asabaInk, AppTheme.error, 4527A0, EF6C00, 0097A7, 558B2F, AD1457, 283593, 6D4C41, 37474F]` (the two hand-copied lists both had 14 entries and the first pass here silently dropped the three status hues — proof: `test/features/tools/inheritance` goldens) |
| Moon & mansions | `tools/moon/**` (`moon_screen.dart` 1377) | D2 · **48 raw sizes** (largest type debt) | SpecializedViewer; keep the `clipData: FlClipData.all()` and the accuracy maths untouched |
| Purification | `purification_screen.dart` (777) | D2 · 7 colours | SimplePage |
| Dangi | `dangi_screen.dart` (940) + report (666) | D2 · 18 sizes | ReportGauge |
| Calculator | `calculator_screen.dart` (868) | D2 | SimplePage |

**Exit gate 3:** zakat/inheritance **calculation tests** unchanged and green; moon
accuracy tests unchanged; each re-pinned golden justified by the intended visual change.

## 4. Wave 4 — knowledge & media

Hadith books index (1597) · Dorar search/details · Riyad list/chapter · hadeeth_enc
(+detail/share) · Fatwa · Yaqeen home/level/quiz · Audio library + mini player (1555/1517,
keep the lazy-list perf work) · Education detail/study (`study_widgets.dart` 1735) ·
global search · dua detail / hesn intro reader.
Template: ListCard / SimplePage / SpecializedViewer. **Exit gate 4:** dorar `network`
tests still pass (they are the regression net for a *recently fixed, network-fragile*
feature — do not “tidy” the UA fallback), audio-library tests green, no new
`BackdropFilter`/blur introduced.

## 5. Wave 5 — long tail + shell edges

Checklist (705) · Fasting (+ Ramadan tracker) · Hajj/Umrah · Ruqyah · Reminders editor ·
Pomodoro · Tasks · Expenses + report · Photo gallery · Worship notes + editor · Goals
(detail/editor) · Suggestions · Announcements · Account · `personal_info` sub-screens
(8, protected) · Settings interiors (1850-LOC hub — split first) · Notification settings ·
Widget settings · About · 404 · Onboarding (3 steps) · boot location dialog
(`boot_coordinator.dart`, protected) · error boundary · font display page.

**Exit gate 5:** `00_…COVERAGE.md` §M counts → 0 inside the allowlist; every row DONE or
explicitly `needs decision`; every `FROZEN` row unchanged (diff check).

## 6. Wave 6 — parity, accessibility, goldens

1. **Native parity:** verify `TopicHues` ↔ `WidgetTokens.kt` ↔ notification accent stay
   in sync; splash window + widget preview screenshots on device.
2. **Accessibility:** the F-06 checklist (TalkBack order/text-scale 1.3/tap targets/
   contrast) on every migrated screen; extend the overflow matrix.
3. **Goldens:** one group per template; the mushaf 9 colour goldens only change if the
   wash/paper maths changes — if they move, stop and explain why.
4. **Consistency tooling:** `design_consistency.py` must report **zero non-allowlisted**
   raw colours/sizes/shadows/directions.

## 7. Protected-file authorization (needed before the wave that touches each)

> **GRANTED 2026-10-12 — the user approved *every row* of this table** (asked as a
> numbered choice, answered «همهٔ بند ۷ را تأیید می‌کنم»): the design-only interiors of
> period / moon / zakat / inheritance / personal_info with logic frozen, the
> `prayer_settings_screen.dart` + `settings_screen.dart` splits, retiring
> `SectionColors`, and deleting the dead `flutter_svg` dependency and the
> `surah_header.png` asset. Each wave still has to keep its own evidence, and a
> logic change is still out of scope for a design commit.

| File / bundle | Wave | Why it must be touched | Requested authorization |
|---|---|---|---|
| `adhkar/tasbih/.../tasbih_counter_widget.dart` | 0.1, 2 | the red type-scale literal + design migration | ✅ already the repo's open task #6 |
| `test/features/home/.../home_golden_test.dart` (+baselines) | 0.2 | fix the harness freeze | justify per PNG |
| `prayer_settings_screen.dart`, `settings_screen.dart` | 2, 5 | split god-files + migrate interiors | split-first, no logic change |
| `period_screen.dart` + `period/**` | 2 | legacy interiors | design only, logic frozen |
| `tools/moon/**` | 3 | the 48 raw sizes | design only; keep clip + maths |
| `tools/zakat/**`, `tools/inheritance/**` | 3 | colours/layout | design only; calculations frozen |
| `personal_info/**` | 5 | legacy sub-screens | design only; vault behaviour frozen |
| `boot_coordinator.dart`, `main.dart`, `pubspec.yaml/lock`, `*.g.dart`, `app_database.dart` | — | **not needed** | keep protected |
| `duas_screen.dart` (حصن المسلم) | — | **stays frozen**; F-38 only deprecates `SectionColors` *after* its last import moves | keep frozen |
| mushaf/QCF4 bundle | — | **not needed** (chrome already done) | keep frozen |
| `section_colors.dart` | 1 or 5 | F-38: retire the duplicate hue table once `duas_screen.dart` no longer imports it | needs explicit OK (it is on the protected list) |
| `pubspec.yaml` (F-22/F-23: `flutter_svg`, `surah_header.png`) | 0 or 5 | delete measured-dead dependency/asset | needs explicit OK |

## 8. Way of working (shared tree — non-negotiable)

- `git status` + `git diff HEAD` before every wave; **never assume staged == yours**.
- Stage **per file** (`git add <file>`), never `git add -A`; `git diff --cached --stat`
  between add and commit.
- Never bare `git stash`. No `build_runner` unless the user asks (F-03/F-04 would need it).
- No `dart format` sweep inside a design commit — format once, separately, after the wave.
- **Never push** (no remote); «ریلیس» = `flutter build apk --release`.
- One wave = one commit series with its own `PROGRESS.md` entry; docs commits separate
  from code commits.
- Any wave whose verification is impossible on the available hardware must be reported as
  “migrated but unverified on a low-end device”, never as “verified”.
- **The share surfaces cannot drift back**: `*_share_screen.dart` and
  `*_share_card.dart` are held at **0 raw colours / 0 raw sizes** by
  `test/core/design_system/share_surfaces_source_lock_test.dart`, which also
  asserts the file list, so a new share card fails the test until it joins the
  lock and gets a palette. Extend the same lock to a new family (a report card, a
  widget-preview surface) rather than re-typing hexes in it.
