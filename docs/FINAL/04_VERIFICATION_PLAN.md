# 04 — VERIFICATION PLAN (gates, device matrix, regression checklist)

**Base:** `release/1.8.0` @ `dccdcfd`, worktree `final-map`. Companion to
`03_PART2_MIGRATION_PLAN.md` (what to change) and `05_BASELINE.md` (the numbers to
compare against). **A claim that cannot be reproduced by the commands below is not a
result** — it is reported as unverified.

---

## 1. Verification principles

1. **Independent references only.** Prayer times are checked against the from-scratch NOAA
   solver and a closed-form solar noon, the Hijri month against the NASA/Espenak new-moon
   catalogue, the mansions against Meeus 47.a, contrast against the palette maths — never
   against the app itself (`docs/ACCURACY_REPORT.md`).
2. **The artifact the user runs is what gets verified** — APK on a device for anything
   visual/behavioural; a green unit test proves nothing about rendering.
3. **Goldens guard layout, not shaping.** The test binding has no font, so goldens render
   **tofu**; Persian shaping/rendering must be seen on device.
4. **Never weaken a check to make it pass.** Re-pinning a golden requires a stated reason
   and an inspection of the diff.
5. **Report the gap.** No low-end (A13/A32-class) device is attached; every performance
   statement must say so.

## 2. Static gates (run at every wave exit)

| Command | Pass condition |
|---|---|
| `flutter analyze` | **0 errors / 0 warnings** (info ≤ baseline 190; goal 0 after the lint sweep) |
| `python tools/quality_check.py --strict` | all **7 gates at 0** (silent catch, `]!`, providers-in-screens, share footer, `Color.lerp(…)!`, build-context lock, ≤14 MB assets) |
| `python tools/design_consistency.py` *(exists since wave 0.4)* | no non-allowlisted count above its budget (a one-way ratchet: budgets only go down); `--budgets` re-prints them after a migration |
| `flutter test` | **all green** (the 6 base reds fixed in wave 0, not excused). Offline / untrusted-network gate: `flutter test --exclude-tags network` — verified in wave 0.5 that it excludes *exactly* the two tripwires (`dorar_search_live_test`, `audio_library_live_host_test`); a yaml-level default exclusion is impossible (package:test **unions** exclude selectors), so the flag stays on the CLI and the tripwires stay live in the default run |
| `dart format --output=none --set-exit-if-changed lib test` | only on the dedicated format commit (after WIP is committed — shared-tree rule) |

## 3. Test layers

| Layer | Coverage today | Requirement |
|---|---|---|
| Unit/domain | strongest: prayer (257 tests incl. NOAA/real-zone reference), qibla (29), calendars, moon, khatm, zakat, inheritance | any output-affecting change keeps these untouched and green |
| Widget | 405 test files across 34 feature dirs | one smoke test per migrated screen (thinnest today: yaqeen/onboarding/hajj/fasting/dua_from_quran/splash/tools-calendar = 1 file — F-36) |
| Golden | 85 PNGs / 10 groups | one group per template; re-pins justified per file |
| Live network (`network` tag) | dorar search + audio-library host | opt-in; kept as the regression net for the UA-fallback and Range-resume fixes |
| Kotlin (JVM) | 5 files ≈ 540 LOC (exact alarm, widget calculator, countdown, tasbih + daily reset) | must stay green when native palette/behaviour is touched |
| Quality script | 7 gates | stays at zero |

## 4. Device matrix

| Device | Status | Use |
|---|---|---|
| **POCO 2412DPC0AG — Android 16, 1220×2712, arm64** | ✅ attached today | functional, visual, notification, backup, cold start, PSS |
| Low-end (A13/A32-class) | ❌ not available | jank/ANR statements — must be flagged unverified |
| Samsung One UI (autostart killer) | ❌ not available | the second OEM in the alarm matrix; needs the user |

Standard commands (verified working today): `adb shell am start -W -n com.islamic.tawheeed/.MainActivity`
(cold start after `adb shell am force-stop`), `adb shell dumpsys meminfo com.islamic.tawheeed`
(PSS), `adb exec-out screencap -p > shot.png`. **Caveat:** Impeller does not feed
SurfaceFlinger FrameMetrics on this device, so `gfxinfo`/frame stats are unavailable; a
`flutter drive --profile` run requires uninstalling the release app (erases app data) —
an explicit user decision, not a default.

## 5. Alarm/notification reliability matrix (V-1, P0-class)

Run after any change touching scheduling, boot, Doze, channels or the native widget:

1. Arm a +5-minute exact reminder and a prayer reminder (force a prayer time in the
   diagnostics/dev path if available).
2. Verify the **diagnostics «armed reminders» card** lists them *before* the fire time.
3. Fire while: screen on · screen off · app in background · app **force-stopped** ·
   battery saver on · after a **reboot** · after a **timezone/date change** (the
   TIME_SET/TIMEZONE_CHANGED/DATE_CHANGED paths) · after granting/denying notifications.
4. Adhan: verify the foreground service audio, the media-style stop control, and the
   silent-mode receiver path.
5. Repeat with **autostart denied** (OEM battery manager) and record exactly which paths
   break — that is the deliverable, not a pass/fail.
6. Widget: verify the 30-minute `updatePeriodMillis` refresh, `WidgetHub.refreshAll` after
   a time change, and the tasbih glance widget's daily reset.

**Output:** a filled table in `docs/FINAL/NOTIFICATION_MATRIX.md` (device, Android version,
OEM, each step, observed, screenshot). A missing step is reported as missing.

## 6. Backup/restore round trip (V-2, P0-class)

1. Populate: tasbih counters, worship notes, khatm progress, expenses, prayer tracker,
   goals, reminders, personal-info items.
2. Create a backup; record its size + the reported counts.
3. Copy the archive off-device (adb pull) and **verify its sha256 locally**.
4. Wipe app data (`adb shell pm clear com.islamic.tawheeed` — explicit destructive step,
   confirm with the user first).
5. Restore; verify every count from step 1.
6. Failure paths: corrupt/truncated ZIP, wrong password, backup from an older schema,
   restore while the target already has data (merge/replace policy must be explicit).
7. Record before/after counts and any data loss. **Any loss is a P0 stop.**

## 7. Perf protocol (compare with `05_BASELINE.md` §3–§4)

- Cold start: 5 runs after `force-stop`, report median (baseline: 530 ms median).
- Memory: PSS after 5 launches + idle (baseline: ~342 MB total PSS).
- Size: `flutter build apk --release` → fat + per-ABI against baseline
  (45.1 MiB / 31.4 MB / 31.7 MB); add `flutter build appbundle --release` (F-16) and record it.
- No `BackdropFilter`, no saveLayer, ≤1 `Opacity` (target 0), static gradients.
- Startup path: tabs stay lazy (`_visitedTabs`), the hero ticks only its seconds ring/digits.
- Frame-time claims: only from a profile build on a real device; on this POCO they are
  **not measurable** — say so.

## 8. Data / integrity protocol

| Item | Check |
|---|---|
| City data (F-12) | new `tools/validate_cities.py`: lat/lng bounds, no duplicate within 2 km in the same province, IANA tz present for all 226 world cities, province count 31/1303 cities unchanged or explained |
| Hijri/Jalali (F-05) | any basis change must be reflected consistently in calendar, date converter, Ayam al-Bidh, khatm daily target — the `calendar_days_test` anchors stay valid |
| Content downloads (F-09) | size floor + resume still work; hash manifest is a `NEEDS-USER` item |
| DB migrations | open a v1.7.x database and a fresh one; no `build_runner` unless authorized |
| Vault | encryption at the screen layer still enforced; F-19 is documented, not silently changed |
| Quran integrity (I-1) | the sha256 pin + 114/6236/604 assertions must stay green after **any** mushaf-adjacent change |

## 9. Regression checklist (per release candidate)

Smoke, in this order, each item recorded with a screenshot where visual:

1. Cold start → splash → onboarding (first run) → home.
2. Home: hero clock/arc/countdown, 5 prayer rows, rawatib, summary rings, reminders.
3. Prayer: today's times, city change, method change, adhan toggle, share times.
4. Qibla: compass, declination banner (device without the plugin path too).
5. Quran: open the reader, jump to a surah, follow the reciter, highlight, tafsir sheet,
   bookmark, search, index, download sheet.
6. Adhkar/tasbih: counter, click sound, reset, daily reset, widget glance.
7. Calendar: month grid, day journal, date converter, Hijri offset change.
8. Evaluation: score ring, breakdown tabs.
9. More → every tile: opens, back works, no dead link (in-section search).
10. Tools: zakat (all steps), inheritance (all tabs), moon (phases + mansion), dangi,
    calculator, purification.
11. Knowledge: hadith books, dorar search (online), riyad, fatwa, yaqeen (locked/unlocked),
    audio library (play/stop/lock-screen), education.
12. Personal: expences + report, notes, goals, tasks, suggestions, personal-info (vault
    guard), photo gallery.
13. Settings: every page opens; font scale 1.0/1.15/1.3; theme/phase switch; language;
    widget settings; about/licenses.
14. Notifications: the §5 matrix (subset at every RC).
15. Backup/restore: §6 (full round trip at least once before PART 4).
16. Upgrade path: install over the previous release build with real data → no crash, no
    data loss, no re-onboarding.

## 10. Exit criteria by part

| Part | Done when |
|---|---|
| **PART 2** (design) | every `00` row DONE/`needs decision`; §M counts zero inside the allowlist; `design_consistency.py` clean; analyze 0/0; suite green; goldens re-pinned with reasons; screenshots for every migrated screen on device |
| **PART 3** (repair/harden) | all `01_FINDINGS` `OPEN` items closed or explicitly deferred with a reason; F-06 a11y sweep done; F-12 validator in CI; V-1/V-2 executed and recorded; no `NEEDS-DEVICE` item left unstated |
| **PART 4** (release) | release APK + AAB built from a **clean detached worktree** (gitignored signing files copied in, never printed); size compared to baseline; sha1 recorded; install-over-upgrade tested; `README`/CHANGELOG/version note written; remaining `NEEDS-USER` items listed in the handoff |
