# Audio library hosting

«کتابخانه صوتی» streams `.opus` files listed by one JSON manifest. Nothing in
the app hard-codes a host beyond the default below, so the whole library can be
moved without touching Dart code.

## What the app needs from a host

| Requirement | Why |
| --- | --- |
| Public, unauthenticated `GET` | No credentials ship in the app; the manifest and files are fetched with plain `http`. |
| **HTTP Range → `206`** | Seeking inside a lecture uses `UrlSource`; without byte ranges the seek bar jumps to the end or fails. |
| CORS `GET` for the manifest origin | The manifest is read by the app, but a browser/CDN preview must also work. |
| ASCII object keys | `tool/audio_library/*.ps1` and the manifest stay ASCII; Persian lives only in track titles. |
| `index.json` readable at `<base>/index.json` | Default manifest location when not overridden. |

## Current layout

```
base   https://s3.ir-thr-at1.arvanstorage.ir/t.audio
files  <base>/yaqeen/<file>.opus
       <base>/عربی نشید/<file>.opus  +  <base>/فارسی نشید/<file>.opus
       <base>/sokhanrani/<speaker>/<file>.opus   (ziaei/, rahemi/, bazmandegan/)
       https://sunnatmedia.ir/download/Abdulghani-Badri/…   (tafsir-badri)
index  <base>/index.json
```

Lecture files live one folder per speaker under `sokhanrani/`; anything
directly under `sokhanrani/` that no speaker folder claims becomes the
«متفرقه» section inside «سخنرانی». New lecture audio is numbered lessons
(`1. …`, `2. …`) — see `tool/audio_library/compose_manifest.py`, rebuilt with
`python compose_manifest.py --bucket t.audio --out index.json` and re-uploaded
as `<base>/index.json`.

**One section is not on this bucket.** «تفسیر قرآن مولانا عبدالغنی بدری» is
served by the source itself, and its files are not re-uploaded: the manifest
carries the third-party URL verbatim as the track `file`, and
`AudioLibraryConfig.objectUrl()` returns an absolute URL unchanged instead of
re-pointing it at the bucket. Two consequences a future edit must respect —
a bucket-composed `index.json` cannot know those 160 tracks, so
`compose_manifest.py` re-attaches every absolute-URL section from the published
manifest (`carry_external()`, defaulting to the file already at `--out`); and
the URL is never re-encoded, because re-escaping `036-Ya%20Seen.mp3` turns its
`%20` into `%2520` and the fetch 404s.

Path style (`host/<bucket>/<key>`) is mandatory for `t.audio`: ArvanCloud's
certificate is `*.s3.<region>.arvanstorage.ir`, which matches exactly one DNS
label, so the virtual-hosted form `t.audio.s3.<region>.arvanstorage.ir` puts
two labels ahead of `s3` and the TLS handshake fails.

Defined in `lib/features/audio_library/audio_library_config.dart`.

## Supabase outage (2026-10) — repointed to ArvanCloud

**Outcome (verified 2026-10-07):** `qjrhxnmxmqtnusifpngd.supabase.co` no longer
resolves in DNS at all, so every request for the manifest or a file dies in
name resolution. `AudioLibraryConfig` now defaults to the ArvanCloud bucket
above, and `--dart-define=AUDIO_LIBRARY_BASE_URL` still overrides it.

This is also the exact shape of the "the app says I have no internet" report:
a host name that does not resolve is indistinguishable on the device from a
dead connection, so the failure is typed `offline` and the caption blames the
listener. Any build that predates the repointing still carries the dead
Supabase base and reads that way on a perfectly good connection.

For the record, the original failure: the bucket answered
`402 {"error":"exceed_cached_egress_quota"}` for every
object, including `index.json`. That is a **billing/egress cap on the Supabase
project**, not a client bug: the server replies with a quota error, so the
request reaches it — the connection on the device side is fine. Two ways out,
both account-side:

1. Raise or reset the cached-egress quota in the Supabase dashboard
   (Settings → Infrastructure / Billing), or upgrade the plan.
2. Move the content to a host without an egress cap — see below.

While the host is unreachable the app shows the tracks already downloaded on
the device (see *Offline behaviour*), so users are not locked out.

## Repointing the host (no code changes)

```
flutter run   --dart-define=AUDIO_LIBRARY_BASE_URL=https://cdn.example.com/tawheed
flutter build apk --dart-define=AUDIO_LIBRARY_BASE_URL=https://cdn.example.com/tawheed
```

`AUDIO_LIBRARY_BASE_URL` moves **both** the files and the manifest (the
manifest defaults to `<base>/index.json`), which is deliberate: listing from
one host and streaming from another would play files the list never promised.
`AUDIO_LIBRARY_MANIFEST_URL` still overrides the manifest alone, for a staged
migration where the index moves first.

Do not commit a production host into `audio_library_config.dart` as the only
copy — pass it at build time so the same binary can be re-shipped against
another mirror.

### Migrating to Cloudflare R2 (recommended: no egress fees)

1. Create a bucket (e.g. `tawheed`), enable the public development URL or a
   custom domain with a CDN. R2 serves `Range` requests natively.
2. Upload with `wrangler` or any S3 client:
   `wrangler r2 object put tawheed/yaqeen/<file>.opus --file <path>`
   (or `aws s3 sync` against the R2 S3 endpoint).
3. Re-upload the manifest built by `build_full_manifest.ps1` as `index.json`
   at the bucket root.
4. Build with `--dart-define=AUDIO_LIBRARY_BASE_URL=<public r2 url>`.

### Migrating to GitHub Releases

Works for modest libraries (files ≤ 2 GB per asset, no egress cap, raw URLs
answer `Range`). Keep the object keys identical — upload the release assets
under the same `<category>/<file>.opus` names and point the base at
`https://github.com/<owner>/<repo>/releases/download/<tag>` only if the asset
URLs are flat; otherwise host `index.json` on GitHub Pages and the files on the
release CDN, and set `AUDIO_LIBRARY_MANIFEST_URL` accordingly.

## Rebuilding and uploading the content

```
$env:SUPABASE_SERVICE_ROLE = '<secret>'          # never committed
.\tool\audio_library\build_full_manifest.ps1 -OutFile index.json …
.\tool\audio_library\upload_supabase.ps1 -Bucket tawheed `
    -SourceDir "<staged upload dir>" -FolderPrefix yaqeen
```

`upload_supabase.ps1` is resumable (existing objects of the correct size are
skipped) and takes `-BaseUrl` for projects other than the default one. The
mapping CSVs under `tool/audio_library/` are the single source of truth for
track order and titles.

A hosted-elsewhere section needs no bucket credentials, only the two input
files beside the script — a `URL<TAB>title` TSV and the sizes measured from the
host, because `sizeBytes` is printed on the track tile («<n> مگابایت») and folded
into the section total, so a zero reads as an empty file:

```
python tool/audio_library/probe_track_sizes.py \
    --input tafsir_badri_tracks.tsv --out tafsir_badri_sizes.json
python tool/audio_library/build_tafsir_badri_manifest.py \
    --input tafsir_badri_tracks.tsv --sizes tafsir_badri_sizes.json \
    --base  <the published index.json> --out index-v5.json
```

Both refuse to write anything unless every row succeeded, and
`test_build_tafsir_badri_manifest.py` / `test_compose_manifest.py` run offline
(`python -m unittest discover -s tool/audio_library -p "test_*.py"`). Upload the
result as `<base>/index.json` — the app fetches that one path, so a section is
live the moment the file is swapped, with no app-code change.

## Verifying a host by hand

```
curl -s -o /dev/null -w "%{http_code}\n" <base>/index.json
curl -s -r 0-1023 -o /dev/null -w "%{http_code} %{size_download}\n" <base>/lectures/<file>.opus
```

Expected: `200` for the manifest and **`206` with 1024 bytes** for the ranged
file request. A `200` on the ranged request means the host ignores `Range` —
seeking will not work. `402`/`403` means the account cap or bucket policy.

## Offline behaviour

- `AudioLibraryRepository` caches the manifest in SharedPreferences
  (stale-while-revalidate), so a returning user sees the full list instantly
  and a refresh failure is silent.
- Failures are typed (`AudioLibraryFailure`): `offline`, `server`, `data`. A
  402/403/500 is reported as a hosting problem, never as «اینترنت وصل نیست».
- `AudioLibraryPlayer` keeps a device-side index (`audio_lib_local_index`) of
  every downloaded track. When the manifest cannot be loaded at all, the
  screen renders that local library with a `ServiceUnavailableBanner` and a
  retry button; downloaded tracks play without any network.
