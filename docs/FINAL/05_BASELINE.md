# 07 — BASELINE (measured before any change)

**Base:** `release/1.8.0` @ `dccdcfd` in worktree `final-map`, measured **2026-10-12**
on the user's machine (Windows, Flutter 3.44.4 stable / Dart 3.12.2) unless stated.
Device numbers come from the attached **POCO 2412DPC0AG — Android 16 (API 36),
1220×2712, arm64**; the installed build is the 1.8.0 line (`versionCode
2000010015`, `versionName 1.8.0`, last update 2026-10-12 12:35). This device is
**mid-range, not the A13/A32 target class** — treat device numbers as optimistic.
Prior reference: `docs/BASELINE.md` (measured at `3a532e5`, 2026-10-09).

## 1. Static analysis

| Check | Result (today, `final-map`) |
|---|---|
| `flutter analyze` | **192 issues = 0 errors + 2 warnings + 190 info** (exit 1) |
| Warnings | `override_on_non_overriding_member` ×2 — `test/core/database/mock_daos.dart:255,260` (test-only, pre-existing) |
| Info lint codes | `avoid_redundant_argument_values` ×134, `prefer_const_constructors` ×31, `curly_braces_in_flow_control_structures` ×13, `unnecessary_import` ×5, `prefer_const_declarations` ×4, others ×6 |
| `python tools/quality_check.py --strict` | **7/7 gates at zero**, exit 0 |

Compared with `docs/BASELINE.md` (80 issues at `3a532e5`): the info count grew mostly
with test-suite growth (134 redundant-argument infos are new test call sites); there
are still **0 errors**.

## 2. Tests

| Metric | Result |
|---|---|
| `flutter test` (full suite, network tag included) | **3501 passed, 9 skipped, 6 failed** — exit 1, wall ≈ 6 min |
| Test files | **405** (`find test -name '*_test.dart'`) |
| Golden baselines | **85 PNGs** in 10 groups (settings 20, home 11, qcf4 15, splash 8, calendar 7, design-system 4, quran sheets 3, inheritance 2, worship 1) + 18 failure-diff PNGs left in `test/features/home/presentation/screens/failures/` |
| Failing tests (all 6 pre-existing, none from PART 1) | 1 × `type_scale_guard_test` (`tasbih_counter_widget.dart:1276 fontSize: 9.5` — off the shared scale) + 5 × `home_golden_test` full-page baselines (the harness freezes only `second`, so the hero prints real wall-clock `minute` — see AGENTS.md) |
| Feature test spread | tools 81, quran 37, prayer 35, settings 27, home 17, adhkar 17, goals 12, audio_library 11, personal_info 9, dorar 9, … (34 feature dirs, thinnest: yaqeen/onboarding/hajj/fasting/dua_from_quran = 1 each — `docs/COVERAGE_GAPS.md`) |
| Kotlin unit tests | 5 files (~540 LOC): exact-alarm registry, widget calculator, countdown, tasbih counting + daily reset |

## 3. Build artefacts & size

| Artefact | Value |
|---|---|
| Version | `1.8.0+10015` (pubspec single source; `versionCode = abiMajor·1e8 + 10015`) |
| Latest durable release APKs (tip-equivalent, `1.8.0-b95411d`) | fat `47,330,963 B (45.1 MiB)`, `arm64-v8a` `31,438,206 B`, `armeabi-v7a` `31,690,595 B`; sha1 in `Desktop/tawheeed-release-apks/1.8.0-b95411d/SHA1SUMS.txt` |
| Note | `dccdcfd` differs from that build by **docs-only** commits → the two are binary-equivalent |
| ABI policy | splits + universal fat APK; `abiFilters` armeabi-v7a/arm64-v8a; x86/x86_64 excluded; verified R8 + resource shrinking on |
| Bundled assets (pubspec-declared) | **≤ 14 MB gate green**; on-disk `assets/` = 20 MB of which declared ≈ 13.7 MB (undeclared repo-only files: `persian_ih.epub` 1.1 MB, `persian_ih_v1.1.3-csv.1.csv` 1.7 MB, `logo_icon.png`, `logo3.png`) |
| Fonts | Vazirmatn ×4, Amiri ×2, Calibri, `qcf4/surah-name-v4.ttf`, `quran-common.ttf` = 3.2 MB |
| Dead weight found | `flutter_svg` declared with **0 imports** in `lib/`; `assets/quran/surah_header.png` (122 KB) still declared although the header is custom-painted — both candidates (01_FINDINGS F-22/F-23) |

## 4. Device baseline (POCO 2412DPC0AG, Android 16, arm64)

| Metric | Result | Method |
|---|---|---|
| Cold start (activity), 5 runs after `am force-stop` | **825 / 528 / 526 / 562 / 530 ms** (median 530 ms) | `adb shell am start -W` `TotalTime` |
| Memory (after the 5 launches + idle) | **TOTAL PSS 350,527 KB (~342 MB)**; RSS 491,626 KB; native heap 67.5 MB, dalvik 10.5 MB | `dumpsys meminfo com.islamic.tawheeed` |
| Idle CPU | not re-measured today (prior baseline: 0.0 % at `3a532e5`) | — |
| Frame times / jank | **not measurable** on this device: Impeller does not feed SurfaceFlinger FrameMetrics; a `flutter drive --profile` run requires uninstalling the release app (erases app data) — user decision | prior experience in `docs/BASELINE.md` §6 |
| Screen-level evidence | `docs/device-verify/*.png` (10 screenshots: home, more, quran, settings, tasbih, calendar, report, personal_info, phase_night, home_scrolled) — captured 2026-10-09 at `3a532e5` | — |

## 5. Performance-relevant facts on this tree (re-verified today)

- **Zero `BackdropFilter`** in production code; the only occurrence is the comment in
  `glass_surface.dart:13`.
- **One `Opacity(`** — `lib/features/prayer/presentation/screens/qibla_screen.dart:1620`.
- `BoxShadow` with `blurRadius ≥ 10`: concentrated in the **legacy** systems
  (`core/design_system/card_design_system.dart` 14/18/22/30, `core/theme/theme.dart`
  14/24, `duas_screen.dart` 10/10/14, …). The new kit paints no blur.
- Source size: `lib/` = 148,402 lines of Dart (97,997 excluding generated), largest
  files `quran_mushaf_view.dart` 2716, `evaluation_stats_widget.dart` 1927,
  `page_data.dart` 1879, `notification_service.dart` 1863, `settings_screen.dart`
  1850, `zakat_screen.dart` 1849, `inheritance_calculator_tab.dart` 1806,
  `ketabkhaneh_screen.dart` 1805.
- **0 `TODO/FIXME/HACK`** in `lib/`; no real `print(` call; 9 `// ignore:` suppressions.
- `Semantics(` used 32 times in `lib/` (kit components carry `semanticLabel`s; the
  painter-heavy screens rely on those).
- Startup path facts unchanged from the prior baseline: shell builds tabs lazily
  (`_visitedTabs`), hero ticks per second only in its seconds ring/digits,
  `TickerMode` wiring carried over.

## 6. Environment / budget

- `assets/env/quran_api.env`, `android/key.properties`, `release-key.jks`,
  `google-services.json` are **gitignored** and were copied into this worktree for
  builds only (never printed, never committed).
- APK builds from a bare worktree need those four files or
  `:app:validateSigningRelease` fails; `flutter build apk --no-pub` fails until
  `pub get` generates the plugin registrant.
- **A connected device existed today** — unlike every prior 1.8.0 report, which
  recorded “no Android device attached”.

## 6b. Wave-0 addendum (2026-10-12 — the gate is honest again)

Wave 0 was executed in this worktree (code + goldens + one new tool). The
numbers above stay as the *pre-change* record; these are the post-wave-0 ones:

| Check | Result after wave 0 |
|---|---|
| `flutter analyze` | **0 errors / 0 warnings / 88 info** — the 2 `mock_daos` warnings of §1 are already gone in this tree |
| `python tools/quality_check.py --strict` | 7/7 gates at zero (unchanged) |
| `python tools/design_consistency.py` | new wave-0 ratchet (0.4), exits 0: screens scope **262 raw colours / 309 raw sizes** (comparable with §0’s ≈250/≈300), all-files scope 714 / 598, budgets seeded to today’s values |
| `flutter test --exclude-tags network` (the deterministic gate) | **all green: 3505 passed / 9 skipped / 0 failed**, exit 0 — the 6 §2 reds fixed (0.1, 0.2), then **36 goldens re-pinned deliberately**: 11 home, 16 More, 5 calendar, 4 kit-sheet. The diffs were measured pixel-by-pixel before re-pinning (header/title band, 22–6 880 px; see F-01/F-39) |
| The two `network`-tagged tripwires (online check) | `dorar_search_live_test` **green** (one transport retry + 45 s ceiling added after a transient 15 s timeout turned a full-suite run red); `audio_library_live_host_test` **red on 2026-10-12 because the host itself answers HTTP 504** — recorded as external observation V-7, not a code regression |
| Golden PNGs | **71** in 10 groups (the 18 failure-diff PNGs are deleted — F-35; `.gitignore:146 test/**/failures/`) |
| `network` tag | stays in the default run; the offline gate is `flutter test --exclude-tags network`, verified to exclude exactly the two tripwires (F-15) |
| New defect the honest harness exposed | `SectionHeader` starved its title to 1.3–2.1 px **on every device** when a trailing exists (F-39), and overflowed 6.3 px at 320dp × 1.3; fixed in the kit, no protected file touched |

## 7. How PART 2–4 will be compared

Same commands, same worktree, same machine: `flutter analyze` (goal ≤ 0 errors /
0 warnings, info ≤ baseline), `quality_check.py --strict` (must stay 7/7 zero),
`flutter test` (all green — the 6 baseline reds must be fixed, not excused),
`flutter build apk --release --analyze-size` (compare fat + per-ABI against §3),
device cold start / PSS (same `am start -W` / `dumpsys meminfo` method), and the
coverage matrix (every row DONE). Anything not re-measurable must be reported as
such, never as improvement.
