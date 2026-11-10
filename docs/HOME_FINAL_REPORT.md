# HOME_FINAL_REPORT.md — the home/final-v3 rebuild

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


Branch `home/final-v3` (nine commits, cut from `release/1.8.0` @ `812d092`).
Scope: presentation/layout rebuild of the Home tab plus the nine listed logic
fixes. Every existing behavior and data source is preserved (prayer checking,
rawatib tracking, reminders, navigation, share, search, location refresh);
religious content untouched — the app's own domain definitions were reused
everywhere (`rawatibWindows`, `duhaWindow`, `azkarTimelineWindows`,
`homeDayState`, the tracker and reminder persistence paths).

## Page structure (top → bottom)

Full-bleed `HeroCard` (ListView padding zero) → padded column, side padding
12, gap 8: `PrayerTimesCard`, `RawatibCard`, `DailySummaryCard`,
`ActionsTimelineCard`, `RemindersCard`. Bottom nav unchanged. Battery
banner (when applicable) stays first in the column. Pull-to-refresh,
search AppBar action, pending-prayer highlight, TickerMode-aware ticking —
all carried over.

## The nine bugs — where each was fixed

1. **10-marker arc** — `_HorizonArcPainter` (3/9): ten markers at
   path-length fractions, five prayers as circles, five derived milestones
   as diamonds, sun/crescent riding time-linearly.
2. **One SectionHeader** — every card uses the shared
   `core/design_system` SectionHeader (title + optional count chip +
   optional trailing).
3. **Timeline wraps content** — `ActionsTimelineCard` (7/9) sizes to its
   rows; «اکنون» pill on the node column, never glued to the chip.
4. **Rawatib row-major chronological** — `RawatibCard` (5/9): six single
   boxes in pairs of two, RTL row-major so «راتب فجر» is first and «وتر»
   last; relevance from the single `rawatibWindows` table.
5. **Summary rings alive at 0%** — `DailySummaryCard` (6/9): track is the
   accent at 20% and a start dot marks the sweep origin; centre carries the
   stat's icon.
6. **Reminder rows compact, no arrow** — `RemindersCard` (8/9): 50dp rows,
   34dp duotone tile, 21dp circle at the end, no chevron.
7. **Sunrise is not a prayer window** — `homeDayState` (1/9): sunrise row is
   never «اکنون»/«بعدی»/missed (only its duha checkbox); «بعدی» goes to
   Dhuhr; the header chip shows the period NAME through the sunrise→dhuhr
   stretch, never a fake «اکنون».
8. **Arc number = time to next ADHAN** — `PrayerSnapshot.nextAdhanTime`
   drives countdown, arc, «بعدی» badge and timeline from ONE shared
   snapshot (`prayerClockProvider`); iqama never names the countdown;
   guarded by `prayer_clock_arc_test.dart`.
9. **No secondary text under prayer rows** — single-line rows (bug #6 of the
   old card): 30dp tile · name · time · check circle only.

## Documented defaults / behavior notes (no fiqh invented)

- **cornerRadiusProvider dropped** — `AppCard` keeps its own r22; the old
  per-screen corner provider had no other consumer.
- **Static loading skeletons** — cards render one skeleton row while their
  provider is loading (previously: blank/spinner).
- **Prayer error card has no retry button** — the RefreshIndicator (pull)
  and the location chip remain the retry paths.
- **Added haptics** — `HapticFeedback.selectionClick()` on prayer-row
  toggles, rawatib boxes and reminder circles (persistence paths
  unchanged).
- **Qada counts as performed** — in the daily summary's نماز ring (the
  app-wide daily-total convention; `homeDayState` already treats
  done+qada the same).
- **Rawatib day framing** — before fajr the card evaluates *yesterday's*
  windows (so late-evening وتر stays relevant); the وتر window extends to
  midnight when its prayer-time-derived end would end before it starts;
  all from `rawatibWindows` (1/9), previously inline in the widget.
- **Rawatib footer** — «+ N مورد دیگر» counts the duha checkbox that lives
  on the prayer card, keeping the n/7 counter honest.
- **Timeline replaces `DailyAdhkarBox`** (deleted with its test); the
  adhkar entry opens `AdhkarCategoryPage` (extracted 7/9) via the existing
  `onNavigateToAzkarTimeline` shell hook.
- **Duha window unified** on the domain `duhaWindow(day)` (sunrise→dhuhr);
  the old reminder widget used dhuhr−30.
- **Reminder progress bars dropped**; the numbers fold into the subtitle
  («… · N از 1 صفحه», «… · X٪ از ختم فعلی»).
- **Conditional-reminder accents** — fasts/ayam-al-bidh → `khatm` green,
  duha → `sunrise`, qiyam → `isha`, post-prayer adhkar → `done` green,
  daily dua → `dua` purple, quran page → `tilawa` blue, khatm → `khatm`.
- **Restored-rows bug fixed** (`RemindersCard._initPrefs`): the old widget
  seeded restored pref ids only into `_doneIds`, never `_completedIds`, so
  after a restart those rows appeared in *neither* list and silently
  vanished while the chip kept counting them. Both sets are seeded now.
- **Daily-dua selection seam** — `RemindersCard` picks the daily dua with
  `widget.nowOverride ?? DateTime.now()` so tests/goldens are
  deterministic; the SharedPreferences keys stay on the real clock (the
  date-roll timer owns them), matching the old semantics.
- **Sections dropped per the approved spec** — `FridayAdabCard`,
  `WorshipTodayCard`, `HomeGoalsCard`, `QuickActions` grid and their tests
  (deleted after verifying no remaining references). `prayer_icons.dart`
  was already a dead file before this branch — left alone.
- **Prayer-card row layout** — the name + state badge group sits in a
  `FittedBox(scaleDown)` so extreme constraints (320dp, text scale 1.3)
  shrink the group instead of overflowing; at normal widths nothing scales.
- **Cross-boundary fix (protected mushaf sheet, kept minimal):** the
  concurrent session's `c03f1ec` (in this branch's base) wrote a raw
  `fontSize: 10.5` into `mushaf_color_sheets.dart`, which left the
  shared type-scale guard red — its caption also ignored the user's
  font-size setting. Fixed to `AppTheme.scaledFontSize(context, 10.0)`
  (the caption's pre-existing size; their alpha 0.6→0.7 legibility bump
  stays) and their three sheet pixel goldens re-pinned — any on-scale
  value differs from the pinned 10.5, so re-pinning was unavoidable.
  The alpha bump is the visible part of their change and is preserved.

## Tests

- `test/features/home/domain/` — arc, day state, rawatib windows, azkar
  timeline unit tests (1/9).
- Widget tests per card: hero (3/9), prayer card (4/9), rawatib (5/9),
  summary (6/9), timeline (7/9), reminders (8/9).
- `home_golden_test.dart` — 10 goldens (per-card day baselines; full page
  412 / 320 / 360@1.3 / lite) + a 320·360·412 × scale 1.0·1.3 overflow
  matrix, all zero-exception, recorded with `--update-goldens` and verified
  plain (16/16). Per-card goldens pump the card ALONE inside its own
  `RepaintBoundary`: `matchesGoldenFile` on a bare card captures the
  nearest boundary ancestor, which silently made five of the six per-card
  files identical full-page shots before that.

## Verification

- `flutter analyze lib test` — 0 errors / 0 warnings (pre-existing infos only).
- `python tools/quality_check.py --strict` — all 7 gates zero.
- `flutter test --exclude-tags network` at the merged tip `d10711f` —
  **3360 passed / 9 skipped / 1 failed**. The single failure is
  `type_scale_guard_test`, and it is **not from this work**: the four
  off-scale literals are in the quran reader, all introduced by the commits
  already sitting on `release/1.8.0` before this merge (`80aabec`, `754c20d`,
  `f1a78e5`):

  | file | line | value |
  | --- | --- | --- |
  | `lib/features/quran/mushaf/quran_mushaf_view.dart` | 1840 | `12.5` |
  | `lib/features/quran/mushaf/quran_reader_header.dart` | 117 | `10.5` |
  | `lib/features/quran/mushaf/quran_reader_player.dart` | 126 | `9.5` |
  | `lib/features/quran/mushaf/quran_reader_player.dart` | 326 | `13.5` |

  Left unfixed deliberately: those three files are inside the protected
  mushaf bundle, the quran session is still mid-spec there (its own progress
  log lists specs D/F/G and the goldens pass as open), and correcting the
  sizes would re-pin their reader/mushaf pixel goldens underneath them. The
  one instance I did have to touch — `mushaf_color_sheets.dart`'s `10.5` —
  was in the same hunk region as my own edit and is fixed in `215b839`.
- Every suite this report is about — home, prayer, adhkar, mushaf-settings —
  is green; the 16 home goldens are deterministic.

## Not verified on device

No Android device was attached during this branch: the goldens prove layout
under the test font (which renders every glyph at a fixed width — wider
than real Persian), and all functional claims are static + widget-test
proof. The ellipsis/guard changes (hero location chip, prayer-row
FittedBox) are laid out to be no-ops at real-device widths.

## Artifacts

- Branch `home/final-v3` → merged at `d10711f`, docs at `ffcbe94`, landed on
  `release/1.8.0` by fast-forward (never pushed — the repo has no remote).
- Release APKs built from clean detached worktrees with no dart-defines
  (Sentry stays OFF), `version: 1.8.0+10015`:
  - `Desktop/tawheeed-release-apks/1.8.0-ffcbe94/` — fat 48,052,615 B
    (sha1 `2b52eba8…`), arm64 31,800,351 B (`c402467c…`),
    armv7 32,073,731 B (`da1e5030…`).
  - `Desktop/tawheeed-release-apks/1.8.0-b873178/` — the same code plus the
    concurrent More four-column commit `eaeeb9f`, i.e. the shipping build:
    fat 48,052,683 B (`6e80c9bf…`), arm64 31,800,396 B (`9f1f51e9…`),
    armv7 32,073,770 B (`bf7411e8…`).
- Proof on the arm64 binary: the ten home/checklist Persian + Arabic strings
  are present as UTF-16, the two CP1256 mojibake forms and the deleted
  «مصحف توحید» / «تلاوت‌یار» / «آمارهٔ پیشرفت» labels are absent.
