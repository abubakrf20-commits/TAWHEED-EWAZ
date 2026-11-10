# Phase 0 — Baseline and logs (read-only)

Audit chain for the Tawheed app. **No code was changed in this phase.**
Branch: `release/1.8.0`. Docs live in `docs/FINAL/`.

## 1. Standing user rulings (recorded before work started)

- **Parallel home WIP: option (الف).** The five uncommitted files
  (`home_tokens.dart`, `prayer_times_card.dart`, `quick_actions.dart`,
  `rawatib_card.dart`, `worship_today_card.dart`) belong to the parallel
  session; they are not staged, not committed, not touched by this audit.
- **The five master-task spec conflicts are resolved in favour of the landed
  state** (the audit prompt forbids redesign, so the spec text is superseded):
  1. `IconTile` Style-2 stays **without** the back circle (removed in `af973c1`).
  2. The More grid stays at **4 columns**.
  3. The Evaluation score stays a **RingView** (no gauge restoration).
  4. The kit `arc.dart` stays **deleted**; the home hero keeps its private painters.
  5. `recitation follow-along` / `Mushaf Tawheed` stay **out of scope**
  (removed features); «مصحف حافظ» remains and is audited as-is.
- **Recent work is untouchable**: every commit on `release/1.8.0` and the
  Splash / Home / More / Quran / Settings / About / Widgets / Tasbih /
  Calendar / Report / Palette lines is reported on, never edited.
- Shared components (`settings_components.dart`, `settings_tokens.dart`,
  design system, `WidgetTheme`, `TopicHues`, `SectionColors`, palettes) are the
  source of truth — used, never forked.

## 2. Environment

- Flutter **3.44.4**, channel stable (2026-06-24); Dart 3 (`sdk: '>=3.0.0 <4.0.0'`).
- Host: Windows. `flutter devices` shows **only** Windows desktop + Chrome +
  Edge — **no Android device and no emulator is attached**.
- Consequence (stated plainly, per the no-guessing rule): **logcat, cold
  start (`am start -W`), first frame, frame times, memory and real battery
  figures are NOT MEASURED.** They are recorded as such below; later phases
  compensate with static analysis (timers, sensors, wakelocks, rebuild scans)
  instead of inventing numbers.

## 3. Git state at Phase 0

- Branch `release/1.8.0`, tip `0b57836` (docs). Code tip `461a1fc`.
- Working tree vs HEAD: only the five foreign home-WIP files (M) plus
  pre-existing untracked (`.zcodeignore`, `cache.db`, `desine/`, `doc/design/`).
- `git log --oneline -50` reviewed; tip history is the settings-redesign merge
  (`ac538a9`), the sciences/adhan fixes (`461a1fc`) and the docs commit.
- No `final/*` branch exists yet; this audit commits small docs/code steps
  directly on `release/1.8.0` (the repo has no remote; never push).
- CI exists: `.github/workflows/ci.yml` runs on `main` + `release/**` —
  `dart format` check, `build_runner --check`, `flutter analyze`,
  `flutter test --coverage` with a line-coverage summary, `quality_check.py
  --strict`, and a ≤5 MB bundled `.db`/`.gz` asset-diet guard. The `build` job
  (signed split APK + AAB, 72 MB budget) runs **only on `main`**, not on
  release branches. Not re-run here (no code changed); it is the gate for
  later phases.

## 4. Static gates (measured, this tree)

- `flutter analyze lib test`: **0 errors / 0 warnings / 103 infos**
  (18.5 s; the infos are pre-existing lints in untouched files).
- `python tools/quality_check.py --strict`: **7/7 zero** (silent catches,
  `]!`, providers-in-screens, share footers, `Color.lerp!`,
  `use_build_context_synchronously`, ≤14 MB asset budget).
- `test/core/utils/text_encoding_guard_test.dart`: **green** (no CP1256
  residue, no U+FFFD, no BOM).
- `dart format` / `build_runner --check`: not run locally in Phase 0
  (docs-only); CI covers them before any code-fixing phase lands.

## 5. Full test suite (measured, this tree)

- `flutter test --exclude-tags network`: **3697 passed / 8 failed / 9 skipped**.
- All 8 failures are under `test/features/home/**`:
  - `home_golden_test.dart`: prayer-card golden (day), rawatib-card golden
    (day), full-page golden (day 320 / 360@1.3 / 412 / lite), no-overflow
    (320@1.3, 360@1.0).
  - `actions_timeline_card_test.dart`: two node/push cases.
  - `quick_actions_test.dart`: restored-tiles case.
- **Attribution (proven, not assumed):** in a clean detached worktree at the
  same tip (foreign WIP absent), `test/features/home` passes **106/106** and
  the full suite passes **3696 / 9 skipped / 0 failed**. The 8 reds come
  solely from the parallel session's uncommitted home rewrite — they are
  **pre-existing/foreign reds, not this audit's**.
- The `home_golden_test` wall-clock drift (harness freezes `second`, reads a
  live `minute`) and the `type_scale_guard_test` tasbih literal noted in
  earlier reports did **not** fail in this run.

## 6. App config baseline (read from source, not guessed)

- `version: 1.8.0+10015`, `applicationId com.islamic.tawheeed`.
- `minSdk = 24` (**Android 7.0** — matches the "Android 7+" target),
  `targetSdk = flutter.targetSdkVersion`, `compileSdk = 36`,
  NDK 28.2, Kotlin JVM 17. ABIs shipped: `armeabi-v7a` + `arm64-v8a`
  (splits + versionCode scheme in `build.gradle.kts`); proguard rules wired.
- Manifest permissions: INTERNET, FINE/COARSE location, RECEIVE_BOOT_COMPLETED,
  SCHEDULE_EXACT_ALARM, POST_NOTIFICATIONS, VIBRATE, ACCESS_NOTIFICATION_POLICY
  (DND), FOREGROUND_SERVICE + MEDIA_PLAYBACK, WAKE_LOCK, MODIFY_AUDIO_SETTINGS,
  RECORD_AUDIO. Receivers: adhan alarm, reminder watchdog, silent-mode, boot +
  clock/timezone (reschedule), schedule-refresh, daily rollover, two widget
  providers; services: `AudioService` (Quran media session) + silent-mode
  service. (Full map with channels/jobs/audit verdicts: Phase 4,
  `04_INFRASTRUCTURE_AUDIT.md`.)
- Notable dependencies: `flutter_riverpod` 3.3.2, `go_router` 17.3.0, `drift`
  2.34.0, `flutter_local_notifications` 22.0.1, `adhan` 2.0.0, `geolocator` 14,
  `flutter_compass` 0.8.1, `fl_chart` 0.70.2, `audioplayers` 6.1.0,
  `audio_service` 0.18.18, `dorar_hadith` 0.5.0, `webview_flutter` 4.10.0,
  `record` 7.1.1, Firebase (core/auth/firestore/messaging/storage),
  `google_sign_in` + `googleapis`, `sentry_flutter` 9.25.0 (pinned; no DSN in
  repo, stays OFF), `encrypt` 5.0.3, `crypto` 3.0.3, `wakelock_plus` 1.6.1
  (pinned), `file_picker` 13.1.0, `share_plus` 13.2.0.
- Fonts bundled: Calibri, Vazirmatn (4 weights), Amiri, SurahNameV4,
  QuranCommon. Content assets: azkar JSON, widget palettes, hesn.db,
  mokhtasar.db, quran_data.json, books index, azan + sounds, surah header art.
  Large hadith/library DBs download on demand (not bundled).
- Codebase size: **774** Dart files under `lib/`, **431** under `test/`.

## 7. APK size baseline

- Durable sets under `Desktop/tawheeed-release-apks/`: the newest code-carrying
  sets (`1.8.0-e00ac2a`, `1.8.0-8ff0762`) ship a fat `app-release.apk` of
  **≈47.3–47.4 MB** (arm64 split ≈31.4–31.5 MB). Older 1.8.0 sets ≈48.1 MB.
- **No APK has been built from the current tip** (`461a1fc`/`0b57836`); the
  first audit-phase build will establish the fresh number. (CI's budget is
  72 MB against a 1.6.1 baseline; the strict asset gate is ≤14 MB bundled.)

## 8. Explicitly NOT measured (no device)

`logcat` during tab walks · cold start · time to first frame · Home/Quran/
Tasbih/Calendar/Settings frame times · memory (incl. QCF4 page cache) ·
battery drain · `am start -W` · Doze/reboot/timezone behaviour · TalkBack pass.
Any number for these appearing in later reports without a device must be
labelled an estimate or omitted.

## 9. Handoff to Phase 1

- Proceed on `release/1.8.0`; keep the five home files untouched; stage per file.
- Phase 1 (`01_LOG_AUDIT.md`): source-scan log origins (categories A–F),
  per-source action (remove / levelled logger / debug-only), small commits.
- Open question for the user (non-blocking): whether the search-highlight
  sweep and the new `sciences_routing_guard_test.dart` count as "recent work"
  protection — treated as such by default (report-only if implicated).
