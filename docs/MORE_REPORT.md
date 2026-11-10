# «بیشتر» (More) redesign — final report

Branch `more/redesign`, cut from `release/1.7.2` at `b9f377d`.

> **Historical snapshot.** The counts below are the page as it was before `release/1.9.0`.
> The live split is **53 = 18/12/3/15/5** (عبادات/حدیث/صوتی/ابزارها/برنامه) and belongs to
> `docs/SECTIONS_1_9_0.md`; do not quote this file's numbers as current.
Approved design: **duotone card tiles with bold icons**, grouped sections,
target class Samsung A13/A32.

---

## 1. What changed

| Before | After |
| --- | --- |
| 5 hard-coded `_MoreSection` lists (38 entries) duplicated by the search filter | one `kMoreItems` registry (`more_registry.dart`) drives grid, search, badge-free list and tests |
| per-item `_MoreItem` sealed hierarchy (`_RouteItem`, `_WebItem`, `_LockedRouteItem`, `_AudioLibraryItem`) | one `MoreItem` + `MoreKind` enum |
| tiles: flat white `AppCard` per group, icon squircle + label, big row gaps | duotone tiles: tinted gradient surface, 0.5px accent border, decorative corner circle, gradient squircle with bold glyph, accent-darkened label, tight rows |
| hero strip: next prayer + countdown, tap did nothing | slim strip, gold-ringed phase icon, adhan + iqamah line, live `HH:MM:SS` countdown **to the adhan named on the strip**, tap jumps to the Home tab |
| search: `contains` on the raw label, ZWNJ-sensitive | 150 ms debounce + `normalizeMoreText` (Arabic/Persian letters, harakat, tatweel, ZWNJ, half-space, all whitespace, Persian/Arabic/Latin digits), keyword haystack, per-group count chip, empty-state card |
| utility entry: one `SettingRow` in its own card | final group «تنظیمات و بیشتر» as a `SettingRow` list (icon tile + title + subtitle + chevron, 0.5px separators) with **تنظیمات، پشتیبان‌گیری، ارسال پیشنهاد، درباره برنامه** |
| colors: `TopicHues` per item, label color = accent | colors: `TopicHues` accent in, seven derived surfaces out (`MoreDuotone`), label darkened until contrast ≥ 4.5:1 |

Files:

- `lib/core/design_system/components/tokens.dart` — added `mix(Color, Color, double)`.
- `lib/features/settings/presentation/more/more_registry.dart` — new (registry + normalization).
- `lib/features/settings/presentation/more/more_duotone.dart` — new (derived palette + WCAG contrast).
- `lib/features/settings/presentation/screens/more_screen.dart` — rewritten.
- `test/features/settings/presentation/more/*` — new unit tests.
- `test/features/settings/presentation/screens/more_*` — rewritten widget tests.
- `test/features/settings/presentation/screens/more_golden_test.dart` — new goldens.
- `test/core/design_system/kit_phase_golden_test.dart` — the four `more_*.png` loops moved out to the feature golden file (the kit sheet keeps its own four).

No route, no behavior, no religious text changed. Bottom navigation untouched.

Two rounds are folded in here: the rebuild itself, and the follow-up the user
asked for after seeing it — the six-section split and the three utility
destinations moved onto the page (§2).

---

## 2. Item inventory (41 entries, none lost)

Accents are the values the old page already used (`TopicHues`); the mockup hex
values were only needed where the code had no color, and it always had one.

The page has six sections. The spec named three; the two extra ones
(**حدیث و مطالعه**, **کتابخانه صوتی**) exist so no section is a one-tile orphan
and so hadith/reading sources are not mixed with Qur'an and supplications —
`more_registry_test.dart` pins the 7 / 5 / 10 / 3 / 12 / 4 split.

### عبادات و مناسک (7)

| id | title | icon | accent | kind → destination |
| --- | --- | --- | --- | --- |
| prayer | نماز | mosque_rounded | 00897B | route `/prayer` |
| qibla | قبله‌نما | explore_rounded | 2E7D32 | route `/qibla` |
| purification | وضو و طهارت | water_drop_rounded | 1976D2 | route `/tools/purification` |
| fasting | روزه | no_meals_rounded | 8E24AA | route `/fasting` |
| zakat | زکات | account_balance_rounded | F9A825 | route `/zakat` |
| hajj-umrah | حج و عمره | travel_explore_rounded | 795548 | route `/hajj-umrah` |
| ruqyah | رقیه شرعی | healing_rounded | 00A86B | route `/ruqyah` |

### قرآن و ادعیه (5)

| id | title | icon | accent | kind → destination |
| --- | --- | --- | --- | --- |
| khatm | ختم قرآن | menu_book_rounded | 1B5E20 | route `/khatm` |
| hifz | حفظ قرآن | workspace_premium_rounded | 00695C | route `/hifz` |
| mushaf-hafiz | مصحف حافظ | psychology_rounded | 00695C | web `https://muhaffidh.app/` |
| dua | دعا | bookmark_rounded | 2E7D32 | route `/dua` |
| duas | حصن المسلم | umbrella_rounded | 00897B | route `/duas` |

### حدیث و مطالعه (10)

| id | title | icon | accent | kind → destination |
| --- | --- | --- | --- | --- |
| riyad | ریاض الصالحین | local_florist_rounded | 558B2F | route `/riyad` |
| hadith-books | کتب حدیث | import_contacts_rounded | 00838F | route `/hadith/books` |
| dorar-hadith | جستجوی احادیث | search_rounded | BF360C | route `/dorar-hadith/search` |
| fatwa | فتاوای شرعی | gavel_rounded | 00695C | route `/fatwa` |
| hadeeth-enc | موسوعه احادیث | auto_awesome_mosaic_rounded | 1565C0 | route `/hadeeth-enc` |
| ketabkhaneh | کتابخانه | library_books_rounded | 8D6E63 | route `/books` |
| sciences | علوم اسلامی | school_rounded | 3F51B5 | route `/sciences` |
| study | مطالعه آزاد | auto_stories_rounded | 0097A7 | route `/study` |
| yaqeen | تثبیت یقین | verified_user_rounded | 37474F | lockedRoute `/yaqeen` (code `yaqeenLockCode` = 2323) |
| qaf-ai | هوش مصنوعی شرعی قاف | auto_awesome_rounded | 673AB7 | web `https://qaf.ai/fa` |

### کتابخانه صوتی (3)

| id | title | icon | accent | kind → destination |
| --- | --- | --- | --- | --- |
| audio-shubuhat | رد شبهات | policy_rounded | 37474F | audio `?cat=yaqeen` |
| audio-anasheed | اناشید اسلامی | music_note_rounded | 00838F | audio `?cat=anasheed` |
| audio-lectures | سخنرانی | record_voice_over_rounded | 7B1FA2 | audio `?cat=lectures` |

### ابزارها و پیشرفت (12)

| id | title | icon | accent | kind → destination |
| --- | --- | --- | --- | --- |
| moon | ماه و منازل | nights_stay_rounded | 283593 | route `/tools/moon` |
| inheritance | میراث | account_tree_rounded | 6A1B9A | route `/tools/inheritance` |
| goals | هدف‌گذاری | flag_rounded | 00897B | route `/goals` |
| personal-info | اطلاعات من | shield_rounded | 37474F | route `/personal-info` |
| tasks | مدیریت کارها | checklist_rounded | 1E88E5 | route `/tasks` |
| expenses | هزینه‌ها | monetization_on_rounded | E53935 | route `/expenses` |
| worship-notes | یادداشت‌ها | note_alt_rounded | F9A825 | route `/notes` |
| reminders | یادآورها | notifications_rounded | FB8C00 | route `/reminders` |
| period | دوره ماهانه | woman_rounded | EC407A | route `/prayer/period` |
| calculator | ماشین حساب | calculate_rounded | 607D8B | route `/tools/calculator` |
| pomodoro | پومودور | timer_rounded | E53935 | route `/tools/pomodoro` |
| dangi | دنگی | groups_rounded | 00ACC1 | route `/tools/dangi` |

### تنظیمات و بیشتر (4)

| id | title | icon | accent | kind → destination |
| --- | --- | --- | --- | --- |
| settings | تنظیمات | settings_rounded | 6D5A4A | route `/settings` |
| backup | پشتیبان‌گیری | backup_rounded | 37474F | route `/settings/account` |
| suggestions | ارسال پیشنهاد | rate_review_rounded | FB8C00 | route `/settings/suggestions` |
| about | درباره برنامه | info_rounded | 6D5A4A | route `/settings/about` |

**Placement notes:**

- The spec listed 15 items; the live page had 40 entries of which 38 were still
  reachable (see §5), plus the three utility destinations below.
- «پشتیبان‌گیری»، «ارسال پیشنهاد» و «درباره برنامه» are now **rows on this page**
  (user decision: they come directly here). پشتیبان‌گیری opens the real account /
  cloud-backup screen (`/settings/account`); the plain-ZIP export stays where it
  always was — a section inside the settings screen — because it has no route of
  its own (see §7).
- «تنظیمات و بیشتر» is the only section rendered as a `SettingRow` list; the
  other five are duotone tile grids.
---

## 3. Contrast (WCAG, computed on host)

`MoreDuotone.readableLabel()` walks mix steps (light: .40→.76 black, dark:
.50→.90 white) and returns the first color that clears **4.5:1 against both
the card surface and the tile's tinted top** (`mix(accent, card, .86)`).

Measured for all 38 accents on the gold palette (worst pair per theme):

| theme | worst card ratio | worst tint ratio | which accent |
| --- | --- | --- | --- |
| light | **5.06:1** | **4.60:1** | F9A825 (زکات / یادداشت‌ها) |
| dark | 5.87:1 | 5.63:1 | 6A1B9A (میراث) |

The two mockup hard cases are asserted separately in
`more_duotone_test.dart`: `D9922B` (amber) and `2B7FD6` (blue) both clear 4.5:1
on every palette the app can render (`gold/dawn/day/sunset/night` × light/dark).
Resulting label colors, e.g. amber → `956516`, blue (`1976D2`) → `0F477E`.

---

## 4. Performance

Banned-by-spec and verified by a widget test
(«the page stays flat: no blur and no drop shadows»): no `BackdropFilter`, no
`BoxDecoration.boxShadow` anywhere on the page.

What the page does instead:

- tints are `withValues(alpha)` colors, never `Opacity`/`saveLayer`;
- the only per-second widget is the countdown `Text`, inside its own
  `RepaintBoundary`; the strip itself is `const` and is not rebuilt by search
  filtering (asserted by the debounce test);
- the countdown subscribes to the shared `ClockTicker.second` only while the
  tab is visible (`TickerMode` notifier), same contract as the Home hero;
- derived colors are computed once per `(accent, brightness, card surface)` in
  a memo cache, not per frame;
- grid rows stay tight by aspect ratio (`tileWidth / (12 + 48 + 4 + label + 8)`
  ≈ 99dp at scale 1.0), `shrinkWrap` + `NeverScrollableScrollPhysics` as before.

**Not measured:** `--profile` frame times on a low-end device. No Android
device/emulator is attached to this environment, so the before/after jank and
repaint-rainbow numbers in the spec cannot be produced honestly — they need one
run of `flutter run --profile` on an A13/A32 class device. The structural
constraints above are what the measurement is expected to confirm.

---

## 5. Removed (verified unreferenced first)

- `more_screen.dart`: `_MoreTile`, `_MoreHeroStrip(+State)`, `_MoreSection`,
  the sealed `_MoreItem`/`_RouteItem`/`_LockedRouteItem`/`_WebItem`/
  `_AudioLibraryItem` family, `_sections`, `_norm`, `_buildGrid`, `_appAccent`,
  the file-level `yaqeenLockCode` (moved to the registry), and the
  `features/settings/settings.dart` barrel import.
- `test/core/design_system/goldens/more_{dawn,day,sunset,night}.png` — replaced
  by 12 goldens under
  `test/features/settings/presentation/screens/goldens/`
  (`more_*`, `more_search_*`, `more_empty_*` × four phases).
- No asset, icon or image file was deleted: the old page drew everything with
  `MaterialIcons` + `CustomPaint`, and every icon it used is still used
  (all glyphs moved to their `*_rounded` variants).
- «مصحف توحید» and «آمارهٔ پیشرفت» are **not** in the new registry, per the
  decision taken during this task (they were already removed from the app with
  the recitation tools; the guard test now asserts their absence).

---

## 6. Verification

| check | result |
| --- | --- |
| `flutter analyze` (changed areas) | 0 issues in this task's files (repo-wide: 90 pre-existing infos, 2 warnings in `test/core/database/mock_daos.dart`) |
| `flutter test` (full suite) | **3380 passed / 9 skipped / 0 failed** |
| More tests | registry 17, duotone 8, screen 17, dedup guard 1, goldens 12 = 55 |
| goldens | re-recorded on host (full page now 412×2260 for six sections); layout/palette guard only — the host test font has no Persian glyphs, so text renders as boxes in the PNGs |
| `python tools/quality_check.py --strict` | 6/7 zero; the one `]!` hit is `lib/features/prayer/data/place_index.dart:115`, from branch-base commit `b9f377d` (another session's file, untouched here) |
| on-device UI | **not verified** — no device attached |
| `flutter build apk --release` | √ from `d68ae30` — universal 67,492,562 B (sha1 `d0532da3`), arm64 41,958,447 B (`023dfe4e`), v7a 41,360,679 B (`fab611c1`); +1.1 KB over the `ca74525` build, +20.3 KB over the `ca6dd18` reference. Copied to `build/more-redesign-apk/` in the main tree (gitignored; it replaces this branch's previous build) |

---

## 7. Open questions

Answered during this task (user: «هر چی بنظرت مناسبتر هست» / «مستقیم اینجا
بیایند»):

1. ~~Split «قرآن و ادعیه»?~~ → the page now has six sections; the reading/hadith
   block is **حدیث و مطالعه** (10) and the audio tiles stand alone as
   **کتابخانه صوتی** (3).
2. ~~Utility rows inside تنظیمات?~~ → **پشتیبان‌گیری، ارسال پیشنهاد، درباره
   برنامه** are direct rows on «بیشتر» (see §2).

Still open:

3. «پومودور» is kept as the old page spelled it; the app's own screen title is
   «پومودورو». Which one wins?
4. Locked «تثبیت یقین» keeps the session-unlock behavior and the `2323` code.
   Remove the gate once that section ships?
5. Device pass still pending: countdown repaint smoothness, haptic on tile tap,
   Persian glyph fit at scale 1.3 (the golden set cannot show shaping).
6. The **plain-ZIP export** (local backup file) is still a section inside the
   settings screen, not a row here, because it has no route of its own — the
   new «پشتیبان‌گیری» row opens the cloud/account screen. Extracting that
   section into its own screen would make it reachable directly; it means
   editing `settings_screen.dart`, so it waits for a go-ahead.
