GENERAL RULES (both phases)
- Work on a new git branch per phase (phase1/redesign, phase2/audit). Small, focused commits with clear messages. Never force-push, never rewrite history.
- Keep a living file PROGRESS.md in the repo root (done / in progress / blocked / decisions). Update it after every major step so work can resume if the context is lost.
- Before changing anything: explore the repo (pubspec.yaml, lib/ tree, android/ config, assets, fonts, existing theme, state management, DB, notification code, widget code, tests, CI). Then write a SHORT plan and wait for my confirmation if something is ambiguous. Do not guess silently; list assumptions.
- RELIGIOUS CONTENT RULE: never edit, "fix", re-word, re-order or regenerate any Quran text, hadith/dua text, tafsir, fiqh rulings or their sources. If you suspect an error, only REPORT it (file, line/ID, why, suggested source to verify) in AUDIT_REPORT.md. Quran mushaf rendering (QCF4 fonts, page data, word timings) must keep working exactly as now; in the redesign only the chrome around it changes.
- Do not remove user data or break DB/prefs compatibility. Any schema/pref change needs a migration + test.
- No heavy new packages. Prefer what is already in pubspec. Every new dependency needs a one-line justification (size, license, maintenance).
- Target devices: weak Android phones (2-3 GB RAM, e.g. Samsung A13/A32 class), Android 7/8+ (check current minSdk and keep it unless I approve). Performance is a hard requirement, not a nice-to-have.
- Persian UI text stays Persian. Code, comments, commit messages in English.

################################################################################
# PHASE 1 — FULL REDESIGN OF THE WHOLE APP, THEN DEAD-CODE CLEANUP + TESTS
> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


################################################################################

STEP 1.0  Recon and baseline (before touching UI)
1. Produce docs/SCREEN_INVENTORY.md: every screen/route/dialog/bottom sheet/widget (including Android home-screen widgets, notification layouts, splash, onboarding, permission dialogs, error/empty/loading states, settings sub-pages, Quran sub-screens: index, search, bookmarks, tafsir, translation, audio, recitation follow-along, etc.). For each: file path, current purpose, which new-design template applies.
2. Record baseline metrics on a low-end device/emulator in --profile: cold start time, frame times (jank %) on Home / Quran / Tasbih, memory, APK/AAB size (flutter build apk --analyze-size), flutter analyze warning count, test results. Save to docs/BASELINE.md. These are compared at the end.
3. Put current screenshots (if I provide them in docs/design/old/) and implement against the spec below (docs/design/new/ may contain my mockups; the spec below is authoritative).

STEP 1.1  Design system (build ONCE, reuse everywhere)
Create lib/design/ (or the project's convention) with:

A) TimeTheme (ThemeExtension<TimeTheme>, implement copyWith + lerp). All pages are LIGHT; only tint changes by time-of-day phase. Phase comes from the app's own prayer times:
  dawn   (fajr -> sunrise):  pageBg F4F0FB, heroTop 8A7FD6, heroMid 5B4FA8, heroBottom 2E2A5E, cardBorder DDD6F3, ink 2E2A4A, inkMuted 6A6590
  day    (sunrise -> asr):   pageBg FFF8E8, heroTop 2FAE90, heroMid 1F8E75, heroBottom 0B4F3F, cardBorder F0E2BF, ink 3B2418, inkMuted 8A7565
  sunset (asr -> maghrib):   pageBg FDEDE6, heroTop E58A4F, heroMid C25A33, heroBottom 6E2A1E, cardBorder F5CDBB, ink 4A2418, inkMuted 8A5A4A
  night  (maghrib -> fajr):  pageBg EAF0F8, heroTop 3F5F9C, heroMid 2B4880, heroBottom 16294F, cardBorder C9D6EA, ink 1B2E52, inkMuted 5C6E91
  Shared: gold F3D58B, goldDeep E0B25C, goldDark B8862B, cream FFF6E0, emerald 1F7A63, card surface FFFFFF.
  MaterialApp rebuilds theme only when the phase changes (ValueNotifier<TimePhase>), themeAnimationDuration 800ms. Settings: theme mode "Automatic by time / Fixed day / Fixed night"; plus a hidden debug override to force each phase for screenshots/tests. Gold-on-light text must pass contrast (use goldDark/ink for text on light surfaces; gold F3D58B only on dark hero surfaces).

B) Shared infrastructure: ClockTicker (ONE app-wide timer aligned to second boundaries, exposes `second` and `minute` ValueNotifiers, pauses in background via WidgetsBindingObserver) and PrayerClock (ValueNotifier<PrayerSnapshot>: next adhan excluding sunrise, its time, arc progress, passed dots, phase; == compares progress in 1/600 steps so widgets do NOT rebuild every second). Per-second work must be limited to the countdown Text.

C) Reusable components (each with a widget test + golden):
  - AppCard: white, radius 22, 0.5px cardBorder, padding 10. NO heavy shadows.
  - SectionHeader: 4x18 gold vertical bar (gold -> goldDark gradient), title 14px w500 ink, optional count chip (pageBg/white fill, 11px), optional trailing widget.
  - HeroCard shell: radius 24, vertical gradient heroTop->heroMid->heroBottom, static CustomPainter background (soft radial gold glow + ~8 tiny stars at fixed fractions; no patterns, no mosque silhouette), `lite` flag disables glow/stars. Repaints only when theme colors change.
  - GlassChip (white 14% fill, gold icon, 11px white text), OutlineChip (gold 0.5px), SmallChip.
  - ArcPainter/ArcCountdown: wide quadratic arc (design space 306x92: M8 84, control 153 -56, to 298 84), track stroke 7px round caps white 20%, elapsed part gold gradient, 5 dots at i/6 of path length (passed = solid gold; next = gold ring with halo; others white 85%), marker = crescent (Path.combine difference) at night/dawn or sun disc at day/sunset. Used on Home and the Report score gauge (smaller variant).
  - RingPainter (progress ring, round caps, track tint + colored progress, center text) used for Daily Summary, Report, any goal ring.
  - IconTile (34-42px, radius 11-14, tint bg + accent icon), SettingRow (IconTile + title + subtitle + chevron), SliderRow (volume-style slider with gold/emerald fill, white round thumb with 3px colored border, value chip), Stepper chips, SegmentedTabs (active = heroTop->heroBottom gradient pill with gold icon), CheckCircle (22px, tinted border; done = emerald fill + check).
  - AppBottomNav: classic full-width bar (NOT floating): pageBg, 0.5px top border, SafeArea, 5 items RTL order Home, Quran, Tasbih, Calendar, More(+Report where it exists in the current nav; keep the CURRENT tab set and order). Each item = 46x30 pill (radius 15) with 20px icon + 10.5px label below. Inactive pills are tinted with their own accent (home E3ECFA/1F3560, quran DDF0E9/1F7A63, tasbih FAEEDA/BA7517, calendar E8E6FA/534AB7, report/more FADCD0/D85A30); active = 52px wide gradient pill (heroTop->heroBottom) with gold icon and w500 ink label; AnimatedContainer 200ms easeOutCubic; HapticFeedback.selectionClick.
  - Typography: keep the app font (Vazirmatn). Scale: title 16/500, section 14/500, body 13-13.5, caption 10.5-11.5, hero numbers 44-60 (tabular figures). Latin digits by default; add a setting "Persian digits" applied by one formatter used everywhere.
  - Spacing: page side padding 10, gap between cards 8, compact rows (6px vertical). Avoid big empty boxes.
  - Icons: Material rounded by default, or the Tabler set if the project already has it. Keep the prayer-row icons exactly as in the home spec below (moon, sunrise, sun, cloud, sunset, moon-stars).
  - Performance rules: no BackdropFilter/blur, no large-blur shadows, avoid Opacity/saveLayer (use color alpha), const everything static, RepaintBoundary around hero/arc/live parts, ListView.builder for long lists, no per-second rebuild of big subtrees.
  - Accessibility: min tap target 48dp (use InkResponse/padding), Semantics labels on icon-only buttons and rings/arcs, support text scale up to 1.3 without overflow (use Flexible/FittedBox and test), honor reduce-motion (disable non-essential animation), contrast >= 4.5:1 for body text.
  - RTL correctness everywhere (AlignmentDirectional, PositionedDirectional, EdgeInsetsDirectional); force LTR only for digit groups (clock, countdown, times).

STEP 1.2  Screen-by-screen redesign (ALL screens in the inventory; unseen screens must be derived from the same templates)
HOME (scrollable page, compact):
  1. Header: centered title, search icon at end.
  2. Hero card: top row (location+elevation glass chip | weekday outline chip); LTR clock row with hour/minute tiles 76x66 radius 18 (white 12% fill, 0.5px gold 50% border, 44px w500 cream tabular), two gold dots between, side column of two 42x30 mini tiles (Jalali day-of-month, AM/PM "ق.ظ/ب.ظ" in gold); date chips (Jalali, Hijri, Gregorian); WIDE ARC countdown at the bottom replacing the old countdown box, with next prayer name + time + "باقی‌مانده" and HH:MM:SS (26px gold, tabular) inside the arc. Clock tiles update per minute; only the countdown text updates per second.
  3. Prayer times card: KEEP the vertical list. Header = SectionHeader "اوقات شرعی" + phase chip (سحر/روز/غروب/شب) + share icon. Six rows: صبح, طلوع, ظهر, عصر, مغرب, عشاء; each row = IconTile (fajr E3E6FA/534AB7, sunrise FAEEDA/BA7517, dhuhr FFF3C9/BA7517, asr FCE8D2/C9822B, maghrib FADCD0/D85A30, isha E3E6FA/534AB7), name, time "h:mm ق.ظ/ب.ظ" (or 24h per setting), CheckCircle. NEXT row: gold 1px border, radius 14, horizontal gradient pageBg->FFF8E6, tile filled heroTop->heroBottom with gold icon, "بعدی" badge, time in heroBottom w500. Rows separated by 0.5px E3EAF4.
  4. Rawatib (سنن مؤکده) card: SectionHeader + counter chip (n/7). 2-column chips in chronological order, each with name line + "N رکعت · قبل/بعد" line (no truncated text) + CheckCircle; the one relevant to the current time gets gold border + small "اکنون" badge; "+ N مورد دیگر" if more.
  5. Daily summary card: three RingPainter rings (prayers, rawatib, dhikr) with icon in center, label, count.
  6. Actions timeline card ("تایم‌لاین اعمال", "مناسب این وقت"): horizontal timeline line with dots (elapsed part gold), chips below; time-appropriate chips highlighted (FFF1D6 / E0B25C border), others neutral; last chip partially visible to hint horizontal scroll.
  7. Reminders card ("یادآوری‌های امروز", counter chip): compact rows (~54px): IconTile + title + subtitle + CheckCircle + chevron, each with its own soft tint (purple dua, blue Quran reading, green khatm).
  Keep every existing behavior/data source of these widgets; only presentation changes. Suggested order: hero, prayer list, rawatib, daily summary, timeline, reminders (keep the current order unless it hurts UX; mention in report).
MORE (بیشتر): title; slim hero strip (next prayer + live countdown, same gradient); search field "جستجو در بخش‌ها" that filters the tiles; sections as AppCards with SectionHeader+count: "عبادات و مناسک" (نماز، قبله‌نما، وضو و طهارت، روزه، زکات، حج و عمره), "قرآن و ادعیه" (ختم، حفظ، مصحف حافظ، مصحف توحید، دعا، حصن المسلم), "ابزارها و پیشرفت" (ماه و منازل، میراث، آمارهٔ پیشرفت, plus any other existing item such as the hidden last tile — nothing may be lost). 3-column borderless tiles: 42x42 IconTile (keep each item's current accent color) + 12px label.
TASBIH: hero-like card (gradient + stars) with the dhikr text in 23px cream and a gold hairline; large beaded progress ring (dotted track via stroke-dasharray, gold progress arc, glowing inner button with radial gradient and gold ring, big count + "از N"); tap = small scale animation + haptic; dhikr chips row (selected = emerald fill); stats cards (this week, daily goal); keep existing modes (آرام/عادی/سریع), reset, change goal, add dhikr, previous/next, quick-tasbih mode and settings.
QURAN: only the chrome changes. Top bar: gradient heroMid->heroBottom with the existing actions (index, translation/tafsir, search, bookmark, reciter chip, repeat, more) in white/gold icons; surah/juz chips (gold-dark text on soft gold tint); mushaf page area keeps its paper color, QCF4 rendering, selection and word highlight untouched; current-ayah highlight keeps the soft green band; bottom audio player = rounded panel gradient heroMid->heroBottom with thin progress line, "سورة … — آیة N", status line, skip back / big gold play button / skip forward / stop, and the existing settings (tune) button. Also restyle Quran sub-screens (index, search, bookmarks, tafsir/translation sheets, download manager, recitation follow-along section if present) with AppCard/SectionHeader/SettingRow.
CALENDAR: title with convert-date icon; hero date card (chevrons, big Jalali date, Hijri · Gregorian line, "today" strip with locate button, "jump" outline chip and an upcoming-event/ayyam-al-bid pill); month grid in an AppCard: weekday header (Friday red), 38px cells radius 12; days with recorded worship = soft green tint + short gold underline; today = heroTop->heroBottom gradient with gold number; Fridays red; event dot (blue); legend row; selected-day AppCard with dual date, convert button, worship points chip and events list. Build the grid with GridView/Table, not 30 nested widgets with per-cell rebuilds.
REPORT (ارزیابی و گزارش): SegmentedTabs (daily/weekly/monthly); hero score card with the ArcPainter gauge (score big gold "20 / 140") and a status chip (keep the logic; use soft coral for "needs effort", gold for "good", emerald for "excellent" — choose wording that encourages rather than shames); streak AppCard (current/best, two cells); "جزئیات امروز" ring grid 4 columns (فرض، رواتب و وتر، روزه (dashed ring if no goal), طاعات، اذکار صبح/شام/خواب، تسبیح) each with its own color; tasbih details card with progress bars. Weekly/monthly tabs: matching charts (bar/line via CustomPainter or the existing chart lib) in AppCards.
SETTINGS: back arrow + title + search; groups with SectionHeader: ظاهر (font & display, theme mode, digits), نماز و اذان (adhan/iqama, Hijri date adjust stepper -5 -1 slider +1 +5 with value chip, location/method), صداهای برنامه (SliderRow: tasbih click 55%, alarm 60%), امتیازدهی عبادات, and every other existing setting (notifications, widgets, data/backup, about). Each setting row = IconTile + title + subtitle. Keep all keys/behaviors.
OTHER SCREENS (Qibla, Moon & Mansions, Wudu, Fasting, Zakat, Hajj/Umrah, Khatm, Hifz, Mushaf Hafez, Mushaf Tawheed, Dua, Hisn al-Muslim, Inheritance, Progress stats, onboarding, permissions, dialogs, empty/error/loading states): apply the same templates (title, optional hero strip, AppCard sections with SectionHeader, IconTile rows, ring/arc visuals where numeric). Qibla: gradient hero with a compass ring drawn by CustomPainter and a clear aligned/not-aligned state. Skeleton/shimmer loaders must be cheap (no blur).
ANDROID WIDGETS / NOTIFICATIONS: restyle the home-screen widgets and notification layouts with the same tokens (light pageBg of the current phase, gold accents, readable at small sizes); verify they still render on Samsung A13/A32 class devices.

STEP 1.3  Migration discipline
- Convert screens one by one; after each: flutter analyze clean, existing tests green, app runs. Commit per screen.
- Introduce the new components first, migrate screens, and only THEN delete the old ones (so the app always builds).
- Add the hidden debug phase override and use it to capture screenshots of each screen in all 4 phases into docs/design/screens/ (golden or manual).

STEP 1.4  Dead-code and old-design cleanup (separate commits, each verified)
Find and remove, with evidence that nothing references them:
- Old theme classes/constants/ThemeData pieces, old color palettes, old gradients, old shadows, old bottom-nav and card widgets, old painters, old pattern/background assets, unused icons/images/fonts/Lottie/audio assets, unused l10n strings, unused routes, feature flags that are always on/off, commented-out blocks, unused packages in pubspec.yaml, duplicate helper functions, stale TODO/FIXME that are already done.
- Tools to use: dart analyze + dart fix --apply (review diffs), flutter pub deps / pub outdated, grep for symbol/asset usage, an unused-files/unused-code checker (e.g. dart_code_linter or equivalent) , flutter build apk --analyze-size before/after, asset reference scan against pubspec assets, android/ unused resources (lint: UnusedResources).
- Never delete anything referenced via reflection/string keys, platform channels, Android manifest/XML, or native widget code without checking those places. When unsure, list it under "needs my decision" instead of deleting.

STEP 1.5  Testing and verification (all must pass)
- flutter analyze: zero errors/warnings introduced; add/extend lints (flutter_lints or stricter) if absent.
- Unit tests: computeSnapshot / phase detection (before fajr, between every prayer pair, after isha, midnight rollover, DST change days, polar edge), formatters (12/24h, Persian digits), arc progress mapping, ring math, theme lerp.
- Widget tests: each shared component; each main screen builds without overflow at text scale 1.0 and 1.3, RTL, small width (320dp) and large width (412dp).
- Golden tests: Home, More, Tasbih, Calendar, Report, Settings, Quran chrome x 4 phases (store goldens; keep fonts deterministic).
- Integration/smoke: launch, navigate every tab and every More tile, open every settings page, no exceptions in logs.
- Performance (flutter run --profile on a low-end device/emulator, DevTools): Home/Quran/Tasbih with no jank spikes, only the countdown repaints per second (verify with repaint rainbow), cold start not worse than baseline, APK size not larger than baseline + justified delta. Test `lite` mode on and off.
- Manual checklist docs/PHASE1_TEST_REPORT.md: for every screen: old vs new screenshot, states checked (loading/empty/error/offline/permission denied), phases checked, text scale checked.
- Release build must succeed: flutter build apk --release (and appbundle). Fix R8/ProGuard issues if any.

PHASE 1 DONE WHEN: every screen in SCREEN_INVENTORY.md is on the new design; no references to the old design remain; analyze clean; tests green; BASELINE vs AFTER metrics table is in docs/PHASE1_REPORT.md; list of removed files/packages/assets with sizes; list of "needs my decision" items. Then STOP and wait for my approval.