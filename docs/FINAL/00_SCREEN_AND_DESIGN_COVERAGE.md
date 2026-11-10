# 00 — SCREEN & DESIGN COVERAGE

**Base:** `release/1.8.0` @ `dccdcfd` (2026-10-12), mapped in worktree `final-map`
(branch `final/map`). **Docs-only**: nothing in `lib/` was touched for PART 1.

**Method.** Three independent evidence sources, cross-checked:

1. **Mechanical markers** (re-run today on this tree): does the file import the
   shared kit (`lib/core/design_system/components/*`), the phase system
   (`core/theme/time_theme.dart`), the **deprecated** `AppColors`
   (`core/theme/app_colors.dart` — the kit's own doc comment forbids it in
   redesigned files), plus counts of hard-coded `Color(0x…)` and raw
   `fontSize: <n>` literals. Regenerate with:
   ```bash
   for f in $(find lib -path '*screens*' -name '*.dart'); do
     printf "kit=%s tt=%s appcol=%s hc=%s raw=%s %s\n" \
       "$(grep -q design_system/components "$f" && echo Y || echo -)" \
       "$(grep -q core/theme/time_theme "$f" && echo Y || echo -)" \
       "$(grep -q -e 'AppColors\.' -e app_colors "$f" && echo Y || echo -)" \
       "$(grep -c 'Color(0x' "$f")" "$(grep -c 'fontSize: [0-9]' "$f")" "$f"; done
   ```
2. **Prior reports** — `docs/SCREEN_INVENTORY.md` (full 197-surface sweep at
   `phase1/redesign` @ `3a532e5`, 2026-10-06), `docs/QURAN_SCREEN_INVENTORY.md`,
   `docs/HOME_FINAL_REPORT.md`, `docs/HOME_POLISH_REPORT.md`, `docs/MORE_REPORT.md`,
   `docs/MORE_ICONS_REPORT.md`, `docs/SPLASH_REPORT.md`,
   `docs/QURAN_REDESIGN_REPORT.md`, `docs/MERGE_1_8_0_REPORT.md`, and `AGENTS.md`
   (which records every landing since).
3. **This session's spot checks** — one command per claim, recorded inline.

**Status legend** (design status): `DONE` = matches the approved language (kit
components + tokens, no deprecated palette); `PARTIAL` = new components on parts of
the file, legacy inside it; `LEGACY` = old design; `FROZEN` = must not be restyled
(mushaf page, حصن المسلم root); `NATIVE` = Kotlin/XML surface.
**Debt tag** (the user's scale): **D0** off-brand/unusable, **D1** legacy design,
**D2** partial, **D3** minor deviation.

**Template keys** (the PART-2 derivation rules): Hero · ListCard · GridTiles ·
QuranChrome · CalendarMonth · ReportGauge · SettingsRows · SimplePage · SheetDialog ·
SpecializedViewer · KeepNative.

---

## 0. Executive summary

| Metric | Value | Source |
|---|---|---|
| Dart files in `lib/` | **740** (excl. `.g.dart` + `lib/desine`) | ⚙ `design_consistency.py` |
| Screen files (`*/screens/*.dart`) | **93** | `find` |
| Top-level GoRoutes | **69** | `grep -c 'path: RouteNames' app_router.dart` |
| Shell tabs (not routes) | **6** | `main_shell.dart` |
| Widget files (`*/widgets/*.dart`) | **141** | ⚙ `design_consistency.py` |
| Files calling `showModalBottomSheet` | **41** call sites | ⚙ (PART-1 count 42/71 used a wider scope) |
| `showDialog` call sites | **26** in `lib/` | ⚙ (PART-1 count 119 used a wider scope) |
| Files importing the shared kit | **125** | grep (unchanged) |
| Files still importing deprecated `AppColors` | **13** | ⚙ `design_consistency.py` |
| BackdropFilter in production code | **0** (one comment in `glass_surface.dart:13`) | grep |
| `Opacity(` (non-animated) | **1** (`qibla_screen.dart:1620`) | grep |
| Raw `Color(0x…)` | **110** in screens / **282** all non-allowlisted `lib` files (+**759** allowlisted palette/painter/token lines) — from **201 / 714** at wave 0; the cross-cutting sweeps (`d09306a`) took it to 423, the inheritance palette to 300 (111 literals in 13 files → one `inheritance_palette.dart`; 12 more were a *tool* bug — the splash allowlist named a `screens/splash_style.dart` path that has never existed), and the last two share cards to 282 | ⚙ `design_consistency.py` |
| Raw `fontSize: <number>` | **2** in screens / **0** all non-allowlisted `lib` files (+138 allowlisted; **+59 fixed-layout** PDF/painter sizes reported separately) — every screen/widget size goes through `AppTheme.scaledFontSize` since `d09306a` | ⚙ `design_consistency.py` |
| `BoxShadow` sites with `blurRadius ≥ 10` | **45** non-allowlisted + **4** allowlisted (`card_design_system.dart` 14/18/22/30, `theme.dart` 14/24, …) | ⚙ `design_consistency.py` |
| `TextDirection.ltr` literals | **37** non-allowlisted + **6** allowlisted | ⚙ `design_consistency.py` |
| Golden PNG baselines | **71** (10 groups; the 18 failure-diff PNGs are gone with F-35) | `find test -name '*.png'` |
| Share surfaces with a raw colour or raw size | **0** of 10 (`*_share_screen.dart` + `*_share_card.dart`) | `share_surfaces_source_lock_test.dart` |

⚙ = machine-checked and ratcheted by **`tools/design_consistency.py`** (wave-0
0.4, exits non-zero when a non-allowlisted count grows). The raw-colour/raw-size
figures use the tool's *screens-only* scope so they stay comparable with the
PART-1 command above (≈250 / ≈300 then); the all-files scope is the one the
migration must drive down. Re-run the tool instead of re-grepping by hand.

**Wave-1 progress (2026-10-12).** The six cream share cards (prayer times,
adhkar, duas, ayah, tafsir, dua-from-Quran) are `DONE`: one `ShareCardPalette`
replaces six hand-copied palettes and all their raw sizes, so §C/§D/§E rows for
those surfaces move from D1 to DONE (each file: 0 raw colours / 0 raw sizes).
Still `LEGACY` in this wave: `yaqeen_lesson_screen` (D1, 17/21),
`book_reader_screen` (D1, 15/4), the ketabkhaneh library (D2) and
`reading_stats_screen` (D1, 0/3).

**The share surfaces are locked (2026-10-13).** All ten
`*_share_screen.dart` / `*_share_card.dart` files are at **0 raw colours / 0 raw
sizes**, enforced by `test/core/design_system/share_surfaces_source_lock_test.dart`:
it scans their source, and it also asserts the file list itself, so a new share
card cannot appear without joining the lock. Closing it meant migrating the last
two cards — `hadeeth_share_card` (13 literals, all byte-identical to
`ShareCardPalette`, whose cream paper it always was) and
`dangi_settlement_share_card` (5, now `DangiSettlementPalette` in
`dangi_colors.dart`). The hadith card's grade→ink mapping moved into
`HadeethPalette.grade`, and the lock was proved to bite: an injected
`Color(0xFF123456)` and an injected `fontSize: 13` each failed it, as did a
throwaway `zzz_share_card.dart`.

**Wave 3, slice 1 — the inheritance tool (2026-10-13).** `tools/inheritance/**`
is `DONE` for colour: 13 files carried 111 `Color(0x…)` literals (the same purple
family written out twenty-one times, `0xFF6A1B9A` alone in 11 of the files, two
identical fourteen-colour pie series, the two-stop hero band twice) and now
carry **0** — one `inheritance_palette.dart` names them, including the
`Madhab → colour` map the comparison tab used to declare twice. Every
replacement was proved byte-identical to the literal it displaced (121 colour
slots across 67 diff hunks, resolved name-by-name), so the share card and the
donut export the same pixels; the palette's `series` keeps the donut's exact
slice ORDER, which is load-bearing. Chart series, the reader's chosen colours
and a scoped identity table are not design tokens, so the module sits under the
existing `*_palette.dart` allowlist precedent — the count still shows in the
tool's `allowlisted` column. Still open in this feature: the layout recipes
(`SpecializedViewer`, D1) and the two goldens that must be re-pinned
deliberately if the layout moves.

**Headline:** the *spine* of the app is redesigned and consistent — Home (7 cards),
More, Calendar, Splash, the Evaluation tab, the Quran reader chrome + its lists, the
bottom nav and the settings hub were all migrated onto the kit with goldens. The
remaining design debt is concentrated in **(a)** secondary/detail screens never
touched by any wave (qibla, period, moon, zakat, inheritance, ketabkhaneh/book reader,
audio library, ruqyah, tasks, dua/hadith share viewers, personal-info sub-screens,
goals, khatm/hifz stats, yaqeen, fatwa, pump/forms) and **(b)** the *interiors* of a
few sheets that sit under redesigned hosts (mushaf colour sheets, tasbih dialogs,
khatm dialogs). Full per-surface grading below.

---

## A. Shell, boot, splash, onboarding

| Surface | File | Route/entry | Status | Debt | Template | Evidence / notes |
|---|---|---|---|---|---|---|
| Root app | `lib/main.dart` (protected) | MaterialApp.router | DONE | — | — (wiring) | phase theme + TextScaler + error handlers |
| Shell | `lib/app/router/main_shell.dart` | `/` shell | DONE | — | SpecializedViewer | AmbientBackground + IndexedStack; bottom nav rebuilt in the home line |
| Bottom nav | `lib/app/router/home_bottom_nav.dart` | tab bar | DONE | — | Navigation | equal pills, labels inside, per-tab hues; `main_shell` tests + goldens |
| 404 | `lib/app/router/app_router.dart` `_NotFoundScreen` | errorBuilder | PARTIAL | D2 | SimplePage | Persian copy OK; still Material defaults (`FilledButton`) — no kit |
| Location/GPS dialog | `lib/app/state/boot_coordinator.dart` (protected) | boot, once | LEGACY | D1 | SheetDialog | `Theme.of` -based dialog |
| Error boundary | `lib/core/error/error_boundary.dart` | wraps routes | PARTIAL | D2 | SimplePage | functional; not on kit |
| Splash | `lib/features/splash/presentation/screens/splash_screen.dart` | `/splash` | DONE | — | SimplePage | rebuilt 2026-10-12 (`5229ce4`,`400fb1e`,`a608008`); 8 goldens; no system-window mark |
| Splash style constants | `splash_style.dart` | — | DONE | D3 | — | 12 hard-coded colours by design (splash is theme-independent) — allowlist |
| Onboarding | `lib/features/onboarding/presentation/screens/onboarding_screen.dart` | `/onboarding` | LEGACY | D1 | SimplePage | 3 steps (location/notification/theme); no kit, 1 raw fontSize; only 1 test |
| Font display page | `lib/features/settings/presentation/screens/font_display_page.dart` | `/settings/font` | PARTIAL (assumed) | D2 | SettingsRows | not covered by SCREEN_INVENTORY; verify in PART 2 |

## B. Home tab (the approved reference)

Landing: `home/final-v3` + `home/polish-v2` (`ffcbe94`, `b873178`, …). Report:
`docs/HOME_FINAL_REPORT.md`; 11 goldens in
`test/features/home/presentation/screens/goldens/`.

| Surface | File | Status | Debt | Evidence |
|---|---|---|---|---|
| Hero card (clock, 3-date chips, 10-marker arc, countdown to **adhan**, iqama pill) | `home/…/widgets/hero_card.dart` | DONE | D3 | `hero_card.dart` still imports `AppColors` (2 uses) and `home_tab.dart` imports it — the only deprecated-palette files in the whole shell; flagged D3, not a visual problem |
| Prayer-times card (5-seg bar, single-line rows, «اکنون»/«بعدی», Friday, hayz) | `prayer_times_card.dart` | DONE | D3 | same `AppColors` import |
| Rawatib card | `rawatib_card.dart` | DONE | — | row-major RTL, counter chip |
| Daily summary (3 rings + streak) | `daily_summary_card.dart` | DONE | — | |
| Actions timeline | `actions_timeline_card.dart` | DONE | — | Part 5 |
| Reminders card | `reminders_card.dart` | DONE | — | restored-rows bug fixed here |
| Home tab composition | `home/presentation/screens/home_tab.dart` | DONE | D3 | full-bleed hero + padded column; imports deprecated `AppColors` only |
| Home tokens | `home/…/widgets/home_tokens.dart` | DONE (by design) | — | 28 semantic hexes; intended single source for the home palette |
| Daily adhkar category page | `home/…/widgets/adhkar_category_page.dart` | PARTIAL | D2 | imports `AppColors` |

**Deviation from the approved mockup:** the ordering is hero → اوقات → رواتب →
خلاصهٔ روز → تایملاین اعمال → یادآورها (approved order) — confirmed in
`PROGRESS.md` and `HOME_FINAL_REPORT.md`. No structural deviation found.

## C. Prayer, qibla, period

| Surface | File | Route | Status | Debt | Template | Evidence / notes |
|---|---|---|---|---|---|---|
| Prayer guide (7 tabs) | `prayer/…/screens/prayer_screen.dart` | `/prayer` | LEGACY | D1 | SimplePage | kit import **but** 3 hard-coded colours + 2 raw sizes |
| Prayer & adhan settings | `prayer_settings_screen.dart` | `/prayer-settings` | PARTIAL | D2 | SettingsRows | kit import, 1 raw size; 1230 LOC god-screen — split in PART 2/3 |
| City picker sheet | `prayer/…/widgets/city_picker_sheet.dart` | sheet | LEGACY | D1 | SheetDialog | |
| Calculation method + details sheets | `prayer_calc_widgets.dart` | sheets | LEGACY | D1 | SheetDialog | |
| Qibla | `qibla_screen.dart` | `/qibla` | LEGACY | D1 | SpecializedViewer | 1692 LOC, kit import only; **the only `Opacity(` in lib** (L1620); 14 raw sizes |
| Qibla sub-cards | `qibla_compass_card.dart`, `qibla_info_card.dart` | in-page | LEGACY | D1 | SpecializedViewer | in `screens/` dir but not routes |
| Period tracker | `period_screen.dart` (protected) | `/period` | LEGACY | D1 | SpecializedViewer | kit imported; interiors legacy |
| Period widgets (7 part files) | `period_widgets.dart` + parts | in-page | LEGACY | D1 | SpecializedViewer | report/journal/PIN/PDF |
| Battery optimisation guide | `battery_optimization_screen.dart` | `/battery` | PARTIAL | D2 | SimplePage | kit import |
| Map picker | `map_picker_screen.dart` | `/map-picker` | LEGACY | D1 | SpecializedViewer | 2 hard-coded colours |
| Prayer-times share | `prayer_times_share_screen.dart` | `/share-times` | LEGACY | D1 | SpecializedViewer | **18 hard-coded colours, 12 raw sizes** — the worst share surface |

## D. Quran, mushaf, khatm, hifz, duas

Reader chrome and every reader **list** moved to the kit (`502dcb8`, `719ee32`,
`5a298b0`, `quran_kit_row.dart`, 2026-10-12). Report: `docs/QURAN_REDESIGN_REPORT.md`.
The page itself is frozen.

| Surface | File | Route/entry | Status | Debt | Template | Notes |
|---|---|---|---|---|---|---|
| Quran tab (host) | `quran/presentation/screens/quran_tab.dart` | tab 1 | PARTIAL | D2 | QuranChrome | 73-LOC host; no style of its own |
| Mushaf reader + header + player | `mushaf/quran_mushaf_view.dart` (2716 LOC) + `…_players/…_overlays/…_content_sheets` parts | in-tab | DONE (chrome) | D3 | QuranChrome | kit row; 15 raw sizes remain in the reader (all on-scale integers, so the guard tolerates them — they simply do not follow the user's font scale; see 01_FINDINGS F-07) |
| Reader lists (reciter, translation/tafsir, player options, index, search) | `quran_kit_row.dart` consumers | sheets/screens | DONE | — | ListCard | `_KitListRow` **deleted** — one recipe only |
| Colour/paper + highlight sheets | `mushaf_color_sheets.dart` (978 LOC) | sheets | LEGACY | D1 | SheetDialog | theme + mushaf palette; 3 goldens |
| Content/tafsir sheets | `mushaf_color_sheets`’ sibling `quran_mushaf_sheets.dart` | sheets | LEGACY | D1 | SheetDialog | tafsir/text viewers |
| Pre-download + QCF4 sheets | `quran_mushaf_pre_download_sheet.dart`, `quran_mushaf_qcf4_sheet.dart` | sheets | DONE | — | SheetDialog | storage hero + juz grids |
| Ayah action sheet / reading settings | `quran_reader_ayah_sheet.dart`, `quran_mushaf_view.dart` | sheets | DONE | — | SheetDialog | |
| QCF4 page viewer + surah header + page chrome | `mushaf/qcf4/*` | page | FROZEN | — | KeepNative | religious text/line-break pipeline — never restyle |
| Surah index / search / bookmarks | `quran_surah_list_screen.dart`, `quran_search_screen.dart`, `quran_bookmarks_screen.dart` | push | DONE / LEGACY | D1 for search | ListCard | index rebuilt; search + bookmarks still `AppColors`-era |
| Ayah/tafsir share viewers | `quran_ayah_share_screen.dart` (568), `quran_tafsir_share_screen.dart` (594) | push | LEGACY | D1 | SimplePage | |
| Khatm dashboard/stats | `khatm_screen.dart` (896), `khatm_stats_screen.dart` (1018) | `/khatm` | PARTIAL | D2 | ReportGauge | kit imported; heatmap + dialogs legacy |
| Hifz | `hifz_screen.dart` (998), `hifz_report_screen.dart` (914) | `/hifz` | PARTIAL / LEGACY | D2/D1 | ReportGauge | report has 8 hard-coded colours + 25 raw sizes |
| حصن المسلم root | `adhkar/duas/…/duas_screen.dart` (protected, frozen) | `/duas` | FROZEN | — | — | only file still on `AppColors` that must stay |
| Dua detail / intro reader | `dua_detail_screen.dart`, `hesn_intro_reader_screen.dart` | push | LEGACY | D1 | SimplePage | |
| Dua share | `dua_share_screen.dart` | push | LEGACY | D1 | SimplePage | 13 hard-coded colours |
| Dua from Quran (+share) | `dua_from_quran_screen.dart` (688), `…_share_screen.dart` (510) | `/dua` | LEGACY | D1 | ListCard | `AppColors`-era palette |

## E. Adhkar & tasbih (tab 2)

| Surface | File | Status | Debt | Notes |
|---|---|---|---|---|
| Tab host + settings sheet + reset dialog | `azkar_tasbih_tab.dart` (523) | PARTIAL | D2 | kit import; 7 raw sizes; dialogs legacy |
| Tasbih counter | `tasbih_counter_widget.dart` (1379) | PARTIAL | D2 | **known-red type-scale literal `fontSize: 9.5` at :1276**; task #6 in progress (AGENTS) |
| Azkar list | `azkar_list_widget.dart` (479) | PARTIAL | D2 | time_theme + glass, not kit |
| Zikr card (post-prayer) | `zikr_card.dart` | LEGACY | D1 | |
| Adhkar share | `adhkar_share_screen.dart` (545) | LEGACY | D1 | 13 hard-coded colours |
| Tasbih widget preview | `tasbih_widget_preview.dart` | PARTIAL | D2 | mirrors the native widget |

## F. Calendar, evaluation, worship, fasting, hajj, ruqyah, reminders

| Surface | File | Status | Debt | Evidence |
|---|---|---|---|---|
| Calendar tab + month grid + selected-day box | `tools/calendar/…/calendar_screen.dart` (541), `calendar_month_widgets.dart`, `calendar_style.dart` | DONE | D3 (11 semantic hexes in `calendar_style.dart`) | `calendar/redesign` (`e577f2b`), 7 goldens; **no** `Navigator.push` allowed (guard test) |
| Day journal + events | `calendar_day_journal.dart`, `calendar_events_section.dart` | DONE | — | card_design + kit |
| Date converter | `date_converter_screen.dart` | DONE | — | 2 goldens; hijri-offset listen fix |
| Evaluation tab | `worship/…/screens/evaluation_tab.dart` (thin) + `evaluation_stats_widget.dart` (1927!) | DONE | D3 | score is a kit `RingView` (`b95411d`); guard test + golden; the widget file is the largest non-reader file — split candidate |
| Checklist | `checklist/…/worship_checklist_screen.dart` (705) | PARTIAL | D2 | rebuilt rows, no kit import |
| Fasting | `fasting_screen.dart` (560) + `ramadan_tracker_tab.dart` | LEGACY | D1 | 5 hard-coded colours |
| Hajj & Umrah | `hajj_umrah_screen.dart` (704) | LEGACY | D1 | |
| Ruqyah | `ruqyah_screen.dart` (1086) | LEGACY | D1 | 9 hard-coded colours |
| Reminders list / editor | `reminders_screen.dart` (782), `reminder_editor_screen.dart` (1284) | PARTIAL | D2 | reminders list on kit |
| Pomodoro | `tools/pomodoro/pomodoro_screen.dart` (970) | LEGACY | D1 | |
| Tasks | `tasks_screen.dart` (451) | LEGACY | D1 | 10 hard-coded colours |

## G. Knowledge: hadith, dorar, riyad, fatwa, yaqeen, books, education, audio

| Surface | File | Status | Debt | Notes |
|---|---|---|---|---|
| Hadith books index | `hadith_books_screen.dart` (1597) | PARTIAL | D2 | kit import, 2 hard-coded |
| Book reader | `books/…/book_reader_screen.dart` (1272) | LEGACY | D1 | 15 hard-coded colours |
| Library (ketabkhaneh) | `ketabkhaneh_screen.dart` (1805) | PARTIAL | D2 | 12 hard-coded colours, 8 raw sizes |
| Reading stats | `reading_stats_screen.dart` | LEGACY | D1 | |
| Dorar search + details | `dorar_hadith_search_screen.dart`, `…_details_screen.dart` | LEGACY | D1 | network feature; provider fixes are the recent work |
| Riyad as-Salihin list/chapter | `riyad_screen.dart` (743), `riyad_chapter_screen.dart` (540) | PARTIAL | D2 | |
| Encyclopedia of hadith (hadeeth_enc) + share | `hadeeth_enc_screen.dart` (1004), `…_detail_screen.dart`, `…_share_screen.dart` | PARTIAL | D2 | share card 13 hard-coded |
| Fatwa | `fatwa_screen.dart` (852) | PARTIAL | D2 | 5 hard-coded |
| Yaqeen | `yaqeen_home_screen.dart` (652), `…_lesson_screen.dart` (1045), `…_level/…_quiz` | PARTIAL | D2 | lesson page 17 hard-coded + 21 raw sizes; **search excluded from More search because of the password gate** |
| Audio library + mini player | `audio_library_screen.dart` (1555), `audio_library_player.dart` (1517) | PARTIAL | D2 | recently perf-optimised (lazy lists) |
| Education: sciences home/detail/study | `sciences_home_screen.dart` (371), `science_detail_screen.dart`, `study_screen.dart`, `study_widgets.dart` (1735) | PARTIAL | D2 | kit import in the home; detail/study legacy |
| Search (global) | `search/…/search_screen.dart` (500) | PARTIAL | D2 | |

## H. Tools

| Surface | File | Status | Debt | Notes |
|---|---|---|---|---|
| Zakat | `tools/zakat/…/zakat_screen.dart` (1849) | PARTIAL | D2 | **28 hard-coded colours** (largest single offender); fiqh table issue `J-1` open |
| Inheritance (calculator + 5 tabs + share) | `tools/inheritance/**` (`calculator_tab` 1806, `madhab_calculator.dart` 1488, `pie_chart` 28 colours) | LEGACY | D1 | 2 goldens |
| Purification (wudu/طهارت) | `purification_screen.dart` (777) | PARTIAL | D2 | kit import, 7 hard-coded |
| Moon & mansions | `tools/moon/**` (`moon_screen.dart` 1377, **48 raw fontSize literals**) | PARTIAL | D2 | protected; accuracy confirmed; the 48 raw sizes are the largest type-scale debt |
| Dangi (split bills) | `dangi_screen.dart` (940+666 report) | PARTIAL | D2 | report 18 raw sizes |
| Calculator | `calculator_screen.dart` (868) | PARTIAL | D2 |
| Date converter | see F | DONE | — | |
| Hajj/fasting/purification see F | | | | |

## I. Personal, expenses, notes, goals, tasks, account

| Surface | File | Status | Debt | Notes |
|---|---|---|---|---|
| «اطلاعات من» landing + 8 sub-screens (profiles, documents, credentials, assets, insurance, emergency, expiry, editor) | `personal_info/**` (protected) | PARTIAL | D2 | all on kit; 1–7 hard-coded each; vault encryption caveat in 01_FINDINGS F-19 |
| Photo gallery | `photo_gallery_screen.dart` | LEGACY | D1 | not a top-level route (pushed) |
| Expenses + report | `expenses_screen.dart` (428), `expense_report_screen.dart` (728) | LEGACY | D1 | report 9 raw sizes |
| Worship notes + editor | `worship_notes_screen.dart` (1396), `note_editor_screen.dart` | PARTIAL | D2 | 7 hard-coded |
| Goals list/detail/editor | `goals_screen.dart` (666), `goal_detail_screen.dart` (1225), `goal_editor_screen.dart` (900) | PARTIAL | D2 | kit imported |
| Tasks | see F | LEGACY | D1 | |
| Account/sign-in | `account_screen.dart` (891) | PARTIAL | D2 | `Theme.of`-era |
| Suggestions / announcements | `suggestions_screen.dart` (1079; 17 raw sizes), `announcements_screen.dart` (781) | PARTIAL | D2 | |
| Personal-info lock / PIN | `personal_info/…/pin_lock_service.dart` + screens | PARTIAL | D2 | PIN pad in the landing screen |

## J. Settings & diagnostics

| Surface | File | Status | Debt | Notes |
|---|---|---|---|---|
| Settings hub | `settings/presentation/pages/settings_screen.dart` (1850) | PARTIAL | D2 | kit + time_theme, but **12 hard-coded colours** and a 1850-LOC god-file |
| More | `more_screen.dart` (1111) | DONE | — | 4 columns, flat duotone tiles, in-section search; 15 goldens |
| Notification settings | `notification_settings_screen.dart` (940) | PARTIAL | D2 | 1 hard-coded |
| Notification diagnostics | `notification_diagnostics_screen.dart` (624) | DONE | — | kit; armed-reminders card |
| Attachment diagnostics | `attachment_diagnostics_screen.dart` (557) | DONE | — | kit |
| Widget settings | `widget_settings_screen.dart` (1136) | PARTIAL | D2 | 6 hard-coded; includes Flutter mirror of the native widget |
| About | `about_screen.dart` (552) | PARTIAL | D2 | 2 hard-coded |
| Backup/restore UI | inside settings pages | PARTIAL | D2 | flows verified in tests; no device round-trip yet |
| Battery guide | see C | PARTIAL | D2 | |

## K. Native Android surfaces (Kotlin/XML — 26 `.kt` files, 6 972 LOC)

| Surface | Files | Status | Notes |
|---|---|---|---|
| Home-screen prayer widget (5 layouts) | `widget/PrayerWidget.kt` (513), `PrayerWidgetViews.kt` (376), `PrayerTimesCalculator.kt` (556), `WidgetRepository.kt` (485), `WidgetTokens.kt` (127), `WidgetHub.kt` | DONE (own language) | palette-token driven; `updatePeriodMillis=1800000`; refresh on TIME_SET/TIMEZONE_CHANGED/DATE_CHANGED + `WidgetHub.refreshAll`; Kotlin unit tests exist (4 files, 538 LOC) |
| Tasbih glance widget | `widget/TasbihGlanceWidget.kt` (290), `TasbihGlanceWidgetReceiver.kt` (369) | DONE | counters + daily reset tested in Kotlin |
| Notification channels | `core/NotificationChannelManager.kt` | DONE | see 03 map |
| Splash window | `res/values*/styles.xml`, `drawable/launch_background.xml`, `splash_icon_none` | DONE | no mark in the system window (user verdict) |
| Adhan foreground service | `AzanForegroundService.kt`, `core/AzanAudioResolver.kt` | DONE | mediaPlayback type |
| Media session | `audio_service` + `MediaButtonReceiver` | DONE | lock-screen controls |
| Reminder/alarm receivers | `core/{ExactAlarmHelper,ExactReminderScheduler,AdhanReceiver,ReminderReceiver,BootReceiver,RolloverReceiver,ScheduleRefreshReceiver,SilentModeReceiver}.kt` | DONE | 2 300 LOC, 1 Kotlin test file |

## L. Unlisted / hidden screens found in code

- `/settings/notification-diagnostics`, `/settings/attachment-diagnostics` —
  diagnostics pages (reachable from Settings; no More tile).
- `/settings/font` (`FontDisplayPage`) — reachable from the settings hub only.
- `/in-app-browser` — WebView host for qaf.ai; args-only route.
- `/map-picker`, `/prayer-times-share`, `/battery` — sub-flows of prayer.
- `/hadeeth-enc/:id` accepts **two shapes**: an `extra` object or a bare id
  (by-id screen is a distinct widget).
- `/personal-info/*` — 8 guarded sub-routes (`VaultGuard`), each its own screen.
- Not routes at all (pushed inside features): photo gallery, reading stats, dangi
  report + group, khatm stats, hifz report, yaqeen level/quiz/lesson, book reader,
  qibla compass/info cards, `document_editor_sheet`, `period_day_sheet`,
  quran search/bookmarks/share viewers.
- `lib/main_admin.dart` + `lib/admin_web/**` (2 files) — admin entry points,
  **not part of the Android app** (separate `main`); confirm before deleting.
- `lib/desine/**` — the standalone design reference package (excluded from
  analyze, never compiled) — a doc artifact living inside `lib/`.
- Removed and must stay removed: prompter/«مصحف توحید», recitation-lab/«تلاوت‌یار»,
  `/prompter`, `/prompter/stats`, `/recitation-lab`. Only residue found today:
  `TimeTheme.prompter` colour constant (`lib/core/theme/time_theme.dart:95`) — dead
  token, candidate for PART 2 cleanup.

## M. Design-debt roll-up

| Debt | Count (screens) | Where |
|---|---|---|
| **D0** (off-brand/unusable) | **0** | none found |
| **D1** (legacy design) | **~34 screens / ~20 sheet+widget files** | qibla + its cards, period + widgets, moon interiors, zakat interiors, inheritance suite, ketabkhaneh/book-reader/reading-stats, audio library interiors, ruqyah, tasks, fasting, hajj, dua reader/share, dua-from-quran share, prayer guide, prayer share, map picker, city picker, calc sheets, mushaf colour/tafsir sheets, quran search/bookmarks/share viewers, khatm/hifz dialogs, tasbih/zikr cards, adhkar share, personal-info photo gallery, expenses + report, pomodoro, yaqeen interiors, fatwa interiors, hadith book reader, education study screen, onboarding, 404, boot dialog, settings interiors |
| **D2** (partial) | **~30 screens** | see tables above (kit imported, legacy interiors/colours remain) |
| **D3** (minor) | **~8 files** | home (`AppColors` ×3 files), calendar style hexes, splash style hexes, evaluation, mushaf reader type |
| Hard-coded `Color(0x…)` in feature screens | **~250 occurrences across ~60 files** | top: zakat 28, prayer-share 18, yaqeen-lesson 17, book-reader 15, adhkar-share 13, dua-share 13, ketabkhaneh 12, dua-detail 11, dua-from-quran-share 10, tasks 10, ruqyah 9, hifz-report 8, purification 7, worship-notes 7, widget-settings 6, fasting 5, fatwa 5, reminders 5, goals 3, adhan settings … |
| Raw `fontSize:` in screens | **~300 occurrences** | top: moon 48, hifz-report 25, yaqeen-lesson 21, dangi-report 18, yaqeen-home 18, suggestions 17, prayer-share 12, dua-from-quran-share 13, dangi-group 12, hifz 9, expense-report 9, ketabkhaneh 8, yaqeen-quiz 8, tasbih tab 7 |
| Deprecated `AppColors` imports | **9 files** | `home_bottom_nav.dart`, `card_design_system.dart`, `app_text_styles.dart`, `design_tokens.dart`, `duas_screen.dart` (frozen), `home_tab.dart`, `adhkar_category_page.dart`, `hero_card.dart`, `prayer_times_card.dart` |

**Sanctioned exceptions (keep):** `duas_screen.dart` (frozen), the mushaf/QCF4 bundle
(frozen), `home_tokens.dart` + `splash_style.dart` + `calendar_style.dart` +
`worship_colors.dart` + `mushaf_palette.dart` + `mushaf_backgrounds.dart` +
`time_theme.dart`/`theme.dart`/`section_colors.dart`/`app_colors.dart` (palette
sources — the PART-2 consistency check must allowlist them explicitly).

## N. What this map could not verify (honest gaps)

1. **No screenshot per surface.** Repo has 10 device screenshots
   (`docs/device-verify/*.png`, POCO 2026-10-09) + 85 golden PNGs — with the known
   caveat that goldens render **tofu glyphs** (no font in the test binding) and
   therefore guard layout/palette, not Persian shaping.
2. **A connected POCO 2412DPC0AG (Android 16) exists today** and the installed
   1.8.0 build was measured (05_BASELINE), but no *low-end* (A13/A32-class) device
   was available; frame-time profiling (`gfxinfo`) is Impeller-blind on this device.
3. **Statuses marked "(assumed)"** (font display page) need one confirmation pass in
   PART 2 when that file is opened.
4. Sheet/dialog **interiors** were graded from the prior inventory + the marker on
   their owning file; a sheet inside a DONE file (e.g. tasbih dialogs) is marked
   PARTIAL only when the inventory recorded it as legacy.

**Deliverable of PART 2 is satisfied when every row above reads DONE (or an explicit
`needs decision`), and section M's counts reach zero inside the allowlist.**
