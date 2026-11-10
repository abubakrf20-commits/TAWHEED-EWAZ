# Phase 4 — Infrastructure audit (static + config reads)

## Storage
- Drift (`app_database.dart`, `@DriftDatabase`, versioned
  `currentSchemaVersion`) with `onCreate` + `onUpgrade` migrations and audit
  indexes; generated file (29k lines) excluded from lint by rule. Corruption
  recovery, snapshot rotation and orphan cleanup present with logged
  fallbacks. Migration-from-every-version tests exist per earlier reports.
  No finding.
- `SharedPreferences` for prefs (keys owned per feature; all keys/defaults
  preserved by rule). Secure storage (Keystore-backed) for the vault AES key
  + PIN verifier. No finding.

## Backup / restore
`backup_service.dart` is hardened: entry-count + per-entry/total byte limits
(checked pre- and post-decode), `format_version: 2`, app/schema versions
stamped, magic `TENC1` + version byte, PBKDF2-version and GCM-version formats
with legacy-CBC read support, size-based auto-backup pruning (~50 MB).
Atomic stage→validate→swap restore and zip-slip path handling are covered by
the existing backup test suite (green). No finding; device round-trip
(wipe→restore→verify) still needs a phone.

## Notifications / alarms
Manifest: `SCHEDULE_EXACT_ALARM`, `POST_NOTIFICATIONS`, boot/clock receivers,
adhan + reminder + rollover receivers, `FOREGROUND_SERVICE(_MEDIA_PLAYBACK)`,
`ACCESS_NOTIFICATION_POLICY` for the mute-before-iqama DND flow.
Reschedule triggers (boot/time/timezone/locale/settings/start) present with
fingerprint keys. Channel ids versioned (`_v2` series present). Exact-alarm
rationale + OEM guidance live in the diagnostics/settings surfaces per
earlier reports. Doze/OEM behavior: NOT MEASURED (needs a device + adb).
No static finding.

## Network (hosts contacted; core must survive them blocked)
- Quran audio/text: `cdn.islamic.network`, `everyayah.com`,
  `api.alquran.cloud`, `api.quran.com` (legacy), `apis.quran.foundation` +
  oauth2, `verses.quran.foundation` (fonts), `d.quranenc.com` (fa audio),
  `raw.githubusercontent.com` (TAWHEED-EWAZ + quran-qcf4), `cdn.jsdelivr.net`
  (qcf4 fallback).
- Content: `dorar.net` (hadith search), `s3.ir-thr-at1.arvanstorage.ir`
  (audio library), `call.tgju.org` (zakat live prices), `tile.openstreetmap.org`
  (map picker + qibla map), `qaf.ai/fa` + `muhaffidh.app` (webviews),
  `t.me` channel link, Play/Drive links (about).
- Firebase/Google: core/auth/firestore/messaging/storage + sign-in —
  suggestions/moderation, push, cloud backup. Offline-first posture and
  blocked-endpoint behavior are covered by existing tests/guards per earlier
  reports; re-verification is a device task.
- TLS: all hosts `https://`. No cleartext exception found in the manifest
  sample. Timeouts present on the sampled network paths (azan platform 10 s,
  FCM init 10 s). No static finding.

## Permissions
All manifest permissions map to features (location→prayer/qibla/map;
exact alarm + boot→adhan/alarms; notifications→reminders/adhan; DND→
mute-before-iqama; mic→notes voice recorder only; storage-adjacent→file
picker/share; vibration; foreground-service media→Quran lock-screen
controls). No new permission introduced by this audit. Play-policy wording
(Bazaar/Myket text, Data Safety answers) is a release task, not audited here.

## Logging
Covered by Phase 1 (`01_LOG_AUDIT.md`): levelled, scrubbed, capped, debug-only
console. No finding beyond fixed L1/L2 and deferred L3.

## Security
- PIN: salted SHA-256 verifier in Keystore-backed secure storage (migrated
  off plaintext prefs), constant-time compare, AES-256 vault key, lockout
  guard in the gate screen. Single-round SHA-256 (not PBKDF2) is noted as a
  P3 hardening candidate only — the gate is device-local UI, not remote auth.
- Secrets: keystore/`key.properties`/`google-services.json`/`quran_api.env`
  are gitignored (build-time copies only); only `quran_api.env.example` is
  bundled, with a "never bundle the real one" comment. No secret found in
  the repo sample.
- Manifest hardening / R8: `proguard-rules.pro` is wired, but local and CI
  release builds do **not** pass `--obfuscate --split-debug-info` — finding
  S1 (P2): enable obfuscation + archive symbols for store builds (needs a
  release-build verification; no behavior change expected, but native
  stack-trace readability for the reschedule fingerprint code must be
  re-tested).
- Dependency advisories: not scanned here (no audit tooling on this host) —
  recorded as a Phase-6/roadmap step, not a finding of a known CVE.
- Licenses/attribution: bundled fonts/content carry source comments
  (SurahNameV4, QuranCommon, QCF4); a full license-screen cross-check is a
  release task.
