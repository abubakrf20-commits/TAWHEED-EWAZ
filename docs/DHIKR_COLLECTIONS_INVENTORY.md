# Dhikr collections — inventory (2026-11-01)

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


All ten adhkar collections in the app are the ten `PrayerPeriod` sections of
`assets/azkar_content.json`. They have always shared **one** page — there are no
per-collection copies — and after this change they share one session controller
and one view-mode selector as well.

- Route: `/azkar/category` (`RouteNames.azkarCategory`, `app_router.dart`), args
  in `extra` as `AdhkarCategoryArgs(title, period, items, highlightQuery, focusId)`.
- Page: `lib/features/home/presentation/widgets/adhkar_category_page.dart`.
- Opened from: the home actions timeline (`actions_timeline_card.dart`) and the
  search results (`search_screen.dart`, with `focusId` + `highlightQuery`).
- Content: `assets/azkar_content.json` → `AzkarData.loadAll()` → `ZikrItem`
  (`id, title, arabicText, translation, virtue, source, period, repeatCount`).
- Progress: `azkarProvider` (`azkar_repository_impl` + `azkar_status_table`),
  one row per dhikr per **azkar day** (`AzkarDayBoundary.dayKey`, reset hour
  from settings). Counted adhkar keep a `count` map persisted in
  `SharedPreferences`; reaching `repeatCount` sets the row to `done`.
- Reset: the daily boundary only. «انتخاب همه» and «پاک کردن پیشرفت این مجموعه»
  are the manual overrides — neither existed as a reset-all before this change.
- Text-size settings read by the page: `appFontSizeProvider`,
  `largeArabicFontProvider`, `showArabicTextProvider` (all from
  `settings_selectors.dart`, untouched).
- Share/copy: `adhkar_share_screen` via `RouteNames.azkarShare` (share) and a
  clipboard copy with the «کپی شد» snackbar (copy). Neither changed.

| # | Period (`azkar_content.json`) | Persian title on the page | Items | Items with a repeat count | 
| - | ----------------------------- | ------------------------ | ----- | ------------------------- |
| 1 | `fajr` | فضائل و اذکار مربوط به نماز فجر | 12 | 0 |
| 2 | `shorouq` | فضائل و اذکار مربوط به طلوع آفتاب | 3 | 0 |
| 3 | `morningAzkar` | أذكار الصباح | 20 | 8 |
| 4 | `duhr` | فضائل و اذکار مربوط به نماز ظهر | 15 | 1 |
| 5 | `asr` | فضائل و اذکار مربوط به نماز عصر | 11 | 1 |
| 6 | `maghrib` | فضائل و اذکار مربوط به نماز مغرب | 2 | 1 |
| 7 | `eveningAzkar` | أذكار المساء | 21 | 9 |
| 8 | `isha` | فضائل و اذکار مربوط به نماز عشاء | 7 | 0 |
| 9 | `postPrayer` | أذكار ما بعد الصلاة | 8 | 0 |
| 10 | `night` | أذكار النوم واليقظة | 21 | 0 |

Total: **120 items**, 20 of them counted (`repeatCount > 1`).

## Items that need a data decision

None. Every item's repetitions come from the structured `repeatCount` field, and
a scan of all 120 Arabic texts found no item whose wording states a repetition
number while its `repeatCount` is 1 — so nothing is displayed as «یک بار» that
the text says otherwise. Nothing was inferred from text and no content was
edited.
