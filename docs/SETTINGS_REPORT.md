# SETTINGS_REPORT.md — Settings & About redesign

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


Branch **`settings/redesign`**, isolated worktree `%TEMP%/opencode/settings-redesign-work`,
branched from `release/1.8.0` @ `274093d`. Tip: **`14dadb7`** (the upgrade
suggestions — palette-owned chips, alert-volume provider, reset-to-defaults —
landed on `9e1d83d`; the approved follow-up suggestions #3/#6/#7/#9 landed after
it, see the #3 / #6 / #7 / #9 notes below).
Inventory + plan: `docs/SETTINGS_INVENTORY.md`. Progress log: `PROGRESS.md`.

Goal: bring the Settings section and the About page to the approved designs
(Settings = Design 1, Prayer & Adhan = Design A, About = Design 1) and fix the
nine reported problems, **without changing a single preference key, default,
range or side effect** — presentation, layout and grouping only. Persian UI
stays Persian; code/comments/commits in English; no new heavy packages.

---

## 1. Commits

| # | Commit | Scope |
|---|---|---|
| 1 | `4a46dd9` | docs: full inventory + short plan |
| 2 | `e846de3` | shared signed/degree/minute formatters + RTL tests |
| 3 | `ff82b2f` | shared kit — tokens, duotone tile, switch, stepper, slider, segmented, warning, search field |
| 4 | `9da7bc8` | search registry with normalization, ranking, integrity tests |
| 5 | `ccb60a5` | tasbih mini-stat label on the shared type scale |
| 6 | `901e83f` | main Settings page on the kit — search field, theme chips, signed stepper |
| 7 | `e7c023a` | `SwitchTile` uses the unambiguous kit switch |
| 8 | `ad496f5` | debounce the notification reschedule to one per burst |
| 9 | `cb8fe8d` | Prayer & Adhan page on the kit — one card per prayer |
| 10 | `343e443` | About page on the kit (Design 1) |
| 11 | `3c49224` | notifications page: one app bar, kit warning, Friday header |
| 12 | `5979777` | widget customizer on the kit |
| 13 | `2b95634` | auto-backup action is a bounded row child; page goldens |
| 14 | `680dcb2` | exhaustive search-page helpers; binding-clock debounce test |
| 15 | `52a3cc0` | report (`docs/SETTINGS_REPORT.md`) + progress log |
| 16 | `1a9209d` | diagnostics screens on `SettingsAppBar` |
| 17 | `13565b4` · `56e06fd` · `e8a3c04` | report touch-ups (stable refs, inventory trim, suite numbers) |
| 18 | `f79e947` | account page on the kit + the functional-audit test (this hand-off) |
| 19 | `c4d82a7` | palette-owned theme chips + chip semantics, alert-volume provider, reset-to-defaults (suggestions #2/#4/#5/#8) |
| 20 | `577815d` | clear the two residual More info lints (suggestion #10) |
| 21 | `9e1d83d` | harden the pomodoro countdown assertion (wall-clock flake) |
| 22 | `5b5fe45` | docs: record the upgrade-suggestion pass and corrected verification |
| 23 | `67c1027` | deep-link flash kit (`SettingsFlashSection`/`SettingsHighlight`) + main-page push wiring (#3) |
| 24 | `0f8c684` | wire the highlight mixin into prayer/notifications/widgets/about pages (#3) |
| 25 | `8587ee1` | deep-link guard test + re-recorded prayer goldens (#3) |
| 26 | `2c1197c` | settings-only JSON export/import in «بازنشانی و انتقال» (#6) |
| 27 | `766d309` | About «تغییرات نسخه‌ها» row + bundled `assets/changelog.md` (#7) |
| 28 | `14dadb7` | delete the dead kit arc + the unused `flutter_svg` (#9) |

> **Hashes.** Rows 1–4 survived the rebase unchanged; rows 5–18 are the post-rebase
> SHAs (the pre-rebase hashes `a17c03d`/`ad29bf2`/`7c43ca8`/`ec8911f`/`8e33478`/
> `5655dd0`/`d58f94b`/`09d5988`/`291e514`/`9198d09`/`5642bbc`/`f139484` no longer
> exist — the branch was rebased to drop a foreign commit, see below).

> **Branch composition note.** The branch was **rebased** to drop one foreign
> commit — `b04df1a` *fix(quran): reader fixes from the on-device report*. Its
> patch-id is **identical** to `c578e33`, which is already on `release/1.8.0`
> (the fuller quran pass `5874b2c`), so nothing is lost. After the rebase
> `git diff --name-only 274093d..HEAD -- lib/features/quran test/features/quran`
> is empty and no later commit touches those files. Safety refs were left in the
> worktree: `safety/settings-redesign-81baaee` (old tip) and
> `safety/quran-b04df1a`. Pre-existing branch stashes were left untouched.

---

## 2. The nine reported problems → fixes

1. **RTL-bidi reversal of signed numbers / degrees.** New shared formatters in
   `lib/shared/utils/number_format.dart`: `formatSigned` (`+2` / `−5` with a true
   minus U+2212 / `0`), `formatDegrees` (`18°`, integral `.0` dropped),
   `formatMinutes` (`5 دقیقه`, unit outside the isolate), all wrapped in
   `ltrIsolated` (U+2066…U+2069). Every stepper/chip/subtitle that carried a sign
   or `°` now goes through them (`SettingsStepper` signed mode, the hijri pill, the
   calc-angle subtitles, the details line). Guard tests assert order in both an RTL
   and an LTR paragraph and the U+2212 codepoint.
2. **Unambiguous switch.** `SettingsSwitch` (42×24): ON = emerald `2E8B3D` track +
   white thumb, OFF = sand `D9CDBB` track + white thumb, 48dp hit box, `Semantics`
   toggled/enabled, disabled = 45 % track. `SwitchTile` renders it, so **every**
   switch in the settings section is now the same control.
3. **Compact steppers with ≥44dp targets.** `SettingsStepper`: 32 h visual pill
   (fill `FBF3E8` + hairline `EADFCC`), the −/+ zones are 44×44 `GestureDetector`s
   around 20dp glyphs, value 13/500 (min width 38), long-press repeat with
   acceleration, bounds disable their side, per-step haptics, and full
   `Semantics(onIncrease/onDecrease/increasedValue/decreasedValue)`.
4. **Duotone IconTiles replace grey squircles.** `IconTile` was rewritten to the
   duotone Style-2 (accent fill @14 %, border @18 %, radius 0.32·S, glyph
   `mix(accent, black, .10)`); the old `filled` parameter is gone and the four
   `kit_*.png` goldens were re-recorded. This is the same tile Home already uses,
   so all three surfaces now match.
5. **One app-bar spec.** `SettingsAppBar` (transparent, centered 16/500 ink title,
   auto-mirrored back arrow, optional trailing) is now the bar on **every**
   settings page — main (with the search field directly under it), font,
   prayer & adhan, notification diagnostics, notifications, widget customizer
   and About — replacing the per-page `AppBar`s.
6. **Per-prayer card replaces the three 5-row adhan lists.** The prayer page now
   has a single `_PrayerAdhanCard` of five hairline-separated `_PrayerAdhanBlock`s
   — line 1: 32dp tile + name + «پخش اذان» + switch; line 2: «تنظیم اذان»
   (signed stepper, −70…+70) and «اقامه» (0…70). Every one of the 15 keys and its
   side effect is preserved, including the dim-when-orphaned rule.
7. **Theme chooser as a horizontal chip row.** `_ThemeKindChips` (6 presets) plus a
   `SettingsSegmented` for light/dark/system, replacing the old vertical cards.
8. **Duplicate entries removed.** The adhan-sound row is single-homed on the prayer
   page (the main page deliberately excludes it). Documented in the inventory §8;
   the rest of the apparent overlaps are distinct keys.
9. **Search FIELD at the top, no search icon.** `SettingsSearchField` sits under
   the app bar; the old app-bar search icon and `_SettingsSearchDelegate` were
   removed. Results are grouped by owning page and tapping scrolls to the row and
   flashes it.

---

## 3. Shared kit (`lib/core/design_system/components/settings_components.dart`)

`SettingsAppBar`, `SettingsSwitch`, `SettingsValueChip`, `SettingsStepper`,
`SettingsSliderRow` (+ gradient track / bordered thumb / no-dot tick shapes),
`SettingsSegment<T>`/`SettingsSegmented<T>`, `WarningCard`, `SettingsSearchField`
and a `DebouncedWriter` (trailing, last-value-wins, `flush()` on dispose).

Performance contract followed everywhere: **no** `BackdropFilter`/blur, no
large-blur shadows, no `Opacity`/`saveLayer` (flat alphas only), `const` where
possible, and every font size routed through `AppTheme.scaledFontSize` so the
type-scale guard stays green.

### Tokens added (`settings_tokens.dart`)
`darkGradientStart 5A4032`, `darkGradientEnd 2A1A12`, `chipFill FFF1D2`,
`trackLine EFE3D0`, `selectedTint FFF6DA`, `pillFill FBF3E8`,
`pillBorder EADFCC`, `switchOn 2E8B3D`, `switchOff D9CDBB`, `chipText 7A5410`,
`warningGradientEnd FFFBF0`, `rowDivider F3EADB`. A trio of About-hero stops
(`aboutHeroTop/Mid/Bottom`) was added for Design 1 and has since been deleted —
the user's later verdict removed the gradient box around the logo (§6). Constants
that already had an equivalent token note it in-file and reuse the existing one.

### Regression found and fixed (guard by test — do not undo)
The redesigned auto-backup row put an `OutlinedButton` as a **bare `Row` child**.
`AppTheme.light`'s `outlinedButtonTheme` sets `minimumSize: Size.fromHeight(48)`
(infinite min width), so the row asserted `BoxConstraints forces an infinite
width` in debug and broke the button in release. Fix: a bounded
`minimumSize: const Size(64, 44)`. `SettingRow` is a plain `Row` + `Expanded`, so
**any** button placed as its `trailing` must set a bounded `minimumSize`; the
golden test re-fails when the line is removed.

---

## 4. Main Settings page (`settings_screen.dart`)

Ten sections in the approved order — «ظاهر برنامه» · «نماز و اذان» ·
«صداهای برنامه» · «امتیازدهی عبادات» · «اعلان‌ها و اذکار» · «قفل ابزارهای شخصی» ·
«ویجت‌ها» · «حساب کاربری» · «پشتیبان‌گیری» · «سایر» (whose last row is About).
Every row is a `SettingRow`; sliders are `SettingsSliderRow`; scoring uses
`SettingsStepper` (min/max preserved); the font page (`FontDisplayPage`, same
file) is on the kit too.

Search: a `SettingsSearchField` with a **150 ms debounce**; a query hides the
plain sections and shows hits grouped under their page header (titles/icons via
exhaustive `switch` helpers so the compiler guarantees coverage and the strict
`]!` gate stays zero). `searchSettings` normalizes the query, then every token
must match (AND) a normalized `title + subtitle + keywords` haystack; title hits
outrank keyword hits.

Goldens: `settings_day`, `settings_day_320`, `settings_night`,
`prayer_settings_day`, `prayer_settings_night`. The page height is
width-independent (subtitles are single-line ellipsized) so 412 and 320 are both
3455 tall — expected, not a bug.

---

## 5. Prayer & Adhan page (`prayer_settings_screen.dart`, Design A)

Eight sections: Adhan sound · Calculation · Location · **Per-prayer** ·
Prayer-notification · Global shift · Friday · Silence. Highlights: the per-prayer
card (§2.6 above); the DND/permission notice is the kit `WarningCard`; the
`SilentAfterIqamahTile` moved from a legacy `ListTile` + `IconButton` steppers to
`SettingRow` + `SettingsStepper`; the legacy `_CompactStepper`/`_StepButton`
(32 dp targets) were deleted.

**Scheduling side effects** stay exactly as today, but the notifier's
`_rescheduleAlarms` is now a **350 ms trailing debounce** (last value wins) so a
stepper drag or a burst of toggles coalesces into **one** reschedule instead of
one per write. `notificationServiceProvider` and
`dailyNotificationSchedulerProvider` moved to a neutral
`settings_infra_providers.dart` (re-exported from the old file), and
`ref.onDispose` cancels the pending timer. A `testWidgets` test drives a burst of
five writes and asserts exactly one scheduler call carrying the last value, plus
a second burst separated by more than the window producing two calls. The timer
runs on the test binding's fake clock (`tester.pump(duration)`), so no extra
async helper package was added to the protected `pubspec.yaml`.

---

## 6. About page (`about_screen.dart`, Design 1)

- **Flat identity header, no box** (user verdict after Design 1: «بوکس گرادیانی دور
  لوگو را حذف کن»): the ~200 dp brand-coffee gradient card is gone, and with it
  `t.heroInk` text and the bespoke white-alpha `_VersionChip`. The page app bar
  (`SettingsAppBar`) is unchanged. What remains sits directly on the page — the
  **real** `assets/logo2.png` at 78 dp, «توحید» 20/w800 in `t.textPrimary`, a kit
  `SettingsValueChip` fed by `PackageInfo`, and the tagline in
  `isDark ? heroGold : goldDark` so one recipe stays readable on both surfaces.
  A guard in `about_screen_test.dart` asserts the logo has no gradient-box
  ancestor; the four About goldens record the flat header. (`_loadVersion` is
  still wrapped in try/catch + `AppLogger`, so a PackageInfo failure degrades to
  a plain chip instead of breaking the page.)
- Description `AppCard` (text unchanged), «امکانات برنامه» 3-column grid of
  duotone tiles, support list (`SettingRow`s), footer.
- **No URL, e-mail or store link was invented.** The support rows and footer
  reuse only constants that already existed at the base commit
  (`kTelegramUrl = https://t.me/TAWHEED_EWAZ1`, the existing Google-Drive folder
  link, the existing Play `market://`/`https` rating URLs from `_rateApp`, the
  existing share text). Rows the spec asked for that have **no real source** were
  omitted and are listed in §10.

Goldens: `about_day` (412×2349), `about_day_320` (320×2156),
`about_day_scale13` (412×2670), `about_night` (412×2349).

---

## 7. Notifications & widget-customizer pages

- Notifications: `SettingsAppBar`; exact-alarm warning → `WarningCard`;
  Friday-adab header → `IconTile`. All keys and the `rescheduleAll()`
  side effect preserved.
- Widget customizer: `SettingsAppBar` with the dirty-guarded Save action as its
  trailing; low-contrast notice → `WarningCard`; `_StyleCard` → `AppCard`.
- Diagnostics (`attachment_diagnostics_screen.dart`,
  `notification_diagnostics_screen.dart`): both already used the kit body
  (`AppCard`/`SettingRow`), so only their legacy `AppBar` was swapped for
  `SettingsAppBar` (refresh action moved to `trailing`).

---

## 8. Tests & goldens

New test files:
`test/core/design_system/settings_components_test.dart`,
`test/features/prayer/presentation/screens/prayer_settings_screen_test.dart`,
`test/features/settings/presentation/providers/settings_reschedule_debounce_test.dart`,
`test/features/settings/presentation/screens/about_golden_test.dart`,
`test/features/settings/presentation/screens/settings_golden_test.dart`,
`test/features/settings/presentation/search/settings_registry_test.dart`,
`test/features/settings/presentation/pages/settings_functional_audit_test.dart`
(the §10 audit),
`test/features/settings/presentation/pages/settings_highlight_test.dart`
(the #3 deep-link guard),
`test/features/settings/services/settings_transfer_service_test.dart`
(the #6 codec) and
`test/features/settings/presentation/screens/about_changelog_test.dart`
(the #7 dialog).

Updated: `settings_screen_test.dart` (search-field-above-sections, the ten-group
order, search-results grouping, a 320/360/412dp × scale 1.0/1.3 no-overflow
matrix under the **real** `AppTheme.light` — the test binding's default theme
hides button-minimum bugs), `about_screen_test.dart` (incl. a 320/360/412 matrix),
`notification_settings_screen_test.dart`, `settings_tool_locks_test.dart`,
`settings_widgets_test.dart`, `silent_after_iqamah_tile_test.dart`,
`fraction_format_test.dart`, `kit_phase_golden_test.dart`, and
`fake_notification_infra.dart`
(`FakeDailyNotificationScheduler.scheduleIfNeededCalls`, `FakePrayerTimeService`).

Registry test guarantees: unique ids, every route is a known settings route,
every preference key is covered or explicitly orphaned, and every routeless entry
has an anchor row. Formatter test guarantees RTL/LTR order and U+2212.

New goldens (9): `about_day`, `about_day_320`, `about_day_scale13`, `about_night`,
`prayer_settings_day`, `prayer_settings_night`, `settings_day`, `settings_day_320`,
`settings_night`. Re-recorded: `kit_dawn/day/night/sunset`. All goldens render
**tofu glyphs** (no font is loaded in the test binding) — they guard palette and
layout drift, not shaping.

---

## 9. Verification

- `flutter test test/features/settings test/features/tools/pomodoro
  test/core/design_system --exclude-tags network` → **355 passed, 0 failed** at
  the current tip. (The earlier 797-wide targeted run — settings, prayer, account,
  adhkar and the whole design-system kit — was green too; the only baselines from
  it that have since moved are the three main-page goldens re-recorded with the
  reset section (§13 #6) and the four About goldens re-recorded with the changelog
  section (§13 #7).)
- Full suite at the final tip `14dadb7` (`flutter test --exclude-tags network`) →
  **3467 passed / 9 skipped / 5 failed**. All five are the known-red
  `home_golden_test` drift inherited from the branch base, and none is in a file
  this branch touched: the harness freezes only `second.value` (line 166), so
  `HeroCard` prints the real wall-clock `minute` for its clock/date chips, and
  the baselines can only match the minute they were recorded in. The parallel
  home session has since fixed exactly that on `release/1.8.0` (`..minute.value =
  …`, verified present in the shared tree) — so these five go green the moment
  this branch lands on the moved line. Zero failures fall in settings / prayer /
  design-system / about / worship.
- `python tools/quality_check.py --strict` → **7/7 all-zero**.
- `flutter analyze lib test` → **0 errors / 0 warnings** (104 pre-existing info);
  the branch's last two `info` lints (More screen) are cleared too (§13 #10).
- The `type_scale_guard_test` failure at `tasbih_counter_widget.dart:1276`
  (`fontSize: 9.5`) that `release/1.8.0` carries is **fixed on this branch** by
  `ccb60a5` (the mini-stat label now goes through the shared type scale).
- The functional audit (see §10) is green: **12/12**, including the new reset-row
  dialog case, the account-page suite (12 tests) and `test/core/design_system/`
  (51 green after the `arc.dart` removal, §13 #9).

**No Android device is attached**, so everything above is widget + golden +
analyzer proof, not on-device verification. The goldens are layout/palette proof
only (tofu glyphs). A device pass — especially the About header's flat logo and
its gold tagline on both surfaces, the
per-prayer card at low width, and the reschedule debounce under real alarms — is
still owed.

---

## 10. Functional audit + the account page

The audit exists because the user's first report after the redesign said that
"before these changes everything was locked". The tree read was clean — no
`IgnorePointer`/`AbsorbPointer`/`enabled: false`/`onTap: null` anywhere in the
settings or prayer screens — so the guard is **behavioural**:
`settings_functional_audit_test.dart` pumps the real main page (real
`AppTheme.light`, mock repo, fake scheduler) and taps each control, asserting the
**persisted** value:

- theme-kind chip «طلایی» → `accentPreset == 'gold'` in the repository;
- {سیستم/روشن/تاریک} segment → `themeMode == dark`;
- hijri-offset stepper → `hijriOffset` ±1 (up **and** down asserted);
- the five worship-point steppers → each its own field +1 (page order is pinned:
  0 hijri, 1 fardh, 2 sunnah, 3 duha, 4 adhkar, 5 tasbih, 6 multiplier; the count
  itself is asserted == 7 so a future stepper cannot slip in unguarded);
- worship-multiplier stepper → `worshipMultiplier` 1.0 → 1.25;
- tasbih volume slider → `azkar_sound_volume` < 1.0 in SharedPreferences **and**
  the `azkarSettingsProvider` agrees;
- «ایجاد پشتیبان کامل» → the password dialog opens («رمز اختیاری پشتیبان» /
  «ادامه»), dismissed via «لغو» with no side effect;
- all 11 navigation rows carry a non-null `onTap` (no dead tiles), and three of
  them (font, about, account) are pushed **for real** through a GoRouter and land
  on their routes;
- the tool-lock block mirrors `ToolLock.options` (3 wires) and a toggle writes the
  exact `tool_locks.enabled` list the router guards read.

Every write lands in `MockSettingsRepository` (or SharedPreferences), so a control
whose write silently vanished would fail here. All 11 tests green.

### Account page (`/settings/account`) — now on the kit
`account_screen.dart` was the last legacy settings route (legacy `AppBar`,
`ListTile`s, a local `_card`). Converted, presentation-only: `AppBar` →
`SettingsAppBar`; `_card` → the palette card (radius 22, hairline border) with the
same `Material(transparency)` ancestor so row inks paint; the firebase/Drive
upload, cloud-list and delete `ListTile`s → `SettingRow` duotone rows. `SettingRow`
gained an optional `titleColor` (default unchanged) so the destructive
«حذف حساب کاربری» stays red. The backup-list tiles and every Firebase/Drive/
sign-in/delete flow are untouched; the existing account widget tests
(12, incl. the password/restore dialog flows) stay green. No device was attached,
so the cloud flows are unit-proven only.

---

## 11. Remaining / not done (needs a decision)

- **Account & cloud page (`/settings/account`)** — converted in §10 (`f79e947`):
  app bar → `SettingsAppBar`, `_card` → palette card, nav `ListTile`s →
  `SettingRow`; every Firebase/Drive flow preserved. What it still needs is a
  **device pass** of the real Google sign-in and Drive restore (no device is
  attached), not more code.
- **About rows with no real source, omitted on purpose:** a «منابع و مجوزها»
  page (no such page/asset) and a Terms screen (does not exist). The rating
  row is **kept** because the app already ships working Play/`market://` URLs.
  The changelog row that used to sit in this list **has since landed** as
  suggestion #7 (§13): `assets/changelog.md` is a bundled copy of the repo's
  `CHANGELOG.md`, so the notes are offline and no longer depend on the remote
  `update.json`.
- No old settings files were deleted: the orphan scan finds **no** settings file
  with zero importers (only a few pre-existing dead files elsewhere —
  `appearance_providers.dart`, `icon_chip.dart`, `tasks_weekly_stats.dart` — all
  of which predate this branch and were left alone).

---

## 12. Rule compliance

- No preference key, default, range or side effect changed (inventory §keys; the
  registry test pins key coverage, `app_settings_test.dart` pins the defaults).
- No religious content touched; Persian UI stayed Persian.
- No new package. `pubspec.yaml` carries two edits, both from approved
  suggestions: `assets/changelog.md` added (#7) and `flutter_svg` removed (#9,
  with its three `vector_graphics*` lock transitives). `pubspec.lock` changed
  only by those removals; no dependency was added.
- Protected files: `more_screen.dart` (pre-authorized in an earlier session) and,
  for the two approved suggestions above, `pubspec.yaml`/`pubspec.lock` (#7/#9)
  — nothing else on the protected list was touched.
- **No push, no tags** (the repo has no remote).

---

## 13. Upgrade suggestions — what was done

The ten suggestions the audit proposed, and their outcome:

| # | Suggestion | Outcome |
| - | ---------- | ------- |
| 1 | device pass of account/cloud | **blocked** — no Android device |
| 2 | palette swatches from one source | **done** |
| 3 | search reaches inside sub-pages | **landed** — scroll + flash, see below |
| 4 | alert volume as a provider | **done** |
| 5 | reset settings to defaults | **done** |
| 6 | export/import a settings-only JSON | **landed** — see below |
| 7 | About changelog row | **landed** — bundled asset, see below |
| 8 | semantic labels on the theme chips | **done** |
| 9 | dead files / dead dependency | **landed** — see below |
| 10 | two residual `info` lints | **done** |

### 2 — theme-chip swatches are palette-owned
`_ThemeKindChips` used to carry twelve hex literals; five of the six pairs had
already drifted from the palette they claimed to preview. They now come from
`AppPalettes.previewSwatches(kind)` (`time_theme.dart`), which derives the pair
from the kind's **own** light palette (`gold` → tertiary/primary, the phase
kinds → heroTop/heroBottom, `live` → dawn + day heroTop). `sunset` keeps its
design pair as a literal **on purpose**: that palette's own hero stops read as a
flat dark rust at chip size. Values are otherwise identical, so no golden moved
for this change.

### 4 — alert volume is a provider
`AlertVolumeNotifier` / `alertVolumeProvider` (a plain `NotifierProvider`, no
codegen) live in `settings_infra_providers.dart`. `_SoundSettingsSection` became
a `ConsumerWidget` that watches it instead of holding a local `_alertVolume` in
`setState` and reading `AlertVolume.get()` in `initState`. Persistence is
unchanged (`sound_alert_volume`), so the pomodoro beep and the reminder previews
read the same number as before.

### 5 — reset to defaults (new)
`Settings.resetPreferences()` writes a factory `AppSettings` while **keeping**
`onboardingCompleted` and `isPremium` — the repository's own `resetSettings()`
clears both, which is exactly why it was never wired to a button. The main page
gained a «بازنشانی» section: a `WarningCard`, a destructive `SettingRow` and a
confirm dialog that spells out what is *not* deleted (notes, expenses, personal
data, backups). It resets the `AppSettings` entity only; azkar/tasbih prefs, the
alert volume and the tool locks live outside it and are untouched. Guarded by
`settings_notifier_test.dart` (defaults restored, onboarding + premium kept) and
by a new audit case that drives the dialog: **cancel** changes nothing,
**confirm** restores defaults. Registry entry `main.reset` added.

### 8 — chip semantics
Each chip is now a `Semantics(button: true, selected: …, label: 'تم …، …')`, so a
screen reader announces the theme name, its one-word character and whether it is
the active one; previously the three texts were read as three loose labels.

### 10 — the last two info lints
`more_screen.dart` dropped a redundant `crossAxisSpacing: 0`; the more-screen
test took `const` on its `BoxConstraints`. `dart analyze lib test` is now
**0 errors / 0 warnings**, and the two lints are gone.

### 3 — deep-link search into sub-pages (landed)
The indexing half already existed (`SettingsRegistry` carries a `rowKey` per
sub-page row; the main page pushed `extra: {'settingsHighlight': rowKey}`); the
missing half was the **receiving** side. It now exists:

- New `lib/features/settings/presentation/widgets/settings_flash.dart`:
  `kSettingsHighlightExtra`, `SettingsFlashSection` (the flash wrapper, tint
  `SettingsTokens.selectedTint` @ 55 %, radius 22) and the `SettingsHighlight`
  mixin, which owns the page's `ScrollController` and exposes
  `disposeSettingsHighlight()`. A page mixes it in, wraps each target row group
  in `SettingsFlashSection(rowKey: …)` and hands `controller:
  highlightScrollController` to its `ListView`.
- On landing, the mixin reads the route extra, runs `_materializeAnchor` (a
  progressive `jumpTo` sweep, because the pages are long lazy lists whose
  below-the-fold children do not exist yet), then `Scrollable.ensureVisible`
  and finally flashes the section for 900 ms. An earlier attempt to widen
  `cacheExtent` (`kSettingsEagerCacheExtent`) was abandoned: it shrank the lazy
  list's initial `maxScrollExtent` estimate and still failed to attach
  below-fold rows — the controller loop is the reliable mechanism.
- Wired into all five destinations: main page (`FontDisplayPage` mixin), prayer
  & adhan, notifications, widget customizer and about (7 sections wrapped on
  the main page alone). Route extra is read through a try/catch because
  go_router 17.5.0 has no `GoRouterState.maybeOf` and the page tests pump a bare
  `MaterialApp`.
- Guarded by `test/features/settings/presentation/pages/settings_highlight_test.dart`
  (330 lines): it lands with a given `rowKey`, asserts the target scrolls into
  view and flashes, covers the reduce-motion path (scrolls, no flash) and the
  unknown-key path (nothing flashes). The two prayer-page goldens were
  re-recorded — `_PrayerAdhanCard` now wraps its five blocks in
  `SettingsFlashSection`, so only they moved; the three main-page baselines were
  byte-identical.

### 6 — settings-only JSON export/import (landed)
The reset section is retitled **«بازنشانی و انتقال»** and gains two transfer
rows above the destructive one:

- **«خروجی گرفتن از تنظیمات»** writes the current `AppSettings` to
  `tawheed_settings.json` in the temp dir and shares it (share_plus + a JSON
  `XFile`); **«دریافت از فایل»** picks a `.json` (file_picker 13 —
  `FilePicker.pickFile` → `readAsBytes`), validates it, confirms, and applies
  it.
- The codec is a pure, IO-free service
  (`lib/features/settings/services/settings_transfer_service.dart`): a small
  versioned envelope `{type: 'tawheed_settings_transfer', version: 1,
  exportedAt, settings: <AppSettingsDto.toJson()>}`. It reuses the existing
  `AppSettingsDto` codec rather than hand-mapping fields, so enums/dates/lists
  cannot drift. `decodeSettingsTransfer` rejects a wrong marker, a newer
  version and damaged payloads; unknown extra fields still import (a newer file
  is read for the fields it knows — never silently misread).
- `SettingsNotifier.importPreferences` mirrors `resetPreferences`: the file's
  own `onboardingCompleted` / `isPremium` are **ignored** in favour of the
  target device's, so an import can never log a user out of onboarding or drop
  premium.
- Registry entries `main.export_settings` / `main.import_settings` (rowKey
  `reset`). Guards: codec round-trip/envelope/version/damage tests, a notifier
  import test, a functional-audit widget guard for the three rows + the new
  section title, and the three main-page goldens re-recorded (the card grew two
  rows).

### 7 — About «تغییرات نسخه‌ها» (landed)
The About page gains a «نسخه و تغییرات» section (between the description card
and «امکانات برنامه») with one row that opens a scrollable dialog of the app's
release notes. Content is **bundled, not fetched**: `assets/changelog.md` is a
byte-identical copy of the repo's `CHANGELOG.md` (same SHA-256), declared in
`pubspec.yaml` — the one protected-file edit this suggestion needed; no package
was added. The dialog renders the markdown through a tiny line-based pass
(`_ChangelogBody`/`_RichLine`: `#`/`##`/`###` headings, `-` bullets, `>`
blockquotes, paragraphs, `**bold**` inline) — deliberately not a full markdown
renderer, and the asset is read only on tap so the page never touches the
bundle while rendering. Guarded by `about_changelog_test.dart`; the four About
goldens re-recorded for the new section.

### 9 — dead kit arc + unused `flutter_svg` (landed)
`lib/core/design_system/components/arc.dart` (`ArcPainter` + `ArcCountdown`) had
**no production consumer**: the home hero paints its own private
`_HorizonArcPainter`/`_ArcCountdown` and the evaluation report its own
`_ScoreGaugePainter`; the only importer was the kit's own `components_test.dart`.
The file and its `components.dart` export are deleted, the test's arc coverage
and its now-unused `ClockTicker`/`PrayerClock` fixtures are removed. `flutter_svg`
^2.2.1 is removed from `pubspec.yaml` (+ its three lock-only transitives
`vector_graphics*`): no `.dart` referenced it and the repo bundles no `.svg`
asset — the surah-header ornament banner it once served is now the
custom-painted `SurahHeader`. The two comments in `evaluation_stats_widget.dart`
that named `ArcPainter` are reworded (they described the local gauge). Guards:
design-system suite 51 green, analyze 0/0, gate 7/7.

### Off-branch: the pomodoro flake
`pomodoro_screen_test.dart` demanded exactly `00:59` one second after start, but
`PomodoroScreen._tick` also reconciles against the real wall clock, so a loaded
machine legitimately printed `00:58` (green in isolation, red in the full suite).
The assertion now accepts the `00:5x` band and still proves the countdown
started. Test-only, commented, no behaviour touched.

