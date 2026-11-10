# Home-screen widgets — Glance migration report

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


Status: **release/1.8.0**, branch tip `release/1.8.0`, widgets live on
`PrayerWidget` (prayer times) and `TasbihGlanceWidgetReceiver` (tasbih).
This document is the current truth; `WIDGETS_THEMING_REPORT.md` is kept for its
palette/contrast history and is **superseded** wherever the two disagree.

> **Brief amendment (2026-11-01, at the user's request).** The "Performance vs
> baseline" section no longer carries an escape hatch. The sentence
> «recommendation (hybrid: keep AndroidRemoteViews for the whole prayer widget)
> instead of shipping a regression» is **removed from the brief**: the move to
> Glance is final and is not to be re-litigated on performance grounds. The
> prayer card stays a Glance composition; the tasbih card stays hand-built
> RemoteViews for the reason in §2 (correctness, not performance).

---

## 1. What the two cards are

| | Prayer times (4×2) | Tasbih (4×3) |
| --- | --- | --- |
| Renderer | `PrayerGlanceWidget` (Jetpack Glance 1.2.0) | `TasbihNativeViews` (hand-built `RemoteViews`) |
| State | `PrayerWidgetModel` read from the app snapshot | `TasbihWidgetModel` + `TasbihTapEngine` queue |
| Update | alarm at each adhan, midnight, 6 h watchdog, app push | tap → `partiallyUpdateAppWidget`; app push |
| Bitmaps | `WidgetArt.surface` (gradient), progress pill | `WidgetArt.surface`, `WidgetArt.ring`, icons |

The Flutter engine is never started by either widget. `updatePeriodMillis = 0`
on both providers; nothing polls.

## 2. Where this deviates from the brief, and why

Three deviations are deliberate and are recorded here rather than silently
"fixed" back:

1. **No `TextClock`, no `Chronometer`.** The brief asked for both, ticking
   inside the launcher through `AndroidRemoteViews`. They were built and then
   removed at the user's explicit request (2026-10-29: «تیک زدن اوقات را کاملا
   حذف کنید زیرا خیلی ضعیف عمل میکند»). Measured reason: the leaves formatted
   with the *launcher's* locale, disagreed with the app's own 12/24-hour choice
   on this host, and after a host-side refresh could sit a whole minute away
   from the baked text. The clock and the countdown are now **baked strings**
   (`WidgetFormatting.formatClockTime` / `formatCountdownMinutes`, both pinned
   to `Locale.US`), re-baked by the receiver's minute tick and at every alarm
   point. `widget_live_clock.xml` and `widget_live_countdown.xml` were deleted.
2. **The tasbih card is not a Glance composition.** A counter must repaint on
   every bead, and on the test device (POCO X7 Pro, Android 16, HyperOS) a
   Glance widget composes **once per process**: `GlanceAppWidget.update()`
   against an open session re-applies the cached tree and never calls
   `provideGlance`. Measured with a `compose` log: four taps, four paints, one
   composition, and the card sat on the first tap's number. The card is
   therefore hand-built `RemoteViews` + `partiallyUpdateAppWidget` (a merge, no
   re-inflation). This is a correctness fix, not a performance retreat.
3. **The palette set differs from the brief's table.** `assets/widget_palettes.json`
   ships `brown_gold` (default), `night_blue`, `emerald`, `dawn_purple`,
   `sunset`, `graphite`, `cream_light`, `gold`, `auto` — with the hexes the
   theming work landed, not the brief's hexes (`emerald` is `#1B4332`, not
   `#0F6150`; there is no `royal_blue`). Aligning the table with the brief's
   approved swatches is an **open item** (§6) because it repaints every
   installed widget and the user is currently on the shipped set.

## 3. Geometry fixes — 2026-11-01

Device screenshots (POCO X7 Pro, 1220×2712, density 3.25, cell 243×269 dp)
showed the tasbih card wrong in two ways that the unit tests could not see:

- **The ring was a bead.** `WidgetArt.ring` capped the bitmap at 256
  **pixels**, and because the `ImageView` is `wrap_content` the bitmap *is* the
  view: 256 px on a 3.25× screen is a 79 dp ring in a 119 dp box, and the
  count (sized from the same number) spilled over the arc. Measured from the
  screenshot: the track's outer diameter was 116 px ≈ 36 dp.
  The cap is now a **density** cap — `min(density, 2.5)` with an absolute
  ceiling of 512 px (`WidgetArt.RING_MAX_DENSITY` / `RING_MAX_PX`) — so a
  119 dp box asks for ~298 px (~355 KB) and the ring fills its box.
- **The three buttons were lozenges.** Each was `layout_weight=1` in a
  `match_parent` row, i.e. a third of the card (~74×44 dp) with a 14 dp corner
  radius. They are now three 44 dp circles (`widget_tasbih_chip` is an oval)
  centred with 18 dp between them, inside 48 dp tap targets.

Both changes are in `widget_tasbih_native.xml`, `WidgetArt.kt` and
`TasbihNativeViews.kt`. The release APK builds clean (`flutter build apk
--release`, 50.5 MB). **Device verification of this pair is pending**: the
handset dropped off adb before the build finished, so the post-fix screenshot
has not been taken. The pre-fix screenshots are in
`.design-shots/verify/` (`home1.png`, `prayer_crop.png`, `tasbih_crop.png`).

## 4. Problems checklist

| Item | State | Evidence |
| --- | --- | --- |
| Clock lags / falls behind | fixed by removal of the ticking leaves; baked string + minute tick | `PrayerWidget` `rearmAll` arms the minute tick unconditionally |
| Countdown = next **adhan**, never iqama | yes | `PrayerWidgetModel.countdown.targetAtMillis` from the adhan table |
| Highlight flips exactly at the adhan | yes | boundary alarm re-renders; `nextIndex` recomputed per render |
| Isha → tomorrow's Fajr | yes | `PrayerWidgetBudget`/model unit tests |
| Tasbih counts past the goal | yes, with the «بعد از رسیدن به هدف» setting | `TasbihWidgetModel.laps`, `afterGoal` |
| Ring concentric with the count | yes by construction (one Box, `Alignment.Center`) | layout |
| Ring fills its box | **fixed 2026-11-01**, awaiting device shot | §3 |
| Tap anywhere on the card counts | yes | listener moved to `tasbih_root` |
| Reset confirm window | yes | `TasbihTapEngine.isConfirming` |
| Survives reboot / package replace / force-stop | yes | `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`, watchdog |
| No "Can't load widget" | yes | composition wrapped, fallback layout + `widget_placeholder_*` |
| No per-second refresh | yes | `updatePeriodMillis=0`, no polling, minute tick only |
| RTL / LTR-isolated digits | yes | `supportsRtl`, `tnum`, Latin-only formatters |
| Prayer widget uses the app font (Calibri) | **not possible in Glance** | `androidx.glance.text.FontFamily(String)` takes a system family name only; the bundled font cannot be referenced. The tasbih card (native) does use `@font/calibri`. |

## 5. Performance notes

- Full render = one surface bitmap (painted at half density) + one ring bitmap
  + three 18 dp icons, all cached by input in an 8-entry LRU.
- A tap sends `partiallyUpdateAppWidget` with the changed setters only; the
  surface never crosses the binder on a bead.
- Ring progress is quantised to 1 %, so most beads reuse the previous bitmap.
- Alarms: the adhan boundary set, local midnight, a 6 h watchdog. Nothing else.

## 6. Open items

1. **Palette table vs the brief's swatches** (§2.3) — decide whether to
   re-swatch `emerald` to `#0F6150 → #07372E` with `#E8C277` accent and add
   `royal_blue`, then regenerate the drawables
   (`dart run tool/widget_palette_generator.dart`) and re-shoot the matrix.
2. **Device verification of §3** — install the current APK, screenshot both
   cards, measure the ring diameter against the 119 dp box.
3. **Persian digits in the baked clock/countdown.** On the test device the
   clock and the countdown render Persian numerals while the prayer times and
   the dates (formatted on the Flutter side) render Latin ones. The Kotlin
   formatters pin `Locale.US`, so the strings are ASCII; the substitution
   therefore happens at render time, and it does **not** affect the same font
   at 13.5 sp. Root cause not yet established — see §7.
4. APK-size delta and p50/p95 update times are **not measured** in this
   session; the last measured numbers live in `WIDGETS_MIGRATION_2026-10-26.md`.

## 7. Notes for the next session

- `dumpsys appwidget` on Android 16 no longer prints `appWidgetId=` blocks in
  the old format; `adb logcat -s TasbihNativeViews` prints the computed cell,
  scale, box and ring size on every render — use that instead.
- The launcher caches the last applied `RemoteViews` across a launcher restart,
  so a code change that alters the *layout* only shows up after a fresh full
  render (`APPWIDGET_UPDATE` from the app, or a resize).


---

## 2026-11 rebuild — the approved designs on `widgets/glance-final`

Branch `widgets/glance-final` (branched from the personal2 line where the
first slices already lived). The brief's four problems:

- **P1 — the clock lagged.** Root cause: the Glance card baked both values as
  strings and moved them with the receiver's minute tick, which Doze
  throttles (exact alarms denied by default from Android 14). Fix: the two
  values are LIVE leaves again, hosted through `AndroidRemoteViews` — a
  `TextClock` (12/24 h travels as its format strings, the other cleared so
  the system mode cannot override; `android:textLocale` pins Latin digits,
  with a `_fa` layout variant behind `widget_fa_digits`) and a count-down
  `Chronometer` re-based at every render from the next-ADHAN target and
  clamped so a late render never runs up. The boundary alarm at each adhan
  re-renders it; the minute tick stays only as the baked parts' backstop.
- **P2 — the approved prayer design.** The card is Version 2: crescent +
  weekday and the location chip, the live clock, ONE muted date line
  (Gregorian half droppable), five state-filled capsules (NEXT = the
  generated `widget_prayer_next_<palette>` fill with `onNext` ink; PAST =
  the faintest neutral, 55 % dim; others = mid neutral), and a 34 dp
  progress pill (cached bitmap, fill from the RTL start edge, 2.5 % steps)
  carrying the caption and the live countdown. Fills are generated shape
  drawables, so corners survive below API 31. The «خواندم» mark taps stay.
- **P3 — the tasbih keeps counting.** The engine's default flipped to
  «ادامه شمارش» (`tasbih_auto_advance=false`); laps derive as
  count/goal, and the badge speaks them: «از 100» → «+3 · دور 2» →
  «✓ دور 1 کامل». The main ring clamps full gold at the goal; a new outer
  ring (3 dp, palette `outerRing`) carries the lap's share. The opt-in
  «رفتن به ذکر بعدی» is a settings-page switch.
- **P4 — the ring is concentric.** The layout puts the count and the badge
  in ONE centered group inside the ring square; the old check icon that
  pushed the count off-centre is deleted. Fixed 8 dp vertical rhythm.

Theming: `widget_palettes.json` v2 — every preset carries the brief's
`prayer.*` / `tasbih.*` tokens with the exact values; defaults are
per-widget (prayer → زمردی, tasbih → شب آبی); the auto mapping follows the
brief's phases; the retired «طلایی» resolves to قهوه‌ای طلایی. The
generator also emits the per-palette next/badge fills and the shared
neutral families (capsule/circle/pill × white/black).

Settings page: the new switches (progress bar, Gregorian date, after-goal
behavior) write the contract keys and push the snapshot, so a placed
widget repaints within a second.

Verification: Kotlin compiles at every commit; 105 widget JVM tests green
(incl. the rewritten lap/tap-path tests and a chronometer-free boundary
suite); the settings-screen tests updated to the v2 palette values and
green. **Pending-device**: tap-to-render latency, Doze lag verification,
battery/alarm wakeups, APK delta, and the visual matrix (no device was
attached to this session; the numbers stay honest blanks instead of
estimates). The on-device checklist from §Problems remains the
acceptance gate.
