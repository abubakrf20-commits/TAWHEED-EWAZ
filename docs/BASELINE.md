# BASELINE — Phase 1 (measured at `3a532e5`, branch `phase1/redesign`)

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


All numbers below are measured on this machine (Windows 10 26300.0, x64) inside the
phase-1 worktree, unless stated otherwise. Device metrics (cold start, memory, repaint
isolation, visual pass) were measured on 2026-10-09 on a connected POCO device — see §6.
The methodology for further device work is in `docs/COLD_START_TTI.md`
(TTFD < 1000ms, TTI < 2500ms, cold prayer tap < 3000ms as *proposed* acceptance targets).

## 1. Static analysis

| Check | Result |
|---|---|
| `flutter analyze` | **80 issues** = 78 info + **2 warnings** + 0 errors; exit code 1 |
| Warnings | `override_on_non_overriding_member` ×2 — `test/core/database/mock_daos.dart:255,260` (test-only) |
| Top info codes | `avoid_redundant_argument_values` ×59, `prefer_const_constructors` ×7, `curly_braces_in_flow_control_structures` ×6, `unnecessary_import` ×2, + 4 singles |
| `python tools/quality_check.py --strict` | **7/7 gates at zero** (silent catches, `]!`, providers-in-widgets, share footers, `Color.lerp(...)!`, `use_build_context_synchronously` at error, asset budget) |

## 2. Tests

| Metric | Result |
|---|---|
| `flutter test` (full suite, incl. `network` tag) | **3233 passed, 9 skipped, 0 failed** — `All tests passed!` (exit 0) |
| Test files | 383 (`test/**/*_test.dart`) |
| Golden tests | 3 files use `matchesGoldenFile`: mushaf QCF4 page color + uniformity, inheritance share card |
| Longest suite legs (observed) | `shamsi_date_picker_test`, mushaf qcf4 tests, prayer-time correctness vs NOAA reference |

## 3. Release APK (arm64-focused `flutter build apk --analyze-size --target-platform android-arm64`)

| Artifact | Size |
|---|---|
| `build/app/outputs/flutter-apk/app-release.apk` (universal) | **51,335,766 B ≈ 49.0 MB** — sha1 `ac39c4be2024a5a5db04ad5925926bc43ee05b1d` |
| `app-arm64-v8a-release.apk` | 41,935,192 B ≈ 40.0 MB |
| `app-armeabi-v7a-release.apk` | 25,231,866 B ≈ 24.1 MB |
| Reference: latest main-tree APK (built at `b6ad0b7`, all-ABI) | 67,439,431 B ≈ 64.3 MB — sha1 `2d182a1bd4775d5c7d070022951c54c01f6cb493` |

Notes:
- The **code-size breakdown step failed** in the tool (`flutter_size_01/snapshot.arm64-v8a.json`
  not found after `assembleRelease`) — a Flutter-tool-side issue on this SDK fork; the APK
  itself is fine. Granular per-library size deltas will therefore be compared at the
  whole-APK level in Step 1.5.
- Icon tree-shaking worked: MaterialIcons 1645184 → 86984 B (94.7% reduction).
- Build from a clean worktree needs the gitignored signing files
  (`android/app/release-key.jks`, `android/key.properties`).

## 4. Assets & fonts

Declared bundled assets ≈ **11.4 MB** (budget ≤ 14 MB, gate green):

| Path | ~Size |
|---|---|
| assets/mokhtasar.db | 3.5 MB |
| assets/quran/quran_data.json | 2.4 MB |
| android/app/src/main/res/raw/azan_*.mp3 | 2.3 MB — APK resources, not Flutter assets (moved 2026-10-19, `b0960fe`) |
| assets/content/ | 2.4 MB |
| assets/persian_translation.json | 1.7 MB |
| assets/hesn.db | 0.8 MB |
| assets/sounds/ | 0.17 MB |
| assets/quran/surah_header.png, azkar_content.json, riyad_hadith_labels.json, books_index.json, logo/icons, env example | ~0.25 MB total |

`assets/` on disk = 20 MB total (fonts 3.2 MB are declared via the `fonts:` section, not
`assets:`). Font families bundled: Vazirmatn, Calibri, Amiri, SurahNameV4, QuranCommon.

## 5. Dependencies & platform config

| Metric | Value |
|---|---|
| Direct runtime dependencies | 53 |
| Dev dependencies | 10 |
| Locked packages (pubspec.lock) | ~280 |
| Dart SDK constraint | `>=3.0.0 <4.0.0` |
| minSdk / compileSdk / targetSdk | 24 / 36 / `flutter.targetSdkVersion` |
| App version | `1.7.2+10014` |
| Repo scale | 666 `.dart` files in `lib/` (app + features); 44 feature `screens/` dirs |

## 6. Device metrics — MEASURED 2026-10-09 (POCO 2412DPC0AG, Android 16/API 36, arm64)

Release APK `app-arm64-v8a-release.apk` built at `b66caab` installed via `adb install -r`.
This is a fast recent device, so it is an optimistic proxy for the A13/A32 target class.

| Metric | Result | Method |
|---|---|---|
| Cold start (activity) | **0.60–0.83 s** (5 runs: 830/622/610/598/644 ms) | `am start -W` after `am force-stop`, screen awake |
| Flutter surface attach | ~330 ms after START; engine warm ~430 ms | logcat `ViewRootImplStubImpl` timestamps |
| Idle CPU (home, countdown ticking) | **0.0 %** | `top -b -n 2 -p <pid>` after 10 s idle |
| Memory | **~338 MB PSS** (Java 25 MB, native 64 MB, graphics 76 MB) | `dumpsys meminfo` |
| Repaint isolation | Countdown ticks change **only** the hero card rows; prayer list / bottom nav / app bar **0 changed rows** across two 3 s pairs | screencap pixel-diff, threshold 250/px-sum |
| Tab rendering | all 6 tabs + settings hub + theme sheet + personal-info render correctly at 1220×2712 | screenshots in `docs/device-verify/` |
| Fixed-phase theming | night palette verified on device; live restore works | theme sheet cycle |

Not measurable here: jank % via `dumpsys gfxinfo` — Impeller/Vulkan frames do not feed
SurfaceFlinger FrameMetrics on this device (0 frames counted even while scrolling);
real frame timing needs a `flutter drive --profile` run, which requires uninstalling
the release app (erases device app data) — deferred as a user decision.

Device-side finding: `FlutterSecureStorage` logged an EncryptedSharedPreferences
Keystore decrypt failure and fell back to custom ciphers — expected when installing
over a prior build with `-r`; a clean uninstall+install should clear it.

## 7. Performance-relevant code facts (baseline for the redesign)

- Shell builds tabs lazily and keeps them alive (`_visitedTabs`) — preserve.
- Home hero uses a per-second ticker only for the seconds row; the clock row updates per
  minute (`_PerMinute`); the arc countdown updates per second (`_ArcCountdown`).
- The report/heatmap, calendar grid, and settings screens are legacy full-rebuild widgets —
  the redesign's RepaintBoundary/const rules apply to them.
- No BackdropFilter usage yet; `GlassSurface` exists and is used by ~20 call sites
  (home widgets, calendar, duas, hadith, about, premium card) — the spec's AppCard must
  subsume or complement it without adding blur.

## 8. Environment incident (2026-10-06)

`C:` reached 100% (2.5 GB free / 466 GB) during this baseline. ENOSPC killed one scan agent
and the first `--analyze-size` build (Gradle "not enough space", 7m27s). After deleting only
regenerable `build/` dirs of temp worktrees: **14 GB free**. No source/commits/APKs touched.
Baseline numbers above were re-measured/re-built after cleanup.

## 9. How AFTER (Step 1.5) will be compared

Same commands, same machine, same worktree:
1. `flutter analyze` issue count (target: ≤ baseline; new code must add zero issues),
2. `python tools/quality_check.py --strict` (must stay 7/7 zero — hard gate),
3. `flutter test` (all green; count grows with new component/golden tests),
4. `flutter build apk --analyze-size --target-platform android-arm64` → APK size vs §3,
5. documented deltas in `docs/PHASE1_REPORT.md`, and the removed files/packages/assets list.
