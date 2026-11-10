# HOME_POLISH_REPORT.md — Home polish v2 (`home/polish-v2-ui`)

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


Base: `release/1.7.2` @ `7af8156`. Branch note: `home/polish-v2` already
exists (another session's tilawa work) — this work lives on
`home/polish-v2-ui` and never touches that branch.

## 0. Countdown bug (fixed first)

**Symptom:** the arc label said «تا اذان عصر» but the number equalled
time-to-iqama (02:36 while the adhan was 2h12m away).

**Root cause:** `PrayerSnapshot.countdownTarget` was `adhan + offset`
whenever a positive iqamah offset was configured
(`lib/features/prayer/domain/prayer_clock.dart`, old line ~207), while the
label named the adhan. One field served two meanings.

**Fix:** the snapshot now counts to the adhan only (`nextAdhanTime`); the
iqamah rides along as a separate nullable `iqamahTime` (null =
disabled/unknown = pill hidden). `countsToIqamah`/`countdownTarget` are
gone. Countdown, «تا پایان وقت», day-progress, rawatib «تا …» and the
timeline hint all derive from `PrayerSnapshot` / `prayerWindowBounds`, so
they cannot disagree. Format rule: ≥1h → `HH:MM` (minute subscription),
<1h → `MM:SS` (second subscription) + `(ساعت:دقیقه)` / `(دقیقه:ثانیه)`
suffix; `_Countdown` re-subscribes itself across the boundary.

## 1. Per-part changes

- **Part 1 hero** (`hero_card.dart`): 78×68 tiles (white 20→6% gradient,
  gold-60% 0.5px border, 48px w500 cream tabular); 46px seconds ring
  (white-18% track, gold arc, 13px number) on the `second` notifier inside
  a RepaintBoundary; date chips Row (no wrap: Flexible + FittedBox
  scaleDown, 10sp, white-14%, r10, gold/green/blue dots via
  `datePill*` tokens); horizon arc 306×112 (horizon line y=102, quadratic
  M14 100 / (153,-72) / (292,100), 7px white-18% track, gold-gradient
  elapsed, 5 PathMetric dots i/6, inner-side 9sp labels, sun r7.5 /
  crescent-by-difference marker with 22% halos, marker last); «تا اذان»
  11sp cream-85% + 30sp countdown inside; adhan (white-14%) + iqamah
  (gold-22%, bell) pills below; FittedBox + Semantics
  («خورشید بین ظهر و عصر، 2 ساعت و 12 دقیقه تا اذان عصر»); bg = palette
  gradient + bottom-center gold-30% glow + 4 stars, `lite` skips both;
  radius 26.
- **Part 2 prayer card** (`home_prayer_summary.dart`): 5-segment day bar
  (green/gold/soft-brown/shell + «N از 5 ثبت شده» / «بعدی: نام»); rows —
  DONE muted text + green check, passed-unchecked neutral dashed ring
  (no red), CURRENT gold-tint gradient + `heroGoldDeep` border r16 +
  «اکنون» badge + gold tile + 3px window-fraction line + «تا پایان وقت»,
  NEXT dashed-gold r14 + «بعدی» + «اقامه · HH:MM»; CheckCircle 23dp/160ms;
  windows from shared `prayerWindowBounds` (isha→midnight rollover, same
  as the tracker).
- **Part 3 rawatib** (`home_tab.dart` + `prayer_windows.dart`):
  `relevantRawatib()` single mapping (asr→∅) + tests; gold relevant chips
  with «تا H:MM», neutral parchment others, relevant-first, counter
  n/7 (6 sunnah + duha — the same convention خلاصه امروز already used),
  «پیشنهاد این وقت», «نمایش همه (N مورد دیگر)» expands in place.
- **Part 4 summary** (`daily_stats.dart`): `RingPainter` 66dp/6dp/round
  caps (green/gold/info-blue), % center, label + count below, track-only
  at zero; streak chip «N روز پیاپی» (flame, evaluation-coral fill) from
  `evaluationProvider`, hidden at 0/loading.
- **Part 5 timeline** (`daily_adhkar_box.dart`): 2dp rail (gold elapsed,
  shell rest) with dots, 86dp chips below, `itemExtent: 94`, highlighted
  actives, static anchors + live «H:MM دیگر» (snapshot) on the nearest
  upcoming chip; category logic/navigation untouched; blur shadow dropped.
- **Part 6 reminders** (`quick_reminders.dart`): rows already matched;
  added measurable 3dp lines — «N از 1 صفحه» (`readingStatsProvider`),
  «P٪ از ختم فعلی» (`khatmProvider`, hidden with no active khatm).
- **Part 7 nav** (`home_bottom_nav.dart`, new): six equal flex-1 pills
  h52 r18, icon-20-over-10px-label inside, active mocha→darkWalnut +
  gold + cream, inactive per-tab tints (contrast-verified, see below),
  180ms easeOutCubic color-only, haptics, Semantics(selected), FittedBox
  labels; `main_shell.dart` uses it (single usage — verified no other
  screen builds a tab bar).

## 2. Token mapping (mockup → existing; + = new in `AppColors`)

- E8C277 borders → `heroGoldDeep` (E0B25C); 7A5410 text →
  `strongAccent(goldRich)`; FFF6DA→FFFBF0 → +`currentPrayerTintStart/End`;
  cream FFF3DA → `AppPalette.cream`; goldLight icon → `heroGold`;
  active gradient 5A4032→2A1A12 → `mocha`→`darkWalnut`.
- Inactive nav: home → `linen`/`mocha`/`mocha` (8.18:1); quran tint
  +`navQuranTint`, icon `SectionHues.quran`, +`navQuranLabel` 176B4D
  (5.46:1 — 1F7A63 only reached 4.40); tasbih +`navTasbihTint`, icon
  `SectionHues.tasbih`, +`navTasbihLabel` 9A5F0F (4.56:1); calendar
  +`navCalendarTint`, icon `SectionHues.calendar`, +`navCalendarLabel`
  443C9A (7.26:1); report +`navReportTint`, icon +`navCoral` B8421C
  (spec D85A30 scored 2.99 — below 3:1 even for icons), label
  +`navDeepCoral` 8F3216 (6.15:1, shared with more); more +`navMoreTint`,
  icon `navCoral` (4.34:1 ✓ icon), label `navDeepCoral` (6.31:1).
- Type sizes snapped to `AppTheme.typeScale` (chips 10, arc labels 9 —
  the guard test pins this); dhikr blue → `AppColors.info` (theme-aware).

## 3. Verification

- `flutter analyze`: no errors/warnings; only pre-existing infos
  (foreign `mock_daos` warnings untouched).
- Tests: home + prayer + app/router + core/theme = **379 green**,
  incl. new countdown-format (9), arc semantics (3), window-bounds (1),
  relevance (2), nav (3), rawatib widget (3).
- Full suite: failures only in foreign-WIP/network areas, none in
  touched files — `browser_user_agent_client_fallback` (2, foreign
  worktree mods in `browser_user_agent_client.dart`),
  `dorar_search_live` (needs internet), `prompter_download_gate`
  (foreign prompter WIP), `mushaf_palette_render_audit` (untracked
  foreign scratch test). `type_scale_guard` failed on my 10.5/9.5 first
  — fixed to scale steps, now green.
- Release APK builds: `app-release.apk` (64.4MB).

## 4. Removed code

- `_SecondTile` (replaced by `_SecondsRing`); old `_ArcPainter`
  (shadow rail, sheen rail, tick marks, glow pass, leading sparkle, end
  anchors) replaced by `_HorizonArcPainter`; arc `timesLine` text
  (replaced by pills); `_AdhkarTab` (replaced by `_TimelineItem`);
  red/amber missed mark (icon + `missColor`); old `_navItem`
  pill-above-label nav; `countdownTarget`/`countsToIqamah` snapshot
  fields.

## 5. Open questions (need user/device)

1. Goldens (6 states + lite) not yet written — HomeTab needs heavy
   provider scaffolding; propose as follow-up.
2. `--profile` repaint/scroll/cold-start numbers need a low-end
   device (no device on ADB); design keeps per-second repaints inside
   the 46px ring + countdown-under-1h only.
3. On-device check of hero height (arc grew 92→112; gaps tightened to
   compensate) and 320dp rows at text-scale 1.3.
4. Report-tab icon uses darker coral B8421C (spec D85A30 failed
   contrast) — confirm acceptable.
5. Rawatib «7» = 6 sunnah + duha (matches خلاصه امروز) — confirm.
