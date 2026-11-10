# 02 — DESIGN CONTRACT (the single language PART 2 must implement)

**Base:** `release/1.8.0` @ `dccdcfd`, worktree `final-map`. **Docs-only** (PART 2 has not
started). Every rule below is derived from what the already-redesigned surfaces
(Home, More, Calendar, Splash, Evaluation, Quran chrome, bottom nav, settings hub) do —
not from a new invention — and every rule names **how it is checked**, so "consistent"
is a verifiable property, not an opinion. Cross-references: `00_…COVERAGE.md` (who is
where), `01_FINDINGS.md` (what is broken), `05_BASELINE.md` (numbers to beat).

> **Definition of done for PART 2.** No screen may (a) paint its own page background,
> (b) hard-code a `Color(0x…)`, (c) hard-code an off-scale or unscaled `fontSize`,
> (d) hand-roll a card/sheet/row that the kit already provides, or (e) keep a legacy
> design from the pre-kit era. Where a surface is `FROZEN` (mushaf page, حصن المسلم
> root, native kotlin/XML), the rule is "do not touch", not "convert".

---

## 1. The twelve laws

| # | Law | Mechanism (existing, verified today) | How it is checked |
|---|---|---|---|
| L1 | **One background.** Every page paints the theme background via the shell/`AmbientBackground`; screens never paint their own `Scaffold(backgroundColor:)` gradients. | `lib/core/design_system/ambient_background.dart` (palette-derived, zero `BackdropFilter`); native side `widget/WidgetTokens.kt` | consistency check flags `Scaffold(backgroundColor:` + `Container(decoration: …gradient` outside the allowlist |
| L2 | **No raw colours in feature screens.** Topic identity comes from `TopicHues` (`core/theme/time_theme.dart`), content colours from `Theme.of(context)`/`dsContentColor`. | `TopicHues` = 64 hues, the superset; `SectionColors` = 45 **value-identical** duplicates (see F-38) | check: `Color(0x` count per file must be 0 outside the palette allowlist (~250 occurrences in ~60 files today → target 0) |
| L3 | **One card.** Anything that reads as a surface is `AppCard` (radius 22, padding `DsSpacing.page`, hairline border, **no heavy shadow**). | `components/app_card.dart`; the legacy `card_design_system.dart` blur shadows (14/18/22/30) are the thing being replaced | check: `BoxShadow` with `blurRadius ≥ 10` outside the allowlist must be 0 (F-08) |
| L4 | **One spacing rhythm.** Page padding 10, sibling gap 8, compact row gap 6. | `DsSpacing.page/gap/rowGap` (`components/tokens.dart`) | visual + the sheet/list goldens |
| L5 | **One type scale, always scaled.** Sizes come from `AppTheme.fs*` semantics or `AppTheme.scaledFontSize(context, step)` over the 19-step `AppTheme.typeScale` (8,9,10,11,12,13,14,15,16,17,19,21,23,26,30,34,40,48,56). | `AppTheme.typeScale` / `scaledFontSize`; `fsCaption 11 … fsHero 23` | `test/core/theme/type_scale_guard_test.dart` (must be **green**: today the 9.5 in `tasbih_counter_widget.dart:1276` fails it) |
| L6 | **One component kit.** Interactive chrome is built from `design_system/components/*` — never a fresh `Container`+`InkWell` pair. | `AppCard, HeroCardShell, SectionHeader, SegmentedTabs, IconTile, RingView, SettingRow, SliderRow, ValueStepper, GlassChip, OutlineChip, SmallChip, BadgeChip, ArcCountdown/ArcPainter, CheckCircle, AppBottomNav` | check: redesigned files must import the kit barrel (`components/components.dart`) — 125 files already do |
| L7 | **One shell for sheets.** A `showModalBottomSheet` (71 call sites / 42 files) uses the same handle, radius, padding and drag-to-dismiss behaviour; content is kit components. | kit + the Quran/home sheets as the reference implementations | sheet goldens (`quran_mushaf_sheet_test`, `quran_mushaf_widget_test`) + before/after screenshots |
| L8 | **One state model.** Every async surface renders four explicit states: `loading` (skeleton/indeterminate, never a determinate 0 %), `empty` (Persian copy + one action), `error` (cause + retry that *resumes*), `offline` (what still works). | the download/prompter fix pattern (`Object? downloadProgress = _unset` sentinel; resume-by-Range) is the reference | widget tests per state; no silent `return false` in a button path |
| L9 | **RTL & Persian by construction.** No hard-coded `TextDirection`, no `EdgeInsets.only(left/right:)`, no `Alignment.centerLeft`, Latin digits only where the app already uses them; religious text never re-worded/re-ordered. | shell is `Directionality.rtl`; `day_time.dart`/formatters own digit policy | check: `TextDirection.ltr` / `.left`/`.right` literals outside the allowlist |
| L10 | **Accessibility floor.** Tap targets ≥ 48 dp, text contrast ≥ 4.5:1 (≥ 3:1 for ≥ 24 dp), every icon-only button has a semantic label, layout survives text scale 1.3 and width 320 dp. | 32 `Semantics(` sites today; the flood/wash contrast math in the mushaf palette is the reference for measured contrast | `F-06` checklist + the 320/360/412 × 1.0/1.3 overflow matrix extended beyond Home/More/Tasbih |
| L11 | **Cheap pixels.** No `BackdropFilter`, no saveLayer, no non-animated `Opacity`, no blur shadow, static gradients only, `const` where possible. | verified: 0 `BackdropFilter` in production code, exactly 1 `Opacity(` (`qibla_screen.dart:1620`) | check script (new) + frame/memory measurement in PART 3 |
| L12 | **Frozen is frozen.** Mushaf/QCF4 bundle, `quran-common.ttf` pages, `duas_screen.dart` (حصن المسلم root), religious strings, native widget/alarm code, `app_database.dart`/`*.g.dart`, `main.dart`, `pubspec.*` — never restyled without explicit approval. | `AGENTS.md` protection list; this task's own rule | every wave's diff reviewed against the protection list |

## 2. Token reference (what to use, exact names)

| Token | Value / API | Notes |
|---|---|---|
| Page padding | `DsSpacing.page = 10` | `AppCard`'s default padding is already this |
| Sibling gap | `DsSpacing.gap = 8` | between cards/tiles |
| Row gap | `DsSpacing.rowGap = 6` | compact rows inside a card |
| Card radius | `AppCard(radius: 22)` default | do not invent 16/18/24 |
| Type steps | `AppTheme.typeScale` (19 steps) | `scaledFontSize(context, n)` scales by `bodyMedium/15` **and snaps** to the nearest step |
| Semantic sizes | `fsCaption 11 · fsLabel 12 · fsBodySm 13 · fsBody 14 · fsBodyLg 15 · fsTitleSm 16 · fsTitle 17 · fsHeadline 19 · fsDisplay 21 · fsHero 23` | prefer these over raw numbers |
| Hues | `TopicHues.*` (64) — **the single source** | `SectionColors.*` (45) is a value-identical duplicate → deprecate (F-38) |
| Readable content colour | `dsContentColor(context, hue)` | darkens on light palettes / lightens on dark, keeps the hue |
| Blend helper | `mix(a, b, t)` | one shared lerp |
| Background | `AmbientBackground(child:, includeGlow:, accent:)` | `accent` = the module hue |
| Native widget palette | `widget/WidgetTokens.kt` | the Kotlin mirror; when a Dart hue changes, check it |

## 3. Template recipes (one per key from `00_…COVERAGE.md`)

| Template | Recipe |
|---|---|
| **Hero** | `HeroCardShell` + `ArcCountdown`/`RingView`; hue = section accent; ONE hero per page |
| **ListCard** | `SectionHeader` + `AppCard` rows (`SettingRow`/`IconTile`), 8 gap |
| **GridTiles** | `AppCard` + `IconTile` grid; duotone tiles via `mix(hue, white, .68)` (the More language) |
| **QuranChrome** | kit row + reader header; **page interior untouched** |
| **CalendarMonth** | `AppCard` grid + `SmallChip`/`BadgeChip` markers; Hijri basis per F-05 decision |
| **ReportGauge** | `RingView` for one headline number + `SegmentedTabs` for the breakdown (the evaluation language) |
| **SettingsRows** | `SettingRow` / `SliderRow` / `ValueStepper` only; `SegmentedTabs` for mode switches |
| **SimplePage** | `AmbientBackground` + `SectionHeader` + one `AppCard`; the 404/boot/onboarding language |
| **SheetDialog** | kit handle + radius + padding, `AppCard` content, drag-dismiss, one primary action |
| **SpecializedViewer** | canvas/painter surface: keep the painter, wrap the chrome in kit rows; no background of its own |
| **KeepNative** | Kotlin/XML only (widget, splash window, channels) — palette parity with `TopicHues`/`WidgetTokens.kt` |

## 4. States, motion, sheets, dialogs

- **States:** `loading` → skeleton or **indeterminate** indicator (a determinate bar at 0 is
  an empty track — that bug shipped once); `empty` → reason + a single action;
  `error` → Persian cause + **retry** (retry must resume, not restart, when the work is
  resumable); `offline` → say what still works. Never a silent failure, never a frozen
  progress bar (`PrompterSessionState.copyWith`'s sentinel is the reference).
- **Motion:** the phase durations only (`AppTheme.fastAnim`/`medAnim`); entrance ≤ 250 ms;
  nothing animates religious text size; haptics only on counter/complete actions.
- **Sheets:** max height 92 %, `isScrollControlled: true` when content can grow, radius from
  the kit, RTL order preserved, one primary action pinned at the bottom.
- **Dialogs:** `AlertDialog` only for destructive/confirm needs — everything else is a sheet.

## 5. Accessibility floor (per the user's own requirement)

1. Text scale 1.3 must not clip any row at 320 dp (extend the existing matrix; F-06/F-07).
2. Tap targets ≥ 48 dp, including the icon-only buttons in the reader header.
3. Contrast ≥ 4.5:1 — measure with the palette maths already in `mushaf_palette_test.dart`
   rather than by eye (that test caught 244/500 sub-floor pairs).
4. Every icon-only control carries a `Semantics` label; the painter-heavy screens must not
   hide the control from TalkBack.
5. TalkBack focus order follows the visual RTL order on every redesigned page.

## 6. Enforcement (PART 2 ships the tooling with the rules)

| Check | Artifact | Status |
|---|---|---|
| off-scale `fontSize` | `test/core/theme/type_scale_guard_test.dart` (exists) | **red today** (1 offender) |
| silent catches / `]!` / providers-in-widgets / share footers / `Color.lerp(…)!` / build-context / assets ≤14 MB | `tools/quality_check.py --strict` (exists, 7/7 zero) | green, must stay green |
| palette/painter allowlist + raw colour/fontSize/BoxShadow/BackgroundFilter counts | **new** `tools/design_consistency.py` (PART 2 deliverable; regenerates the `00` marker table) | to build |
| golden coverage per template | 85 PNG baselines (10 groups) today; add one group per newly migrated surface | partial |
| overflow matrix | exists for Home/More/Tasbih | extend |

## 7. What this contract explicitly does **not** change

- Religious content of any kind (text, order, tafsir, fiqh output). Design only.
- The mushaf rendering pipeline (`metric.bannerW × Qcf4Config.surahHeaderAspect`
  justification, the `clipData: FlClipData.all()` clip, the live-ayah wash search).
- The audio/download/mini-player logic; only its chrome.
- Kotlin widget/alarm behaviour; only its palette parity.
- Anything in `01_FINDINGS.md` marked `NEEDS-USER` (F-02/F-03/F-04/F-05) — a design pass
  never silently "fixes" a religious or product decision.
