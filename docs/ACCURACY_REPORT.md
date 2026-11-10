# Tawheed — Accuracy report

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


Companion to `docs/AUDIT_REPORT.md` (findings C-*, D-*, E-*, J-*). Every
religious / astronomical computation the user acts on, how it is verified, and its
error bounds. Branch `release/1.7.2` (worktree `%TEMP%/opencode/merge-172`).
Full suite at time of writing: **3341 passed, 9 skipped** (incl. 257 prayer tests).

**Verification principle:** correctness is checked against **independent
references** — a from-scratch NOAA solar solver, published new-moon catalogs,
Meeus worked examples, and closed-form solar noon — **never against the app
itself**.

---

## 1. Prayer times

- **Engine:** `package:adhan ^2.0.0` (Meeus solar model), always with a **per-date
  UTC offset** (`prayer_repository_impl.dart:139-140, 335-337`). Fully offline —
  no prayer-times API exists anywhere.
- **Methods** (`_getCalculationParams:612-664`): MWL, Karachi, Umm al-Qura,
  Egyptian, Tehran, Turkey, Dubai, Kuwait, Qatar, Singapore, ISNA,
  MoonSightingCommittee, and **custom** (raw fajr/isha angles, defaults 18°/17°).
- **Asr:** `AsrMethod { hanafi, shafi }` → adhan shadow ratio 1 vs 2; the Shafi'i
  label covers Jumhur (مالکی/حنبلی) (`app_settings_options.dart:86-97`).
- **High-latitude rules** (`:645-652`): middle-of-night / one-seventh / angle-based
  (twilight). Default middle-of-night.
- **Maghrib:** Tehran method carries a **fixed `maghribAngle = 4.5°`** (it is *not*
  a visual sunset); Umm al-Qura/Qatar use `ishaInterval: 90`.
- **Elevation correction** (opt-in): a second pass that re-solves only the *visual*
  horizon events (sunrise/maghrib) against the dipped horizon
  (`elevation_correction.dart`); user minute-offsets are **added to** the dip delta,
  never replaced.
- **Timezone:** `_resolveZone:297-319` honours `settings.timezone` (real Olson id),
  falls back to the device numeric offset (not hard Tehran) on an invalid id; the
  per-date DST offset is anchored at **local noon** (`offsetForDate:821-831` — a
  02:00 changeover like Sydney's would otherwise pick the wrong day's offset).

### Tests (against the NOAA solver, `noaa_solar_reference.dart`)
- `prayer_reference_table_test.dart` — 3 sites (Mecca/Tehran/Istanbul, cap ≤41° so
  fajr/isha always exist) × 4 equinox/solstice dates 2026, all 6 events, tol 3-4 min.
- `prayer_worldwide_times_test.dart` (~8) — Dhuhr vs closed-form solar noon for
  **every** `PlaceIndex` city at both solstices under LMT; ordering via
  `difference().inSeconds` (not hour-of-day); day-length sanity band; high-lat rules
  for 4 polar cities (definedness/ordering only); southern-hemisphere symmetry;
  per-date UTC-offset regression.
- `prayer_realzone_reference_test.dart` (~18) — offset table incl. quarter-hour
  zones (Kabul +4:30, Kathmandu +5:45, Chatham +13:45/+12:45, noon-anchored
  changeover) + 6 cities × 15 combos + DST-jump (Sydney/LA dhuhr shift exactly
  +60 min).
- `prayer_timezone_resolution_test.dart` (9) — Tehran stable +3:30, foreign zones
  never pinned to Tehran, invalid non-Olson ids fall back without throwing, Dubai
  vs Tehran dhuhr differ by **exactly 30 min** for identical coords/date.
- `prayer_golden_times_test.dart` — wide-window sanity; Stockholm 59.33°N proves
  the high-lat setting moves fajr/isha >30 min.

### Fixes this phase
- **C-2 (P1, `9137c6f`)**: elevation correction no longer re-solves the
  angle-defined **Tehran Maghrib** to geometric sunset — regression test asserts
  `maghribAngle==4.5`, `maghribMinutes==0`, sunrise still corrected, and a *visual*
  Maghrib method yields non-zero. 10 tests in `elevation_correction_test.dart`.
- **C-4 (P2, `b9f377d` + `359b8ef`)**: place-name normalization folds
  ي↔ی, ك↔ک, harakat/tajweed marks, ZWNJ/tatweel and Arabic-Indic/Persian digits.

## 2. Qibla

- **Bearing:** custom great-circle initial bearing to the Kaaba (21.4225, 39.8262)
  via `atan2` (`qibla_math.dart:40-49`), haversine distance `:52-64`.
- **Magnetic→true:** `applyMagneticDeclination` using Android `GeomagneticField`
  (WMM) via MethodChannel (`magnetic_declination_service.dart`).
- **E-2 (P1, `e0202a3`)**: `calculateDeclination` now returns `Future<double?>` —
  `null` on `PlatformException`/`MissingPluginException` so callers distinguish a
  genuine 0° from "no value" (up to ~20° error). UI shows a "compass approximate"
  banner on null; heading conversion applies declination only when a value exists.
  5 tests in `magnetic_declination_service_test.dart`.
- Verified by `qibla_math_test.dart` (29): known bearings Tehran ~218°, NY ~58°,
  Sydney ~277°; solar shadow-clock Qibla moments use a NOAA-style `_solarPosition`
  (replaced a Spencer formula whose ~0.35° declination error shifted moments ~1
  min); Polaris via proper GMST LST (old day-fraction approx drifted ~1.8°).

## 3. Calendars (Hijri / Jalali)

- **DST-safe day arithmetic** (`calendar_days.dart`): `calendarDaysBetween` counts
  via **UTC dates** so a 23-hour DST month measures 30, not 29.96→29.
  - **D-2 (P1, `5e2cacf`)**: astronomical Hijri `dayInMonth`/`monthLength` migrated
    off `difference().inDays` (`astronomical_hijri.dart:62-67`).
  - **J-2 (P2, `3d3efa5`)**: khatm `dailyTarget` counts calendar days, not elapsed
    hours (`khatm_model.dart:72-76`) — 4 regression tests.
- **Two coexisting bases** (the pending D-3 decision):
  - **Tabular** `HijriUtils` — odd months 30 / even 29, 30-year leap cycle
    `(11y+3)//30`, user `offset` applied; Ayam al-Bidh off the *displayed* day.
  - **Computed-astronomical** `AstronomicalHijri` — true new moon (Meeus ch.49),
    new Hijri day starts at sunset of the conjunction day, `monthLength.clamp(29,30)`.
  Default `hijriOffset = 2` days.
- Verified by `calendar_days_test.dart`: month boundaries anchored to
  **Fred Espenak/NASA new-moon catalog** (2024-12-30 22:27 UT, 2025-01-29 12:36 UT);
  `dayInMonth == calendarDaysBetween(monthStart)+1` over 200 days; month length
  stable across every day.

## 4. Moon & mansions (منازل) — reviewed, accurate, DO NOT "simplify"

Confirmed in the prior moon review (`AGENTS.md:85-88`); no regression found.
- **Mansions** (`lunar_calculator.dart:98-132`): Meeus ch.47 ecliptic longitude with
  **precession correction** (0.0139647°/yr ≈ 50.36″/yr) — houses are tied to fixed
  stars, not the drifting equinox; without it they'd have slipped ~20° (≈1.5 manzil)
  over 14 centuries. Anchor 27° (β/γ Aries), 28 houses of 360/28 = 12.857°.
  `currentManzil` evaluated at **20:15 tonight**, not page-open time.
- **Phases/illumination**: Meeus ch.49 true new moon; illumination
  `(1−cos sep)/2` (sign bug fixed); eclipses ch.54/55.
- **Hilal visibility** (`hilal_visibility.dart`): **Yallop TN69**, **Odeh 2006
  (ICOP)**, **Bruin 1977**, Danjon elongation floor ~7°, refraction applied.
- **Chart clip** (`hilal_sky_panel.dart:115-123`): fl_chart 0.70.2 defaults
  `FlClipData.none()`; the sunset→moonset sweep drops the sun past `minY:-10`, so
  `clipData: const FlClipData.all()` is required — do not remove.
- Verified by `lunar_calculator_test.dart`: NASA/JPL new-moon catalog 2024-2026
  (moon-age error <0.5 d, conjunction within <2 h of real); Meeus Example 47.a
  (1992-04-12) reproduced λ=133.167265° ±0.002, distance ±1 km; full-moon illum
  >95%, quarters 40-60%.

## 5. Needs religious / product decision (flagged, NOT changed)

- **C-1** 7 ecosystem methods missing from the picker (Gulf, Morocco, Tunisia,
  Algeria, France/Grand Mosque, …) and no nearest-latitude "no valid time" fallback.
- **C-5** Umm al-Qura **Ramadan Isha** uses the standard angle, not the fixed
  ~90-min-after-maghrib convention of official Gulf timetables.
- **D-3** Which Hijri basis (astronomical vs Umm al-Qura table vs civil+offset) is
  authoritative **per feature** — currently inconsistent.
- **D-5** Commemorative events are a fixed bundled table, not configurable by
  madhhab/tradition.
- **J-1** Zakat livestock Hanafi age-bands are applied to all schools
  (over-taxes Shafi'i/Maliki/Hanbali) — **fiqh output correctness**, needs scholarly
  input; code untouched.

See `docs/ROADMAP.md` for the proposals; none are started.
