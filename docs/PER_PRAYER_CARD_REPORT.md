# The per-prayer adhan card (Design A) — `settings/per-prayer-card`

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


Branch landing report — 2026-10-17. Six commits rebased onto `release/1.8.0` @
`5041485` and fast-forward-merged:

| commit | subject |
| --- | --- |
| `7928729` | fix(settings): per-prayer adhan shifts reschedule like the other consumers |
| `383d51a` | feat(prayer): per-prayer azan voice overrides, prefs-backed |
| `c796341` | feat(design-system): opt-in style knobs for SettingsStepper |
| `3453d47` | fix(design-system): stepper value slot stays a loose minWidth-34 |
| `d5c19a8` | feat(prayer): the per-prayer adhan card (Design A) |
| `7b60014` | test(settings): re-record the two prayer-settings page baselines for the card |

## What the card is

`PrayerSettingsScreen`'s old «اذان و اقامه» list (one row per control, 15 rows)
became **five prayer blocks inside one card** (`PerPrayerAdhanCard` +
`PerPrayerBlock` in `lib/features/prayer/presentation/widgets/per_prayer_adhan_card.dart`).
Each block owns: a header (identity tile + prayer name + the adhan switch), one
status line, a voice chip, and two counters — «جابجایی اذان (دقیقه)» and
«تا اقامه (دقیقه)» — with a bulk row on top of the card: «صدا برای همه» /
«اقامه یکسان» / «بازنشانی» (+ «واگرد» snackbar).

## The a/c rule (the contract worth not breaking)

An OFF adhan dims **ONLY the voice chip**:

- the chip loses its accent (flat muted fill/border from `textMuted` alphas —
  never an `Opacity` widget), stops taking hits (`PopupMenuButton.enabled:
  false`), and its `Semantics` node carries `enabled: false` plus the
  `- غیرفعال` label variant; the stored sound key is **preserved**, never
  cleared;
- **the prayer name and the identity tile keep their ink at OFF** (the first
  cut muted them; the `all off` golden exposed it and it was reverted — the
  status line below is the only state voice: accent «پخش اذان فعال» vs muted
  «اذان خاموش · زمان و اقامه همچنان اعمال می‌شود»);
- the two counters stay **full-opacity accent** and fully editable at OFF, and
  they still RESCHEDULE the real alarms (`7928729` routes the per-prayer shift
  through the same debounced `_saveWith`/reschedule doors every other consumer
  uses). Pinned by the regression test «OFF leaves the times editable» +
  the shifted-times-while-off matrix combo.

## Layout modes

`LayoutBuilder` with two thresholds — 3 columns only when the stepper cell is
≥ 124 px **and** the chip cell ≥ 78 px (chip flex 1.15 : steppers 1 : 1, gap 6);
otherwise two rows (chip full-width, then both counters); below the twin
threshold everything stacks. 412 dp renders the 2-row mode (verified in
goldens — the same layout the app shipped elsewhere), 320 dp the 2-row mode,
and a 240 dp pump the stacked one.

## Sounds

Per-prayer sound keys live in `PrayerAzanSoundStore`
(`azan_sound_<slot>`, absent = inherit the global `azanSound`), a plain
`SharedPreferences` store — no Drift, no codegen. `alarmSoundFor` resolves
store → global → default for the whole alarm path, and the native scheduler's
settings fingerprint carries the five raw keys so a per-prayer voice change
re-arms the alarms. The notifier exposes `setAzanSoundFor / clearAzanSoundFor /
setEnabledAt / setShiftAt / setIqamahAt / setIqamahOffsetsUniform /
resetPrayerAdhanSection` — all full settings saves with alarm rescheduling via
the existing doors; nothing bypasses `SettingsNotifier`.

**Bulk operations snapshot BEFORE the write** (the first cut snapshotted after
— the undo then restored the new state; caught by the «واگرد» test). «بازنشانی»
never touches toggles or the global sound.

## The stepper knobs and the landmine they left

`c796341` style-knobbed `SettingsStepper` (height / radius / glyphSize /
valueFontSize / fillColor / borderColor / borderWidth / expand) with every
default equal to the shipped kit look. The first cut handed the value slot a
**tight width 34** where the old pill had a **loose minWidth 34** — a wide
value (the «۳۰ دقیقه» row on the main settings page) wrapped inside the pill
and the main-settings day golden drifted 0.16 % (1413 px in a 31-row × 96-col
band). `3453d47` restores the loose slot.

**Do not tighten a stepper value slot again** — wide values must grow the pill.
The golden pair (base `48a7b39` vs the branch) was diffed per-pixel to localize
that band; the main-page baselines did not need re-recording (bit-identical
after the fix).

## Test seams worth knowing

- `per_prayer_card_pump.dart::pumpCard` — the card stand-alone harness. It
  watches `settingsProvider` inside a `_CardHost` exactly like the screen does
  so writes are reflected, wraps the card in a `SingleChildScrollView` (a real
  1 px vertical overflow at 800 dp, where the card is ~1180 px tall — vertical
  scroll keeps the width tight), and captures goldens through a
  `RepaintBoundary(key: ValueKey('golden-card'))` (the repo's per-card golden
  rule). Text scale is driven by **theme `bodyMedium` × scale** — that is what
  `AppTheme.scaledFontSize` reads — not `MediaQuery.textScaler`.
- Chip semantics are asserted at the **widget level**
  (`Semantics.properties.label`); the semantics tree merges the inner
  `PopupMenuButton.tooltip`, so tree-level exact matches fail.
- The notifier debounces saves ~350 ms; every tap test pumps ~500 ms before it
  asserts so no orphan timer outlives the test.
- Chips render `shortLabel(soundKey)`; default `azanSound` is `'takbir'`, so
  tests asserting popup-only strings pass `azanSound: 'kamel'` to make
  «تکبیر» a popup-only marker. `find.byType(PopupMenuButton<Object>)` targets
  the bulk menus, `PopupMenuButton<String>` the per-block chips.

## Proof

- Card tests 10/10 (skeleton, unit matrix 4 combos, clamping, the OFF-editable
  regression, one-ON-among-dimmed, the 3 layout modes, toggle-ON re-enable,
  bulk uniform + sound-all, bulk reset + undo ordering), screen tests 16/16
  (incl. the 320/412 × 1.0/1.3 no-overflow matrix), card goldens 6/6
  (`on` / `one_off` / `all_off` / `two_row` @ 320 / `scale13` / `night` — the
  OFF states pin that ONLY the chip mutes while the counters keep the accent).
- Prayer scope 411/411; settings scope green including the two re-recorded
  page baselines (`prayer_settings_day/night`) — re-recorded per-file, never
  whole-file.
- `flutter analyze lib test` 0 issues; `quality_check.py --strict` 7/7;
  `design_consistency.py` OK (no budget moved); encoding guard 2/2.
- Not built here beyond the release-compile check recorded at merge time — no
  on-device verdict has been requested for this card yet.
