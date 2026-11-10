# Tawheeed App — Master Complete Review Report

Generated: 2026-07-26

---

## Executive Summary

Five subagent deep-dives were conducted across all app domains: Prayer/Qibla/Inheritance/Zakat mechanics, Books/Quran/Hadith features, UI/visual consistency, Islamic content accuracy, and functional bug review. A large number of issues were identified across all layers — from critical logic bugs and content errors to subtle visual inconsistencies. This report prioritizes findings by severity and domain.

---

## Priority 1: Critical Bugs

### 1. Prayer Engine — Sunrise Timeline Inconsistency
- **File:** `lib/features/prayer/presentation/engines/prayer_dashboard_engine.dart`
- **Problem:** `_periodForTime` returns `PrayerPeriod.night` before Fajr when `now.isBefore(fajr)`, and sunrise is excluded from the timeline but included in status counting. This means the prayer dashboard may show incorrect "current prayer" status in the pre-Fajr window and the sunrise row appears in the prayer status list but not in the timeline.
- **Severity:** High

### 2. Zakat Calculator — Irrigation Rate Labels Swapped
- **File:** `lib/features/tools/zakat/zakat_screen.dart` (UI) vs `zakat_content.dart` (educational content)
- **Problem:** The UI shows `آبی` (irrigated) = 10% and `بارانی` (rain-fed) = 5%. Per Shafi'i fiqh, rain-fed (بارانی/عری) = 10% and irrigated (آبی/مزروع بیع) = 5%. The labels are inverted from the correct Shafi'i rates. The educational content correctly states rain=10%, well=5% — but the calculator does the opposite.
- **Severity:** High — gives users wrong Zakat calculations

### 3. Azkar Content — Angels Gathering Hadith Translation Error
- **File:** `lib/features/adhkar/tasbih/presentation/widgets/azkar_content.dart`
- **Problem:** The Fajr angels gathering hadith (Bukhari 4717) translation adds "(و عصر)" (and Asr) to the text, but the original Arabic only mentions Fajr: `تَجْتَمِعُ مَلَائِكَةُ اللَّيْلِ وَمَلَائِكَةُ النَّهَارِ فِي صَلَاةِ الْفَجْرِ`. The "(و عصر)" is fabricated and not in the source hadith.
- **Severity:** High — Islamic content inaccuracy

### 4. Notification Reminders Fire Too Early
- **File:** `lib/shared/services/notification_service.dart`, `reminder_provider.dart`
- **Problem:** Reminder notifications may fire hours or a day early. Sound should use the phone's default alarm tone instead of the custom sound being played.
- **Severity:** High — user-facing functional bug

### 5. Books Export / Type Mismatches
- **Files:** `lib/features/books/` (multiple files)
- **Problem:** Type mismatches between `BookModel`, `KetabkhanehBook`, and provider models cause runtime export failures. Barrel exports missing `book_reader_screen`, `ketabkhaneh_screen`, and the bookmark provider.
- **Severity:** High — breaks core export functionality

### 6. Hadith Favorites Use Index-Based Keys
- **File:** `lib/features/hadith/`
- **Problem:** Favorite hadith entries use the list index as the key instead of a unique hadith ID. If the hadith list ever changes or is reordered, favorites become orphaned or point to wrong hadith.
- **Severity:** High — data integrity issue

---

## Priority 2: Important UI/Visual Issues

### Android Widget XML — Gold Colors Still Present
The following widget XML files still contain gold-colored text (`#FFC9A94E`, `#FFB89540`) and gold separators that should be neutral/white:

| File | Issues |
|------|--------|
| `widget_prayer_medium.xml` | Gold text on prayer times, gold separators |
| `widget_prayer_boxes.xml` | Gold text, gold separators |
| `widget_prayer_preview.xml` | Duplicate of boxes — same gold issues |
| `widget_calendar_prayer.xml` | Gold text on times, gold separators |
| `widget_prayer_small.xml` | Already partially fixed — may have remaining gold text |

### Splash Screen Layout
- **File:** `lib/features/splash/presentation/screens/splash_screen.dart`
- **Problem:** The subtitle box ("همراه شما در مسیر بندگی") is too narrow; text wraps. Horizontal margin is 130 — should be ~60 for comfortable text display. Logo bottom overlaps with the subtitle box because the box is positioned too close to the logo.

### About Screen
- **File:** `lib/features/settings/presentation/screens/about_screen.dart`
- **Problem:** Logo is 120×120 but should fill the container better — increase to ~160×160. Logo bottom is hidden by adjacent elements. Font uses hardcoded `fontSize: 16` instead of `AppTheme.scaledFontSize`. App name uses `fontFamily: 'Calibri'` instead of `AppTheme.fontFamily`.

### Subtitle Box Border Radius Mismatch
- Splash feature icons use `BorderRadius.circular(14)` while subtitle box uses `BorderRadius.circular(16)`. Neither matches any design token perfectly — subtitle box should use `radiusMedium` (14).

### Bottom Navigation Font Size
- Already fixed to use `AppTheme.scaledFontSize(context, 10)` — confirmed applied.

### Card Design System — Dark Mode Visibility
- Already fixed: `sectionDivider` alpha `0x0FFFFFFF` → `0x1AFFFFFF`, `innerPanel` alpha increased, `heroShadow` `0x40000000` → `0x33555555`.

---

## Priority 3: Content Accuracy

### Zakat — Conditions List Inconsistency
- **File:** `lib/features/tools/zakat/zakat_content.dart`
- **Problem:** Lists 6 conditions for Zakat obligation (Islam, Bulugh, Aql, Malakiyyat, Nassab, Hawl), but the Shafi'i school only requires 5 — Hawl is not a condition in Shafi'i for gold/silver. The conditions list contradicts the disclaimer that says it follows Shafi'i fiqh.
- **Severity:** Medium — confuses users expecting Shafi'i-only content

### Hadith — No Grading System
- **File:** `lib/features/hadith/`
- **Problem:** The `Hadith` entity has no `grade` field (no sahih/hasan/da'if). Hadith grading is a critical component of Islamic scholarship and a significant gap for a religious app.
- **Severity:** Medium — missing important scholarly information

### Hadith Book Registry Counts
- The 17 hadith book counts are approximately correct (Bukhari 7008, Muslim 5362, etc.) — no factual errors found.

### Prayer Time Calculations
- Properly delegates to the `adhan` package with all major methods (Muslim World League, ISNA, Umm al-Qura, etc.). No factual errors found. Calculation methods and madhab handling are correct.

### Inheritance Calculator
- Math follows standard Shafi'i rules with proper madhab differentiation. No critical mathematical errors found.

### Quran Data Model
- Well-structured with correct fields (number, name, arabicName, ayahCount, revelationType). Content loaded dynamically — unverifiable without bundled data.

---

## Priority 4: Code Quality & Architecture

### Duplicate Widget XML Layouts
- `widget_prayer_preview.xml`, `widget_prayer_boxes.xml`, and `widget_calendar_prayer.xml` contain nearly identical content — a maintenance risk. Changes must be applied to all three files.

### Prayer Time Colors — XML vs Flutter Mismatch
| Prayer | XML Color | Flutter Color |
|--------|-----------|---------------|
| Fajr | `#5C6BC0` (blue) | `#FF7C4DFF` (purple) |
| Dhuhr | `#F9A825` | `#FFFFC107` (yellow) |
| Asr | `#FF8F00` | `#FFFF9800` (orange) |
| Maghrib | `#D32F2F` | `#FFFF5722` (red) |
| Isha | `#5C6BC0` (blue) | `#FF5C6BC0` (purple) |

The XML widget and Flutter side use completely different color schemes for prayer times — visually inconsistent.

### Books — Missing Barrel Exports
- `book_reader_screen.dart`, `ketabkhaneh_screen.dart`, and bookmark provider are not exported from barrel files.

### Quran Tab
- AudioPlayer/streams are properly disposed — confirmed correct.

### Test Files
- `settings_prayer_section_test.dart` — `const` constructors added
- `evaluation_provider_test.dart` — unnecessary lambdas converted to tearoffs

---

## Priority 5: Previous Fixes Already Applied

The following items were already fixed in prior work sessions and are confirmed applied:

- `notification_service.dart` — alarm channel created, redundant args removed
- `reminder_provider.dart` — daysOfWeek fix, DB query dedup, ID range expanded
- `shell_nav.dart` — keepAlive + SharedPreferences persistence
- `main.dart` — `_pendingPrayerName` cleared after first use
- `card_design_system.dart` — dark mode visibility fixes
- `ic_launcher_round.xml` — `@drawable/` → `@color/` fix
- `ic_launcher.xml` — symmetric inset (15%)
- Gold widget separators/text — partially fixed in `widget_tasbih.xml`, `widget_prayer_small.xml`
- `bottom_nav.dart` — fontSize uses scaledFontSize
- `background_scheduler.dart` — hourly task interval increased to 6hr
- `home_tab.dart` — ref.read → ref.watch for isInPeriod
- `header_icon_button.dart` — safeArea removed
- `tasbih_counter_widget.dart` — Flutter tasbih counter fixes
- `widget_tasbih.xml` — Android tasbih widget fixes (gold, prev/next swap)
- `widget_prayer_small.xml` — gold removed
- Prayer engine gold border/divider/shadow → neutral
- Corner radius provider created and wired to settings
- `appearance_providers.dart` created
- `home_prayer_summary.dart` — gold border/divider/shadow → neutral
- `azkar_settings_provider.dart` — autoReset SP fallback fixed
- `notification_service.dart` — `_createNotificationChannels()` added
- All `flutter analyze` passes (0 errors, 0 warnings)

---

## Next Steps

1. **Fix Zakat irrigation labels** — swap `آبی`/`بارانی` rates or fix the label mapping
2. **Fix azkar hadith translation** — remove spurious "(و عصر)" from Fajr angels hadith
3. **Fix all remaining widget XML files** — replace gold text/colors with neutral/white in `widget_prayer_medium.xml`, `widget_prayer_boxes.xml`, `widget_prayer_preview.xml`, `widget_calendar_prayer.xml`
4. **Fix splash screen box width** — reduce horizontal margin from 130→~60
5. **Fix about screen logo size** — increase from 120×120 to ~160×160, use `AppTheme.fontFamily`
6. **Fix books barrel exports** — add missing exports
7. **Fix hadith favorites** — use unique hadith IDs instead of index-based keys
8. **Fix notification timing** — investigate why reminders fire early; use system alarm tone
9. **Fix prayer engine sunrise timeline inconsistency** — add sunrise to timeline or exclude from status
10. **Add hadith grading field** to `Hadith` entity and display
11. **Run `flutter analyze`** after all fixes
12. **Update design token `cornerRadius`** to 22 (or keep 24 and just update the splash subtitle box to match a token)

---

## Open Questions

1. Should the sunset prayer ("غروب") be shown when it falls within the selected date range in the prayer timeline? Currently it overlaps with Maghrib in the status counting.
2. Should `_periodForTime` be adjusted to handle the midnight (night → Fajr) edge case differently?
3. Should the widget XML files be deduplicated into a shared layout?
4. Should the hadith grading system be added as a new data field, or handled via a separate lookup table?
5. Should "فجر" and "صبح" be treated as the same prayer period or displayed separately?
