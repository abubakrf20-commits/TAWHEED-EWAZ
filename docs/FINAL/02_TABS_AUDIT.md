# Phase 2 — Tab-by-tab audit (static; no device)

Method: source scans + targeted reads. No on-device frame times, memory
snapshots or battery drain could be measured (no device attached) — those
cells say NOT MEASURED instead of guessing. Overflow behavior is covered by
the existing 320dp/1.3 widget tests where they exist; gaps are listed.

## 2.1 Global UI rules (whole `lib/`)

- **BackdropFilter: zero.** Only two doc-comment mentions; no widget uses it.
- **`Opacity(`: one site** — `qibla_screen.dart:1620`, a static
  `Opacity(opacity: isPassed ? 0.45 : 1.0)` around a moment row. Forces a
  saveLayer even at 1.0. Fix (Phase 6, F1): only wrap when faded.
- **`blurRadius > 8`: ~40 sites, all static card/hero shadows** in legacy
  feature files (`card_design_system.dart` up to 30, `theme.dart` 14/24,
  duas/khatm/education/tasks/hadith share art 10–24, qibla compass 20,
  map picker 16). No animated blur. These are *visual design* (shadow
  softness), so per the no-redesign rule they are **recorded, not changed**:
  P3 batch for the phased plan (a shared shadow-token pass, only with user
  approval). The new kit (`settings_components.dart`, hero shells) already
  documents the no-blur contract.
- **RepaintBoundary on live parts: present** — home hero + arc + countdown,
  mushaf pages, qibla compass card, daily summary, timeline, splash coin,
  More search strip, all share-image cards.
- **Per-second work: isolated.** Home seconds ring/digits, hero countdown,
  pomodoro ticker, audio/quran sleep timers, tasbih quick-timer — each inside
  its own `State` + `RepaintBoundary` where painted. No log call inside any
  tick callback (verified Phase 1).
- **Dispose: correct on sampled timers/sensors** — qibla compass subscription
  + countdown (`dispose` cancels both), azkar midnight timer, reminders
  date-check + hide timers, tasbih/book/pomodoro tickers. No orphan-timer
  evidence found in the sampled set.
- **Lists: lazy where long** — hadith books/detail/list/chapter/search all
  `ListView.builder`; duas/hadith entries verified; share screens use short
  static `ListView`s (fine).
- **Number/bidi layer exists** (`number_format.dart`: LTR-isolated fractions,
  U+2212 signed minus, Persian-digit option) — adoption gaps, if any, are a
  per-screen P3 item, not a systemic hole.
- **Tap targets/semantics/contrast: NOT MEASURED on device.** Code uses ≥44dp
  steppers and shared rows; painters mostly lack `semanticsLabel` (except the
  evaluation ring). TalkBack pass needs a phone → roadmap.

## 2.2 Per-tab findings (only non-DONE items listed)

| Tab | State | Findings |
|---|---|---|
| Home | recent, hands-off | 8 failing tests come from the parallel WIP (Phase 0 proof). No audit edits. |
| Quran reader | protected, hands-off | Only the Phase-1 log demotion touched it. Page cache bounds + font memory: NOT MEASURED. |
| Calendar | recent, hands-off | `Navigator.push` guard test in place. No edits. |
| Report/Evaluation | recent, hands-off | Ring (not arc) per user ruling. No edits. |
| Tasbih | recent, hands-off | No logs in widget; timers disposed. No edits. |
| More/Settings/About/Widgets/Splash | recent, hands-off | No edits. |
| Prayer (qibla) | audited | **T1** `Opacity(` static row (F1). Compass lifecycle clean; calibration/haptic/no-sensor fallback NOT verified without device. |
| Hadith books | audited | **T2** four inner screens (detail/list/chapter/search) are transparent scaffolds pushed via `Navigator.push` outside the router's `_ambient` → **black background** (same class as sciences). Entry route is ambient-wrapped, so only inner pages affected. Fix F2a. |
| Duas / Adhkar share | audited | **T3** `DuaShareScreen`, `AdhkarShareScreen` same black-bg class (full interactive pages, transparent scaffold, `Navigator.push`). Fix F2b/F2c. (`DuaDetailScreen`/`AdhkarCategoryPage` use opaque themed scaffolds — fine.) |
| Dua-from-Quran share | audited | **T4** `DuaFromQuranShareScreen` same class. Fix F2d. |
| Ketabkhaneh | audited | **T5** `ReadingStatsScreen` same class (`BookReaderScreen` uses an opaque `_bgColor` — fine). Fix F2e. |
| Moon/mansions, zakat, fasting, hajj, inheritance calc, expenses, notes, dongi, tasks, library, hifz, khatm, ruqyah, period, qaf, onboarding, account/cloud | scanned | No volume/perf violations found in the pattern scans; blur>8 shadows recorded under 2.1; deep functional verification (accuracy, states, validation) belongs to the feature-accuracy pass, not this UI/perf audit. |

## 2.3 What Phase 2 did NOT do (honest gaps)

Frame-time/jank/memory/battery numbers, TalkBack, 48dp tap-target
measurement, contrast measurement, on-device overflow confirmation — all need
a phone. The static gates above are necessary but not sufficient; the device
pass stays open in every downstream report.
