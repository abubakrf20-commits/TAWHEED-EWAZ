# QURAN_REDESIGN_REPORT.md — the reader chrome & list pass

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


Branch `release/1.8.0`. This session: 2026-10-12, on top of the quran redesign
line (`c578e33` → `f471e0f`) and the splash line (`79fdd1b`).

Commits:

| commit | what |
| --- | --- |
| `502dcb8` | the download hero's off-scale type onto the shared scale |
| `719ee32` | every reader list on the shared kit row, and a rotate button in the bar |
| this doc | the report + the `PROGRESS.md` entry |

Religious content is untouched throughout: only chrome, colour, spacing and
row structure outside the text block. No glyph, verse, order, page boundary or
mushaf asset changed.

## 1. The one list row (`quran_kit_row.dart`)

Every list in the reader had grown its own row: a gradient tile in the reciter
sheet, bare `ListTile`s for translations/tafsirs, a second `ListTile` list for
the in-download reciter picker, the player's speed/repeat pickers, the surah
index (a `Card` per row), search results, and the player's own options sheet.

They now all share **`QuranKitRow`**, built on the same flat duotone
`DuotoneIconTile` the home page puts on every prayer, rawatib and reminder row
(fill accent @14 %, border @18 %, radius 0.32·S, glyph `mix(accent, black, .10)`
— flat alphas, no gradient, no blur). The row carries:

- a leading duotone tile (or `QuranKitNumberTile` for number-led rows),
- a title on the shared type scale (`scaledFontSize(context, 14)`, w600; w700
  when selected) and a subtitle at 12 in `surfaceMuted` — overridable via
  `subtitleColor` for rows whose subtitle is the real content,
- an optional `badge` chip after the title (the translation/tafsir language
  tag), an optional `trailing` widget, and a faint accent wash when `selected`.

It takes a `MushafPalette`, not the app theme: the mushaf is deliberately
theme-independent (a paper/night reader), so a sheet follows the paper it opens
on. The mushaf view library imports it, so every `part` sees it.

## 2. Where it landed

- **Reciter sheet** (`quran_mushaf_small_sheets.dart`): the local `_KitListRow`
  is deleted; the sheet uses the shared row.
- **Downloads page** (`quran_mushaf_pre_download_sheet.dart`): the in-download
  reciter picker used a second, older `ListTile` list — now the same row, so
  the two duplicates collapse into one. Its wifi subtitle also lands on the
  type scale.
- **Translations & tafsirs** (`quran_mushaf_sheets.dart`): the language tag
  survives as a chip next to the name (new small `_LangChip`).
- **Player** (`quran_reader_player.dart`): the options sheet's `_sheetRow` and
  both pickers (speed, repeat) use the kit row; the two pickers gain vertical
  padding so their first row no longer hugs the sheet's rounded top.
- **Surah index** (`quran_surah_list_screen.dart`): the per-row `Card` is gone
  — a duotone number tile, the Arabic name over its meta line, and the start
  page as the trailing chip, flat on the page like Home and «بیشتر».
- **Search** (`quran_search_screen.dart`): a number tile, the surah identity,
  the matching verse as the readable second line, and the page chip.

## 3. The rotate button in the header

`quran_reader_header.dart` gains a fifth control between the bookmark and the
overflow: `stay_current_landscape` / `stay_current_portrait`, tooltipped with
the destination («حالت افقی» / «حالت عمودی»). It calls the same
`_setLandscapeLock` the reading-settings switch uses, so the two controls can
never disagree and the choice still survives a restart through the existing
`quran_landscape_lock` restore path. The switch stays in the settings sheet as
the discoverable form.

The header now carries five 44dp controls; at 320dp the centre title keeps
~100dp and truncates with ellipsis. `quran_mushaf_widget_test.dart` still
renders the header at 320dp with no render overflow.

## 4. Deliberately not changed

- **The go-to dialog's surah tab** (`quran_mushaf_small_sheets.dart`): it is a
  bare number + name list *on purpose* — the reader asked for «جزء و سوره در
  بوکس نباشند». Adding kit tiles there would undo that.
- **`MushafSettingRow`** (`mushaf_color_sheets.dart`): a dense settings row
  with a spelled-out current value, not a list entry. See §6.2.
- The mushaf text block, its pages, goldens and assets.

## 5. Verification

- `flutter analyze lib/features/quran` → **0 issues**.
- `quality_check.py --strict` → **7/7 gates at zero**.
- Full quran suite (`test/features/quran`, `--exclude-tags network`, minus the
  foreign untracked audit test) → **273 passed / 0 failed**.
- The header, sheet, picker and surah-index widget tests stay green.
- `type_scale_guard_test` now lists only the pre-existing
  `tasbih_counter_widget.dart:1276` literal (another session's file); the three
  quran literals this pass found are fixed.
- **No Android device is attached**, so this is static + widget-test proof, not
  an on-device pass. Persian shaping, real contrast on the night paper, and the
  rotate button's actual orientation change are unverified on hardware.

## 6. Review of the section — findings (read-only, not applied)

1. **Bookmarks screen ignores the reader's palette.** `_showBookmarkList`
   pushes `QuranBookmarksScreen` with a raw `Navigator.push`, and that screen
   is built on the app's time theme (`TimeThemeKit`) — so opening the list from
   a night-mode reader cross-fades into the light theme, and the row card uses
   the theme's flat accent tile rather than the reader's duotone one. Worth
   passing the active `MushafPalette` in (the row recipe is already shared).
2. **`MushafSettingRow` is the last ListTile in a mushaf list.** It is
   defensible (value line, dense), but its leading tile is a flat accent box,
   not the duotone tile, so the settings sheet is the one surface that does not
   match the kit. Converting it re-pins the three sheet goldens.
3. **Two reciter sheets, one row.** The reciter sheet and the download page's
   picker now share the row but still have separate `showModalBottomSheet`
   chrome (title, padding, height). A single `ReciterPickerSheet` would remove
   the last duplicate.
4. **`QuranKitRow(icon: …, leading: …)`** — both are optional and `leading`
   silently wins. A `debug` assert would catch a caller who passes neither.
5. **Search results do not mark the match.** The full verse previews at two
   lines; the searched word is not highlighted. A simple `TextSpan` highlight
   over the normalized key would make scanning much faster.
6. The section has no goldens for the reader's *lists* (the colour-sheet,
   page-viewer and reader goldens cover the page). If the row recipe drifts
   again, nothing catches it — the new `quran_kit_row.dart` deserves a small
   golden or at least a widget test of its states (selected / badge / trailing).

## 7. Suggested next features (numbered, awaiting approval)

1. **Match highlight in search results** (§6.5) — small, high perceived value.
2. **A single reciter sheet** shared by the player, the settings and the
   download page, with the download size per reciter and a «دانلود کل سوره»
   action from the picker.
3. **«ادامهٔ مطالعه» on Home** — the reader already persists the last page; a
   one-tap resume card would close the loop between the two redesigned tabs.
4. **Bookmark notes surfaced** — the bookmarks table already has a `note`
   column and `QuranBookmarksScreen` renders it; there is no UI to *write* one.
   Attaching a note from the ayah sheet is a small, self-contained addition.
5. **Bookmark sort/filter chips** (by surah, by recency) on the list screen.
6. **Player quick-toggle** — long-press the speed row to flip 1× ↔ 2×, skipping
   the sheet (the speed range already reaches 2×).
7. **Translation compare** — a two-column ayah sheet when two or more
   translations are downloaded.
8. **Semantics pass on the kit row** — one `Semantics` label per row so screen
   readers get «قاری — حفص عن عاصم» instead of two loose texts.

Each is independent; tell me which numbers to take and I will open them one at
a time.

## 8. The page identity moves ONTO the paper (2026-10-13)

Commit `922ec33`, branch `quran/page-chrome-identity` off `a69f875`.

Reader request: «اسم سوره و جزء حتی در صورت صفحه غیر کامل هم بالا باشد، و پایین
ایکون صفحه راست و چپ حذف کن، اما شماره صفحه خیلی رفته سمت چپ یک مقدار کمی بیاد
راست که موازی آیات باشه». Asked back, the two ambiguities resolved to
**continuation pages** and **both chrome states**.

Three changes, all inside the bands the page already reserves — the pager
geometry invariant (§ the note in `quran_mushaf_view.dart`'s `build`) is
untouched, so a swipe still cannot skip a page:

1. **Surah + juz print on every page, in both states.** `_PageChrome` used to
   receive `null` for both whenever the header was up, on the theory that the
   header carried the same facts. It now always receives them, and the two
   `Positioned`s moved from `top: 8` to `top: headerBand + 8`, where
   `headerBand` is the `_pageTopInset` the view already computes. So with the
   chrome up they sit in the 28 dp band *below* the header instead of behind it,
   and in fullscreen they stay exactly where they were. A continuation page is
   not a special case: `_surahNameFor(page)` answers for every page from the
   page data, which is what makes the request a removal rather than a new
   feature.
2. **The bottom-left page-side glyph is deleted**, `_PageSideIcon` with it —
   the «صفحهٔ راست / صفحهٔ چپ» affordance and its `Semantics` label went with
   the icon, since nothing else in the reader ever spelled the spread side.
3. **The page number moved right, inside the text column.** It used to ride
   beside that glyph, at `left: 8 + 16 + 5 ≈ 29`; the glyph's deletion alone
   would have dropped it to 8, right into the 26 dp gutter shadow — the
   «خیلی رفته سمت چپ» the reader saw. It now sits at a named
   `_PageChrome._numberLeft = 34`, clear of the binding band, and its `bottom`
   tracks `_pageBottomInset` so a visible mini player pushes it up instead of
   covering it. Fullscreen-only as before (the header prints «صفحه N» while it
   is up).

Proof:

- `the page identity is printed inside the page bands` (sheet suite) now
  measures both states: with the chrome up the labels are asserted
  structurally against `Qcf4PageViewer`'s top edge — they must clear the header
  *and* stay above the glyphs — and in fullscreen against the pager's bands,
  corners and the new `left: 34`, plus `number.left > pager.left + 26` so the
  number can never move back onto the gutter shadow.
- `the page-side right/left glyph is gone from the reader` asserts both
  semantics labels are absent in fullscreen.
- The header test that counted one «سورة …» now counts **two** and pins that
  one of them is the page's own `mushaf_corner_surah_1` label.
- `flutter test test/features/quran` → **310 passed / 0 failed**; analyze
  0 errors / 0 warnings; `quality_check.py --strict` 7/7; encoding guard green.
- **No Android device is attached.** The reading of «موازی آیات» as "out of the
  spine shadow, into the text column" is the one judgement here that only the
  reader's eye can confirm.
