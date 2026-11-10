# Tawheed — roadmap (proposals only, not implemented)

These are the P2/P3 findings and the larger features surfaced by the Phase-2
audit. **None are started** — each needs explicit approval, one by one, per the
audit rules. Items marked **[RELIGIOUS]** or **[PRODUCT]** or **[DEVICE]** are
flagged in `AUDIT_REPORT.md` and must not be decided by the agent.

## Prayer times

- **[PRODUCT/RELIGIOUS] C-1 — method coverage + nearest-latitude rule.** Add the
  missing regional methods (Gulf, Morocco, Tunisia, Algeria, France/Grand
  Mosque, Kuwait time variants) and a documented fallback when a day has no
  valid fajr/isha. Touches the `CalculationMethodOption` enum + mapping in the
  protected `app_settings.dart` and needs `build_runner`.
- **[RELIGIOUS/PRODUCT] C-5 — Ramadan Isha (user-ruled: make it a choice, do NOT
  hardcode 90).** During Ramadan some Gulf timetables fix Isha at ~90 min after
  maghrib instead of the isha angle. Ruling: expose a **user-selectable option**
  (angle vs "N min after maghrib", N editable) rather than baking in a value.
  Needs a new persisted setting → touches protected `app_settings.dart` +
  `app_database.dart`/`.g.dart` + `build_runner`, so it awaits an explicit go-ahead
  for codegen.
- **[PRODUCT] C-7 — favorites + country→method defaults.** Remember favourite
  cities and preselect the method a user's country officially uses.

## Calendars / events

- **[RELIGIOUS/PRODUCT] D-3 — single declared Hijri month-start basis per
  feature** (astronomical vs Umm al-Qura table vs civil). Today it differs by
  screen.
- **[RELIGIOUS] D-5 — events configurable by tradition.** Let the user pick the
  school that decides which commemorative days are highlighted.

## Zakat / fiqh

- **[RELIGIOUS] J-1 — per-madhhab zakat tables.** The livestock (and possibly
  other) Hanafi bands are applied to every school; make them school-specific
  with scholarly input.

## Storage / backup

- ~~**G-1 — keep location out of OS backup.**~~ **FIXED** — coordinates, city and
  altitude are now written to `FlutterSecureStorage` only (already backup-excluded)
  and the readers migrate+purge any legacy plaintext copy. Chosen approach:
  secure-storage coords, no OS-backup rule changed.

## Notifications / reliability

- **[DEVICE] F-1/F-4/F-5/F-6 — exact-alarm reliability matrix.** Prove azan
  timing under Doze, OEM autostart (Samsung/Xiaomi/Huawei), reboot, and process
  kill on real hardware. Add the "next N armed alarms" list to the reliability
  doc output once a device pass is done.

## Performance

- Device-bound jank profiling for the long mushaf reader and the audio library
  (framework-level scroll profiles, not code guesses).

## Security / privacy / a11y

- ~~**I-2 — `calibri.ttf` licensing.**~~ **PARKED (2026-10-19, user request)** —
  the font is left untouched for now. Recorded evidence: the bundled file is
  Calibri **Bold v6.27**, nameID 0 `© 2025 Microsoft Corporation`, and its
  license entry (nameID 13) permits use only as the Microsoft product/service it
  shipped with allows; no license file is bundled. Alternatives were offered in
  the session report (the app already ships Vazirmatn). No code change was made;
  revisit only if the user asks.
- **[PRODUCT] P3 security backlog** (see `SECURITY_PRIVACY.md` §8): enforce vault
  field-encryption at the DAO layer (not just screens); add hash/signature
  verification to downloaded content DBs and models; consider certificate pinning;
  a Sentry `beforeSend` PII-redaction hook; ~~exclude `tawheed_log.txt` from OS
  backup~~ (**FIXED 2026-10-19** — both log names excluded in all three backup
  sections; guarded by `backup_rules_auth_token_test.dart`); ~~the plugin's
  `resetOnError` default could delete the vault / backup key on a failed read~~
  (**FIXED 2026-10-19** — one `appSecureStorage` instance with
  `resetOnError: false`, guarded by `app_secure_storage_test.dart`); an
  offline-first toggle so precise GPS isn't sent to Nominatim/Open-Meteo by
  default.
- ~~**K — TalkBack/VoiceOver audit pass** across the redesigned screens; verify
  focus order in RTL.~~ **DONE 2026-10-26 (`c41b6f2`)** — see the audit section
  in `AGENTS.md`. Critical class fixed (Semantics nodes announcing as buttons
  but activating nothing), every unlabeled FAB/field/chart named, the icon
  picker's empty-named chips given Persian names; the tasbih surface, qibla
  dial, kit rings/steppers and bottom nav were verified already correct. A
  verbosity/design-level pass over list-row semantics (adding per-row roles
  everywhere) remains available on request — it doubles the announcement
  length on dense lists and is a product choice, not a defect.

## Release readiness

- ~~**M-1 — machine-specific `java.home`**~~ **FIXED** — removed from the tracked
  `gradle.properties`; override moved to the untracked `~/.gradle/gradle.properties`.
- ~~**M-2 — recitation-lab `onnxruntime` (~10 MB)** still ships; confirm
  intent or exclude.~~ **OBSOLETE (2026-10-19)** — the recitation-lab and
  prompter were removed in 1.8.0 (`sherpa_onnx` cut from `pubspec.yaml`), and
  the shipped `1.8.0-550e660` arm64 APK contains zero `onnx`/`sherpa` entries.
- **[PRODUCT] M-4 — wire the Sentry DSN.** Code side is complete and gated on
  the credential: `--dart-define=SENTRY_DSN` → guarded no-op when absent,
  `tool/build_release.ps1` refuses a silent build, `test/android/
  release_error_tracking_test.dart` pins it, `docs/ERROR_TRACKING.md` is the
  activation guide. Only the DSN itself (a Sentry project credential the user
  creates) is missing — never commit or print it.
- **[PRODUCT] M-7 — keystore backup/rotation policy.**

## Housekeeping (P3)

- ~~**[ENG] A-2 — apply the `_ready`-Completer guard pattern** to every Notifier
  that does DB work in `build()` (standardise what `ExpenseList` does well).~~
  **FIXED (2026-10-19, `ed5b9d6`)** — eight notifiers guarded; seven race
  tests fail at the pre-fix tree and pass here. Details in AGENTS.md.
- Drift dead columns + `quickActions` (blocked on `build_runner` over protected
  files).
- ~~**Phase-8 — 44 per-feature reports.**~~ **OBSOLETE (2026-10-30)** — the item
  predates the 1.8.0 design wave it was meant to document, and every section now
  has its own evidence: `SCREEN_INVENTORY.md`, `SETTINGS_INVENTORY.md`,
  `QURAN_SCREEN_INVENTORY.md`, `QURAN_REDESIGN_REPORT.md`,
  `BOOKS_READER_REVIEW.md`, `HOME_FINAL_REPORT.md`, `MORE_REPORT.md`,
  `SPLASH_REPORT.md`, `WIDGETS_PLAN.md` + `WIDGETS_AUDIT_2026-10-26.md`,
  `AUDIT_2026-09.md`, and the dated AGENTS.md sections. Forty-four separate
  per-feature files would restate those, not add a finding.
