# Widgets theming report (1.8.0)

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


> **Superseded (2026-11-01).** The current architecture, palette table and
> problem checklist live in `docs/GLANCE_WIDGETS_REPORT.md`. Two statements
> below are no longer true and must not be relied on: the `TextClock` /
> `Chronometer` leaves were **removed** (2026-10-29), and the tasbih card is
> **not** a Glance composition any more. The palette and contrast history in
> this file is still accurate for the shipped `widget_palettes.json`.

Both home-screen widgets are now user-themable. Branch `widgets/final-themed`,
worktree `%TEMP%/wlwidgets`, base `eb58ab5`.

## What shipped

- **`assets/widget_palettes.json` is the single source of truth.** 7 color
  presets + the time-phase `auto` entry («خودکار»), and the four user-facing
  opacity steps `[100, 85, 70, 55]`. Declared in `pubspec.yaml`; contract
  tests pin the schema and the contrast floors.
- **`tool/widget_palette_generator.dart`** emits one rounded-gradient drawable
  per palette per step (`widget_<palette>_bg[_oNN].xml`, 7×4) so the layout's
  pre-render skin and the API < 31 fallback come from the same data. Regenerate
  after any palette edit (`dart run tool/widget_palette_generator.dart`);
  `test/tools/widget_palette_generator_test.dart` guards the output shape.
- **`WidgetTheme` (Kotlin)** resolves the stored selection (`widget_palette_id`
  + `widget_opacity_step` in the `tawheeed_widgets` prefs) into concrete
  colors. Its pure core (`parseSpec`/`resolveSelection`/`phaseFor`) runs in JVM
  unit tests without an Android context (`android.graphics.Color` is stubbed
  there, so the parser is hand-rolled hex). `auto` picks the palette bound to
  the current prayer-time phase, re-evaluated at every boundary render.
- **Both renderers** (`PrayerWidgetViews`, `TasbihGlanceWidget`) take their
  colors from the resolved theme; the corner radius is
  `WidgetTheme.CORNER_RADIUS_DP` (22) — the same value the generated drawables
  and the Flutter preview (`WidgetTokens.widgetRadius`) use, so the runtime
  gradient never disagrees with the pre-render skin.
- **The settings page «ویجت‌ها» was rebuilt around the palette model:**
  live preview per tab (اوقات نماز / تسبیح) fed by the resolved palette,
  gradient chips per preset plus the «خودکار» chip, a 4-step opacity segmented
  control, a readability warning when the *effective* (opacity-composited)
  contrast drops under 3:1, and the footer (manual sync / pin-to-home /
  help). Saving persists palette + step through `setWidgetTheme` and delegates
  the snapshot rebuild to the sync engine. Opening with no stored selection
  mirrors the native legacy migration, so the page opens on what the widgets
  actually paint. Unsaved changes are guarded by a confirm-on-pop.
- **Legacy style path deleted** after the palette model replaced it:
  `updateWidgetStyle` (bridge + Kotlin handler), the `WidgetRepository` legacy
  writes and `ensureDefaults`, the `WidgetSnapshot`
  bg/text/opacity/cornerRadius fields, and the `WidgetSync` SharedPreferences
  style cache. Old installs migrate once on the first native resolve
  (exact bg match → nearest same-lightness preset; old opacity → nearest
  step). `docs/WIDGET_DATA.md` carries the full data contract.

## Palettes

| id | name | bg → bgEnd | text | accent | notes |
| --- | --- | --- | --- | --- | --- |
| `brown_gold` | قهوه‌ای طلایی | `#3B2316` → `#2A1A10` | `#F5EDE3` | `#C9A94E` | **default**; auto phase: afternoon |
| `night_blue` | شب آبی | `#004F9E` → `#003A73` | `#FFFFFF` | `#E8D08A` | auto: night |
| `emerald` | زمردی | `#1B4332` → `#122E23` | `#F5EDE3` | `#95D5B2` | |
| `dawn_purple` | بنفش سحر | `#4C1D95` → `#35156B` | `#F3E8FF` | `#D8B4FE` | auto: dawn |
| `sunset` | غروب | `#7C2D12` → `#5A1F0C` | `#FFF7ED` | `#FDBA74` | auto: sunset, evening |
| `graphite` | گرافیت | `#1A1A2E` → `#12121F` | `#E8E8F0` | `#C9A94E` | |
| `cream_light` | روشن کرم | `#F8F5F0` → `#EDE4D3` | `#3B2316` | `#8A5A2B` | light; auto: morning |
| `auto` | خودکار | — | — | — | resolves per phase, re-rendered at each boundary flip |

## Contrast policy

- Text on bg ≥ **4.5:1** (WCAG AA) at 100 %; accent on bg ≥ 3:1. Pinned per
  palette by `test/features/settings/widget_palettes_test.dart`.
- At the 55 % step the background lets the wallpaper through: dark palettes
  hold ≥ 3:1 against their own darkened surface (pinned over a black
  backdrop), the light palette holds ≥ 3:1 over white, and the layouts carry
  a text shadow for light wallpapers behind dark skins.
- The settings page composites the *selected* palette over a mid-grey
  wallpaper proxy and warns («در این شفافیت، خوانایی متن روی پس‌زمینه کم است»)
  whenever the effective ratio drops under 3:1.

## Sizing matrix

| widget | min | min resize | max resize | resize |
| --- | --- | --- | --- | --- |
| Prayer (`widget_prayer_info.xml`) | 250×120 dp (4×2) | 120×80 dp | 500×500 dp | horizontal+vertical |
| Tasbih (`widget_tasbih_info.xml`) | 190×190 dp (4×3, square) | 120×120 dp | 400×400 dp | horizontal+vertical |

Both widgets are Jetpack Glance composables (`PrayerGlanceWidget`,
`TasbihGlanceWidget`), so there are no full-page XML layouts any more: content
is composed from this theme at render time and scales between the min and max
bounds from `LocalSize` (the prayer card switches to its narrow face below
140 dp tall). The only XML left is the pair of live leaves —
`widget_live_clock` (TextClock) and `widget_live_countdown` (Chronometer) —
embedded through `AndroidRemoteViews`, because Glance cannot tick and neither
widget polls. `onAppWidgetOptionsChanged` hands the resize to Glance.

## Test inventory

- **JVM (Kotlin):** `android/app/src/test/.../widget/` — `WidgetThemeTest`
  (parse/resolve/phase/migration/opacity, pure core) and the widget helpers
  (per-zikr counts, queue append/prune/collapse, reset confirm, bead
  progress). Run: `./gradlew :app:testDebugUnitTest --tests "com.islamic.tawheeed.widget.*"`.
- **Dart:** `test/features/settings/widget_palettes_test.dart` (JSON contract +
  contrast floors + legacy migration), `test/tools/widget_palette_generator_test.dart`
  (generator output), `test/features/settings/presentation/screens/widget_settings_screen_test.dart`
  (new UI: render, legacy mirror, save path, dirty guard, auto selection,
  no-warning sweeps), `test/shared/services/widget_sync_merge_test.dart`
  (the tap-event merge planner), `test/features/home/domain/entities/widget_snapshot_test.dart`.
- **Gate:** `python tools/quality_check.py --strict` all-zero;
  `flutter analyze lib test` 0 errors / 0 warnings.

## Manual / visual checklist (needs a device — none attached for this work)

1. Add both widgets to the launcher; verify the default قهوه‌ای طلایی at
   100 % renders identically to the pre-render skin (drawable vs runtime).
2. Change palette + step on the settings page → ذخیره → both widgets repaint
   immediately; reopen the page → the same selection is shown.
3. «خودکار» → add the widget in the evening and after fajr — the skin flips
   at the boundary without opening the app.
4. Tasbih: rapid taps (~10) → open the app → counts imported; kill the app
   right after a tap burst → reopen → nothing lost, nothing doubled.
5. Reset: first tap shows «تأیید؟» for 3 s; second tap zeroes; wait 3 s and
   the window closes without resetting.
6. Legacy upgrade: install an old build with a custom color, then this one →
   the widget keeps a visually equivalent skin and the settings page shows
   that preset preselected.
7. Battery: no polling — confirm no `APPWIDGET_UPDATE` storms in
   `adb shell dumpsys alarm | grep tawheeed` beyond the boundary alarms.

## Engine cost notes

- No per-minute alarm chain, no polling: the prayer widget ticks itself via
  `TextClock`/`Chronometer`; the only alarms are the exact boundary set, the
  midnight roll and the 6 h watchdog, all re-armed unconditionally on every
  render (no alarm-store drift).
- Tasbih taps hold the broadcast open with `goAsync()` for a single
  `updateAppWidget` render. The old ~310 ms / 12-frame bead animation
  (`partiallyUpdateAppWidget` per frame) was removed: re-rendering the ring
  bitmap twelve times per tap is what made counting feel slow on cheap
  phones, and a source-scan test forbids it from coming back.
- The Flutter engine is never started by either widget.
