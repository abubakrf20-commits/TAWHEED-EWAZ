# 01 — FINDINGS (master list, graded)

**Base:** `release/1.8.0` @ `dccdcfd`, worktree `final-map`, 2026-10-12.
Everything marked **verified today** was re-checked in this tree; items marked
**(prior)** come from `docs/AUDIT_REPORT.md`, `docs/ROADMAP.md`,
`docs/SECURITY_PRIVACY.md`, `docs/NOTIFICATION_RELIABILITY.md`,
`docs/ACCURACY_REPORT.md`, `docs/DATA_SOURCES.md` (2026-10-10/11, release/1.7.2 →
carried into 1.8.0) and `AGENTS.md` — they are recorded so PART 3 does not redo them.

**Severity (the definitions from the master task):**
- **P0** data loss/corruption · wrong prayer time/qibla/date shown as correct ·
  adhan/alarm not firing · crash on launch or in a core flow · security/privacy
  breach · corrupted Quran text · backup/restore that can destroy data.
- **P1** major functional bug · unreliable background behaviour · serious jank/ANR on
  low-end · wrong calculation in a secondary tool · accessibility blockers.
- **P2** inconsistency · edge case · maintainability · moderate perf · missing state ·
  incomplete validation.
- **P3** polish · naming · minor UX · nice-to-have.
**Design debt** (D0 off-brand/unusable · D1 legacy · D2 partial · D3 minor) is graded
per surface in `00_SCREEN_AND_DESIGN_COVERAGE.md` §M.

**ID namespaces:** `F-*` and `V-*` are **this report's** rows. Ids like `C-2`, `D-3`,
`E-2`, `G-1`, `I-1`, `J-1`, `M-4` are **prior-audit** ids (docs/AUDIT_REPORT.md,
docs/ROADMAP.md, …) quoted for traceability — they are not rows in the tables below.

**Status values:** `OPEN` (to fix in PART 2/3) · `NEEDS-USER` (religious/product call)
· `NEEDS-DEVICE` · `CLOSED` (already fixed/verified — do not redo).

---

## Summary

Rows are counted exactly as they appear below (the table is the source of truth):

| Severity | OPEN | NEEDS-USER | NEEDS-DEVICE | CLOSED (in-table) | Rows |
|---|---|---|---|---|---|
| **P0** | 0 | 0 | **2** | 0 | 2 |
| **P1** | **3** | **4** | 0 | 1 | 8 |
| **P2** | **8** | **3** | 0 | 1 | 12 |
| **P3** | **13** | **4** | 0 | 2 | 19 |
| **Total** | **24** | **11** | **2** | **4** | **41** |

Plus the **30 already-shipped fixes** listed in §“Recorded as CLOSED” (audit rounds
before PART 1) — those are recorded so PART 2/3 does not redo or revert them.

**No P0 defect is open in the code today.** The two P0 rows are *unproven* P0-class
behaviours (alarm end-to-end, backup round trip) that only a device pass can close —
and a device is attached right now, so PART 3 can finish them. The 24 `OPEN` rows are
what `03_PART2_MIGRATION_PLAN.md` schedules; the 11 `NEEDS-USER` rows are listed in
§“Needs your decision” and must not be silently “fixed” by a design pass.

---

## P0 — critical

| ID | Sev | Area | Evidence | Impact | Proposed fix | Effort | Risk | Test needed | Status |
|---|---|---|---|---|---|---|---|---|---|
| V-1 | P0 | Alarms/notifications | `docs/NOTIFICATION_RELIABILITY.md` §7; code paths + unit tests exist (`ExactAlarmHelper.kt`, `ExactReminderScheduler.kt`, Boot/Rollover receivers) | If a path is broken on a real OEM, **adhan/alarms silently don't fire** — the app's core promise | Run the documented matrix on the attached POCO: +5-min exact reminder → kill → reboot → verify; battery-saver on/off; autostart denied; check the diagnostics «armed reminders» card before/after; then Samsung One UI if the user can supply one | M | Low (test only) | the matrix in `04_VERIFICATION_PLAN.md` §5; results recorded in `docs/FINAL/NOTIFICATION_MATRIX.md` (PART 3) | **NEEDS-DEVICE** |
| V-2 | P0 | Backup/restore | `AGENTS.md` “Still open”; `backup_service.dart:234-402,904-1050` (VACUUM INTO snapshot, sha256 manifest, ATTACH restore from a temp copy) | A restore that fails halfway could lose all user data; **never executed end-to-end** | Device round trip: create backup → wipe app data → restore → verify counts (tasbih, notes, khatm, expenses, prayer tracker); also test a corrupt ZIP and a wrong password | M | Medium (data!) | the round trip in `04_VERIFICATION_PLAN.md` §6 + the smoke list §9, run on the attached device | **NEEDS-DEVICE** |

## P1 — high

| ID | Sev | Area | Evidence | Impact | Proposed fix | Effort | Risk | Test | Status |
|---|---|---|---|---|---|---|---|---|---|
| F-01 | P1 | CI health (release gate) | verified today: `flutter test` at `dccdcfd` = **3501 passed / 9 skipped / 6 failed** — 1 × `type_scale_guard_test` (`tasbih_counter_widget.dart:1276 fontSize: 9.5`), 5 × `home_golden_test` full-page baselines (harness froze only `second`, `home_golden_test.dart:166`, hero printed the real `minute`) | The repo’s “keep green” rule was broken; a real regression could hide in the noise | (a) move 9.5 → a scale step, (b) freeze `minute` in the harness and re-pin the home baselines | S | Low | re-run the 6 + full suite | **CLOSED (wave 0)** — 9.5 → `AppTheme.scaledFontSize(context, 10)`; `_frozenNow` freezes BOTH notifiers and `RemindersCard` is pinned via `nowOverride`; 11 home + 25 more/calendar/kit baselines re-pinned (diffs measured, see F-39); full suite green (see the wave-0 addendum in `05_BASELINE.md`) |
| F-39 | P2 | Design kit (found by the wave-0 honest harness) | `section_header.dart` gave its title `free/101` px — `Flexible(flex: 1)` sharing the row with `Spacer(flex: 100)`, so the title rendered **1.3–2.1 px wide (invisible)** on every header that has a trailing: the home prayer card, «خلاصه امروز», «تایم‌لاین اعمال», plus More/calendar/kit-sheet headers; with a long count label it also overflowed **6.3 px at 320dp × 1.3** | A header without its title is broken design on every device — the goldens could not catch it (tofu glyphs) and the overflow matrix could not see it at other widths/labels | title + count chip become one min-size group of proportional `Flexible`s (3 : 2), one line with ellipsis; trailing stays intrinsic and pinned via `spaceBetween` | S | Low | override matrix + re-pinned goldens | **CLOSED (wave 0)** — fixed in the kit, no protected file touched |
| F-02 | P1 | Fiqh output (religious) | `docs/AUDIT_REPORT.md` **J-1** (verified by prior audit; code untouched): livestock nisab age-bands are the **Hanafi** table for every madhhab (`tools/zakat/**`) | Shafi'i/Maliki/Hanbali users are over-taxed — a **wrong religious result they act on** | Needs the user's per-madhhab tables; then a school selector + tests. Do **not** invent the tables | L | High (religious) | zakat table tests per madhhab | **NEEDS-USER** |
| F-03 | P1 | Prayer method coverage | `docs/AUDIT_REPORT.md` **C-1** + `docs/ACCURACY_REPORT.md` §5: 13 methods exist (MWL, Karachi, Umm al-Qura, Egyptian, Tehran, Turkey, Dubai, Kuwait, Qatar, Singapore, ISNA, Moonsighting, Custom); **7 ecosystem methods missing** (Gulf, Morocco, Tunisia, Algeria, France/Grand Mosque, Kuwait variants) and **no nearest-latitude fallback** | Users in those countries can’t match their official timetable | Add the methods + documented fallback; touches protected `app_settings.dart` enum + mapping → needs `build_runner` approval | M | Medium (protected + codegen) | per-method reference tables | **NEEDS-USER** |
| F-04 | P1 | Ramadan Isha | `docs/AUDIT_REPORT.md` **C-5**, `docs/ROADMAP.md` (user already ruled: *make it a choice, never hardcode 90*) | Gulf users get an Isha that differs from the official Ramadan timetable | Expose “angle vs N min after maghrib” as a **user-selectable** setting (new persisted key → protected files + codegen) | M | Medium | setting round-trip + times test | **NEEDS-USER** |
| F-05 | P1 | Hijri consistency | `docs/ACCURACY_REPORT.md` §3 “Two coexisting bases (pending D-3)”: tabular `HijriUtils` (odd 30/even 29, offset default **+2**) vs computed-astronomical `AstronomicalHijri`; the calendar rework fixed the *converter-vs-calendar* offset mismatch but not the basis question | Two screens can show different Hijri days for the same date → a user can act on the wrong day (Arafah/Eid) | Declare one basis per feature (or one globally) and document it; product/religious call | M | Medium | calendar golden + basis test | **NEEDS-USER** |
| F-06 | P1 | Accessibility | `Semantics(` appears 32× in `lib/`; goldens render **tofu glyphs** (no font in the test binding) and the 320/360/412 × 1.0/1.3 overflow matrix exists only for Home/More/Tasbih (`docs/HOME_FINAL_REPORT.md`); no TalkBack pass has ever been run (round 2 of `docs/ROADMAP.md` K item) | Blind/low-vision users may hit unlabelled painters and clipped rows | TalkBack pass on every redesigned screen, focus order RTL, tap targets ≥48 dp, contrast ≥4.5:1; extend the overflow matrix to the remaining screens | L | Low | a11y checklist + screenshots | **OPEN** (PART 3) |
| F-07 | P1 | Type scale / text scaling | **CLOSED for the app (2026-10-13, `d09306a`): 561 → 0** raw sizes across non-allowlisted `lib` files (screens scope 272 → 2); 472 literals in 79 files now go through `AppTheme.scaledFontSize`, so the reader's «اندازه فونت» setting applies everywhere, and text scale 1.0 stayed pixel-identical. The only raw sizes left are the 59 in the 7 fixed-layout surfaces (5 PDF generators + 2 canvas painters) — a PDF must not reflow with the phone's text scale and a `CustomPainter` has no `BuildContext`; the tool reports them as an informational counter so a new raw size elsewhere still fails the run. The long tail that was still open at wave 1 — ~300 literals, densest in moon 48, hifz-report 25, yaqeen-lesson 21, dangi-report 18, yaqeen-home 18, suggestions 17, dua-from-quran-share 13, prayer-share 12 — is what that sweep closed; the guard’s scale is `[8,9,10,11,12,13,14,15,16,17,19,21,23,26,30,34,40,48,56]`: `type_scale_guard_test.dart` fails the build when a literal sits *off* the scale, and `design_consistency.py` (budget 0) fails when a *new* raw `fontSize:` appears outside the seven fixed-layout surfaces | These sizes ignore the user’s system text scale → accessibility + inconsistency | Mechanically migrate to `AppTheme.scaledFontSize(context, step)` in PART 2 (file-by-file, goldens re-pinned); keep palette/painter constants allowlisted | L | Medium (golden churn) | guard green + overflow matrix | **OPEN** (PART 2) |
| V-3 | P1 | Prayer/anomaly reporting | `docs/ACCURACY_REPORT.md` §5: QF API off, all times on-device, NOAA-anchored tests, DST/quarter-hour zones covered | (positive) — recorded so PART 3 does not “improve” the engine | none | — | — | — | **CLOSED** |

## P2 — medium

| ID | Sev | Area | Evidence | Impact | Fix | Effort | Risk | Test | Status |
|---|---|---|---|---|---|---|---|---|---|
| F-08 | P2 | Perf rule (low-end) | verified today: `BoxShadow` with `blurRadius ≥ 10` in `core/design_system/card_design_system.dart:91,100,114,178,187` (14/18/22/30), `core/theme/theme.dart:1385,1393` (14/24), `duas_screen.dart:557,753,992` (10/10/14); **0** BackdropFilter in production code; **1** `Opacity(` at `qibla_screen.dart:1620` | Large-blur shadows and saveLayer are the classic low-end jank/gpu cost the master task forbids | Replace legacy shadow helpers with the kit card (no blur) as their last consumers are migrated; turn `Opacity` into an alpha colour; then add the automated consistency check (PART 2) with an allowlist for palette/painter files | M | Low | consistency-check script | **OPEN** (PART 2) |
| F-09 | P2 | Download integrity | `docs/SECURITY_PRIVACY.md` §4: content DBs/models verified by **size floor only**; no hash/signature; GitHub account is the trust root. Update APK path is the exception (4-host allowlist + SHA-256 pin) | A compromised host silently substitutes content (hadith/tafsir/books) | Publish a sha256 manifest next to the content and verify before use (server-side file needed → user action) | M | Medium | content-download tests | **NEEDS-USER** |
| F-10 | P2 | Privacy (disclosure) | `docs/SECURITY_PRIVACY.md` §4 **P2**: precise GPS (6-decimals) sent to OSM Nominatim + system geocoder and elevation to Open-Meteo **whenever online**; offline `place_index` fallback exists but fires second | Location disclosure to third parties by default | Offline-first toggle (default off-network lookup) + privacy-policy note | S | Low | location resolver tests | **NEEDS-USER** |
| F-11 | P2 | Sensor accuracy | `docs/ACCURACY_REPORT.md` §2: `calculateDeclination` returns `null` on failure → “compass approximate” banner; WMM comes from Android `GeomagneticField` | Old devices can carry a stale WMM; the app cannot warn about epoch | Add an epoch/age check where the platform exposes it; otherwise document the limitation on the qibla screen | S | Low | qibla tests | **OPEN** (PART 3) |
| F-12 | P2 | City data quality | verified today: `iran_cities.dart` = **31 provinces, 1303 cities**; `world_cities.dart` = **226 cities with IANA tz**; merge tool `tools/expand_iran_cities.py` exists, but there is **no validator** (bounds/duplicates/province mismatch/elevation sanity) — the master task asks for one | A bad coordinate silently shows wrong prayer times | Add `tools/validate_cities.py` (assert lat/lng bounds, no duplicate name+coord within 2 km in the same province, tz present for world cities, monotone spelling) + document in `docs/DATA_SOURCES.md` | S | Low | the script itself runs in CI | **OPEN** (PART 3) |
| F-13 | P2 | Maintainability | verified today: 8 files >1800 LOC — `quran_mushaf_view.dart` 2716, `evaluation_stats_widget.dart` 1927, `page_data.dart` 1879, `notification_service.dart` 1863, `settings_screen.dart` 1850, `zakat_screen.dart` 1849, `inheritance_calculator_tab.dart` 1806, `ketabkhaneh_screen.dart` 1805 | God-files block review, cause merge conflicts (see the many “stale buffer overwrote file” incidents in AGENTS.md) | Split along the existing report boundaries (settings pages, zakat steps, notification parts) after their feature work lands — never in the same commit as a design change | L | Medium | existing feature tests | **OPEN** (PART 3, opportunistic) |
| F-14 | P2 | Crash reporting | `docs/ROADMAP.md` **M-4**: Sentry is only active with a build-time `--dart-define=SENTRY_DSN`; no DSN exists in the repo → crash reporting effectively **off**; no `beforeSend` PII scrubber | Field crashes are invisible; diagnostics rely on the on-device log | Decide: wire a DSN + PII scrubber, or delete the dead config | S | Low | error-tracking doc | **NEEDS-USER** |
| F-15 | P2 | CI robustness | `dart_test.yaml` declares the `network` tag; the 2 live-network tests (`audio_library_live_host_test.dart`, `dorar_search_live_test.dart`) run in every `flutter test` | Offline/CI runs flake for reasons unrelated to code | Either exclude by default via a preset, or make the tag opt-in and document the offline command | S | Low | CI run twice | **CLOSED (wave 0)** — a yaml-level `exclude_tags` is impossible *by construction*: package:test **unions** exclude selectors (`test_core` `configuration.dart:1033`), so a default exclusion could never be re-enabled from the CLI and the two tripwires would become dead code. Kept the tag + 4x timeout in the default run and documented/verified the offline gate: `flutter test --exclude-tags network` excludes **exactly** those two tests (“No tests ran” when pointed at them alone). The deterministic release gate is that command; the two tripwires are the separate online check. 2026-10-12 evidence that this matters: a transient `dorar.net` 15 s timeout turned a full-suite run red (`DorarTimeoutException`), and hours later the audio host answered **504** to every request — neither is a code regression. Both live tests now retry once on *transport* failures only and use 45 s ceilings, while HTTP error statuses and parse failures still fail immediately |
| F-16 | P2 | Release packaging | verified today: `app/build.gradle` has **no bundle** pipeline (splits are explicitly disabled for bundles — the code path exists but nothing builds it); CI builds split APKs only | Play requires AAB; Bazaar/Myket take APKs | Add `flutter build appbundle --release` to the release script and record its size; verify the ABI-split interaction | S | Low | build log | **OPEN** (PART 4) |
| F-17 | P2 | Settings god-screen | verified today: `settings_screen.dart` 1850 LOC with 12 hard-coded colours; `prayer_settings_screen.dart` 1230 LOC | Design unification will touch a file this large; risk of regression | Split into section files before/with the migration | M | Medium | existing settings tests | **OPEN** (PART 2) |
| F-18 | P2 | Notification text/locale | fixed twice (CP1256 double-encoding); guarded by `text_encoding_guard_test` (also rejects U+FFFD + BOM) — verified the guard file exists and passed today (not among the 6 reds) | (positive) | none | — | — | — | **CLOSED** |
| F-19 | P2 | Vault encryption depth | `docs/SECURITY_PRIVACY.md` §2 caveat: encryption is enforced at the **screen** layer, not the DAO | A future writer could store plaintext | Enforce at DAO/entity level (needs care with `app_database` codegen) | M | Medium | vault tests | **OPEN** (PART 3, opportunistic) |

## P3 — low

| ID | Sev | Area | Evidence | Fix | Status |
|---|---|---|---|---|---|
| F-20 | P3 | Housekeeping | baseline recorded 2 warnings (`test/core/database/mock_daos.dart:255,260` `override_on_non_overriding_member`) | Correct the mock signatures | **CLOSED (wave 0 re-check)** — the tree carries **0 warnings** now (`flutter analyze`: 0 errors / 0 warnings / 88 info); nothing to correct |
| F-21 | P3 | Lint debt | verified today: 134 `avoid_redundant_argument_values` + 31 `prefer_const_constructors` + 13 curly braces + 5 unused imports | Mechanical cleanup; const also trims rebuilds | **OPEN** (PART 3) |
| F-22 | P3 | Dead dependency | verified today: `pubspec.yaml:81 flutter_svg ^2.2.1` — **0 imports** in `lib/` | Remove after confirming no platform/asset use; one-line justification: unused | **OPEN** (PART 2) |
| F-23 | P3 | Dead asset | verified today: `assets/quran/surah_header.png` (122,564 B) declared at `pubspec.yaml`; its only Dart reference is the constant `qcf4_config.dart:97 surahHeaderAsset`, which has **no consumer** (header is custom-painted) | Delete constant + asset (mushaf-bundle territory → ask first) | **OPEN** (PART 2, needs authorization) |
| F-24 | P3 | Dead token | verified today: `lib/core/theme/time_theme.dart:95 static const Color prompter` — 0 usages | Delete with the prompter removal leftover | **OPEN** (PART 2) |
| F-25 | P3 | Repo weight (not shipped) | verified today: undeclared repo-only files `assets/persian_ih.epub` 1.1 MB, `assets/persian_ih_v1.1.3-csv.1.csv` 1.7 MB, `logo_icon.png` 64 KB, `logo3.png` 168 KB | Keep (source artefacts) or move under `_archive/` | **NEEDS-USER** |
| F-26 | P3 | Logs & backup | `docs/SECURITY_PRIVACY.md` §3: `tawheed_log.txt` sits in Documents and is **not** excluded from OS backup (content is scrubbed) | Add an exclude rule | **OPEN** (PART 3) |
| F-27 | P3 | Plaintext flags | `docs/SECURITY_PRIVACY.md` §2: period/pregnancy flags, per-day diary, Google email in plaintext prefs (per-file-excluded from backup) | Document or encrypt | **NEEDS-USER** |
| F-28 | P3 | Attachment photos | `docs/SECURITY_PRIVACY.md` §2: ID-document photos stored unencrypted while their numbers are encrypted (10 MB cap, `isWithin` guard) | Encrypt attachment store | **NEEDS-USER** |
| F-29 | P3 | Fonts/licensing | `docs/AUDIT_REPORT.md` **I-2**: user already confirmed the bundled fonts are free/redistributable → **no action, do not touch** | — | **CLOSED** |
| F-30 | P3 | Mushaf fonts | `quran-common.ttf` (QUL) + `qcf4/surah-name-v4.ttf` bundled for offline headers — attributable in the About/licenses text? | Verify the attribution text mentions QUL | **OPEN** (PART 4, doc) |
| F-31 | P3 | In-app update | `docs/DATA_SOURCES.md` §1: allowlist + SHA-256 pin verified; installer re-verifies before opening | Confirm the “unknown sources” UX copy on device | **OPEN** (PART 4) |
| F-32 | P3 | Deprecation sweep | Not run today: `flutter pub outdated` (network) — 76 packages have newer versions incompatible with constraints (from `pub get` output) | Run and triage in PART 3 | **OPEN** |
| F-33 | P3 | Dead code | `lib/main_admin.dart` + `lib/admin_web/**` (2 files) are a separate admin entry (not the Android app); `lib/desine/**` is the design reference package excluded from analyze | Confirm and relocate/keep by decision | **NEEDS-USER** |
| F-38 | P3 | Dual hue tables | verified today by script: `SectionColors` (45 hues) is a **value-identical subset** of `TopicHues` (64) — 45/45 match, 0 differences; `SectionColors` is referenced by 2 files only (`duas_screen.dart`, which is frozen, + itself) | Two competing “single sources of topic colour” invite drift (edit one, the other goes stale) | Retire `SectionColors` once `duas_screen.dart` stops importing it (it is on the protected list → needs approval); until then document `TopicHues` as authoritative | S | Low | `design_consistency.py` asserts hue-table parity | **OPEN** (PART 2, needs authorization) |
| F-34 | P3 | Waqf/UX | `evaluation_stats_widget.dart` 1927 LOC after the ring rework; `qibla_screen.dart` 1692 — both candidates for the split in F-13 | — | **OPEN** |
| F-35 | P3 | Golden hygiene | `test/features/home/presentation/screens/failures/` held **18 failure-diff PNGs** from the red goldens | Delete after F-01 is fixed; ensure they are gitignored | **CLOSED (wave 0)** — all `test/**/failures/` dirs deleted and confirmed untracked + covered by `.gitignore:146 test/**/failures/` |
| F-36 | P3 | Analytic completeness | `docs/COVERAGE_GAPS.md`: thinnest features (1 test file each) — yaqeen, onboarding, hajj_umrah, fasting, dua_from_quran, splash, tools/calendar | Add smoke tests for the screens | **OPEN** (PART 3) |
| F-37 | P3 | Notifications doc | `docs/NOTIFICATION_RELIABILITY.md` §6: diagnostics «armed reminders» card exists (the key triage tool) | (positive) | **CLOSED** |

## External / hosting observations (not code defects)

| ID | Sev | What | Evidence | Impact | Status |
|---|---|---|---|---|---|
| V-7 | P1 (external) | Audio-library host | observed 2026-10-12 on this machine: the production manifest URL `https://s3.ir-thr-at1.arvanstorage.ir/t.audio/index.json` **and** the bucket root both answer **HTTP 504** (17 s, 11 KB error page) while the same live test passed ~2 h earlier | if it persists, every user's library falls back to cache/empty and playback reports an internet problem — exactly the symptom `audio_library_live_host_test.dart` exists to catch | **OPEN — re-check before release**: `flutter test --tags network test/features/audio_library/audio_library_live_host_test.dart`; no code change implied unless it persists |

## Needs your decision (product / religious) — do not implement without approval

| ID | Question | Recommendation |
|---|---|---|
| U-1 | **F-02 zakat madhhab tables** — supply the per-madhhab livestock/age tables (or approve “Hanafi-only + a visible madhhab note”) | Recommend: add a school selector with your tables |
| U-2 | **F-03 prayer methods** — approve adding the 7 missing methods (touches protected `app_settings.dart` + codegen) | Recommend: approve; it is the single biggest accuracy-coverage gap |
| U-3 | **F-04 Ramadan Isha** — approve the selectable “N minutes after maghrib” option (new persisted key + codegen) | You already ruled: expose as a choice, never hardcode |
| U-4 | **F-05 Hijri basis** — pick one basis (astronomical vs tabular+offset) for *all* surfaces, or per-surface | Recommend: one global basis + the existing day-offset control |
| U-5 | **F-09 content hashes**, **F-10 offline-first geocoding**, **F-14 Sentry DSN**, **F-25/F-27/F-28/F-33** privacy & repo items | Each is cheap; approve as a batch or defer with a reason |
| U-6 | **D-5 events by tradition** (`docs/ROADMAP.md`): commemorative days are one bundled table | Needs your approval + sources before any change |
| U-7 | **M-7 keystore backup/rotation policy** (undocumented) | Decide where the release key is backed up |
| U-8 | **PART 2 protected-file authorizations** — the plan touches, at minimum: `duas_screen.dart` (frozen → should stay), mushaf sheet files, `more_screen.dart` (already authorized once), `section_colors.dart`, moon/zakat/period interiors | **ANSWERED 2026-10-12: the user approved every row of `03_…MIGRATION_PLAN.md` §7** (design-only interiors with logic frozen, the two god-file splits, retiring `SectionColors`, deleting dead `flutter_svg` + `surah_header.png`). `duas_screen.dart` and the mushaf bundle stay frozen |

## Needs a device (attached today: POCO 2412DPC0AG / Android 16 — no A13-class unit)

| ID | What to prove |
|---|---|
| V-1 | Exact-alarm/adhan matrix under Doze, OEM autostart, reboot, force-stop (P0) |
| V-2 | Backup/restore round trip incl. failure paths (P0) |
| V-4 | Low-end frame times/ANR (A13/A32 class). On this POCO, Impeller does not feed FrameMetrics; a `flutter drive --profile` run requires uninstalling the release app |
| V-5 | TalkBack pass + text-scale 1.3 sweep on every screen (F-06) |
| V-6 | Qibla compass behaviour with a real magnetometer + declination banner (F-11) |

## Recorded as CLOSED — do not re-fix (audit fixes that already shipped)

`G-1` location secure-only · `C-2` Tehran maghrib under elevation · `C-4` place-name
folding · `D-2` DST-safe Hijri day arithmetic · `E-2` declination null vs 0 ·
`A-1` `<queries>` package visibility · `A-5` disposed-`ref` in `finally` (prior-audit ids) ·
`I-1` Quran text integrity guard (sha256 pin + 114/6236/604) · `I-3` WebView origin
confinement · prior audit's `F-2` armed-reminder diagnostics · `J-2` khatm DST-safe daily target ·
`M-1` gradle java.home portability · `I-2` fonts licensing (user-cleared) ·
prompter/recitation-lab removal (+ `sherpa_onnx`, 19.2 MB APK drop) ·
CP1256 double-encoding repair with the `text_encoding_guard_test` ·
splash no-mark system window + bigger coin · More 4-column + in-section search ·
live-ayah wash contrast (500-pair palette test) · evaluation score as a kit ring.
