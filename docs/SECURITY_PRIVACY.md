# Tawheed — Security & privacy

Companion to `docs/AUDIT_REPORT.md` (findings G-*, I-*). Data at rest/in transit,
permissions, backup, WebView, logging and input handling. Branch `release/1.7.2`
(worktree `%TEMP%/opencode/merge-172`). Risk scale **P0 critical → P3 info**.

**Overall posture: sound.** No cleartext, no JS bridges, no command exec, SQL and
path handling are hardened, secrets are gitignored and verified untracked, prayer
times are computed on-device. The open items are privacy *disclosure* decisions
(location/geocoding to third parties, backup granularity), not exploitable bugs.

---

## 1. Android permissions (`AndroidManifest.xml`)

Declared and **all used in code**: INTERNET, ACCESS_FINE/COARSE_LOCATION,
RECEIVE_BOOT_COMPLETED, SCHEDULE_EXACT_ALARM (**`USE_EXACT_ALARM` deliberately
omitted** — Play policy, `:19-22`), POST_NOTIFICATIONS, VIBRATE,
ACCESS_NOTIFICATION_POLICY, FOREGROUND_SERVICE(+_MEDIA_PLAYBACK), WAKE_LOCK,
MODIFY_AUDIO_SETTINGS, RECORD_AUDIO (voice notes / prompter / lab — **all on-device,
no upload found**). `<queries>` (`:56-77`) is minimal (tel/mailto/market/http(s)) —
the A-1 fix `4e9485a`. `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` intentionally not
declared. **No over-permission. P3 clean.**

## 2. Data at rest

- **Drift SQLite** `app_database.dart`: notes, expenses, khatm, prayer tracker,
  period records, personal_info — plaintext at the DB level except the vault (§ below).
- **personal_info vault = real encryption**: AES-256-GCM (`secure_cipher.dart`),
  key = random 32 bytes in Keystore-backed `flutter_secure_storage`
  (`pin_lock_service.dart:111-116`). Encrypted fields: nationalId/birthCert/passport,
  credential username/password, asset/insurance/document numbers. PIN does **not**
  derive the key (documented trade-off); PIN verifier is salted-SHA-256 with
  constant-time compare. **Caveat (P3):** encryption is enforced at the *screen*
  layer, not the DAO — a future writer bypassing screens could store plaintext.
- **P3 (fixed 2026-10-19) — plugin could delete the vault key on a read error.**
  flutter_secure_storage 10.3.4 defaults `AndroidOptions.resetOnError` to `true`;
  `FlutterSecureStorage.handleStorageError` then **deletes** the key whose read
  failed (including a transient Keystore error) and retries, so `read` returns
  null and `PinLockService.cipher()` (`:105-116`) would mint a new AES key over
  ciphertext sealed with the lost one — the same path applies to the auto-backup
  key (`backup_service.dart` `_deviceBackupKey`, which would strand every older
  archive). All three sites (vault, prayer coordinates, backup key) now use
  `lib/shared/services/app_secure_storage.dart`, whose `resetOnError: false`
  makes the failure surface instead. Guard:
  `test/shared/services/app_secure_storage_test.dart` pins the option and fails
  if any site constructs its own `FlutterSecureStorage()`.
- **G-1 (fixed) — location now secure-only**: `saved_lat`/`saved_lng` were in
  secure storage, but `setSavedCoords` *also* wrote plaintext
  `saved_lat_fallback`/`saved_lng_fallback` + `saved_city` + altitude into prefs,
  which rode in Google cloud backup. Those writes are removed; the datasource now
  keeps coordinates/city/altitude **secure-storage only** and migrates+purges any
  legacy plaintext (see §3).
- **P2 — sensitive flags in plaintext prefs**: menstrual/pregnancy/fertility state
  (`period_provider.dart`), per-day diary (`day_journal_service.dart`), Google
  account email (`google_auth_service.dart:23-24`). Legacy `period_pin` is already a
  salted hash (low risk).
- **Attachment photos** (document/ID images, avatars, voice notes): plaintext under
  `app_data/attachments/`, 10 MB cap, deletion `isWithin`-guarded — identity-document
  *photos* are not encrypted even though their numbers are (P3).

## 3. Android backup

- `allowBackup="true"` (`:84`) — full app data is backup-eligible by design; the
  DB is intentionally included.
- `backup_rules.xml` / `data_extraction_rules.xml` exclude per-**file**:
  `FlutterSecureStorage.xml`, `backups`, `app_data`, `database_diagnostics`,
  `quran_content/audio_cache`, downloaded content DBs, `app.sqlite.backup*`.
- **G-1 (fixed — user-approved)** — the crux had been: Android backup granularity
  is **per-file, not per-key**, so the single default `FlutterSharedPreferences.xml`
  (which held plaintext coord fallbacks, `saved_city`, altitude) **could not** be
  partially excluded, defeating Keystore protection for the *backup* path. Fix:
  `PrayerLocalDataSource` now stores coordinates/city/altitude in
  **`FlutterSecureStorage` only** (that file is already excluded) and the readers
  migrate any surviving plaintext copy and delete it — existing installs self-heal,
  new writes never touch prefs. No OS-backup rule or other prefs key changed.
  Test: `prayer_local_datasource_secure_test.dart`. (Period flags/diary/email in
  prefs remain a P3 disclosure, still per-file-excluded — see §8.)
- ~~**P3**: the on-device log `tawheed_log.txt` sits at documents root and is NOT
  excluded → cloud-backed-up (scrubbed, see §6).~~ **FIXED (2026-10-19)** — both
  names (`tawheed_log.txt` and the legacy `trayheed_log.txt`) are excluded in
  `backup_rules.xml` and in both `data_extraction_rules.xml` sections. Guard:
  `test/android/backup_rules_auth_token_test.dart` pins the exclusions and the
  logger constants they must match.

## 4. Data in transit

- **No cleartext**: `usesCleartextTraffic="false"`; all endpoints HTTPS.
- **What leaves the device** (by design, none carries an account id):
  - Hadith **search terms** → `dorar.net` (browser-UA disguise is an anti-block
    measure, not a user id). P3 third-party-visible query.
  - **P2 — precise GPS → third parties**: reverse geocoding sends lat/lon at
    6-decimal (~0.1 m) precision to **OSM Nominatim** + the **system/Google**
    geocoder, and elevation at 4-decimal (~11 m) to **Open-Meteo**, *whenever online*
    (offline `place_index` fallback exists but online fires first). Prayer times
    themselves never need or send location.
  - Suggestions → Firestore: text + category + random 8-byte anonymous tag. P3.
  - FCM token; Drive `appdata` backups; update manifest (no user data).
- **Integrity of downloads (P3)**: content DBs/models verified by **size floor
  only** — no hash/signature; **no certificate pinning anywhere** (mitigated by
  HTTPS + platform trust). The GitHub account is the trust root; compromise =
  silent content substitution.
- **Update channel is the strong exception (P3 clean)**: APK restricted to a 4-host
  allowlist and **SHA-256 pin required** before offering
  (`update_checker.dart:46-51,99-112`); installer re-verifies the hash before
  opening the package installer.

## 5. Auth / secrets

- `google_sign_in` **is used** — Firebase account exchange + Drive `appdata`
  backup (minimal `drive_appdata` scope, correct). OAuth tokens held in-memory by
  the plugin only; app persists a signed-in bool + email (→ OS backup, P3).
- QF API creds: **never hardcoded** — from gitignored `quran_api.env` / dart-defines;
  **release always uses the server proxy**; real env not bundled.
- Signing hygiene: `.gitignore` excludes `key.properties`, `release-key.jks`,
  `google-services.json`, `quran_api.env`, admin SDK json — `git ls-files` confirms
  none tracked. `firebase_options.dart` public apiKey is normal (not a secret).

## 6. WebView & logging

- **I-3 (P1, fixed `69b41e4`)**: `InAppBrowserScreen.allowNavigation` confines the
  main frame to http(s) on the opened host or a true subdomain
  (`host == root || host.endsWith('.$root')`) — blocks the `evil.com/#https://qaf.ai`
  and `qaf.ai.evil.com` tricks. JS unrestricted (needed by the site) but there is
  **no `addJavaScriptChannel` anywhere** (zero bridges), no file/content access.
  P3 edge: a host-less root URL would allow any http(s) host — unreachable today
  (callers pass fixed https). 
- **Sentry**: crash reporting **only** with a build-time `--dart-define=SENTRY_DSN`
  (`main.dart:31-36`) — DSN not in source; **M-4 NEEDS USER: DSN never wired →
  crash reporting effectively off.** No `beforeSend` PII scrubber (P3) — relies on
  AppLogger for the file path only.
- **AppLogger** (`app_logger.dart`): 150 KB rotating `tawheed_log.txt`, `debug`
  lines never persisted; **every persisted line is scrubbed** — emails → `[email]`,
  digit runs ≥8 (phones/cards) → `[digits]`. No call site logs coordinates. Sharing
  is user-initiated from diagnostics.

## 7. Input handling — hardened (P3 clean)

- **SQL injection**: all raw-SQL call sites **bind variables**; the only identifier
  interpolation is backup restore, where table names are regex-allowlisted
  `^[A-Za-z0-9_]+$`, columns come from the trusted on-device `PRAGMA table_info`,
  and `ATTACH DATABASE ?` / `VACUUM INTO ?` are parameterised.
- **Path traversal / zip-bomb**: ZIP entries validated against absolute paths, drive
  letters, `..`, NUL, both separators, then re-normalised under `app_data/`; central-
  directory zip-bomb preflight before any inflate + value-size caps.
- **No `Process.run`/`Process.start`** anywhere in `lib/`.
- Portable backups: optional password → PBKDF2-HMAC-SHA256 200k + AES-256-GCM,
  SHA-256 manifest integrity on restore.

## 8. Needs decision / follow-up

- **G-1** backup of plaintext coords/flags → your call (two options above).
- **I-2** bundled `calibri.ttf` — verify redistribution license + attribution, or
  swap for an OFL font (touches `pubspec.yaml`, a hard line).
- **M-4** enable Sentry DSN or drop the dead reference.
- **P3 hardening backlog** (proposals, not started — see `docs/ROADMAP.md`): DAO-
  level encryption enforcement, hash/signature for downloaded content, cert pinning,
  Sentry `beforeSend`, exclude the log file from backup, offline-first geocoding
  toggle.
