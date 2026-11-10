# Tawheed — Data sources

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


Companion to `docs/AUDIT_REPORT.md`. Every place the app reads or writes data
outside its own Dart code, on branch `release/1.7.2`
(worktree `%TEMP%/opencode/merge-172`). Paths below are relative to that root.

**Headline:** all configured endpoints are HTTPS (`usesCleartextTraffic="false"`).
Prayer times, qibla, Hijri/Jalali calendars and moon/mansions are computed **fully
on-device** — no location ever leaves the phone for time calculation. Network is
used only for: hadith search, downloadable content (tafsir/hadith/books/ruqyah),
recitation models, audio, a city-name/altitude convenience lookup, FCM, Drive
backup, and the self-update manifest.

---

## 1. Network endpoints

| Purpose | Host / path | Client | Resilience / failure |
|---|---|---|---|
| Content catalog + downloads (tafsir, hadith, books, ruqyah, translation, update manifest) | `raw.githubusercontent.com/abubakrf20-commits/TAWHEED-EWAZ/main/…` (`quran_api_config.dart:49-50`; `QF_CONTENT_BASE` override) | `content_download_service.dart`, `quran_content_service.dart` | 15-min whole-file timeout, gzip, size caps (1/96/512 MiB), name sanitised against traversal; failure → null, caller shows retry |
| Downloaded SQLite bodies | `hadith/hadith.db`, `riyad/…`, `hadeeth_enc/…`, `fatwa/fatwas.db` | `downloaded_sqlite_db.dart` (rev key `content_rev_<db>`) | `.part`+rename; no hash (see §4) |
| Recitation/prompter models (gated HuggingFace mirror, never bundled) | `…/recitation_model/` (`model_downloader.dart:20-22`) | `model_downloader.dart` | HTTPS-only; 45 s headers + 90 s stall timeouts, 3 attempts, **Range resume**, byte-floor verify, 401/404/410 bail |
| Dorar hadith search (الدرر السنية) | `dorar.net` site HTML + `dorar_api.json` fallback | `dorar_remote_datasource.dart`, `BrowserUserAgentClient` | site-parse primary (2026 markup), api fallback (no ids); Cloudflare 400/403/503 → retry once with Dart UA; `dorar_cache.db` 7-day TTL |
| QCF4 mushaf pages + fonts | `raw.githubusercontent.com/MohamadHajjRabee/quran-qcf4` + `cdn.jsdelivr.net` | `qcf4_data_store.dart`, `qcf4_font_loader.dart` | disk-first, one CDN fetch per miss (pages 30 s; fonts 3×45 s), corrupt file auto-deleted |
| Reciter catalog + verse audio | `api.alquran.cloud`, `cdn.islamic.network`, `everyayah.com` | `mp3quran_service.dart` | curated offline fallback list; 7-day audio cache; explicit offline set in Drift `AudioDownloadTable` |
| Word-level recitation timing | `api.quran.com/api/v4/…?segments=true` | `quran_timing_service.dart` | 10 s; failure → whole-ayah highlight (no word sync) |
| Persian translation audio | `d.quranenc.com/data/audio/persian_ih/…` | `quran_translation_download_service.dart` | browser UA (CDN 403s Dart UA); bulk per-surah/juz offline download |
| Quran Foundation API (dev-only) | `apis.quran.foundation` + OAuth2 | `quran_api_service.dart` | **not configured in release** — `isConfigured` false, falls back to bundled page table; no credentials shipped |
| Audio library | Supabase `…supabase.co/…/tawheed` (dart-define override) | `audio_library_repository.dart`, `…_player.dart` | Range/206 streaming; offline `.opus` files; failure classified unreachable vs parse |
| Reverse geocoding | `nominatim.openstreetmap.org/reverse` + device geocoder | `location_resolver.dart` | 8 s, custom UA; queried in parallel with offline `place_index.dart` fallback (nearest within 150 km) |
| Elevation | `api.open-meteo.com/v1/elevation` | `location_resolver.dart:230-244` | 8 s, optional; offline → number hidden |
| Map tiles | `tile.openstreetmap.org/{z}/{x}/{y}.png` | flutter_map (map picker, qibla) | — |
| Zakat live prices | `call.tgju.org/ajax.json` | `zakat_live_price_service.dart` | 12 s; failure → manual/persisted prices |
| Firebase (Firestore, Auth, FCM, Storage) | project `tawheed-1f347` | `firebase_options.dart`, `firebase_push_service.dart`, `firestore_*` | degrades silently when unconfigured; FCM only after notif permission |
| Drive backup | scope `drive.appdata` | `drive_backup_service.dart` | appDataFolder ZIPs, keep newest 10 |
| Self-update | `${contentBaseUrl}/app/update.json` | `update_checker.dart`, `update_installer.dart` | 8 s, never throws; **APK host allowlist + required SHA-256 pin**; installer verifies hash before opening |
| External links | qaf.ai, muhaffidh.app, t.me, Play, Drive | `in_app_browser_screen.dart`, url_launcher | WebView origin-confined (§I-3 of the audit) |

## 2. Bundled assets (read at runtime; `pubspec.yaml:157-176`)

`azkar_content.json` 76 KB · `hesn.db` 828 KB (copied to Documents) ·
`mokhtasar.db` 3.6 MB (offline tafsir fallback) · `persian_translation.json` 1.7 MB ·
`quran/quran_data.json` 2.4 MB (surah/juz/page tables — pinned by
`quran_integrity_test.dart`) · `riyad_hadith_labels.json` · `books_data/books_index.json`
(books themselves downloaded) · `content/*.json` 2.4 MB (static fiqh/education) ·
`azan/*.mp3` 2.3 MB · `sounds/*` · fonts Calibri/Vazirmatn/Amiri +
`qcf4/surah-name-v4.ttf` + `quran-common.ttf` (offline mushaf header glyphs).
`assets/env/quran_api.env.example` only — the real env is deliberately **not** bundled.

## 3. Local persistence

- **Drift/SQLite** `app_database.dart` — 38 tables (settings, azkar/tasbih/duas,
  books/bookmarks, notes, khatm, reminders, worship status, periods, prayer tracker,
  tasks, expenses+budget, hifz, calculator, dongi, quran bookmarks/highlights/audio
  downloads, goals, personal_info, dorar favorites, pomodoro). Schema v43. File
  `Documents/app.sqlite`, rotating 3-gen backups, `busy_timeout=5000`, FK on.
- **Raw sqlite3**: `Documents/hesn.db` (from asset), downloaded read-only content
  DBs, `dorar_cache.db` (app-support).
- **flutter_secure_storage** (Keystore): prayer coords `saved_lat`/`saved_lng`;
  personal_info AES-256 key + PIN verifier.
- **SharedPreferences**: onboarding flags, coord fallback, audio/reciter/positions,
  reader prefs, zakat prices, content revisions, favourites, prompter settings.
- **path_provider**: Documents (DB+backups, models, `quran_content/`,
  `audio_library/`, `update/` APK), ApplicationSupport (`dorar_cache.db`).

## 4. Integrity / trust notes (see SECURITY_PRIVACY.md)

- Only the recitation-model downloader does Range resume; every other downloader
  is whole-file `.part` + restart.
- Downloaded content DBs/models are verified by **size floor only** — no
  hash/signature; the GitHub account is the root of trust. The self-update APK
  path is the exception (SHA-256 pin required).
- Qur'an text asset integrity is guarded in tests (`quran_integrity_test.dart`:
  sha256 pin + 114 surahs, Σ 6236 ayat, 604 pages, 30 ajzā'), not at runtime.
