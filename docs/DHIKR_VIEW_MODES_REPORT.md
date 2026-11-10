# Dhikr collections: list / timeline / focus — report (2026-11-01)

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


## What changed

Every adhkar collection (all ten, see
[DHIKR_COLLECTIONS_INVENTORY.md](DHIKR_COLLECTIONS_INVENTORY.md)) now renders
through one shared page with three selectable views:

1. **فهرست** (default) — the section's familiar list, refined.
2. **تایم‌لاین** — a vertical rail down the start edge; the current dhikr is the
   only full card, finished ones collapse to a row with «انجام شد».
3. **تمرکز** — one dhikr at a time with a 150 dp counter ring, undo, skip and a
   gentle completion card.

One selector (`DhikrViewSelector`) sits under the app bar on every collection and
persists `dhikr.viewMode`. One controller (`DhikrSessionController`) holds the
session for all three, so switching views mid-dhikr cannot lose a count.

## Architecture

| File | Role |
| ---- | ---- |
| `features/adhkar/presentation/collection/dhikr_session_controller.dart` | Pure per-collection state: counts, done, skipped, current index, `tap/undo/complete/setDone/skip/unskip/goTo/advance/markAll/resetAll`, `seed()` migration. No widgets, no I/O. |
| `.../collection/dhikr_list_view.dart` | Mode 1. `ScrollablePositionedList` so the search focus jump stays an exact index jump. |
| `.../collection/dhikr_timeline_view.dart` | Mode 2. Rail + node painter by plain containers, `RepaintBoundary` per row. |
| `.../collection/dhikr_focus_view.dart` | Mode 3. Counter ring, segmented bar, bottom pills, completion card, swipe left→right = next (RTL). |
| `.../collection/dhikr_collection_kit.dart` | Tone resolution, Arabic box, virtue/source chips, 40 dp icon button, progress card, copy helper. |
| `.../collection/dhikr_palette.dart` | The section's fixed tokens (navy, cream, rail, ring track, gold tint, paper, hairline). |
| `.../providers/dhikr_view_prefs.dart` | `DhikrViewMode` + auto-advance / haptics / keep-awake prefs and the per-collection session stamp. |

### Where state lives, and why

Completion flags and repetition counts stay in **`azkarProvider`** — that is
where the daily reset policy lives and it is unchanged. The controller adds
only what a session needs and the provider never had: the current item and the
skipped set, persisted per period under `dhikr.session.<period>` and stamped
with the azkar *day key*, so a session that crosses the reset starts clean the
same way progress rows do.

`azkarProvider.setCount(id, value, target)` is new: the provider could only walk
one step up (`incrementCount`), which cannot express undo or a restored count.

### Persistence behaviour

- One item change → debounced 250 ms → a single provider write.
- Bulk changes (mark all / clear) → one batch write.
- Session stamp (current/skipped) → debounced 250 ms, flushed on pause; both
  timers are cancelled in `dispose`.

## Behaviour worth not breaking

- **Long break of a dhikr is never invented:** an item with no `repeatCount`
  has a target of 1. No count is parsed from Arabic text.
- **Rapid taps:** counts are clamped at the target and extra taps are ignored;
  the focus view never double-advances (advance is a single 350 ms timer that
  is cancelled on a new completion).
- **«رد کردن» keeps the count.** A skipped dhikr resumes where it stopped and
  appears on the focus bar in the skipped state; the completion card offers
  «رفتن به رد شده‌ها».
- **Reduce motion:** no animation is played for any mode-critical state change
  (the 350 ms advance is a timer, not an animation); the app's
  `disableAnimations` path leaves the views static.
- **Keep-awake** is acquired only in «تمرکز» with the setting on, through the
  ref-counted `AppWakelock` (`adhkar_focus` owner), released on mode change,
  pause and dispose.
- **One selector, one palette:** all three modes read `DhikrTone`/`DhikrPalette`,
  and no widget hard-codes a colour.

## Selection, reset, and the appearance sheet

- App bar keeps «انتخاب همه» (now with a confirmation and an **undo** snackbar).
- Overflow: «ظاهر و ترتیب نمایش» (mode + three switches) and «پاک کردن پیشرفت این
  مجموعه» (confirmation, then a snackbar).
- The same three options are **not** duplicated in the global Settings screen:
  the sheet is one tap from every collection and adding a second copy in
  `settings_screen.dart` (a file the parallel session is editing) risked a
  conflicting write for no functional gain. Open question for the user — see
  below.

## Tests

- `test/features/adhkar/presentation/collection/dhikr_session_controller_test.dart`
  — 21 unit tests: single/target-3/target-33 counting, the clamp, 100 rapid taps,
  undo from partial and from done, skip/unskip, `nextUnfinishedAfter` wrap,
  `advance`, `markAll`, `resetAll`, percent math, bulk-vs-single notification, and
  four seeding/migration cases (stored done → full count, stored partial,
  over-target clamp, done-wins-over-skipped, cursor repair).
- `test/features/adhkar/presentation/collection/dhikr_views_test.dart` — 23
  widget tests: each mode at 320/360/412 dp and text scale 1.0/1.3 without
  overflow, list counter «+» and completion circle, timeline expand/collapse and
  the advance pill, focus ring counting with and without auto-advance, undo,
  skip, the completion card, and the selector's three options.
- Existing guards still pass unchanged: `adhkar_category_page_test.dart` (search
  focus lands on the hit, highlight painted), `actions_timeline_card_test.dart`,
  and the whole `test/features/adhkar` tree — 211 passing.
- `flutter analyze lib test` → 0 errors / 0 warnings; `quality_check.py --strict`
  → 7/7 zero.

## Not done, and why

- **Golden images for the three modes.** The rest of the suite uses goldens, but
  these views take their colours from `TimeThemeKit`, and a golden recorded here
  would freeze the widget-test font fallback, not the app's rendering. The
  layout guarantees are pinned by the overflow tests instead. Worth adding once
  the section has a stable custom font in tests.
- **On-device performance numbers.** No Android device was attached, so the
  «tap latency < 100 ms» target is **not measured**; what is guaranteed by
  construction is one `ChangeNotifier` notification per tap and a
  `RepaintBoundary` around the ring/lines.
- **Global Settings section** — see above.
