# widgets/glance-final — findings and plan

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


Scope: the brief (2026-11-03) — rebuild the prayer (4×2) and tasbih (4×3) widgets on
Glance in the approved designs, with the user-selectable theming system, fixing
P1–P4. This file is the short findings + plan the brief asks for; the full
architecture report stays in `docs/GLANCE_WIDGETS_REPORT.md`.

## Findings (what already exists, measured against the brief)

1. **State of the two cards.** The prayer card IS Glance
   (`PrayerGlanceWidget`, SizeMode.Exact). The tasbih card is NOT: after a
   measured Glance bug (a tap session composed once per process and never
   repainted), it was rebuilt as a hand-written RemoteViews card
   (`TasbihNativeViews` + `widget_tasbih_native.xml`) with
   `partiallyUpdateAppWidget` merges — the exact architecture the brief's
   §5 contingency prescribes for taps. It already: broadcasts to a
   receiver with `goAsync()`, coalesces nothing (one partial render per
   tap, all under a few ms), keeps the append-only pending queue
   (`widget_tasbih_pending` + seq, collapse at 300), has a confirm-reset
   state machine, prev/next with wraparound, and a 6 h watchdog + local
   midnight reset.
2. **P1 root cause confirmed.** The Glance clock/countdown are BAKED
   STRINGS (`formatClockTime` / `minuteElapsed`), re-baked by the receiver's
   minute tick (`ACTION_MINUTE_REFRESH`, setExactAndAllowWhileIdle at the
   next minute boundary + a repeating inexact backstop). In Doze the exact
   grant is denied by default on Android 14 → the baked clock lags. The
   brief's fix (AndroidRemoteViews hosting TextClock/Chronometer) removes
   the dependency on any tick for the two values that must never lag.
3. **Refresh points already correct** (`PrayerWidget.rearmAll`): boundary
   alarms at every adhan + local midnight, time/timezone/date listeners,
   package-replaced, 15-min inexact backstop for the progress line,
   `updatePeriodMillis = 0`. Countdown target = next ADHAN
   (`computeCountdown`, never iqamah — the iqamah phase only renames the
   caption). No new scheduler needed.
4. **Theming system already exists** from the 1.8.0 work:
   `assets/widget_palettes.json` → `WidgetTheme` (per-widget palette +
   opacity keys, legacy migration, auto-by-phase) → generated gradient
   drawables via `tool/widget_palette_generator.dart`; the Flutter
   settings page (widget_settings_screen.dart) already previews and picks
   palettes/opacity. What the brief adds: per-widget TOKEN SETS
   (nextFill/onNext/muted/accentLight/ring/badge/btn…), the 8 concrete
   presets with the brief's exact values, and «خودکار» per-widget-type
   default (prayer→زمردی, tasbih→شب آبی).
5. **P3 partially started before this branch** (carried as the first
   commit): `tasbih_auto_advance` default flipped to false
   («ادامه شمارش»), the flag threaded through snapshot → repo → prefs,
   plus the two prayer display flags. What remains: laps/inLap state, the
   badge «+3 · دور 2» / «✓ دور 1 کامل», the outer lap ring, the app-side
   setting row, and the ring bitmap rework.
6. **P4 root cause confirmed.** In `widget_tasbih_native.xml` the count
   lives in a vertical LinearLayout inside the ring box, so the 14 dp
   check icon shifts it off-centre when visible, and the ring area is a
   `layout_weight=1` box — the ring floats in leftover space instead of a
   fixed square, which is the «empty gap». The brief's layout (fixed 176 dp
   square, one Box, Alignment.Center) is the fix.
7. **Contract** (`docs/WIDGET_DATA.md`, widget_snapshot.dart) already
   carries: times (today+tomorrow fajr), pre-formatted strings, statuses,
   city, dates, 12/24h + digits, tasbih list/count/targets/total, pending
   queue, themes. Missing for the brief: per-zikr totals already exist;
   laps are derivable natively; the new setting is now in the contract.

## Baseline (honest note)

No device is attached to this session (Samsung A13/A32-class and the
POCO X7 Pro reports all come from prior sessions' logs). Baseline
update-time/memory/battery numbers and the on-device tap-latency median
cannot be re-measured here; the report will carry the previous session's
measured numbers where they exist (Glance compose-once bug, ring px caps)
and mark the rest `pending-device`. APK delta will be reported from the
release build size. Per the brief's edit, the hybrid-fallback clause is
removed: the Glance migration stays.

## Plan

1. **C1 (done)** — carry the in-flight WIP as the brief's first slice.
2. **C2** — this plan.
3. **C3 (P1)** — hybrid leaves: `widget_prayer_clock.xml` (+ `_fa`) with a
   TextClock (format12/24 from the setting, `android:textLocale` per
   variant, palette color/size via RemoteViews setters, click → app), and
   `widget_prayer_countdown.xml` with a Chronometer
   (`setChronometerCountDown(true)`, base = elapsedRealtime + (target −
   now), format `%s`), composed via `AndroidRemoteViews`; the minute tick
   stays as the backstop for the baked date/labels, not for the clock.
4. **C4 (P2)** — prayer card redesign to approved «Version 2»: emerald
   capsule row (icon holder + name + time; past/next/others fills), date
   line, TextClock row, progress pill (bitmap track+fill, 2.5 % steps) with
   the caption + Chronometer inside; palette JSON gains the brief's token
   sets and 8 presets with the new values; generator re-run;
   `WidgetTheme.parseSpec` learns the new tokens.
5. **C5 (P3+P4)** — tasbih: approved «Design 1» layout (fixed ring square,
   concentric count, chips row, badge states, 44 dp controls with 18 dp
   gap), ring bitmap with inner disc + gold gradient arc + outer lap ring,
   unbounded per-zikr totals with laps/inLap + badge texts, gold full ring
   at goal, strong haptic at the goal, «بعد از رسیدن به هدف» honoured in
   widget AND app.
6. **C6** — settings page: the new switches («بعد از رسیدن به هدف»,
   «لرزش هنگام شمارش», «نمایش نوار پیشرفت», «نمایش تاریخ میلادی») wired to
   the snapshot push.
7. **C7** — docs (`WIDGET_DATA.md`, `GLANCE_WIDGETS_REPORT.md`),
   PROGRESS.md, tests: lap logic, theme token resolution, contract
   round-trip, generator determinism.

## Non-goals this pass

- On-device matrix + baseline numbers (no device) — marked pending-device
  in the report.
- The 2×2 tasbih mini (does not exist today; the brief only asks for it if
  it does).

## Status after this session (handoff)

Landed on `widgets/glance-final`:
1. `d522773` — carried WIP (display flags + after-goal default flip).
2. `60bf6c9` — this plan.
3. `beea4f4` — **P1 done**: TextClock/Chronometer leaves hosted via
   AndroidRemoteViews (`PrayerRemoteLeaves`, three layouts, fa-digit
   variant behind `widget_fa_digits`), re-based per render, boundary
   alarm keeps the countdown off negative.
4. `bd3bd8d` — the palette table v2: per-widget tokens on every preset
   with the brief's exact values, per-widget defaults
   (prayer→زمردی, tasbih→شب آبی), auto-phase remap, `gold`→`brown_gold`
   alias, generator emits `widget_prayer_next_<id>` /
   `widget_tasbih_badge_<id>` + the shared neutral families
   (capsule/circle/pill × w/b), `WidgetTheme.Resolved.token()`.

Remaining (all building blocks in place):
- **P2 composition**: rewrite `PrayerGlanceWidget` to the approved
  «Version 2» — capsule row using `widget_prayer_next_<id>` + neutral
  capsules via `WidgetTheme.neutralFill`-style resolution (light presets
  take the b-family), date line joined from the three stored strings,
  34 dp progress pill as a `WidgetArt` bitmap (track w@12, fill
  accent@32 from the RTL start edge, 2.5 % steps, LRU ≤ 8) with the
  caption and the live Chronometer inside, crescent + pin glyphs, whole
  card tap → app. Budget keeps pricing bands.
- **P3**: tasbih laps — unbounded per-zikr totals exist; add
  lapsCompleted/inLap to `TasbihWidgetModel`, the badge texts
  («از 100» / «+3 · دور 2» / «✓ دور 1 کامل»), the outer lap ring in
  `WidgetArt.ring`, the goal haptic, and the app-side setting row
  (engine default + contract flag already committed).
- **P4**: `widget_tasbih_native.xml` — fixed 176 dp ring square
  (`wrap_content` → fixed box), the count in ONE center-aligned Box with
  the bitmap (the check icon must not shift it), chips row spacing 8 dp.
- **Settings page**: the four switches (after-goal, tap haptic, progress
  bar, Gregorian date) — the snapshot/contract side is committed; the
  page rows are not.
- **Tests/report**: lap-logic + token-resolution JVM tests, contract
  round-trip, generator determinism check, `WIDGET_DATA.md` +
  `GLANCE_WIDGETS_REPORT.md` updates, on-device matrix pending-device.

Kotlin compiles at every commit; nothing on the branch is verified on a
device yet.
