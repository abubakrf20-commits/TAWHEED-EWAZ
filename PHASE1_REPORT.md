# PHASE 1 REPORT — Full redesign on the design kit (`phase1/redesign`)

Branch cut from `release/1.7.2` at `3a532e5`, executed per `docs/PHASE1_SPEC.md`
with the user's standing approval to complete all remaining phases
autonomously. All work is committed on `phase1/redesign`; nothing was pushed
(this repo has no remote).

## 1. Scope delivered

| Step | Result |
|---|---|
| 1.0 Inventory + baseline | `docs/SCREEN_INVENTORY.md` (570 lines, every screen/route/dialog), `docs/BASELINE.md`, `docs/COLD_START_TTI.md` |
| 1.1 Design system | Completed kit components, shared type scale + `type_scale_guard_test.dart`, theme tests |
| 1.2 Screens | Waves 1–2 (Home, Report, Settings, More, Tasbih, Quran, Calendar, qibla, share screens…), Wave 3 (khatm/hifz, libraries, reminders, goals, personal_info, tools, knowledge ×5), Wave 4 (shared widgets W4-S, prayer W4-A, azkar W4-B, checklist+dua W4-C, fasting W4-D, account W4-E, expenses/tasks W4-F, final nine W4-G) |
| 1.3–1.4 Cleanup | Wave 5: 8 dead files / 1368 lines deleted with grep evidence (`0197a71`) |
| 1.5 Verification | Full suite, goldens, strict gate, release APK (this file) |

Branch totals vs base: **115 commits, 261 files, +16,954 / −14,656**.

## 2. Design migration canon

- Screens/widgets read `TimeThemeKit.of(context).palette` (`final t = …`) for
  surface/text/outline/divider/primary colors; identity hues come from
  `TopicHues` (value-identical to the old `SectionColors`); contrast-safe text
  accents via `dsContentColor`.
- Chrome canon on full screens: transparent `Scaffold`/`AppBar` +
  `elevation: 0, scrolledUnderElevation: 0` + `w700` `t.primary` titles.
- Semantic locals (`isDark`, `shadow`, `success`, `warning`, `error`, `info`)
  replace `AppColors` statics; the 3-arg `strongAccent(context, X, 0.45)`
  amber-contrast sites kept the exact legacy maths inlined
  (`isDark ? X : Color.lerp(X, black, 0.45)`).
- Intentional exemptions (spec §7.5): Quran reader stays on `MushafPalette`,
  `duas_screen.dart` root untouched, tab screens (hajj, ruqyah, fast) keep
  their own app bars, `note_editor` keeps its custom color-background, native
  side = documents + icons only.
- End state: **zero `AppColors`/`SectionColors` references left in feature
  code** outside the documented exemptions (`app_colors.dart` itself,
  `tokens.dart`/`card_design_system.dart` core refs, `duas_screen.dart` root).

## 3. Quality metrics (final, at `75a4839`)

| Check | Baseline (`3a532e5`) | Final |
|---|---|---|
| `flutter analyze` | 80 issues (78 info, 2 warnings, 0 errors) | **76 issues, 0 errors** (2 warnings pre-existing in `test/core/database/mock_daos.dart`) |
| `flutter test` full suite | 3233 passed, 9 skipped | **3255 passed, 9 skipped, 0 failed** (incl. `network`-tagged live tests) |
| Golden tests | 3 | 3 — still passing (mushaf QCF4 color/uniformity, inheritance share card) |
| `quality_check.py --strict` | 7/7 zero | **7/7 zero** |
| Release APK (universal, signed) | 67,439,431 B (main-tree ref build `b6ad0b7`) | 67,457,832 B — **+18.4 KB (+0.03 %)** |
| arm64 split | 41,935,192 B (worktree baseline) | 41,945,049 B (+9.9 KB) |

Note: the baseline table's 49 MB universal / 24 MB v7a rows were measured in a
worktree pass whose asset packaging differed; the honest apples-to-apples
comparison is against the main-tree reference release build above. Icon
tree-shaking still trims MaterialIcons 94.7 %.

The only full-suite regression found during 1.5 (tasbih stats card `fontSize:
11.5 / 20` off the shared type scale, introduced by the Oct-7 restyle commit
`304d252` while waves ran scoped tests) was fixed in `75a4839`.

## 4. Constraints honored

- Religious content: never edited — proof + notes in `AUDIT_REPORT.md`.
- No user data / DB / prefs breakage: no schema or prefs key changed, no
  `build_runner` run, no dependency added (`pubspec.yaml` untouched).
- Performance: no heavy packages; palette reads are O(1) statics; deletion
  wave reduced Dart + resource surface. Device cold-start/jank metrics remain
  deferred (no Android device connected) — methodology in
  `docs/COLD_START_TTI.md`.
- Persian UI text unchanged (text-run multiset verification per commit); code,
  comments and commit messages in English.

## 5. Deferred / follow-ups (not Phase 1 blockers)

- Device verification: on-device walkthrough of the 4 time-of-day themes and
  cold-start numbers (needs a phone).
- End-to-end backup/restore device test (pre-existing blocker).
- Phase-8 per-feature reports (44) — need group-by-group approval.
- Drift dead columns + `quickActions` — need `build_runner` on protected
  files (user opt-in).
- Tasbih click-sound + tab review (task #6) continues in its own session.

## 6. Release artifacts (built from `75a4839`)

- `build/app/outputs/flutter-apk/app-release.apk` — 67,457,832 B (64.3 MB)
  universal, sha1 `29836bde37682b7ef492c89048b0f3dd8406d8f7`
- `app-arm64-v8a-release.apk` — 41,945,049 B (40.0 MB),
  sha1 `cda7d8185c87cb6e39cf1261fb6c87d1b2eb8ab6`
- `app-armeabi-v7a-release.apk` — 41,336,601 B (39.4 MB),
  sha1 `27aabee7a5aed9d88b3937790ed322c7df6339ae`
