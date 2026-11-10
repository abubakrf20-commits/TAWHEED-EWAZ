# PROGRESS — Quran redesign (`quran/redesign`, on release/1.8.0)

Spec: docs/QURAN_SCREEN_INVENTORY.md. Every commit is one screen.
Religious text is never touched — chrome, colours, spacing outside the
text block only.

## Done

- [x] Inventory + plan (all 26 screens/sheets/states) — 52dcbb9 equivalent.
- [x] Fraction formatter + RTL-bidi isolation, applied everywhere — bugs 1.
- [x] **Bug 2** download-sheet header pinned above its scroll (was clipped
      under the status bar).
- [x] **Bug 3** reader header rebuilt: 46dp gradient band, index + search at
      the start, «سورة X» / «جزء N · صفحه M» centred, bookmark + overflow at
      the end, 3dp gold progress line. Reciter chip / repeat / tune / go-to
      left the bar, so nothing is truncated any more.
- [x] **Bug 4** start-download icon now says download (not a check) until
      everything is on disk; counters confirmed to come from real files
      (cachedPageCount / cachedFontCount list the disk).
- [x] Spec A player: radius-24 gradient panel, gold progress, chevron-up,
      «<reciter> · mm:ss», 44dp gold play button with a loading ring.
      Expanded sheet carries reciter / speed / repeat / sleep / stop.
- [x] Spec B overflow menu (settings, verse-follow, downloads, translation,
      + bookmark list and page share).
- [x] Page chrome: 34dp page-number ring at the bottom centre, gutter shadow
      on the binding side, gold hairlines around the text block. The
      floating surah/juz chips are gone (the header carries them).
- [x] Spec C reading-settings sheet: two cards, colour swatches, keep-awake
      toggle on the shared AppWakelock, pinned close button.

- [x] Spec E download page — `254c51f`: storage hero (ring + two labelled
      bars + free space), wifi-only toggle, reciter row, surah/whole-quran
      buttons, juz grids with per-juz states.
- [x] Spec F translation & tafsir sheet — per-row download/delete/progress
      states and the language chip.
- [x] Spec D ayah action sheet — `quran_reader_ayah_sheet.dart`: verse chips
      over the tile grid plus the share tile.
- [x] Spec G index / search / bookmarks on the shared templates.
- [x] Every reader list on the one kit row + a rotate button in the bar —
      `719ee32`; the download hero's off-scale type back on the scale —
      `502dcb8`. See the session section at the end of this file.

## Left

- [ ] Mushaf integrity golden (pixel-identical text block, default theme).
- [ ] A baseline for the reader's *lists* — `quran_kit_row.dart` is not covered
      by any golden yet, so the row recipe can drift unseen.
- [ ] Device pass: no Android device is attached, so Persian shaping, night
      contrast and the rotate button's real orientation change are unverified.

## Notes / open

- Keep-awake + word-by-word: only keep-awake exists in the app's prefs, so
  word-by-word is out until a preference backs it (reported, not invented).
- The untracked `mushaf_palette_render_audit_test.dart` is a foreign
  session's scratch test and fails for that reason; not touched.
- Icons in the old reader header that are now unreachable (reciter picker)
  are reachable from the player sheet.


---

# Home final v3 — branch `home/final-v3` (2026-10-10)

Full home-page rebuild per the approved spec (9 bugs, 7 sections, hero arc).
Worktree: `C:/Users/abubakr/AppData/Local/Temp/home-final-v3`, cut from
`release/1.8.0` @ `812d092`. Small commits per section; merge = `--ff-only`
into `release/1.8.0`, then release APK from the merged tip.

- [x] **1/9 Domain:** ten-marker arc + home day state (pure, unit-tested).
  `prayer_clock.dart`: `PrayerSnapshot.arc` (ArcState: 10 markers at
  path-length fractions 0·1/6·2/6·3/6·7/12·8/12·9/12·10/12·11/12·1, prayer
  circles + derived diamonds طلوع/ضحی/نیمه‌شب/ثلث آخر, states passed/next/
  upcoming, time-linear nowFraction per segment, «صبح (فردا)» end rule,
  undefined milestones dropped — no crash/NaN); derived-event defaults
  duha=sunrise+20min (app convention), midnight/last-third = SunnahTimes
  formulas. `home_day_model.dart`: HomeDayState (open fardh window — sunrise
  is NOT a window, bug #7; row states done/missed/now/next/upcoming —
  «بعدی» targets the same absolute instant as the countdown; app period
  labels شب/فجر/اشراق و صبح/…; rawatib windows + duhaWindow; azkar windows +
  active-indices ported verbatim from DailyAdhkarBox incl. fallback).
  Tests: 8 arc groups in prayer_clock_test (ring==countdown all-day sweep)
  + home_day_model_test (17 tests). Suite + strict gate green.
- [x] 2/9 shared DuotoneIconTile + home tokens (log below)
- [x] 3/9 hero rebuild (10-marker arc painter, countdown to ADHAN only) — log below
- [x] 4/9 prayer times card (single-line rows, no secondary text — bug #9) — log below
- [x] 5/9 rawatib card (row-major chronological RTL) — log below
- [x] 6/9 daily summary rings — log below
- [x] 7/9 actions timeline (wraps content — bug #3) — log below
- [x] 8/9 reminders card rebuild (bug #6): RemindersCard — a compact
  behavioural port of the old QuickReminders with the same data sources
  (per-day done-ids under home_reminders_<dateKey>, daily dua from
  HesnDbService + DailyDuaSelector, readingStatsProvider for today's
  pages, active khatm for the percent line) and the same conditional
  set: Mon/Thu fasts + tomorrow's fast, ایام البیض (HijriUtils, offset
  selector), duha inside the DOMAIN duhaWindow (documented change: the
  old reminder window ended at dhuhr−30min), qiyam hour≥20/<5, and the
  post-prayer slots VERBATIM (iqamahOffsetX ?? fallback {fajr 30, dhuhr
  25, asr 25, maghrib 7, isha 25} + 10, window −5/+30) keyed on the
  pre-fajr-framed day. Presentation: ~50dp rows r15 accent@10% +
  0.5dp accent@25% border, 34dp DuotoneIconTile, title 12.5/500
  mix(accent,black,45%) light / raw accent dark, subtitle 10.5 muted
  with tabular figures, and the toggle circle (21dp, hollow accent /
  filled done + white check, 48×50 tap area, Semantics «انجام شد»/
  «لغو انجام», selectionClick) as the ONLY affordance — the arrow icon
  is gone. Progress bars dropped; the label folds into the subtitle
  («… · N از 1 صفحه», «… · N٪ از ختم فعلی») — documented. Accents:
  fasts/bidh→khatm, duha→sunrise, qiyam→isha, post-prayer→done,
  دعا→dua, تلاوت→tilawa, ختم→khatm (collisions accepted). Header:
  SectionHeader + LTR-isolated n/total chip counted over ALL rows
  (pre-hiding, as before); completed rows green lineThrough; allDone →
  green border + «آفرین!» footer verbatim; rows hidden one minute
  after completion (1-min hide timers kept); minute-tick date rollover
  kept. Loading = static skeleton card. BUG FIX (one deliberate logic
  change beyond presentation): rows restored from prefs landed in
  _doneIds but never _completedIds, so after an app restart they
  rendered in NEITHER list and silently vanished while the chip kept
  counting them — _completedIds now seeds from the saved ids so
  restored rows show completed and the all-done footer works across
  restarts. 12 widget tests (always-present rows + chip + no arrow,
  duha window in/out, qiyam night/day, Monday fast, Sunday-evening
  tomorrow fast, post-prayer slot 13:45, toggle round-trip with chip
  0/N→1/N→0/N, toggle-all footer, progress fold-in, saved-ids
  restore). Test facts recorded: the count chip carries LTR-isolate
  wrappers (strip ⁦/⁩ before asserting); the init pref key
  uses the REAL current date (date-roll timer), not nowOverride.
  Analyze clean, strict gate all-zero.
- [x] 9/9 tab restructure + goldens + report. home_tab rebuilt: full-bleed
  hero (ListView padding zero) then the padded column (side 12, gap 8) —
  PrayerTimesCard, RawatibCard, DailySummaryCard, ActionsTimelineCard,
  RemindersCard; old inline RawatibSection/_CounterChip/_RawatibColumn/
  _RawatifChip gone; RefreshIndicator/search/highlight/battery-banner/
  TickerMode lifecycle carried over. Deleted 8 old home widgets + 7 old
  tests after verifying no references (prayer_icons.dart left as a
  pre-existing dead file). Goldens: home_golden_test.dart — 10 goldens
  (6 per-card day, full page 412/320/360@1.3/lite) + 320·360·412 ×
  scale 1.0·1.3 overflow matrix, 16/16. Golden harness fact worth keeping:
  matching a bare card widget captures its NEAREST RepaintBoundary
  ancestor, so five of the six per-card goldens were silently the same
  full-page picture — each card is now pumped alone inside its own
  boundary (key 'golden-card'). Two overflow fixes found by the
  matrix: hero top Row children get unbounded main-axis width so the
  location chip is now Flexible (ellipsis; on-device no-op) — the 68px
  overflow; prayer-row name+badge group wrapped in FittedBox(scaleDown)
  inside its Expanded (the 33px overflow at scale 1.3 — Ahem renders
  every glyph at fontSize width, ~2× real Persian). docs/
  HOME_FINAL_REPORT.md written (all documented defaults + the
  restored-rows bug + the nowOverride daily-dua seam). Cross-boundary
  fix found by the full suite: the concurrent session's c03f1ec (in
  this branch's base) wrote a raw fontSize: 10.5 into the protected
  mushaf_color_sheets.dart, leaving the shared type-scale guard red —
  fixed to AppTheme.scaledFontSize(context, 10.0) (the caption's
  pre-existing size; their alpha 0.6→0.7 stays) and their three sheet
  pixel goldens re-pinned (any on-scale value differs from the pinned
  10.5, so re-pinning was unavoidable). Full suite + analyze + strict
  gate green at commit time.
- [x] 2/9 shared DuotoneIconTile (squircle 0.32S, fill 14%, border 18% over
  the clipped back circle, glyph 0.54S mix 10%) + HomeTokens table
  (mockup-exact hexes; existing-token equalities documented) + tile widget
  test. Gate green.
- [x] 3/9 hero rebuild: full-bleed warm gradient (5B3F31→6A4B3A@16%→
  4A3024@58%→2A1A12) + sun orb gold@26% + bottom glow ellipse + 5 static
  stars (painter static, lite skips all three); bottom corners r42; 78×68
  tiles white 22%→5%, 44px seconds ring track white 20%, glass chip white
  16%, date chips 10.5sp. NEW ten-marker horizon arc painter (306×130
  design space, path-length-fraction markers, circles r3.8 / diamonds 6.6,
  passed gold · next gold ring+halo on gradient fill · upcoming white 90%,
  labels 9sp outer-side along normal / first+last below horizon / next
  gold w500, «صبح (فردا)» end rule, sun r7.5 + 15dp halo by day / crescent
  Path.combine at night, drawn last; RepaintBoundary; repaints only on
  quantized ArcState change). Countdown = «تا اذان <نام>» (bug #8: adhan
  ONLY, iqamah demoted to its own gold pill «اقامه · HH:MM», hidden when
  disabled) + 34sp goldLight digit groups with 9sp unit captions
  «ساعت/دقیقه» or «دقیقه/ثانیه» (bug #1's crowded parenthetical gone);
  resubscribes at the 1h boundary; arcSemantics now marker-based. Tests:
  hero contract (تا اذان + never تا اقامه + اقامه pill), captions render,
  24h, lite; countdown_format_test rewritten for the marker API. Analyze
  clean, home suite green, strict gate all-zero.
- [x] 4/9 prayer-times card rebuild (bugs #2 #7 #9 + hayz gate): shared
  SectionHeader («اوقات شرعی» + phase chip + LTR n/5 + share →
  prayer-times-share route); 4dp 5-segment day bar (done 2E8B3D / now
  E0B25C / missed E6D9C7 / upcoming EFE3D0); six single-line rows (bug #9:
  no secondary line) 30dp duotone tile + 13sp name + LTR time + 21dp
  circle; «اکنون» dark badge only on the open window, «بعدی» dashed-gold
  row only when snap.nextAdhanTime == row time (bug #7: sunrise is never
  now/next — between sunrise and dhuhr the header chip shows the period
  «اشراق و صبح»); notification-tap highlight draws the open-window
  gradient; Friday renames dhuhr via fridayPrayerLabel; hayz day shows
  PeriodHayzBanner and suppresses past-due marks (dayState.exempt);
  done+qada both count as ticked (homeDayModel done set + unit test);
  row tap = tracker toggle + selectionClick haptic. Test seam: nowOverride
  computes the snapshot via the same pure computeSnapshot (production path
  unchanged, shared clock otherwise). 10 widget tests (rows, chip states,
  sunrise-never-now, tap persistence, qada, past-due, hayz, 12h, loading
  skeleton, error). Static loading skeleton (no AnimationController);
  error card without retry (deliberate simplification). Analyze clean,
  home+prayer-domain suites green, strict gate all-zero.
- [x] 5/9 rawatib card rebuild (bug #4): six single boxes in a ROW-MAJOR
  chronological RTL grid (the old card filled two columns top-down so
  مغرب sat above ظهر-بعد); ~36dp boxes with prayer-tint accents (وتر
  534AB7); suggested = accent@12% + accent@35% border, past+unchecked =
  F8F4EC + dashed D9C7B3@85% (new shared DashedRRectPainter, extracted
  from the prayer card), done = green check, muted otherwise. ONE
  relevance table: rawatibWindows() in prayer/domain/rawatib_model.dart
  (فجر-قبل Fajr→sunrise, ظهر-قبل/بعد Dhuhr→Asr, مغرب-بعد Maghrib→Isha,
  عشاء-بعد Isha→midnight, وتر Isha→tomorrow-fajr) + rawatibStateAt
  (ticking wins; suggested inside; past = ended+unchecked) — day framing
  matches the prayer card. Header: SectionHeader + n/7 (duha counts, per
  app convention) + «پیشنهاد این وقت: <نام>» hidden when none; footer «+
  1 مورد دیگر» = the duha tally whose checkbox lives on the prayer card.
  Tap = toggleSunnah + selectionClick. Tests: 10 model tests (spans,
  boundaries, ticking wins, witr across midnight) + 6 widget tests
  (row-major order + RTL dx, suggestion header, tap persistence, past
  dashed, done-never-past, n/7 + footer). Test gotcha recorded:
  re-pumping a second ProviderScope with different overrides in one test
  keeps the OLD container — _pumpCard now passes UniqueKey. Analyze
  clean, home+prayer-domain suites green, strict gate all-zero.
- [x] 6/9 daily summary rings (bug #5): DailySummaryCard — SectionHeader
  «خلاصه امروز» + streak chip (flame B8421C on FCE8DF, hidden at 0, from
  the existing evaluationProvider); three 62dp rings over ONE shared
  painter (6dp stroke, track = accent@20%, round-capped sweep from 12
  o'clock, always-drawn start dot so a zero ring is visibly alive) with
  the stat icon in the centre (mix accent/black 10%) instead of a
  percentage; counters «0/5»/«0/7»/«0/49» in LTR-isolated Latin digits.
  Data sources unchanged: fardh done+qada, sunnahs + duha, azkar
  morning/evening/postPrayer periodStats, evaluationProvider.currentStreak.
  RepaintBoundary around each ring. 4 widget tests (zero render + 3
  counters, qada counts, duha counts, streak chip hidden/shown). Analyze
  clean, strict gate all-zero.
- [x] 7/9 actions timeline (bug #3): ActionsTimelineCard — SectionHeader
  «تایم‌لاین اعمال» + trailing «مناسب این وقت»; ten 78dp nodes (the nine
  azkarTimelineWindows categories 0–8 + the ride-along «بعد از نماز»,
  which never wears the pill) at itemExtent 84 in a bounded
  ListView.builder (card WRAPS at ~105dp — no fixed 122dp dead space, no
  clipped chip). Node = tag row 16dp («اکنون» heroGold/espresso pill r7
  only on the current node) + 4dp + dot row 12dp (2dp rail through the
  centre, gold E8C277 up to the current node / EFE3D0 after; dot 10dp
  2dp white border, current 12dp + 25% halo) + 6dp + chip r14 padding
  7/3 (28dp DuotoneIconTile with the category accent, name 11/500, time
  9.5 LTR tabular = window START time — never a remaining-time «دیگر»).
  States: past F6F1E8@80%, now FFF6DA + 1.2 E8C277 border, upcoming
  FBF8F2 + 0.5 EFE3D0 (dark mode = white-alpha equivalents). Line
  metrics allocated exactly (explicit height 1.35 styles + matching
  SizedBoxes + the widest border 1.2×2 in the budget) so the 1.3 font
  scale cannot overflow. Current node = the latest window whose start ≤
  now (windows may overlap; before today's fajr the day is yesterday's
  cycle so the night node stays current); no schedule →
  azkarFallbackIndices(now.hour) + anchor texts. Auto-scroll centers the
  current node once per index via ScrollController + postFrame jump.
  Tap = selectionClick + push AdhkarCategoryPage (or onNavigateToAzkar
  when the category has no items — old behaviour kept). EXTRACTION: the
  old _AdhkarCategoryPage/_AdhkarItemCard (daily_adhkar_box.dart
  523–1199) moved verbatim into public
  home/widgets/adhkar_category_page.dart (only renames: public class +
  super.key + AppLogger tag 'adhkar_category_page'); daily_adhkar_box
  now imports it and its six now-unused imports were pruned. 9 widget
  tests: start times per window (03:30…22:00 + «بعد هر نماز»), exactly
  one «اکنون» on ضحی at 09:00 (not on the still-open صبح node, not on
  the ride-along), vertical metrics (pill bottom < chip top, node
  ~105dp, ListView == node height), past/upcoming/now chip colors,
  pre-fajr night node current, fallback anchors, tap pushes the page
  (AzkarData.setTestData seed), auto-scroll >300px at 412dp, 12h
  format. Test fact recorded: AzkarData.getByPeriod reads the static
  cache that only loadAll()/setTestData fill — widget tests seed it.
  Analyze clean, home+prayer+adhkar suites green (279), strict gate
  all-zero.

## Landing note

`release/1.8.0` moved under this branch while it was in flight (three quran
redesign commits, tip `26e0d65`), so the branch carries a single merge commit
instead of a rebase: replaying nine commits would have re-conflicted the shared
`PROGRESS.md` nine times. The merge touches two files — `PROGRESS.md` (resolved
by keeping the quran redesign log and re-appending only this section, so
neither session's current log is lost) and `mushaf_color_sheets.dart` (their
sheet-footer/`leading` hunks auto-merged with my one-line type-scale fix three
hunks away). `--ff-only` into `release/1.8.0` after that, then the release APK
from the merged tip. Never pushed — this repo has no remote.

- Landing verification (`d10711f`): analyze 0/0, strict gate 7/7, suite
  3360 passed / 9 skipped / **1 failed**. The failure is `type_scale_guard`
  on four off-scale literals in the quran reader (`quran_mushaf_view.dart:1840`
  12.5, `quran_reader_header.dart:117` 10.5, `quran_reader_player.dart:126`
  9.5 and `:326` 13.5) that arrived with `80aabec`/`754c20d`/`f1a78e5` — the
  branch was already red at `26e0d65`, before this merge. Not fixed here: those
  files are protected mushaf-bundle ground the quran session is still working
  in, and the change would re-pin their in-flight reader goldens. Recorded in
  `docs/HOME_FINAL_REPORT.md` → Verification.

## Splash redesign (`splash/new-design`, on release/1.8.0)

Full write-up: **docs/SPLASH_REPORT.md**. Six commits — `31aa7a2` native
field, `676c6bb` launch re-timing, `ce9cc06` the Flutter field + gate,
`2d0b04e` goldens, then the first device look answered by `5229ce4`
(no mark in the system window) and `400fb1e` + `a608008` (the bigger, lifted
coin and its eight re-recorded baselines).

- [x] Native: `launch_background.xml` is the 3-stop ramp and **nothing else**;
      API 31+ paints that same ramp as `windowSplashScreenBackground` with
      `splash_icon_none` (a 1dp transparent shape — not `@null`, which falls
      back to the launcher icon) in the icon slot, and `MainActivity` fades the
      system window out over 200ms. No new package. The coin appears exactly
      once per launch, on the Flutter frame.
- [x] Dart: `runApp` before the init chain — the same four phases now start on
      the first frame (`AppBootstrap`), and FCM / BackgroundScheduler / Sentry
      are deferred behind it.
- [x] `SplashOrchestrator`: 400ms floor, no ceiling, init and the onboarding
      read in parallel, 12s hang guard that opens Home anyway, dots only past
      2s, 250ms cross-fade (instant in lite mode / under reduce-motion).
- [x] The coin is a plain `Image` of the real asset, centred horizontally and
      63dp (= 1 cm) above the screen centre at `clamp(0.784·w, 224, 320)` — no
      box, clip, glow or shadow, and a test walks its ancestor chain to keep it
      that way. The tagline and the tile-hiding rule derive from its top edge.
- [x] 35 unit/widget tests + 8 goldens (320/360/412 × scale 1.0/1.3, dots,
      short screen). Analyze 0/0, strict gate 7/7, suite 3479 passed /
      9 skipped / 6 failed — none from this branch: the type-scale guard's one
      remaining offender is the tasbih `9.5`, and the five `home_golden_test`
      drifts are its unfrozen `minute`.
- [x] Landed on `release/1.8.0` by rebase + fast-forward onto the quran
      session's tip — zero file overlap in either direction, and the two
      sessions' splash bullets both survive here.
- [x] Release APKs built from `d982679` (this tip, both halves of the second
      pass): fat 47,327,329 B `03e8b347…`, arm64 31,436,675 B `f3689fcc…`, armv7
      31,688,778 B `f4133f37…`, in `Desktop/tawheeed-release-apks/1.8.0-d982679/`
      (+ `SHA1SUMS.txt`, `BINARY_PROOF.txt`). Gradle 753.8s, exit 0 — the only
      command that links `@drawable/splash_icon_none` and compiles the Kotlin.
      28.3 KB **smaller** than the previous splash build: the deleted coin PNG.
      `resources.arsc` names `splash_icon_none` and no longer `splash_icon_288`
      or `splash_logo`; the tagline and «توحید» are in `libapp.so` at both UTF-16
      alignments with every computed CP1256 form absent.
- [x] **The earlier sets are not the build to install.** `1.8.0-84395a0` and
      `1.8.0-7a2eb67` still ship `splash_icon_288` + `splash_logo` in the API 31+
      window — i.e. the square-icon page the user reported. They predate `5229ce4`.
- [ ] **Device pass, all of it**: no Android device is attached, so no
      `am start -W` before/after numbers, no A13/A32 check, no real Persian
      shaping (the goldens render tofu). The commands and the two marks that
      matter are in §3 of the report.
- [x] **Release-build fix (2026-10-12, `7a2eb67`, made by the quran session so
      a release could exist at all):** the 200ms fade was written against
      members that do not exist — `window.splashScreen` and
      `splashView.view`. The handle is an **Activity** member
      (`Activity.getSplashScreen()`, API 31+) and `android.window.SplashScreenView`
      **is** the view (it extends `FrameLayout`), so `:app:compileReleaseKotlin`
      failed with three unresolved references and **no release APK could be
      produced from this tip** (a `flutter test` / `flutter run` never compiles
      Kotlin, which is why it went unnoticed). Confirmed with `javap` against
      the API 36 `android.jar`; the platform-correct form is
      `splashScreen?.setOnExitAnimationListener { it.animate()… }`. No
      `core-splashscreen` dependency was added — the `values-v31` theme stays
      the plain platform one.

## Quran: one kit row for every reader list + rotate button (2026-10-12)

Full write-up: **docs/QURAN_REDESIGN_REPORT.md** (§6 review, §7 suggestions).
Commits `502dcb8` (download hero type onto the shared scale) and `719ee32`
(the kit row, every list, and the header rotate button).

- [x] New `quran_kit_row.dart`: `QuranKitRow` + `QuranKitNumberTile`, built on
      the same flat duotone `DuotoneIconTile` the home page uses on every
      prayer/reminder row. It takes a `MushafPalette` (the reader is
      theme-independent), and the mushaf view library imports it so every
      `part` resolves it. Do not re-introduce a per-list row recipe.
- [x] Converted: reciter sheet (`_KitListRow` deleted), the download page's
      in-download reciter picker (the duplicate list), translations/tafsirs
      (language tag kept as a chip), the player options sheet + the speed and
      repeat pickers, the surah index (per-row `Card` removed;
      `QuranKitNumberTile` + page chip) and the search results (verse stays the
      readable second line via `subtitleColor`).
- [x] `quran_reader_header.dart` gained a fifth control between the bookmark
      and the overflow: a rotate button that calls the same `_setLandscapeLock`
      the reading-settings switch uses, so the two can never disagree. The
      header still fits 320dp with no render overflow (widget test).
- [x] Left alone on purpose: the go-to dialog's surah tab (the reader asked
      for no boxes there) and the reading-settings `MushafSettingRow` (a dense
      settings row, not a list).
- [x] Verification: analyze 0 issues, strict gate 7/7, full quran suite
      **273 passed / 0 failed**, and `type_scale_guard_test` now lists only the
      pre-existing tasbih literal. Full suite
      `flutter test --exclude-tags network` = **3486 passed / 9 skipped /
      31 failed**, and all 31 are accounted for off this work: 25 are the
      foreign untracked scratch file `mushaf_palette_render_audit_test.dart`
      (delete it to run the quran dir), 1 is the pre-existing tasbih literal,
      5 are the pre-existing home goldens that freeze only `second` and read a
      real `minute` (`home_golden_test.dart:166`). **No Android device is
      attached**, so this is static + widget-test proof, not an on-device pass.
- [x] **Release APKs from `7a2eb67`** (the Kotlin compile fix above; the
      docs-only commit `a97b224` on top cannot change a binary) — clean detached
      worktree `%TEMP%/opencode/rel-build-1.8.0-5a298b0` at that tip, the four
      gitignored files copied in (`android/key.properties`,
      `android/app/release-key.jks`, `android/app/google-services.json`,
      `assets/env/quran_api.env`), no dart-defines (Sentry stays OFF: no DSN
      exists in the repo). `flutter build apk --release` = exit 0 in 145 s:
      fat **47,355,576 B** sha1 `326d853a…`, `arm64-v8a` 31,465,109 B
      (`d6b23c71…`), `armeabi-v7a` 31,716,783 B (`a47d1f5d…`). V3 signer DN
      `CN=Tawheed, OU=Mobile, O=TawheedApp, L=Tehran, ST=Tehran, C=IR`.
      Durable copies: `Desktop/tawheeed-release-apks/1.8.0-7a2eb67/` (+
      `SHA1SUMS.txt`, `BINARY_PROOF.txt`), and the three also copied into the
      main tree's `build/app/outputs/flutter-apk/` so they are where the user
      looks. `version: 1.8.0+10015` unchanged.
- [x] Binary proof (`BINARY_PROOF.txt`, arm64 `libapp.so`, strings searched as
      UTF-16LE at **both** byte alignments — a literal at an odd offset is missed
      by a naive decode, which is what made the first two runs lie):
      **8/8 correct forms FOUND** (حالت افقی، حالت عمودی، یادآورها، تقویم، خانه،
      خلاصه امروز، اذان فجر، الصَّلَاةُ خَيْرٌ مِّنَ النَّوْمِ), **5/5 CP1256
      mojibake forms ABSENT**, and the **4 removed labels ABSENT** (مصحف توحید،
      ملقّن، تلاوت‌یار، آمارهٔ پیشرفت). `resources.arsc` still names
      `splash_icon_288` / `launch_background`.

## ارزیابی: the score box is a circle, not an arc (2026-10-12)

User request: «در بخش ارزیابی باکس بنظرم قوس نباشد بلکه طبق دیزاین جدید برنامه
بنظرم دایره باشد زیباتر هست». Landed on `release/1.8.0` as `b95411d` (branch
`worship/score-ring`, rebased onto the quran session's `5874b2c` — zero
overlapping files).

- [x] **What the «قوس» was:** `_ScoreGaugePainter` in
      `lib/features/worship/presentation/widgets/evaluation_stats_widget.dart` —
      a shallow quadratic rail in a 306×92 design space, letterboxed by an
      `AspectRatio`, swept with a `heroGold → heroGoldDeep` linear-gradient
      shader and a cream sparkle at the head. Every other score in the app is a
      circle from the kit (`RingView`), including the worship detail grid in the
      same file, so the rail was the last bespoke gauge in the section.
- [x] **Replaced, not restyled:** `_ScoreHero` is now the label/tier row over one
      `RingView` (132 dp, 8 dp stroke) with the number inside it —
      `AppPalette.heroGold` arc on the white-at-20 % hero track the home ring
      uses, round caps, from 12 o'clock. `RingView` owns the 0..1 clamp, so the
      call site stopped pre-clamping; the painter, the `AspectRatio`, the extra
      `RepaintBoundary` and the gradient shader are deleted, and `heroGoldDeep`
      is no longer referenced here. The ring gains a `semanticLabel`
      (label، score از max) the CustomPaint stack never had.
- [x] The number is `FittedBox(scaleDown)` inside a box capped to the ring's
      inner width, so 1.3 text scale and a four-digit monthly score stay inside
      the stroke.
- [x] **Two pre-existing overflows in the same tab, found by auditing it at
      320 dp / 1.3** and fixed with the codebase's own recipe (the cap must sit
      at the **Row** level — a `Flexible` nested inside the child can never
      bound it): `_TierChip` overflowed the label row by 1.4 px (now `Flexible`
      + `FittedBox(scaleDown)` + `maxLines: 1`, label gets `ellipsis`, 8 dp
      gap), and `_StreakCard`'s label/value column overflowed its `Expanded` by
      35 px under «بهترین زنجیره» (now `Flexible` + `FittedBox(scaleDown)`).
- [x] **Tests:** the file gains `the score hero is a full circle, not the old arc
      rail` (exactly one `RingView` in the `HeroCardShell`, **no** `AspectRatio`,
      a 132×132 rect, gold arc on white-20 % track, non-null semantic label, plus
      `goldens/evaluation_score_hero.png`) and `the score fits a 320dp phone at
      1.3 text scale`. `flutter test --no-pub test/features/worship` =
      **63 passed / 0 failed**; `flutter analyze --no-pub lib test` = 0 errors /
      0 warnings (88 pre-existing info lints); `quality_check.py --strict` 7/7
      zero. The golden renders tofu glyphs and LTR (the test binding loads no app
      font), so it guards palette and layout drift, not shaping.
- [x] **Release APKs from `b95411d`** — built in the `%TEMP%/eval-ring` worktree
      (the branch tip itself, gitignored `key.properties`, `release-key.jks`,
      `google-services.json` and `quran_api.env` copied in), no dart-defines
      (Sentry stays OFF). `flutter build apk --release` = exit 0, Gradle
      `assembleRelease` 406.3 s: fat **47,330,963 B** sha1
      `9b466aff956de2fbbb6687d108e2c8a8d28dbae7`, `arm64-v8a` **31,438,206 B**
      (`077a78d8f407675fdf3abbdb59e04b19a795ab03`), `armeabi-v7a` **31,690,595 B**
      (`cb0be66a88c9a505fa3829edd7779807b40db3df`). Durable copies +
      `SHA1SUMS.txt` + `BINARY_PROOF.txt`:
      `Desktop/tawheeed-release-apks/1.8.0-b95411d/`. `version: 1.8.0+10015`.
      Not copied into the main tree's `build/` — that is the concurrent session's
      build directory. **This set also carries the splash fix**, so it, not
      `1.8.0-d982679`, is the build to hand over.
- [x] **Binary proof** (arm64 `libapp.so`, 22,479,760 B, literals probed as
      UTF-16LE at both byte alignments): **7/7 expected forms FOUND** (امتیاز
      امروز، امتیاز ماه، بهترین زنجیره، زنجیره فعلی، روزهای فعال، یادآوری‌های
      امروز، الصَّلَاةُ خَيْرٌ مِّنَ النَّوْمِ), **4/4 CP1256 mojibake forms
      ABSENT**, **4/4 removed labels ABSENT** → `RESULT: PASS`. The raw-decode
      adjacency scan is recorded as informational only (7,481 hits): a
      byte-wise decode of length-prefixed Dart strings joins unrelated words,
      so it is not a verdict — `text_encoding_guard_test.dart` is the
      source-level check and it passes.
- [x] **What a binary proof cannot show here:** the ring vs the arc is a widget
      tree, not a string. The label probes only prove the build carries the
      un-garbled evaluation text; the shape itself is proven by the widget test +
      golden, and the visual verdict is the user's on a device.
- [x] **No Android device is attached**, so this is golden + widget-test +
      binary proof, not an on-device pass. The visual verdict — whether the
      circle reads better than the rail did — is the user's, on the installed
      build.

## Home polish batch + tasbih ring + order swap (2026-10-13)

User request (Persian, two rounds): the home polish list (arc prettier,
text countdown, visible اذان/اقامه boxes, restore «اوقات شرعی», polished
timeline with much less spacing, «اکنون»/«بعدی» in beautiful boxes, rawatib
3×2, restore «خلاصه امروز» + «تایم‌لاین اعمال», quick access exactly like the
More Style-2 tiles at the same size); then «در صفحه خانه خلاصه امروز تعداد
تسبیح هم اضاف کن، همچنین 10 روز پیاپی حذف کن، در ضمن تایم لاین اعمال بیار
بالای خلاصه امروز قرار بده». All landed on `release/1.8.0` as nine commits
(`ed29946`…`28907a9`).

- [x] **One design-system fix underneath it all (`ed29946`):** the
      `SectionHeader` title+count group is now
      `Expanded(FittedBox(scaleDown, centerStart))` — pixel-identical while
      fitting, uniform scale-down when title and count outrun the row, never
      the invisible-title squeeze. Guarded by the new
      `test/core/design_system/section_header_test.dart`.
- [x] **Hero (`988b039`):** dial deleted; arc stroke 7→4.5, glow 9 stops,
      markers 3.4/5.6; countdown = gold 26sp tabular text + caption under the
      arc. Countdown unit logic unchanged.
- [x] **Prayer card (`dd61206`):** `_RowBadge` carries a tinted fill +
      hairline border; the «بعدی» pill gets a gold-tinted border.
- [x] **Rawatib (`df462fe`):** 3 lines × 2 rawatibs, `IntrinsicHeight` paired
      cells, `FittedBox(scaleDown)` titles for half-width cells at 320dp/1.3.
- [x] **Timeline (`3fab944`):** single `_tagH` formula, rail 10, dots 11/9
      with hollow-ring upcoming borders, 24dp chip tile, far tighter vertical
      rhythm.
- [x] **Quick access (`1414f46`):** the shared `DuotoneIconTile` at
      `moreTileSize` — home and More now cannot drift; only vertical padding
      so the LayoutBuilder still sees full cell width.
- [x] **Summary + order (`28907a9`):** four rings — prayers, rawatib, adhkar
      and **tasbih** (today's total vs the day's summed targets from
      `tasbihStatsProvider`); the «روز پیاپی» chip and `streakBg`/`streakFlame`
      tokens deleted; `ActionsTimelineCard` sits directly above
      `DailySummaryCard`. The ring row uses `Expanded` cells because four
      fixed-width cells overflowed 320dp at scale 1.3 by 12px.
- [x] **Harness (`28907a9`):** the golden harness freezes the ticker's
      `minute` too (the known full-page drift) and overrides
      `tasbihStatsProvider`; all ten home goldens re-recorded.
- [x] **Proof:** `flutter test test/features/home` = **105/105 green**;
      `flutter analyze` on the touched scopes = clean. **No Android device is
      attached** — golden + widget-test proof, not an on-device pass.

## Calendar: pale day boxes, numbered hero, compact occasions (2026-10-13)

User request (Persian): «در بخش تقویم ... هر روز در یک بوکس کمرنگ ... پایین آن
دوباره تاریخ های شمسی و هجری و میلادی امده که حذفش کن ... بالا میخواهم شماره
ماه هم باشد مثلا 12 اکتبر (10) 2026، و مناسبات این ماه هم یه خورده زیبا سازی و
جمع و جور باشد». Landed on `release/1.8.0` as three commits
(`38acea8`, `3b53d36`, `573243d`).

- [x] **Day cells (`38acea8`):** every grid day sits in a pale `t.surfaceAlt`
      box; worship/selected tints layer over it, today keeps its gradient.
- [x] **The duplicated three-date rows are deleted** (`38acea8`): the hero owns
      the three readings; `SelectedDateSummary` slimmed to
      `date/dayName/events/isToday` and keeps only occasions, worship score
      and the fasting control (the `_CalendarRow` class is gone).
- [x] **Month numbers in the hero** (`38acea8`): «9 مهر (7) 1405» pattern on
      all three readings; the parenthesised number goes through
      `NumberFormat.ltrIsolated` so it cannot mirror in the RTL line. New
      `shamsiMonthNum/hijriMonthNum/gregorianMonthNum` fields.
- [x] **Occasions compact (`3b53d36`):** 32dp tile, 6dp padding/gaps, every
      row in its family hue at pale fill, marked rows stronger + hairline
      border, past rows neutral.
- [x] **Tests (`573243d`):** `selected_date_summary_test` now pins the rows'
      *absence*; the layout test derives the hero strings through the same
      isolate helper and expects one occurrence each; five page goldens
      re-recorded, the two converter goldens untouched.
- [x] **Proof:** `flutter test test/features/tools/calendar` = **50/50
      green**. **No Android device is attached** — golden + widget-test proof.

## Inheritance: مناسخات picks its deceased, and wears the kit (2026-10-13)

User request (Persian): «میخواهم بخش میراث مناسخات پیشرفتش بدی، مرحله دوم که میاد
باید متوفی امکان انتخاب یکی از وارثین مرحله اول وجود داشته باشه؛ همچنین دیزاین
مناسخات نیاز به پولیش و اصلاح دارد». Scope confirmed with the user before coding:
the next stage's estate stays **only the picked heir's own share**,
`calculateMunasakhatMerged` is **not** put in the UI, and the entry plus the
bottom sheet stay inside the «محاسبه» tab — rebuilt on the design kit, no new
tab. Landed on `release/1.8.0` as four commits (`974e666`, `96a6442`, `a9ed9fc`,
`cd04a75`) plus docs `75d7961`, merged into the line at `8ff0762` (a merge, not a
rebase, so the other session's hashes stay valid).

- [x] **One heir table (`974e666`):** `presentation/heir_catalog.dart` now owns
      the 44 heirs (label, glyph, tree indent) and both the محاسبه tab and the
      مناسخات sheet read it, so the two can never offer a different set.
      `InheritanceInput.fromCounts` builds the input from a `{HeirType: count}`
      map (all 44 covered), with `heirIsMale` / `heirMaxCount` beside it.
- [x] **The engine takes the relationship, not a name (`96a6442`):**
      `calculateMunasakhat(..., inheritedFromHeir: [HeirType?])` — element 0
      unused — wins over label matching, and the share that moves to the next
      stage is the **per-head** part (`amount / count`), so a chain no longer
      carries two sons' pooled share as one man's estate. An unresolved link
      throws `MunasakhatLinkageException` instead of estimating; the legacy
      fallback warning is Persian now.
- [x] **Stage 2 and on pick, never type (`a9ed9fc`):** the chips are exactly the
      heirs entered for the previous stage (with a count suffix when several),
      the deceased's gender follows the pick (no second toggle), both spouses
      are cleared when the gender becomes impossible, dropping an heir drops
      every link that used it, and the sheet opens on the madhab the tab
      already uses. Refusals are Persian: an unlinked stage, an heir who
      inherits nothing because he is محجوب.
- [x] **The design pass (`a9ed9fc`):** the entry collapsed from three controls
      (expander row + purple-gradient card + «باز کردن محاسبه مناسخات» button)
      into one flat `AppCard` row — one tap to the form. The sheet is kit
      furniture now: `AppCard` stage boxes with `IconTile` heads, `ValueStepper`
      counts (48dp targets), `SectionHeader` for مذهب and the result, one flat
      pill recipe shared by madhab and linkage chips, spouses promoted out of
      «وراث دورتر», and the estate field matching the tab's own input.
- [x] **Tests (`96a6442`, `a9ed9fc`, `cd04a75`):** 11 engine linkage tests
      (picker beats label, three-stage chain, per-head division, strict throw,
      the Persian estimate warning, 44×44 `fromCounts` round trip), 13 sheet
      tests driving the real form through keys, and 6 catalog/tab-entry tests
      (one tap opens the sheet, it opens on the tab's madhab). The sheet is
      pumped inside `Directionality(rtl)` — the direction it is read in — and a
      three-stage chain is proven to fit 320dp at text scale 1.3 with every
      stepper inside the phone's width.
- [x] **Deliberately not done:** no `MunasakhatSheetContent` goldens — the test
      binding loads no Persian font, so they would record tofu boxes; the
      layout/palette is guarded by the RTL fit test and the kit-type assertions
      instead. `calculateMunasakhatMerged` (the all-in-one-mixed-estate solver)
      stays library-only, per the user's scope answer.
- [x] **Proof:** inheritance scope **754/754 green**, full suite
      `--exclude-tags network` at the landed tip = **3562 passed / 9 skipped /
      0 failed**, `flutter analyze` 0 errors / 0 warnings (88 pre-existing info
      lints), `quality_check.py --strict` 7/7 zero, encoding guard green.
- [x] **Release APKs from `8ff0762`:** fat 47,351,447 B (sha1 `2497dbf8…`),
      `arm64-v8a` 31,451,027 B (`38619905…`), `armeabi-v7a` 31,698,323 B
      (`681f3491…`); `version: 1.8.0+10015`; durable copies + `SHA1SUMS.txt` +
      `BINARY_PROOF.txt` in `Desktop/tawheeed-release-apks/1.8.0-8ff0762/`. On
      the arm64 `libapp.so` the ten munasakhat labels are FOUND and the deleted
      «باز کردن محاسبه مناسخات» button label is ABSENT. **No Android device is
      attached** — widget-test + binary proof, not an on-device pass; the visual
      verdict on the form is the user's.

## Home-screen widgets: user-themable palettes (widgets/final-themed, 2026-10-13)

Task #103 — both home-screen widgets (prayer 4×2, tasbih 4×3) rebuilt with
user-selectable styling, on branch `widgets/final-themed` (worktree
`%TEMP%/wlwidgets`, base `eb58ab5`), merged into `release/1.8.0` as
**`e00ac2a`** (62 files, +3045/−1221, zero file overlap with the nine
main-side commits since the base, no conflicts). Seven commits: `4fd017e`
palette source + generator, `5ebac06` WidgetTheme + JVM tests, `0890ebf`
prayer theming + polling removal, `294c785` tasbih tap pipeline, `3c7fe83`
channel bridge, `4baa3f9` palette-picker settings page, `61104ab` docs.

- [x] **Palette source of truth (`4fd017e`):** `assets/widget_palettes.json`
      is the single source both platforms read — 7 Persian-named presets
      (قهوه‌ای طلایی is the default, plus شب آبی, زمردی, کرم روشن, بنفش سحر,
      نارنجی غروب, گرافیتی) and «خودکار», whose palette follows the
      prayer-time phase, plus the four user-facing opacity steps
      (100/85/70/55 %, background only — text/accent stay full strength). A
      Dart generator (`tool/widget_palette_generator.dart`) emits one
      rounded-gradient drawable per preset per step (28
      `widget_<preset>_bg[_oNN].xml`), so the layouts' pre-render skin and
      the API <31 fallback come from the same data. Contract tests pin the
      JSON schema, the WCAG contrast floors (4.5:1 text / 3:1 accent at
      100 %; 3:1 at the 55 % step over a dark backdrop) and auto-phase
      coverage.
- [x] **Native theming (`5ebac06`, `0890ebf`):** a Kotlin `WidgetTheme`
      resolves `widget_palette_id` + `widget_opacity_step` natively — with a
      legacy migration from the old exact-color keys on first resolve — and
      both receivers render from it. The prayer widget stops polling
      (`updatePeriodMillis=0`): 13 boundary alarms are re-armed on every
      render plus a midnight alarm and a 6 h watchdog; TextClock self-ticks
      so no per-minute renders. The tasbih widget does the same with
      TextClock + Chronometer for the live counter.
- [x] **Tasbih tap pipeline (`294c785`, `3c7fe83`):** goAsync +
      `partiallyUpdateAppWidget` drive a 12-frame bead animation (26 ms
      ease-out) on the tapped instance only; the exported receiver
      sender-verifies every mutating broadcast; reset is a two-tap
      confirmation (3 s window); the haptic is gated on the app's
      `azkar_haptic` setting; every tap appends to an append-only drained
      event queue (`{s,k,z,d}` entries, collapsing to a `full` counts
      snapshot past 300) that the app merges idempotently — apply → persist
      `widget_tasbih_applied_seq` → ack `drainTasbihEvents`. The Flutter
      engine is never started from the widget side.
- [x] **Settings page (`4baa3f9`):** the widget settings screen is now a live
      preview + palette chips + opacity segmented control + the manual-sync /
      pin / help footer; the dead legacy per-color path is deleted (bridge
      `updateWidgetStyle`, 9 dead token keys, snapshot color fields — 20
      files, +638/−964). Hub subtitle «رنگ، شفافیت و ابعاد» →
      «رنگ و شفافیت ویجت‌ها».
- [x] **Docs (`61104ab`):** `docs/WIDGET_DATA.md` (channel methods, prefs
      keys, the tap-event protocol with crash semantics, the refresh model)
      and `docs/WIDGETS_THEMING_REPORT.md` (shipped behaviour, palettes,
      contrast policy, sizing matrix, test inventory, manual checklist).
- [x] **Proof:** JVM tests green (WidgetTheme, TasbihWidgetCounting,
      TasbihWidgetDailyReset, PrayerWidgetCountdown, PrayerTimesCalculator;
      `android.graphics.Color` stubbed for the JVM); the widget-settings
      screen test file is fully rewritten (8 tests: render, legacy mirror
      through the save path, stored-theme save, inert save until change,
      tab switch, «خودکار» stored as the selection itself, no-warning sweep,
      dirty-guard pop). Full suite on the branch has the single pre-existing
      More-golden red that `2565420` re-pinned on main after my base (zero
      file overlap with this arc); `flutter analyze` 0 errors / 0 warnings;
      strict gate 7/7; encoding guard green.
- [x] **Release APKs from `e00ac2a`:** fat 47,378,918 B (sha1 `852ab383…`),
      `arm64-v8a` 31,481,604 B (`c1b9d1d1…`), `armeabi-v7a` 31,720,478 B
      (`04d223b0…`); Gradle `assembleRelease` 195.2 s;
      `version: 1.8.0+10015`. Durable copies + `SHA1SUMS.txt` +
      `BINARY_PROOF.txt` in `Desktop/tawheeed-release-apks/1.8.0-e00ac2a/`.
      Binary proof on the arm64 APK (**RESULT: PASS**): 10 widget-screen
      labels FOUND in `libapp.so` (UTF-16LE, both alignments), 3 computed
      CP1256 mojibake forms ABSENT, `resources.arsc` names the generated
      skins (`widget_emerald_bg`, `widget_brown_gold_bg_o55`) and
      `splash_icon_none` (no `splash_icon_288`/`splash_logo`), and both
      appwidget labels («توحید — اوقات نماز» / «توحید — تسبیح») FOUND inside
      the obfuscated-name binary XML entries.
- [x] **No Android device is attached** — JVM + widget-test + binary proof
      only, NOT an on-device pass: adding a widget, tapping the counter, the
      reset confirmation, vibration and palette switching on a real launcher
      remain unverified; the visual verdict is the user's on the installed
      build (`1.8.0-e00ac2a` is the set to install).

# PROGRESS — Settings redesign (`settings/redesign`, branched from `release/1.8.0` @ `274093d`)

Spec: task brief (Design 1 / Design A); inventory: `docs/SETTINGS_INVENTORY.md`
(every screen/row/control + pref key + range/default + side effects +
template; short plan at its tail). Small commits per page. Preference keys,
defaults, ranges and side effects stay exactly as today; presentation only.
Persian UI stays Persian; code/comments/commits in English.

## Done

- [x] Inventory + plan (`docs/SETTINGS_INVENTORY.md`).
- [x] Shared components + formatters + registry + search (+ unit tests).
- [x] Main Settings page (Design 1) + tests/goldens.
- [x] Prayer & Adhan page (Design A) + reschedule test.
- [x] Widgets / Notifications / Locks rows / Font page.
- [x] About page (Design 1) + goldens.
- [x] Report (`docs/SETTINGS_REPORT.md`); zero orphaned settings files.
- [x] **Functional audit** (`settings_functional_audit_test.dart`): every main-page
      control tapped and its persisted write asserted (theme chip/mode, hijri +
      worship steppers, multiplier, tasbih slider, backup dialog, tool-lock
      switches, 11 nav rows wired + 3 pushed through a GoRouter) — 11/11 green.
- [x] **Account page (`/settings/account`)** on the kit: `SettingsAppBar`, palette
      `_card`, nav `ListTile`s → `SettingRow` (destructive row kept red via the
      new `SettingRow.titleColor`); all Firebase/Drive flows untouched and the
      12 existing account tests still green.
- [x] **Upgrade suggestions** (`docs/SETTINGS_REPORT.md` §13): palette-owned
      theme-chip swatches (`AppPalettes.previewSwatches`), chip `Semantics`
      (button/selected/label), `alertVolumeProvider` (plain `NotifierProvider`,
      no codegen) replacing the slider's local `setState`, and the new
      **«بازنشانی»** reset row — `Settings.resetPreferences()` keeps
      `onboardingCompleted` + `isPremium` (the repo's `resetSettings()` clears
      both, which is why it was never wired), registry `main.reset`, guarded by
      a notifier test and an audit case that drives the dialog (cancel/confirm).
- [x] Two residual `info` lints cleared: `more_screen.dart` redundant
      `crossAxisSpacing: 0`, more-screen test `const BoxConstraints`.
- [x] Off-branch pomodoro flake hardened: the exact `00:59` assertion now
      accepts the `00:5x` band (`PomodoroScreen._tick` reconciles with the real
      wall clock, so a loaded machine prints `00:58`).
- [x] **Suggestion #3 — deep-link scroll + flash (landed).** New
      `settings_flash.dart`: `SettingsFlashSection` + the `SettingsHighlight`
      mixin (owns the page's `ScrollController`). On landing it runs a
      progressive `jumpTo` sweep (`_materializeAnchor`, for long lazy lists whose
      below-fold children do not exist yet), then `Scrollable.ensureVisible` and
      a 900 ms flash. Wired into all five destinations (main, prayer, notif,
      widgets, about); guarded by
      `settings_highlight_test.dart` (330 lines) + re-recorded prayer goldens.
      The earlier `cacheExtent` idea was abandoned — see the report.
- [x] **Suggestion #6 — settings-only JSON export/import (landed).** Section
      retitled «بازنشانی و انتقال» with two rows (export → share a
      `tawheed_settings.json`; import → pick a `.json`, validate, confirm,
      apply). Pure versioned codec in
      `services/settings_transfer_service.dart` reusing `AppSettingsDto`;
      `SettingsNotifier.importPreferences` keeps the device's own
      `onboardingCompleted`/`isPremium`. Registry `main.export_settings` /
      `main.import_settings`; codec/notifier/audit guards + 3 main-page goldens.
- [x] **Suggestion #7 — About «تغییرات نسخه‌ها» (landed).** Bundled
      `assets/changelog.md` (byte copy of `CHANGELOG.md`, declared in pubspec)
      shown in a scrollable dialog via a tiny line-based markdown pass; read
      only on tap. `about_changelog_test.dart` + 4 About goldens re-recorded.
- [x] **Suggestion #9 — dead kit arc + unused `flutter_svg` (landed).**
      `arc.dart` (`ArcPainter`/`ArcCountdown`) deleted with its `components.dart`
      export and test coverage; `flutter_svg` + its three `vector_graphics*`
      lock transitives removed from `pubspec.yaml`/`pubspec.lock` (no dart
      usage, no `.svg` asset). Two stale `ArcPainter` comments reworded. 51
      design-system tests green.

## Remaining (needs the user)

- [ ] Account/cloud **device pass**: real Google sign-in + Drive restore on a
      phone (no device is attached; the flows are unit-proven only).
- [ ] On-device pass of the whole settings section, especially the About header
      (flat logo + gold tagline on both surfaces), the per-prayer card at 320 dp,
      the new «بازنشانی و انتقال»
      transfer rows (real share sheet + file picker) and the changelog dialog.
- [x] Merge the branch into `release/1.8.0` — landed as the merge **`ac538a9`**
      (parents `a69f875` + `8a6f8bf`). Conflicts resolved by keeping the release
      side where it superseded this branch (`tasbih_counter_widget.dart`,
      `evaluation_stats_widget.dart`, the widgets palette page) and hand-merging
      `section_header.dart` + `settings_screen.dart`; the settings-search
      highlight was re-hosted on the release widgets page.
- [ ] On-device pass of the widgets palette page (the release line's) and the
      re-hosted search highlight.
- [x] **Post-tip follow-up (user verdict, branch `settings/about-flat-logo` off
      `8a6f8bf`, commit `c78341c`):** the About page's gradient box around the
      logo is removed — the header sits flat on the page, `_VersionChip` is
      replaced by the kit `SettingsValueChip`, the dead `SettingsTokens.aboutHero*`
      trio is deleted, and the four About goldens were re-recorded. See
      `docs/SETTINGS_REPORT.md` §6.

## Later fixes on `release/1.8.0` (2026-10-13, `461a1fc`)

- [x] **علوم اسلامی black background.** The science home and detail screens
      pushed each other with `Navigator.push`, which leaves the GoRouter branch
      and its `AmbientBackground` wrapper behind, so the transparent scaffold
      painted the bare window — the calendar converter's bug again. They now use
      `context.push(RouteNames.scienceDetailPath(id))` with a new path helper.
      Guard: `test/features/education/presentation/sciences_routing_guard_test.dart`.
- [x] **صدای اذان volume.** `azanVolume` had no UI anywhere. A «صدای اذان» slider
      was added to صداهای برنامه (`_SoundSettingsSection`), the settings registry
      now covers the key (its orphan note is gone), and
      `azan_playback_service.dart` was fixed so a custom adhan file honours the
      volume too (only the asset branch did). Guard: the
      `the adhan volume slider writes azanVolume` test in
      `settings_functional_audit_test.dart`.

Hand-off: `release/1.8.0` now carries the settings redesign (merge `ac538a9`).
This branch's code tip was `8a6f8bf` — the upgrade-suggestions pass (`9e1d83d`)
plus the approved follow-ups #3/#6/#7/#9 on top. See `docs/SETTINGS_REPORT.md`
§13 and the #3/#6/#7/#9 notes.

## Audit chain — Phase 0 done (2026-10-13, docs-only, no code changes)

User rulings recorded: parallel home WIP stays uncommitted (option الف, not
staged/touched); the five master-task spec conflicts resolve in favour of the
landed state (no back circle, 4-col More, Evaluation ring, no kit arc,
follow-along/Tawheed out of scope, مصحف حافظ stays); recent design work is
report-only; audit docs live in `docs/FINAL/`.

- Output: `docs/FINAL/00_BASELINE_AND_LOGS.md`.
- Measured on this tree: analyze 0/0/103 infos; strict gate 7/7; encoding
  guard green; full suite 3697 passed / 8 failed / 9 skipped — all 8 under
  `test/features/home/**` from the foreign WIP (clean-tip proof: 3696/9/0,
  home 106/106).
- NOT measured (no Android device/emulator): logcat, cold start, first frame,
  frame times, memory, battery, Doze/reboot behaviour — recorded as such.
- Config read: 1.8.0+10015, minSdk 24 (Android 7.0), compileSdk 36,
  arm64-v8a + armeabi-v7a, CI (`ci.yml`) with format/build_runner/analyze/
  coverage/strict-gate/asset-diet jobs; last fat APK ≈47.3 MB, none from the
  current tip.
- Next: Phase 1 log audit (`01_LOG_AUDIT.md`).

## Audit chain — Phase 1 done (2026-10-13, log demotions only)

- Output: `docs/FINAL/01_LOG_AUDIT.md`. Categories A–F scanned: no stray
  prints, no recurring error floods, no lifecycle chatter, no per-tick logging
  in any of the 14 `Timer.periodic` sites, no logging in hot `build()`s.
- Fixed L1: 3× `mushaf_nav` `info` → `debug` in `quran_mushaf_view.dart`
  (a settle/jump fires per page turn; the page itself stays persisted via
  `quran_last_page`). Protected-file edit, log-level only, flagged in the doc.
- Fixed L2: FCM token preview `info` → `debug` in `firebase_push_service.dart`
  (credential fragment must not reach the shareable log file). User email in
  `google_auth_service.dart` reviewed: `_scrub` redacts it, left as-is.
- Deferred L3: ~100× bare `'operation failed'` without `$e` across ~40 files
  (quality, not volume; several sites in protected files) → goes to the
  phased plan as a P3 batch, not mass-edited here.
- Verified: analyze clean on both files; quran mushaf widget/policy/prefs
  45/45 pass; no test asserts on the changed log text.

## Quran reader: the page carries its own identity (2026-10-13)

Full write-up: **docs/QURAN_REDESIGN_REPORT.md** §8. Branch
`quran/page-chrome-identity` off `a69f875`; user-authorized slice of the
protected mushaf bundle — page chrome only, no glyph, verse, order, page
boundary or asset touched.

Request: «در بخش مصحف اسم سوره و جزء حتی در صورت صفحه غیر کامل هم بالا باشد و
پایین ایکون صفحه راست و چپ حذف کن اما شماره صفحه خیلی رفته سمت چپ یک مقدار
کمی بیاد راست که موازی آیات باشه». Clarified by question: «صفحه غیر کامل» = a
**continuation page**, and «هر دو حالت» = **both chrome states**.

- [x] `quran_page_chrome.dart`: the surah (top-right) and juz (top-left) corner
      labels are now **always** drawn, and sit at `top: headerBand + 8` — the
      page's own `_pageTopInset`, so with the header up they land in the 28 dp
      band *below* it instead of hiding behind it. The call site stopped
      passing `null` for the chrome-up case; a continuation page needs no
      special case because `_surahNameFor(page)` answers for every page.
- [x] `_PageSideIcon` (the «صفحهٔ راست / صفحهٔ چپ» book glyph and its
      `Semantics`) is **deleted** — do not restore it.
- [x] The page number moved right to `_PageChrome._numberLeft = 34`, clear of
      the 26 dp gutter shadow that the deleted glyph used to sit in; deleting
      the glyph alone would have dropped it to `left: 8`, which is the
      «خیلی رفته سمت چپ» the reader reported. Its `bottom` now tracks
      `_pageBottomInset` so a visible mini player cannot cover it. Fullscreen
      only, as before (the header prints «صفحه N» while it is up).
- [x] Pager-geometry invariant kept: everything lives in the bands the page
      already reserves, so a resize cannot re-map the scroll offset mid-swipe.
- [x] Tests: `the page identity is printed inside the page bands` measures both
      states structurally against `Qcf4PageViewer` (labels clear the header and
      stay above the glyphs) and pins `number.left > pager.left + 26`;
      `the page-side right/left glyph is gone from the reader` asserts both
      semantics labels absent; the 320 dp header test now counts **two**
      «سورة …» and pins that one is the page's own label.
- [x] Verification: quran scope **310/310**, full suite `--exclude-tags network`
      **3589 passed / 9 skipped / 0 failed**, `flutter analyze lib test`
      0 errors / 0 warnings, strict gate 7/7, encoding guard green.
- [x] **No Android device is attached** — widget-test proof only. The reading
      of «موازی آیات» as "out of the spine shadow, into the text column" is a
      judgement the reader's eye must confirm.

## Evaluation hero: the verdict moved under the dial (2026-10-13, `30a8265`)

- [x] User asked for «نیاز به تلاش بیشتر» to sit **below the ring, at the left**.
      Measured first (widget test under `Directionality.rtl`): it was already the
      top-LEFT of the hero's first row, so the request was about the row, not the
      corner — confirmed with the user before editing.
- [x] `_ScoreHero` is now label → `RingView` → chip. The label keeps the top line
      alone; the chip rides under the dial in `Align(centerLeft)` (visual left,
      not `centerStart` — the corner itself was asked for). The Row-level
      `Flexible` cap went with the Row; alone on its line the card width bounds
      the chip, which is what its `FittedBox(scaleDown)` needs at 320 dp / 1.3.
- [x] Tests + golden: geometry asserted (chip below the ring, text 22 dp in from
      the card edge = 12 shell + 10 chip padding), `evaluation_score_hero.png`
      re-recorded. Worship scope **63/63**; analyze 0 errors / 0 warnings
      (103 pre-existing info lints); strict gate 7/7; encoding guard green.
- [x] **No Android device is attached** — golden + widget-test proof only.

## Audit chain — Phases 2-6 done (2026-10-13, black-bg inner pages + qibla Opacity)

- Docs: `docs/FINAL/02_TABS_AUDIT.md` (BackdropFilter zero, one static
  `Opacity(`, ~40 legacy blur>8 shadows recorded-not-changed, RepaintBoundary
  present, timers disposed, lists lazy), `03_ARCHITECTURE_AUDIT.md`
  (uniform Riverpod, no P0/P1), `04_INFRASTRUCTURE_AUDIT.md` (storage/backup/
  alarms/channels hardened, endpoint map, PIN salted-hash in Keystore,
  S1: no `--obfuscate` on store builds), `05_PHASED_FIX_PLAN.md` (findings
  table + packages A–F, deferrals listed).
- Fixed F-T2 (P1, same black-bg class as sciences): 3 share screens self-wrap
  `AmbientBackground` (8741379; diff -w 7+/1- each); hadith 4 inner screens
  wrapped at push sites (b0d845a); reading stats wrapped at push site
  (da265e1). DuaDetail/AdhkarCategory/BookReader pinned opaque by guard test.
- Fixed F-T1 (P3): qibla moment rows return directly unless faded (8cb10d4).
- Guard: `test/core/navigation/pushed_screens_ambient_guard_test.dart` 9/9.
- Affected areas re-run: guard + dua-share + hadith + books + dua-from-quran
  + prayer = 442/442. Final verdict on this tree: analyze 0/0, strict gate
  7/7, full suite `--exclude-tags network` = **3715 passed / 0 failed**.

## Audit chain — device pass, partial (2026-10-13, POCO/Android 16, `c177472`)

- Phone connected mid-pass; installed clean-tip `33703d3` via
  `flutter run --release` (arm64-only 30.8 MB, Impeller/Vulkan).
  Worktree kept at `%TEMP%/opencode/ondevice-verify`.
- Verified: diagnostics screen renders live OEM data (battery-opt + GPS
  correctly flagged); scheduler logged 58 alerts; old store build's
  background crash + Locale failure confirmed **out of current code**
  (`intl` usage in `lib/` is zero).
- Fixed D-VAULT (P1): `PersonalInfoScreen.dispose` threw on `ref.read` and
  skipped `lock()` — vault silently stayed open. Notifier now captured in
  `initState`; guard test green; personal_info 59/59. Protected-file edit,
  flagged for veto.
- Observed (no fix): SecureStorage Keystore fallback on this install history;
  plugin multi-engine log noise (benign).
- NOT done (phone disconnected): cold start, black-bg screenshots, widget
  tap, backup round trip, TalkBack — finger checklist in
  `docs/FINAL/07_DEVICE_PASS.md`. Samsung A13-class pass still open.

## Evaluation hero: the dial's counter reads on two lines (2026-10-13, `e5b0bd9`)

- [x] User request (Persian): «شمارنده در دایره در دو سطر قرار بده هدف پایین
      باشد». The `Text.rich('35 / 150')` inside `RingView` became a `Column` —
      score above (36 sp, w800, `heroGold`), target below (`/ 150`, 14 sp,
      w600, `heroGold` at 55 %) — the reading the detail grid's rings already
      use, so hero and grid no longer disagree.
- [x] Kept inside the stroke: the box is capped at `_ringSize - _stroke*2 - 14`
      (102 dp) under `FittedBox(scaleDown)`, and `Directionality(ltr)` stops
      the slash from mirroring in the RTL page.
- [x] Tests + golden: `scoreRect`/`targetRect` measured — target's top at or
      below the score's bottom, centers within 1 dp, both lines inside the ring
      rect; the 320 dp / 1.3 fit assertion still holds (`< 116` dp).
      `evaluation_score_hero.png` re-recorded. Worship scope **63/63**; strict
      gate 7/7; encoding guard + changelog tests green.
- [x] **No Android device is attached** — golden + widget-test proof only.

## Tasbih widget: taps count again + the dial reads its states (2026-10-13, `33df778`)

- [x] Root cause of «تیک که میزنم روی ویجت تسبیح کار نمیکند و هیچی ثبت
      نمیشود»: the audit-5.1 sender guard compares `intent.package` with
      `context.packageName`, but an explicit `Intent(context, cls)` sets the
      **component** and leaves the package null — so every self-tap was logged as
      «dropped foreign tasbih broadcast from: null» and nothing (count, daily
      total, pending event) was ever written. All four actions now go through
      `tapIntent()`, which calls `setPackage(context.packageName)`; the guard
      stays (it is the anti-tamper check, not the bug).
- [x] Guard: `test/android/tasbih_widget_tap_broadcast_test.dart` source-scans
      both Kotlin files — `setPackage` present, every `setOnClickPendingIntent`
      wired through `tapPending(context, appWidgetId, …)`, no re-inlined
      `Intent(context, receiverClass)`, and the receiver guard still intact.
- [x] Beautification, all inside the palette contract: the computed
      `countTextSize`/`targetTextSize` are finally applied after `applyCenter`
      (the number used to stay 40 sp at any widget size), `ringBitmap` takes
      `countColor` so arc + number + badge turn green together at the target, the
      armed-reset button wears a red wash while «تأیید؟» is live, the confirm
      state shrinks the figure and its caption, `includeFontPadding=false` on the
      four texts, and `providePartialViews` re-stamps the sizes so an animation
      frame cannot inherit the confirm-state face.
- [x] Preview fidelity: `tasbih_widget_preview.dart` now mirrors the native
      render (TL→BR gradient, accent on arc + number, the «ذکر 2 از 5» caption,
      stroke = 5.5 % of the ring, the `WidgetShadowText` halo as a `Shadow`,
      Latin digits) and `widget_settings_screen.dart` feeds it
      `bgEndColor`/`accentColor`/`light`/`zikrIndex`/`zikrCount`.
- [x] Proof: `:app:compileDebugKotlin` + the widget JVM tests BUILD SUCCESSFUL;
      `test/android` + preview + settings screen 18 green; `test/features/adhkar`
      + encoding guard 113 green; analyze 0 errors / 0 warnings; strict gate 7/7.
- [x] **Prayer widget reviewed read-only and reported, not changed** — six
      findings (API<31 skin compositing, always-true `time.contains(":")`,
      `use12Hour` ignored in the rows, clamped iqamah mislabel, untinted status
      hint, dead/hardcoded colours) awaiting the user's numbered approval. Same
      for the drain-ack path that loses a delta when a dhikr matches no app row,
      and `MainActivity.incrementTasbih` clamping at the target without appending
      an event. **No device attached**: the tap fix is proven by source +
      compile, so the on-device pass needs a build carrying `33df778` —
      `1.8.0-e00ac2a` still ships the dead taps.

## Settings were locked: two never-migrated columns (2026-10-13, schema 44)

- [x] User report (Persian): «ظاهر برنامه» and «تم برنامه» are locked, the page
      sits on «روشن» + «طلایی»; and «اندازهٔ فونت» / «صدای اذان» and the rest are
      locked too — «همه چیز را بررسی کن و اصلاح کن».
- [x] **Root cause is the database, not the UI.** `friday_prayer_time` (`55cc89e`,
      which never bumped `currentSchemaVersion`, so `onUpgrade` never ran for it)
      and `quran_theme_mode` (`4f0cd47`, which added no ALTER step) entered the
      settings table *definition* with no migration. `onCreate` builds from the
      current definition, so a fresh install is fine and every test stays green —
      only an install whose `app.sqlite` predates those commits lacks both columns.
- [x] **Why it reads as "locked":** Drift names every column in its generated
      SELECT and UPDATE, so both the settings *read* and *write* threw
      `no such column: friday_prayer_time`. `SettingsNotifier._save` catches and
      reverts its own state (the snap-back) and `_saveWith`'s `await future`
      rethrows on the failed `build()`, while `main.dart` falls back to
      `const AppSettings()` — the whole page on factory defaults, no control
      answering.
- [x] Fix: schema **43 → 44** with a `PRAGMA table_info`-guarded pair of
      `ALTER TABLE … ADD COLUMN` (the v41 goal-column recipe; a duplicate-column
      error would abort the migration and trip the snapshot-restore path).
      `friday_prayer_time` is nullable so needs no DEFAULT; `quran_theme_mode` is
      NOT NULL and gets `DEFAULT 'light'`, the entity's own default. A database
      with no settings table at all gets `m.createTable`.
- [x] **Whole-schema scan** so the class does not recur: every declared column of
      all 19 tables diffed against the migration steps' coverage. These two were
      the only uncovered ones (GoalTable's six are covered by the v41 PRAGMA loop).
- [x] Proof: `test/core/database/app_database_schema_v44_test.dart` (4 tests)
      builds a v43-shaped database with a real settings row, `DROP`s both columns,
      then asserts the upgrade adds them and that dark / gold / 21:00 / 0.4 /
      `followApp` / Friday 12:00 all **write and read back** through the real
      `SettingsRepositoryImpl` — written red first (it failed with the production
      exception), green after the fix. `test/core/database` +
      `test/features/settings/data` + encoding guard = **47/47**; strict gate 7/7;
      `flutter analyze lib test` 0 errors / 0 warnings.
- [x] **No device attached and no build requested** — the fix is proven by
      migration test + source. It only helps a real phone through a *new* APK:
      `1.8.0-e00ac2a` predates this and the settings redesign, and the user's
      «فعلا بیلد نزن» still stands, so the build is the user's call.
- [x] Not mine, untouched: the parallel session's live WIP in
      `settings_components.dart`, `prayer_settings_screen.dart`,
      `prayer_calc_widgets.dart`, `settings_notifier.dart` and
      `settings_registry.dart` (its `setFridayPrayerTime` → `_saveWith` change is
      a different, correct hardening of the same notifier).

## All sessions collected and committed (2026-10-13, `53b6158` + `bd14e2d`)

- [x] User instruction: «همه جلسات را ببین تکمیل شدند اگر اوکی بود کامیت کن» — so the
      parallel session's still-uncommitted work was verified and landed rather than
      left sitting in the shared tree.
- [x] What was open: the evaluation hero's verdict chip (`Alignment.centerLeft` →
      `Align`'s own default `center`, the user having asked for the middle and not the
      left corner) with its retargeted guard (`chipRect.center.dx ≈ ring.center.dx`)
      and its re-recorded `evaluation_score_hero.png`, plus my schema-44 CHANGELOG
      section that an intervening commit of theirs had dropped.
- [x] Completeness checked before staging, not assumed: the `Align` really lost its
      explicit argument (so no `avoid_redundant_argument_values`), the doc comment
      above `_ScoreHero` now says "centred", and `AGENTS.md` already carried their
      superseding "the verdict chip is centred" section — that line reached the repo in
      `53b6158`, whose message discloses the one foreign doc line whole-file staging
      swept in (nothing of theirs was lost or altered).
- [x] Proof at `bd14e2d`: `test/features/worship` **63/63**, `test/core/database` +
      `test/features/settings/data` **45/45**, encoding guard green, strict gate 7/7,
      `flutter analyze` on the changed scope = one pre-existing info lint
      (`IconTile(size:)` default at line 1740, outside this arc).
- [x] The full suite then ran: **3734 passed / 4 failed**, and all four were the
      About page's own goldens — `87746ae` rewrote 301 lines of `about_screen.dart`
      (logo 117, wordmark gone, the four-tile flat feature grid) and never re-recorded
      its baselines, which last moved at `c78341c`. They failed on *size*, not on an
      exception. Verified before re-pinning: the 13 functional About tests are green,
      including the 320 dp / 1.3 no-overflow matrix and «all sections render when
      scrolled», so the page is shorter by design, not clipped. Re-recorded as
      `114830e` (day/night 2171 → 1710, 320 dp 2007 → 1712, scale 1.3 2474 → 2057).
- [x] Both CHANGELOG sections (mine + theirs) reached the repo in their
      `04deaa8 docs(changelog)` — this file is the only docs still carrying my log.
- [x] Deliberately NOT committed: the untracked `cache.db`, `.zcodeignore`, `desine/`
      and `doc/design/` — foreign, not authored here, and recorded as the other
      session's territory; and their **live** in-flight edits to
      `notification_settings_screen.dart` + `settings_registry.dart`, which were
      already dirty again while this pass ran.
- [x] **No Android device attached and no build run** («فعلا بیلد نزن» still stands),
      so both landed items still need a fresh APK before any on-device verdict — the
      newest recorded set (`1.8.0-e00ac2a`) predates the schema-44 settings repair.
## PART 2 — wave 0: the release gate is honest again (`final/map`, 2026-10-12)

Plan: `docs/FINAL/03_PART2_MIGRATION_PLAN.md` §0. Numbers: `docs/FINAL/05_BASELINE.md` §6b.

- [x] **0.1 type scale** — the one off-scale literal (`tasbih_counter_widget.dart`
      `_MiniStatBox` 9.5) → `AppTheme.scaledFontSize(context, 10)`;
      `type_scale_guard_test` green.
- [x] **0.2 home harness** — the harness froze only `second`, so the hero printed
      the wall-clock **minute** and every card derived `now` from it. `_frozenNow`
      (2026-10-09 12:00:40, the fixture's own date) now drives BOTH notifiers, the
      reminders card is pinned with `nowOverride`, and `_initPrefs` selects the
      daily dua from the pinned instant (the shared ticker) instead of
      `DateTime.now()`.
- [x] **F-39, found while making the suite honest** — `SectionHeader` shared its
      row between `Flexible(flex: 1)` and `Spacer(flex: 100)`, and `RenderFlex`
      splits free space by flex in one pass: the title rendered **1.3–2.1 px
      wide** (invisible) on every card that has a trailing (the home prayer card,
      «خلاصه امروز», «تایم‌لاین اعمال», More/calendar/kit-sheet headers) and the
      long «اشراق و صبح» count label overflowed 6.3 px at 320dp × 1.3. It is now
      one min-size group of proportional flexibles (title 3 : count 2), one line
      + ellipsis, trailing intrinsic and pinned with `spaceBetween`.
- [x] **36 goldens re-pinned deliberately**, each diff measured before re-pinning:
      11 home (minute/countdown + the now-visible titles + the Friday reminders
      set) and 25 More/calendar/kit-sheet (the titles coming back); diffs 22–6 880
      px, confined to header/title bands.
- [x] **0.3** — every `test/**/failures/` dir deleted; `.gitignore:146` already
      covers regeneration.
- [x] **0.4** — new `tools/design_consistency.py`: reproduces the coverage marker
      table and ratchets it (budgets only go down). Screens scope today: 262 raw
      colours / 309 raw sizes (matches `00` §0's ≈250/≈300); all-files scope 714 /
      598, plus 45 heavy shadows and 37 `TextDirection.ltr`.
- [x] **0.5** — the `network` tag: a yaml-level default exclusion is impossible
      (package:test **unions** `exclude_tags`, so it could never be re-enabled),
      therefore the deterministic gate is `flutter test --exclude-tags network`
      (verified to exclude exactly the two tripwires) and both live tests retry
      once on *transport* failures with 45 s ceilings.
- [x] **0.6** — nothing to fix: `flutter analyze` = 0 errors / 0 warnings / 88 info.
- [x] **Exit gate 0** — `flutter analyze` 0/0 · `quality_check.py --strict` 7/7 at
      zero · `design_consistency.py` exit 0 · `flutter test --exclude-tags network`
      = **3505 passed / 9 skipped / 0 failed**.
- [!] **External, not code (V-7):** the audio-library host
      `s3.ir-thr-at1.arvanstorage.ir` answers **HTTP 504** for both the bucket root
      and the production manifest `/t.audio/index.json`, so `audio_library_live_host_test` is red for that
      reason alone. Re-check before release.

## PART 2 — wave 1, slice 1: the cream share family (2026-10-12)

Plan: `docs/FINAL/03_PART2_MIGRATION_PLAN.md` §1. The six share cards — prayer
times, adhkar, duas, ayah, tafsir, dua-from-Quran — are the same exported cream
card, and each one had hand-copied its palette.

- [x] **One palette** (`00b18bc`) — `ShareCardPalette` (kit barrel) now owns the
      cream paper, its dark twin, the hairline/divider, the chips, the teal
      accent, the light-mode ink set and the «ذکر» box greens/golds. Six screens
      dropped from 25/13/13/10/10/10 = **81 raw colours to 0**, and every removed
      value was verified byte-identical to its palette entry, so the exported
      PNGs do not change. Ratchet: `raw_color` 714 → 653.
- [x] **Sizes scale with the reader** (`c57e51f`) — 62 raw `fontSize:` literals
      now go through `AppTheme.scaledFontSize(context, n)`; all six files are at
      **0 raw sizes**. Every literal was already on the shared scale and snaps
      back to the same step at scale 1.0, so only a raised «اندازه فونت» changes
      anything (which is the point). The tafsir `_verseBlocks` helper needed a
      `BuildContext` and now takes one. Ratchet: `raw_size` 598 → 561.
- [x] **Verified**: `flutter analyze lib` 0 errors / 0 warnings; share tests +
      `type_scale_guard_test` green; `quality_check.py --strict` 7/7 zero;
      `flutter test --exclude-tags network` green (the wave gate).
- [ ] **Still open in wave 1**: `yaqeen_lesson_screen` (17 colours / 21 sizes),
      `book_reader_screen` (15/4), the ketabkhaneh library (12/8) and
      `reading_stats_screen` (0/3) — the reader/stat recipes (`SimplePage`,
      `ListCard`, `ReportGauge`) are what they will be built from.
- [!] **Not verified on a device**: the share *image* is the artifact the user
      sends; the test binding renders tofu, so the export must still be looked at
      once on the phone (`اشتراک تصویر` from اوقات شرعی). No device is attached.

## PART 2 — wave 1 close + the two cross-cutting sweeps (2026-10-13)

Committed as `83b06aa` (wave 1) and the sweep commit that follows it. The wave-1
plan named four leftover screens; all four are now at 0 raw colours / 0 raw sizes,
which closes wave 1 (§1 of `03_PART2_MIGRATION_PLAN.md`).

- [x] **Two kit helpers** — `dsOnAccent(context)` and `dsShadow(context)` in the kit
      barrel. Thirty screens had hand-typed the same two ternaries
      (`isDark ? const Color(0xFF1A1410) : Colors.white` — 39 of the app's raw
      colours — and `isDark ? Colors.black : const Color(0xFF3E2723)`, 16 more).
- [x] **`BookPalette`** — the reader's two pages (day linen / neutral night), its
      six highlighter swatches and the library's category swatches. The reader
      switches pages by hand (`reader_night_mode`), so its surfaces cannot be
      theme colours; the conventions section of `tools/design_consistency.py`
      now allowlists one `presentation/*_palette.dart` per feature, and the four
      legacy colour tables (worship, dongi, calendar, notes) joined it under
      their older names.
- [x] **Status family** — `AppTheme.{success,warning,error}` + `*Bg` replace the
      legacy Material accents the screens re-typed (2E7D32 in 18 files, C62828 in
      11, E65100 in 9, 43A047 in 5, C9A94E in 8 → `AppTheme.goldPale`).
      **This is a visible change**: the muted palette family now draws those
      states, exactly as `02_DESIGN_CONTRACT.md` §1 L2 asks. `worship_colors`
      keeps its own content-matched iftar orange — there the hue is content, not
      status — and is allowlisted as a colour source.
- [x] **Font scale now applies everywhere** — 472 raw `fontSize:` literals in 79
      files go through `AppTheme.scaledFontSize(context, n)` (all of them already
      sat on the shared 19-step scale, so scale 1.0 is pixel-identical). Three
      helper groups had no `BuildContext` and now take one (the dongi + inheritance
      share-card row builders, the ketabkhaneh search field).
- [x] **Fixed-layout surfaces are named, not silently exempt** — a PDF is a
      document and a `CustomPainter` draws on a fixed canvas: neither has a
      `BuildContext`, and a PDF that reflows with the phone's text scale would be
      a bug. The tool's new `FIXED_LAYOUT` list holds exactly those 7 files (5 PDF
      generators + 2 painters, 59 sizes) and reports them as an informational
      counter, so a new raw size anywhere else still fails the run.
- [x] **5 goldens re-pinned, each diff measured first** — kit sheet ×4 (dawn/day/
      sunset/night): **541 px, bbox 27×27** — one 26 px circle, the `CheckCircle`
      done fill, identical in every phase because that fill ignores the palette
      (before `#308134`, after `#588657`); `CheckCircle`'s second gradient stop is
      now derived (`mix(AppTheme.success, Colors.black, .22)`) instead of a second
      hard-coded Material green. Home full page ×1 (day 360dp **text scale 1.3**):
      14 % of pixels, confined to the content band — the migrated sizes grow at
      1.3, which is the point; the same golden at scale 1.0 is untouched, which is
      the proof that nothing moved at default scale.
- [x] **Ratchet**: `raw_color` 653 → **423** (−230), `raw_size` 561 → **0**
      (+59 documented fixed-layout), screens scope 201 → 110 colours and 272 → 2
      sizes. `flutter analyze` 0 errors / 0 warnings / **8 info** (wave-0 baseline
      was 10). `dart fix --code=prefer_const_constructors` put back the 35 `const`
      the sweep had to drop.
- [ ] **Still open at that point** (423 colours): the per-feature palettes of
      waves 2–5 — inheritance's purple/amber family (~100, closed below), moon,
      zakat, period, adhkar, knowledge/media, the long tail — plus 45 heavy
      `BoxShadow`s, 37
      `TextDirection.ltr` and the single `Opacity(` at `qibla_screen.dart:1620`.

## PART 2 — wave 3, slice 1: the inheritance tool (2026-10-13)

`tools/inheritance/**` went from **111 `Color(0x…)` literals in 13 files to 0**,
against `InheritancePalette`.

- [x] **One palette** (`inheritance_palette.dart`) — the purple family
      (`0xFF6A1B9A` was written out 21 times across 11 files, `0xFF9C4DCC` 10×),
      the two-stop hero band (light + dark), the amber highlight/note pair, the
      five share-type inks, the share card's grey paper and the
      `Madhab → colour` map the comparison tab declared **twice** in one file.
      `accent` is `TopicHues.inheritance`, so the tool's identity hue and the
      «بیشتر» tile cannot drift apart.
- [x] **The pie series is one list, in slice order** — the donut and its legend
      each re-declared the same 14 colours by hand. `series` now holds them in
      the exact original order (the first draft of this file had silently
      replaced the three `AppTheme.{success,warning,error}` entries with
      purple/teal and dropped the list to 11 — that would have re-painted the
      donut and the legend with nothing failing loudly). Guarded by a comment on
      the list and by the feature's goldens.
- [x] **Every replacement proved value-identical, not eyeballed** — a checker
      resolved each `InheritancePalette.<name>` back to its hex and compared it
      with the literal the diff removed: **67 hunks, 121 colour slots, 0
      mismatches**, and the two `series` lists parse to exactly the palette's 14
      values. That is why no golden moved: the feature's **724 tests pass
      unchanged** (domain + the share-card/pie goldens).
- [x] **Ratchet**: `raw_color` 423 → **300** (−123: −111 inheritance, −12 splash
      — the allowlist had been naming `splash/presentation/screens/splash_style.dart`,
      a path that has never existed, so those literals were charged to the
      ratchet instead of the palette column). `raw_size` stays **0**. Screens
      scope 110 colours / 2 sizes. `flutter analyze lib/features/tools/inheritance`
      = no issues.
- [!] **Not yet verified on a device**: the two exported artifacts (the share
      card image and the donut) are proved identical at the *source* level — the
      goldens render tofu, so the PNG a user sends was not looked at on a phone.
      No device is attached.

## The share surfaces are locked to zero (2026-10-13)

The extraction kept being undone card by card, so it now has a guard:
`test/core/design_system/share_surfaces_source_lock_test.dart`.

- [x] **Every share surface must paint from a palette only** — the test scans
      the source of all ten `*_share_screen.dart` / `*_share_card.dart` files for
      `Color(0x…` and for a literal right after `fontSize:` (the same two
      patterns `design_consistency.py` ratchets) and requires both to be **0**,
      with the fix named in the failure message. It is source-level on purpose:
      a hard-coded hex renders fine and no golden notices it — a hex that still
      matches its palette entry produces a *pixel-identical* card until someone
      edits the palette.
- [x] **The list itself is asserted** — the files on disk must equal the ten
      pinned paths, so adding a share card fails the test until it joins the
      lock (and gets a palette). Screens that merely *offer* a share button
      (`qibla`, `ruqyah`, `khatm_stats`, `worship_notes`, …) are deliberately
      out: they are ordinary screens held by the global ratchet.
- [x] **Migrated the last two cards to make the lock honest** — there was no
      point pinning a rule two files broke.
      `hadeeth_share_card.dart`: 13 literals, of which **12 were byte-identical
      to `ShareCardPalette`** (its cream paper, border, divider, chips, ink) — it
      had simply never joined the family the wave-1 extraction created. The
      grade→ink mapping moved out of the widget into `HadeethPalette.grade`
      (`hadeeth_enc`'s new colour source), the app's amber «حسن» chip included.
      `dangi_settlement_share_card.dart`: 5 literals → `DangiSettlementPalette`
      in the dongi colour source; `_green` became `const`, which put back one
      `const BoxDecoration`.
- [x] **The lock was proved to bite, not assumed** — an injected
      `static const Color _probe = Color(0xFF123456);` failed with
      `hadeeth_share_card.dart:51`, an injected `TextStyle(fontSize: 13)` failed
      with its own message, and a throwaway `zzz_share_card.dart` failed the
      list assertion; all three probes were removed and the test is green again.
      Plus 4 assertions on `HadeethPalette.grade` (both spellings of صحيح, حسن,
      and that an unknown grade does not claim حسن's amber).
- [x] **Ratchet**: `raw_color` 300 → **282** (−13 hadith, −5 dongi; +6 into the
      two new palette sources). `raw_size` stays **0**, screens scope unchanged
      at 110 / 2. `flutter analyze` clean for `hadeeth_enc`, `dongi`,
      `inheritance` and the new test; 870 feature tests pass.

## The design wave landed: `final/map` merged into `release/1.8.0` (2026-10-13, `15f4cac`)

- [x] **Merged in an isolated worktree, not in the shared tree** — the branch forked
      at `dccdcfd` and the release line had moved ~110 commits past it, so
      `%TEMP%/opencode/merge-final-map` (branch `merge/final-map`) took
      `git merge --no-ff final/map` first: 36 conflicted files (15 source/test,
      20 goldens, `PROGRESS.md`), resolved by the policy below, then a zero-conflict
      `git merge release/1.8.0` to catch the two commits the parallel session landed
      meanwhile (`e306b55`, `84a4096`), then `git merge --ff-only` in the main tree.
- [x] **Conflict policy — the release line's newer, user-decided behaviour wins;
      their palette/typography unification is kept wherever it does not collide.**
      `section_header.dart` keeps the `Expanded(FittedBox(scaleDown))` title group
      (not `Flexible(3)/Flexible(2)`) plus the description row;
      `tasbih_counter_widget.dart` keeps the amber+pill recipe and the single-source
      `countStyle`; `tasbih_widget_preview.dart` keeps `countSize` (mirror of the
      native dial); `hero_card.dart` takes `scaledFontSize(context, 16)` at the
      release's enlarged ring; `quran_bookmarks_screen.dart` keeps the provider-driven
      list; the one-row مناسخات entry and the kit-unified prayer settings stay; the
      home harness keeps freezing `second` **and** `minute`.
- [x] **The three share screens took `ShareCardPalette` wholesale and then had the
      release's `AmbientBackground` self-wrap re-applied on top** (their version
      predates the black-page fix), formatted per-file — no global `dart format`.
- [x] **20 drifted baselines were measured, then re-recorded** (`15f4cac`): 4 kit
      phase sheets (0.15 %), 15 More pages (0.01–0.56 %, palette + type), and
      `home_page_day_360_scale13` (12.89 %, because the cards' type now honours the
      reader's scale). Each was a pixel diff — no size mismatch, no exception, and
      the `no overflow — 320dp × 1.3` case green — before anything was re-pinned.
- [x] **Landed over the parallel session's 21-file WIP without touching it**: one
      incoming file (`azkar_tasbih_tab.dart`) was also dirty, so it was backed up,
      the ff ran, and their patch was re-applied with `-3`. The single conflicting
      hunk (their `SettingsSliderRow` vs a `fontSize` inside the `Row` they deleted)
      resolved to their side; the incoming scaling survived in every region they had
      not rewritten. The index was cleared with `git restore --staged`, never
      `git add`, so their work is still unstaged and byte-identical.
- [x] **The merge also closed the design ratchet** (`eb6ce18`): measured at the wave's
      fork, it reported growth from release-side commits it never saw. Three raw
      sizes in the release's tasbih pill recipe went through `scaledFontSize`
      (`raw_size` back to 0), the widget preview's `9 * scale` joined `FIXED_LAYOUT`
      (it mirrors the *native* dial, which never follows the phone's text scale),
      `raw_color` lowered 282 → 275, and `ltr` moved 37 → 38 — the only budget
      allowed to rise, because both sites are the sanctioned bidi isolation of a
      Latin-digit run inside Persian text. The reason is in the budget comment.
- [x] **Proof on the clean merged tree**: analyze 0 errors / 0 warnings (102 info
      lints), strict quality gate 7/7, encoding guard green,
      `design_consistency.py` OK, the six golden files 57/57, and
      `flutter test --exclude-tags network` = **3744 passed / 9 skipped / 0 failed**.
      Not built («فعلا بیلد نزن»), no device attached — the visual verdict of a
      type-scaling wave belongs to the user on an installed build.
- [!] **Foreign WIP note**: in the shared tree the parallel session's uncommitted
      `account_screen.dart` puts `ltr` at 41 > 38. Their queue, not a merge
      regression — the merged line measures OK.

## Prayer: the country decides the method — «خودکار» is the default (2026-10-13, `a76a0e4`)

- [x] **The outside-Iran verification is not a new feature** — it is a result: the
      engine already builds the wall clock from the place's real Olson zone plus the
      per-date UTC offset, so nothing in the compute path is Tehran/+3:30. Tehran is
      only ever a *default* (startup coords, model `timezone`, notification fallback).
      The prayer suite pins it: foreign zone ≠ Tehran, the 30-min Dubai dhuhr gap,
      DST, both solstices, and an independent NOAA reference solver.
- [x] **`auto` («خودکار — بر اساس کشور») is the new default** and the manual pick still
      wins. Country comes from the persisted city against the bundled
      `worldCities`/`iranProvinces`, in `prayer_method_by_country.dart`; unknown →
      MWL. **No new column, no migration, no codegen.**
- [x] **The four names in both tables (حلب، آستانه، هرات، احمدآباد) are broken by the
      picked position** (`manualLat/Lng`) — otherwise Iran's «احمدآباد» takes India's
      Karachi method. It is a tie-break only; a unique name ignores the position.
- [x] **Four methods appended, after `custom`** (the enum is int-indexed in Drift and
      name-indexed in JSON, so middle inserts corrupt stored rows): jafari, france,
      russia, gulfRegion. «کراچی (ایران، پاکستان)» → «کراچی (پاکستان)». Iran → MWL by
      the user's decision; Tehran/Jafari stay manual.
- [x] **All three auto call sites move together**: the repository's
      `_getCalculationParams`, `widgetCalcParamsFor` (the native widget recomputes
      alone, so it must resolve auto), and the details sheet's auto←method row.
- [x] **Proof**: prayer + settings + widget_calc_params **712 passed**; analyze 0/0 on
      the touched files; strict gate 7/7; encoding guard green; design-consistency
      growth is only the parallel session's `account_screen.dart`. Two settings goldens
      re-recorded (longer default label); 320/360/412dp × 1.0/1.3 no-overflow green.
- [!] **No device, not built** («فعلا بیلد نزن») — golden + widget-test proof, so the
      visual verdict of the longer label is the user's on a future build.

## Settings unification pass (2026-10-13, user request)

Full design + function review of every settings surface, unified on the
Home/More kit, duplicates removed. Landed as `9222a26` (prayer),
`84a4096` (notifications), `2758619` (account), `96353b5` (kit/shared).
- Prayer: Friday tiles + calc rows + angle sliders on kit; lat/lng refuses
  empty, folds Persian digits, commits on focus loss; _saveWith Friday fix;
  single-patch city pick; sunrise stepper (registry-covered); WarningCard
  accent param (default byte-identical).
- Notifications: delay dropdown to SelectTile (conditional); snooze/adhan
  init + error-revert guards; quran rowKey split from daily; test-adhan
  passes the configured sound (ConsumerState + Fake stub + tap test);
  onFix awaited; spinner-gated rows; location/gps warnings; attachment
  route release-guarded; _CleanCard dropped; titles/radii/paddings/fonts
  unified. Stat: 16/16 screen tests green.
- Account: kit rows/cards/headers/snackbars; encrypted cloud uploads
  (optional password); shared restore-repair helper; listing error state;
  backup dates; honest delete wording (Drive-file deletion left as an
  explicit product decision); trims, guards, GB sizes, spellings.
- Shared: settingsRow()/settingsCard() replace 11 copy-pasted helpers;
  azkar sheet + font slider on kit; widget app-bar/snackbars/error color.
- Proof: analyze 0/0, strict gate 7/7, design ratchet OK, prayer + settings
  suites green incl. 5 new regression tests; 5 goldens re-recorded
  (2 prayer + 3 settings, layout deltas only).
- Left for explicit approval: ToolLockScreen kit pass (protected file),
  SegmentedTabs unification (system-level), Friday accent token (protected
  section_colors), shared status-card extraction (debug-only), kit
  dialog/sheet invention (none exists).

## Prayer accordion rows (2026-10-13, user request, `55f5b51`)

- The per-prayer card showed 15 rows; each prayer is now ONE accordion row
  (hue icon on / muted off, offsets caption, azan switch, «تنظیم دقیق»
  toggle opening its two steppers, one open at a time). SwitchTile gained
  an optional icon color (default identical).
- Proof: 15/15 prayer tests (new accordion + caption tests), 2 prayer
  goldens re-recorded, analyze clean.

## Home prayer rows boxed + a bigger adhan countdown (2026-10-14, user request)

Two home-tab requests in one pass, landed on `release/1.8.0` as `745d945` (test +
golden proof only — no device, «فعلا بیلد نزن»).
- **Every prayer row is a faint box.** Only the open window had a box
  (`HomeColors.nowRowStart/End` gradient + `goldLine`); the rest were bare. The
  non-active rows now take the rawatib card's faint recipe — light:
  `AppTheme.parchment.withValues(alpha: .85)`, dark:
  `Colors.white.withValues(alpha: .06)`, radius 14 — and the open
  window/highlighted row swaps in the solid-gold gradient. The «بعدی» dashed
  outline still draws over the faint fill. No new colour literal, so the
  design ratchet is untouched.
- **The adhan countdown grew with the hero.** `_Countdown`'s two lines now ride
  the existing `_heroScale` (1.2) and the caption→number gap went 2 → 6. The
  shared type scale rounds 14 → 16.8 = **17** and 26 → 31.2 = **30** (nearest
  step; neighbours are 26 and 34 — documented in the comment rather than
  inventing a step).
- **Guards.** `prayer_times_card_test.dart` reads each row `Container` by
  `ValueKey('prayer-row-<id>')` and asserts the six faint boxes vs dhuhr's
  gradient box; `hero_card_test.dart` measures the two keyed countdown Texts
  against `AppTheme.scaledFontSize(ctx, n * 1.2)` and asserts their gap.
- **Proof**: `test/features/home` **110 passed**; `flutter analyze lib test`
  0 errors / 0 warnings (102 pre-existing info lints); `quality_check.py
  --strict` 7/7; encoding guard 2/2; `design_consistency.py` OK. Six home
  baselines re-recorded (`home_hero_day`, `home_prayer_day`, the four full
  pages) and **every image size is unchanged** — pixel-only diffs of 2.18 %
  (hero), 57.23 % (prayer card), 6–9 % (pages). The other home goldens are
  byte-identical.
- **Not mine, left untouched:** the parallel session's WIP
  (`widget_settings_screen.dart`, the widget Kotlin/XML + two `*_widget_preview.dart`
  files, and the untracked `.zcodeignore`, `cache.db`, `desine/`, `doc/design/`,
  `widget_ic_*.xml`).

## Tabs lost their AppBars: a slim scrolling page header (2026-10-14, user request, `ecb5078`)

User: «بالای تب‌ها زیادی جا گرفتند» — every top-level tab wore a 56dp `AppBar`
whose 20sp **centred** title only repeated the bottom-nav pill, and adhkar stacked
a fat `TabBar` under it (56 + 56 = **112dp**). Option 1 of the numbered choices was
approved: remove the bar, keep the title in a quiet 40dp row that scrolls with the
content, and swap adhkar's TabBar for the kit's `SegmentedTabs`. Test + golden
proof only — no device attached, `فعلا بیلد نزن`.
- **New kit component**: `lib/core/design_system/components/page_header.dart`
  (`PageHeader` + `PageAction`, exported by `components.dart`). One 40dp row:
  title 14sp/w600 on the **start** edge via `AppTheme.scaledFontSize(context, 14)`
  (so it is never a raw literal and follows «اندازه فونت»), compact 20dp action
  glyphs in 40dp square targets on the end edge. The title is the flexible half
  (`Expanded(FittedBox(scaleDown))`), so a long one scales down instead of
  truncating. The action glyph defaults to the page accent (`t.primary`) — the
  colour the calendar and adhkar bars already tinted their icons with; home's
  search therefore goes ink → gold.
- **Where it went**: home / calendar / more put it as the **first ListView child**
  (it leaves with the content); evaluation (a fixed `Column`) and adhkar keep it
  pinned. The actions moved verbatim: home's search, the calendar's converter
  (now `_openConverter`, still a `context.push` — a `Navigator.push` would leave
  the ambient branch and paint the black page), adhkar's settings. adhkar's
  `TabBarView` stays; the strip is `SegmentedTabs` driven by the tab controller
  through an `AnimatedBuilder`, so a swipe updates it as well as a tap.
- **Measured, not impressionistic**: on the golden surfaces the content below the
  header is **pixel-identical** to before at a shift of exactly 10px (home), 8px
  (more), 12px (calendar) — mean absolute difference at the best shift = **0.000**.
  So the only thing that changed on those pages is where the content starts.
- **Guards**: `test/core/design_system/page_header_test.dart` (row is 40dp, title
  hugs the start edge in RTL and LTR, rides `AppTheme.typeScale` at w600 and
  ≤14sp, action keeps a 40dp square target and fires, long title survives
  320dp × 1.3 with no overflow) and `test/app/router/tab_page_header_guard_test.dart`
  (a source scan — the repo's idiom for a "must not come back" invariant: none of
  the five tab files may carry `appBar:`/`AppBar(`, each keeps its title and
  action tooltip, and adhkar may not return to `TabBar`/`Tab`).
- **Proof**: full suite `flutter test --exclude-tags network` = **3788 passed /
  9 skipped / 0 failed**; affected scopes alone **538 passed**; `quality_check.py
  --strict` 7/7; `design_consistency.py` OK (`raw_size` still 0, no new raw
  colour/direction literal); encoding guard green. **29 goldens re-recorded**
  (4 home, 20 more, 5 calendar) and every image size is unchanged — the diffs are
  the vertical shift. Two pre-existing `flutter analyze` warnings live in files
  this work never touched (`tasbih_widget_preview.dart` unused import — the
  parallel session's WIP; `munasakhat_sheet_content.dart` duplicate import).
- **Not mine, left untouched:** the parallel session's WIP
  (`widget_settings_screen.dart`, `PrayerWidgetViews.kt`, `TasbihGlanceWidget.kt`,
  `widget_prayer_medium.xml`, four `values*/styles.xml`, `colors.xml`, the two
  `*_widget_preview.dart` files, `pubspec.lock`, and the untracked `.zcodeignore`,
  `cache.db`, `desine/`, `doc/design/`, `widget_ic_*.xml`).

## The dark chrome follows the app theme (2026-10-15, user request)

User report (Persian): the header / clock box, the quran header, the selected
bottom tab and the recitation/translation player pads kept their colour when
«تم برنامه» changed. All four were painted from a **fixed** brown, which is why
the theme never reached them.

- **One source**: `AppPalette.heroGradient` (`time_theme.dart`) returns
  `[heroTop, heroMid, heroBottom]`. `hero_card.dart`'s `_HeroBackgroundPainter`
  takes `(lite, hero)` and paints it (the three colours also joined
  `shouldRepaint`, or a theme change would leave the memoised field alone), and
  `_ArcCountdown`'s ring hole is `Color.lerp(t.heroMid, t.heroBottom, .6)`.
  `HomeColors.heroTop/heroUpper/heroLower/heroBottom` are **deleted**.
- **The quran chrome**: `_readerChromeGradient(BuildContext)` (in
  `quran_reader_header.dart`) is the single builder both the header band and the
  two player pads use — `_kReaderHeaderGradient` and `_MiniPlayer._panelGradient`
  (the same `0xFF5A4032/0xFF2A1A12` pair) are gone, so the talaawah pad and the
  translation pad can no longer be painted from different browns. The quran
  **index list and bookmarks list are deliberately left on the paper chrome** —
  `quran_bookmarks_screen_test.dart` pins that contract ("chrome, paper and rows
  follow the palette, not the app theme"), so only the reader's own band and the
  two pads follow the app theme.
- **The nav pill**: selected pill = `[t.heroTop, t.heroBottom]` (was
  `const [AppTheme.mocha, AppTheme.darkWalnut]`); the gold icon and cream label
  stay `AppPalette` accents, which are shared by every palette.
- **Guard**: `test/core/theme/chrome_follows_theme_test.dart` — a source scan for
  the retired browns/declarations (plus "the shared builder has exactly two call
  sites") **and** a behavioural test on `HomeBottomNav`: under `ThemeKind.day`
  the selected pill paints the active palette's gradient, it changes under
  `ThemeKind.night`, and the two palettes must actually differ (because the
  comparison is against the palette read from the same pump, a silent
  no-change would otherwise pass).
  **Landmine for whoever tests themes next**: `MaterialApp` wraps the theme in an
  `AnimatedTheme`, so reading `TimeThemeKit.of` on the frame the new theme is
  handed over returns the *previous* palette at lerp `t=0` — `pumpAndSettle`
  before asserting, and always assert against a value that cannot move together
  with the thing under test.
- **Goldens**: 5 home baselines re-recorded (`home_hero_day` 76 % — the whole
  field — and the four page shots 5.8–6.3 %); **no image size changed**. The
  quran/More/settings/calendar baselines did not move (none of them contains
  these four surfaces).
- **Proof**: analyze clean on the 7 touched files; `quality_check.py --strict`
  7/7; `design_consistency.py` OK (`raw_color` 275 → 273); home 109 green, quran
  320 green, the new guard 7/7, and the whole suite green: `flutter test
  --exclude-tags network` in a clean worktree at `d0dfd0e` carrying exactly these
  seven files, the five goldens and the new guard = **3796 passed / 0 failed /
  9 skipped**. The three remaining reds in the shared tree are
  **not** this work: `test/app/router/{app_router,main_shell}_test.dart` fail to
  load on the parallel session's in-flight
  `notification_settings_screen.dart:862` (`const accent = SectionColors.friday`)
  and `prayer_settings_day.png` drifts with their 279-line
  `prayer_settings_screen.dart` rewrite.
- **Not built** («فعلا بیلد نزن»), **no Android device attached** — test/golden/
  source proof only, so the visual verdict is the user's on an installed build.

## Settings: nothing is cut with «…» any more (2026-10-15, user request)

User report (Persian): in تنظیمات the option texts are not written in full — each one
ends with «…» — under the standing constraint that **no box, header or font size may
grow**. Both halves of that are what shipped.

- **The caps were the cause, not the copy**: `SettingRow` pinned `maxLines: 1` on both
  title and subtitle, and the settings-only rows did the same (`SettingsSliderRow`
  title, `_ThemeKindChips` subtitle, `_pointRow` label/hint) — so any text wider than
  one line at 320/360dp was ellipsised. Only `maxLines` moved: `SettingRow` title 3 /
  subtitle 4, `SettingsSliderRow` title 2, `_ThemeKindChips` subtitle 3, `_pointRow`
  label 4 / hint 4. **No font size, padding, tile or header was touched** — a row now
  takes the lines its text needs.
- **Five strings shortened**, only where wrapping could not fit them: hijri
  «تنظیم تاریخ هجری»→«تاریخ هجری» and «تغییر روز تقویم هجری (برای تطبیق با رویت
  هلال)»→«تطبیق با رویت هلال»; auto-backup «پشتیبان‌گیری خودکار روزانه»→«پشتیبان‌گیری
  روزانه» and «هر روز یک نسخه از آمارها (تسبیح، ختم، مطالعه، نماز، روزه و…) ذخیره
  می‌شود»→«ذخیره خودکار آمارها»; and the worship-points label «طاعات (قرآن، صدقه، نماز
  شب و…)»→«طاعات (قرآن، صدقه و…)».
- **Measured, not assumed**: a temp probe loaded the real
  `assets/fonts/Vazirmatn-Regular.ttf` through `FontLoader` and counted
  `RenderParagraph.didExceedMaxLines` across the settings tree. At HEAD it cut
  **18 / 10 / 3** texts at 320 / 360 / 412dp; now **0 / 0 / 0** (and 0 at text scale
  1.3). In the test binding's font — which is ~1.7× wider than Persian — HEAD cut
  53/47/36 and this fix leaves 3/0/0.
- **Guard**: `test/features/settings/presentation/screens/settings_no_truncation_test.dart`
  — 8 tests. The real-font track (Vazirmatn at 320/360/412 × scale 1.0/1.3) is the
  user-facing promise; the test-font track at 360/412 is a deliberately conservative
  tripwire, and 320dp is **absent from that track on purpose** (the binding's font is
  not a realistic Persian face, so it would fail on text no phone cuts — the three
  remaining literals there are «تاریخ هجری», «هر دور اذکار صبح یا شام تکمیل‌شده» and
  the worship-points label).
- **A real defect in the golden harness surfaced and is fixed**
  (`test/features/settings/presentation/screens/golden_page_fit.dart`): the page height
  came from `maxScrollExtent + viewportDimension`, which is only an *estimate* while
  rows below the fold are unbuilt — exact only while every row was one line. With
  wrapping rows it recorded **~1100px of empty space** at 412dp and **clipped ~370px
  off the bottom** at 320dp. The helper lays the whole page out first (a very tall
  viewport), walks the sliver's children for the exact extent, and fails the test if
  the page still scrolls. Both `settings_golden_test.dart` and `about_golden_test.dart`
  call it. **9 baselines re-recorded**: `settings_day`/`settings_night` 3932→3683,
  `settings_day_320` 3932→4680 (320dp is genuinely taller once rows wrap),
  `prayer_settings_day`/`night` 3621→2515, `about_day` 1710→1548, `about_day_320`
  1712→1601, `about_day_scale13` 2057→1860, `about_night` 1710→1548. The about/settings
  images got *shorter* because the old estimate had padded their tails. **Do not go
  back to a single-pass estimate.**
- **Drive-by**: `munasakhat_sheet_content.dart:14` carried a duplicate
  `core/design_system/components/components.dart` import (left by the `final/map`
  merge) — the repo's only analyze **warning**. Removed; `flutter analyze lib test` is
  back to **0 errors / 0 warnings** (101 pre-existing info lints).
- **Proof**: settings + design-system **387** green and, with
  `test/features/tools/inheritance`, **1107** green; `quality_check.py --strict` 7/7;
  `design_consistency.py` OK (`raw_color` 270 ≤ 275, `raw_size` 0). The pre-existing red
  `prayer_settings_screen_test` «renders the eight designed sections in order» (it wants
  a `SectionHeader` ancestor) is **not** this work and was red before it.
- **No Android device attached, not built** («فعلا بیلد نزن») — test/golden proof only,
  so the visual verdict is the user's on an installed build.

## Account + backup + reset/transfer unified into one hub (2026-10-15, user request, `6b9a451`)

User report (Persian): the account section, the backup section and the
reset/transfer section feel like repetitions of each other — all should live
in one section, duplicates removed — plus a fundamental fix and development
pass. User decisions by number before editing: the hub lives on the
`/settings/account` route; BOTH dead-code duplicates deleted; full-device
wipe added with two-step confirm.

- **One hub.** `/settings/account` (AppBar «حساب و پشتیبان») owns every door:
  sign-in/account header, Drive + Firebase cloud sections, «پشتیبان‌گیری در
  این گوشی» (old `_BackupSection` moved verbatim → `LocalBackupSection`,
  minus its unused `settings` param), «انتقال تنظیمات» (export/import rows →
  `SettingsTransferSection`), and «منطقه خطر» (reset + wipe + delete-account
  in one red card with a one-line scope warning). The settings page keeps ONE
  nav tile («حساب ابری و نسخه پشتیبان»); its backup/reset sections, their
  anchors and ~740 lines are deleted. Local sections render signed-out too.
- **One restore pipeline** (`restore_flow.dart`): confirm (vault caveat
  always appended) + password + apply + repair, returning `RestoreResult
  {applied, error}` (null error = user cancelled, stay silent). The mirrored
  settings/account implementations are deleted; all four doors share the
  completeness check and the permission nudge. One password-dialog spelling
  per direction.
- **Wipe** (`BackupService.wipeAllLocalData`): one transaction over
  `sqlite_master` with deferred FKs + VACUUM, then `app_data`/`custom_azans`,
  secure-storage deleteAll, prefs.clear. Keeps `backups/` + downloads by
  design (stated in both dialogs). Two dialogs → best-effort cancel/sign-out
  → invalidate → go splash.
- **Dead code deleted:** `SettingsRepository.exportBackup/importBackup`
  (zero callers) + impl + notifier passthroughs + mock overrides; the
  unreferenced domain `account_repository.dart` duplicate.
- **Search/nav:** registry entries retargeted to the hub with rowKeys;
  `account.cloud` split into drive/app; new `main.wipe`;
  `AccountScreen.accountHighlightKeys` is the anchor contract (registry test
  pins it); account page mixes in `SettingsHighlight`. More tile renamed
  «حساب و پشتیبان». 10 goldens re-recorded.
- **Proof:** full suite `--exclude-tags network` = **3824 passed / 2 failed**,
  both pre-existing (`prayer_settings_screen_test` eight-sections,
  `qcf4_offline_test` tearDownAll flake that passes solo); analyze 0/0;
  strict gate 7/7; design_consistency OK; encoding guard green.
- **No Android device attached, not built** — test/golden proof only.
- **Collision note:** landed while the parallel session held a staged bundle;
  committed with `git commit -- <mine-only paths>` after verifying the FULL
  cached list, so their index survived untouched.

## Bottom content clears the 3-button system bar (2026-10-15, user request, `43e5f0d`)

User report (Persian): on 3-button phones, parts of sections sit behind the
system buttons (qaf search box untappable, reminders, mushaf-hafiz, others) —
review completely and fix, with no empty gap on phones without the problem.

- **Root cause:** edge-to-edge app, so every Scaffold body runs under the
  bar. All 14 FAB sites were bare (FAB at 16dp above the edge = behind ~48dp
  of buttons); scrollable bottoms (editor 12, hifz 40, report 32) and the
  WebView body had no live inset, so the last ~36px could never scroll into
  view.
- **Fix is additive everywhere** (live inset + own padding): zero where there
  is no bar, so unaffected phones stay pixel-identical (goldens at zero
  inset prove it — none re-recorded).
- **One recipe `InsetFab`** (barrel-exported): the inset is read in the page
  build context and passed as a value — a SafeArea *inside* the FAB slot can
  never work because the Scaffold strips all padding around that slot (SDK
  `_addIfNonNull`); the first cut did exactly that and the tests caught it.
  Seven unprotected FAB screens converted; in-app browser body wears a
  bottom-only SafeArea.
- **Guard:** `test/core/navigation/system_nav_inset_test.dart` (7 tests:
  clearance, zero-inset identity, recipe coverage, four reported screens
  under a 48dp inset). Editor/report tests load Vazirmatn (tofu overflows
  narrow rows that fit on real phones); report pumps 800dp wide like its own
  test.
- **Untouched:** 7 personal_info FABs (protected bundle — listed for explicit
  authorization), book_reader (intentional full-bleed), shell tabs (body
  above the inset-aware nav).
  - **Follow-up (`79d8000`, user-authorized):** the 7 protected FABs converted
    too (one wrapper each); recipe test now asserts all fourteen.
- **Proof:** affected scopes 477 green; full suite 3831/1 (pre-existing
  prayer_settings eight-sections); analyze 0/0; strict gate 7/7;
  design_consistency OK; encoding guard green.
- **No Android device attached, not built** — on-device verdict is the
  user's.

## Release build 1.8.0-9793f41 (user request, 2026-10-15)

- First two `assembleRelease` runs failed in `compileFlutterBuildRelease`
  with a real error the green tree hid: `widget_settings_screen.dart`
  passed `accentColor:`/`light:` to `PrayerWidgetPreview`, which no longer
  declares them. Fixed in `9793f41` (dropped the two stale args, zero
  behavior change); widget-settings 8/8 green.
- APKs from a clean detached worktree at `9793f41`, four gitignored files
  in, no dart-defines: fat 47,509,184 B (45.3 MB, `d61f7e1d…`), arm64
  31,542,390 B (`8728c48a…`), armv7 31,792,893 B (`98db4c2c…`);
  `1.8.0+10015`. Durable copies + SHA1SUMS + BINARY_PROOF (PASS) at
  `Desktop/tawheeed-release-apks/1.8.0-9793f41/`. Binary proof: 10 correct
  forms FOUND (incl. the new hub/wipe labels), 4 removed + 5 mojibake
  ABSENT, `splash_icon_none` present. This set supersedes all older 1.8.0
  APKs.

## FreeBuff review + qibla/purification/sciences transfer + rebuild (2026-10-15, user request)

- Branch inventory (unique vs release/1.8.0): arc-sweep 0, https-prompter 0,
  task-5dec 5, task-7cf 16, 1.8.0-transfer 1, home/polish-v2 27,
  release/1.7.2 13, rescue/safety/wip snapshots, qibla-sciences-tahara 18.
  Contained already: arc-sweep, https-prompter, 1.7.2 (subjects match the
  second pass one by one); snapshots stay snapshots; 1.8.0-transfer
  superseded (doc at HEAD); task-5dec doc-photos landed, tasbih-click
  superseded by HEAD's AudioPool, quran flips by approved redesigns;
  home/polish-v2 tilawa would resurrect deleted features, home C1–C7 already
  via -ui; task-7cf rows stay out by prior user decision (flagged).
- b04df1a audited hunk by hunk: bookmark-list, 2x picker, sheet scroll
  present at HEAD; ring + spec-D sheet superseded by user decisions; gutter
  moot; chip overlap dissolved in redesign. Nothing to merge.
- Transferred in 4 slices then fast-forwarded (full-branch merge rejected:
  ~60 conflicts incl. deleted arc.dart/prayer_icons.dart): qibla wall-clock
  fix, compass redesign (adapted), purification 7 tabs, sciences hub.
- Proof: full suite 3875/0; analyze 0/0; gates green.
- Release APKs from `d2888a6`: fat 47,526,345 B (`4b9ae2bb…`), arm64
  31,548,416 B (`16ae9be2…`), armv7 31,804,179 B (`ef9604fa…`); proof PASS
  with 13 forms incl. the three new sections. At
  `Desktop/tawheeed-release-apks/1.8.0-d2888a6/`. Supersedes 1.8.0-9793f41.

## Google sign-in was DEAD — the google-services plugin was never applied (`0eb8985`)

User report: the Google button opens no account picker at all, and email/password
does not sign in either. Two independent runtime defects, one per door:

- **Google door:** `com.google.gms.google-services` was declared
  `apply false` in `settings.gradle.kts` and NEVER APPLIED in
  `android/app/build.gradle.kts`. `android/app/google-services.json` was
  therefore inert — proven on the shipped release APK with
  `aapt2 dump strings`: `default_web_client_id`, `google_app_id`,
  `project_id` are all ABSENT from the resource table (4312 strings, none of
  them). With no `default_web_client_id` resource, google_sign_in 7.x resolves
  no serverClientId and fails `getCredential` with
  `MISSING_SERVER_CLIENT_ID` **before showing any UI** — a tap with zero
  reaction. Now applied; proven in a clean worktree via
  `gradlew :app:processDebugGoogleServices` (BUILD SUCCESSFUL) and the
  generated `build/app/generated/res/processDebugGoogleServices/values/values.xml`
  carrying `default_web_client_id` = the project's type-3 oauth client.
- **Second belt on the same door:** both `GoogleSignIn.instance.initialize()`
  sites now pass `GoogleAuthService.serverClientId` explicitly (the same web
  client ID), so the picker can never die on a missing/stripped resource and
  the idToken is minted for the audience the Firebase credential expects.
- **Email door:** a cold-start race. Firebase init is deliberately unawaited in
  `main()`, so `Firebase.apps` is empty for the first seconds; the repository
  read it synchronously, so every tap inside that window threw «سرویس ابری در
  دسترس نیست.» — and worse, the provider's constructor evaluated
  `FirebaseAuth.instance` **eagerly**, which THROWS before any app exists (the
  hub reads that provider at build time). `_available` is now async and awaits
  `ensureFirebaseInitialized()` (memoized, 8s-bounded), `_auth`/`_storage`
  resolve lazily, and `authStateChanges()` yields null instead of throwing.
- **Verified clean elsewhere:** the release SHA-1 (`7b8572bd…`) matches the
  keystore exactly (keytool vs the JSON), so the OAuth client is registered for
  release signing; form validators, INTERNET permission and the
  `firebase_options.dart` values are all correct.
- **Guard:** `test/android/google_sign_in_server_client_test.dart` pins the
  plugin application, the serverClientId ↔ google-services.json agreement (so
  the two can never drift), the registered SHA-1, and the awaited-init
  invariant.
- **Proof (clean detached worktree `%TEMP%/opencode/fix-gsignin`):**
  `:app:processDebugGoogleServices` SUCCESSFUL + generated resource checked;
  `flutter analyze` on the touched scope **0 issues**; `test/android` +
  `test/features/account` **40 passed**; `quality_check.py --strict` 7/7;
  `design_consistency.py` OK; encoding guard green. Full suite run ordered in
  the same worktree.
- **NOT built** («فعلا بیلد نزن» still stands; the user must say so explicitly)
  and **no Android device attached** — the picker opening and a real sign-in
  round-trip still need an on-device pass on a new APK.

## Battery / heat audit of every section (`af4425a`)

User request: verify that no section of the app burns battery or heats the phone.
Method: a static review of both sides (Dart + Kotlin) — every periodic timer,
every wakelock owner, every stream subscription, the sensors, the animation
controllers and the background schedulers. **No device was attached, so this is
source-level reasoning, not measurement** — the on-device numbers are still the
user's to take.

- **What was already right** (recorded so it is not re-litigated): the shared
  `ClockTicker` is second-aligned AND stops itself when the app is not resumed;
  the shell builds unvisited tabs lazily and wraps hidden tabs in
  `TickerMode(enabled: false)`; قبله‌نما cancels its 31 Hz compass stream, its
  sensor probe and its wakelock-all-release timer in `dispose` and filters
  sub-0.7° changes; location is a one-shot with a hard time limit; every
  `AnimationController` that repeats is disposed; all 13 periodic timers are
  cancelled in `dispose`; crypto (PBKDF2-200k / AES-GCM), gunzip, JSON decoding,
  mushaf page decoding and quran search indexing all run in `Isolate.run`; the
  Firestore streams are push-based and dispose with the page; WorkManager is
  6h + 24h only; widgets use `updatePeriodMillis=0` with native-only refreshes.
- **1. The pomodoro held the screen awake FOREVER after a mode switch.**
  `_setAwake` opened with `if (_mode != countdown || !_cdKeepAwake) return;`,
  so every *release* went through the same policy that granted it — and the two
  paths that change `_mode` *before* releasing (switching mode, then disposing
  the screen) never released at all. The screen stayed on until the process
  died. Acquire stays policy-gated; release is now unconditional.
  Guard: `test/features/tools/pomodoro/pomodoro_screen_test.dart` acquires the
  lock, switches mode and asserts the owner set is empty. **Proved it bites** by
  re-introducing the old guard and watching the test fail with
  `Set:['pomodoro']`. `AppWakelock.debugOwners()` (`@visibleForTesting`) existed
  only so this pairing could be observed at all — a silent non-release is
  invisible on a phone until the screen stops sleeping.
- **2. Two upkeep cycles had no lifecycle awareness.**
  `BootCoordinator`'s 15-minute maintenance tick and `WidgetSyncService`'s
  30-minute sync (+24h refresh) ran for the whole process lifetime — on Android,
  long after the user left the app, ~96 wakeups a day doing work the resume path
  already performs. Both now pause with the app and run their catch-up on the
  way back, mirroring the `ClockTicker` pattern that was already in the code.
- **3. The adhan polled four audio volumes every 100 ms** on the main thread
  for the whole adhan (minutes of sustained wakeups per prayer). Now 300 ms —
  still faster than any human press of a volume key.
- **4. `GoogleAuthService` latched `_initialized` *before* `initialize()`,** so a
  single transient failure disabled the Google picker for the rest of the
  process's life. The flag now latches only after success (same door as the
  `0eb8985` fix).
- **5. CORRECTION to my own earlier report:** I claimed the home hero keeps
  repainting per second while another tab is selected. **It does not.** The
  production code already gated its per-second layer on `TickerMode` and, while
  inactive, reads the notifier's **current** value (`builder(context,
  minute.value)`), so it is both cheap and never stale. What was actually
  missing was a test. The new `hero_card_test.dart` group now pins both
  directions — no subscription to `second`/`minute` while hidden, and the LIVE
  time the moment the tab returns (asserts `12:03`, i.e. it fails if anyone
  caches the last rendered value instead of reading the notifier). That is the
  user's own constraint honoured: skipping rebuilds must never cost a wrong
  clock.
- **Kotlin lesson repeated on purpose:** the volume-poll change was verified
  with `:app:compileReleaseKotlin` (BUILD SUCCESSFUL), because `flutter test`
  cannot see Kotlin.
- **Proof (clean detached worktree at `af4425a`):** pomodoro 15/15; hero 10/10;
  home + pomodoro + `test/app` = 144 green with exactly one red — the
  pre-existing `prayer_times_card_test` hayz case, re-proved red at `99f6754`
  (the commit immediately *before* this work) with the identical
  "0 widgets containing «فاته حساب نمی‌شود»" failure, so it belongs to the
  prayer-card session, not to the battery pass. `flutter analyze lib test`
  0 errors / 0 warnings (infos only); strict gate 7/7; design ratchet OK;
  encoding guard green. **No device attached, not built.**

## صحیح الترغیب: the book, its own colour, and the upload (2026-10-16, user request)

The user wanted a new hadith section next to «ریاض الصالحین» — same
download-on-demand pattern, bundled nothing — and its colour must not be the
riyad olive. Suggestions were offered; the user picked **number 1: عنابی
`#880E4F`**.

- **The book** (`lib/features/taraghib/**`): 3 volumes parsed to 440 chapters /
  2727 entries; standalone ~1.4 MB gzipped DB, deliberately NOT the 18 MB full
  hadith.db; `HadithDbService.taraghib` (bookId 19, remoteKey
  `taraghib/taraghib.db`); route `/taraghib`; More tile right after
  ریاض الصالحین. Work: `2b9b7af`, `08cf181`, `a7bc517`.
- **Colour wired single-source** (`94d79d9`): `SectionColors.taraghib` +
  `TopicHues.taraghib` (parity pinned by `topic_hues_test.dart`) + a
  `RouteNames.taraghib` case in `SectionColors.of` + the More tile. The riyad
  copy leftovers were cleaned with it — service header text, the
  `riyad/ryadalsalihin.db.gz` path comment, book number, and the two
  `riyad_screen`/`riyad_chapter_screen` logger tags.
- **The taraghib-tile reds are closed with it** (they were the queued
  pre-existing failures from `2b9b7af`): registry split 41 → 42, tile metrics
  37 → 38, and **7 More full-page goldens re-recorded**. Before re-pinning,
  every failing case was checked to be a pixel diff with no exception and
  unchanged page sizes (412×2084 / 320×1884 / 360×1952 / 360@1.3×2108), so no
  clipping hid in the ~5.6 % (recoloured tile + one-cell shift).
- **Upload**: `taraghib/taraghib.db.gz` is live on `TAWHEED-EWAZ` main
  (`c916e70`) — the same URL the app fetches, verified HTTP 200, 1,491,362 B.
- **Proof**: theme + settings 265/265; strict gate 7/7; design ratchet OK;
  analyze clean on all touched files; encoding guard 2/2. **No device
  attached, not built** («فعلا بیلد نزن») — the colour verdict is the user's on
  an installed build.

## Home: the Friday adab card is back — under the reminders box (`1f7a78f`)

User request (Persian): «1 با دیزاین جدید و زیر بوکس یادآوری ها بیایید فقط این
انجام بده» — of the four presented options only option 1 (restore the Friday
box), in the new flat design, directly below the reminders box, and nothing
else.

- **Card restored** (`lib/features/home/presentation/widgets/friday_adab_card.dart`),
  Friday-only — a zero-size box every other day, so the rest of the page never
  moves. Placement is pinned by a source scan in `friday_adab_card_test.dart`:
  it must sit in `home_tab.dart` directly after `RemindersCard`, before
  `QuickActions`.
- **It had been deleted silently** in the 2026-10-11 home restructure
  (`de23001`); its content source `FridayContent` and `SectionColors.friday`
  had stayed alive with no consumer at all. Do not delete it again without a
  guard.
- **Content preserved**: each row is ONE shared `ExpandableText` of the adab's
  own detail + its own hadith («arabic» — translation — source)», so a
  collapsed row can only hide a long line, never drop a source; the share text
  carries every adab with its hadith and ends with `ShareService.appLine`.
  Card, weekly notification and settings preview all read the same
  `FridayContent` list.
- **Design**: flat home language — palette `AppCard` with hairline border (no
  gradient/blur/shadow), `SectionHeader` with the two share IconButtons, the
  headline hadith as a tinted quote box, rows on the shared `DuotoneIconTile`
  (10 % fill / .25 border / radius 15), «بیشتر (2 آداب)» expander for the last
  two of six. `HomeColors.friday` aliases `SectionColors.friday` (#7A5AF8).
- **Clock/golden invariant**: the card reads `clockTickerProvider.minute` (the
  `now` parameter is a test seam only). The home golden harness pins
  2026-10-09 12:00:40 — a Friday — so the card is part of every full-page home
  baseline; `home_friday_day.png` was added and the 4 page baselines
  re-recorded (pixel-only diffs, page sizes unchanged).
- **Proof**: `test/features/home` = 116 passed / 1 failed — the one red is the
  pre-existing `prayer_times_card_test` hayz case, re-proved red in a clean
  detached worktree at HEAD (foreign period territory). analyze 0 issues on
  touched files; strict gate 7/7; design ratchet OK; encoding guard green.
  **No device attached, not built** («فعلا بیلد نزن») — the Friday look is the
  user's verdict on an installed build.
  Still open: options 2–4 of the reminder list (same-day catch-up for
  non-adhan reminders on boot / Friday + Kahf reminders only / no change plus
  a diagnostics note) await the user's pick — option 1 is what shipped here.

## Flat-pass follow-up: the DuaDetailScreen ambient boundary (`70217bf`)

Full suite at `1f7a78f` = 3901 passed / 9 skipped / 5 failed. After triage,
exactly one was a new real red: the ambient guard still required
`dua_detail_screen.dart` to stay opaque, but the دعا/حصن flat pass (`9bb7fce`)
made its scaffold transparent on purpose. With the ROOT ambient wrap in
`main.dart` (pinned by the same guard file), a transparent pushed scaffold
shows the ambient — no per-site wrap needed — so the stale boundary entry is
dropped with a comment naming the commit and the mechanism. Guard file 11/11;
core/navigation + adhkar + encoding guard 132 green.

The other four reds: three `google_sign_in_server_client_test.dart` cases that
read the gitignored `android/app/google-services.json` (fail in a clean
worktree, all seven pass in the main tree) and the known hayz case (foreign
period territory). Recorded so the next clean-worktree full run is not
misread.

## Audio library: background playback + the lock-screen card (`351f9bc`)

User request (Persian): «می‌خواهم در خلفیه کار کند یعنی وقتی از اون بخش بیرون امدم
یا حتی وقتی از برنامه هم بیرون امدم کار کند، اگر می‌شود این گزینه اضافه کن».
Shipped as an **always-on capability** (no settings toggle): a lecture keeps
playing when «کتابخانه صوتی» closes and when the app leaves the foreground — the
notification / lock-screen card is the control surface outside the section.

- **Root cause was one line:** `audio_library_screen.dart` `dispose()` called
  `_player.stop()` («Leaving the screen stops playback»). The player is a
  process-wide singleton, so this is exactly the reported behavior. Dispose now
  only removes the listener; re-entering the screen re-attaches to the live
  session. A source guard fails if `.stop(` ever reappears in that dispose.
- **New `lib/features/audio_library/audio_library_media_session.dart`** —
  `AudioLibraryMediaPlayback` (the narrow surface the session may touch: track,
  byline, playing/loading, position/duration, speed, resume/pause/seek/stop),
  the `mediaItemForSource` / `playbackStateForSource` mappers, the
  `AudioLibraryMediaSession` singleton and the `AudioLibraryMediaHandler`. The
  player implements the interface directly (no adapter); `togglePlay`'s
  same-track branch now shares `resumeActive()`/`pauseActive()` with the card.
- **Session lifecycle (mirrors the mushaf's pattern, with one deliberate
  difference):** starts on every `_playTrack`, stays through pause (the card can
  resume it), ends on every player `stop()` (queue end, sleep timer, card X) and
  on a failed start. The handler is **reused across stop→start —
  `AudioService.init` runs at most once per process** (process-global callbacks;
  a second init would swap a live mushaf session, and assert-fails in a debug
  build — so a debug build shows no card when the mushaf session init'ed first;
  release unaffected).
- **Card controls mirror the mini player:** rewind / play-pause / fastForward
  (±15 s) + a seek slider; no next/prev/stop (the mini player has none). The
  ±15 s buttons deliberately do NOT use `SeekHandler` — its `_seekRelative`
  clamps against `MediaItem.duration`, which snaps BOTH buttons to 0:00 while a
  streamed track has not reported a duration yet; they measure from the player's
  live position (a `skipStep` const single-sourced with the config intervals)
  and route through the player's own clamp. The test for this caught the mixin
  version doing exactly that (expected 0:45, got 0:00).
- **The card's X silences the lecture:** `stopCard()` clears its source first,
  so the chain player.stop → session.stop → stopCard cannot re-enter the player;
  a late OS stop after teardown is a no-op (both pinned by tests).
- **Config:** own Android channel `com.islamic.tawheeed.audio_library.playback`
  («پخش کتابخانه صوتی»), `androidNotificationOngoing: true`, no artwork. While
  playing, the service stays foreground + wake-locked (background / screen-off /
  recents-swipe keep the audio); while paused the default
  `androidStopForegroundOnPause` demotes it (position persisted). **No manifest
  change** — the service/receiver/FGS declarations were already there; no iOS
  target exists.
- **Proof**: `test/features/audio_library` (incl. the new file's 17 cases on
  mocked service + path_provider channels) + quran media-session + encoding
  guard = **131 green**; analyze 0 issues on the touched files; strict gate 7/7;
  `design_consistency.py` OK. **No Android device attached, not built**
  («فعلا بیلد نزن») — the on-device pass (lock-screen card, ±15 s, swipe-away,
  card X) is the user's verdict on a build carrying `351f9bc`.

## Qibla needle/labels, settings kit, More ink, tasbih dial (`76f9ad4` → `c9042bf`)

User batch (Persian): «بخش قبله کامل بررسی کن … حرکت دایره قبله صحیح نیست…
شرق/غرب و درجهها بهتر کن» + settings «بوکسها بزرگ هستند زیباترشون کن …
تمامی موارد بررسی و یکدست کن» + «اگر بازم چیزی مانده در بخش بیشتر اصلاح کن» +
«ویجت تسبیح را زیباتر کن». Six commits; **not built** («فعلا بیلد نزن»), no
device attached.

- **Qibla** (`76f9ad4`, cleanup `5495190`): the «حرکت صحیح نیست» root was the
  needle geometry — the badge orbited at r≈24 with its arm to r≈46 on the
  opposite side, so the sweep read inverted. Badge now rides r=60 on a slim
  3-wide arm (r≈6→39); cardinal labels 11 w700 gold, bearings 9 w600 with «°»;
  smoothing is continuous `(0.10 + δ·0.02).clamp(0.10, 0.50)` and the distinct
  filter moved 0.7→0.5. The full review read the page, compass card, dial and
  math end to end; the dead empty `qibla_info_card.dart` part file deleted.
  Dial test 6/6, prayer 387/387.
- **Settings kit** (`74126df`): `_FlatTrackShape` solid heroGold, solid segment
  pill, solid WarningCard; stepper 30h / 17px glyphs / 34 min width with
  `dsContentColor` glyphs; the 44dp hit zones kept. 5 goldens re-recorded
  individually (day, day-320, night, prayer day/night).
- **More** (`1037e18`): the deep-search rows' owner ink → `dsContentColor`
  (raw accents can sit under 3:1 as text); 5 `more_content_*` goldens
  re-recorded. No other leftovers found in the page.
- **Tasbih** (`d1cc3c9`): accent idle reset (0.10 fill / 0.80 glyph), badge
  0.62, caption scales natively (clamp 7–11sp, preview mirrored). JVM widget
  suites 38/38 + `test/android` scans + adhkar + widget-settings 141 green.
- **Drive-by** (`c9042bf`): the one analyzer warning at HEAD
  (`flat_section_chrome_test.dart`'s unused `theme.dart` import) removed.
- **Suite at `d1cc3c9`**: `--exclude-tags network` = 3934 passed / 1 failed —
  the single red is the pre-existing `prayer_times_card_test` hayz case
  (the `c9042bf` import removal cannot change it; that scope re-ran green).
  Analyze 0 errors / 0 warnings (108 pre-existing infos, none in this batch's
  files); strict gate 7/7; `design_consistency.py` OK. No device — visual
  verdict pending a build carrying these commits.

## Home: the Friday adab card is always fully open (`fec4abe`)

User (Persian): «اداب وفضایل روز جمعه بنظرم وقتی میاد کلا بلز باشد و نوشته بستن
حذف کن همچنین نوشته 6 اداب مستحب هر کدام با حدیث .. اینم حذف شود».

- **The card-level «بیشتر (2 آداب)»/«بستن» expander is deleted** — all six
  adabs render in place from the first frame.
- **Each row's `ExpandableText` (maxLines: 2 + per-row «بیشتر»/«بستن») became a
  plain `Text`** — the detail + hadith + source are never behind a tap either.
  `FridayContent` is untouched and the share text still carries every adab, so
  the «Content is never summarised» invariant is strengthened, not weakened.
  The header's «۶ آداب مستحب، هر کدام با حدیث و منبع» subtitle is gone.
- **Goldens re-recorded** (`--update-goldens`, then byte-checked via
  `git status`): only `home_friday_day.png` + the four full-page baselines
  changed (the pinned clock is a Friday). Card tests 9/9; home scope 116 green
  + the known pre-existing hayz red; analyze 0 / format 0 on both files.
  **No device attached, not built** («فعلا بیلد نزن») — the look is the user's
  verdict on the next build.

## صحیح الترغیب: false «ناموفق», the attribution, legacy honorifics — schema v2 (`72f8f06`)

User report: دانلود said ناموفق although the file was on disk; the شرح line
carried ریاض الصالحین's author; the Arabic text rendered the publisher's
honorific glyphs as tofu. Three fixes, plus one landmine found while fixing
them.

- **False failure root cause**: `downloadFile` wrote the decompressed DB, then
  `tmp.delete()` threw into the outer catch → null → the caller threw
  «دانلود دادهٔ … ناموفق بود» while the file sat on disk. The cleanup is now
  non-fatal (logged) and `DownloadedSqliteDbService.download` re-checks
  `ContentDownloadService.isDownloaded(path)` before reporting failure.
- **Screen flow**: download → `_openAndLoad(retries: 1)`; only after that
  fails does the calm `_reenterNotice` show — the red slot stays reserved for
  genuine download failures. Ctor seam `TaraghibScreen({service})`;
  `_checkDatabase` clears `_dbError`/`_dbNotice` on entry.
- **Attribution**: title «صحیح الترغیب و الترهیب» / subtitle «علامه منذری ·
  تخریج علامه البانی · ترجمهٔ شیخ موسی بازماندگان» / chip 440 باب; riyad's
  العثیمین line verified correct and untouched.
- **Schema v2 repair**: `legacyHonorificSymbols` (F0C9/F072/F092 → صلوات،
  F0B8 → dual، F0C3 → عنه، F0CF → عنها) + `legacySymbolOrnament` (F05D,
  deleted) + `repairLegacyHonorifics` (public, `@visibleForTesting`, `same()`
  fast path, idempotent, glue padding, double collapse, ابن عمر typo) +
  `_repairLegacyHonorificSymbols(db)` from `migrateHadithSchema` before the
  normalized backfill; `hadithSchemaVersion` 1 → 2; own try/catch;
  PRAGMA-guarded columns.
- **The FTS landmine**: the v1 backfill never populated the index (an
  external-content SELECT reads the CONTENT table, so NOT IN was always
  empty — proved with a probe script). Search has always run on the complete
  LIKE path. The repair is the first-ever `hadiths_fts_au` write, so the
  migration clears the index again (delete-all, guarded by `rows.isNotEmpty`
  + sqlite_master) — a partial index would make `_ftsHadiths` short-circuit
  and hide complete results. A real rebuild = search-semantics decision
  (ال-prefixed forms) — reported, not taken; pinned empty by the migration
  test.
- **Prepared DBs — then uploaded (2026-10-16, user request)**: `Desktop/tawheeed-fixed-dbs/` —
  taraghib.db.gz 1,471,130 B sha1 f0e5d949… (959 hadiths + 3 chapters),
  ryadalsalihin.db.gz 2,810,690 B sha1 2dc9cf23… (6 hadiths); rebuild script
  rerunnable at `%TEMP%/opencode/rebuild_fixed_dbs.py`. The user asked for the
  upload to the content repo: `TAWHEED-EWAZ` `main` commit `9f01839` (parent
  `c916e70`) replaces both files with exactly these repairs — verified live via
  the API (sizes + blob shas) and raw.githubusercontent (sha1 byte-identical);
  the replaced live files were the repair bases byte-for-byte. v2 still covers
  installed devices.
- **Proof**: hadith + taraghib + riyad 72 green (10 + 2 + 5 new cases);
  analyze 0/0 on the touched scope; strict gate 7/7; design ratchet OK;
  encoding guard 2/2. `taraghib_screen.dart` was already format-dirty at HEAD
  (verified against the HEAD blob) — left unformatted per the standing rule.
  **No device attached, not built** («فعلا بیلد نزن») — visual verdict pending
  a build carrying `72f8f06`.

## علوم اسلامی on the flat kit — six distinct category hues, per-science accents (`cec4226`)

User request (Persian): the whole علوم اسلامی section (hub + inside every
science) must follow the new flat design, and علوم تاریخی needs its own
suitable colour («اکمل» = apply it). 12 files, net −1 widget (the dead
inline-search path outweighs the new test).

- **The colour decision**: `categoryVisuals[historical]` was `#283593` — the
  byte-identical value of the moon section's colour — and `deductive`
  `#5C6BC0` made a second indigo. Picked **آجری `#BF360C`** (deep orange 900,
  the درر token family): distinct from every other category and evocative of
  clay/manuscript.
- **science_detail_screen**: header → `TabIntroCard(icon:
  glyphOf(category), accent, title, subtitle: category.label)`;
  `_buildComingSoonBanner(context, accent)`; all six sub-sections take
  `accent: accent`; AppBars 16/w500; `_buildHeader` lost its unused context
  param.
- **Sections gain `accent` (default `SciencesContent.accent`)**: chapters
  (the old `int accentColor`/`_baseAccent` is gone), evidence, branch, term,
  faq (icon + chevron), related (icon + chip fill/border/label; emoji →
  `Icon(glyphOf(s.category))`).
- **science_card**: the «به‌زودی» badge moved from module indigo to the
  tile's own `accent`.
- **sciences_home_screen**: deleted `_searchQuery`/`_searchController`/
  `dispose`/`_filteredSciences`/`_buildSearchResults`/`_findSnippet` (both
  search entries already opened the delegate, so the inline path was
  unreachable); `_showSearch` is one `showSearch` call; AppBar title adds
  `fontSize 16 / w500`; delegate rows lead with the category
  `DuotoneIconTile` under a `Semantics(label: s.title)` and the badge wears
  the category accent.
- **What stays**: the chapter 10-hue `_palette` (flat, colour-codes chapters
  of a long treatise), the semantic red of common-mistakes and success of
  application, and the hub hero.
- **Guards**: `sciences_flat_design_test.dart` — intro accent+glyph,
  ChaptersSection/RelatedSciencesSection accents for `islamicHistory`
  (`scrollUntilVisible` for the lazy list), hourglass colour +
  evidence/branch/term/related accents for `shafiiMadhhab` at a tall
  viewport, the hub AppBar w500 + `scaledFontSize` equality, the delegate's
  first `DuotoneIconTile` accent and `findsNothing` for the first science's
  emoji, plus a source scan that no sciences file contains `Text(s.icon`.
  `sciences_registry_test` gained the six-distinct + `#BF360C` pins.
- **Proof**: education 50/50 green; analyze clean on the scope; strict gate
  7/7; design ratchet OK (net-zero raw counts); encoding guard 2/2.
  `science_detail_screen.dart` and `related_sciences.dart` were already
  format-dirty at HEAD (their HEAD blobs fail `dart format` too) — left
  unformatted per the standing rule; the new test file is format-clean.
  **No device attached, not built** — visual verdict pending a build
  carrying `cec4226`.

## Settings/More de-duplication — the four More-owned doors left the settings page (`ffec477`)

User decision (2026-10-17): a settings row whose destination already lives on
«بیشتر» must not stay as a second door — More is the preferred home. Four
doors moved for good; 17 files (2 lib, 5 tests, 10 goldens).

- **settings_screen.dart −31 lines**: the «حساب و پشتیبان» section (its one
  account tile) deleted; the three «سایر» rows «ارسال پیشنهاد»، «پیامهای
  مدیریت» و «درباره برنامه» deleted — «سایر» keeps only «بهینهسازی باتری».
  The page is 7 sections.
- **more_registry.dart +11**: new `announcements` item in `MoreGroup.app`
  (`Icons.campaign_rounded`, `TopicHues.reminders` — the message family it
  shares with suggestions), between `backup` and `suggestions`; registry
  42 → 43 (14/11/3/10/5).
- **Kept on purpose**: the settings search registry (`main.account`,
  `main.suggestions`, `main.announcements`, `main.about`) — search is a
  finder that pushes those pages directly, not a page row.
- **Guards/pins**: settings no-duplicates test (the four labels must stay
  absent); the audit `navTitles` 11 → 7 and its representative pushes now tap
  widget/notifications instead of about/account; More mini tiles 4 → 5 + the
  new caption; registry split + `containsAll` gained announcements.
- **Goldens**: the 7 More full-page baselines re-recorded at the MEASURED
  content heights (a temp `golden_page_fit` probe; the old fixed
  2084/1884/1952/2108 were stale — 320/360/1.3 clipped 16/7/43 px, 412 had
  ~10 px slack) → now 2074/1900/1960/2151. The 3 settings baselines
  re-recorded shorter (412dp page 2565 → 2201).
- **Proof**: settings (all — incl. the 29 golden-file cases) + home + search
  + announcements green except the known pre-existing `prayer_times_card`
  hayz red; scoped analyze 0 issues; strict gate 7/7; design ratchet OK;
  encoding guard 2/2. **No device attached, not built** («فعلا بیلد نزن»).

## Release APKs from `41c477d` — the build the phone now carries (2026-10-17)

«ریلیس بیلد» request (user picked release over debug by number), then approved
installing it on the attached phone. Built from a clean detached worktree
`%TEMP%/opencode/rel-build-1.8.0-41c477d` at the branch tip — four gitignored
files copied in, no dart-defines (Sentry OFF), `pub get` first: fat
`app-release.apk` 47,534,333 B (sha1 `c1f46a6d…`), `arm64-v8a` 31,550,594 B
(`e857674e…`), `armeabi-v7a` 31,812,820 B (`5eeb7dcd…`); Gradle 414.8 s +
80.8 s; `version: 1.8.0+10015`. Durable copies + `SHA1SUMS.txt` +
`BINARY_PROOF.txt` (RESULT: PASS — 20/20 correct forms incl. «آداب و فضایل روز
جمعه»، «علوم تاریخی»، «صحیح الترغیب و الترهیب»؛ removed/mojibake ABSENT؛
`splash_icon_none`): `Desktop/tawheeed-release-apks/1.8.0-41c477d/`.

- **Carries every commit through `41c477d`** — it supersedes every older 1.8.0
  set on disk, and answers the «visual verdict pending a build carrying …»
  notes above (the on-device verdicts themselves are still owed).
- **Installed on the phone 2026-10-17 05:34** with `adb install -r -d`. The
  previous test install carried `2000012019` — a higher transient code — so a
  plain `install -r` refused (`INSTALL_FAILED_VERSION_DOWNGRADE`); **`-d`
  succeeded anyway (Android 16) and the data was preserved.** Never
  `uninstall` to work around a downgrade — try `-d` first. Observed codes of
  this set: fat `2000010015`, armv7 `2000011015`, arm64 `2000012015` (the
  `+10015` line + Flutter's per-ABI offset 0/1 000/2 000). Launch verified
  (app process up; crash buffer clean for this app).
- **The settings/More de-dup (`ffec477` + its docs `75a8c01`) landed while this
  build ran** — this APK predates them; they ride the next build.

## ۱۰۸ info آنالایزر → ۰، و بمب تاریخی گارد حفظ — 2026-10-17 (`30004dc`, `a16f34e`)

- **جاروب (`30004dc`، ۳۲ فایل):** ۳۱ فایل با `dart fix --apply` (۷ lib + ۲۴
  test) و یک اصلاح دستی در `android_manifest_queries_test.dart` (بکتیک دور
  `<queries>` — تنها قاعده‌ای که fixer ندارد؛ تنها info باقی‌ماندهٔ پس از
  اجرا همین بود). هر آرگومان حذف‌شده با دیفالت سازنده‌اش تطبیق داده شد؛
  دیفالت‌های کلیدی از سورس خوانده شد (AppSettings، SliderRow ‏0/100،
  ValueStepper.step 1، GeoFormat.degrees رقم ۱، DsSpacing.page ۱۰،
  TasbihWidgetPreview، ZakatPriceState).
- **۴ هانک در سه فایل محافظت‌شده** (زیر مجوز «۱۰۸ را اصلاح کن»؛ قابل
  برگشت): `main.dart` دو آکولاد، `app_database.dart` تک‌کوتیشن خط ۵۶۸،
  `zakat_price_provider.dart` حذف `refreshFailed: false` پیش‌فرض.
  `kit_phase_golden_test.dart` هم به سبک دو-در-خط قبلی برگردانده شد.
- **اثبات:** analyze = **۰ مشکل** (لاگ‌های قبل/بعد + دیف کامل در
  `%TEMP%/opencode/`)؛ `quality_check --strict` ۷/۷؛ `design_consistency`
  OK؛ گارد انکودینگ سبز. سوییتِ ورک‌تری تمیز روی `30004dc`: **۳۹۴۸ قبول /
  ۹ اسکیپ / ۲ رد** — hayz شناخته‌شده + تست حفظ.
- **تست حفظ — بمب تاریخی (`a16f34e`، فقط تست):** از ۱۷ اکتبر در همه‌ی
  درخت‌ها رد می‌شد — هدر انتخابگر هفته (`hifz_screen.dart:875`) در فونت
  تست ۹.۸px سرریز می‌کرد، چون هفته از مرز ماه جلالی می‌گذرد و برچسب بلند
  می‌شود. **پیشینه‌دار اثبات شد:** همان سرریز روی `4274ed3` (آخرین سوییت
  همه‌سبز) هم امروز رخ می‌دهد و نه صفحه و نه تست از آن زمان عوض شده‌اند.
  اصلاح سمت تست: لود Vazirmatn مثل همسایه‌ها + فونت اپ روی تم `insetApp`
  (`ThemeData(fontFamily: AppTheme.fontFamily)`) — نیمهٔ گمشده، وگرنه فونت
  لودشده به `TextStyle`های خام نمی‌رسد. ورک‌تری تمیز روی `a16f34e`: فایل
  ۷/۷ و **exit 0**. سوییت پس از آن: **۳۹۴۹ / ۹ / ۱** — تنها قرمز باقی‌مانده
  hayz است. فشردگی نهفتهٔ ۳۲۰dp × مقیاس ۱.۳ در همان ردیف برای تصمیم کاربر
  گزارش شد.
- **گزینه‌ها:** FTS + fallback به LIKE و حیض فقط گزارش شدند؛ منتظر انتخاب
  شماره‌دار کاربر — عمداً چیزی تغییر نکرد.

## واجراژن‌کد اندروید منجمد شد — ۲۰۲۶-۱۰-۱۷ (`9be7687`, `67fe327`)

- **درخواست کاربر:** «نمی‌خواهم شماره زیاد بزرگ بشود … هر اولا شماره تغییر
  نکند مگر در بیلد نهایی قبل از نشر و شماره در حد یک تا ده بالا برود».
  پیش‌تر `+code` در `pubspec.yaml` (و `--build-number`) کد را در **هر** بیلد
  جابه‌جا می‌کرد.
- **تک‌منبع اکنون `android/app/build.gradle.kts` است:**
  `val FROZEN_VERSION_CODE = 2_000_012_020` و در `defaultConfig`
  `versionCode = FROZEN_VERSION_CODE`؛ `flutter.versionCode` دیگر کد نمی‌دهد و
  `--build-number` بی‌اثر است. `versionName` همان `pubspec` می‌ماند (UI هنوز
  «۱.۸.۰» می‌گوید). افزایش فقط ۱..۱۰ قبل از نشر.
- **آفست اسپلیت‌ها حفظ شد:** AGP خودش `base + 1000` (armv7) و `base + 2000`
  (arm64) می‌سازد — با `aapt2` روی ستِ `28a76d0` اثبات شد (فت `2000012020`،
  armv7 `2000013020`، arm64 `2000014020`)؛ مقدار صریح قبلی برای armv7
  (`1_000_012_020`) عملاً نادیده گرفته شده بود و باز هم `base+1000` در آمد.
  بلوک `onVariants` حالا دقیقاً `FROZEN`/`+1000`/`+2000` می‌گذارد که در هر دو
  تفسیر درست است و هرگز دوبار جمع نمی‌شود.
- **کف نصب‌ها:** `2_000_012_020` بالای `1.7.1` منتشرشده (`2_000_010_013`) و
  `1.7.0` مستقیم (`2_000_004_000`) است. arm64 اسپلیت این پایه
  (`2_000_014_020`) برابر نصب فعلی گوشی است و پاک جایگزین می‌شود؛ **فت** پایین‌تر
  است و یک‌بار `adb install -r -d` لازم دارد (هرگز uninstall نکنید).
- **دو کانال، یک کد:** هیوریستیک قبلی «`≥ 2_000_000_000` ⇒ مستقیم» کافی نیست؛
  `update_checker.dart` حالا `String.fromEnvironment('APP_CHANNEL')` دارد و
  `isDirectBuild()` روی `play` غلط، روی `direct` درست، وگرنه کف `_directCode`
  را نگه می‌دارد. **AAB گوگل‌پلی باید با `--dart-define=APP_CHANNEL=play`
  ساخته شود.** تنها سازندهٔ AAB، استپِ `appbundle` در
  `.github/workflows/ci.yml` بود که این تعریف را نمی‌داد؛ حالا می‌دهد
  (`2c14933`) تا هیچ آرتیفکتی از CI برخلاف قاعده گرفته نشود. بیلدهای مستقیم
  (`tools/prepare_update.ps1` و `tool/build_release.ps1`) چیزی پاس نمی‌دهند و
  درست است (پیش‌فرض `direct`).
- **ابزارها:** `tools/check_release_version.py` ثابت گریدل را می‌خواند
  (کدهای دستگاه `+1000`/`+2000` پذیرفته)، قبل از downgrade هشدار می‌دهد و
  `--fix` ثابت را یک واحد بالا می‌برد؛ `tools/prepare_update.ps1` همان ثابت را
  به `revision` می‌دهد. مستندات: `docs/versioning.md` (طرح دو-شمارنده در
  `3a26a60` منسوخ شد)، `docs/APP_UPDATE_GUIDE.md`، `content/app/README.md`.
- **گارد:** `test/android/version_code_scheme_test.dart` — اگر تخصیص از ثابت
  برود، `flutter.versionCode` یا عبارت `20 * 100_000_000 +` برگردد، مقدار به
  کف برسد، یا آفست اسپلیت‌ها از ثابت جدا شود، رد می‌کند.
- **اثبات این پاس:** آن تست + `update_checker_test` = ۲۱ سبز؛ analyze روی فایل‌های
  دست‌خورده = ۰؛ `check_release_version.py` = OK؛ parse هر دو اسکریپت OK.
- **بیلد و اثبات باینری (`67fe327`):** ورک‌تری تمیز، چهار فایل gitignore کپی، بدون
  dart-define (Sentry خاموش): فت `47,538,684` بایت sha1 `d0eef5a8…`، arm64
  `31,554,903` (`dc89c6f0…`)، armv7 `31,814,017` (`a3240969…`); Gradle ۲۵۷.۵s +
  ۲۶.۷s (اسپلیت با exit 1 ولی هر دو ساخته شد — گاتچای همیشگی).
  **versionCode ثابت‌ها با aapt2 تأیید شد:** فت `2000012020`، armv7 `2000013020`،
  arm64 `2000014020`. **اصلاح polling نسخهٔ v31 (`f8780d6`) داخل باینری است:**
  `aapt2 dump xmltree` روی مسیرهای واقعی از `dump resources`
  (`res/nk.xml` = `xml-v31/widget_tasbih_info`، `res/8s.xml` =
  `xml-v31/widget_prayer_info`) مقدار `updatePeriodMillis(0x01010250)=0` را نشان
  می‌دهد — پس اندروید ۱۲+ دیگر هر ۳۰ دقیقه پروسه را بیدار نمی‌کند. `BINARY_PROOF`
  = **PASS** (۲۰/۲۰ درست، mojibake/حذف‌شده ABSENT، `splash_icon_none`).
  کپی‌های ماندگار: `Desktop/tawheeed-release-apks/1.8.0-67fe327/`.
  **`adb devices` خالی بود** پس نصب/تأیید روی گوشی انجام نشد؛ arm64 اسپلیت
  (`2000014020`) برابر نصب فعلی است و پاک جایگزین می‌شود، فت `-d` می‌خواهد.
- **در نشر بعدی، `revision`/`versionCode` باید از هر دو بیشتر باشد** (گوشی
  `2_000_014_020` و کاربران `1.7.1` با `2_000_010_013`) ⇒ اولین نشر
  `2_000_014_022` (یا هر مقدار در `+1000..+2000` روی همان خط).

## بستر حیض + FTS سه‌گانهٔ حدیث + برچسب حفظ — ۲۰۲۶-۱۰-۱۷ (`22339e2`، `3a080c5`، `b2956b1`)

کاربر دو مجموعهٔ گزینهٔ شماره‌دارِ `30004dc`/`a16f34e` را تفویض کرد: «هر کدام
بنظرت مناسب هست انجام بده». هر دو نیمه رفت و سخت‌سازی برچسب حفظ هم آمد.

- **حیض (`22339e2`):** `PeriodHayzBanner` پارامتر اختیاری `now` گرفت و کارتِ
  نماز `now` خودش را می‌دهد — پنجرهٔ بسته‌نشمارده دیگر ساعت واقعی دیوار را
  بازبینی نمی‌کند؛ تست کارت («a hayz day shows the banner…») و گولدن‌ها
  قطعی شدند. `period_provider.dart` (محافظت‌شده) دست نخورد.
- **حدیث — FTS سه‌گانه (`3a080c5`):** دو پروب یک‌بارمصرف روی موتور بسته‌بندی
  (SQLite 3.53.2) ثابت کرد: `LIKE '%…%'`ِ سروشده از ایندکس دقیقاً همان
  سطرهای اسکن ساده را می‌دهد (کاندیدها در برابر خود مقدار بازبینی می‌شوند —
  تلهٔ «اب‌سی‌دی‌اف» پراکنده رد شد)، الگوی کوتاه‌تر از سه حرف به همان اسکن
  برمی‌گردد، و JOIN تولیدی با فیلتر کتاب/درجه دقیق است. اما ایندکس خالی
  پاسخ «هیچ» می‌دهد ⇒ **rebuild-or-drop**: `hadithSchemaVersion` ۲→۳،
  حذف/ساخت جدول unicode61 با `tokenize='trigram'`، `('rebuild')` در پایان
  هر پاسِ مهاجرت؛ شکستِ rebuild کل جدول را می‌اندازد تا جستجو به اسکن
  کاملِ LIKE برگردد (هرگز ایندکس ناقص نمی‌ماند).
  `searchArabic`/`searchHadiths` از `_ftsHadithsByLike` می‌روند و دو هلپر
  MATCH حذف شدند — شکاف دقت پیشوندی یونی‌کد۶۱ (فرم‌های «ال»-دار که
  token-prefix پیدا نمی‌کرد) بسته شد. delete-all داخل تعمیر صلوات
  (superseded by آن rebuild پایانی) حذف شد. باتری گارد: تلهٔ hits-only،
  برابری سطرِ سرویس == اسکن ساده در تیرهای لاتین/عربی/چندکلمه‌ای و سه طول
  اجرا (۶/۳/۲)، ترکیب book+grade روی مسیر ایندکسی، تریگرها با محمولِ
  سروشده، init ایندکس پُر (نه خالی) می‌گذارد، و هر دو تست مهاجرت
  برابری مجموعه‌ای ایندکس == محتوا را روی متنِ تعمیرشده می‌بندند.
- **برچسب حفظ (`b2956b1`):** `Text` لخت بین دو فلش هفته فرزند انعطاف‌ناپذیر
  بود؛ در هفتهٔ عبور از مرز ماه (بلندترین فرم برچسب) ردیف سرریزِ ۹٫۸pxِ
  فونتِ بایندینگ (`a16f34e`) و فشردگی ضمنی ۳۲۰dp/۱٫۳ روی گوشی واقعی داشت.
  رسپ مخزن: `Flexible` در سطح `Row` + `FittedBox(scaleDown)`. گارد: تست
  تعداد ضربهٔ دقیق تا هفتهٔ عبور مرز را از تقویم جلالی می‌شمارد (رسمیِ
  محض ⇒ قطعی)، در ۳۲۰dp/`TextScaler.linear(1.3)` با وزیرمتنِ واقعی رد
  می‌کند و «بدون استثنا + FittedBox بین دو فلش» را می‌بندد — و **گاز
  می‌گیرد** (بازگرداندن `Text` لخت ادعای ساختاری را قرمز می‌کند؛ در متریک
  فونت واقعی برچسبِ قدیمی ممکن است بی‌سرریز بگذرد، پس ادعای فیت تنها هرگز
  نمی‌گازید).
- **اثبات:** حوزهٔ حدیث ۵۴/۵۴ (+ جستجو و گارد انکودینگ ۳۰ سبز)، حفظ
  ۳۹/۳۹، کارت/بنر خانه ۱۶ سبز؛ `flutter analyze lib test` ۰؛
  `quality_check.py --strict` ۷/۷؛ `design_consistency.py` OK. بیلد نشد
  («فعلا بیلد نزن»).
- **پانوشت تصمیم FTS:** اندازهٔ ایندکسِ بازسازی‌شده روی پایگاه‌های بزرگ
  «کتب حدیث» با APK بعدی می‌نشیند (فقط حجمِ داده‌ی کتابخانهٔ دانلودی،
  بدون گیت بودجهٔ دارایی‌ها)؛ مهاجرت v3 در همان آپن اولِ کتاب، داخل
  schema-worker isolate.

## ۲۰۲۶-۱۰-۱۷ — کارت «اذان و اقامه هر نماز» (طرح الف) روی `settings/per-prayer-card`

شش کامیت (`7928729` جابجایی‌ها و زمان‌بندی، `383d51a` صدای هر نماز، `c796341`
خواب‌بندِ استپر، `3453d47` اصلاحِ قرص ارزش، `d5c19a8` خودِ کارت، `7b60014`
بزلاین‌های صفحه) ری‌بیسِ تمیز روی نوک `5041485`. گزارش کامل:
**`docs/PER_PRAYER_CARD_REPORT.md`**.

- **قرارداد a/c (قابل شکستن نیست):** خاموش‌کردن اذانِ یک نماز **فقط چیپِ صدا**
  را کم‌رنگ و غیرفعال می‌کند (فلتِ `textMuted` — هرگز `Opacity`)، صلوات
  انتخابی **حفظ** می‌شود، نام و آیکنِ هویت همیشه پررنگ می‌مانند و خط وضعیت
  ( accent «پخش اذان فعال» / کمرنگ «اذان خاموش · زمان و اقامه همچنان اعمال
  می‌شود») تنها صدای وضعیت است؛ دو شمارنده در OFF کامل‌رنگ و کار می‌کنند و
  واقعاً زمان‌بندی را دوباره می‌چینند (`7928729` از همان درهای debounce).
- **چیدمان:** سه‌ستونه فقط با پهنای حجرهٔ شمارنده ≥۱۲۴ و چیپ ≥۷۸ (عناصر
  ۱٫۱۵:۱:۱، فاصله ۶)؛ وگرنه دو ردیف؛ پایین‌تر انباشت. ۴۱۲ در حالت دو-ردیفی
  می‌نشیند — در طلایی‌ها پین شده.
- **صداها:** `PrayerAzanSoundStore` (`azan_sound_<slot>`، غیاب = ارث از
  سراسری)؛ `alarmSoundFor` در کل مسیر هشدار، و اثر انگشت زمان‌بند پنج کلیدِ
  خام را حمل می‌کند. درهای نوتیفایر: `setEnabledAt/setShiftAt/setIqamahAt/
  setAzanSoundFor/clearAzanSoundFor/setIqamahOffsetsUniform/
  resetPrayerAdhanSection` — هیچ bypassی از `SettingsNotifier`.
- **عملیات گروهی اسنپ‌شات را «قبل از» نوشتن** می‌گیرد (نسخهٔ اول بعد از
  نوشتن می‌گرفت؛ تست «واگرد» گاز می‌گیرد)؛ «بازنشانی» به سوییچ و صدای
  سراسری دست نمی‌زند.
- **گازِ استپر که بسته شد:** `c796341` حجرهٔ ارزش را عرض TIGHT ۳۴ داد در
  حالی که قرص قدیمی LOOSE-min بود — ارزش پهن («۳۰ دقیقه») داخل قرص می‌شکست و
  طلایی صفحهٔ اصلی تنظیمات ۰٫۱۶٪ (۱۴۱۳px در نوار ۳۱×۹۶) کج می‌شد؛
  `3453d47` بازگرداند و **صفحات اصلی بیت‌به‌بیت همان ماندند** — بزلاین اصلی
  دوباره ثبت نشد. **دیگر هیچ‌وقت حجرهٔ ارزش استپر را تنگ نکنید.**
- **پارچهٔ تست:** هارنسِ مستقل کارت (`per_prayer_card_pump.dart`) مثل صفحه
  `settingsProvider` را در `_CardHost` نگاه می‌کند تا نوشته‌ها دیده شوند،
  کارت را در `SingleChildScrollView` می‌پچاند (سرریز واقعی ۱px در ۸۰۰dp) و
  از روی `RepaintBoundary('golden-card')` عکس می‌گیرد؛ مقیاس متن با
  `bodyMedium×scale` (چیزی که `scaledFontSize` می‌خواند) نه `textScaler`.
  السمِ چیپ در سطح ویجت (`Semantics.properties.label`) ادعا می‌شود چون
  درخت، tooltip داخلی را ادغام می‌کند؛ هر تستِ لمسی ~۵۰۰ms پامپ می‌کند و
  تایمرباوقه نمی‌ماند.
- **اثبات:** کارت ۱۰/۱۰، صفحه ۱۶/۱۶ (ماتریس ۳۲۰/۴۱۲×۱٫۰/۱٫۳)، طلایی کارت
  ۶/۶ (on/one_off/all_off/two_row@۳۲۰/scale13/night — دقیقاً فقط چیپ
  کمرنگ)، دامنهٔ نماز ۴۱۱/۴۱۱، تنظیمات سبز با دو بزلاین
  `prayer_settings_day/night` که فایل‌به‌فایل دوباره ثبت شدند؛
  `flutter analyze lib test` ۰؛ `quality_check.py --strict` ۷/۷؛
  `design_consistency.py` OK؛ گارد انکودینگ سبز.

## ۲۰۲۶-۱۰-۱۷ — رفع کندی ۲۰ ثانیه‌ای بعد از باز کردن برنامه (R1 تا R5)

گزارش کاربر: «تا حدود ۲۰ ثانیه برنامه کاملا لاگ دارد و اسکرول صفحات کند است، بعد
اوکی می‌شود». اندازه‌گیری روی گوشی متصل (`4XQCWGBQLVZXTOAE`، اندروید ۱۶) علت را
پیدا کرد: **رندرینگ نبود**. یک پاس بوت ~۳۲۸ فراخوانی `setAlarmClock` را یکی‌یکی
منتظر می‌ماند و هر `MethodChannel` روی **ترد اصلی اندروید** اجرا می‌شود — پس
۱۴٫۵ ثانیه اشباع ترد UI. پنج اصلاح اعمال شد (مورد ۶ — `tzdata` — درخواست نشد و
اضافه نشد). شرح کامل: `docs/NOTIFICATION_RELIABILITY.md` §8.

- **R1 — یک دسته، بیرون از ترد اصلی.** `NotificationService` همهٔ عملیات نیتیو
  (`arm`/`cancel`/`cancelRange`) را در `batchNativeReminders` جمع می‌کند و با یک
  `applyReminderOps` + `opsJson` می‌فرستد؛ `MainActivity` هر هفت متد کانال
  reminders را با `replyAsync` روی یک `HandlerThread("reminder-alarms")` FIFO
  پاسخ می‌دهد (`quitSafely()` در `onDestroy`، پاسخ با `runOnUiThread`). عمق
  تودرتو شمرده می‌شود: فقط خروج بیرونی‌ترین فلیش می‌کند و مجوز exact alarm
  **هر دسته یک‌بار** پرسیده می‌شود.
- **R2 — آرمی که چیزی عوض نمی‌کند، هزینه ندارد.** `applyOps` درخواست در انتظار را
  فیلد‌به‌فیلد مقایسه می‌کند (`isArmCurrent` — `JSONObject` پشتش HashMap است، پس
  `toString()` هرگز قابل مقایسه نیست) و `"unchanged"` برمی‌گرداند. مُهرِ زمان
  **نسبت به بوت** است (`armed_at >= bootTimeMillis(now)`، `ARM_FRESH_MS = 6h`) تا
  مُهرِ قبل از ری‌بوت هرگز «تازه» حساب نشود. فقط آرمِ **ناموفق** شناسه‌اش را
  پاک می‌کند (`cancel(context, request.id)` روی `ArmResult.Failed`)؛ لغو کردن
  قبل از آرم، کار بیهوده بود.
- **R3 — فرستنده‌های بوت ادغام می‌شوند.** دست‌کم پنج فراخوان `scheduleIfNeeded`
  در ~۰٫۵ ثانیهٔ اول. `_request` در پنجرهٔ ۱۲۰۰ms بافر می‌گیرد و **یک** پاس با
  تازه‌ترین service/settings اجرا می‌کند؛ `force` (باززمان‌بندی دستیِ کاربر) فوراً
  فلیش می‌کند و تایمرِ در انتظار را لغو می‌کند، و درخواستِ force که پشت یک
  درخواست معمولی صف شده هم force می‌ماند. صف سریال است تا پاس‌ها در هم نروند.
- **R4 — شاخهٔ «چیزی عوض نشده» دیگر دوباره آرما نمی‌کند.** این شاخه هر بار کل
  صف روزانه را بازآرما می‌کرد؛ اکنون تا `reconcileInterval` (۲ دقیقه) و **با
  کلید خراشِ زمان‌بندی** محدود شده (`_markReconciled(fp)`). تغییر تنظیم هرگز دیر
  از آب درنمی‌آید، چون هر ورودیِ مؤثر در نوتیفیکیشن — تاریخ، منطقهٔ زمانی،
  `highLatitudeRule`، ارتفاع، هر iqamah — همین حالا داخل همان خراش است. مُهرِ
  آینده یا خراب همیشه «در وقت» حساب می‌شود.
- **R5 — برنامهٔ پیش‌زمینه دوباره از خودش بازسازی نمی‌خواهد.** `AppLiveness`
  (مُهر ۴ ثانیه) به `MainActivity` می‌گوید وقتی برنامه بالا است `needs_reschedule`
  را ننویسد؛ ردیورهای بوت و rollover همان را می‌نویسند و
  `rescheduleAllAfterBoot` + `scheduleDailyRollover` را همچنان اجرا می‌کنند. این
  فقط یک **فلگ** را خاموش می‌کند، هرگز چیزی را از زمان‌بندی حذف نمی‌کند.

- **دقت، همان قیدی بود که کار را قید می‌کرد:** هیچ‌یک از اصلاحات یادآوری را نمی‌اندازد.
  `setAlarmClock` با کلید `ID_OFFSET + id` و `FLAG_UPDATE_CURRENT` همان
  `PendingIntent` را جایگزین می‌کند، پس رد کردنِ R2 فقط ترافیک binder را کم می‌کند؛
  اگر فراخوانِ دسته‌ای خطا دهد، **هر عمل** تک‌تک از مسیر قدیمی
  (`scheduleReminder`/`cancelReminder`/`cancelRangeReminders`) دوباره تلاش می‌شود؛
  در پلتفرم غیراندروید اصلاً صف نمی‌شود؛ و شاخهٔ «زمان گذشته» پیش از بازگشت،
  آلارمِ نیتیوِ همان شناسه را لغو می‌کند تا آرمِ کهنه دوباره شلیک نکند.
- **تلهٔ پارچهٔ تست (اینجا پیدا شد):** `flutter_test` دستور `setUp` را **بیرون** از
  fake-async zoneٔ `runTest` اجرا می‌کند. سینگلتونی که زنجیرهٔ future معلق را نگه
  می‌دارد (`_scheduleQueue`) اگر در `setUp` کاشته شود، به ترد واقعی تعلق دارد و پاسِ
  زنجیره‌شده روی microtask queue واقعی تحویل می‌شود — که ساعت fake هرگز فلیشش
  نمی‌کند؛ نتیجه سکوت کامل و هنگ تا تایم‌اوت ۱۰ دقیقه‌ای فریمورک. **پس سم را همان
  اولین دستورِ داخل بدنهٔ تست** (`begin()`) بکار، نه در `setUp`. نکتهٔ دوم:
  `resetCoalescingForTest()` مقدار `passOverride` را هم پاک می‌کند، پس اگر آن را
  بعد از نصب استاب صدا بزنی، همان استاب را پاک کرده‌ای. `--timeout=Ns` هنگِ
  FakeAsync را نجات نمی‌دهد (آن تایمر هم fake است) — نگهبان را سمت shell بگذار
  (`timeout 100 flutter test …`).
- **اثبات:** `test/shared/services/daily_notification_scheduler_test.dart`
  ۱۰/۱۰ و `test/android/reminder_batch_test.dart` ۱۹/۱۹؛
  `ExactReminderOpsTest.kt` روی JVM؛ اسکوپ‌های `test/shared/services` +
  `test/android` + گارد انکودینگ **۱۴۰/۱۴۰**؛ `test/features/prayer` +
  `settings` + `home` **۸۸۰ سبز**؛ `reminders` + `worship` + `test/app`
  **۱۱۴/۱۱۴**؛ کامپایل gradle در دیباگ و ریلیس سبز با **۵۸ تست JVM، ۰ خطا**؛
  `flutter analyze lib test` ۰ خطا/۰ وارنینگ؛ `quality_check.py --strict` ۷/۷؛
  `design_consistency.py` OK؛ گارد انکودینگ سبز. **ریلیس بیلد زده نشد**
  («فعلا بیلد نزن») و اندازه‌گیری دوبارهٔ زمان راه‌اندازی روی گوشی هنوز مانده است —
  تا بیلد بعدی، این کد روی تلفن نیست.



## ۲۰۲۶-۱۰-۱۷ — پوستهٔ تنظیمات از رنگِ تم + اصلاح‌های عملکردی (`settings/accent-kit`)

مخزن بازبینی ۲۳موردیِ «رنگ‌ها و دیزاین تنظیمات» با تأیید کاربر اجرا شد («اینها همش
برام انجام بده اما رنگ ایکون های بیشتر تغییر نده»). شاخهٔ `settings/accent-kit` در
ورک‌تری ایزوله، پایهٔ `07c5e21`.

- **`AppPalette.accent`**: توکن هویتِ هر پالت — طلایی خودش در پالت طلایی، رنگِ فاز در
  چهار فاز زنده. کل پوستهٔ تنظیمات (نوار سربخش، اسلایدر، سگمنت، چیپ تم، رینگ ویجت،
  حاشیهٔ کارت اذان گروهی، آیکون ردیف‌ها + سه آیکون خام) روی آن سوار شد. `tertiary`
  طلای مقدس می‌ماند. انتخاب تم دیگر «حلقهٔ طلایی ثابت روی صفحهٔ آبی» نمی‌کشد.
- **یک رسپیِ آیکون**: DuotoneIconTile/IconTile/MoreDuotone روی همان پرکردن ۰x24/۲۵۵
  (همان عددی که `dsReadableGlyph` می‌سنجد)، حاشیهٔ ۰.۱۸، شعاع ۰.۳۲·S، گلیف نردبان
  خوانایی. **آیکون‌های «بیشتر» پیکسلی تغییری نکردند** (قید کاربر).
- **SettingsTokens ۱۲→۳ ثابت**؛ بقیه از پالت تم.
- **عملکردی**: reset/import تنظیمات + آفست طلوع ← `_rescheduleAlarms()`؛ حذف
  `setAccentPreset` و `PremiumCard` مرده؛ لنگر `prayer.adhanBulk` وصل شد.
- **ردشده‌ها و چرا**: حذف shim
  SectionHeader (۱۲۸ سایت/۴۴ فایل برای صفر سود بصری)، جدول‌های hue (زمینِ محافظت‌شدهٔ
  هویت «بیشتر»)، مهاجرت store اکشن‌های سریع (`settings_selectors.dart` محافظت‌شده)،
  بازنویسی seam زمان‌بند (ریسک دقت اوقات)، adoption کامل DebouncedWriter (ریسک مسیر
  درگ).
- **اثبات**: آنالیز ۰/۰؛ گیت سخت ۷/۷؛ رچت OK؛ گارد انکودینگ سبز؛
  `--exclude-tags network` = **۴۰۰۵ سبز / ۸ قرمز** — ۳ موردِ شناخته‌شدهٔ
  `google_sign_in` در ورک‌تری تمیز (google-services.json گیت‌ایگنورد است) + ۵ گلدن
  صفحهٔ تقویم که برای همین تغییر ضبط دوباره شدند و در اسکوپ ۵۰/۵۰ سبزند. ۵۰
  بازلاینِ گلدن (تنظیمات/درباره/بیشتر/خانه/کارت اذان/تقویم/کیت) فقط پیکسلی
  دوباره‌ثبت شدند. بیلد ریلیس: بخش «ریلیس» زیر.

## ۲۰۲۶-۱۰-۱۹ — پاس روی گوشی برای بیلد حسابرسی (`f8e6490`)

گوشی دوباره وصل شد و کارهای پارک‌شدهٔ بررسی روی دستگاه انجام شد. نصب با
`install -r` روی همان `versionCode` (`2000014020`، اسپلیت arm64) بود؛ **دادهٔ
برنامه حفظ شد و هیچ عملیات مخربی اجرا نشد** (تنها تعاملِ حذف، دکمهٔ «انصراف» در
دیالوگ پاک‌سازی بود).

- **A-01 — قبول:** `dumpsys notification` برای بسته **۱۱ کانال زنده** نشان می‌دهد
  (هفت کانال `_v3` + `custom_reminders_v2` + `general` + `prayer_times_v5` +
  `adhan_playback` نیتیو) و **۵ شناسهٔ قدیمی به‌صورت tombstone حذف‌شده**
  (`daily_azkar`, `daily_reminders`, `silent_mode`, `prayer_reminders`,
  `quran_reminder`). فهرست تنظیمات گوشی ۱۰ ردیف فارسیِ یکتا دارد؛ کانال پخش اذان
  را سیستم سامسونگ در آن فهرست نشان نمی‌دهد (فیلتر OEM، نه تکرار).
- **A-05 — قبول:** وضعیت زندهٔ Doze نمایش داده می‌شود («توحید در فهرست بهینه‌سازی
  باتری نیست») و هر دو دکمه به `Settings$AppBatteryUsageActivity` می‌رسند.
- **B-05 — قبول:** «مدیریت فضا» حجم `468.5MB` را در پنج گروه اندازه می‌گیرد، فقط
  ردیف‌های قابل‌دانلود دکمهٔ پاک‌کردن دارند و هر حذف، دیالوگ تأیید با نام و حجم
  («۱۰۱۷KB آزاد می‌شود») نشان می‌دهد؛ انصراف چیزی را پاک نکرد.
- **C-01 — قبول:** پنجرهٔ سیستم بدون آیکون (رمپ قهوه‌ای)، سپس سکهٔ بزرگ اسپلش و
  محو شدن به برنامه. زمان راه‌اندازی سرد `am start -W`: **۶۹۰ms** (اجرای دوم
  ۵۲۹ms) — بسیار پایین‌تر از تأخیر ۲ ثانیه‌ای loader و گارد ۱۲ ثانیه‌ای.
- **B-03 — محدودیت اندازه‌گیری، نه اصلاح:** روی بیلد ریلیس،
  `SurfaceFlinger --latency` برای لایهٔ Flutter فقط دورهٔ ۱۲۰Hz را برمی‌گرداند و
  `gfxinfo` فریم‌های Flutter را نمی‌بیند؛ تایم‌لاین واقعی به بیلد profile نیاز دارد
  و چون `buildTypes` فقط `release` را تعریف می‌کند، profile با کلید دیباگ امضا
  می‌شود و روی نصب ریلیس `install -r` نمی‌خورد (حذف برنامه ممنوع). اثبات این
  حلقه: زمان راه‌اندازی + اصلاح حافظهٔ B-02 (تست‌شده). پاس فریم‌به‌فریم نیاز به
  پچ محلی امضا با کلید ریلیس دارد و تصمیم جداگانه‌ای است.

## ۲۰۲۶-۱۰-۱۹ — B-03: ساختِ ایندکس جستجوی عمیق به ایزولهٔ کارگر رفت (`8bbe0f2`)

بیلد profile با پچ محلی امضا/شماره ساخته و نصب شد و تایم‌لاین VM گرفته شد.
جستجوی «در متن بخش‌ها» در «بیشتر» در **اولین کلیدِ ≥۲ کاراکتر** هر فرایند، هفت
راهنمای JSON را می‌خواند و کلید جستجو می‌سازد — روی رایانه (AOT) **۱۶۶٫۸ms** برای
۴٬۱۹۰ قطعه / ۷۸۵٬۶۷۹ کاراکتر (علوم اسلامیِ ۱٫۱۸ مگابایتی تنها ۱۴۲٫۸ms). این همان
انسدادِ فریم بود.

- **اصلاح:** خواندن JSON، latinize، پیمایش و ساخت کلیدها داخل `Isolate.run`
  (`buildGuideIndex`) انجام می‌شود و فقط `[titles, bodies, keys]` برمی‌گردد؛
  `_installFoldedKeys` نتیجه را نصب می‌کند تا ایزولهٔ UI دوباره کلید نسازد.
  خواندن asset روی ایزولهٔ UI می‌ماند. در `arabic_search.dart` دو RegExp از داخل
  تابع بیرون آمد و `normalizeSearchKey` پس از `normalizeForSearch` فقط همان
  فاصله‌های ASCII را حذف می‌کند — خروجی روی هر ۴٬۱۹۰ قطعه **بایت‌به‌بایت یکسان**.
- **اثبات روی گوشی (اپ profile):** با تایپ `ab` در صفحهٔ «بیشتر»، **۹ ایزولهٔ
  کوتاه‌عمر** هم‌زمان بالا آمدند — هشت‌تا ۱۰–۲۰ms و یکی **۱۵۰ms** (راهنمای علوم
  اسلامی) — و ایزولهٔ UI در همان ۱۸ ثانیه **۵۸ فریم، بیشینهٔ ۹٫۶۱ms و صفر فریم
  بیش از ۱۶٫۷ms** تولید کرد؛ نتیجهٔ «در متن بخش‌ها ۳» هم رندر شد.
- **صداقت اندازه‌گیری:** کپچرِ قبل از اصلاح مبنای معتبر نیست (فقط ۱ فریم در ۲۵
  ثانیه — کلید به فیلد نرسیده بود)، پس عدد «قبل» همان میکروبنج رایانه است، نه
  مقایسهٔ قبل/بعد روی گوشی.
- **بیلد profile:** `buildTypes` فقط `release` دارد؛ برای نصب درجای profile روی
  نصب ریلیس، پچ محلی (امضای profile با کلید ریلیس + بالابردن موقت
  `FROZEN_VERSION_CODE`) لازم بود و **کامیت نشده است**.
- **تست:** ۳۰/۳۰ (شامل خواندن واقعی `taharah.json` و `sciences.json` از مسیر
  ایزوله)، analyze صفر، گیت سخت ۷/۷.

## ۲۰۲۶-۱۰-۲۲ — روش عرضهٔ ماه: ایرانی / افغانی (`1413dcf`)

درخواست کاربر: کاربران افغانستان نام ماه‌های شمسی را «حمل، ثور، …» می‌خواهند؛
گزینهٔ انتخاب در تنظیمات اضافه شود. فقط **نام‌ها** عوض می‌شوند و حساب شمسی دست
نخورده است؛ همچنین کشیدگی جعبه‌های ویجت اوقات در همان درخواست با `120ad39` بسته
شد.

- **تنظیم pref-محور** (`month_display`، بدون ستون Drift و بدون migration) زیر
  «ظاهر برنامه»: ردیف «روش عرضه ماه» با دو گزینهٔ «ایرانی» / «افغانی» و پیش‌نمایش
  هر دوازده نام. جستجوی تنظیمات هم ایندکسش می‌کند (`main.month_display`).
- **یک منبع نام:** `DateConstants.persianMonths` حالا getter وابسته به نمایش است
  (`iranianMonths` / `afghanMonths`)؛ همهٔ نقطه‌های مصرف (هیرو خانه، پیش‌نمایش
  ویجت، گزارش‌های ختم/حفظ/ارزیابی، کارت‌های اشتراک و گزارش میراث، مبدل تاریخ،
  مناسبت‌ها) بدون تغییر امضا تابع انتخاب می‌شوند. هیچ آرایهٔ محلیِ نام ماه در
  `lib` نمانده و تست نگهبان همین را بررسی می‌کند. getter صفرمبناست؛ ماه جلالی
  یک‌مبناست، پس `[month - 1]`.
- **به‌روزرسانی فوری:** `MonthDisplayScope` (InheritedNotifier) داخل
  `AppTextScale` ریشه؛ انتخاب در `initState` همان ریشه بارگذاری می‌شود و
  ویجت‌هایی که باید بی‌درنگ بازرنگ شوند در build خود
  `MonthDisplayScope.of(context)` می‌خوانند. `main.dart` دست نخورد.
- **ویجت صفحهٔ خانه:** `WidgetSyncService` انتخاب ذخیره‌شده را پیش از ساخت
  snapshot می‌خواند، چون اندروید ویجت را بدون اجرای برنامه رندر می‌کند.
- **مرزها:** `main.dart`، `app_settings.dart`، اسکیمای Drift و pubspec دست نخوردند.
- **اثبات (worktree جدا `%TEMP%/opencode/month-display`):** `flutter analyze lib
  test` صفر؛ `flutter test --exclude-tags network` = **۴۲۱۵ قبول / ۹ ردشده /
  ۰ شکست**؛ گیت سخت ۷/۷؛ `design_consistency.py` سبز؛ نگهبان کدگذاری سبز؛ ۳ گلدن
  تنظیمات برای صفحهٔ بلندتر بازضبط شد. **بدون بیلد و بدون پاس روی گوشی**
  («فعلا بیلد نزن»).
- **پروتکل درخت مشترک:** کامیت از `GIT_INDEX_FILE` موقت ساخته شد؛ نُه فایلی که
  WIP نشست موازی را هم دارند (تیپ‌های دسترس‌پذیری، بازنویسی مقیاس فونت دستگاه در
  `AppTextScale`، بلوک صداقت اذکار) از blobهای بازسازی‌شدهٔ «HEAD + فقط هانک‌های
  من» stage شدند، پس هیچ‌کدام از آن کارها در `1413dcf` نیست.

## مهاجرت ویجت‌ها به Jetpack Glance — 2026-10-23

- **معماری:** هر دو ویجت صفحهٔ خانه (`PrayerWidget` و `TasbihGlanceWidgetReceiver`)
  حالا `GlanceAppWidgetReceiver` هستند و محتوا را `PrayerGlanceWidget` /
  `TasbihGlanceWidget` با Compose می‌سازند. هیچ XML تمام‌صفحه‌ای نمانده؛
  `widget_prayer_medium/small` و `widget_tasbih` حذف شدند و پنج drawable‌ای که
  فقط همان‌ها ارجاع می‌دادند هم پاک شد. پل Dart، فرمت snapshot و
  پیش‌نمایش‌های تنظیمات دست نخوردند.
- **برگ‌های زنده (عمدی):** Glance نمی‌تواند تیک بزند و هر دو ویجت
  `updatePeriodMillis=0` دارند (هر تغییر فاز با آلارم مرزی دقیق). ساعت و
  شمارش معکوس همان `TextClock`/`Chronometer` فریم‌ورک‌اند که با
  `AndroidRemoteViews` داخل ترکیب‌بندی جای گرفته‌اند؛ تنها XML باقی‌مانده
  `widget_live_clock` و `widget_live_countdown` است.
- **تپ‌ها:** `ActionCallback` جای PendingIntent broadcasts؛ سطح جعلِ audit 5.1
  حذف شد و مسیر قدیمی broadcast برای ویجت‌های نصب‌شدهٔ قبل از به‌روزرسانی با
  همان نگهبان `intent.package` باقی ماند. پنجرهٔ تأیید ریست (۳ ثانیه)، صف
  رویداد، ریست نیمه‌شب و نگهبان ۶ ساعته بدون تغییر منتقل شدند.
- **منطق خالص:** `PrayerWidgetModel`، `TasbihWidgetModel` و `WidgetArt` (کش
  بیت‌مپ حلقه/گرادیان) از رندر جدا شدند تا تست JVM ممکن شود؛
  `PrayerWidgetViews` فقط `computeCountdown`/`convertTo12h` را نگه می‌دارد چون
  تست‌های موجود همان‌جا صدایش می‌زنند.
- **اثبات:** `:app:compileDebugKotlin` و `:app:testDebugUnitTest` سبز
  (۸۰ تست Kotlin، شامل ۱۲ تست تازهٔ مدل)؛ `flutter analyze` صفر خطا؛
  `flutter test` ویجت/پالت/allowlist سبز؛ `flutter build apk --release` ساخته شد.
- **بدهی:** پیش‌نمایش picker لانچر پیاده نشده (`providePreview` در Glance 1.2
  هست) و **هیچ پاس روی دستگاه انجام نشد** — `adb devices` خالی بود، پس رندر
  واقعی روی لانچر، اندازه‌ها و ترتیب راست‌به‌چپ هنوز باید با اسکرین‌شات تأیید شود.

## خانه: متن کامل حیض زیر «دسترسی سریع» + چیپ‌های تاریخ هم‌اندازه — 2026-10-23 (`c78675f`)

- **برشِ متن حیض ریشه‌اش یک property بود:** `TextOverflow.ellipsis` داخل
  `Flexible` پاراگراف را از خط‌شکستن باز می‌داشت؛ با فونت واقعی برنامه در
  ۱۲/۱۲ حالت (۳۲۰/۳۶۰/۴۱۲ × ۱٫۰/۱٫۳) `didExceedMaxLines == true` اندازه
  گرفته شد. حذف همان overflow، متن را کامل می‌کند — حکم فقهی کوتاه نمی‌شود.
- **جابه‌جایی:** بنر از کارت اوقات شرعی بیرون رفت و بلوک مستقلی شد درست زیر
  `QuickActions`؛ کارت فقط اثر دوره را نگه می‌دارد (پنجرهٔ بستهٔ بی‌ثبت همچنان
  خط قرمز را خاموش می‌کند) و جمله را دوباره چاپ نمی‌کند.
- **چیپ‌های نامساوی:** سه جعبهٔ تاریخ `Flexible` بودند (چسبیدن به عرض ذاتی،
  پس هجری کوتاه‌تر). حالا `Expanded` با یک‌سوم ردیف و جعبهٔ وسط‌چین؛
  `FittedBox(scaleDown)` داخلی ماند تا ۳۲۰dp × ۱٫۳ امن بماند. هیرو ۲dp بلندتر
  شد، پس ۶ بیس‌لاین خانه بازضبط شد و ۱۰ تای دیگر بایت‌به‌بایت مطابق ماندند.
- **نگهبان:** `hayz_note_guard_test.dart` (اسکنِ جای‌گیری در `home_tab.dart` +
  دوازده حالت رندر واقعی) و دو تست برابری عرض در `hero_card_test.dart`.
- **اثبات:** `test/features/home` سبز؛ کل مجموعه **۴۲۸۰ قبول** با ۵ قرمز
  همگی ازپیش‌شناخته‌شده؛ آنالیز ۰، گیت سخت ۷/۷، رچت OK. بدون بیلد، بدون
  دستگاه — verdict بصری با کاربر است.

## تنظیمات: «روش عرضه ماه» داخل «فونت و نمایش» — 2026-10-23 (`f0e6ee8`)

- **انتقال، نه حذف:** ردیف از کارت مستقلِ صفحهٔ اصلی به همان کارت «فونت و
  نمایش» رفت و لباس ردیف‌های همسایه‌هایش را پوشید (IconTile 18، عنوان ۱۴/w600،
  زیرنویس ۱۲ خاکستری + زیرنویس تازه «نام ماه‌های شمسی: ایرانی یا افغانی»).
  زیرنویس ردیف فونت روی صفحهٔ اصلی هم «…نام ماه…» شد تا درِ بسته توضیح بدهد.
- **جست‌وجو و لنگر:** `main.month_display` → `font.month_display`
  (`rowKey: monthDisplay`)، «نام ماه» به کلیدواژه‌های فونت اضافه شد، و
  `FontDisplayPage.fontHighlightKeys` قرارداد لنگر شد؛ تست registry هر
  `rowKey` صفحهٔ فونت را در همان فهرست می‌خواهد و یک تست اسکرول با viewport
  ۳۸۰dp ورود را داخل دید اثبات می‌کند (کارت ~۷۰۸dp است؛ ۲۴۰ هیچ‌وقت نمی‌رسید).
- **گلدن:** ۳ بیس‌لاین تنظیمات کوتاه‌تر بازضبط شد (۶۷۴۸۱→۶۳۵۵۲ و هم‌ترازها).
- **اثبات (worktree جدا `%TEMP%/opencode/month-display-v3` روی `c78675f`):**
  حوزهٔ تنظیمات + نگهبان کدگذاری **۴۰۴ قبول / ۰ شکست**؛ آنالیز روی فایل‌های
  این کار صفر؛ گیت سخت ۷/۷؛ `design_consistency.py` OK.
  **بدون بیلد** («فعلا بیلد نزن»).
- **پروتکل درخت مشترک:** کار از worktree قدیمی‌تر (`b80c732`) با patch باینری و
  `git apply -3` روی tip تازه منتقل شد؛ مجموعهٔ تغییر دو worktree قدیمی با
  diffِ کامیت مقایسه و «یکسان» اثبات شد، سپس هر سه worktree خودم حذف شد
  (`month-display` نشست موازی دست نخورد). ff پس از اطمینان از پاک بودن هر ۸
  مسیر دلتا در درخت اصلی؛ ۷۷ مسیر dirty بیگانه پیش و پس یکسان.

## اشتراک تصاویر: یک کیت + شیت‌های قرآن روی کیت + عنوان وسط‌چین + گارد منبع — 2026-10-24 (`a857254`، `a7c7cdb`، `bd3e415`، `0b46f1a`)

چهار جلسهٔ نیمه‌کارهٔ قبلی، هرکدام پیش از کامیت در worktree جدا
(`%TEMP%/opencode/header-center` روی `c3f195d`) اثبات شد. بدون بیلد
(«فعلا بیلد نزن»)، بدون دستگاه.

### #183 — کیتِ مشترکِ اشتراک (`a857254`، ۱۶ فایل، +۹۳۱/−۱۳۸۰)
- **`ShareCardShell` تازه** (`lib/core/design_system/components/share_card_shell.dart`)
  + `ShareCardHeader` (کاشی دورنگ ۳۴ + عنوان ۱۵/w800 + زیرنویس ۱۲/w600)،
  `ShareCardLabel`، `ShareCardDivider` (رنگ از `ShareCardColors.divider`) و
  `ShareCardFooter` (جداکننده + `ShareService.appLine('<section>')` ۱۱/w600).
  کاغذ کرم، شعاع ۱۸، حاشیهٔ مویی ۱٫۲dp، بدون سایه؛ از بشکهٔ کیت صادر می‌شود.
- **هشت سطح روی کیت رفتند**: اشتراک دعا، اذکار، دعای قرآنی، حدیث (کارت +
  صفحه)، اوقات شرعی، آیه، تفسیر، و کارت میراث. اموجی سرصفحه‌ها حذف شد
  (پیشنهاد ۱۴)؛ عربی با امیری و فارسی با فونت برنامه، همه از `scaledFontSize`
  (۱۵)؛ ردیف‌ها روی `DuotoneIconTile` ۳۴ با ۸–۱۰٪ رنگ (۱۶)؛ `assets/logo2.png`
  از هر هفت کارت حذف شد و پانوشت یکسان شد (۱۷)؛ `Divider`های بی‌رنگ رنگ
  گرفتند (۱۸). `ShareCardColors` یک‌بار پالت را حل می‌کند و `divider`/`chipBg`/
  `wash` را می‌دهد؛ چهار گرادیان `wisdomBg*` به دو تُن تخت رسیدند.
- **کارت میراث:** پانوشت تصویری حذف و گلدن `share_card_scan.png` دوباره ضبط
  شد — فقط پیکسلی، همان اندازه (۱۸۵۹۳→۱۸۵۹۸ B).
- **اثبات:** باتریِ اشتراک **۵۴/۵۴** در ده فایل؛ تست جزئیات حدیث به سرصفحهٔ
  آیکونی به‌روز شد و **۵/۵** سبز است.

### #184 — شیت تفسیر و انتخاب‌گر ترجمه روی کیت خواننده (`a7c7cdb`، ۲ فایل)
- **`QuranKitRow` جای رسپی فهرست قدیمی**: ردیف تخت دورنگ، زبان به‌شکل چیپ
  (`QuranLangChip` از چیپ خصوصی به کیت عمومی رفت) و همان حاشیهٔ مویی رنگ لهجهٔ
  کروم خواننده — ردیف تفسیر دانلودشده و ردیف قاری یک خانواده‌اند.
- **انتخاب‌گر ترجمه یک ردیف بازشو شد**: ردیف ترجمهٔ فعلی (نام + چیپ + «برای
  تغییر ترجمه لمس کنید») باز می‌شود و فهرست زیرش می‌آید؛ انتخاب همان ترجمه
  پنل را می‌بندد. هیچ رفتار محتوا/انتخاب/دانلود عوض نشد.

### #185 — عنوانِ تب روی مرکز صفحه (`bd3e415`، ۳۲ فایل، +۵۴/−۲۳)
- **ریشه:** `PageHeader` عنوان را از ابتدای `Expanded` می‌کشید (چسبیده به راست).
  حالا گاتر ابتدایی آینهٔ بلوک اکشن‌هاست (۴۲dp برای هر اکشن = ۴۰ + ۲) و عنوان
  یک `FittedBox(scaleDown)` وسط‌چین است؛ حساب در LTR و RTL یکی است:
  ۴۲n + (W−۸۴n)/۲ = W/۲.
- **۳۰ بیس‌لاین بازضبط شد:** پنج صفحهٔ کامل خانه، بیست صفحهٔ «بیشتر» و پنج
  صفحهٔ تقویم — هر دیف فقط پیکسلی و بدون تغییر اندازه؛ مبدل تاریخ دست نخورد.
- **گارد:** `page_header_test.dart` **۸/۸** (مرکز در هر دو جهت، بدون اکشن، با
  دو اکشن، فیت ۳۲۰dp×۱٫۳، نردبان تیپ، هدف لمسی ۴۰dp).

### #186 — قفلِ منبعِ سطوح اشتراک (`0b46f1a`، +۲۲۷/−۱)
- **`share_surfaces_source_lock_test.dart`** ده سطح اشتراک + فایل‌های کیت را
  (پس از حذف کامنت‌ها) اسکن می‌کند و روی هر پنج لکهٔ بازگشت شکست می‌دهد:
  رنگ خام `Color(0x`، `fontSize:` دست‌نویس، اموجی نقاشی‌شده، `Divider` بی‌رنگ،
  و `assets/logo2.png`. یک تست هم ثابت می‌کند کامنت‌ها (متنِ خود قواعد) تست را
  نمی‌اندازند. **۱۸/۱۸**.

### اثبات کل و مرزها
- **آنالیز `lib test` ۰**؛ `quality_check.py --strict` **۷/۷**؛
  `design_consistency.py` OK (پیشنهادِ کاهش بودجه‌ها — raw_color ۲۷۵→۲۲۵،
  blur10 ۴۵→۹، opacity ۱→۰، ltr ۳۸→۳۷ — **گرفته نشد؛ بودجه‌ها قفل‌اند**).
- **کل مجموعه** (`flutter test --exclude-tags network` در همین worktree پاک):
  **۴۳۱۱ سبز / ۹ رد‌شده / ۳ شکست**؛ هر سه شکست همان
  `google_sign_in_server_client_test.dart`اند که `android/app/google-services.json`
  گیت‌ایگنورشده را می‌خوانند و در درخت اصلی ۷/۷ سبزند — **صفر قرمزِ تازه**.
- **گیتِ سخت روی کامنت هم حساس است:** جملهٔ «— برنامه توحید» بدون `appLine` در
  همان خط، کامنتِ Dart هم باشد، رد می‌شود؛ مستندِ `ShareCardFooter.section` با
  `ShareService.appLine` بازنویسی شد، نه با شل‌کردنِ گیت.
- **بدون بیلد** («فعلا بیلد نزن»)؛ هیچ APK این چهار کامیت را ندارد. verdict
  بصری کارت‌های اشتراک، شیت‌های قرآن و عنوانِ وسط با کاربر روی بیلد بعدی است.

### #187 — تب تسبیح: نیمه‌شب، خواندنِ شکست‌خورده و تخریبِ میانِ شمارش (`e6ec8a3`، ۹ فایل، +۱۵۴۴/−۳۷۷)

بازبینیِ کاملِ تب تسبیح (۱۸ یافته) با اجازهٔ کاربر: «هر کدام به‌نظرم مناسب است
انجام بده ولی کامل باشد و همه چیز اصلاح شود» و «اکمل» — هر یافته با ریشه، نه
وصله.

- **یک تصمیمِ ریست به‌جای دو قاعدهٔ ناهم‌خوان.** `tasbihResetDecision(now)` در
  `tasbih_daily_reset.dart` تنها منبعِ تصمیم است — provider، تایمرِ بوت و
  تایمرِ دقیقه‌ایِ تب همه از همان می‌پرسند. مهرِ تاریخ همان `decision.today` است
  و «تغییر اپ» روی `decision.deadline` مهر می‌شود، نه روی «الان».
- **`_ready` Completer در provider.** هر mutation اول `_awaitReady()` می‌کند و
  بعد از await دوباره `ref.mounted` را می‌بیند؛ ضربه‌ای که وسطِ بارگذاریِ اول
  می‌رسد دیگر با snapshot قدیمی پاک نمی‌شود (همان کلاسِ باگِ A-2).
- **نوشتنِ شکست‌خورده خودش را برمی‌گرداند.** rollback با «دلتای معکوس» فقط
  همان +۱ را کم می‌کند (count و lifetime جدا، کفِ صفر)؛ حذفِ شکست‌خورده ردیف را
  در همان ایندکسش برمی‌گرداند؛ `updateTarget` هدف را روی ردیفِ زنده می‌نشاند.
- **آمارِ شکست‌خورده دیگر صفر نیست.** `tasbih_stats_provider` خطا را
  `AsyncError` می‌دهد و `_MiniStatBox` جای عدد «—» با دلیلِ خوانده‌شدنی چاپ
  می‌کند؛ `weekStart` هم با حسابِ تقویمی (نه کسرِ میلی‌ثانیه) ساخته می‌شود تا
  هفتهٔ DST یک روز جابه‌جا نشود.
- **شمارشگر روی لیست گوش می‌دهد، نه روی build.** `ref.listenManual(...,
  fireImmediately: true)` + `_syncActiveTasbih`؛ build دیگر state نمی‌نویسد
  (نه `_currentIndex`، نه `_displayCountNotifier`) — قبلاً هر فریم همان مقدارها
  را دوباره می‌نوشت.
- **دستهٔ تپش‌ها در `deactivate` ریخته می‌شود، نه در `dispose`.** Flutter عنصر
  را پیش از `State.dispose()` unmount می‌کند، پس `ref` در dispose می‌ترکید و
  بقیهٔ teardown (notifierها + pool صدا) هرگز اجرا نمی‌شد. `_flushPendingSync`
  حالا `Future<void>` است، تایمرِ ۱۸۰ms را cancel می‌کند و `Future.wait` می‌گیرد.
- **ریست وسطِ شمارش دیگر به شمارشِ دسته برنمی‌گردد.** `_resetAfterFlush` اول
  شمارشِ نگه‌داشتن را متوقف، بعد flush را await، بعد ریست می‌کند.
- **کل سطحِ شمارش یک دکمهٔ Semantics است** (label=ذکر، value=«N از M»، hint) و
  عنوان و حلقه `ExcludeSemantics` شده‌اند؛ صفحه‌خوان قبلاً هیچ چیزِ شمارش را
  نمی‌دید. ۲۰ نقطه یک `Wrap` وسط‌چین زیر `ExcludeSemantics`اند.
- **ثابتِ هپتیک واقعاً می‌شمارد**: شمارنده بیرون از شرطِ
  `hapticEnabled && !isRapid` جلو می‌رود، پس پاریتی که برای نازک‌کردنِ لرزش
  نوشته شده از تپش‌ها جدا نمی‌افتد.
- **برچسبِ چیپ بریده نمی‌شود**: `substring(0, 15) + '...'` حذف شد؛
  `ConstrainedBox(maxWidth: chipLabelMax)` + ellipsis + Tooltipِ کامل.
- **«N از M» از notifier خوانده می‌شود، نه از مدلِ فریم**: مدلِ capture‌شده در
  build با ریست یا دستهٔ ویجت وسطِ تپش کهنه می‌شد و شمارنده را به عددی
  برمی‌گرداند که دیگر روی صفحه نبود.
- **صادق‌بودنِ اعلان‌ها**: دو `catch` خاموشِ ویجت با `AppLogger.warning` شناسا
  شدند؛ `_pushSelectionToWidget` ایندکس را پارامتر می‌گیرد تا با clamp مسابقه
  ندهد؛ رنگِ overshoot از `AppTheme.darkWarning/lightWarning` و عدد از
  `NumberFormat.formatSigned`؛ «تکمیل شده» از `scaledFontSize`.
- **ردیف دکمه‌ها در ۳۲۰dp × ۱٫۳ می‌ماند**: `_ActionButton` با
  `BoxConstraints(minHeight: 52)`، `alignment: center` و `maxLines: 2`.
- **تایمرِ نیمه‌شبِ تب**: `mounted` دیگر *قبل* از prefs read چک نمی‌شود (بعد از
  await چک می‌شود)، و tickِ تغییرِ روز `return` می‌کند تا همان tick دوباره
  مسیرِ overdue را هم اجرا نکند.
- **گاردها:** یک گروه تازه در تستِ `tasbih_daily_reset` (۶ حالتِ predicate +
  مصرف‌کنندهٔ واقعی)، سه تستِ race در `tasbih_provider_test`
  (`_GatedTasbihDao`، `_FlakyTasbihDao`، `_DeleteFailingTasbihDao`)، سه گروه
  Semantics، گروهِ نقطه‌ها، گروهِ دسته/ریست، و اسکنِ منبعِ تایمرِ نیمه‌شب.
  **با برگرداندنِ پنج فایلِ lib به HEAD، ۱۵ assert و یک شکستِ کامپایل**
  (`tasbihResetDecision` پیدا نمی‌شود) می‌افتد — یعنی گاردها واقعاً گاز می‌گیرند.
- **اثبات:** `flutter test test/features/adhkar
  test/features/home/presentation/widgets/daily_summary_card_test.dart
  test/core/utils/text_encoding_guard_test.dart` = **۱۵۴/۱۵۴**؛ تستِ ویجت تنها
  **۲۱/۲۱**؛ `flutter analyze lib test` **۰**؛ `quality_check.py --strict`
  **۷/۷**؛ `design_consistency.py` OK؛ گاردریل رمزنگاری ۲/۲.
- **بدون بیلد** («فعلا بیلد نزن»)؛ دستگاه متصل نیست. verdict بصری/دستگاه با
  کاربر است.

## ۲۰۲۶-۱۰-۲۵ — فاز دوم: پوستهٔ مشترک بخش‌ها، سه‌گانهٔ ابزارها و کروم قرآن (`af85c75` → `bc7ac89`، `9966f64`)

هشت کامیت معماریِ دیزاین روی `release/1.8.0`. ترتیب همان ترتیبی است که کاربر
تأیید کرد: خانه ← قرآن (فقط کروم) ← تسبیح ← تقویم ← ارزیابی ← بیشتر/تنظیمات ←
ابزارها. دو تصحیح کاربر در طول کار حاکم بود: (۱) پاس مکانیکی
`AppTheme.light*/dark*` → palette (۱۰۵ فایل، ۶۳۵ ارجاع، ۲۳۲ سه‌گانهٔ `isDark ?`)
یک کامیت مستقل است و **بعد از فروکش WIP جلسهٔ موازی** می‌آید — هنوز نیامده؛
(۲) پوسته **از خانه استخراج** شود، نه از پیش طراحی.

- **`SectionShell` از خانه استخراج شد، نه از پیش** (`af85c75`، ۱۰ فایل):
  `lib/core/design_system/components/section_shell.dart` — کرومی که هر تب با
  دست دوباره تایپ کرده بود: `Scaffold(transparent)` + `PageHeader` باریک + شکلِ
  بدنه. دو نما: `.list` (هدر اولین فرزندِ `ListView` است و با محتوا می‌رود) و
  `.fixed` (هدر می‌ماند، `Expanded(child)` بقیه را پر می‌کند). **پس‌زمینهٔ
  ambient نمی‌کشد** (تک‌منبع در ریشه: `MaterialApp.router`'s builder) و
  **SafeArea اضافه نمی‌کند** (پوستهٔ تب همین حالا داخل یکی است). خانه با آن
  پیکسل‌به‌پیکسل یکسان شد: ۱۵۲ تست خانه سبز و هر گلدنِ کارت byte-identical.
- **هارنسِ گلدنِ صفحه دیگر ارتفاع را حدس نمی‌زند** (`af85c75`): پنج بیس‌لاین
  تمام‌صفحه ارتفاعِ حدسی ۲۶۰۰/۳۶۰۰ داشتند در حالی که صفحه در ۴۱۲dp برابر
  ۲۹۲۳dp، در ۳۲۰dp برابر ۳۱۲۶dp و در ۳۶۰dp/۱٫۳ برابر ۴۰۰۹dp است — **چهار
  بیس‌لاینِ از پنج، پایینِ خودشان را می‌بریدند**: در ۴۱۲dp کلِ بلوک
  QuickActions و ۱۱۱۲dp از کارت جمعه بیرونِ تصویر بود. حالا هارنس صفحه را روی
  سطحِ ۲۴۰۰۰dp می‌چیند، از فرزندانِ sliver حدِ دقیقِ محتوا را می‌خواند، سطح را
  به همان اندازه می‌سازد و اگر صفحه هنوز اسکرول شد شکست می‌دهد.
- **پذیرش در پنج بخش، همه بدون تغییر پیکسل جز یکی**:
  `69b8a55` تسبیح (`.fixed`؛ هدر تک‌منبع با خانه؛ یک تپ = ۱۳۷ element rebuild،
  فریم اول ۷۱۵ms در debug/JIT)؛ `1a1651d` تقویم (`.list` + پارامترهای تازهٔ
  `padding` و `headerPadding` در خودِ پوسته، پیش‌فرض‌ها `EdgeInsets.zero` تا هر
  صفحهٔ موجود یکسان بماند؛ `git diff -w` ثابت می‌کند تنها دلتای معنایی
  wrapper است و ۷ گلدن تقویم byte-identical)؛ `d071f6b` ارزیابی (`.fixed`؛
  فریم اول ۵۰۰٬۷۷۶us)؛ `cee76af` بیشتر.
- **تنها تغییر بصریِ فاز، و عمدی است** (`cee76af`): صفحهٔ «بیشتر» پس‌زمینهٔ
  کرمِ مات خودش را می‌کشت، پس میدانِ «نارنجی بیشتر» که پوسته همیشه پشت این تب
  گذاشته (`main_shell.dart:221`، `SectionHues.more = #D85A30`) حالا دیده
  می‌شود — گرادیانِ ambient با واشِ ۴–۵٪ و glow، به‌جای رنگِ مات. هارنسِ گلدن
  هم `AmbientBackground` نداشت و صفحهٔ شفاف پنجرهٔ خالی ثبت می‌کرد؛ حالا دقیقاً
  مثل production آن را می‌پیچد و **۲۰ بیس‌لاین More** بازثبت شد. قبل از ثبت:
  ابعاد یکسان، آلفا ۲۵۵ در همه‌جا، رنگِ گوشه‌ها در ۱/۲۵۵ از `pageBg` قبلی، و
  IoU نقشهٔ لبه **۹۴٫۵–۹۸٫۲٪** یعنی چیدمان تکان نخورده.
- **تنظیمات عمداً پذیرفته نشد:** صفحهٔ push‌شده است و `SettingsAppBar` با ارتفاع
  ۵۶dp دکمهٔ Back را در خود دارد (`settings_components.dart:33`)، و
  `SectionShell` هیچ slot برای leading ندارد. پذیرشِ آن یعنی یا دکمهٔ بازگشت در
  جای غلط، یا slot تازه در پوسته — هیچ‌کدام لازم نبود.
- **سه‌گانهٔ ابزارها: شکست دیگر خودش را «خالی» جا نمی‌زند** (`e521b64`، ۱۰
  فایل، +۵۴۷/−۳۷): dongi حالا `loadError` را در state دارد و هاب و صفحهٔ گروه
  `AppErrorDisplay` با reload می‌کشند، نه اسپینرِ بی‌پایان؛ pomodoro شکستِ
  خواندنِ تاریخچه را در `_historyError` نگه می‌دارد، دکمهٔ تلاش دوباره خطا را
  تا پایانِ خواندنِ تازه دیده‌شدنی نگه می‌دارد و خلاصهٔ صفر را در حالت خطا
  خفه می‌کند ولی ردیف‌های آخرین خواندنِ سالم می‌مانند؛ ژورنالِ تقویم ردیفِ خطا
  را با «تلاش مجدد» جمع‌وجور می‌کند که `dayJournalProvider` را invalidate
  می‌کند. گاردها: `dangi_provider_load_test` (۲)، `session_history_test` (۵)،
  حالت خطا/تلاش در `calendar_sections_test` و دکمهٔ تلاش در
  `pomodoro_screen_test`.
- **قرآن: فقط کروم** (`bc7ac89`): فهرستِ نشانک‌ها، فهرستِ سوره‌ها و جستجوی
  درون‌خوان هر کدام AppBar خودشان را ساخته بودند — دو تا روی `chrome`، یکی روی
  `surface`، سه سبکِ عنوان، `centerTitle` روی دو از سه و `elevation: 0` روی
  یکی. `quranPaperAppBar` در باندلِ مصحف همان دستور را یک‌بار می‌گوید:
  `chrome`/`onChrome`، بدون lift در هر دو حالتِ اسکرول، عنوان وسط‌چین با
  `scaledFontSize(context, 15)` و w700 (۱۵ روی مقیاسِ مشترک است، پس رندرِ
  پیش‌فرض پیکسل‌یکسان؛ عیب drift رنگِ کروم بود نه اندازه). اسپینرِ صفحهٔ جستجو
  هم `palette.accent` شد. عمداً بیرون: خوانندهٔ immersive (کرومِ خودش را روی
  صفحه می‌کشد) و صفحه‌های اشتراکِ آیه/تفسیر (خانوادهٔ `ShareCardPalette`).
  گارد: `quran_paper_chrome_test.dart` — توکن‌های دستور زیر هر دو paper، قفلِ
  منبعِ comment-stripped روی سه صفحه (حضور دستور، ایمپورت دقیق، نبودِ
  `AppBar(` خام، نبودِ `fontSize: 15`)، استثناها، و self-test که ثابت می‌کند هر
  اسکنر گاز می‌گیرد. دامنهٔ قرآن **۳۷۱** سبز.
- **تقویم: یک تپ روی روز، انتخاب را رنگ می‌کند نه صفحه را** (`9966f64`، ۴
  فایل، +۵۷۲/−۲۶۶). اندازه‌گیریِ ثبت‌شده در `1a1651d` (۵۵۵ element / ۱۲۱٬۳۸۸us)
  و probe این کامیت (۵۶۳ element / ۹۳٬۲۹۲us؛ اختلاف از JIT است، نه کد) یک
  ریشه داشت: روزِ انتخاب‌شده در یک فیلدِ `setState` بود و داخل هر ۳۰ مدلِ
  `CalendarCellData` پخته می‌شد، پس هر تپ کلِ صفحه را — با گرید — دوباره
  می‌ساخت. حالا `CalendarSelection` (یک مقدارِ immutable: هر سه تاریخ، رویدادها
  و روزه‌های آن روز) در **یک** `ValueNotifier` منتشر می‌شود؛ هر
  `_SelectableDayCell` جداگانه گوش می‌دهد و فقط وقتی پرچمِ خودش عوض شد
  `setState` می‌کند؛ `setState` سطحِ صفحه فقط برای تغییرِ ماه/سال می‌ماند .
  نتیجه: **۵۶۳ → ۲۱۴ element (−۶۲٪)**؛ گرید، فهرستِ مناسبات و پوسته **صفر**
  rebuild؛ تپ روی روزِ از قبل انتخاب‌شده **هیچ** رنگی نمی‌کشد. هندسه دست
  نخورد (همان `AppCard(Column([هدر، Table، legend]))`) و ۷ گلدن تقویم
  byte-identical؛ گارد `calendar_rebuild_scope_test.dart` (۳ حالت) همین دامنه
  را قفل می‌کند.
- **پس‌مانده‌های ثبت‌شده برای ادامه:** سوییچ دوره در ارزیابی (۲۱۲ element /
  ۱۷۱٬۰۹۷us)، تیکِ دقیقه‌ایِ خانه (۶ `ValueListenableBuilder` روی `minute`؛
  ۴۳۷ rebuild / ~۱۱۰–۱۱۹ms) و جستجوی عمیقِ بیشتر (۲۹۶ element / ۲۶۳٬۳۱۳us).
- **اثبات:** `flutter analyze lib test` **۰**؛ `quality_check.py --strict`
  **۸/۸**؛ `design_consistency.py` OK؛ گاردریل رمزنگاری سبز. **بدون بیلد**
  («فعلا بیلد نزن»)؛ دستگاه متصل نبود — verdict بصری با کاربر است.

### ۲۰۲۶-۱۰-۳۰ — اعداد سه‌رقمی همه‌جا، حذف ریال، اسپلش ۱۰٪ کوچک‌تر، شهر روی کارت اشتراک (`98a8493`)

- **گروه‌بندی هزارگان**: منبع یکی `NumberFormat.groupDigits`/`groupRun` است
  (`formatPlain` روی همان سوار شد) و `grouped(num)` برای نمایش. فیلدها با
  `LatinGroupingFormatter` در فایل تازهٔ
  `lib/shared/widgets/number_input_formatters.dart` هنگام تایپ گروه می‌شوند؛
  مکان‌نما با **شمردن رقم‌ها** بازنگری می‌شود (collapse به انتها نبود)، پس
  تایپ در وسط و انتخاب بازه سالم می‌ماند. روی هر فیلدِ مقدار: هزینه‌ها (مبلغ +
  سقف بودجه)، زکات (همهٔ `_inputField`ها، پول و وزن)، قیمت فطریه، اهداف (هدف /
  هدف روزانه / افزودن و ویرایش ثبت)، تسبیح و اذکار (هدف و افزودن تعداد)، میراث
  (ترکه، کفن، بدهی، سه وصیت در هر شش زبانه + مناسخات)، دُنگی (مبلغ و سهم هر
  عضو).
- **نمایش‌های خام که گروه‌بند شدند**: مجموع/باقی/هدفِ اهداف (`grouped`)،
  `formatGram`، `formatBytes` («1,023.0MB» — و `account_screen._size` هم‌خانواده
  شد، بدون ایزوله چون ردیف‌های آن لیست علامت bidi ندارند)، `enDigits` در PDFها،
  `_round` در خطوط جزئیات زکات، و خط نتیجه/تاریخچهٔ ماشین‌حساب (نمایش گروه
  می‌گیرد؛ مقدار ذخیره‌شده و `double.tryParse` خام می‌مانند).
- **قاعدهٔ صریح**: شناسه‌ها گروه نمی‌شوند — سال، شمارهٔ صفحه/آیه/حدیث/جزء، PIN و
  مختصات از `NumberFormat.en` می‌خوانند و آن عمداً بدون گروه است (توضیح در
  سندش). خروجی CSV/JSON هم خام می‌ماند (`expense_exporter`).
- **خواندن‌ها**: `NumberFormat.parse`، `parseDangiAmount` و
  `parseNonNegativeAmount` از قبل جداکننده را می‌شناختند؛ سه خوانندهٔ ناسازگار
  اصلاح شدند (دو `_normalizeDigits` در تسبیح/اذکار و ترکهٔ تب سهام). علامت منفی
  در فیلد **می‌ماند** تا اعتبارسنجِ خودش پیام بدهد — حذفِ بی‌صدای آن تستِ
  «بدهی منفی رد می‌شود» را می‌کشت و آن را برگرداند.
- **ریال‌ها رفتند**: `AppCurrency.rial` و `.saudiRial` حذف؛ با رفتنِ ریال،
  `liveTomanFactor`/`fromToman` بی‌مصرف بودند پس حذف شدند و `isIranian` به
  `== toman` جمع شد (بدون shim؛ نام نگه داشته شد چون چهار مصرف‌کننده‌اش دقیقاً
  همان معنی را می‌خواهند). کلید واحد در prefs **کد پایدار** است و `fromCode` به
  تومان برمی‌گردد، پس نصب قدیمیِ IRR/SAR خودبه‌خود درست می‌شود — تستِ تازه همین
  را قفل می‌کند. `settings_registry` فقط واژهٔ کلیدی «ریال» را از دست داد (یک خط،
  چون آن در دیگر پیدا نمی‌شود).
- **اسپلش**: `logoSize` = همان جدول ×۰٫۹ (`0.7056`، کف/سقف ۲۰۱٫۶/۲۸۸) — چون
  ضریب و سقف‌ها با هم مقیاس می‌شوند، کوچک‌شدن در هر عرض یکسان است. ۸ گلدن ضبط
  دوباره؛ سنجهٔ «صفحهٔ کوتاه» ۵۰۰ ← ۴۷۰dp (سکهٔ کوچک‌تر جا باز کرده؛ قرارداد
  همان).
- **کارت اشتراک اوقات**: شهر به `trailing` هدر رفت = لبهٔ **چپ** در ردیف RTL، با
  `Icons.place_outlined` و `FittedBox` (برش ندارد)؛ زیرعنوان روز را نام می‌برد
  («امروز · جمعه»)؛ شش ردیف در `_TimeTable` یکی با فریم و خط میانی. گارد
  `prayer_share_city_table_test.dart` (اسکن منبع کامنت‌زدوده) هر چهار بند را
  قفل می‌کند؛ `prayer_share_date_strip_test.dart` بدون تغییر سبز ماند.
- **گاردریل تازه**: `test/shared/widgets/number_input_formatters_test.dart`
  (۱۶ حالت). دو انتظار تست با قرارداد جابه‌جا شد: «3,315» در نمایش
  ماشین‌حساب و «.» به‌جای «abc» در دُنگی.
- **اثبات**: analyze ۰/۰ روی فایل‌های این کار (سه info از کار commit‌نشدهٔ نشست
  موازی)؛ گیت ۸/۸؛ یکپارچگی طراحی OK با بودجه‌های قفل؛ سبزها: tools ۱۱۸۴،
  goals+expenses+adhkar+fasting ۳۳۵، design-system+prayer ۵۴۶، splash ۴۳،
  settings+home+search ۶۵۲، quran/services ۶۷، سوئیت کامل تا لحظهٔ stop:
  ۴۳۳۸ سبز / ۳ قرمز. `riyad_service_test` در worktree پاک روی HEAD هم قرمز است
  (خط نسخهٔ ریاد — نشست دیگر) و `widget_layout_allowlist_test` با WIP ویجت آن‌ها
  در درخت مشترک می‌لنگد؛ هیچ‌کدام از این کار نیست. **بیلد زده نشد**
  («فعلا بیلد نزن»)، دستگاه وصل نبود.

## ورق زدن مصحف: «ورق کتابی» و «طومار»، و برگ راست/چپ مثل چاپ (2026-10-31)

شاخهٔ `quran/page-turn-effects`؛ گزارش کامل: `docs/PAGE_TURN_REPORT.md`.

- **افکت قبلی حذف شد**: `MushafPageTurn.slide`/`.flip` رفتند؛ سه حالت `plain`،
  `bookFlip`، `scroll`. `slide`→`plain` (کسی که ساده خواسته بود ساده می‌ماند)،
  `flip`/`leaf`→`bookFlip`، نصب تازه → `bookFlip`.
- **بدون لایهٔ overlay جدا**: افکت داخل همان PageView و از `PageController`
  خوانده می‌شود، پس ایندکس/بوکمارک/تعقیب تلاوت/نواحی ضربه دست‌نخورده‌اند و شکل
  زنجیرهٔ ویجت هرگز عوض نمی‌شود (درخت memoize‌شدهٔ صفحه زنده می‌ماند).
- **ورق کتابی**: ۸ نوار (lite ۶)، برگ `105°·p^1.7`، خم هر لولا `9°·sin(πp)`،
  دوربین ۱/۱۱۰۰. **طومار**: ۱۲ نوار (lite ۸)، `u = p(N+3)`، خم ۳۴° از لبهٔ آزاد،
  و از `p>0.78` خروج با `0.95q²`.
- **عکس صفحه**: یک `toImage` در شروع درگ از `RepaintBoundary` **دور PageView**
  (نه روی صفحه — GlobalKeyِ روی صفحه با هر ورق جابه‌جا می‌شد و درخت را می‌ساخت؛
  تست موجود همین را گرفت). نبود عکس = کج‌شدن تک‌صفحه‌ای، نه معطلی.
- **عملکرد**: بدون blur/saveLayer/Opacity، سایه‌ها تخت؛ watchdog ۱۲ فریم/۱۴ms →
  lite → plain برای همان نشست؛ کاهش حرکت سیستم → plain و کارت‌ها غیرفعال.
- **برگ راست/چپ**: صفحهٔ فرد = برگ راست (عطف چپ، سوره بالا-راست، شماره
  پایین-راست)، زوج = برگ چپ؛ نوار عطف ۱۸dp با ۲۶٪. گزینهٔ «ظاهر صفحات راست و
  چپ مثل مصحف چاپی» پیش‌فرض روشن و خاموشش دقیقاً چیدمان قبلی.
- **تنظیمات**: بخش «افکت ورق‌زدن» با سه کارت ۷۲dp + بندانگشتی نقاشی‌شده،
  «پیش‌نمایش»، «سرعت» (۲۶۰/۳۸۰/۵۲۰) و «لرزش ملایم». کلیدها:
  `quran_page_turn`، `quran_page_turn_speed`، `quran_page_turn_haptic`،
  `quran_page_chrome_parity`.
- **اثبات**: `flutter test test/features/quran/mushaf --exclude-tags network` =
  ۳۲۴ سبز؛ `flutter analyze lib/features/quran test/features/quran` پاک.
  گلیف‌ها دست نخوردند؛ هیچ گلدنی لازم نشد. **بیلد و پروفایل روی دستگاه انجام
  نشد** (دستگاه وصل نبود) — بند ۱۱ گزارش.

### ۲۰۲۶-۱۱-۰۱ — حلقهٔ تسبیح به اندازهٔ جعبه‌اش شد، دکمه‌ها دایره شدند، و بند «راه بازگشت» از بریف حذف شد

- **اصلاح بریف (خواستهٔ صریح کاربر):** جملهٔ «recommendation (hybrid: keep
  AndroidRemoteViews for the whole prayer widget) instead of shipping a
  regression» از بخش «Performance vs baseline» حذف شد؛ مهاجرت به Glance
  قطعی است و دیگر به‌عنوان گزینهٔ بازگشت مطرح نمی‌شود. در
  `docs/GLANCE_WIDGETS_REPORT.md` به‌صورت یک یادداشت بالای سند ثبت شد.
- **باگ اندازهٔ حلقه (اثبات با پیکسل، نه با چشم):** اسکرین‌شات دستگاه
  (1220×2712، density 3.25، سلول ۲۴۳×۲۶۹dp) نشان داد قطر بیرونیِ شیار حلقه
  **۱۱۶px ≈ ۳۶dp** است. علت: `WidgetArt.ring` بیت‌مپ را در **۲۵۶ پیکسل** سقف
  می‌زد و چون `ImageView` در لایه `wrap_content` است، همان بیت‌مپ اندازهٔ ویو
  است — یعنی ۷۹dp در جعبهٔ ۱۱۹dp، و شمارنده هم از همان عدد سایز می‌گرفت و از
  کمان بیرون می‌زد. سقف حالا **سقف چگالی** است: `min(density, 2.5)` با کف
  مطلق ۵۱۲px (`WidgetArt.RING_MAX_DENSITY`/`RING_MAX_PX`) → جعبهٔ ۱۱۹dp حدود
  ۲۹۸px (~۳۵۵KB) می‌خواهد.
- **دکمه‌های پایین کارت:** هر سه `layout_weight=1` بودند، یعنی یک‌سومِ عرض کارت
  (~۷۴×۴۴dp) با گوشهٔ ۱۴dp — همان «قرص کشیده»ای که در اسکرین‌شات دیده می‌شد.
  حالا سه دایرهٔ ۴۴dp با ۱۸dp فاصله، وسط‌چین، در ناحیهٔ لمس ۴۸dp؛
  `widget_tasbih_chip` از مستطیل به **oval** تغییر کرد.
- **بیلد:** `flutter build apk --release` سبز (50.5MB). **تأیید روی دستگاه
  ناتمام ماند** — گوشی وسط کار از adb افتاد (`no devices/emulators found`) و
  اسکرین‌شات پس از اصلاح گرفته نشد. اسکرین‌شات‌های قبل از اصلاح در
  `.design-shots/verify/` است.
- **سند تازه:** `docs/GLANCE_WIDGETS_REPORT.md` — معماری فعلی، سه انحرافِ
  عمدی از بریف (حذف TextClock/Chronometer بنا به درخواست کاربر، تسبیحِ
  RemoteViews به‌خاطر باگ نشستِ Glance روی HyperOS، و اختلاف جدول پالت با
  رنگ‌های بریف)، چک‌لیست مشکلات با شواهد، و موارد باز. سر
  `docs/WIDGETS_THEMING_REPORT.md` هم «Superseded» شد چون دو حکمش (وجود
  TextClock و Glance بودن تسبیح) دیگر درست نیست.
- **مورد بازِ ثبت‌شده:** ساعت و شمارش معکوس روی دستگاه **ارقام فارسی** می‌دهند
  در حالی که وقت‌ها و تاریخ‌ها (که سمت Flutter قالب می‌گیرند) لاتین‌اند؛
  `formatClockTime`/`formatCountdownMinutes` هر دو `Locale.US` را پین
  می‌کنند، پس رشته ASCII است و تبدیل در زمان رندر رخ می‌دهد — علت ریشه‌ای
  هنوز پیدا نشده و در گزارش به‌عنوان سؤال باز ثبت شد.
## ادغام `quran/page-turn-effects` در ۱.۸.۰ و بیلد انتشار (۲۰۲۶-۱۱-۰۱)

- **ادغام شد** (`9b2a463`، والد دوم `61d3460`) — ۱۳ فایل: موتور ورق
  (`mushaf_page_turn.dart`)، کلیدهای پیش‌ترجیح، بخش تنظیمات
  (`mushaf_page_turn_settings.dart`)، پارامترهای برگ راست/چپ و گزارش
  `docs/PAGE_TURN_REPORT.md`. تنها برخورد `PROGRESS.md` بود؛ هر دو لاگ
  نگه داشته شدند (`0f75967`).
- **تست‌ها:** `flutter test test/features/quran/mushaf --exclude-tags network`
  = ۳۲۴ سبز / ۰ قرمز؛ `flutter analyze lib/features/quran test/features/quran`
  = «No issues found».
- **بیلد انتشار** از worktree تمیز و detached روی `0f75967`
  (`%TEMP%/opencode/rel-build-1.8.0-0f75967`، چهار فایل gitignore‌شده کپی
  شد): `app-release.apk` ۴۷٬۱۹۵٬۱۴۹ بایت (۴۵.۰MB)، sha1
  `23bf340c8edbe12b5ca152acf4644efc83036145`. دستور
  `flutter build apk --release --no-pub` (pub از `pub.flutter-io.cn` جواب
  نمی‌داد — خطای DNS؛ از `.dart_tool` موجودِ درخت استفاده شد)، گریدل ۱۹۱.۸s،
  exit 0. نسخهٔ بادوام: `Desktop/tawheeed-release-apks/1.8.0-0f75967/`.
- **اثبات باینری** روی `lib/arm64-v8a/libapp.so` (UTF-16LE): ۹ رشتهٔ درست
  پیدا شد («ورق کتابی»، «طومار»، «افکت ورق‌زدن»، «ظاهر صفحات راست و چپ»،
  «ظاهر برنامه»، «قوس صفحه اصلی»، «پیش‌نمایش»، «لرزش ملایم»، «مصحف چاپی») و
  برچسب‌های حذف‌شدهٔ «مصحف توحید»/«تلاوت‌یار» هنوز غایب‌اند.
- **بدون دستگاه:** اثبات تست/گلدن است؛ پروفایل روی گوشی ضعیف و بازبینی روی
  دستگاه انجام نشد.
## پاک‌سازی جلسات قبلی: کار ویجت‌ها کامیت شد، تست‌های جامانده سبز، بیلد ۱.۸.۰ (۲۰۲۶-۱۱-۰۱)

- **کار نیمه‌کارهٔ ویجت‌ها کامیت شد** (`d35675f`): ۲۵ فایل — حذف `WidgetLiveLeaves.kt`
  و دو لِی‌اوت زنده، برداشتن کلید «حالت سازگاری» از `widget_bridge`/`widget_sync`،
  حلقهٔ تسبیح با سقفِ چگالی (`min(density, 2.5)`، کف ۵۱۲px)، دکمه‌های ۴۴dp دایره‌ای،
  قلم `res/font/calibri.ttf`، و گزارش `docs/GLANCE_WIDGETS_REPORT.md`.
- **دو گاردریل ویجت به قرارداد تازه منتقل شدند**: هیچ `setViewLayoutWidth/Height`
  برنگردد (چون عددِ dp روی لانچر پیکسل می‌شد و حلقهٔ ۳۶dp را می‌ساخت) و سقفِ
  چگالی/کف پین شد. هر دو فایل حالا CRLF-نرمال می‌خوانند تا نگارش ویندوز پاسخ را
  عوض نکند — پیش‌تر همین باعث رد شدن تست در in‌درخت ویندوزی شده بود.
- **گارد قوس خانه اصلاح شد** (`9289fba`): تست `Color.lerp(t.heroMid, t.heroBottom`
  را می‌خواست، یعنی جزئیات پیاده‌سازی‌ای که بازطراحی خانهٔ v3 برداشته بود؛ حالا
  همان نیت پین می‌شود: هیرو، گلوله و هالهٔ آن همه از پالت می‌آیند.
- **CHANGELOG کامل شد** (`dc6a334`): چهار خط جاافتادهٔ ۱.۸٫۰ اضافه شد — ورق کتابی و
  طومار با برگ راست/چپ، سه نمای قوس خانه، سه نمای مجموعه‌های ذکر، و پایان مهاجرت
  ویجت‌ها.
- **تمیزکاری درخت** (`c4c8fc7`): `.design-shots/` (۹۷ مگابایت)، `.workbuddy-ai/`،
  `cache.db`، `ui.xml` و پوشهٔ سهوی `%TEMP%/` به `.gitignore` رفتند (فایل‌ها سر
  جایشان هستند، فقط از `git status` بیرون می‌آیند).
- **اثبات**: `flutter analyze lib test` = ۰ خطا / ۰ هشدار (۱۰ info از پیش موجود)؛
  گیت سخت‌گیرانه **۸/۸ صفر**؛ سوئیت کامل `--exclude-tags network` =
  **۴۹۴۲ سبز / ۰ قرمز / ۹ جهش‌داده‌شده** (تنها شکست، همان گارد قوس بود که پیش از
  کامیت اصلاح شد)؛ بخش مصحف ۳۲۴ سبز؛ `test/android` + `test/features/home` ۲۹۲ سبز.
- **بیلد انتشار از `9289fba`** — worktree تمیز و detached، چهار فایل gitignore‌شده
  کپی، `flutter build apk --release --no-pub`، گریدل ۴۹۰.۸s، exit 0:
  `app-release.apk` ۴۷٬۹۶۱٬۳۳۳ بایت (۴۵.۷MB)، sha1
  `d090ad2bdc800b7f49d76c1c6ecba55cb401373b`. نسخهٔ بادوام:
  `Desktop/tawheeed-release-apks/1.8.0-9289fba/` و کپی در `build/app/outputs/flutter-apk/`.
  در `libapp.so`: «ورق کتابی»، «طومار»، «قوس صفحه اصلی»، «تمرکز» و «تایم‌لاین»
  پیدا شدند و «تیک زدن» غایب است (برگ‌های زنده واقعاً حذف شده‌اند).
- **تنها خطِ بازِ جلسات قبل**: شاخهٔ `screens/qibla-sciences-tahara` با ۱۹ کامیت
  (طراحی صاف در کل برنامه + بازطراحی قبله/علوم/طهارت). با ۱.۸.۰ بیش از ۴۰ فایل
  تعارض دارد و هر صفحهٔ تازه‌تر (خانهٔ v3، تقویم، «بیشتر» چهارستونه، قوس‌ها،
  مصحف) را دوباره دست می‌زند، پس **عمداً ادغام نشد** — تصمیم با کاربر است.
  `freebuff/1.8.0-transfer`، `safety/quran-b04df1a` و دو اصلاح `freebuff/task-5dec…`
  (پشتیبان عکس اسناد، تست v42) از قبل در ۱.۸٫۰ هستند و فقط patch-id متفاوت‌اند.
- **بدون دستگاه**: اثبات analyze/تست/باینری است، نه بازبینی روی گوشی.

---

# PROGRESS — ابزارهای شخصی مجموعهٔ ۲ (`personal2/stage1-kids-teacher`)

Spec: docs/PERSONAL2_INVENTORY.md (built first, from the working tree).
Branch cut from `release/1.8.0` at `5b1d5a3`. Every commit is one layer.

## Done

- [x] Inventory + plan — the section/lock/migration/notification/reader map,
      including the finding that «ابزارهای شخصی» has no hub any more and the
      registration therefore lands inside «اطلاعات من» (the only section with
      a list component, icon style, navigation AND a real PIN lock).
- [x] v46 migration — raw-SQL `Personal2Tables` on the v45 precedent, no
      build_runner; CREATE IF NOT EXISTS in both onCreate and onUpgrade.
- [x] Shared kit — ParentLock (PBKDF2 ≥120k off the UI isolate, 5→30 s
      doubling lockout, constant-time compare), ReportRenderer (PNG ≤2×,
      A4/A5 PDF with the brand strip), MiniCharts (CustomPainter, RTL, cached
      Pictures), TemplateStore (assets + DB overrides + reset), SoftNotifier
      (quiet hours incl. midnight wrap, daily cap 3, one summary; ids
      14000/15000).
- [x] «دفتر عادت کودک» — 12 tables' worth of DAO + pure logic + 7 screens
      (parent home, setup, child mode, habits, rewards, approvals, report).
- [x] «دفتر مربی قرآن» — DAO + pure logic + 5 screens (class home, lesson
      sheet, student profile, parent report, class management).
- [x] Reader preview-only: `QuranNavRequest(previewOnly: true)` + launcher;
      the mushaf drops the debounced `quran_last_page` write while previewing.
- [x] Registration in «اطلاعات من» + 13 routes behind `VaultGuard` + two new
      hues pinned by the TopicHues↔SectionColors parity test.

## Bugs found and fixed along the way (all test-caught or grep-found)

1. `assets/data/` was never declared in pubspec — the existing
   `care_templates.json` load had been failing into `CareTemplates.empty`
   silently. Declared the directory.
2. SoftNotifier id collision: a stableSlot of 999 landed exactly on the
   summary id, so a reminder could overwrite the day's summary. Slot space is
   now one short of each range; test pinned.
3. Child-mode tile grid overflowed by 31 px at 320 dp (and 16 px more at text
   scale 1.3): aspect 1.32 → 0.9, keeping the brief's 52 dp tile.
4. Parent-lock throttle keys (`personal2.lock_*`) were outside the backup
   service's sensitive prefix, so a lockout would have travelled to a new
   device. Renamed under `personal_info.`.

## Verification so far

- `flutter analyze lib test` — 0 errors; none of the 51 infos touch
  `lib/features/personal2` (all pre-existing elsewhere).
- personal2 suite — 118 tests green (46 kid logic, 47 teacher logic, 7 v46
  migration incl. a real 45→46 upgrade with data, 7 mushaf preview, 15
  SoftNotifier, 38 layout at 320/360/412 dp × scale 1.0/1.3 RTL, 3 backup
  round-trip, 6 goldens day+night with Vazirmatn loaded).
- Goldens visually inspected: Persian shaping correct, day/night differ,
  icons tofu'd exactly like the repo's existing kit goldens.
- Full suite: 5258+ green؛ سه شکست — دو تای آن‌ها گاردهای سراسری بودند که
  کد تازه نقض می‌کرد (قرارداد شعاع شیت و مقیاس قلم) و هر دو رفع و سبز شدند؛
  سومی روی HEAD پایه هم شکست می‌خورد (قبل از این کار، شکاف کانال
  secure-storage در همان تست).
- APK انتشار: ۴۷٬۹۶۱٬۳۳۳ → ۴۸٬۴۹۹٬۸۲۳ بایت = **+۰٫۵۱ مگابایت** از بودجهٔ
  ۱٫۵ مگابایت (exit 0). جزئیات: docs/PERSONAL2_STAGE1_REPORT.md.
- **بدون دستگاه**: اثبات analyze/تست/باینری است، نه بازبینی روی گوشی.

---

# PROGRESS — «حساب مغازه» (`personal2/stage2-shop-core`)

Spec: brief مرحلهٔ ۲؛ قرارداد دامنه: docs/SHOP_DOMAIN.md (اول نوشته شد، کد و
تست‌ها هر دو از آن می‌خوانند). مرحلهٔ ۱ ابتدا راستی‌آزمایی شد — قطعات مشترک
دوباره ساخته نشدند.

## Done

- [x] v47 — جداول مغازه (14 جدول) با ایندکس‌های بارکد/نام/تاریخ؛ INTEGER
      برای پول و مقدار (تستِ «هرگز REAL نباشد»).
- [x] هستهٔ حسابداری خالص: گرد کردن نیم‌به‌بالا در یک تابع، فاکتور از خط‌ها +
      گرد کردنِ ذخیره‌شده، ارزیابی فروش با وارنینگ/مسدودِ سقف اعتبار، تخصیص
      FIFO، سنین بدهی، میانگین موزون costs.
- [x] DAO تراکنشی: ثبت فروش (شماره + فاکتور + اقلام + حرکت انبار + کش موجودی
      + پرداخت‌ها + دفتر + AuditLog در یک تراکنش)، ابطال معکوس دقیق، برگشت
      فروش، دریافت با پیش‌نمایش FIFO، بخشش/تعدیل با یادداشت الزامی، تغییر
      قیمت گروهی با undo دسته‌ای، verifyIntegrity (فقط گزارش، بدون اصلاح).
- [x] صفحه‌ها: نوار پایین داخلی با FAB مرکزی «فروش جدید»؛ امروز (هیرو تخت +
      نوار ترکیب پرداخت + هشدارها)؛ POS (جستجوی debounce، اسکنر کیبورد، سبد
      با تعداد اعشاری، پرداخت ترکیبی، سبد معلق، رسید از ردیف‌های ثبت‌شده)؛
      کالاها؛ مشتریان + پرونده (سنین، دفتر با ماندهٔ رونده، یادآوری مؤدبانه،
      صورت‌حساب)؛ گزارش مینیمال؛ تنظیمات با بررسی سلامت و پاک‌کردن با PIN.
- [x] ثبت «حساب مغازه» در بخش ابزارهای شخصی + مسیرها پشت VaultGuard + هویت
      رنگی سوم (shopLedger 0E7C86) با تست توازن.
- [x] اسکنر: اینترفیس + کیبورد-وج + دستی؛ دوربین به مرحلهٔ ۳ (اعداد در
      SHOP_DOMAIN.md §7).
- [x] CSV: خروجی محصولات + واردکنندهٔ ایزوله با خطای سطری فارسی، بارکد تکراری،
      ارقام فارسی، اعشار از پارسر مشترک؛ نوشتن در دسته‌های ۲۰۰تایی.

## باگ‌هایی که تست‌ها گرفتند (هیچ‌کدام تا دستگاه نرفته بود)

۱. بلاک onUpgrade v47 جا افتاده بود — دستگاه آپگرید جداول را نمی‌گرفت.
۲. ردیف تنظیمات سید نمی‌شد → همهٔ فاکتورها شمارهٔ «۱» و مرگِ فروش دوم روی
   UNIQUE شماره.
۳. برست بلند اسکنر پس از انقضا هنوز Enter را «اسکن» می‌کرد.
۴. FractionallySizedBox مستقیم در Row → w=Infinity روی نوار ترکیب پرداخت.
۵. «--1.5» در فرمت‌کن و «-1.5 → -500» در پارسر (علامت فقط روی کل).
۶. جداکنندهٔ اعشار فارسی (٫) اصلاً پارس نمی‌شد.

## اعداد

- personal2: **۲۷۰ تست سبز** (۱۱۵ تازه)؛ `flutter analyze` — ۰ خطا/۰ هشدار در
  lib/features/personal2 (۱۲۴ info از پیش موجود در جای دیگر).
- APK انتشار: ۴۸٬۴۹۹٬۸۲۳ → ۴۸٬۸۱۸٬۶۸۱ بایت = **+۰٫۳۰ مگابایت** از بودجهٔ ۲
  مگابایت (exit 0).
- بدون دستگاه: اعداد cold-start و پروفایل به اجرای `--profile` نیاز دارند.

جزئیات و باز: docs/PERSONAL2_STAGE2_REPORT.md

---

# PROGRESS — «حساب مغازه» کامل (`personal2/stage3-shop-complete`)

Spec: brief مرحلهٔ ۳؛ پیوستSHOP_DOMAIN.md §Stage3 (قرارداد علامت تأمین‌کننده،
میانگین موزون، ماشین حالت چک، فرمول صندوق).

## Done

- [x] v48 — ۱۱ جدول تازه (تأمین‌کننده، خرید + اقلام با اسنپ‌شات بهای سربار و
      میانگین قبل/بعد، هزینه + دسته + قواعد تکراری، چک، روز صندوق + تعدیلات،
      انبارگردانی + خطوط) با ایندکس‌ها؛ تستِ INTEGERبودن پول.
- [x] خرید در یک تراکنش (شمارهٔ P جدا از فروش، اقلام با تخصیص حمل و
      landed/prev/new cost، حرکت انبار، پرداخت، دفتر، AuditLog)؛ ابطال معکوس
      دقیق؛ موجودی ≤ ۰ → بهای سربار می‌شود میانگین تازه.
- [x] تأمین‌کنندگان: دفتر با علامت «+ = بدهی ما»، پرداخت FIFO با پیش‌نمایش،
      پیش‌پرداخت، پیرسازی ۰-۳۰/…/۹۰+.
- [x] چک: ماشین حالت بسته (صادره endorsement ندارد)، چک دریافتی به‌عنوان
      پرداخت از لحظه ثبت مانده مشتری را کم می‌کند («چک در جریان»)، برگشت
      دقیقاً برمی‌گرداند — روی party_type درست (تست گرفت).
- [x] صندوق: فرمول واحد، افتتاح از شمارش دیروز، بستنِ منجمد (بستن دوباره
      رد می‌شود)، اختلاف ثبت می‌شود نه اصلاح؛ هزینهٔ نقدی از کش بیرون می‌رود.
- [x] انبارگردانی: شمارش با ثبت اختلاف و اثر ارزشی، تعدیل‌های «انبارگردانی»
      در یک تراکنش، پشت تأیید.
- [x] شیت «بیشتر» در ابزار + داشبورد v2 با چهار کارت تنبل (صندوق، بدهی
      تأمین‌کنندگان، چک سررسید، هزینهٔ امروز) + verifyIntegrity بسط‌یافته.
- [x] Jalali تکرار ماه‌انه با shamsi_date (الگوریتم دست‌ساز ماه اشتباه می‌داد
      — جایگزین شد).

## باگ‌هایی که تست‌ها گرفتند

۱. landed cost بر milli تقسیم شده بود (۱۰۰٬۵۰۰ → ۱۰۱) — ضریب ×۱۰۰۰ جا افتاده
   بود. ۲. برگشت چکِ صادره روی party_type مشتری نوشته می‌شد و تراز
   تأمین‌کننده نمی‌دید. ۳. شمارندهٔ خرید ستون ناموجود می‌خواند. ۴. جا افتادن
   placeholder در INSERT دفتر (۹ مقدار برای ۱۰ ستون). ۵. جلالی دست‌ساز ماه
   غلط می‌داد. ۶. بستن دوبارهٔ صندوق ساکت رونویسی می‌کرد.

## اعداد

- personal2: **۳۲۲ تست سبز** (۵۲ تازه)؛ analyze — ۰ خطا/۰ هشدار در feature.
- APK انتشار: ۴۸٬۸۱۸٬۶۸۱ → ۴۹٬۳۶۱٬۴۶۴ بایت = **+۰٫۵۲ مگابایت** از بودجهٔ
  ۱٫۵ مگابایت (exit 0).
- بدون دستگاه: cold-start و اعداد پروفایل به اجرای `--profile` نیاز دارند.

باز: docs/PERSONAL2_STAGE3_REPORT.md §4

## Final pass — بازهای باقی‌مانده بسته شد

- برگشت از خرید: سند PR با کپ «خریداری‌شده منهای برگشتی‌های قبلی» (الگوی LIKE
  اول یک دلار escape‌شده داشت و هیچ‌وقت interpolate نمی‌شد — تست کپ گرفت)،
  کسر انبار با میانگین جاری، کسر بدهی تأمین‌کننده، یک تراکنش.
- مدیر هزینه‌های ماهانه: قواعد با فعال/غیرفعال، روز جلالی month-end-safe،
  «ثبت این ماه» شیت هزینهٔ پیش‌پر با id قاعده — یادآور فقط با لمس کاربر به
  ثبت تبدیل می‌شود.
- UI ورود CSV: انتخاب فایل → پارس در ایزولیت → پیش‌نمایش (خطای سطری فارسی،
  بارکد تکراری، نمونه ردیف‌ها) → ثبت تأییدشده در دسته‌های ۲۰۰تایی.
- هوک یادآورها: ShopReminders.rearm چک‌های ۷/۳/۰ روز و قواعد سررسید را
  محاسبه و از SoftNotifier (بازهٔ ۱۶۰۰۰+، جمع ۱۶۹۹۹) زمان‌بندی می‌کند؛ فقط
  از ذخیرهٔ تنظیمات و باز شدن شیت «بیشتر» — هرگز در استارت برنامه.
- APK: ۴۹٬۳۶۱٬۴۶۴ → ۴۹٬۴۱۰٬۲۹۸ (+۰٫۰۵ مگابایت برای همهٔ این‌ها).
- بدون دستگاه اندروید: تنها بازِ واقعی، اجرای `--profile` روی گوشی.

---

# PROGRESS — شخصال audit (شاخهٔ `personal/audit-and-polish`)

## PHASE 0/1 + اولین بیلد آیتم

- docs/PERSONAL_AUDIT/00_TRACEABILITY.md — همهٔ اقلام REQUIRED SCOPE با
  وضعیت و شواهد؛ سه FALSE CLAIM از گزارش‌های قبلی شناسایی شد.
- docs/PERSONAL_AUDIT/01_GAPS.md — فهرست شکاف‌ها با شدت و ترتیب اجرا.
- docs/PERSONAL_AUDIT/03_DECISIONS.md — تصمیم‌های خودکار + اقلام نیازمند بازبینی.
- P2-B-UNITS: تبدیل واحد کامل شد — دسته‌های مساحت و سرعت، «محلی ★» با پنج
  واحد مستند (مبنا قابل ویرایش و unverified؛ مبنیِ خالی هرگز حدس زده نمی‌شود)،
  تبدیل‌های اخیر (۶ تای ماندگار) و دستهٔ به‌یادماندنی. ریاضی در
  calculator/domain/unit_conversion.dart با ۱۲ تست؛ پنل بازنویسی شد و ۸ تست
  قدیمی پنل هم سبز ماند.
- مدیریت دسته‌های هزینه در تنظیمات مغازه (افزودن/تغییرنام/آرشیو).
- فیکس type-scale (۱۸→۱۹) که بازبینی تداخل مِرج گرفت.

## اعداد انتشار

- `release/1.8.0` (۱f۱۴e2f) build انتشار در worktree تمیز: **exit 0،
  ۵۰٬۲۲۶٬۴۱۶ بایت (۴۷٫۹ MB)**. این عدد شامل کار ویجت/family-faith جلسهٔ
  موازی هم هست (۴ba۲۸c۵ و ۸ace۴a۴) — رشدِ سهم شخصیِ audit فقط ~۴۸ کیلوبایت.
- نکتهٔ build در worktree: سه فایل gitignored لازم بود (google-services.json،
  release-key.jks، key.properties) و کش hooks_runner سی‌کیوال‌ایت۳ باید از
  مخزن اصلی کپی می‌شد (دانلود گیت‌هاب در این شبکه handshake نمی‌گذرد).
- **بازِ تنها**: اجرای `--profile` روی دستگاه اندرویدی — دستگاهی متصل نیست.

## Remains (به ترتیب اجرا؛ "continue" از P1-B-MALI شروع می‌کند)

P1-B-MALI دفتر مالی ← P1-B-DEBT دفتر دَین ← P1-A-UI خودرو/خانه ←
P1-C-ALL چهار ابزار C ← P1-F-REPORTS نمودارهای drill-down و ZIP کامل ←
P1-D-MONTHLY گزارش ماهانهٔ کودک.

## ابزارهای شخصی مرحلهٔ ۳ به گرید «ابزارها و پیشرفت» — 2026-11-04 (`b3aa551`)

کاربر: «مرحلهٔ ۳ را از اطلاعات من به ابزارها و پیشرفت منتقل کن؛ الان
نمی‌بینمشان». بررسی نشان داد هر چهار صفحه در مسیریاب ثبت بودند
(`/personal-info/relatives|qaza|kaffara|savings`) ولی **هیچ دکمه‌ای به آن‌ها
وصل نبود** — نه در «اطلاعات من» و نه در هیچ جای دیگر. عمیق‌تر: در ادغامِ
خطِ audit/۱.۸.۰ **مایگریشنِ جداولشان هم جا افتاده بود**، پس اولین خواندن در
هر چهار صفحه با `no such table: relative` می‌شکست. «دفتر مالی» دقیقاً همین
حال را داشت (`finance_*` هرگز ساخته نمی‌شد) و کفاره هم که obligation خود را
در همان دفتر می‌نویسد.

- **اسکیمای ۴۹:** `FinanceTables` + `FamilyFaithTables` به `onCreate` و به
  پلهٔ `from < 49` اضافه شدند (همه `IF NOT EXISTS`، پس اجرای دوباره بی‌اثر
  است). تست تازهٔ `app_database_schema_v49_test.dart` هم شکل تازه را قفل
  می‌کند و هم idempotent بودنِ مایگریشن را.
- **پنج کاشی تازه در `MoreGroup.tools`:** صله رحم، قضایار، کفاره و فدیه،
  قلک، دفتر مالی — با هویت رنگی خودشان در `TopicHues` (قهوه‌ای، بنفش،
  سرخ، سبزآبی؛ دفتر مالی رنگ `personalTools`). گرید ابزارها: ۱۰ → ۱۸ کاشی،
  کل رجیستری ۴۴ → ۵۲ (دو عددِ کهنه در تست‌ها که از پیش قرمز بودند هم
  هم‌تراز شدند).
- **گلدن‌ها:** ارتفاع واقعی صفحه در چهار اندازه دوباره اندازه‌گیری و قفل شد
  (۴۱۲→۲۲۹۳، ۳۲۰→۲۰۹۵، ۳۶۰→۲۱۶۶، ۳۶۰@۱.۳→۲۳۹۱) و ۱۱ گلدن بازضبط شد.
- **تست:** `test/features/personal/finance` + `family_faith` + اسکیمای ۴۹ =
  ۲۰۸ سبز؛ `test/features/settings` سبز جز ۹ قرمزِ از پیش موجود
  (`widget_palettes`/`widget_settings`)؛ `flutter analyze lib test`
  ۰ خطا/۰ هشدار. گیت `--strict` همان ۵ تخلفِ پایهٔ `906281c` را دارد (۱۰
  silent catch، ۲ `]!`، ۲ provider در فایل screen، ۲ widget wiring، ۲
  FailureView) — پیش از این کار هم قرمز بود.
- **ریلیس:** `b3aa551` → `app-release.apk` ۵۰٬۲۳۳٬۹۶۳ بایت، sha1
  `8f54b673438fbfacc243fc945354856695dfb9c5`، در
  `Desktop/tawheeed-release-apks/1.8.0-stage3tools-b3aa551/` (+`SHA1SUMS.txt`)
  و کپی در `build/app/outputs/flutter-apk/`. اثبات باینری: هر پنج عنوان و دو
  پیامِ حالت خالی FOUND.
- **هشدار ادغام:** در worktree `widget-toggles` (چک‌اوت `release/1.8.0`) یک
  نشست دیگر **حذفِ** سه کاشی `kids-habits`/`teacher-ledger`/`shop-ledger` را
  staged دارد؛ بعد از آن، اعداد قفل‌شدهٔ من (۵۲/۱۸/۴۷) باید به ۴۹/۱۵/۴۴
  برسند. `release/1.8.0` را دست نزدم تا آن WIP سالم بماند.

## معالم: شمارش دقیقاً شمارهٔ چاپی ۱…۳۹۲۱ — 2026-11-04 (`0745eda`)

کاربر: «می‌خواهم طبق نسخهٔ چاپی باشد، یعنی شمارش مثل کتاب ۳۹۲۱، دقیق مثل
کتابی که چاپ شده». پیش از این `hadith_number` شمارندهٔ ردیف بود (۱…۳۸۲۳)،
پس نشان «حدیث ۱۰۶۸» به روایتی می‌رسید که صفحهٔ کتاب زیر ۱۰۶۸ چاپ نکرده و
پرش با شمارهٔ چاپی هم جواب نداشت.

- **مبدل** (`tools/maalim_to_sqlite.py`): `hadith_number` = همان شماره‌ای که
  سطر چاپ کرده (`PRINTED_TOTAL = 3921`). چهار شمارهٔ غلطِ بزرگ‌تر از سقف
  (۳۹۶۳، ۴۲۲۵، ۴۳۲۹، ۷۳۳۴ — تایپوی خود فایل ورد) جایگاه جاری می‌گیرند تا
  آخرین شماره ۳۹۲۱ بماند، همان عددی که مقدمهٔ کتاب وعده داده.
- **چیزی «اصلاح» نشد که چاپ نشده**: ۲۴۴ شماره هرگز چاپ نشده و غایب می‌ماند
  (پرش پیام «در این نسخه موجود نیست» می‌دهد، نه نزدیک‌ترین حدیث)، و ۱۴۴
  شماره دو بار چاپ شده و هر دو روایت با همان شماره می‌مانند — به همین دلیل
  ۳۹۲۱ شماره ۳۸۲۳ روایت را نگه می‌دارد. نمونهٔ مستند: ج۲ ص۱۰۲۵ و ۱۰۳۰ هر دو
  «1076» چاپ شده‌اند؛ ج۲ ص۱۱۵۷ «117» در میانهٔ ۱۱۵۰ها.
- **`contentRevision` ۷ → ۸** تا نسخهٔ نصب‌شده دوباره دانلود کند؛ تعداد باب
  (`minChapters: 1900`) دست نخورد.
- **انتشار محتوا:** `TAWHEED-EWAZ` @ `fbc56aa` روی `main` (`6959b18..fbc56aa`)،
  فایل ۲٬۰۸۰٬۵۴۷ بایت، md5 `58542e55bce4582494e9acff01a921e9`؛ بازخوانی زندهٔ
  raw.githubusercontent (HTTP 200) همان بایت‌ها را داد؛ `pragma integrity_check`
  روی دیتابیس = ok، ۳٬۸۲۳ روایت / ۱٬۹۲۹ باب / شماره ۱…۳۹۲۱.
- **تست:** `flutter test test/features/maalim` = ۳۳ سبز.
- **ریلیس:** `0745eda` → ۵۰٬۲۳۳٬۸۵۶ بایت، sha1
  `7893059781d5dc2149b72557ac7f88c4217422d6`، در
  `Desktop/tawheeed-release-apks/1.8.0-printed-0745eda/` (+`SHA1SUMS.txt`) و
  کپی در `build/app/outputs/flutter-apk/`.

## ابزارهای شخصی: درِ خودرو/خانه، هویت رنگی واحد، نقشهٔ ایدهای اعلان — 2026-11-05 (`0006bb2`)

کاربر: این ابزارها را به «اطلاعات من» اضافه کرده بود ولی می‌خواهد **کاملاً در
«ابزارها و پیشرفت»** باشند، کامل شوند و نواقصشان برطرف شود؛ اول بررسی وضعیت،
بعد نقشهٔ فازبندی. بررسیِ کد نشان داد سه نقص واقعی وجود دارد، هر سه برطرف شد:

- **خودرو و خانه هیچ دری نداشتند.** مسیرها و صفحه‌های کامل بودند
  (`/personal-info/car`, `/personal-info/home`) ولی هیچ صفحه‌ای به آن‌ها push
  نمی‌کرد، پس کل موتور careEngine عملاً نامرئی بود (همان P0-1 ممیزی). هر دو
  کاشی تازه در `MoreGroup.tools` نشستند و همان `VaultGuard` مسیر را نگه
  داشتند. تست `more_registry_test` حالا هر ابزار شخصی را به **یک** در در همین
  بخش قفل می‌کند.
- **دو پالت برای یک ابزار.** کاشی «صله رحم» قهوه‌ای بود و صفحه رز؛ «کفاره»
  زرشکی بیرون و کهربایی درون. `lib/core/theme/tool_identity.dart` تنها منبع
  هشت هویت شد؛ `TopicHues` و سه فایل style ابزارها از آن می‌خوانند.
- **بازه‌های شناسهٔ اعلان روی هم افتاده بودند**: دفتر مالی روی بلوک کودک
  (14000+)، صله رحم روی بلوک مربی (15000+)، قضایار و قلک روی بلوک مغازه
  (16000+) — یعنی یادآوری یک ابزار یادآوری دیگری را بازنویسی می‌کرد.
  نقشهٔ تازه: 13000 care / 14000 kids / 15000 teacher / 16000 shop /
  17000 finance / 17400 relatives / 17800 qaza / 17900 savings، و
  `test/features/personal/notification_range_map_test.dart` این جدول را
  هم با خودش و هم با همهٔ بلوک‌های قدیمی اپ قفل می‌کند.
- تست کهنهٔ `care_templates` که خطِ تک‌فایلی pubspec می‌خواست (در حالی که
  پوشهٔ `assets/data/` اعلان شده) اصلاح شد.
- گلدن‌های «بیشتر» با دو کاشی تازه بازضبط شدند (۱۱ فایل). `more_screen_test`
  شمارش ۴۷ → ۴۹ و `more_registry_test` ۵۲/۱۸ → ۵۴/۲۰.
- **نقشهٔ فازبندی:** `docs/PERSONAL_TOOLS_ROADMAP.md` (وضعیت تأییدشدهٔ هر
  ابزار + شکاف‌های G-2…G-9 + فازهای ۱ تا ۷)؛ `PERSONAL_AUDIT/CHECKPOINT.md`
  به آن ارجاع داده شد.
- **تست:** `flutter test test/features/personal` = ۳۲۳ سبز؛ رجیستری ۲۱ سبز؛
  `more_screen_test` ۳۳ سبز؛ `more_content_search_test` ۳۵ سبز؛
  `flutter analyze` روی فایل‌های تغییریافته ۰ خطا/۰ هشدار.

## فاز ۱ ابزارهای شخصی: گزارش مغازه کامل شد — 2026-11-05 (`963c0a9`)

گزارش مغازه تا امروز فقط «امروز/۷ روز/۳۰ روز» و یک PDF خلاصه بود؛ موتور
(`ReportFigures`, `slowMovers`, `PeriodComparison`) و ستون‌های `last_sold_at`/
`avg_cost` از قبل آماده و تست‌شده بودند ولی هیچ صفحه‌ای از آن‌ها استفاده
نمی‌کرد. حالا تب گزارش یک گزارش واقعی است:

- **پنجرهٔ زمانی:** امروز / ۷ روز / ۳۰ روز / **این ماه شمسی** (اول ماه تا
  امروز، نه ۳۰ روز اخیر) / **بازهٔ دلخواه شمسی** با پیکر خود اپ. مرزها به
  نیمه‌شب نرمال می‌شوند، `to` با بازهٔ نیم‌باز شامل کل روز آخر است، و بازهٔ
  برعکس (تا قبل از از) جابه‌جا می‌شود تا «روز بی‌فروش» جعلی ساخته نشود.
- **ارقام:** فروش خالص، سود ناخالص (Σ خط − Σ بهای تمام‌شدهٔ لحظهٔ فروش)، سود
  خالص، برگشتی، تخفیف، هزینه + میانگین فاکتور + حاشیهٔ سود + درصد تغییر نسبت
  به دورهٔ پیش (اگر دورهٔ پیش فاکتور نداشته باشد، درصد **چاپ نمی‌شود**).
- **drill-down:** فروش خالص، هر روش پرداخت (باقی‌ماندهٔ نسیه به‌صورت «نسیه») و
  هر کالای پرفروش، فهرست فاکتورهای پشت همان عدد را باز می‌کنند؛ هر ردیف
  رسید واقعی (POS) را باز می‌کند. کالاهای کندگرد هم فهرست و «سرمایهٔ خوابیده»
  را می‌دهند.
- **خروجی:** PDF خلاصه با سود و مقایسه، و **ZIP کامل CSV** از همهٔ جدول‌های
  مغازه (مرحلهٔ ۲ و ۳) با `README.txt` واحدها. CSVها BOM یوتی‌آف-۸ دارند چون
  اکسل ویندوز فایل فارسی بدون BOM را CP1256 می‌خواند.
- provider و state مردهٔ مرحلهٔ ۲ حذف شدند. ۲۶ تست تازه: ریاضی پنجره (شامل
  لبهٔ ماه شمسی)، DAO روی ردیف‌های واقعی (باطل/برگشتی/هزینه، ترکیب نسیه،
  مقایسه، کندگردها، فیلترهای drill-down، محتوای ZIP)، و خود تب در
  ۳۲۰/۳۶۰/۴۱۲ × ۱٫۰/۱٫۳ با شیت drill-down.
- `flutter test test/features/personal2/shop` = ۱۷۵ سبز؛ `flutter analyze lib
  test` = ۰ خطا؛ گیت `--strict`: هیچ تخلف تازه‌ای از این فایل‌ها نیست
  (۹ silent catch و ۱ failure surface باقی‌مانده همان پایهٔ `906281c` است).
- **مرحلهٔ بعد:** فاز ۲ — بسته‌های فصلی خانه (G-3).

## فازهای ۲ تا ۷ ابزارهای شخصی — بسته شد — 2026-11-05 (`04d9a7d`)

بقیهٔ نقشهٔ `docs/PERSONAL_TOOLS_ROADMAP.md` تا آخر رفت. گزارش کامل و
قابل‌ارجاع: **`docs/PERSONAL_TOOLS_DELIVERY.md`**.

- **فاز ۲ (`445fdbd`) پک فصلی خانه:** `care_season_plan.dart` پنجره را از
  خودِ پک می‌خواند (نه جدول ماه)، «در پنجره / N روز تا پنجره / پنجرهٔ امسال
  گذشت» می‌گوید، تعداد باقی‌مانده را می‌آورد و وقتی پک کامل و پنجره بسته شد
  ناپدید می‌شود. ۱۲ تست + ۲ تست بنر.
- **فاز ۳ (`f582e6a`، `43f2b53`) سوئیچ‌هایی که دروغ می‌گفتند:** گزارش کودک
  بین ۷ و ۳۰ روز جابه‌جا می‌شود (تیک نمودار شمارهٔ روز، سهم‌ها و عنوان PDF
  تابع بازه)، خلاصهٔ شب هفت شب را با کلید per-day و احترام به ساعات سکوت
  زمان‌بندی می‌کند، و شیت مربی سه یادآور واقعی می‌سازد (شروع کلاس، ثبت درس،
  خلاصهٔ جمعه) — همه از `SoftNotifier` (کودک ۱۴۰۰۰+، مربی ۱۵۰۰۰+). تست‌ها
  یک باگ واقعی گرفتند: `kidDayKeyOf`/`teacherDayKeyOf` سال میلادی را به
  `Jalali(y,m,d)` می‌دادند و کلید ۲۰۲۶-۱۱-۰۵ می‌شد `3648-…`؛ هر دو حالا از
  `Jalali.fromDateTime` می‌آیند.
- **فاز ۴ (`01ba249`) ویرایش پیش‌فرض‌ها:** «تنظیم پیش‌فرض‌ها» در خودرو و خانه
  همان دو عددی را که یک «پیشنهاد» از آن ساخته شده (روز/کیلومتر) ویرایش
  می‌کند و به‌صورت سطر override با kind = `care_template` در جدول موجود
  `p2_template_override` ذخیره می‌شود — بدون تغییر schema و بدون بازنویسی
  asset؛ «بازگردانی» سطر را پاک می‌کند. ۸ تست + تست بازشدن شیت، ۴ گلدن
  بازضبط.
- **فاز ۵ (`1c824bb`):** `docs/KAFFARA_CONTENT.md` (دو قاعدهٔ `reviewed:false`،
  ریاضی، مسیر تأیید) + مرور شش ابزار در نقشه.
- **فاز ۶ (`04d9a7d`):** تست کامل چهار رگرسیون از همین کار را لو داد که هیچ
  تست فیچری نمی‌دید، چون هر گارد کل درخت را می‌خواند: سه `fontSize` خارج از
  مقیاس در `care_defaults_sheet` و یکی در شیت مربی، دو شیت گزارش با شعاع
  ۲۲ به‌جای ۲۰ تم، یک `showTimePicker` در شیت کودک و یک `showDatePicker` در
  سررسید چک. همه رفع شد (`scaledFontSize`، حذف `shape:`،
  `showLatinTimePicker`، `showShamsiDatePicker`) و سه گارد دوباره سبز شدند.
- **ریلیس (`04d9a7d`)** از درخت تمیز detached با چهار فایل gitignored:
  `app-release.apk` ۴۹٬۹۹۵٬۴۴۴ بایت (۴۷٫۷ مگابایت)،
  sha1 `4c919b826f3797c69c46fae554d9a4293cd022ae`، `version: 1.8.0+10017`.
  ABI split عمداً ساخته نمی‌شود (بلوک `splits` در build.gradle خاموش است).
  نسخهٔ پایدار: `Desktop/tawheeed-release-apks/1.8.0-04d9a7d/` با
  `SHA1SUMS.txt` و `BINARY_PROOF.txt` — اثبات باینری UTF-16LE در هر دو
  alignment: ۱۲/۱۲ رشتهٔ تازه FOUND، ۳/۳ شکل CP1256 ABSENT.
- **تأیید:** `test/features/personal` + `test/features/personal2` = ۷۰۶ سبز؛
  سه گارد تمیز = ۱۱ سبز؛ `flutter analyze lib test` = ۰ خطا/۰ هشدار؛
  `quality_check.py --strict` فقط همان قرمزهای پایه. تست کامل روی `1c824bb`:
  ۵۸۱۷ سبز / ۹ skip / ۲۰ شکست که ۳تایش مال این کار بود (رفع شد) و بقیه در
  `release/1.8.0` هم قرمزند (google-services غایب در worktree، schema v47 در
  برابر ۴۹، پالت ویجت ۹→۸، `AndroidRemoteViews`، دو تست حساب/اطلاعات شخصی).
- **باز مانده و فقط با کاربر بسته می‌شود:** G-7 (متن/عدد کفاره) و G-8 (پاس
  روی دستگاه — گوشی وصل نیست، پس همهٔ شواهد تست/گلدن/باینری است). ادغام در
  `release/1.8.0` هم انجام نشده چون آن شاخه جلو رفته (`d2de107`) و نشست
  موازی روی همان درخت کار می‌کند.

## ادغام شاخهٔ `personal/stage3-family-faith` در ابزارهای شخصی — 2026-11-05

شاخه‌ای که کاربر از آن APK می‌گرفت (`personal/stage3-family-faith`، tip `795b0ac`، ۲۲
کامیت روی پایهٔ `0ab1994`) با خط یکپارچهٔ ۱.۸.۰ + فازهای ۰ تا ۷ ادغام شد. هر دو خط
همان ابزارها را جدا ساخته بودند (خودرو/خانه، دفتر مالی، تبدیل واحد، کفاره/قضا/صله
رحم/قلک) و دیف فایل‌ها کوچک بود، پس در هر تعارض نسخهٔ خط یکپارچه گرفته شد — که
همان کد است به‌علاوهٔ فازهای ۲ تا ۴ و رفع گاردها — و تنها استثناها این‌ها بودند:

- `app_database.dart`: شمارهٔ ۴۹ می‌ماند، ولی بلوک `from < 49` حالا مجموعه‌جدول‌های
  `Personal2Tables`/`ShopTables`/`Shop3Tables` را هم با `IF NOT EXISTS` می‌سازد.
  دلیل: آن خط شماره‌گذاری خودش را داشت (مالی = ۴۶، ابزارهای خانواده = ۴۷)، پس نصبی
  که از آن بیلد به ۴۹ می‌آید بلوک ۴۶/۴۷ را رد می‌کرد و جدول‌های کودک/مربی و مغازه
  هرگز ساخته نمی‌شد.
- `PROGRESS.md`: لاگ خط یکپارچه می‌ماند و همین بخش به آن اضافه شد؛ لاگ‌های اصلی آن
  شاخه در تاریخ خودش (`795b0ac` و پیش از آن) دست‌نخورده است.

کامیت‌های آن شاخه که اکنون در تاریخ این خط هستند:

- 795b0ac feat(maalim): all four volumes, numbered the way the printed book is
- 0f70cc5 test(personal): 136 tests, goldens and the backup round trip for stage 3
- f523824 feat(personal): wire the four tools into the vault, schema 47
- e9ab53f feat(personal): the four stage-3 screens
- b605555 feat(personal): stage-3 data layer and pure engines
- 656e2dc docs(personal): stage-3 plan and the fiqh inventory check
- ae2ca19 docs(personal): record the stage-2 suite result
- 538f81c docs(personal): stage-2 plan, delivery report and progress log
- 8ead331 test(personal): 110 tests for finance, the converter and schema 46
- 7faf85e feat(personal): wire finance into the vault, schema 46 and notifications
- ad8220a feat(calculator): «تبدیل واحد» as a tab, sharing the keypad
- 7978d4b feat(calculator): unit catalog, converter engine and local bases
- 99acde4 feat(personal): «دفتر مالی» screens on the shared kit
- 3a99558 feat(personal): finance data layer for «دفتر مالی»
- 6accd53 docs(personal): correct the delivered test count to 113
- d67b868 chore(personal): keep the new tests lint-clean
- e8c7f98 docs(personal): stage-1 inventory, care engine contract and delivery report
- a8abff8 test(personal): engine, storage, planner, layout and goldens
- 116a70e feat(personal): «خودرو» and «خانه» inside «اطلاعات من»
- a25cba5 feat(personal): 30-day care reminders on the existing notification service
- 7e21647 feat(personal): nine care tables on schema 45
- b309af1 feat(personal): shared care engine and its editable defaults
### ریلیس همین شاخه + حقیقت عدد معالم — 2026-11-06 (`2b237ec`)

- کاربرها می‌گفتند «تعداد احادیث ۳۸۲۳» غلط است. خودِ پایگاه‌دادهٔ میزبانی‌شده
  (`maalim/maalim.db.gz`، دانلود و بازرسی‌شده) می‌گوید: **۳۸۲۳ روایت**، شمارهٔ
  چاپی ۱ تا **۳۹۲۱**، ۳۶۷۷ شمارهٔ استفاده‌شده، **۲۴۴ شمارهٔ بی‌استفاده** و
  **۱۴۴ شماره‌ای که دو بار چاپ شده** (۱۴۶ سطر اضافه). پس ۳۸۲۳ جواب درست است و
  ۳۹۲۱ شمارهٔ آخر؛ حالا زیر چیپ‌ها یک خط «شمارهٔ چاپی ۱ تا ۳٬۹۲۱» چاپ می‌شود
  تا این دو با هم اشتباه گرفته نشوند.
- نکتهٔ مهم برای نصب: تا پیش از این ادغام، شاخهٔ بیلد `contentRevision` نداشت،
  پس نسخهٔ کهنهٔ `maalim.db` روی گوشی هرگز جایگزین نمی‌شد؛ حالا `maalim` روی
  revision 8 است و نصبی که db قدیمی دارد یک بار دوباره دانلود می‌کند.
- دو تست `kid_evening_summary`/`teacher_reminders` تاریخ ثابت ۲۰۲۶-۱۱-۰۵
  داشتند و `SoftNotifier` هر مقصدِ گذشته را رد می‌کند، پس فردای همان روز قرمز
  شدند؛ حالا از «فردا» شروع می‌کنند. تست اسکیمای مغازه هم به ۴۹ رسید.
- **ریلیس (`2b237ec`)**: `app-release.apk` ۵۰٬۰۰۰٬۲۷۲ بایت (۴۷٫۷ مگابایت)،
  sha1 `7414e9b0181eb4b7bc93937f9b5c94f716a64a13`، `version: 1.8.0+10017`؛
  نسخهٔ پایدار در `Desktop/tawheeed-release-apks/1.8.0-2b237ec/` با
  `SHA1SUMS.txt` و `BINARY_PROOF.txt` (۸/۸ رشته FOUND، ۳/۳ مویبیک ABSENT).
- تست‌های هدفمند پس از ادغام: `maalim` + `personal` + `personal2` +
  `tools/calculator` = ۸۳۸ سبز؛ `flutter analyze lib` = ۰ خطا/۰ هشدار.
## مجموعهٔ ۲ ابزارهای شخصی — وضعیت کامل و ریلیس (`e065f7e`) — 2026-11-06

هر سه مرحلهٔ «ابزارهای شخصی — مجموعهٔ ۲» در همین شاخه پیاده و از «ابزارها و پیشرفت»
باز می‌شوند؛ هیچ صفحهٔ hub اضافه نشد و ردیف تازه‌ای به Home/More اضافه نشد.

- **مرحلهٔ ۱ — «دفتر عادت کودک» + «دفتر مربی قرآن»**: ۷ صفحهٔ کودک (خانه، راه‌اندازی
  کودک، حالت کودک با چیپ‌های نمازِ LOCKED/NOW/DONE، عادت‌ها، جایزه‌ها، صف تأیید، گزارش
  هفتگی) و ۵ صفحهٔ مربی (خانهٔ کلاس، برگهٔ درس با «باز کردن در مصحف» و
  `previewOnly`، پروفایل شاگرد با نوار جزء، گزارش والدین، مدیریت کلاس).
- **مرحلهٔ ۲ — «حساب مغازه» بخش ۱**: POS (جستجو/اسکنر، ستاره‌دار، سبد، تخفیف،
  پرداخت ترکیبی، نگه‌داشتن سبد)، مشتریان + دفترِ FIFO/بخشش، کالاها، گزارش کوتاه،
  تنظیمات، `verifyIntegrity`.
- **مرحلهٔ ۳ — بخش ۲**: تأمین‌کنندگان و خرید با میانگین متحرک، هزینه‌ها و هزینه‌های
  تکرارشونده، چک‌ها با ماشین حالت و اثر معکوس، صندوق روزانه، انبارگردانی، گزارش کامل
  (سود ناخالص/COGS/کم‌گردش/ارزش انبار/سالمندی)، خروجی و ورودی CSV — همه در شیت
  «بیشتر» همان ابزار، بدون ردیف تازه در More.
- **تنها سوراخ واقعی که این پاس بست (`e065f7e`)**: `applyBulkPriceChange` +
  `undoBulkPriceChange` در DAO بود، تست داشت، ولی **هیچ‌جا در UI صدا زده نمی‌شد**؛
  ردیف ابزار کالاها فقط CSV داشت. حالا چیپ «تغییر قیمت گروهی» شیت
  `shop_bulk_price_sheet.dart` را باز می‌کند: درصد/مبلغ، پیش‌نمایش تفاوتِ همان
  فهرستِ فیلترشده، اعمال و «واگرد» روی همان دسته. ضمناً `roundingStep` که DAO
  می‌گرفت و **اعمال نمی‌کرد** حالا واقعاً قیمت را به مضربِ گردش می‌برد و پیش‌نمایش و
  نوشتن از یک تابع (`bulkPriceAfter`) می‌آیند تا هرگز اختلاف نداشته باشند.
- **ثبت در بخش**: `more_registry.dart` هر سه را در `MoreGroup.tools` دارد
  (`kids-habits`, `teacher-ledger`, `shop-ledger`) و `more_registry_test.dart`
  عضویتشان را pin می‌کند. مسیرها `/kids`, `/teacher`, `/shop` هستند و قفلِ پین
  سرِ **عمل‌های حساس** می‌ماند (ParentLock)، نه سرِ ورود به ابزار.
- **تست**: `flutter test --exclude-tags network` = **5841 passed / 9 skipped /
  11 failed**. یازده قرمزِ باقی‌مانده هیچ‌کدام از این کار نیست و روی همین شاخه پیش
  از آن هم بود:
  - `widget_palettes_test` (۷) — تست هنوز قراردادِ قدیمی «۹ پریست + طلایی + auto»
    را می‌خواهد، ولی `bd3bd8d` جدول را عمداً به ۸ پریستِ بریف تغییر داده و «طلایی»
    را بازنشسته کرده (نگاشت به `brown_gold`). دو تست کنتراست هم `text` را روی
    `bg` می‌سنجند، در حالی که پریست‌ها گرادیان `bg → bgEnd` دارند و سایهٔ متن
    سیاستِ مستند است.
  - `widget_settings_screen_test` (۲) — همان قرارداد.
  - `widget_layout_allowlist_test` (۱) — گارد «هیچ `AndroidRemoteViews`» را
    `d35675f` نوشت، ولی `beea4f4` (۲۰۲۶-۱۱-۰۳) عمداً دو برگِ تیک‌زن را به شکل
    `AndroidRemoteViews` برگرداند؛ گارد و طراحی با هم نمی‌خوانند و تصمیمش با
    نشست ویجت است.
  - `account_screen_test` (۱) — پرسش رمزِ پشتیبانِ رمزنگاری‌شده.
  این‌ها با تصمیم صاحبشان (نه با شل‌کردن assertion) باید بسته شوند.
- **ریلیس (`9d6276f`)** — `flutter build apk --release` در همین worktree با چهار فایل gitignored موجود: fat APK ۵۰٬۰۲۵٬۵۰۶ بایت (۴۷٫۷ مگابایت)، sha1 `c56e4ecd1e664d76a9bae2ccbc6013ef7185036f`، `version: 1.8.0+10017`؛ نسخهٔ پایدار `Desktop/tawheeed-release-apks/1.8.0-9d6276f/` با `SHA1SUMS.txt` و `BINARY_PROOF.txt` (۱۰/۱۰ رشته FOUND در هر دو alignment: دفتر عادت کودک، دفتر مربی قرآن، حساب مغازه، تغییر قیمت گروهی، واگرد، انبارگردانی، تأمین‌کنندگان، باز کردن در مصحف، حالت کودک، گزارش والدین؛ ۰ فرم mojibake).

- **پاس دوم (`9d6276f`) — گیت سخت دوباره صفر شد، و نوتیفیکیشن ساعتِ فراخوان را می‌پذیرد:**
  - چهار `catch` که فقط `0` برمی‌گرداندند (لودرهای مرحلهٔ ۳) و پنج `catch` در صفحه‌های POS/رسید/گزارش والدین اکنون `AppLogger.error` دارند؛ دو `]!` (`chequeTransitions[from]!` و `_localBases[unit]!`) به fallback تبدیل شدند. `shop_stage3_providers.dart` و `studentsProvider` از فایل صفحه به `providers/` منتقل شدند (گیت #۳).
  - **باگ واقعی ساعت:** `SoftNotifier.schedule` هدف را با `TZDateTime.now()` می‌سنجید، نه با `now`ی که سرویس از قبل «امروز» را از آن ساخته بود؛ پس نوتیفیکیشن ۲۳:۰۰ بسته به ساعت دیوار یا حذف می‌شد یا یک روز جلو می‌افتاد و تست `kid_evening_summary_test` فقط تا قبل از ۲۳:۰۰ سبز بود. `schedule(now:)` اضافه شد و سرویس کودک ساعت خودش را می‌دهد.
  - تست هدفمند این پاس: `flutter test test/features/personal2 test/features/tools/calculator` = **۳۹۵ passed / 0 failed**؛ `flutter analyze lib test` = ۰ error / ۰ warning؛ گیت سخت = **۹ از ۱۰**.
  - تنها گیتِ باقی‌مانده `widget wiring` (۲) است: `PrayerGlanceWidget.kt` و `WidgetFormatting.kt` مستقیم `AndroidRemoteViews` می‌سازند، در حالی که گارد می‌خواهد از `widget/WidgetLiveLeaves.kt` عبور کند — همان تعارضی که `widget_layout_allowlist_test` را هم قرمز کرده. تصمیمش با نشست ویجت است.

## نسخهٔ ۱٫۹٫۰ — بازبینی نهایی مجموعهٔ ۲ و ریلیس (`release/1.9.0`) — 2026-11-06

شاخهٔ `release/1.9.0` از نوک کار مجموعهٔ ۲ ساخته شد؛ `version: 1.9.0+10018`.
`versionCode` طبق فریزِ عمدی gradle همان مقدار ثابت می‌ماند و فقط `versionName`
جابه‌جا شد (کامنتِ همان بلوک هم به ۱٫۹٫۰ اصلاح شد).

- **بازبینی چشمی/ساختاری:** همهٔ ۱۸ صفحهٔ سه بخش ورودی دارند (هیچ صفحهٔ مرده‌ای
  نیست)، همه از کیت مشترک استفاده می‌کنند (`DuotoneIconTile` ۲۷، `SectionHeader` ۲۵،
  `FailureView` ۱۵، `AppEmptyState` ۹)، `elevation: 0` در همه‌جا (قرارداد بدون سایه).
- **چهار نقص واقعی که با پمپ کردن هر صفحه در ۳۲۰dp × ۱٫۳ کشف و رفع شد (`24ab72b`):**
  1. هیروی «دفتر عادت کودک» دو چیپش را در یک `Row` می‌گذاشت و ۱۶۲ پیکسل سرریز
     می‌کرد؛ حالا `Wrap` + `Flexible` + ellipsis.
  2. کاشی عادت در «حالت کودک» ۳۴ پیکسل از پایین بریده می‌شد چون ارتفاعش از عرض
     ستون می‌آمد نه از مقیاس متن؛ حالا `mainAxisExtent = max(width/1.32, 112×scale)`.
  3. لِجند روش پرداخت در داشبورد مغازه (۶۹px) و ردیف جمع هزینه‌ها (۵۵px) سرریز
     می‌کردند؛ اولی `Flexible`, دومی `Expanded` شد. برچسب تب‌های نوار پایین مغازه
     هم با `FittedBox` در یک خط می‌ماند.
  4. **مشترک کل اپ:** هر `AppCard` غیرِکلیک‌پذیر رنگش را در `Container` می‌کشت و
     هر `ListTile`/`SwitchListTile` داخلش assertion «ink splashes may be invisible»
     می‌داد (در بیلد دیباگ کرش، در ریلیس ripple نامرئی). `AppCard` حالا فرزندش را در
     `Material(type: transparency)` می‌گذارد — پیکسل‌ها دست‌نخورده (همهٔ گلدن‌های
     More/تقویم/personal2/مغازه سبز ماندند).
- **تست‌های تازه:** ۱۲ تست دیتابیسی برای دفتر مربی (که هیچ نداشت: جلسهٔ یکتا،
  شمارهٔ جلسه، جایگزینی حضور، حذف کامل یک شاگرد، محدودهٔ درس، تنظیمات) و ۱۷ پمپ
  صفحه برای کودک/مربی/مغازه در ۳۲۰dp با متن ۱٫۳×.
- **سنجش:** `flutter test --exclude-tags network` = **۵۸۷۰ passed / ۹ skipped /
  ۱۱ failed** (همان ۱۱ قرمزِ موروثی ویجت/اکانت، هیچ‌کدام از این کار)؛
  `flutter analyze lib test` = ۰ error / ۰ warning؛ گیت سخت ۹ از ۱۰ (تنها
  `widget wiring` که تصمیمش با نشست ویجت است).
- **APK (`00c2d4d`)**: fat ۵۰٬۰۲۹٬۷۶۶ بایت (۴۷٫۷ MB)، sha1
  `e77a93fe050a5879070765b86fa4ebc680005b0d`؛ `versionName` در
  `AndroidManifest.xml` = **۱٫۹٫۰** (تأییدشده در باینری)؛ ۱۰/۱۰ رشتهٔ فارسی FOUND،
  ۰ فرم mojibake. نسخهٔ پایدار: `Desktop/tawheeed-release-apks/1.9.0-00c2d4d/`
  (+ `SHA1SUMS.txt`, `BINARY_PROOF.txt`). **دستگاه اندروید وصل نبود**، پس این
  گواهیِ تست/گلدن/باینری است نه اجرای روی گوشی.
