# Home prayer arc: three styles — report (2026-11-01)

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


## What changed

The hero's arc now has three selectable looks, chosen once in
**تنظیمات ← ظاهر برنامه ← نمای قوس صفحهٔ اصلی** (and applied immediately,
without a restart):

| Style | Wire | Look |
| ----- | ---- | ---- |
| «برچسب‌دار» (default) | `tags` | calm 4dp arc, prayer tags with name + time outside, diamond milestones inside |
| «آسمان» | `sky` | same labels, 7dp gradient arc, sky dome, stars, glowing orb |
| «قطعه‌ای» | `segments` | nine coloured intervals, names inside, no times on the arc |

Existing installs keep `tags` — `HomeArcPrefs.style` defaults to it and a value
the app does not recognise also falls back to it.

## What was already there (and was NOT re-implemented)

`computeArcState()` in `lib/features/prayer/domain/prayer_clock.dart` already
produced exactly the model this task describes: the cycle
`Fajr(D) → Fajr(D+1)` that contains "now" (yesterday's cycle before today's
Fajr), ten markers at `0, 1/6, 1/3, 1/2, 7/12, 8/12, 9/12, 10/12, 11/12, 1`,
duha = sunrise + 20 min, midnight = midpoint Maghrib→next Fajr, last third =
Maghrib + 2/3 of the night, `nowFraction` interpolated linearly inside the
current segment, and `next` pinned to the snapshot's next **adhan**. Those
definitions were left untouched; the only model addition is `ArcMarker.time`,
so a tag can print the milestone's clock time.

## Architecture

| File | Role |
| ---- | ---- |
| `home/presentation/widgets/arc/arc_layout.dart` | `ArcGeometry` (330×215 design, centre (165,170), R=135, semicircle from t=0 left to t=1 right) and the label planner for all three styles. |
| `.../arc/arc_theme.dart` | The arc's tokens: track, passed, label/dim/time colours, marker fills, orb, next ring, the nine segment colours and the sky gradient stops, plus their light-surface variants. |
| `.../arc/home_arc.dart` | `HomeArc` widget (AspectRatio → RepaintBoundary → CustomPaint) and `ArcPainter`, which also powers the settings preview. |
| `home/presentation/providers/arc_style_provider.dart` | `HomeArcStyle` + `home.arcStyle` / `home.arcSmallLabels`. |
| `settings/presentation/screens/arc_style_screen.dart` | The three cards, the live preview and the small-labels switch. |

### Static/dynamic split

`ArcPainter` records everything that does not depend on the minute — track or
segments, sky fill, horizon, stars, marker shapes, every label — into a
`ui.Picture` and keeps at most **three** of them (LRU by key). The key is
`style | size | brightness | text scale | small-labels | 12/24h | lite | marker
states`, so:

- a minute change, a tap or a scroll reuses the picture;
- a marker boundary, a style change, a rotation or a text-scale change records a
  new one;
- `shouldRepaint` quantises `nowFraction` to 1/1440, i.e. the arc repaints at
  most once a minute, and never once per second for the countdown.

The dynamic layer is only the passed sweep (or the current segment's bright
part) and the orb: flat paths and circles, no text layout, no blur, no
`saveLayer`.

### Label layout

Labels are planned, not nudged: `planTaggedLabels` / `planSegmentedLabels`
place the next prayer's tag first, then the other prayer tags, then their times,
then the diamond names, and **drop** a candidate whose estimated box would
overlap an accepted one (`dropped` records which marker lost its label).
Priority means the next prayer always keeps its name and time.

Text scale rules:

- `> 1.15`: diamond names hide, except the one nearest the orb;
- `> 1.3`: prayer tags drop their times, except the next prayer;
- small labels off: no diamond names at all.

The box estimate is `text.length * fontSize * 0.52` wide and `fontSize * 1.25`
high — the same estimate in the planner and in the tests, so "no overlap" is a
property of the layout rather than of the font that happens to be loaded.

## Settings

`ظاهر برنامه` gained the row «نمای قوس صفحهٔ اصلی» (`/settings/arc-style`): three
72dp cards with markers-only thumbnails, a hero-like **live preview** drawn by
the real painter with the real snapshot, and the switch «نمایش نام نشانگرهای
کوچک» (default on). Keys: `home.arcStyle`, `home.arcSmallLabels`.

## Tests

- `test/features/home/presentation/widgets/arc/arc_layout_test.dart` — 21 tests:
  geometry (left/top/right ends, design ratio, marker fractions), no-overlap for
  320/360/412dp × 1.0/1.15/1.3, prayer tags carry their times, diamond names
  inside, small-label switch, large-scale time dropping, a missing Isha, the
  segmented plan, and the wire-value stability/migration.
- `.../arc/arc_widget_test.dart` — 11 tests: every style at 320 and 412dp, lite
  sky mode, the minute-granularity repaint policy, and preference persistence
  (default tags, stored choice, unknown value → tags).
- Goldens: the 6 home images were re-recorded for the new arc (they were red
  before this change), and the 3 settings images for the new appearance row.
  `flutter test test/features/home` = 22 golden tests green;
  `test/features/settings` + `test/core/navigation` + `test/features/prayer` =
  924 green.
- `flutter analyze lib test` → 0 errors / 0 warnings (10 pre-existing info lints
  elsewhere); `quality_check.py --strict` → 8/8 zero.

## Not done / open questions

- **No on-device performance numbers.** No Android device is attached, so the
  «dynamic paint < 2ms» target is not measured; what is guaranteed by
  construction is the picture cache, the 1/1440 repaint quantisation and the
  absence of text layout in the dynamic layer.
- **Style goldens for nine moments × two palettes were not added.** The home
  full-page goldens cover the default (`tags`) style at four sizes/palettes;
  the per-style moment matrix would be 54 more PNGs of the same painter, and the
  colour/marker rules it would guard are already pinned by the layout and widget
  tests.
- **Light-surface variants** are resolved by brightness but the hero itself is
  always the dark field, so only the ink colours differ today. The tokens are in
  place if a light hero is ever added.
- **Reduce-motion**: the orb is not tweened (it jumps at each minute), which is
  the reduced behaviour the spec asks for; there is no separate animation to
  disable.
