# Quran Offline Setup Guide

## Step 1: Generate Quran Text Data

Run this script on your dev machine (needs internet ONCE):

```bash
dart run tools/generate_quran_db.dart
```

This downloads from api.quran.com and creates:
- `assets/quran_offline.json` (~3-4MB)
  - All 114 surahs metadata
  - All 6236 verses (Arabic Uthmani + Imlaei)
  - Full Persian translation (Islamhouse, ID 135)

After running, add to `pubspec.yaml` under `assets:`:
```yaml
- assets/quran_offline.json
```

## Step 2: Add Mushaf Page Images

You need 604 page images of the Madani Mushaf.

### Option A: From existing source
Place 604 WebP files in `assets/quran/pages/`:
```
assets/quran/pages/001.webp
assets/quran/pages/002.webp
...
assets/quran/pages/604.webp
```

### Option B: Download from open sources
Use any free Mushaf page image dataset (e.g., from Quran.com or similar).
Convert to WebP for smaller file size (~50-80KB per page = ~30-50MB total).

### Recommended specs:
- Format: WebP (smaller than PNG)
- Resolution: 1200x1800 pixels (good for mobile)
- Naming: 001.webp through 604.webp (zero-padded)

The pubspec.yaml already declares:
```yaml
- assets/quran/pages/
```

## Step 3: Build & Run

```bash
flutter pub get
flutter run
```

## Architecture

```
lib/
  services/
    quran_db_service.dart         # SQLite database (bundled JSON → DB on first run)
    offline_quran_provider.dart   # State management for offline Quran
  features/quran/presentation/
    quran_home_screen.dart        # Main Quran hub
    quran_text_reader.dart        # Arabic + Persian text reader
    quran_image_reader.dart       # Mushaf image page viewer
    quran_surah_list.dart         # 114 surahs list
    quran_juz_list.dart           # 30 juz list
    quran_bookmarks_screen.dart   # Saved bookmarks
    quran_search_screen_new.dart  # Search in Arabic/Persian/surah names

tools/
  generate_quran_db.dart          # One-time data generation script
```

## Data Flow

1. `generate_quran_db.dart` → downloads data → `assets/quran_offline.json`
2. App first launch → `QuranDbService` reads JSON → populates SQLite
3. All subsequent reads → instant SQLite queries (no network)
4. Mushaf images → loaded from `assets/quran/pages/` (bundled)

## Features

- Text mode (Arabic only)
- Text + Translation mode (Arabic + Persian)
- Translation only mode
- Image Mushaf mode (page-by-page with zoom)
- Continue last reading
- Bookmark ayahs
- Search in Arabic text
- Search in Persian translation
- Search surah names
- Jump to any ayah/page/surah/juz
- Night mode
- Adjustable font sizes
