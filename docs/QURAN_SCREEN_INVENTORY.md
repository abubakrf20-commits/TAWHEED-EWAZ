# QURAN_SCREEN_INVENTORY.md — full Quran feature (branch `quran/redesign`, 2026-10-10)

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


Screens/sheets/chrome in `lib/features/quran/**` (+ the Quran tab in the shell).
Template keys: **R** reader chrome, **L** list/index, **D** download, **S** sheet,
**V** viewer, **P** player, **X** dialog/state.
Religious text (glyphs, ayah markers, surah headers, page breaks, tafsir/
translation text) is NEVER touched — presentation only.

| # | Screen/sheet/state | Current file(s) | Template |
|---|---|---|---|
| 1 | Mushaf reader (page + chrome) | `mushaf/quran_mushaf_view.dart` (2417) | R |
| 2 | Reader header band (icons, reciter chip, overflow) | same | R |
| 3 | Reader fullscreen exit chip | same (`_FullscreenExitChip` in `quran_mushaf_overlays.dart`) | R |
| 4 | Reader go-to dialog (page/surah/juz) | `mushaf/quran_mushaf_small_sheets.dart` | X |
| 5 | Reading settings sheet | `quran_mushaf_view.dart` `_showReadingSettingsSheet` | S |
| 6 | Verse-follow sheet | same `_showVerseFollowSheet` | S |
| 7 | Translation list sheet (tafsir/translation pickers) | `mushaf/quran_mushaf_content_sheets.dart` | S |
| 8 | Tafsir viewer (per-ayah tafsir) | `mushaf/quran_mushaf_content_sheets.dart` + `services/tafsir_service.dart` | V |
| 9 | Pre-download sheet (pages+fonts+translation audio) | `mushaf/quran_mushaf_pre_download_sheet.dart` (1080) | D |
| 10 | QCF4 download sheet (embedded variant) | `mushaf/quran_mushaf_qcf4_sheet.dart` (416) | D |
| 11 | QCF4 page viewer (page renderer) | `mushaf/qcf4/qcf4_page_viewer.dart` (1040) | R |
| 12 | QCF4 surah header (custom painted) | `mushaf/qcf4/qcf4_surah_header.dart` | R |
| 13 | Mini players (recitation + translation) | `mushaf/quran_mushaf_players.dart` | P |
| 14 | Player expanded sheet (reciter/speed/repeat) | `mushaf/quran_mushaf_sheets.dart` | P/S |
| 15 | Ayah action sheet | `mushaf/quran_mushaf_sheets.dart` | S |
| 16 | Ayah share screen (range/text/image) | `mushaf/quran_ayah_share_screen.dart` | V |
| 17 | Range share sheet | `quran_mushaf_view.dart` `_showRangeShareSheet` | S |
| 18 | Repeat-range dialog | `mushaf/quran_mushaf_small_sheets.dart` | X |
| 19 | Surah/Juz index | `mushaf/quran_surah_list_screen.dart` | L |
| 20 | Quran search | `mushaf/quran_search_screen.dart` | L |
| 21 | Bookmarks | `quran/presentation/quran_bookmarks_screen.dart` | L |
| 22 | Quran tab (entry) | `quran/presentation/screens/quran_tab.dart` | R |
| 23 | Color/paper + highlight sheets | `mushaf/mushaf_color_sheets.dart` (795) | S |
| 24 | Translation audio controller UI | `mushaf/quran_translation_audio_controller.dart` | P |
| 25 | Tafsir share screen | `mushaf/quran_tafsir_share_screen.dart` | V |
| 26 | Loading / error / empty / offline states | scattered (sheets + screens) | X |

Not in this feature (unchanged): recitation-lab/prompter (removed), tafsir SQLite
downloads live in `services/tafsir_service.dart` (data only).

Plan + status in `docs/QURAN_SCREEN_INVENTORY.md` §Plan.

## Plan

- **Step 0**: shared fraction formatter + tests (bug 1), storage counters from disk (bug 4).
- **Step 1**: reader header rework (spec A) + SafeArea fixes (bug 2, 3) + chips removal.
- **Step 2**: reader page chrome (gutter, ring page number, paper themes, highlight picker, immersive).
- **Step 3**: player collapsed/expanded (spec A-player).
- **Step 4**: overflow menu (B) + reading settings sheet (C) + ayah sheet (D).
- **Step 5**: download page (E) + robustness verification.
- **Step 6**: translation/tafsir sheet (F).
- **Step 7**: index/search/bookmarks/viewers (G).
- **Step 8**: goldens + mushaf integrity + performance + report.
