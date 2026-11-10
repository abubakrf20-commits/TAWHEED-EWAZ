# Phase 1 — Log audit (root causes, fixes, deferrals)

Scope: excessive logging (volume reaching the console/file), not log quality
in general. All fixes are behavior-neutral log-level demotions.

## Method

Scanned `lib/` for `print(`/`debugPrint(`, `developer.log`, `stderr`,
`AppLogger.*(` call sites, and every `Timer.periodic` for per-tick logging.
`flutter analyze` and the strict quality gate were green throughout.

## Category verdicts

| Cat | Meaning | Verdict |
|---|---|---|
| A. stray print/debugPrint | Leftover prints in rebuilds/listeners | **Clean.** Zero outside `app_logger.dart` itself (6 sites, all `kDebugMode`-gated). `avoid_print` lint is on. |
| B. recurring error logs | Same exception/stack flooding | **None found.** `warning`/`error` sites sit in failure paths (catch blocks, guarded by the strict gate's no-silent-catch rule) and fire on failure only. |
| C. lifecycle logs | Per-navigate/resume chatter | **None persisted.** Startup phase timings (`main.dart:45`) are a handful of lines. |
| D. timing/timer logs | Per-second/per-tick logging | **None.** All 14 `Timer.periodic` sites checked (tasbih quick-timer, pomodoro ticker, audio sleep timers, midnight/date-check timers, widget sync, qibla countdown): zero log calls inside tick callbacks. |
| E. third-party logs | `package:` prefixes in logcat | **Not measurable** (no device/logcat). Nothing in code routes third-party SDK output into `AppLogger`. |
| F. rebuild loops | Logging inside `build()` of hot widgets | **None.** Home/More build methods carry no log calls. |

## Fixed in this phase (2 commits)

### L1 — `mushaf_nav` persisted on every page turn (volume)
- `lib/features/quran/mushaf/quran_mushaf_view.dart:737` (`_onPageChanged`
  settle), `:904` (dropped audio-follow), `:912` (programmatic nav).
- `AppLogger.info` persists to the on-device file; a fast swipe through N
  pages wrote N lines (plus every audio-follow page turn during playback).
- Fix: demoted all three to `AppLogger.debug` (debug console only, never the
  release file). The page itself remains persisted via `quran_last_page`, so
  no diagnostic is lost that isn't already stored.
- **Protected-file note:** `quran_mushaf_view.dart` is in the protected mushaf
  bundle. This edit changes three log-level calls only — no widget, layout,
  text, routing or behavior change; trivially revertible. Done under the
  audit's explicit log-fix mandate; flagged here for the user's veto.
- Verified: analyze clean on the file; `quran_mushaf_widget_test`,
  `mushaf_nav_policy_test`, `mushaf_reader_prefs_test` — 45/45 pass.

### L2 — FCM token fragment in the shareable log file (privacy)
- `lib/shared/services/firebase_push_service.dart:54` persisted a 12-char FCM
  token prefix via `AppLogger.info`. The diagnostics screen can share this
  file off-device; a credential fragment does not belong in it.
- Fix: demoted to `AppLogger.debug`. (The user's email in
  `google_auth_service.dart:76` was reviewed and left: `_scrub` redacts
  emails before persisting.)
- Verified: analyze clean on the file; no test references the log text.

## Deferred (documented, not fixed here)

### L3 — ~100× bare `'operation failed'` warnings without `$e` (quality, not volume)
- Pattern: `AppLogger.warning('<tag>', 'operation failed')` with no error
  attached — satisfies the no-silent-catch gate but carries zero diagnostic
  value. Spread across ~40 files (audio_library_player 15, pomodoro 11,
  ruqyah_audio 8, quran services, hadeeth_enc, fasting, suggestions, …).
  Precedent: `main.dart:214` notes an earlier audit already enriched one such
  site ("used to be a bare 'operation failed'").
- Why deferred: (1) these fire on failure only — no volume to remove, so out
  of Phase 1's mandate; (2) proper enrichment needs per-site care (`catch (_)`
  has no `e` in scope; operation names must be written by hand); (3) several
  sites live in protected files (`personal_info/*`, mushaf-bundle quran
  services, `duas_screen.dart` neighbours) and need explicit authorization.
- Goes to `05_PHASED_FIX_PLAN.md` as a P3 batch (file-by-file enrichment with
  tests untouched — log text has no test contract today).

## What was deliberately NOT changed

- `AppLogger` itself: console is already debug-only; file has scrub + 150 KB
  cap + rotation; `debug()` never persists. No change needed.
- `success` logs (11 sites: scheduler syncs, mute/unmute, uploads): rare,
  intentional trail. Kept.
- Per-failure `warning`/`error` logs: required by the strict gate; removing
  them would reintroduce silent catches. Kept.

## Verification

- `flutter analyze` on both touched files: no issues.
- Quran mushaf widget/policy/prefs tests: 45/45 pass.
- Full-suite re-run happens after each fix batch per the audit rule (see
  PROGRESS.md); no test asserts on the changed log text (verified by grep for
  `mushaf_nav` / `FCM token` under `test/`).
