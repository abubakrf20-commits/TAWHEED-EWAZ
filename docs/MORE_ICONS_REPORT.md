# More icons — Style 2 (flat duotone squircle) — `more/icons-style2`

Branch `more/icons-style2` off `release/1.8.0`.

> **Historical snapshot.** The per-group counts below describe the page when this style
> landed. The live split is **53 = 18/12/3/15/5** and every tile move since then is
> recorded in `docs/SECTIONS_1_9_0.md`. Scope kept exactly to the
approved spec: the More page's icons/tiles, grid spacing/grouping and utility
rows. Navigation, routes, search behaviour, the next-prayer strip logic and all
other screens untouched. Every item kept, every route kept.

## What changed (before → after)

| aspect | before (Style 1, `more/redesign`) | after (Style 2, this branch) |
| --- | --- | --- |
| tile art | glossy gradient squircle — `mix(c, white, .68→.42)` plate, white border feel | flat duotone: fill `c @ 0x24`, 1dp border `c @ 0x2E`, back circle `c @ 0x28` bleeding out of the bottom-start corner, corner dot `c @ 0x70` top-end, all clipped at radius `0.32·S` |
| tile size | fixed ~96dp cells | `S = clamp(0.8·(cell−10), 58, 77)` via `LayoutBuilder`; 3 columns, crossAxisSpacing 0, mainAxisSpacing 14 |
| label ink | accent-derived (`readableLabel`) | theme ink `textPrimary` (the theme's own contrast contract), 12.5sp w500, max 2 lines, FittedBox scaleDown, 7dp below tile |
| grouping | each tile its own bordered card | one white `AppCard` per group (radius 22, 0.5px hairline, padding 6/14/6/10); `SectionHeader` with an 8dp gap above |
| groups | 7/5/10/3/12/4 | **6/6/10/3/12/4** — رقیه شرعی moved عبادات → قرآن و ادعیه so the first two groups are multiples of 3; hadith stays 10 (best fit), tools 12, app 4 |
| utility rows | kit `SettingRow` (plain `IconData`) | page-local `_UtilityRow`: 40dp mini squircle of the same recipe (glyph `0.52·S`), title 13.5 w500, subtitle 10.5 muted, chevron, 0.5px separators, one `AppCard` |
| interaction | tap | splash at the squircle radius over the whole cell (≥48dp target), `HapticFeedback.selectionClick()`, 150ms scale-down (`Transform.scale` only), `Semantics(button: true, label: title)` |
| registry | fixed | `iconScale` field (0.9–1.1) per item for optical balancing; one registry remains the single source of truth |

No gradients, no gloss, no white borders, no shadows, no blur, no `Opacity` /
`saveLayer` — flat alpha-derived colors only, derived once per
`(accent, brightness, card surface)` and memoized (`MoreDuotone._cache`).

## Final placement of all 41 items

Groups in page order; `Δ` = iconScale (untouched items are 1.0).

**عبادات و مناسک (6):** نماز Δ.94 · قبله‌نما · وضو و طهارت Δ1.06 · روزه · زکات
Δ.95 · حج و عمره Δ.94

**قرآن و ادعیه (6):** ختم قرآن Δ.95 · حفظ قرآن Δ.98 · مصحف حافظ Δ.98 · دعا
Δ1.06 · حصن المسلم · رقیه شرعی (moved here)

**حدیث و مطالعه (10):** ریاض الصالحین Δ1.04 · کتب حدیث Δ.96 · جستجوی احادیث
Δ1.08 · فتاوای شرعی Δ1.02 · موسوعه احادیث Δ.96 · کتابخانه Δ.96 · علوم اسلامی
Δ.96 · مطالعه آزاد Δ.96 · تثبیت یقین (locked) · هوش مصنوعی شرعی قاف Δ1.04

**کتابخانه صوتی (3):** رد شبهات · اناشید اسلامی Δ1.06 · سخنرانی

**ابزارها و پیشرفت (12):** ماه و منازل · میراث Δ.94 · هدف‌گذاری · اطلاعات من ·
مدیریت کارها Δ.98 · هزینه‌ها · یادداشت‌ها Δ.98 · یادآورها · دوره ماهانه ·
ماشین حساب Δ.98 · پومودور · دنگی

**تنظیمات و بیشتر (4, rows):** تنظیمات · پشتیبان‌گیری · ارسال پیشنهاد · درباره
برنامه

## Tile size S and the neighbor gap

Grid width = screen − 2×page padding (10) − 2×card padding (6) − the card's two
0.5px hairlines; cell = width/3.

| screen | cell | S | edge gap = cell − S |
| --- | --- | --- | --- |
| 320dp | 95.67 | **68.53** | 27.1 (spec window 18–34 ✓) |
| 360dp | 109.0 | **77** (cap) | 32.0 ✓ |
| 412dp | 126.33 | **77** (cap) | 49.3 — see open question 1 |
| 600dp | 189.0 | **77** (cap) | — |

Guarded by tests: tile squares 58–77 at 320/360/412/600 with exactly 37 grid
tiles (41 − 4 app rows); gap window asserted at 320/360; the 412 value is
asserted as the documented number, not the window.

## Contrast

- **Glyph vs tile fill ≥ 3:1** for every registry accent, light **and** dark,
  across all ten palettes — asserted in `more_duotone_test.dart`. The ladder
  (`mix(c, black, .10→.40)` light, `mix(c, white, .10→.50)` dark) keeps the
  faintest passing step, so glyphs stay accent-colored, only darkened as far as
  the accent forces. The amber (0xFFD9922B) and sky-blue (0xFF2B7FD6) mockup
  accents are the hard cases and pass.
- **Label ≥ 4.5:1** is carried by `textPrimary` on the card surface — a theme
  guarantee, not a per-accent derivation any more (that is what removed
  `readableLabel`).

## Performance

No device is attached, so the `--profile` pass **was not run** — stated
explicitly rather than faked. The static recipe is the perf argument: flat
`Color`s only (no gradient shaders, no `Opacity`/`saveLayer`, no blur, no
shadows), the derivation memoized per `(accent, brightness, surface)` so the
grid never recomputes per frame, and the only per-second repaint on the page is
still the strip countdown inside its own `RepaintBoundary`. A device/profile
pass remains open.

## Removed code

- `MoreDuotone`: fields `tint`, `circle`, `squircleTop`, `squircleBottom`,
  `label`; `readableLabel()`; the gradient/gloss derivation (`_kFillAlpha`
  replaced by the Style-2 alpha set). Cache kept, now keyed on the same triple.
- `more_screen.dart`: `_DuotoneGrid` + `_DuotoneTile` (Style-1 glossy tiles),
  the `_kSquircle = 48` constant, and the kit `SettingRow` usage for utility
  rows (replaced by `_UtilityList`/`_UtilityRow`/`_Style2MiniTile` inside the
  page; the shared kit widget itself is untouched).
- Verified no references remain (`flutter analyze` — only two **pre-existing**
  warnings in `test/core/database/mock_daos.dart`: `getDhikrList`/`setDhikrList`
  overrides on methods `TasbihDao` no longer declares; present at the base
  commit, left for the tasbih session).

## Fixed on the way

- Prayer strip: the fixed 48dp strip overflowed by 1px at text scale 1.3 when a
  live clock renders it (the overflow-matrix tests never pass a clock, so this
  hid until the new live-strip golden at 1.3). The strip's second line is now
  `Flexible` — zero visual change at scale 1.0. Logic untouched.

## Tests

- `more_duotone_test.dart` rewritten: spec alphas (`0x24/0x2E/0x28/0x70`),
  glyph ladder clears 3:1 with the faintest step, per-accent × per-palette sweep
  (all 10 palettes), memoization identity, `moreTileSize` clamps including the
  widths the page actually produces (68.53 @320 — the card hairlines eat 1dp).
- `more_registry_test.dart`: split 6/6/10/3/12/4, ruqyah in قرآن و ادعیه,
  iconScale within 0.9–1.1 for all 41.
- `more_screen_test.dart`: utility rows asserted as 40dp mini squircles inside
  the card; new `style-2 metrics` group (tile squares + count, gap window at
  320/360, the documented 412 value, last-row START alignment for the 10-item
  hadith group, `Semantics` button contract); 41-item navigation sweep, strip,
  search and lock tests all green.
- Goldens re-recorded (15): full page at 412 × dawn/day/sunset/night, search +
  empty per kind, **new** full page at 320 and 360, and 360 @ text scale 1.3.
  The four empty-state goldens are byte-identical to before (they contain no
  tiles).
- Full suite + strict gate: see PROGRESS.md log for the final numbers.
