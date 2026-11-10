# Tawheed — Phase-2 audit report

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


Auditor roles: senior engineer + QA + security reviewer + Islamic-app domain
specialist. Scope: the whole app on branch `release/1.7.2` (worktree
`%TEMP%/opencode/merge-172`). General rules from the Phase-1 prompt still apply.

Grading: **P0** = data loss / crash / haram-output risk / privacy leak. **P1** =
wrong result the user acts on (prayer times, fiqh math, security). **P2** =
degraded UX / reliability / maintainability. **P3** = polish / nice-to-have.

Every **P0/P1 that was safely fixable in code** has a regression test and its own
commit (listed inline). Items that need a device, product, or religious decision
are **flagged, not decided** — see §N and `docs/ROADMAP.md`.

---

## Summary of fixes shipped this phase

| # | Grade | Finding | Commit | Test |
|---|-------|---------|--------|------|
| D-2 | P1 | Hijri `dayInMonth`/`monthLength` used `difference().inDays` → truncates across DST (23-h day) | `5e2cacf` | `calendar_days_test.dart` |
| E-2 | P1 | Qibla magnetic-declination service returned `0.0` on failure, conflating a genuine 0° with "no value" | `e0202a3` | `magnetic_declination_service_test.dart` |
| — | P1 | Follow-up: E-2's failure path could never *succeed* — the native handler read the epoch-seconds argument as a typed `Long`, but StandardMessageCodec sends a small Dart int as `java.lang.Integer`, so every lookup threw and the compass stayed in approximate mode | `e62dbcd` | `magnetic_declination_channel_test.dart` |
| A-1 | P1 | Android 11+ package visibility: no `<queries>` → `canLaunchUrl` false for `tel:`/`mailto:`/`market:` | `4e9485a` | `android_manifest_queries_test.dart` |
| C-2 | P1 | Elevation correction re-solved **Tehran** Maghrib (angle-defined −4.5°) to geometric sunset, discarding the official rule | `9137c6f` | `elevation_correction_test.dart` |
| A-5 | P1 | `ExpenseList._load()` read another provider in `finally` after an await → Riverpod 3 crash if disposed in the gap | `d81ef90` | `expense_provider_test.dart` (2 cases) |
| J-2 | P2 | Khatm `dailyTarget` measured elapsed hours → time-of-day/DST truncation shifted the page-per-day target | `3d3efa5` | `khatm_model_daily_target_test.dart` |
| C-4 | P2 | Place search normalize ignored ي↔ی, ك↔ک, harakat, Arabic-Indic/Persian digits | `b9f377d` | `place_index_test.dart` |
| — | P2 | Follow-up: `m[0]!` in the C-4 mapper tripped the strict `]!` gate | `359b8ef` | (gate) |
| I-3 | P1 | In-app WebView accepted every cross-origin redirect with unrestricted JS | `69b41e4` | `in_app_browser_navigation_test.dart` |
| F-2 | P2 | Diagnostics page never showed what is actually armed on the OS alarm clock | `bc18c5e` | `notification_diagnostics_screen_test.dart` |
| I-1 | P1 | No consolidated integrity guard on the shipped Qur'an text asset | `0ccfb84`,`08a52b0` | `quran_integrity_test.dart` |
| M-1 | P2 | Machine-specific `org.gradle.java.home` committed in tracked `gradle.properties` (breaks other machines/CI) | this commit | `gradle_properties_portability_test.dart` |
| G-1 | P1 | Location (coords/city/altitude) written to plaintext prefs → copied into Google cloud backup; now secure-only with legacy-plaintext migration | this commit | `prayer_local_datasource_secure_test.dart` |

Perf hotspots (workstream 2, earlier this session): `6ec8af7` ramadan,
`10a77c7` search (plus `12517a8` riyad, audio library). Not audit findings —
delivered under the "next suggested step" directive.

Full suite after all fixes: see `docs/BASELINE.md` / final chat summary.

---

## A. Architecture & code health

- **A-1 (P1, fixed)** Android package visibility — `4e9485a`.
- **A-5 (P1, fixed)** disposed-`ref` use in an async `finally` — `d81ef90`.
- **A-2 (P2, fixed)** Several `Notifier`s scheduled DB work in `build()` via
  un-awaited futures (`_load()`), so a mutation in that window was clobbered
  by the older snapshot. The `_ready` Completer guard is now applied to all
  eight (`ed5b9d6`); seven race tests fail at the pre-fix tree and pass here.
  Invariant recorded in AGENTS.md.
- **A-3 (P2)** Provider placement is gate-enforced (no providers in widget files,
  verified by the strict gate), good.
- **A-4 (P3)** `adhan.CalculationParameters` is mutated per recompute in
  `prayer_repository_impl`; the fresh-params-per-call already avoids the shared
  object being clobbered. Keep.

## B. Performance

Covered by workstream 2 (audio_library lazy + rebuild scope; riyad 366-tile
lazy; ramadan optimistic edits + parallel load; search cached haystacks +
surrogate-safe snippets). Remaining device-bound jank profiling → ROADMAP
(`docs/COLD_START_TTI.md` tracks TTI).

## C. Prayer times — correctness, worldwide, dense Iran data

- **C-2 (P1, fixed)** Tehran angle-defined Maghrib preserved under elevation
  correction — `9137c6f`.
- **C-4 (P2, fixed)** place-name normalization folding — `b9f377d`.
- **C-1 (P0-ish, NEEDS USER)** Seven calculation methods present in the
  ecosystem are missing from the picker (e.g. Gulf, Morocco, Tunisia, Algeria,
  France/Grand Mosque, Kuwait-time variants), and there is **no
  nearest-latitude / "no valid time" fallback rule** beyond the three
  high-latitude rules. Adding methods touches `app_settings.dart` enum +
  `CalculationMethodOption` mapping (protected + codegen). **Ask, don't add.**
- **C-5 (NEEDS USER)** Umm al-Qura Ramadan **Isha** is scheduled with the
  standard isha angle, not the fixed ~90-min-after-maghrib convention many
  official Gulf timetables use during Ramadan. Religious/product call.
- **C-7 (NEEDS USER)** No favorites list and no country→recommended-method
  mapping; users must know which method their country uses. Product decision.
- **C-6 (verified OK)** Per-date UTC-offset plumbing + noon-anchored DST offsets
  pass the independent NOAA reference solver (Phase-6 suite). No change.

## D. Calendars, moon, mansions, events

- **D-2 (P1, fixed)** DST-safe Hijri day/month length — `5e2cacf`.
- **D-3 (NEEDS USER)** Hijri month-start basis is inconsistent across screens
  (some use the astronomical new-month, some the Umm al-Qura table, some the
  user's civil calendar). A single declared basis per feature is a product/
  religious decision.
- **D-5 (NEEDS USER)** Religious events (Arbaeen, Eid al-Ghadir, etc.) are a
  fixed bundled table; not configurable by madhhab/tradition. Sensitivity →
  user approval before any change.
- Mansions/moon math was reviewed and confirmed accurate in the prior moon
  review (`AGENTS.md`); no regression found.

## E. Qibla

- **E-2 (P1, fixed)** declination failure surfaced, not silently 0° — `e0202a3`.
  Follow-up `e62dbcd`: the "failure" branch was the only one ever taken. The
  Kotlin handler read `call.argument<Long>("timestamp")` while the Dart side
  sends epoch **seconds** (~1.7e9), which StandardMessageCodec encodes as
  Int32 → `java.lang.Integer`; the cast threw, the channel answered with an
  error, the Dart service returned `null`, and the card permanently showed
  «انحراف مغناطیسی در دسترس نیست · جهت تقریبی». Now
  `call.argument<Number>("timestamp")?.toLong()`, pinned by
  `test/android/magnetic_declination_channel_test.dart` (also asserts no other
  small numeric argument is read as a typed `Long`/`Int` — the three
  epoch-**millisecond** alarm keys are the only safe ones).
- **E-1 (verified OK)** great-circle bearing math matches independent
  references.

## F. Notifications, alarms, background

- **F-2 (P2, fixed)** armed-reminders now visible on the diagnostics page —
  `bc18c5e`. This is the key triage tool.
- **F-1 / F-4 / F-5 / F-6 (NEEDS DEVICE)** real reliability of exact alarms
  under Doze, OEM autostart (Samsung/Xiaomi/Huawei), reboot recovery, and
  process-kill — cannot be proven off-device. The in-app battery/DND guidance
  exists; end-to-end timing must be validated on hardware. →
  `docs/NOTIFICATION_RELIABILITY.md`.

## G. Storage, backup, cloud

- **G-1 (P1, fixed — secure-storage coords, user-approved)** Coordinates, city and
  altitude were duplicated into plaintext SharedPreferences
  (`saved_lat_fallback`/`saved_lng_fallback`/`saved_city`/`saved_altitude*`), and
  because Android backup rules exclude **per-file** (not per-key), that whole prefs
  XML — location included — rode along in the Google cloud backup. `PrayerLocalDataSource`
  now stores these **secure-only** (`FlutterSecureStorage.xml` is backup-excluded),
  and the readers migrate any surviving plaintext copy into secure storage and purge
  it, so existing installs self-heal on next read. No portable/OS backup rule
  changed and no other prefs key is affected. →
  `prayer_local_datasource_secure_test.dart`.
- **G-2 (verified OK)** DB forensic copies were moved out of the backed-up path
  into `database_diagnostics/` (excluded) and `FlutterSecureStorage.xml` is
  already excluded. Good.

## H. Logging & diagnostics

- **H-1 (NEEDS DEVICE)** Keystore-backed vault reinstall behaviour (the secure
  AES key is device-bound, so a reinstall cannot decrypt the old vault) — this
  is intended and documented, but the user-facing recovery flow should be
  validated on a device.
- Logger is quiet/rotating with a share path on the diagnostics page. OK.

## I. Security & privacy

- **I-1 (P1, fixed)** consolidated Qur'an text-integrity guard (sha256 pin +
  structural cross-check) — `0ccfb84`.
- **I-3 (P1, fixed)** in-app WebView origin confinement — `69b41e4`.
- **I-2 (parked — user request, 2026-10-19)** bundled fonts (`calibri.ttf`):
  left untouched for now. The bundled file is Calibri **Bold v6.27**; its name
  table carries `© 2025 Microsoft Corporation` and an embedding-restriction
  entry (nameID 13), and no license file is bundled with it. The user asked to
  defer the decision, so no font was changed; alternatives (the app already
  ships Vazirmatn, OFL) were offered in the session report. Revisit only on the
  user's word.
- Cleartext is off (`usesCleartextTraffic="false"`); model/audio downloads are
  HTTPS-only with Range resume (verified earlier).

## J. Feature-by-feature correctness

- **J-1 (FIQH — flag, do NOT edit)** Zakat livestock: the Hanafi age-band table
  is applied to every madhhab, which over-taxes Shafi'i/Maliki/Hanbali users.
  This is religious output correctness — **needs scholarly/user decision**;
  the code was not touched.
- **J-2 (P2, fixed)** khatm `dailyTarget` DST-safe calendar days — `3d3efa5`.

## K. Accessibility & localisation

- RTL-first, Persian UI copy throughout, fixed hues / Latin digits in personal
  tools per the usability notes. Semantic labels were added on the design-kit
  components in Phase-1. No new defects found in this pass.

## M. Release readiness

- **M-1 (fixed)** a machine-specific `java.home` was committed in
  `gradle.properties` — **removed from the tracked file**; the override now lives
  in the untracked user-level `~/.gradle/gradle.properties` (Gradle precedence
  keeps this machine building; CI/other machines resolve their own JDK).
  Regression guard: `test/android/gradle_properties_portability_test.dart`.
- **M-2 (NEEDS USER)** a hidden recitation-lab path still ships ~10 MB of
  `onnxruntime`; confirm the feature is intended for the shipping build or
  exclude it. (Recitation voice tools were slated for removal — see memory.)
- **M-4 (NEEDS USER)** Sentry DSN is referenced but never wired; crash
  reporting is effectively off. Decide whether to enable.
- **M-7 (NEEDS USER)** release keystore backup/rotation policy is undocumented.

## N. Deliverables & decisions needed

See the sibling docs: `ROADMAP.md`, `DATA_SOURCES.md`,
`NOTIFICATION_RELIABILITY.md`, `ACCURACY_REPORT.md`, `SECURITY_PRIVACY.md`, and
the final chat summary. The blocked items requiring your input are tagged
**NEEDS USER** above (C-1, C-7, D-3, D-5, F-*, M-2, M-4, M-7). Resolved since the
first pass: **M-1** fixed, **I-2** closed (fonts are free), **G-1** fixed
(secure-only coords), **C-5** ruled (make Ramadan Isha a user-selectable option,
no hardcoded value — see ROADMAP), **J-1** awaiting the user's per-madhhab tables.
