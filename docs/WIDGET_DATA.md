# Widget data contract

Everything the home-screen widgets need travels over one method channel and
one `SharedPreferences` file. This document is the single description of
both; the code that implements each side is named in every row.

## Channel: `com.tawheeed/widgets`

Dart side: `lib/features/home/services/widget_bridge.dart` (`WidgetBridge`).
Kotlin side: `android/.../MainActivity.kt` `setMethodCallHandler`.

| method | direction | payload | notes |
| --- | --- | --- | --- |
| `syncWidget` | app → native | full `WidgetSnapshot.toMethodChannel()` map | everything both widgets render; also carries the native self-refresh inputs (`calc*`) and `azkarHaptic` |
| `updateTasbihWidget` | app → native | dhikr, count, target, isActive, zikrIndex, zikrId | lightweight tasbih-only push from the counter UI |
| `getTasbihData` | app → native | — | returns the tasbih state **plus** `pendingEvents` + `pendingSeq` (the tap-event queue below) |
| `drainTasbihEvents` | app → native | `appliedSeq: int` | native prunes queue entries with `s <= appliedSeq` |
| `setWidgetTheme` | app → native | `paletteId: String`, `opacityStep: int` | persists the selection (`auto` = خودکار) and re-renders every widget |
| `getWidgetTheme` | app → native | — | `{paletteId: String?, opacityStep: int (-1 before first save)}` — what the settings page opens on |
| `requestPinWidget` | app → native | `widgetType: 'prayer' \| 'tasbih'` | `AppWidgetManager.requestPinAppWidget` (API ≥ 26; false below) |
| *(snapshot fields, 2026-11 brief)* | app → native | `tasbihAutoAdvance: bool`, `widgetShowProgress: bool`, `widgetShowGregorian: bool` | carried inside `syncWidget`'s map; persisted by `WidgetRepository` into `tasbih_auto_advance` / `widget_show_progress` / `widget_show_gregorian` and read by the tap engine / prayer composition |

The app never starts the Flutter engine from the widget side. The widget
never invokes Dart.

## Prefs file: `tawheeed_widgets`

Written by `WidgetRepository.persistSnapshot` / the tap pipeline; read by
`PrayerWidgetViews`, `TasbihGlanceWidget` and `WidgetTheme`.

- **Prayer/data**: `next_prayer_name/minutes/time`, `next_prayer_iqamah_offset`,
  `iqamah_offsets`, `prayer_1..5`, `sunrise`, `sunset`, `shamsi_date`,
  `gregorian_date`, `hijri_date`, `city_name`, `azan_sound`,
  `widget_use_12_hour`, `widget_calendar_events`, `timeline_*`, `current_prayer_name`
- **Native self-refresh**: `calc_lat/lng/method/fajr_angle/isha_angle/maghrib_angle/
  isha_interval/madhab/high_latitude/method_adj/user_adj/timezone/elevation_adj/hijri_offset`
  + `widget_times_date` (the recompute trigger — the native side recomputes when
  it stops matching today)
- **Tasbih**: `tasbih_dhikr/count/target/active`, `tasbih_zikr_index`,
  `tasbih_zikr_list`, `tasbih_per_zikr_targets`, `tasbih_per_zikr_counts`,
  `tasbih_auto_reset`, `widget_tasbih_daily_total/date`,
  `widget_tasbih_last_tap_at`, `widget_tasbih_last_active_date`
- **Theme**: `widget_palette_id` (preset id or `auto`), `widget_opacity_step`
  (index into `opacitySteps` in `assets/widget_palettes.json`)
- **Haptics**: `azkar_haptic` — the app's «لرزش» toggle; the widget vibrates a
  20 ms tick on increment/reset-confirm only while it is true
- **Legacy (read-only, migrated once)**: `widget_bg_color`, `widget_opacity`.
  On the first `WidgetTheme.resolve` with no stored palette id the closest
  preset (exact bg match → nearest same-lightness) and the nearest opacity
  step are persisted, so app and widgets always agree. The renderer
  corner radius is `WidgetTheme.CORNER_RADIUS_DP` (22) — the same value the
  generated skin drawables and the Flutter preview
  (`WidgetTokens.widgetRadius`) use; the generator reads the constant instead
  of hardcoding a radius, so the three cannot drift.

## Tap-event queue (tasbih widget → app)

Append-only, seq-numbered, drained by the app's sync — never a live callback.

- Event JSON in `widget_tasbih_pending`, one row per tap:
  `{s: seq, k: 'inc'|'reset'|'zikr'|'full', z: zikrIndex, d: delta?, c: counts?}`
  (`d` on `inc`, `c` on `full`; `z: -1` on reset = reset **all** zikr).
- `widget_tasbih_pending_seq` is the highest seq ever issued.
- If the queue outgrows 300 undrained entries it collapses into a single
  `full` event carrying the committed per-zikr counts (idempotent superset
  of every dropped row).
- The app drains on sync (`WidgetSyncService._drainPendingTasbihEvents`):
  1. `getTasbihData` → events + native seq,
  2. the pure planner `drainedTasbihCounts` merges the events additively onto
     the app's own DB counts (idempotent by seq),
  3. diffs are applied to the tasbih DB (earliest-createdAt row claimed per zikr),
  4. **then** the app persists `widget_tasbih_applied_seq` (its own prefs),
  5. **then** acks via `drainTasbihEvents(nativeSeq)`.

  A crash between (3) and (4) re-applies a batch on the next sync — visible
  and resettable — rather than silently dropping counted worship. Increment
  events stay additive per zikr; counts never go down by replay.
- Guarded against foreign broadcasts: all four tap actions verify
  `intent.package == context.packageName` (the receiver is exported because
  the launcher needs it).

## Rendering & refresh model

- `updatePeriodMillis = 0` — **no OS polling** in either widget.
- Prayer widget: `TextClock` + countdown `Chronometer` tick themselves;
  re-renders happen on app snapshots, the 13 boundary alarms (five adhan
  times + sunrise + date flips, re-armed unconditionally on every render),
  the midnight alarm and a 6 h watchdog.
- Tasbih widget: re-renders once per tap (goAsync + one `updateAppWidget`;
  the bead animation is deleted — twelve bitmap re-renders per tap lagged on
  cheap phones), plus app snapshots and system broadcasts; a native
  daily reset zeroes counters at the first render of a new day when
  «ریست خودکار روزانه» is on.
- Both widgets render valid defaults even if the app has never pushed a
  snapshot (safe-fallback guarantee, `WidgetTokens.init`).
