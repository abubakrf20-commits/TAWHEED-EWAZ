# SCREEN INVENTORY — Phase 1 redesign recon (فهرست کامل سطوح)

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


Base: branch `phase1/redesign` @ `3a532e5` (worktree `…/Temp/opencode/phase1-redesign`).
Status: **COMPLETE** — all 5 scan groups (shell/home/prayer · quran · adhkar/worship · settings/personal · knowledge/tools) done on 2026-10-06. Code bytes = `3a532e5` (docs-only commits above: `a994c95`, `7c4f635`).
Scope: every screen / route / dialog / bottom-sheet / widget surface, **plus** Android native surfaces (home-screen widgets, notification layouts, splash).
Visual references: `doc/design/old/` = 7 mockups, `doc/design/new/` = 7 current-app screenshots (main tree, untracked). **The Phase-1 spec text is authoritative**; images are style references only.

## راهنمای خواندن (legends)

- **وضعیت طراحی (Design status)** — مکانیکی از ایمپورت‌های فایل:
  - `new` = ایمپورت `lib/core/theme/time_theme.dart` یا `lib/core/design_system/*` یا استفاده از `HeroCard`/`AmbientBackground`/`TimeThemeKit`;
  - `partial` = هر دو سیستم جدید و قدیمی (`AppColors`/`Theme.of`) در یک فایل;
  - `legacy` = بدون ایمپورت سیستم جدید; `native` = کد Kotlin/XML; `n-a` = بدون UI.
  وضعیت **به‌ازای هر فایل** است؛ یک فایل `partial`/`legacy` ممکن است چند زیر‌ویجت مهاجرت‌کرده داشته باشد.
- **اولویت (Priority)** — چون اپ آفلاین است و Analytics ندارد، از این معیارها استفاده شد:
  - **High** = تبِ پوسته، یا صفحه‌ای که مشخصاً در اسپک فاز ۱ نام‌برده شده، یا مصرف روزانه + سابقهٔ شکایت کاربر؛
  - **Medium** = با ≤۲ گام از یک تب قابل دسترسی و مصرف هفتگی، یا مالکِ محتوای مهم (تنظیمات نماز، کتابخانه‌ها)؛
  - **Low** = صفحهٔ اشتراک‌گذاری، ویرایشگر، دیالوگ، تشخیصی، پنهان/فصلی، یا سطح بومی بدون اثر گرافیکی.
  LOC بزرگ و تعداد مصرف‌کننده در امتیازدهی دخیل بوده‌اند.
- **تست موجود (Tests)** — پایه: `test/…` @ `3a532e5` (۳۸۳ فایل تست، ۳۲۳۳ تست سبز):
  - ✅ = فایل تست مستقیم برای همین سطح/کلاس; ⚠️ = تست غیرمستقیم (تست‌های کلی‌تر فیچر)؛ ❌ = بدون تست.
- **⚿ = فایل محافظت‌شده در AGENTS.md** (ویرایش فقط با تأیید صریح کاربر). اسپک فاز ۱ بازطراحی *ظاهری* این صفحات را خواسته است؛ ولی هیچ تغییر منطق/مقادیر مجاز نیست.
- **قطعی (frozen)** = نباید بازطراحی شود: صفحهٔ مصحف (QCF4/صفحه‌آرایی)، `duas_screen.dart` (حصن المسلم).
- **قالب هدف (Target template)**: HomeHero · ListCard · GridTiles · QuranChrome · CalendarMonth · ReportGauge · SettingsRows · SimplePage · SheetDialog · SpecializedViewer · KeepNative.
- LOC = `wc -l` اعداد گزارش‌شده در `3a532e5`؛ دیالوگ/شیت‌ها = شمارهٔ خط سازنده.

---

## ۱. خلاصهٔ اجرایی (Executive summary)

- **۱۹۷ سطح** در جدول‌های گروه ۳ بازشناسی شد (صفحه/شیت/دیالوگ/ویجت/سطح بومی؛ اعداد از شمارش خودکار همین سند) — به‌علاوهٔ ۹ کامپوننت/گروه کامپوننت مشترک موجود و ۴۲ فایل >۱۰۰۰ LOC (پیوست ۱۰)؛ هر ۴۴ پوشهٔ `features/*/screens` زیر پوشش‌اند.
- **وضعیت توزیع‌شدهٔ طراحی:** هستهٔ سیستم جدید (`time_theme` + `core/design_system`) فقط توسط **۴ تب + ~۲۰ فایل** استفاده می‌شود؛ اکثریت قریب‌به‌اتفاق سطوح `legacy` یا `partial` هستند.
- **۷ تب/صفحهٔ اصلی اسپک (HOME→MORE→TASBIH→QURAN→CALENDAR→REPORT→SETTINGS)** همه هنوز `legacy/partial`اند — هیچ‌کدام «تمام‌شده» نیست.
- **۳ سیستم رنگ موازی** (بخش ۵) و **۸۶ فایل مصرف‌کنندهٔ `SectionColors`** — باید قبل از موج ۲ تک‌منبع شوند.
- **۱۲ کامپوننت مشترک اسپک وجود ندارد** (بخش ۴) و باید در گام ۱.۱ ساخته شوند: ArcPainter، RingPainter، GlassChip، OutlineChip، AppCard، IconTile، SettingRow، SliderRow، Stepper، SegmentedTabs، CheckCircle، AppBottomNav. `SectionHeader` فقط feature-local (education) هست.
- **۴۲ فایل >۱۰۰۰ LOC** (پیوست ۱۰) — گلوگاه‌های نگهداری؛ بازطراحی آن‌ها باید با احتیاط و تست انجام شود.
- **پوستهٔ پایین (bottom nav)** به‌صورت inline در `main_shell.dart` ساخته شده؛ `AppBottomNav` مستقل وجود ندارد (نمونهٔ اولیه در `desine/` هرگز promote نشد).
- **Quran chrome نیمه‌جدید است:** هدر/پلیر جدید (`time_theme`+`MushafPalette`) ولی شیت‌های قدیمی (`quran_mushaf_sheets.dart`، `mushaf_color_sheets.dart`) هنوز legacyاند. صفحهٔ مصحف (QCF4) **قطعی** است — فقط دور و برش تغییر می‌کند.
- **سطوح بومی (Android):** ویجت‌های صفحهٔ خانه/تسبیح، اسپلش بومی و اعلان‌ها از Flutter قابل‌ری‌استایل نیستند؛ فقط با ویرایش Kotlin/XML (بخش ۳.۱۰). سه layout و یک drawable مرده شناسایی شد (نامزدهای پاک‌سازی ۱.۴ با شاهد grep).
- **زیرساخت تست خوب است:** ماشین گلدن موجود (۳ فایل)، ۷۶ تست برای ابزارها، ۳۲ قرآن، ۳۱ نماز، ۲۳ تنظیمات — پایهٔ امنی برای موج‌های مهاجرت.
- **Baseline:** analyze ۸۰ مورد (۰ error)، gate هفت‌گانه ۷/۷ صفر، تست‌ها ۳۲۳۳/۳۲۳۳؛ APK فعلی ۴۹MB (جزئیات در `docs/BASELINE.md`).

## ۲. نقشهٔ پوسته و تب‌ها (Shell & tabs)

`lib/app/router/main_shell.dart` — ۶ تب `IndexedStack`، ساختِ تنبل (`_visitedTabs`)، ایندکس در `shellTabIndexProvider`؛ آیتم‌ها/رنگ‌ها در `_navItems` با `SectionHues`. تب‌ها **GoRoute نیستند** (کامنت صریح در `route_names.dart`: پوش‌کردن مسیرشان ۴۰۴ می‌دهد)؛ مسیرها فقط برای صفحات push شونده‌اند.

| # | برچسب | ویجت | فایل | نوع پیاده‌سازی | وضعیت |
|---|---|---|---|---|---|
| 0 | خانه | `HomeTab` | lib/features/home/presentation/screens/home_tab.dart | widget + scroll feed | partial |
| 1 | قرآن | `QuranTab` | lib/features/quran/presentation/screens/quran_tab.dart | host مصحف (73 LOC) | legacy (host) |
| 2 | تسبیح | `AzkarTasbihTab` (زیرتب تسبیح/اذکار) | lib/features/adhkar/presentation/screens/azkar_tasbih_tab.dart | 2 زیرتب + شیت تنظیمات | legacy |
| 3 | تقویم | `CalendarScreen` | lib/features/tools/calendar/presentation/screens/calendar_screen.dart | گرید ماه + ژورنال | partial |
| 4 | ارزیابی | `EvaluationTab` | lib/features/worship/presentation/screens/evaluation_tab.dart | پوشش نازک (21 LOC) | legacy |
| 5 | بیشتر | `MoreScreen` | lib/features/settings/presentation/screens/more_screen.dart | گرید دسته‌بندی‌شده ⚿ | legacy |

نکات پوسته:
- `MainShell` (317 LOC، partial): `AmbientBackground` (جدید) + `_buildBottomNav`/`_navItem` inline؛ ارتفاع/رنگ نوار امروز از `AppColors.surface`؛ آیتم فعال فعلی pill گرادیانی ندارد — **هدف اسپک: AppBottomNav** (pill شیشه‌ای 46×30، فعال 52px گرادیانی + آیکون طلایی).
- `_navItems` فعلی: خانه/قرآن/تسبیح/تقویم/ارزیابی/بیشتر — **همین ترتیب و مجموعه باید حفظ شود** (اسپک: keep CURRENT tab set and order).
- صفحهٔ ۴۰۴ (`_NotFoundScreen` در app_router) و `AppErrorBoundary` (core/error) — سطوح ساده.
- دیالوگ‌های مجوز موقعیت (boot_coordinator ⚿، یک‌بار در نصب) — هدف: SheetDialog.
- Splash فلاتر (366 LOC، legacy، gold های hardcode) + splash بومی (بخش ۳.۱۰) باید همگام بمانند؛ Onboarding ۳ مرحله‌ای (447 LOC، legacy).
- مسیرهای push: ۵۰+ ثابت در `route_names.dart` (zakat, prayer*, qibla, period, khatm, hifz, duas, dua, prompter(+stats), recitationLab, audioLibrary, hadith*, dorar*, riyad, fatwa, hadeethEnc(+detail), ketabkhaneh, sciences(+detail), study, yaqeen, tools/*, notes, tasks, expenses(+report), reminders(+edit), worshipChecklist, fasting, hajjUmrah, ruqyah, settings/*, personal-info/*, goals/*).

## ۳. صفحات به تفکیک گروه (Screens by group)

ستون‌ها: سطح | فایل | کلاس | ورود/مسیر | کارکرد | LOC | وضعیت | اولویت | تست | قالب هدف | شاهد.

### ۳.۱ پوسته، راه‌اندازی، اسپلش، آنبوردینگ (Shell & boot) — اسکن A

| سطح | فایل | کلاس | ورود/مسیر | کارکرد | LOC | وضعیت | اولویت | تست | قالب هدف | شاهد |
|---|---|---|---|---|---|---|---|---|---|---|
| ریشهٔ اپ | lib/main.dart | `TawheedApp` | root MaterialApp.router | اتصال تم فاز زنده، TextScaler سراسری، error boundary | 344 | partial ⚿ | High | ⚠️ | — (سیم‌کشی) | theme + time_theme |
| پوسته | lib/app/router/main_shell.dart | `MainShell` | RouteNames.shell `/` | AmbientBackground + IndexedStack ۶ تب + نوار پایین | 317 | partial | High | ✅ | SpecializedViewer→AppBottomNav | ambient + time_theme + AppColors |
| ۴۰۴ | lib/app/router/app_router.dart | `_NotFoundScreen` | errorBuilder | پیام فارسی + بازگشت | ~40 | legacy | Low | ✅ | SimplePage | Material تنها |
| دیالوگ موقعیت/GPS | lib/app/state/boot_coordinator.dart | `_showLocationDialog` | بوت پوسته (یک‌بار) | GPS خاموش / مجوز مکان | ~40 | legacy ⚿ | Low | ⚠️ | SheetDialog | Theme.of |
| مرز خطا | lib/core/error/error_boundary.dart | `AppErrorBoundary` | wrap هر مسیر | صفحهٔ خطای قابل‌بازیابی | ~100 | ? | Low | ✅ | SimplePage | — |
| Splash | lib/features/splash/presentation/screens/splash_screen.dart | `SplashScreen` (+`_FeatureItem`) | RouteNames.splash | زمینهٔ طلایی + لوگو + تصمیم shell/onboarding | 366 | legacy | Medium | ✅ | SimplePage | golds ثابت + goldRich |
| آنبوردینگ | lib/features/onboarding/presentation/screens/onboarding_screen.dart | `OnboardingScreen` | RouteNames.onboarding | ۳ گام: مکان → اعلان/آلارم → تم | 447 | legacy | Medium | ✅ | SimplePage | Theme.of فقط |

### ۳.۲ خانه — تب ۰ (اسکن A)

| سطح | فایل | کلاس | ورود/مسیر | کارکرد | LOC | وضعیت | اولویت | تست | قالب هدف | شاهد |
|---|---|---|---|---|---|---|---|---|---|---|
| تب خانه | lib/features/home/presentation/screens/home_tab.dart | `HomeTab` (+`RawatibSection`,`_RawatifChip`) | tab 0 | فید: hero، اوقات، رواتب، آمار، اذکار، یادآور، جمعه، طاعات، اهداف، دسترسی سریع، باتری | 336 | partial | High | ⚠️/✅ رواتب | HomeHero | hero_card + glass + AppColors×9 |
| Hero ماه و اذان | lib/features/home/presentation/widgets/hero_card.dart | `HeroCard` (+`_HeroBackgroundPainter`,`_LiveClock`,`_ArcCountdown`,`_ArcPainter`,`_GlassChip`…) | inline تب ۰ | ساعت زنده + تاریخ ۳گانه + کمان شمارش معکوس اذان/اقامه | 934 (~135 کلاس) | partial | High | ✅ | HomeHero | time_theme + AppColors×2 |
| کارت اوقات شرعی | lib/features/home/presentation/widgets/home_prayer_summary.dart | `HomePrayerSummary` | inline | ۶ ردیف نماز + تیک‌ها + بنر حیض | 777 | legacy | High | ✅ | ListCard | AppColors×14 |
| آمار روز | lib/features/home/presentation/widgets/daily_stats.dart | `DailyStatsSection` | inline | شمارش نماز/اذکار/ضحی | 169 | partial | High | ✅ | ReportGauge | glass + AppColors×5 |
| اذکار روزانه | lib/features/home/presentation/widgets/daily_adhkar_box.dart | `DailyAdhkarBox` | inline → ارسال ذکر | چک‌لیست اذکار وقت | 1090 | partial | Medium | ✅ | ListCard | glass + AppColors×27 |
| یادآورهای امروز | lib/features/home/presentation/widgets/quick_reminders.dart | `QuickReminders` | inline | دعای روز + یادآورها | 474 | partial | High | ✅ | ListCard | glass + AppColors×23 |
| آداب جمعه | lib/features/home/presentation/widgets/friday_adab_card.dart | `FridayAdabCard` | inline (جمعه) | کارت بازشو + اشتراک | 322 | legacy | Low | ✅ | ListCard | AppColors×11 |
| طاعات امروز | lib/features/home/presentation/widgets/worship_today_card.dart | `WorshipTodayCard` | inline → چک‌لیست | حلقه + زنجیره + امتیاز | 262 | partial | Medium | ⚠️ | ListCard | glass + AppColors×8 |
| اهداف | lib/features/home/presentation/widgets/home_goals_card.dart | `HomeGoalsCard` | inline → اهداف | پیشرفت اهداف امروز | 144 | partial | Medium | ⚠️ | ListCard | glass + AppColors×5 |
| دسترسی سریع | lib/features/home/presentation/widgets/quick_actions.dart | `QuickActions` | inline (+۲ دیالوگ L153/265) | گرید ۳ستونه قابل‌سفارشی | 395 | partial | Medium | ✅ | GridTiles | glass + AppColors×7 |
| بنر حیض | lib/features/home/presentation/widgets/period_hayz_banner.dart | `PeriodHayzBanner` | inline (داخل کارت اوقات) | یادداشت ایام حیض | 56 | legacy | Low | ✅ | ListCard | theme + section_colors |

نکات خانه: ترتیب فعلی = hero → اوقات → رواتب → آمار → اذکار → یادآورها → جمعه → طاعات → اهداف → دسترسی سریع (اسپک پیشنهادی: hero، اوقات، رواتب، خلاصهٔ روز، تایم‌لاین، یادآورها؛ نگه‌داشتن ترتیب فعلی در گزارش نهایی باید ذکر شود). هر ۶ ردیف نماز و ۷ آیتم رواتب منطق موجود را حفظ می‌کنند — فقط ارائه عوض می‌شود.

### ۳.۳ نماز، قبله، دورهٔ ماهانه (اسکن A)

| سطح | فایل | کلاس | ورود/مسیر | کارکرد | LOC | وضعیت | اولویت | تست | قالب هدف | شاهد |
|---|---|---|---|---|---|---|---|---|---|---|
| «نماز» راهنما | lib/features/prayer/presentation/screens/prayer_screen.dart | `PrayerScreen` (+۷ تب) | RouteNames.prayer | ۷ تب آموزشی | 580 | legacy | Medium | ✅ | SimplePage | AppColors×7 + SectionColors |
| تنظیمات نماز و اذان | lib/features/prayer/presentation/screens/prayer_settings_screen.dart | `PrayerSettingsScreen` (+`_CompactStepper`…) | RouteNames.prayerSettings | صدا/فایل اذان، روش، زوایا، مذهب، شهر، دقایق اعلان، سایلنت | 1263 | legacy | High | ⚠️ | SettingsRows | AppColors×17 |
| انتخاب شهر | lib/features/prayer/presentation/widgets/city_picker_sheet.dart | `CityPickerSheet` | sheet | جداول آفلاین + ژئوکد آنلاین | 175 | legacy | Medium | ⚠️ | SheetDialog | AppColors×2 |
| شیت‌های روش/جزئیات محاسبه | lib/features/prayer/presentation/widgets/prayer_calc_widgets.dart | `showCalculationMethodPicker` + `PrayerCalculationDetailsSheet` | sheets | روش محاسبه + همهٔ ورودی‌ها پشت اوقات امروز | ~78/~160 | legacy | Medium | ✅ | SheetDialog | AppColors×9 |
| قبله | lib/features/prayer/presentation/screens/qibla_screen.dart (+parts 480/56) | `QiblaScreen` | RouteNames.qibla | قطب‌نما sensor-rate، فاصله، سایه/ماه، نقشه، اشتراک | 1673 | legacy | High | ⚠️ | SpecializedViewer (hero + حلقهٔ قطب‌نما) | AppColors×16 |
| دیالوگ‌های قبله | qibla_screen.dart L372/L625 | — | dialogs | GPS/مجوز + راهنمای اولین‌بار | ~60 | legacy | Low | ⚠️ | SheetDialog | AppColors |
| دورهٔ ماهانه | lib/features/prayer/presentation/screens/period_screen.dart | `PeriodScreen` (+`PeriodQadaFastingSection`) | RouteNames.period | ردیابی سیکل، تقویم، نمودار، گزارش، قضای روزه، قفل PIN | 573+~187 | legacy ⚿ | Medium | ✅ | SpecializedViewer | AppColors×10 + SectionColors |
| کتابخانهٔ سکشن‌های دوره | lib/features/prayer/presentation/widgets/period_widgets.dart (+۶ part) | `PeriodStatusCard`,`PeriodCalendarSection`,… | inline | وضعیت/تقویم/نمودار/گزارش/قفل/احکام/تاریخچه/بارداری + کنترل‌ها | 54+478+612+443+290+295+348+206 | legacy ⚿ | Medium | ✅/⚠️ | SpecializedViewer | theme+AppColors+SectionColors |
| شیت ثبت روز | period_day_sheet.dart (part) | `showPeriodDayActions` | sheet | شروع/پایان، خون‌ریزی، استحاضه، علائم، یادداشت | 348 | legacy ⚿ | Medium | ⚠️ | SheetDialog | part file |
| دیالوگ‌های دوره (۷) | period_screen L175/252/302/358/429 … | — | dialogs | PIN/حذف/ویرایش/قضا/حذف تاریخچه | ~200 | legacy ⚿ | Low | ⚠️ | SheetDialog | AppColors |
| PDF گزارش دوره | lib/features/prayer/presentation/widgets/period_report_pdf.dart | `buildAndSharePeriodReport` | action | رندر+اشتراک PDF (بدون UI) | 157 | legacy ⚿ | Low | ⚠️ | — | n/a |
| بهینه‌سازی باتری | lib/features/prayer/presentation/screens/battery_optimization_screen.dart | `BatteryOptimizationScreen` | RouteNames.batteryOptimization | راهنمای Doze به‌تفکیک برند | 272 | legacy | Low | ✅ | SimplePage | AppColors×5 |
| انتخاب روی نقشه | lib/features/prayer/presentation/screens/map_picker_screen.dart | `MapPickerScreen` (+دیالوگ مختصات L163) | RouteNames.mapPicker | پین‌گذاری، ژئوکد معکوس، ارتفاع | 406 | legacy | Medium | ⚠️ | SpecializedViewer | AppColors×11 |
| اشتراک اوقات شرعی | lib/features/prayer/presentation/screens/prayer_times_share_screen.dart | `PrayerTimesShareScreen` | RouteNames.prayerTimesShare | کارت کرم امروز/فردا + نوار ۴تقویم + PNG/متن | 705 | legacy | Medium | ⚠️ | SpecializedViewer | AppColors×3 + cream ثابت |
| پیش‌نمای ویجت نماز | lib/features/prayer/presentation/widgets/prayer_widget_preview.dart | `PrayerWidgetPreview` | inline در تنظیمات ویجت | ماکِت Flutter ویجت بومی با شمارش زنده | 439 | legacy | Medium | ⚠️ | SpecializedViewer | رنگ‌های پیش‌فرض hardcode |

نکات نماز: منطق محاسبه (Phase-6) در برابر مرجع NOAA تست شده — **دست نزنید**. `period` محافظت‌شده است (⚿) — فقط ظاهر با تأیید. مورد مشکوک: `period_section.dart` (206 LOC) با صفر نقطهٔ instantiation در lib — کاندید حذف در ۱.۴ (تأیید کاربر در §۷.۵).

### ۳.۴ قرآن و مصحف، ختم، حفظ، دعا، ملقّن، کتابخانهٔ صوتی (اسکن B)

#### ۳.۴.۰ پوستهٔ خواننده (chrome — قابل بازطراحی؛ قالب QuranChrome)

| سطح | فایل | کلاس | ورود/مسیر | کارکرد | LOC | وضعیت | اولویت | تست | قالب هدف | شاهد |
|---|---|---|---|---|---|---|---|---|---|---|
| تب قرآن (host) | lib/features/quran/presentation/screens/quran_tab.dart | `QuranTab` | tab 1 | سوارکردن خواننده + مسیریابی ناوبری معلق | 73 | legacy (host) | High | ⚠️ | QuranChrome | بدون ایمپورت تم |
| خوانندهٔ مصحف | lib/features/quran/mushaf/quran_mushaf_view.dart (+۷ `part of`) | `QuranMushafView` | inline در تب | خوانندهٔ ۶۰۴صفحه‌ای — CHROME قابل تغییر، PAGE قطعی | 2417 (+parts) | new (عملاً `MushafPalette` خصوصی) | High | ✅ | QuranChrome | AppPalette.heroGold (۴جا) |
| نوار بالای خواننده | quran_mushaf_view.dart L1517–1806 | `_buildHeader`/`_hdrIcon`/`_hdrMoreMenu` | overlay | فهرست سوره‌ها، رفتن‌به، جستجو، نشانها، قاری، تکرار حفظ، «بیشتر» | ~290 | new | High | ✅ | QuranChrome | AppPalette + MushafPalette |
| پلیر تلاوت | lib/features/quran/mushaf/quran_mushaf_players.dart L5–348 | `_MiniPlayer` | overlay پایین | play/pause، ناوبری آیه، تکرار، سرعت، تایمر خواب | ~344 | new | High | ✅ | QuranChrome | part of view |
| پلیر ترجمهٔ صوتی | quran_mushaf_players.dart L349–589 | `_TranslationMiniPlayer` | overlay پایین | کنترل‌های پخش ترجمهٔ صوتی | ~241 | new | Medium | ✅ | QuranChrome | part of view |
| overlayهای خواننده | lib/features/quran/mushaf/quran_mushaf_overlays.dart | `_PageLoadErrorCard`,`_FullscreenExitChip`,`_PageCornerInfo`,`_PageSideIcon` | overlay | خطای صفحه + خروج تمام‌صفحه + شمارهٔ صفحه/کناره | 276 | new | Medium | ⚠️ | QuranChrome | MushafPalette |
| شیت اقدامات آیه | quran_mushaf_view.dart L996–1141 | inline `_showVerseActions` | sheet (تپ آیه) | پخش آیه، تفسیر، ترجمه، ترجمهٔ صوتی، نشان، هایلایت، اشتراک | ~146 | new | High | ✅ | SheetDialog | same file |
| انتخاب هایلایت | quran_mushaf_view.dart L1169–1218 | `_showAyahHighlightPicker` | sheet | رنگ ثابت آیه + حذف | ~50 | new | Low | ✅ | SheetDialog | same file |
| تنظیمات مطالعه | quran_mushaf_view.dart L1229–1319 | `_showReadingSettingsSheet` | sheet | پس‌زمینه، رنگ تلاوت، قفل افقی، تمام‌صفحه | ~91 | new | Medium | ⚠️ | SheetDialog | same file |
| انتخاب رنگ پس‌زمینه | lib/features/quran/mushaf/mushaf_color_sheets.dart L117–180 | `MushafBackgroundPickerContent` | sheet | گرید سواچ کاغذ مصحف | ~64 (file 795) | legacy | Medium | ⚠️ | SheetDialog | theme + mushaf_palette |
| انتخاب رنگ تلاوت | mushaf_color_sheets.dart L181–234 | `MushafRecitationPickerContent` | sheet | سواچ رنگ آیهٔ در حال تلاوت | ~54 | legacy | Medium | ⚠️ | SheetDialog | theme + mushaf_palette |
| مدیر دانلود ترجمه/تفسیر | lib/features/quran/mushaf/quran_mushaf_sheets.dart L21–359 | `MushafContentSheet` | sheet («بیشتر») | دانلود/حذف آفلاین ترجمه و تفسیر | ~339 (file 720) | legacy | Medium | ✅ | SheetDialog | theme + mushaf فقط |
| شیت تفسیر آیه | quran_mushaf_sheets.dart L392–720 | `MushafTafsirSheet` | sheet | متن تفسیر + پیمایش + اشتراک | ~329 | legacy | Medium | ✅ | SheetDialog | theme + mushaf فقط |
| دانلود آفلاین تلاوت | lib/features/quran/mushaf/quran_mushaf_pre_download_sheet.dart | `_PreDownloadSheet` | sheet | مدیر دانلود: سوره/کل/جزء، حذف، قاری + گروه ترجمهٔ صوتی | 1080 | new | Medium | ⚠️ | SheetDialog | part of view |
| دانلود QCF4 | lib/features/quran/mushaf/quran_mushaf_qcf4_sheet.dart | `_Qcf4DownloadSheet` | سکشن داخل پیش‌دانلود (L211) | ۶۰۴صفحه + ۴۸ فونت: دانلود/توقف/حذف | 416 | new | Medium | ⚠️ | SheetDialog | part of view |
| انتخاب قاری | lib/features/quran/mushaf/quran_mushaf_small_sheets.dart L5–194 | `_ReciterSheet` | sheet | جستجو/لیست قاری | ~190 (file 416) | new | Medium | ⚠️ | SheetDialog | part of view |
| رفتن به (صفحه/سوره/جزء) | quran_mushaf_small_sheets.dart L195–~340 | `_GoToDialog` | dialog | پرش شماره‌ای | ~145 | new | Medium | ⚠️ | SheetDialog | part of view |
| شیت ترجمهٔ فارسی صفحه | lib/features/quran/mushaf/quran_mushaf_content_sheets.dart L3–279 | `_TranslationSheet` | sheet | لیست ترجمه + fallback دانلود | ~277 (file 556) | new | Medium | ⚠️ | SheetDialog | part of view |
| پیروی از تلاوت (لیست آیات) | quran_mushaf_content_sheets.dart L280–416 | `_VerseFollowSheet` | sheet | لیست خوداسکرول همزمان با تلاوت | ~137 | new | Medium | ⚠️ | SheetDialog | part of view |
| تایمر خواب | quran_mushaf_view.dart L2036–2135 | `_showSleepTimerDialog` | sheet | چیپ‌های دقیقه | ~100 | new | Low | ⚠️ | SheetDialog | same file |
| تکرار برای حفظ | quran_mushaf_view.dart L1825–2034 | `_showRepeatRangeDialog` | dialog | تکرار بازهٔ آیه N بار | ~205 | new | Low | ⚠️ | SheetDialog | same file |

#### ۳.۴.۱ زیرصفحه‌های قرآن

| سطح | فایل | کلاس | مسیر | کارکرد | LOC | وضعیت | اولویت | تست | قالب هدف | شاهد |
|---|---|---|---|---|---|---|---|---|---|---|
| فهرست سوره‌ها | lib/features/quran/mushaf/quran_surah_list_screen.dart | `QuranSurahListScreen` (+`_DailyVerseCard`) | push از هدر | لیست+جستجو + hero آیهٔ روز (TimeThemeKit) | 377 | new | High | ✅ | ListCard | time_theme |
| جستجوی قرآن | lib/features/quran/mushaf/quran_search_screen.dart | `QuranSearchScreen` | push از هدر | جستجوی متن کامل | 254 | legacy | Medium | ✅ | ListCard | theme + MushafPalette |
| نشان‌های قرآن | lib/features/quran/presentation/screens/quran_bookmarks_screen.dart | `QuranBookmarksScreen` | push از هدر | لیست نشان‌ها + حذف | 167 | legacy | Medium | ⚠️ | ListCard | AppColors |
| اشتراک آیات | lib/features/quran/mushaf/quran_ayah_share_screen.dart | `QuranAyahShareScreen` | از شیت آیه | پیش‌نمای اشتراک متن/تصویر بازه | 568 | legacy | Low | ⚠️ | SimplePage | AppColors |
| اشتراک تفسیر | lib/features/quran/mushaf/quran_tafsir_share_screen.dart | `QuranTafsirShareScreen` | از شیت تفسیر | اشتراک بازهٔ تفسیر | 594 | legacy | Low | ⚠️ | SimplePage | AppColors |
| **صفحهٔ مصحف (FROZEN)** | lib/features/quran/mushaf/qcf4/qcf4_page_viewer.dart | `Qcf4PageViewer` | pager داخلی | رندر صفحهٔ مدینه از JSON + QCF4 (هایلایت/انتخاب) | 1016 | legacy (frozen) | — (قطعی) | ✅ | KeepNative | qcf4 internals |
| سرِ سوره (FROZEN) | lib/features/quran/mushaf/qcf4/qcf4_surah_header.dart | `SurahHeader` (+`_HeaderPainter`) | داخل صفحه | بنرهای چاپی سر سوره | 527 | legacy (frozen) | — | ✅ | KeepNative | qcf4 |
| صفحه‌آرایی (FROZEN) | lib/features/quran/mushaf/qcf4/qcf4_page_chrome.dart | `Qcf4PageChrome` | helper | juz/شمارهٔ صفحه/ترتیبی | 99 | n-a (frozen) | — | ✅ | KeepNative | — |

#### ۳.۴.۲ ختم قرآن

| سطح | فایل | کلاس | مسیر | کارکرد | LOC | وضعیت | اولویت | تست | قالب هدف | شاهد |
|---|---|---|---|---|---|---|---|---|---|---|
| ختم قرآن | lib/features/khatm/presentation/screens/khatm_screen.dart | `KhatmScreen` | `/khatm` | داشبورد ختم فعال: پیشرفت، گرید جزء، یادآور، افزودن/اعضا/حذف | 879 | legacy | Medium | ✅ | ListCard | AppColors + SectionColors |
| گزارش ختم | lib/features/khatm/presentation/screens/khatm_stats_screen.dart | `KhatmStatsScreen` | push | نمودار ماهانه/هفتگی + heatmap + گزارش متنی | 1190 | legacy | Medium | ✅ | ReportGauge | AppColors + SectionColors |
| دیالوگ ختم جدید | khatm_screen.dart L175–~345 | inline AlertDialog | dialog | نوع/روزها/اعضا | ~170 | legacy | Low | ✅ | SheetDialog | same |
| دیالوگ ثبت پیشرفت | khatm_screen.dart L346–~430 | inline | dialog | ثبت صفحات + انتخاب جزء | ~85 | legacy | Low | ⚠️ | SheetDialog | same |
| تاریخچهٔ ختم‌ها | khatm_screen.dart L612–~810 | `_showHistory` | sheet | لیست ختم‌های گذشته | ~200 | legacy | Low | ⚠️ | SheetDialog | same |
| دیالوگ ساعت یادآوری | lib/features/khatm/presentation/widgets/khatm/khatm_time_dialog.dart | `KhatmTimeDialog` | dialog | ورود دستی ساعت | 93 | legacy | Low | ⚠️ | SheetDialog | material + عددفارسی |
| کارت‌های داخل صفحه | lib/features/khatm/presentation/widgets/khatm/*.dart | `KhatmCards`,`KhatmVirtues`,`KhatmSummaryCard`,`KhatmJuzGrid`,… | content | کارت‌های ترکیب‌ساز | 547+286+221+211+… | legacy | Medium | ✅ | ListCard | AppColors + SectionColors |

#### ۳.۴.۳ حفظ قرآن

| سطح | فایل | کلاس | مسیر | کارکرد | LOC | وضعیت | اولویت | تست | قالب هدف | شاهد |
|---|---|---|---|---|---|---|---|---|---|---|
| حفظ قرآن | lib/features/hifz/presentation/screens/hifz_screen.dart | `HifzScreen` | `/hifz` | لیست حافظان، سبق/مرور، ورود گزارش | 988 | legacy | Medium | ✅ | ListCard | AppColors + SectionColors |
| گزارش حفظ | lib/features/hifz/presentation/screens/hifz_report_screen.dart | `HifzReportScreen` | push | گزارش ماه/سال شمسی + PDF | 902 | legacy | Medium | ✅ | ReportGauge | AppColors + shamsi |
| فرم حافظ | lib/features/hifz/presentation/widgets/hifz_form_sheets.dart | `_HafizFormSheet` (L44–172) | sheet | افزودن/ویرایش حافظ | ~129 | legacy | Low | ✅ | SheetDialog | AppColors |
| فرم سبق | hifz_form_sheets.dart | `_LessonFormSheet` (L188–345) | sheet | ثبت سبق جدید | ~158 | legacy | Low | ⚠️ | SheetDialog | AppColors |
| فرم مرور | hifz_form_sheets.dart | `_ReviewFormSheet` (L368–546) | sheet | ثبت مرور (نوع/تاریخ/کیفیت) | ~179 | legacy | Low | ⚠️ | SheetDialog | AppColors |
| انتخاب‌گر بازه | lib/features/hifz/presentation/widgets/hifz_range_picker.dart | `HifzRangePicker` | داخل فرم‌ها | انتخاب سوره/آیه از-تا | 226 | legacy | Low | ⚠️ | SheetDialog | AppColors |

#### ۳.۴.۴ دعاهای قرآنی («دعا»)

| سطح | فایل | کلاس | مسیر | کارکرد | LOC | وضعیت | اولویت | تست | قالب هدف | شاهد |
|---|---|---|---|---|---|---|---|---|---|---|
| دعا | lib/features/dua_from_quran/presentation/screens/dua_from_quran_screen.dart | `DuaFromQuranScreen` | `/dua` | لیست دعاهای قرآنی + جستجو/موردعلاقه | 691 | legacy | Medium | ⚠️ (فقط data test) | ListCard | AppColors + SectionColors |
| اشتراک دعا | lib/features/dua_from_quran/presentation/screens/dua_from_quran_share_screen.dart | `DuaFromQuranShareScreen` | push | اشتراک متن/تصویر | 507 | legacy | Low | ⚠️ | SimplePage | AppColors + SectionColors |

#### ۳.۴.۵ ملقّن (مصحف توحید) و آزمایشگاه

| سطح | فایل | کلاس | مسیر | کارکرد | LOC | وضعیت | اولویت | تست | قالب هدف | شاهد |
|---|---|---|---|---|---|---|---|---|---|---|
| ملقّن | lib/features/prompter/presentation/prompter_screen.dart | `PrompterScreen` | `/prompter` | واژه‌به‌واژهٔ تلاوت با پالت خصوصی روشن/تیره | 1593 | legacy ⚿ | Medium | ✅ | SpecializedViewer | PrompterPalette |
| شیت تنظیمات نمایش | prompter_screen.dart L143–416 | `_openSettings` | sheet | نمایش و دقت | ~274 | legacy ⚿ | Low | ⚠️ | SheetDialog | PrompterPalette |
| انتخاب سورهٔ شروع | prompter_screen.dart L417–~540 | `_openSurahPicker` | sheet | انتخاب سوره | ~120 | legacy ⚿ | Low | ⚠️ | SheetDialog | PrompterPalette |
| آمارهٔ پیشرفت | lib/features/prompter/presentation/prompter_stats_screen.dart | `PrompterStatsScreen` | `/prompter/stats` | نرخ دقت + پرخطاترین واژه‌ها | 722 | legacy ⚿ | Low | ✅ | ReportGauge | PrompterPalette |
| آزمایشگاه | lib/features/recitation_lab/presentation/recitation_lab_screen.dart | `RecitationLabScreen` | `/recitation-lab` (پنهان) | پروتوتایپ بازشناسی واج | 341 | legacy ⚿ | Low | ✅ | SpecializedViewer | recitation_colors |

#### ۳.۴.۶ کتابخانهٔ صوتی

| سطح | فایل | کلاس | مسیر | کارکرد | LOC | وضعیت | اولویت | تست | قالب هدف | شاهد |
|---|---|---|---|---|---|---|---|---|---|---|
| کتابخانهٔ صوتی | lib/features/audio_library/presentation/screens/audio_library_screen.dart | `AudioLibraryScreen` (+`_CategoryTabs`…) | `/audio-library?cat=` | دسته‌ها/سخنرانان/آهنگ‌ها/جستجو/دانلود + شیت فضا (L1463–1545) | 1545 | legacy | Medium | ✅ | ListCard | AppColors + SectionColors |
| مینی‌پلیر | lib/features/audio_library/presentation/widgets/audio_mini_player.dart | `AudioMiniPlayer` (+`_PlayerSheet` L363–415) | inline (L381) | پلیر پایدار: play/seek/سرعت/خواب | ~345 | legacy | Medium | ✅ | QuranChrome (audio) | AppColors |
| — نظر باز: قالب مینی‌پلیر (QuranChrome یا KeepNative) — تصمیم در §۷.۵ |

#### ۳.۴.۷ حصن المسلم (duas — فایل اصلی محافظت‌شده/قطعی)

| سطح | فایل | کلاس | مسیر | کارکرد | LOC | وضعیت | اولویت | تست | قالب هدف | شاهد |
|---|---|---|---|---|---|---|---|---|---|---|
| حصن المسلم | lib/features/adhkar/duas/presentation/screens/duas_screen.dart | `DuasScreen` | `/duas` | مرورگر حصن + جستجو/موردعلاقه | 1162 | partial ⚿ (قطعی — بازطراحی نشود) | Frozen | ✅ (hesn_content_guard + translation_completeness) | — (قطعی) | design_system + AppColors + SectionColors |
| متن دعا | lib/features/adhkar/duas/presentation/screens/dua_detail_screen.dart | `DuaDetailScreen` | push | متن/آوانگاری/ترجمه/شرح | 354 | legacy | Low | ⚠️ | SimplePage | theme |
| ارسال دعا | lib/features/adhkar/duas/presentation/screens/dua_share_screen.dart | `DuaShareScreen` | push | اشتراک متن/تصویر | 674 | legacy | Low | ✅ | SimplePage | AppColors + SectionColors |
| مقدمات کتاب | lib/features/adhkar/duas/presentation/screens/hesn_intro_reader_screen.dart | `HesnIntroReaderScreen` | push | خوانندهٔ مقدمات | 99 | legacy | Low | ⚠️ | SimplePage | theme |

نکات قرآن: هدر و پلیر خواننده overlayهای عمدی Positioned هستند — **resize دادن pager ممنوع** (کامنت L1349–1370). `quran_mushaf_sheets.dart`/`mushaf_color_sheets.dart` قدیمی‌اند ولی هم‌مسیر با شیت‌های جدید — وضعیت per-file متفاوت است. `mushaf_backgrounds.dart` (473، painter+records) بین «صفحه» و «chrome» است — تصمیم بازطراحی در §۷.۵.

### ۳.۵ اذکار و تسبیح — تب ۲ (اسکن C)

| سطح | فایل | کلاس | ورود/مسیر | کارکرد | LOC | وضعیت | اولویت | تست | قالب هدف | شاهد |
|---|---|---|---|---|---|---|---|---|---|---|
| تب «اذکار و تسبیح» | lib/features/adhkar/presentation/screens/azkar_tasbih_tab.dart | `AzkarTasbihTab` | tab 2 | chrome + ۲ زیرتب تسبیح/اذکار + تنظیمات | 409 | legacy | High | ⚠️ | SimplePage | AppColors (فرزندان partial) |
| «تسبیح» (شمارنده) | lib/features/adhkar/tasbih/presentation/widgets/tasbih_counter_widget.dart | `TasbihCounterWidget` (+`_BeadCounterCircle`,`_ProgressRingPainter`,`_QuickModePill`,`_SpeedSelector`…) | inline | شمارندهٔ big-tap، حالت سریع، چیپ اذکار، ۵ اکشن، نقطه‌های صفحه | 1194 | partial | High | ✅ | SpecializedViewer | SectionHues.tasbih + AppColors |
| «اذکار» (لیست) | lib/features/adhkar/presentation/widgets/azkar_list_widget.dart | `AzkarListWidget` (+`_StatCircle`,`_ZikrCard`) | inline | کارت آمار کل + کارت‌های ذکر + FAB افزودن | 479 | partial | Medium | ✅ | ListCard | time_theme + glass + AppColors |
| کارت ذکر (اوراد پس‌نماز) | lib/features/adhkar/presentation/widgets/zikr_card.dart | `ZikrCard` | inline (PeriodSection) | ردیف چک‌شدنی اذکار | 268 | legacy | Low | ✅ | ListCard | AppColors |
| ارسال ذکر | lib/features/adhkar/presentation/screens/adhkar_share_screen.dart | `AdhkarShareScreen` (+`_ContentSelector`) | push (daily_adhkar_box) | اشتراک ذکر به‌صورت تصویر/متن | 545 | legacy | Low | ⚠️ | SpecializedViewer | AppColors |
| شیت تنظیمات اذکار | azkar_tasbih_tab.dart L133–409 | `_AzkarSettingsSheet` | sheet | هپتیک/صدا/حجم/شمارش سریع/ریست/چرخش | ~276 | legacy | Medium | ✅ | SheetDialog | AppColors |
| دیالوگ ریست روزانه | azkar_tasbih_tab.dart | dialog | dialog | ورود ساعت (رقم فارسی) | ~85 | legacy | Low | ⚠️ | SheetDialog | AppColors |
| دیالوگ‌های لیست اذکار | azkar_list_widget.dart L103,172,219,356,389 | AlertDialog ×۵ | dialogs | ریست‌کل/افزودن/هدف/حذف | ~230 | partial (file) | Low | ⚠️ | SheetDialog | — |
| دیالوگ‌های شمارنده | tasbih_counter_widget.dart L255,299,349 | dialog ×۳ | dialogs | هدف/افزودن دستی/ریست | ~120 | partial | Low | ⚠️ | SheetDialog | — |
| پیش‌نمای ویجت تسبیح | lib/features/adhkar/tasbih/presentation/widgets/tasbih_widget_preview.dart | `TasbihWidgetPreview` (+`_RingPainter`) | inline تنظیمات ویجت | پیش‌نمای ویجت بومی شمارنده | 201 | legacy | Medium | ✅ | SpecializedViewer | WidgetTokens |

نکات تسبیح: رنگ‌ها دوگانه‌اند (هویت از `SectionHues.tasbih`، داخل از `AppColors` + `AppTheme.scaledFontSize`)؛ دایره اخیراً ساده شد (`820779a`). صدا: `ClickSoundPlayer('sounds/tick.wav')` — استخر چرخشی ≤۸ پخش‌یک‌باره (`audioplayers`)، `warmUp()` در init، `play(settings.tasbihVolume)` هر تپ؛ هپتیک هر ۲ تپ غیرسریع. کلیدهای prefs: `azkar_*` (azkar_settings_provider.dart، 146).

### ۳.۶ عبادات و مناسک: تقویم · ارزیابی · چک‌لیست · روزه · حج/عمره · رقیه · یادآورها (اسکن C)

| سطح | فایل | کلاس | ورود/مسیر | کارکرد | LOC | وضعیت | اولویت | تست | قالب هدف | شاهد |
|---|---|---|---|---|---|---|---|---|---|---|
| تب تقویم | lib/features/tools/calendar/presentation/screens/calendar_screen.dart | `CalendarScreen` | tab 3 | تقویم ۳گانه، خلاصهٔ روز، ژورنال، مناسبت‌ها | 454 | partial | High | ⚠️ | CalendarMonth | glass + AppColors |
| هدر تقویم | lib/features/tools/calendar/presentation/widgets/calendar_month_widgets.dart | `CalendarMonthHeader` | hero | تاریخ ۳گانه + prev/next/امروز + شمارش مناسبت | 673 (file) | partial | High | ⚠️ | HomeHero | card_design + AppColors |
| سلول‌های ماه | calendar_month_widgets.dart | `CalendarDayCell` | inline | روز شمسی + عدد قمری + نقطهٔ رویداد/ژورنال + روزه | " | partial | High | ⚠️ | CalendarMonth | — |
| خلاصهٔ روز انتخابی | calendar_month_widgets.dart | `SelectedDateSummary` | inline | روز در ۳تقویم + رویدادها + تغییر تاریخ | " | partial | Medium | ⚠️ | CalendarMonth | — |
| ژورنال روز | lib/features/tools/calendar/presentation/widgets/calendar_day_journal.dart | `DayJournalSection` (+`FastingToggle`…) | inline | یادداشت روز + «روزه گرفتم» + چیپ امتیاز | 558 | partial | Medium | ✅ | ListCard | card_design + AppColors |
| مناسبت‌های ماه | lib/features/tools/calendar/presentation/widgets/calendar_events_section.dart | `MonthlyEventsSection` | inline | مناسبت‌ها/ایام‌البیض ماه | 355 | partial | Medium | ⚠️ | ListCard | — |
| شیت انتخاب ماه | lib/features/tools/calendar/presentation/widgets/jalali_month_picker_sheet.dart | `JalaliMonthPickerSheet` | sheet | انتخاب سال/ماه (GridView.count) | 235 | partial | Low | ⚠️ | SheetDialog | — |
| تب ارزیابی | lib/features/worship/presentation/screens/evaluation_tab.dart | `EvaluationTab` | tab 4 | پوشش نازک Scaffold+AppBar | 21 | legacy | High | ⚠️ | ReportGauge | Material |
| بدنهٔ گزارش | lib/features/worship/presentation/widgets/evaluation_stats_widget.dart | `EvaluationStatsWidget` (+۱۳ کلاس داخلی) | inline | حلقه‌ها/امتیاز/زنجیره/heatmap + اشتراک | 1941 | legacy | High | ✅ | ReportGauge | AppColors |
| انتخاب ماه/سال گزارش | evaluation_stats_widget.dart L810–932 | `_showMonthYearPicker` | sheet | انتخاب ماه شمسی برای ماهانه | ~120 | legacy | Low | ⚠️ | SheetDialog | AppColors |
| کارت اشتراک گزارش | lib/features/worship/presentation/widgets/evaluation_report_card.dart | `EvaluationReportCard` | inline | PNG ثابت عرض برای اشتراک | 269 | legacy | Low | ⚠️ | ReportGauge | AppColors |
| چک‌لیست طاعات | lib/features/checklist/presentation/screens/worship_checklist_screen.dart | `WorshipChecklistScreen` (+`_ProgressRing`,`_RingPainter`,…) | `/worship-checklist` | hero حلقه + امتیاز/زنجیره + چک‌لیست + لینک‌ها | 684 | legacy | Medium | ✅ | HomeHero | AppColors + SectionColors |
| شیت الگوهای چک‌لیست | worship_checklist_screen.dart L25–80 | `_showTemplates` | sheet | افزودن بسته‌های آماده | ~100 | legacy | Low | ⚠️ | SheetDialog | AppColors |
| لیست عبادات + دیالوگ‌ها | lib/features/checklist/presentation/widgets/worship_list_widget.dart | `WorshipListWidget` (+دیالوگ L26,58) | inline | ردیف‌ها، چک انیمیشنی، افزودن/حذف | 313 | legacy | Medium | ✅ | ListCard | AppColors |
| روزه و رمضان | lib/features/fasting/presentation/screens/fasting_screen.dart | `FastingScreen` (+۸ تب) | `/fasting` | ۸ تب: رمضان، فطریه، آشنایی، ارکان، قضا، سنن، ویژه، FAQ | 556 | legacy ⚿ | Medium | ✅ | SimplePage | AppColors + SectionColors |
| ردیاب رمضان | lib/features/fasting/presentation/tabs/ramadan_tracker_tab.dart | `RamadanTrackerTab` | تب | روزه/تراویح/شب‌قدر/جزء/قضا + شمارش سحر/افطار | 1286 | legacy ⚿ | Medium | ✅ | GridTiles | AppColors |
| زکات فطره | lib/features/fasting/presentation/tabs/fitr_zakat_tab.dart | `FitrZakatTab` | تب | محاسبهٔ فطریه + قیمت‌های ذخیره | 951 | legacy ⚿ | Medium | ✅ | SimplePage | AppColors + SectionColors |
| حج و عمره | lib/features/hajj_umrah/presentation/screens/hajj_umrah_screen.dart | `HajjUmrahScreen` (+۷ تب) | `/hajj-umrah` | راهنمای ۷تبی | 704 | legacy ⚿ | Low (فصلی) | ✅ | SimplePage | AppColors + SectionColors |
| چک‌لیست مناسک | lib/features/hajj_umrah/presentation/widgets/ritual_steps_view.dart | `RitualStepsView` | inline | پیشرفت گام‌به‌گام (prefs) | 407 | legacy ⚿ | Low | ⚠️ | ListCard | AppColors |
| رقیه شرعی | lib/features/ruqyah/presentation/screens/ruqyah_screen.dart | `RuqyahScreen` (+`_StudyTab`…) | `/ruqyah` | ۳ تب: مطالعه/عملی/صوتی (دانلود+پخش) | 1081 | legacy ⚿ | Low | ✅ | SimplePage | AppColors + SectionColors |
| دیالوگ حذف صوتی | ruqyah_screen.dart ~L585 | — | dialog | تأیید حذف فایل | ~35 | legacy ⚿ | Low | ⚠️ | SheetDialog | AppColors |
| سرویس صوتی رقیه | lib/features/ruqyah/services/ruqyah_audio_service.dart | `RuqyahAudioService` | n/a | wrapper audioplayers | 778 | n-a | — | ✅ | — | — |
| یادآورها | lib/features/reminders/presentation/screens/reminders_screen.dart | `RemindersScreen` (+`_RemindersSummary`,…) | `/reminders` | فیلتر + خلاصه + لیست + FAB | 765 | legacy | Medium | ✅ | ListCard | AppColors + SectionColors |
| حالت خالی (فضایل) | reminders_screen.dart L219–480 | `_RemindersVirtuesScreen` | inline | فضایل + CTA وقتی یادآوری نیست | ~260 | legacy | Low | ⚠️ | SimplePage | AppColors |
| ویرایشگر یادآور | lib/features/reminders/presentation/screens/reminder_editor_screen.dart | `ReminderEditorScreen` (+شیت صدا L122–~300، TimePicker L641) | `/reminders/edit` | عنوان/یادداشت/زمان/روزها/تقدم/مرجع-نماز/صدا | 1347 | legacy | Medium | ⚠️ | SettingsRows | AppColors |
| ویجت‌های برگ یادآور | lib/features/reminders/presentation/widgets/reminder/*.dart | `ReminderCard`,`ActionBtn`,`ReminderFilterChip`,… | inline | کارت/چیپ/دکمه؛ رنگ از `SectionColors.reminders` | 262/25/58/38/15 | legacy | Low | ✅ | ListCard | section_colors |

کلاس‌های داخلی `evaluation_stats_widget.dart` (هدف بازطراحی گزارش): `_TabBtn` L1035 (segmented)، `_ScoreCard` L1098 (کارت امتیاز)، `_CompactSummaryRow` L1233، `_ProgressCircle` L1302 (حلقهٔ ۷۲px روزانه)، `_OverallTasbihCard` L1438، `_CirclePainter` L1506 (گیج فعلی — با ArcPainter عریض اسپک جایگزین می‌شود)، `_TasbihDetailCard` L1596، `_ZikrRow` L1660، `_StreakCard` L1723، `_MonthlyHeatmap` L1787.
شبکهٔ تقویم امروز به‌صورت inline در `calendar_screen.dart` build (L370–397) با Column/Row ساخته می‌شود — اسپک GridView/Table می‌خواهد.

### ۳.۷ بیشتر · تنظیمات · اطلاعات من · اهداف · حساب/پیشنهاد/اعلان (اسکن D)

| سطح | فایل | کلاس | ورود/مسیر | کارکرد | LOC | وضعیت | اولویت | تست | قالب هدف | شاهد |
|---|---|---|---|---|---|---|---|---|---|---|
| تب بیشتر | lib/features/settings/presentation/screens/more_screen.dart | `MoreScreen` | tab 5 | لانچر ۳ستونهٔ دسته‌بندی‌شده | 635 | legacy ⚿ | High | ✅ | GridTiles | AppColors |
| تنظیمات | lib/features/settings/presentation/pages/settings_screen.dart | `SettingsScreen` (+`_ThemeRow`,`_HijriOffsetSlider`,`_VolumeSlider`,`_PointStepper`…) | `/settings` | هاب تنظیمات: تم، صدا، امتیاز، قفل، پشتیبان | 1959 | partial | High | ✅ | SettingsRows | time_theme + AppColors |
| فونت و نمایش | settings_screen.dart L1650–1766 | `FontDisplayPage` | `/settings/font` | فونت/اندازه + سوییچ‌های عربی/۱۲ساعت/دلیل | ~117 | partial | Medium | ✅ | SettingsRows | same |
| جستجوی تنظیمات | settings_screen.dart L1480–1646 | `_SettingsSearchDelegate` | overlay | جستجو + اسکرول-به-لنگر/پوش | ~166 | partial | Medium | ⚠️ | SheetDialog | same |
| ویجت‌ها | lib/features/settings/presentation/screens/widget_settings_screen.dart | `WidgetSettingsScreen` (+`ColorPickerSheet` L889–1132، how-to ~L735) | `/settings/widget` | ویرایشگر ویجت بومی: تب‌ها/رنگ/شفافیت/گوشه + پیش‌نمای زنده | 1178 | legacy | Medium | ✅ | SpecializedViewer | AppColors |
| اعلان‌ها و اذکار | lib/features/settings/presentation/screens/notification_settings_screen.dart | `NotificationSettingsScreen` | `/settings/notifications` | اذکار/آیه‌حدیث‌دعا/قرآن/مناسبت/جمعه، snooze، لغو همه | 911 | legacy | High | ✅ | SettingsRows | AppColors |
| تشخیص اعلان | lib/features/settings/presentation/screens/notification_diagnostics_screen.dart | `NotificationDiagnosticsScreen` | `/settings/notifications/diagnostics` | چک سلامت مجوزها + اذان آزمایشی + اشتراک لاگ | 521 | legacy | Low | ✅ | ReportGauge | AppColors |
| تشخیص پیوست‌ها | lib/features/settings/presentation/screens/attachment_diagnostics_screen.dart | `AttachmentDiagnosticsScreen` | `/settings/attachments/diagnostics` (debug) | اسکن فایل بی‌صاحب/ارجاع شکسته | 522 | legacy | Low | ✅ | ReportGauge | AppColors |
| درباره | lib/features/settings/presentation/screens/about_screen.dart | `AboutScreen` | `/settings/about` | امکانات/تماس/امتیاز/به‌روزرسانی | 576 | partial | Low | ✅ | SimplePage | card_design (شعاع/طلایی) |
| شیت پشتیبان ابری | lib/features/settings/presentation/widgets/cloud_backup_sheet.dart | `CloudBackupSheet` | sheet | لیست/دانلود/حذف پشتیبان Drive | 273 | legacy | Low | ✅ | SheetDialog | AppColors |
| اطلاعات من | lib/features/personal_info/presentation/screens/personal_info_screen.dart | `PersonalInfoScreen` | `/personal-info` | داشبورد گاوصندوق: PIN + هدر گرادیانی + آمار + کاشی‌ها | 1129 | legacy ⚿ | Medium | ⚠️ | HomeHero | AppColors |
| گارد «قفل است» | lib/features/personal_info/presentation/providers/vault_session.dart | `VaultGuard`/`_VaultLocked` | wrap زیرمسیرها | placeholder «ورود رمز» | 138 | legacy ⚿ | Low | ✅ | SimplePage | AppColors |
| قفل ابزار | lib/features/personal_info/presentation/providers/tool_locks.dart | `ToolLockScreen` | guard (هزینه‌ها/یادداشت/دنگی) | ورود PIN برای ابزار قفل | 272 | legacy ⚿ | Low | ✅ | SimplePage | AppColors |
| افراد و خانواده | lib/features/personal_info/presentation/screens/profiles_screen.dart | `ProfilesScreen` | `/personal-info/profiles` | کارت اعضای خانواده | 355 | legacy ⚿ | Low | ✅ | ListCard | AppColors |
| افزودن/ویرایش عضو | personal_info/…/profile_editor_screen.dart | `ProfileEditorScreen` | `/personal-info/profiles/edit` | فرم عضو + آواتار + حذف | 308 | legacy ⚿ | Low | ⚠️ | SimplePage | AppColors |
| مدارک و اسناد | personal_info/…/documents_screen.dart | `DocumentsScreen` (+`DocumentEditor` sheet 544) | `/personal-info/documents` | مدارک هویتی هر عضو | 413 | legacy ⚿ | Low | ⚠️ | ListCard | AppColors |
| رمزها و کارت‌ها | personal_info/…/credentials_screen.dart | `CredentialsScreen` | `/personal-info/credentials` | اعتبارنامه‌ها + دسته‌ها | 579 | legacy ⚿ | Low | ⚠️ | ListCard | AppColors |
| خودرو و املاک | personal_info/…/assets_screen.dart | `AssetsScreen` | `/personal-info/assets` | کارت دارایی‌ها | 616 | legacy ⚿ | Low | ⚠️ | ListCard | AppColors |
| بیمه | personal_info/…/insurance_screen.dart | `InsuranceScreen` | `/personal-info/insurance` | کارت بیمه‌ها | 461 | legacy ⚿ | Low | ⚠️ | ListCard | AppColors |
| تماس اضطراری | personal_info/…/emergency_contacts_screen.dart | `EmergencyContactsScreen` | `/personal-info/emergency` | لیست تماس‌ها | 385 | legacy ⚿ | Low | ⚠️ | ListCard | AppColors |
| تاریخ‌های مهم | personal_info/…/expiry_screen.dart | `ExpiryScreen` | `/personal-info/expiry` | اقلام انقضا با رنگ فوریت | 574 | legacy ⚿ | Low | ✅ | ListCard | AppColors |
| نمایشگر عکس | personal_info/…/photo_gallery_screen.dart | `PhotoGalleryScreen` | push | swipe/pinch/اشتراک | 96 | legacy ⚿ | Low | ✅ | SpecializedViewer | theme + مشکی |
| شیت‌های ویرایش درون‌فایل | *_screen.dart (نیمهٔ پایین) | `_AssetEditor`/`_CredentialEditor`/`_InsuranceEditor`/`_ContactEditor`/`_ExpiryEditor` | sheets | فرم هر موجودیت | ~150–260 هرکدام | legacy ⚿ | Low | ⚠️ | SheetDialog | AppColors |
| هدف‌گذاری | lib/features/goals/presentation/screens/goals_screen.dart | `GoalsScreen` (+شیت بایگانی ~L86، قالب ~L136) | `/goals` | لیست اهداف + FAB + بایگانی/قالب | 648 | legacy | Medium | ✅ | ListCard | AppColors |
| نوار ابزار اهداف | lib/features/goals/presentation/widgets/goal_list_toolbar.dart | `GoalListToolbar` | inline | جستجو + چیپ دسته/اولویت/انجام‌شده + مرتب‌سازی | 249 | legacy | Medium | ✅ | ListCard | AppColors |
| جزئیات هدف | lib/features/goals/presentation/screens/goal_detail_screen.dart | `GoalDetailScreen` | `/goals/:id` | درصد، ثبت امروز، نمودار ۱۴روزه، زنجیره | 1228 | legacy | Medium | ✅ | ReportGauge | AppColors |
| ویرایشگر هدف | lib/features/goals/presentation/screens/goal_editor_screen.dart | `GoalEditorScreen` | `/goals/edit` | فرم کامل هدف | 895 | legacy | Low | ✅ | SimplePage | AppColors |
| حساب کاربری | lib/features/account/presentation/screens/account_screen.dart | `AccountScreen` (+`CloudBackupSheet`) | `/settings/account` | ورود ایمیل/گوگل + پشتیبان ابری | 774 | legacy | Medium | ✅ | ListCard | AppColors |
| ارسال پیشنهاد | lib/features/suggestions/presentation/screens/suggestions_screen.dart | `SuggestionsScreen` | `/settings/suggestions` | فرم بازخورد + پیشنهادها + پنل ادمین | 1060 | legacy | Low | ✅ | SimplePage | AppColors |
| پیام‌های مدیریت | lib/features/announcements/presentation/screens/announcements_screen.dart | `AnnouncementsScreen` | `/settings/announcements` | اعلان‌های رسمی + ادمین | 776 | legacy | Low | ✅ | ListCard | AppColors |

#### More — ساختار فعلی (هدف دلتای اسپک)
- (a) hero strip: **ندارد** · (b) فیلد جستجوی «جستجو در بخش‌ها»: **ندارد** · (c) چیپ شمارش هر سکشن: **ندارد**. چیدمان: AppBar + `ListView` از `_SectionHeader` + `GridView` ۳ستونه (aspect 1.02) + سرصفحهٔ «برنامه» + کاشی «تنظیمات».
- `_sections`: عبادات و مناسک (طلایی، ۱۵): قبله‌نما، ماه و منازل، وضو، نماز، روزه، زکات، حج و عمره، ختم، حفظ، مصحف حافظ (web)، مصحف توحید، دعا، حصن المسلم، میراث، رقیه · مطالعه و محتوا (فیروزه‌ای، ۱۰): ریاض الصالحین، کتب حدیث، جستجوی احادیث، فتاوای شرعی، موسوعه احادیث، کتابخانه، علوم اسلامی، مطالعهٔ آزاد، تثبیت یقین (قفل `2323`)، هوش مصنوعی قاف (web) · کتابخانهٔ صوتی (نارنجی، ۳): رد شبهات، اناشید، سخنرانی · ابزارهای شخصی (نیلی، ۱۰): هدف‌گذاری، اطلاعات من، مدیریت کارها، هزینه‌ها، یادداشت‌ها، یادآورها، دورهٔ ماهانه، ماشین‌حساب، پومودور، دنگی · برنامه: تنظیمات.
- آیتم‌ها: `_RouteItem`/`_LockedRouteItem`/`_WebItem`/`_AudioLibraryItem`؛ قفل per-session؛ دیالوگ رمز ۶رقمی. رنگ کاشی‌ها ثابت از `SectionColors.*` (تم روی آن‌ها اثر ندارد — قاعدهٔ طراحی مستندشده).

#### Settings — ساختار فعلی (هدف دلتای اسپک)
AppBar «تنظیمات» + جستجو → `_SettingsSearchDelegate`. گروه‌ها: ۱ ظاهر برنامه (۳ کارت حالت تم + ۶ کارت نوع تم ۲×۳ + فونت و نمایش) · ۲ نماز و اذان (تنظیمات اذان/اقامه + اسلایدر هجری −5..+5 + دکمه‌های سریع) · ۳ صداها (۲ اسلایدر حجم) · ۴ امتیازدهی (۶ استپر ±: فرض/سنت/ضحی/اذکار/تسبیح + ضریب طاعات ۲۵–۳۰۰٪) · ۵ اعلان‌ها (settings → diagnostics → attachments در debug) · ۶ قفل ابزارها (۳ سوییچ + تعیین رمز) · ۷ ویجت‌ها · ۸ حساب · ۹ پشتیبان‌گیری (وضعیت + همین حالا + ZIP کامل + بازگردانی خودکار + فایل) · ۱۰ سایر (باتری، پیشنهاد، پیام‌ها، درباره).
پایداری داده (تغییر ندهید): جدول تک‌ردیفی Drift (`settings_table` + DAO + datasource + DTO)، کلیدهای prefs (`onboarding_completed`, `is_premium`, `eval_*`, `notif_*`, `azkar_*`, `tool_locks.enabled`)، مسیر restore (`BackupService.isRestorablePreferenceKey` + نام‌ستون‌های JSON/ZIP/cloud).

#### الگوی قفل personal_info
`PinLockService` (isPinSet/setPin/verifyPin/resetVault؛ نرمال‌سازی ارقام فارسی/عربی → ASCII قبل از هش). `PersonalInfoScreen` خودش را گیت می‌کند (۵ تلاش → قفل موقت)؛ `vaultSessionProvider` روی pause/hide/detach قفل می‌کند؛ هر زیرمسیر در `VaultGuard`. `ToolLockGuard` همین الگو برای هزینه‌ها/یادداشت‌ها/دنگی. **یک رفتار هم تغییر نکند.**

### ۳.۸ دانش و محتوا: حدیث · کتابخانه · علوم · یقین · جستجو (اسکن E)

| سطح | فایل | کلاس | ورود/مسیر | کارکرد | LOC | وضعیت | اولویت | تست | قالب هدف | شاهد |
|---|---|---|---|---|---|---|---|---|---|---|
| کتب السنة | lib/features/hadith/presentation/screens/hadith_books_screen.dart | `HadithBooksScreen` (+`HadithBookDetailScreen`/`_HadithDetailSheet`/`HadithSearchResultsScreen`/`HadithListAllScreen`/`HadithChapterScreen` در همان فایل) | `/hadith/books` | کتابخانهٔ حدیث + فصول + جستجوی درون‌کتاب + جزئیات | 1556 | partial | Medium | ⚠️ | ListCard | card_design + AppColors + SectionColors |
| جستجوی احادیث (الدرر) | lib/features/dorar_hadith/presentation/screens/dorar_hadith_search_screen.dart (+`_SharhSheet` در result_card) | `DorarHadithSearchScreen` | `/dorar-hadith/search` | جستجوی dorar.net + فیلتر + شارح | 177 (+~88) | legacy ⚿ | Medium | ✅ | ListCard | AppColors + SectionColors |
| جزئیات الدرر | lib/features/dorar_hadith/presentation/screens/dorar_hadith_details_screen.dart | `DorarHadithDetailsScreen` | `/dorar-hadith/details/:id` | متن/شرح/بدیل | 268 | legacy ⚿ | Medium | ✅ | SpecializedViewer | AppColors |
| موسوعه احادیث | lib/features/hadeeth_enc/presentation/screens/hadeeth_enc_screen.dart (+`_JumpDialog`) | `HadeethEncScreen` | `/hadeeth-enc` | دانشنامهٔ حدیث + فیلتر/موردعلاقه/تصادفی | 1005 | legacy | Medium | ✅ | ListCard | AppColors + SectionColors |
| حدیث N | lib/features/hadeeth_enc/presentation/screens/hadeeth_enc_detail_screen.dart | `HadeethEncDetailScreen`/`HadeethEncDetailByIdScreen` | `/hadeeth-enc/:id` | متن/ترجمه/تخریج/فواید/اشتراک | ~260+~57 | legacy | Medium | ✅ | SpecializedViewer | AppColors + SectionColors |
| ارسال حدیث | lib/features/hadeeth_enc/presentation/screens/hadeeth_enc_share_screen.dart | `HadeethEncShareScreen` | push | کارت اشتراک تصویر/متن | 313 | legacy | Low | ✅ | SpecializedViewer | SectionColors |
| ریاض الصالحین | lib/features/riyad/presentation/screens/riyad_screen.dart (+`_RiyadJumpDialog`) | `RiyadScreen` | `/riyad` | فصول + موردعلاقه | ~560 (+~130) | legacy | Medium | ✅ | ListCard | AppColors + SectionColors |
| فصل ریاض | lib/features/riyad/presentation/screens/riyad_chapter_screen.dart | `RiyadChapterScreen` (+شیت پرش ~L301) | inline | احادیث فصل | 539 | legacy | Medium | ✅ | SpecializedViewer | AppColors + SectionColors |
| فتاوای شرعی | lib/features/fatwa/presentation/screens/fatwa_screen.dart (+`_FatwaDetailScreen`) | `FatwaScreen` | `/fatwa` | لیست/جستجو/موردعلاقه/تصادفی + جزئیات | ~555 (+~166) | legacy | Medium | ⚠️ | ListCard | AppColors |
| کتابخانه | lib/features/books/presentation/screens/ketabkhaneh_screen.dart (+دیالوگ برچسب ~L933) | `KetabkhanehScreen` | `/books` | گرید/لیست کتاب + جستجو/نشانک/برچسب/دانلود | 1735 | legacy | Medium | ✅ | GridTiles | SectionColors + AppColors |
| خوانندهٔ کتاب | lib/features/books/presentation/screens/book_reader_screen.dart (+شیت نشانک ~L806، پانویس ~L706) | `BookReaderScreen` | push | خوانندهٔ صفحه‌ای: فونت/پس‌زمینه/تمام‌صفحه/ذخیره خودکار | 1536 | legacy | Medium | ⚠️ | SpecializedViewer | AppColors |
| فهرست/نشانک‌ها/نمایش خواننده | lib/features/books/presentation/widgets/book_reader_toc_sheet.dart / bookmark_sheet / display_settings | `BookReaderTocSheet`/`BookReaderBookmarkSheet`/`BookReaderDisplaySettings` | sheets | TOC/نشانک/تنظیمات نمایش | 254/246/421 | legacy | Low | ⚠️ | SheetDialog | AppColors |
| آمار مطالعه | lib/features/books/presentation/screens/reading_stats_screen.dart | `ReadingStatsScreen` | push | آمار + نمودار | 220 | legacy | Low | ⚠️ | ReportGauge | AppColors + SectionColors |
| علوم اسلامی | lib/features/education/presentation/screens/sciences_home_screen.dart (+`_ScienceSearchDelegate`) | `SciencesHomeScreen` | `/sciences` | گرید علوم + جستجو | 376 | legacy | Low | ✅ | GridTiles | theme + SectionColors |
| جزئیات علم | lib/features/education/presentation/screens/science_detail_screen.dart | `ScienceDetailScreen` | `/sciences/:id` | فصول/ادله/FAQ | 273 | legacy | Low | ⚠️ | SpecializedViewer | theme |
| مطالعهٔ آزاد | lib/features/education/presentation/screens/study_screen.dart (+۴ شیت/دیالوگ در `study_widgets.dart` 1730) | `StudyScreen` | `/study` | برنامهٔ مطالعه: پیشرفت امروز + کتاب‌ها | 110 (+~370+110+80+50) | legacy | Medium | ✅ | ListCard | SectionColors + AppColors |
| «یقین» (تثبیت یقین) | lib/features/yaqeen/presentation/screens/yaqeen_home_screen.dart + level/lesson/quiz | `YaqeenHomeScreen`/`YaqeenLevelScreen`/`YaqeenLessonScreen`/`YaqeenQuizScreen` | `/yaqeen` (قفل ۳بخشی) | سطوح/نشان/درس/آزمون | 651/111/1047/344 | legacy | Low | ⚠️ | GridTiles/ListCard/SpecializedViewer | AppColors + SectionColors |
| جستجوی سراسری | lib/features/search/presentation/screens/search_screen.dart | `GlobalSearchDelegate` | overlay (آیکون جستجوی خانه) | جستجو: دعاها/یادداشت/اذکار/قرآن + چیپ دسته | 486 | legacy | Medium | ✅ | ListCard | theme + AppColors |

### ۳.۹ ابزارها و ابزارهای شخصی (اسکن E)

| سطح | فایل | کلاس | ورود/مسیر | کارکرد | LOC | وضعیت | اولویت | تست | قالب هدف | شاهد |
|---|---|---|---|---|---|---|---|---|---|---|
| ماشین‌حساب | lib/features/tools/calculator/presentation/screens/calculator_screen.dart (+`history_sheet` 279) | `CalculatorScreen` (+`CalculatorToolPanels` 642) | `/tools/calculator` | ۷ حالت: معمولی/علمی/درصد/تخفیف/سن/واحد/قسط | 870 | legacy | Medium | ✅ | SpecializedViewer | AppColors + SectionColors |
| تبدیل تاریخ | lib/features/tools/date_converter/presentation/screens/date_converter_screen.dart | `DateConverterScreen` | `/tools/date-converter` | تبدیل شمسی/میلادی/قمری + اشتراک | 714 | legacy | Low | ✅ | SimplePage | theme + AppColors |
| دنگی | lib/features/tools/dongi/presentation/screens/dangi_screen.dart (+group 937 +report 661) | `DangiScreen`/`DangiGroupScreen`/`DangiReportScreen` | `/tools/dangi` | تقسیم هزینهٔ گروهی: اعضا/مانده‌ها/گزارش | 232+937+661 | legacy | Low | ✅ | ListCard/ReportGauge | AppColors + SectionColors |
| شیت‌های دنگی | lib/features/tools/dongi/presentation/widgets/dangi_form_sheets.dart (+sheets در group_screen) | `_GroupFormSheet`/`_ExpenseSheet`/`_SettlementSheet`/member sheet | sheets | ساخت/هزینه/تسویه | ~310/~620/~256/~60 | legacy | Low | ✅ | SheetDialog | AppColors + SectionColors |
| میراث | lib/features/tools/inheritance/presentation/screens/inheritance_screen.dart (+۱۰ تب در پوشه‌ها) | `InheritanceScreen` (+`inheritance_calculator_tab` 1514، `heir_catalog` 135، `comparison` 1107، `special` 884، …) | `/tools/inheritance` | جعبه‌ابزار ارث ۱۰تبی | 86 (+~6000 مجموع تب‌ها) | legacy | Low | ✅ (۳۱ تست) | SpecializedViewer | AppColors + SectionColors |
| مناسخات | lib/features/tools/inheritance/presentation/widgets/munasakhat_sheet_content.dart | `MunasakhatSheetContent` | sheet | محاسبهٔ چندمرحله‌ای — متوفی هر مرحله از ورثهٔ مرحلهٔ پیش انتخاب می‌شود | 801 | ✅ کیت (2026-10-13) | Low | ✅ (۱۹ تست) | SheetDialog | design kit: AppCard/IconTile/ValueStepper/SectionHeader |
| ماه و منازل | lib/features/tools/moon/presentation/screens/moon_screen.dart | `MoonScreen` (+`_TodayTab`,`_MonthAheadTab`,`_ManazilTab`,`_HilalTab` + `HilalSkyPanel`) | `/tools/moon` | ۴ تب: امروز/۳۰روز/۲۸منزل/هلال (Yallop/Odeh/Bruin-Danjon) | 1357 | legacy ⚿ | Medium | ✅ | SpecializedViewer | SectionColors |
| پومودور | lib/features/tools/pomodoro/presentation/screens/pomodoro_screen.dart (+`TimerSettingsSheet` 225) | `PomodoroScreen` | `/tools/pomodoro` | تایمر حلقه‌ای، نشست‌ها، تاریخچه | 957 | legacy | Low | ✅ | SpecializedViewer | AppColors |
| وضو و طهارت | lib/features/tools/purification/presentation/screens/purification_screen.dart | `PurificationScreen` (+۷ تب) | `/tools/purification` | راهنمای ۷تبی طهارت | 788 | legacy | Low | ✅ | SpecializedViewer | theme + AppColors + SectionColors |
| زکات | lib/features/tools/zakat/presentation/screens/zakat_screen.dart (+`zakat_info_tabs` 435) | `ZakatScreen` (+`_CalculatorTab`، `ZakatResultCard` 522، PDF 173) | `/zakat` | ۷ تب: محاسبه/…؛ ورود از گزارش هزینه با مقدار پیش‌پر | 1854 | legacy ⚿ | Medium | ✅ | SpecializedViewer | theme + AppColors + SectionColors |
| دیالوگ قیمت روز | zakat_screen.dart ~L1729 | — | dialog | ویرایش قیمت طلا/نقره/دلار | ~70 | legacy ⚿ | Low | ⚠️ | SheetDialog | same |
| یادداشت‌ها | lib/features/notes/presentation/screens/worship_notes_screen.dart (+`_NotesVirtuesScreen`، شیت رنگ ~L1296، دیالوگ حذف ~L122) | `WorshipNotesScreen` | `/notes` (More؛ ToolLock.notes) | یادداشت با فیلتر/سنجاق/جستجو/صوت | 1376 | legacy | Medium | ✅ | ListCard | theme + AppColors + SectionColors |
| ویرایش یادداشت | lib/features/notes/presentation/screens/note_editor_screen.dart (+دیالوگ تغییرات ذخیره‌نشده ~L93) | `NoteEditorScreen` | `/notes/edit` | ساخت/ویرایش یادداشت | 234 | legacy | Low | ✅ | SimplePage | theme + AppColors + SectionColors |
| مدیریت کارها | lib/features/tasks/presentation/screens/tasks_screen.dart (+دیالوگ L405) | `TasksScreen` | `/tasks` (More) | فیلتر/خلاصه/آمار هفته | 446 | legacy | Medium | ✅ | ListCard | AppColors |
| دیالوگ کار | lib/features/tasks/presentation/widgets/tasks/tasks_dialog.dart | `TaskDialog` | sheet | افزودن/ویرایش: تاریخ/اولویت/برچسب/زیرکار/تکرار | 1010 | legacy | Low | ✅ | SheetDialog | theme + AppColors |
| هزینه‌ها | lib/features/expenses/presentation/screens/expenses_screen.dart (+دیالوگ حذف ~L387) | `ExpensesScreen` | `/expenses` (More؛ ToolLock.expenses) | ردیاب هزینه: جستجو/فیلتر/خلاصه | 422 | legacy | Medium | ✅ | ListCard | theme + AppColors |
| دیالوگ هزینه | lib/features/expenses/presentation/widgets/expenses/expenses_dialog.dart | `ExpenseDialog` | sheet | افزودن/ویرایش + دسته + تکرار | 551 | legacy | Low | ✅ | SheetDialog | theme + AppColors |
| گزارش هزینه‌ها | lib/features/expenses/presentation/screens/expense_report_screen.dart (+دیالوگ بودجه ~L535) | `ExpenseReportScreen` | `/expenses/report` | پای‌چارت + بودجه + PDF | 718 | legacy | Low | ✅ | ReportGauge | AppColors + SectionColors |

### ۳.۱۰ اندروید و سطوح بومی (Native — خارج از دسترس Flutter؛ اسکن A)

| سطح | فایل | کلاس | ورود | کارکرد | LOC | وضعیت | اولویت | تست | قالب هدف | شاهد |
|---|---|---|---|---|---|---|---|---|---|---|
| ویجت نماز (صفحهٔ خانه) | android/app/src/main/kotlin/…/widget/PrayerWidget.kt + PrayerWidgetViews.kt + res/layout/widget_prayer_{small,medium}.xml + res/xml/widget_prayer_info.xml | `PrayerWidget`/`PrayerWidgetViews` | APPWIDGET_UPDATE + TIME_SET/TIMEZONE/DATE_CHANGED | ساعت/شمارش/۵ جعبهٔ نماز؛ آلارم دقیقه‌ای و مرزی | 513+376+93+362 | native | Medium | ❌ | HomeHero (پورت بومی) | RemoteViews + WidgetTokens + widget_tokens.json |
| ویجت تسبیح | …/widget/TasbihGlanceWidget.kt + Receiver.kt + res/layout/widget_tasbih.xml + res/xml/widget_tasbih_info.xml | `TasbihGlanceWidgetReceiver` | TASBIH_INCREMENT/RESET/PREV/NEXT_ZIKR | شمارنده + ناوبری ذکر | 290+369+158 | native | Medium | ❌ | SpecializedViewer (بومی) | R.layout.widget_tasbih |
| Layoutهای مرده | res/layout/widget_prayer_boxes.xml / widget_calendar_prayer.xml / widget_prayer_preview.xml | — | هیچ ارجاعی ثبت نشده | جانشین‌های رهاشده | 347/312/191 | native (مرده) | Low (پاک‌سازی) | — | delete | grep: صفر ref |
| اسپلش بومی | res/drawable/launch_background.xml (+v21) + values{,-v31,-night,-night-v31}/styles.xml + drawable-nodpi/splash_logo.png + drawable/splash_no_icon.xml | `LaunchTheme`/`NormalTheme` | windowBackground | زمینهٔ طلایی شعاعی + لوگو؛ API31+ ماسک سیستم | 27/22/13/19/18/13 | native | Medium | ❌ | KeepNative | گلدهای #C48A27 همگام دستی با Flutter |
| Drawable مرده | res/drawable/splash_background.xml | — | هیچ ارجاعی | گرادیان قدیمی | 8 | native (مرده) | Low (پاک‌سازی) | — | delete | grep |
| اعلان‌ها | AzanForegroundService.kt L511 / core/ReminderReceiver.kt L105 / NotificationHelper.kt / NotificationChannelManager.kt / drawable/ic_notification.xml | `AzanForegroundService`/`NotificationChannelManager` | notification | اذان FGS + BigTextStyle یادآور + اعلان‌های Dart | 535/162/30/121/38 | native | Low | ⚠️ | KeepNative | **XML layout وجود ندارد**؛ فقط آیکون/محتوا قابل تغییر |

نکات بومی: ری‌استایل از Flutter ممکن نیست — فقط Kotlin/XML؛ تنها کلید مشترک `assets/content/widget_tokens.json` است و پیش‌نمای Flutter (`PrayerWidgetPreview`/`TasbihWidgetPreview`) باید دستی همگام بماند. `MainActivity.kt` (1098) میزبان کانال `com.tawheeed/azan` و `WidgetHub.refreshAll()` است (بدون UI).

## ۴. کامپوننت‌های مشترک: موجود / غایب + الگوهای تکرارشونده

### ۴.۱ موجود (پایهٔ موج ۱)
| کامپوننت | فایل | LOC | تست | یادداشت |
|---|---|---|---|---|
| TimeThemeKit/AppPalette/AppPalettes/SectionHues | lib/core/theme/time_theme.dart | 529 | ✅ time_theme_test | ۱۰ پالت × روشن/تاریک؛ `lerp` دارد؛ در ThemeData نصب می‌شود (theme.dart L543/L867) |
| AmbientBackground | lib/core/design_system/ambient_background.dart | 107 | ✅ ambient_background_test | گرادیان + ≤۴ blob ارزان؛ فعلاً فقط MainShell |
| GlassSurface | lib/core/design_system/glass_surface.dart | 89 | ✅ glass_surface_test | پرایمیتیو کارت بالفعل؛ ۱۲ مصرف‌کننده |
| CardDesignSystem + GoldFramedCard | lib/core/design_system/card_design_system.dart | 284 | ✅ gold_framed_card_test | پل توکن‌های legacy؛ ۱۰ مصرف‌کننده |
| IslamicPatternPainter | lib/core/design_system/islamic_pattern.dart | 56 | — | ستارهٔ ۸پر روی دیوار |
| ClockTicker | lib/core/services/clock_ticker.dart | 76 | ⚠️ | تایمر سراسری دوم/دقیقه + pause در background |
| PrayerClock/PrayerSnapshot | lib/features/prayer/domain/prayer_clock.dart | 258 | ✅ prayer_clock_test | progress کوانتیزه ۱/۶۰۰ — بدون rebuild هرثانیه |
| DateFormatters/TimeFormatters | home/presentation/utils | 18+ | ✅ | فرمت ۳تقویم |
| AppEmptyState/AsyncScreen/LoadingOverlay/ServiceUnavailableBanner | lib/shared/widgets/ | — | ✅ ۴ فایل تست | **موجود ولی کم‌استفاده** — الگوهای خالی/لود/خطا |

### ۴.۲ غایب (باید در گام ۱.۱ ساخته شود — لیست تأییدشده در `3a532e5`)
ArcPainter · RingPainter · GlassChip · OutlineChip · AppCard · IconTile · SettingRow · SliderRow · Stepper · SegmentedTabs · CheckCircle · AppBottomNav.
وضعیت فعلی: `_ArcPainter`/`_GlassChip`/`_OutlineChip`/`_HeroBackgroundPainter` خصوصی داخل `hero_card.dart`؛ نوار پایین inline در `main_shell.dart`؛ `SectionHeader` فقط feature-local در `education_widgets.dart` (باید promote شود).

### ۴.۳ الگوهای تکرارشونده (کاندیدهای استخراج مشترک)
- **کلاس‌های خصوصی هم‌نام در ≥۴ فایل**: `_SectionTitle`×5، `_RowLabel`×4، `_LegendDot`×4، `_EmptyState`×4، `_ContentSelector`×4، `_IntroTab`×4 (fasting/hajj/prayer/zakat-guide). → SectionHeader واحد + استفاده از AppEmptyState موجود.
- **۱۴ فایل CustomPainter**: islamic_pattern، tasbih_counter، tasbih_widget_preview، worship_checklist، hifz_report، hero_card، qcf4_surah_header (frozen)، quran_mushaf_overlays، widget_settings، inheritance_pie_chart، inheritance_share_card، moon_screen، hilal_sky_panel، evaluation_stats (`_CirclePainter`). → ArcPainter/RingPainter مشترک؛ painterهای حوزهٔ خاص (هلال، چرخ ارث، قطب‌نما) می‌مانند.
- **~۸۶ فایل مصرف‌کنندهٔ SectionColors** → با تصمیم بخش ۵ یک‌منبع می‌شود.
- **~۱۲ مصرف‌کنندهٔ GlassSurface + ۱۰ CardDesignSystem** → AppCard/Acard tokens واحد.
- **الگوی «اشتراک به‌صورت تصویر»**: `ShareService.shareWidgetAsImage` در قبله/اوقات شرعی/جمعه/ارزیابی/دنگی/حدیث/دوره — یک الگوی مشترک کارت اشتراک است.
- **الگوی کارتِ hero گرادیانی**: هدر تقویم عیناً از جعبهٔ ساعت خانه تقلید کرده؛ کارت تسبیح و hero فهرست سوره‌ها هم مشابه‌اند → HeroCard shell با `lite`.
- **الگوی دیالوگ ورود ساعت با ارقام فارسی**: adsreset روزانه، KhatmTimeDialog، period — یک helper مشترک.
- **الگوی hero/تیتر درون‌صفحه (`_HeroHeader`، `_Hero`)**: checklist/ruqyah/education — → یک کامپوننت.

## ۵. سیستم‌های رنگ موازی (و تصمیم قفل‌شده)

| سیستم | محل | مصرف | سرنوشت در فاز ۱ |
|---|---|---|---|
| `AppPalette`/`TimeThemeKit`/`AppPalettes` + `SectionHues` | core/theme/time_theme.dart | هستهٔ جدید (۶ تب + hero + فهرست سوره‌ها) | **مرجع (canonical)** — منبع واحد رنگ |
| `SectionColors` (191 خط) | core/theme/section_colors.dart | **۸۶ فایل** (حدیث، کتاب، ابزارها، به‌علاوهٔ نماز/شخصی/اهداف/ختم/یادآور/خانه…) | **منسوخ (deprecated)** — هویتِ موضوعی هر فیچر به فیلدهای پالت جدید map می‌شود؛ مصرف جدید ممنوع |
| `AppColors` + `AppTheme` (theme.dart 1428) | core/theme/app_colors.dart | تقریباً همه‌جا (legacy) | لایهٔ سازگاری موقت؛ فایل‌های بازطراحی‌شده دیگر از آن نخوانند |
| `WidgetTokens` (+`widget_tokens.json` native) | settings/…/widget_design_tokens.dart + android assets | فقط ویجت بومی + پیش‌نمای Flutter | **فقط اندروید (native)** — از پالت جدید فید نمی‌شود؛ همگام‌سازی دستی با `widget_tokens.json` |

**تصمیم قفل‌شده (طبق‌بازبینی کاربر):** `SectionHues`/`AppPalette` مرجع رسمی است؛ `SectionColors` منسوخ (فقط map شدن به پالت جدید برای هویت موضوعی ثابت تایل‌ها)؛ `WidgetTokens` فقط برای سطوح بومی اندروید. هیچ فایل بازطراحی‌شدهٔ جدیدی نباید به `SectionColors` یا `AppColors` وابسته شود.

## ۶. وابستگی‌ها (Dependencies)

### ۶.۱ وضعیت مشترک اپ (زیرساخت — همهٔ تب‌ها)
| فایل | تأمین می‌کند | مصرف‌کننده |
|---|---|---|
| lib/app/state/clock_providers.dart | `clockTickerProvider`, `liteModeProvider` (prefs `lite_mode`), `prayerClockProvider`, `timePhaseProvider`/`TimePhaseNotifier`, `phaseForSchedule`, `heuristicPhase` | MainShell, HeroCard, ردیف‌های اوقات، ویجت‌سینک |
| lib/app/state/shell_nav.dart | `shellTabIndexProvider` (+زیرتب اذکار) | MainShell + دیپ‌لینک‌ها |
| lib/app/state/pending_prayer.dart | تپ سرد اعلان → تب خانه | MainShell/Home |
| lib/app/state/boot_coordinator.dart ⚿ | بوت: مجوزها، سرویس‌ها | main.dart |
| lib/shared/providers/appearance_providers.dart | مقیاس فونت/ظاهر | root + تنظیمات |
| lib/shared/providers/service_providers.dart | سرویس‌های سراسری | بین فیچرها |
| lib/shared/providers/shared_prefs_provider.dart | prefs | تقریباً همه |

### ۶.۲ وابستگی هر گروه (providers / repositories / services)
| گروه | Providers | Repos | Services |
|---|---|---|---|
| خانه | — (widget_sync_provider) | — | widget_bridge, widget_sync, widget_sync_provider |
| نماز | ۵ (period_provider, period_session, prayer_tracker, prayer_time_helpers, …) | ۲ | ۸ (prayer_time، azan_playback، location_resolver، qibla_math، silent_mode، islamic_events، elevation_correction، …) |
| قرآن | ۲ (ayah_highlight, quran_bookmark) | — | ۸ (quran_content/search/storage/timing/translation، persian_translation، tafsir، mp3quran) |
| اذکار/تسبیح | ۵ (azkar, azkar_settings, tasbih (+daily_reset), duas) | ۱ (azkar) | ClickSoundPlayer (shared) |
| عبادات (ارزیابی/کتابخانه‌ها) | ۴ (evaluation, evaluation_notes_ops, evaluation_report, reading_streak) | — | — |
| ختم | ۱ | ۱ (khatm) | — |
| حفظ | ۱ (hifz) | — | — |
| یادآور | ۱ | ۱ (reminder) | — |
| اهداف | ۱ | ۱ (goal) | goal_reminder_scheduler |
| تنظیمات | ۵ (settings, notification_settings_notifier, …) | ۳ (settings, backup…) | ۶ (backup, update_checker, cloud_backup…) |
| شخصی | ۴ (vault_session, tool_locks, pin_lock…) | ۲ | ۶ (attachment_storage/scanner، pin_lock، insurance_expiry_sync…) |
| حساب/پیشنهاد/اعلان | ۳ | ۲+۲+۲ (account/cloud، firestore suggestions، firestore announcements) | — |
| کتاب‌ها/دانش | ۴ (books) | — | ۳ (+hadith/riyad/hadeeth_enc/dorar DB services) |
| ابزارها (`features/tools`) | ۵ | — | ۱۴ (moon/inheritance/zakat/calendar محاسباتی…) |
| یادداشت/کار/هزینه | ۵ | ۶ | ۵ (…_reminder_scheduler, exporters) |
| ملقّن/آزمایشگاه | ۳ | — | model downloader/catalog |

نکتهٔ cross-feature (مشاهده‌شده): Home → adhkar share / checklist / goals / reminders / evaluation (طاعات امروز) / widget bridge؛ ارزیابی → ختم؟ (نه — ختم جدا)؛ گزارش هزینه → زکات (`initialCashAmount`)؛ تقویم ← worship tracker (تیک روزه/عبادات روی سلول‌ها)؛ MainShell ← prefs (تب آغازین). «صفحات وابسته به آن» برای سطوح مشترک در ۴.۳ آمد (GlassSurface ۱۲، SectionColors ۸۶).

### ۶.۳ قید پایداری داده (همهٔ گروه‌ها)
Drift: جداول موجود + migration تا schema v42 (تست‌های `core/database` ۷ فایل). prefs: `onboarding_completed`, `is_premium`, `eval_*`, `notif_*`, `azkar_*`, `tool_locks.enabled`, `lite_mode`, `theme_kind` (از طریق سرویس تنظیمات). Backup: allowlist `BackupService.isRestorablePreferenceKey` + نام‌ستون‌های DTO. **هیچ کلید/ستون/مسیری تغییر نام نمی‌دهد.**

## ۷. اولویت‌بندی و نقشهٔ راه بازطراحی (Roadmap)

### ۷.۱ ترتیب اجباری (از اسپک): Home → More → Tasbih → Quran → Calendar → Report → Settings → بقیه
### ۷.۲ موج‌ها
| موج | محتوا | گیت‌ها |
|---|---|---|
| ۰ | کامپوننت‌های مشترک (§۴.۲) + تست/گلدن هرکدام؛ promote کردن `SectionHeader` | analyze، تست‌های design_system |
| ۱ | AppBottomNav + MainShell؛ سپس تب‌ها به ترتیب اسپک: خانه → بیشتر → تسبیح → قرآن(chrome) → تقویم → ارزیابی → تنظیمات | analyze خروجی تمیز، تست‌های همان فیچر سبز، اجرای اپ |
| ۲ | سطوح Highِ push شونده: تنظیمات نماز، قبله، فهرست سوره‌ها، شیت‌های پرکاربرد خواننده، اعلان‌ها | همان + بررسی RTL/textScale |
| ۳ | Mediumها به‌ترتیب گروه (ختم/حفظ، کتابخانه‌ها، یادآور/اهداف/شخصی، ابزارها، دانش) | همان |
| ۴ | Lowها (اشتراک‌ها، ویرایشگرها، تشخیصی، پنهان/فصلی) + ری‌استایل بومی اندروید (تصمیم §۷.۵) | همان |
| ۵ | پاک‌سازی ۱.۴ با شاهد grep (layoutهای مرده، drawable مرده، `period_section.dart` مشکوک، کد قدیمی بعد از مهاجرت) | کامیت جدا برای هر مورد + analyze/gate |

### ۷.۳ قواعد موج‌ها
- قاعدهٔ مهاجرت: **اول کامپوننت‌ها، بعد صفحه‌ها؛ حذف قدیمی‌ها فقط در پایان** (اپ همیشه باید build شود).
- کامیت به‌ازای هر صفحه/موج کوچک؛ پیام انگلیسی؛ stage per file.
- گلدن/اسکرین‌شات ۴ فاز با اورراید مخفی دیباگ (گام ۱.۳) در `docs/design/screens/`.

### ۷.۴ خلاصهٔ اولویت (Highها)
خانه (فید + Hero + اوقات + آمار + یادآور + رواتب) · تنظیمات نماز · قبله · تب قرآن + هدر/پلیرها + فهرست سوره‌ها · تب تسبیح + شمارنده · تقویم (هدر/سلول‌ها) · تب ارزیابی + بدنهٔ گزارش · بیشتر ⚿ · تنظیمات + اعلان‌ها. (جزئیات در ستون اولویت هر جدول.)

### ۷.۵ تصمیم‌های لازم قبل از اجرا (needs my decision)
1. **سطوح بومی اندروید**: ویرایش Kotlin/XML اسپلش/ویجت‌ها/اعلان‌ها انجام شود (و ریسک همگام‌سازی دستی با Flutter پذیرفته شود) یا فقط مستند شوند؟ (پیشنهاد: فقط `widget_tokens.json` + آیکون‌ها؛ بقیه KeepNative.)
2. **QuranTab/QuranMushafView**: خواننده روی `MushafPalette` بماند و فقط شیت‌ها/ناوبری به design system برود؟ (پیشنهاد: بله.)
3. **`mushaf_backgrounds.dart`** (473 LOC): قابل بازطراحی یا KeepNative؟ (پیشنهاد: نگه‌داشتن — انتخاب کاربر روی صفحهٔ قطعی اثر می‌گذارد.)
4. **AudioMiniPlayer**: قالب QuranChrome یا KeepNative (به `AudioLibraryPlayer` گره خورده)؟ (پیشنهاد: QuranChrome سبک.)
5. **`period_section.dart`** (206 LOC، صفر مصرف در lib): حذف تأیید می‌شود؟ (شاهد: grep کنونی.)
6. **۳ layout مرده + `splash_background.xml`**: حذف در ۱.۴ تأیید می‌شود؟ (شاهد grep: صفر ارجاع.)
7. **فایل‌های محافظت‌شده (⚿)**: آیا اسپک فاز ۱ برای ری‌استایل ظاهری `more_screen`/`personal_info`/`prompter`/`moon`/`dorar`/`zakat`/`period`/`ruqyah`/`ramadan`/`hajj`/`main.dart`/`boot_coordinator` مجوز می‌دهد؟ (پیشنهاد: بله با «ظاهر فقط، بدون منطق».)
8. **هزینه‌رویداد «حصن المسلم»** (`duas_screen.dart` + دوای پیرامونش): قطعی بماند؛ زیرصفحه‌ها (detail/share/intro) ری‌استایل شوند؟
9. **تناقض شماره‌گذاری «دعا»**: `RouteNames.dua`=دعاهای قرآنی، `RouteNames.duas`=حصن المسلم — هر دو در دامنهٔ فاز ۱ بمانند؟
10. **متغیرهای v1**: premium_card با خانه بازطراحی شود (تأیید قبلی) — تأیید نهایی.

## ۸. معیارهای پذیرش (Acceptance criteria)

### ۸.۰ سراسری (پایان فاز ۱)
- `flutter analyze`: هیچ error/warning جدید (پایه: ۷۸ info + ۲ warning موجود — نباید بیشتر شود).
- `python tools/quality_check.py --strict`: هر ۷ گیت = صفر.
- همهٔ تست‌ها سبز (۳۲۳۳ پایه) + تست‌های جدید کامپوننت‌ها/گلدن‌ها.
- هیچ ارجاعی به طرح قدیمی در سطوح مهاجرت‌کرده نماند (grep شاهد)؛ AppCard/SectionHeader/… در همه‌جا.
- `flutter build apk --release` موفق؛ حجم ≤ پایه (۴۹MB) یا دلتای موجه مستند.
- `docs/PHASE1_TEST_REPORT.md` + `docs/PHASE1_REPORT.md` (BASELINE vs AFTER) + لیست حذف‌شده‌ها + «نیاز به تصمیم».

### ۸.۱ معیار به‌ازای گروه (خلاصه)
| گروه | «تمام» وقتی… | تست‌های کلیدی که باید سبز بمانند | analyze |
|---|---|---|---|
| پوسته/راه‌اندازی | AppBottomNav روی shell؛ تم فاز زنده؛ اسپلش/آنبوردینگ با توکن‌ها | app_router, main_shell, splash_screen, splash_prefs_hang, onboarding | تمیز |
| خانه | ۶ زون اسپک روی HeroCard/AppCard؛ رواتب و اوقات با همان منطق | hero_card, home_prayer_summary, daily_stats, daily_adhkar_box, quick_reminders, friday_adab_card, quick_actions, rawatib_section, period_hayz_banner | تمیز |
| نماز/قبله/دوره | اوقات/تنظیمات/قبله/دوره با توکن‌ها؛ منطق محاسبه دست‌نخورده | prayer_clock, prayer_reference_table, prayer_golden_times, qibla_math, period_* | تمیز |
| قرآن | chrome جدید؛ صفحهٔ QCF4 بیت‌به‌بیت ثابت (گلدن‌ها) | ۳۲ فایل quran (مهم: qcf4 goldens, mushaf_reader_prefs, mushaf_widget) | تمیز |
| اذکار/تسبیح | شمارنده/لیست/شیت تنظیمات روی سیستم جدید؛ صدا/هپتیک حفظ | tasbih_counter_widget, azkar_list_widget, tasbih_provider, azkar_settings_provider | تمیز |
| عبادات | تقویم/گزارش/چک‌لیست و بقیه سطوح با قالب‌ها | evaluation_*, worship_*, checklist, fasting/fitr, period_section | تمیز |
| بیشتر/تنظیمات/شخصی | More با جستجو+سکشن‌ها؛ Settings با ردیف‌های جدید؛ قفل‌ها حفظ | more_screen, settings_screen(+persistence), notification_*, backup_*, tool_locks, vault_guard, personal_* | تمیز |
| دانش | کتاب‌ها/حدیث/علوم با قالب‌ها؛ رفتار جستجو حفظ | dorar parser/notifier, hadeeth_enc*, book_*, study, sciences, yaqeen_content | تمیز |
| ابزارها/شخصی | ابزارها با SpecializedViewer تمیز؛ منطق محاسبه دست‌نخورده | inheritance (۳۱), dongi, zakat, moon, calculator, notes/tasks/expenses | تمیز |
| اندروید | طبق تصمیم §۷.۵؛ در غیر این‌صورت مستند «بدون تغییر» | — (بدون تست) | — |

### ۸.۲ چک‌های هر صفحه (از اسپک ۱.۵)
تست build بدون overflow در textScale 1.0/1.3 × عرض 320/412dp × RTL؛ حالت‌های loading/empty/error/offline/permission؛ اسکرین‌شات ۴ فاز + before/after.

## ۹. گزارش حادثه‌ها (Incidents)

1. **پرشدن دیسک — 2026-10-06:** `C:` به ۱۰۰٪ رسید (۲.۵GB آزاد از ۴۶۶GB). علائم: شکست نوشتن همین سند (ENOSPC)، مرگ agent اسکن quran با ENOSPC، شکست build بیس‌لاین analyze-size (Gradle : «فضا کافی نیست»، 7m27s). رفع: حذف فقط `build/`های بازتولیدشدنی (`phase1-redesign`, `rel-build`, `rel-build-b6ad0b7`, `quran-paging`, `announcements`, `announcements-polish`, `friday_iso`, `suggestions-polish`, `wt_171`) → ۱۳GB آزاد. هیچ سورس/کامیت/APK لمس نشد. build سایز باید دوباره اجرا شود (انجام شد — BASELINE). فشار مجدد: پاک‌سازی `build/app/intermediates` در تری اصلی.
2. **مرگ خاموش agentهای اسکن (A/E):** اول A/E بدون خروجی ماندند؛ دوباره اجرا شدند. اسکن quran (B) با ENOSPC مرد و پس از رفع فضا دوباره اجرا شد و کامل شد. درس: قبل از اجرای agentهای پرحجم، آزاد بودن ≥۵GB بررسی شود.
3. **شکست ابزار analyze-size (fork):** پس از `assembleRelease` موفق، خواندن `build/flutter_size_01/snapshot.*.json` شکست می‌خورد (باگ Flutter tool فورک Codebuff). APK سالم است؛ مقایسه‌ها در سطح کل‌APK انجام می‌شود (در BASELINE ثبت شد).

## ۱۰. پیوست: فایل‌های >۱۰۰۰ LOC (۴۲ فایل)

| # | فایل | LOC | گروه | نقش در فاز ۱ |
|---|---|---|---|---|
| 1 | quran/mushaf/quran_mushaf_view.dart | 2417 | قرآن | chrome (حساس — overlay/PAGE قطعی) |
| 2 | settings/…/pages/settings_screen.dart | 1959 | تنظیمات | High — بازطراحی |
| 3 | worship/…/evaluation_stats_widget.dart | 1941 | عبادات | High — بازطراحی |
| 4 | quran/data/page_data.dart | 1879 | قرآن | داده (دست‌نزن) |
| 5 | shared/services/notification_service.dart | 1856 | زیرساخت | منطق اعلان (دست‌نزن) |
| 6 | tools/zakat/…/zakat_screen.dart | 1854 | ابزار ⚿ | بازطراحی ظاهری |
| 7 | tools/inheritance/…/inheritance_calculator_tab.dart | 1785 | ابزار | بازطراحی ظاهری |
| 8 | books/…/ketabkhaneh_screen.dart | 1761 | دانش | بازطراحی |
| 9 | education/…/study_widgets.dart | 1730 | دانش | بازطراحی |
| 10 | prayer/…/qibla_screen.dart | 1673 | نماز | High — بازطراحی |
| 11 | prompter/…/prompter_screen.dart | 1593 | ملقّن ⚿ | بازطراحی ظاهری |
| 12 | hadith/…/hadith_books_screen.dart | 1556 | دانش | بازطراحی |
| 13 | audio_library/…/audio_library_screen.dart | 1545 | صوتی | بازطراحی |
| 14 | prayer/…/providers/period_provider.dart | 1490 | نماز ⚿ | منطق دوره (دست‌نزن) |
| 15 | audio_library/audio_library_player.dart | 1490 | صوتی | منطق پلیر |
| 16 | tools/inheritance/domain/madhab_calculator.dart | 1488 | ابزار | منطق (دست‌نزن) |
| 17 | core/theme/theme.dart | 1428 | زیرساخت | لایهٔ سازگاری legacy |
| 18 | prayer/data/iran_cities.dart | 1379 | نماز | داده |
| 19 | notes/…/worship_notes_screen.dart | 1376 | شخصی | بازطراحی |
| 20 | tools/moon/…/moon_screen.dart | 1357 | ابزار ⚿ | بازطراحی ظاهری |
| 21 | reminders/…/reminder_editor_screen.dart | 1347 | عبادات | بازطراحی |
| 22 | fasting/…/ramadan_tracker_tab.dart | 1286 | عبادات ⚿ | بازطراحی ظاهری |
| 23 | prayer/…/prayer_settings_screen.dart | 1263 | نماز | High — بازطراحی |
| 24 | books/…/book_reader_screen.dart | 1263 | دانش | بازطراحی |
| 25 | goals/…/goal_detail_screen.dart | 1228 | اهداف | بازطراحی |
| 26 | settings/services/backup_service.dart | 1214 | تنظیمات | منطق (دست‌نزن) |
| 27 | adhkar/tasbih/…/tasbih_counter_widget.dart | 1194 | اذکار | High — بازطراحی |
| 28 | khatm/…/khatm_stats_screen.dart | 1190 | ختم | بازطراحی |
| 29 | settings/…/widget_settings_screen.dart | 1178 | تنظیمات | بازطراحی |
| 30 | adhkar/duas/…/duas_screen.dart | 1162 | حصن ⚿قطعی | **قطعی** |
| 31 | prompter/…/prompter_session_provider.dart | 1146 | ملقّن ⚿ | منطق (دست‌نزن) |
| 32 | personal_info/…/personal_info_screen.dart | 1129 | شخصی ⚿ | بازطراحی ظاهری |
| 33 | tools/inheritance/…/inheritance_comparison_tab.dart | 1107 | ابزار | بازطراحی ظاهری |
| 34 | home/…/daily_adhkar_box.dart | 1090 | خانه | بازطراحی |
| 35 | ruqyah/…/ruqyah_screen.dart | 1081 | رقیه ⚿ | بازطراحی ظاهری |
| 36 | quran/mushaf/quran_mushaf_pre_download_sheet.dart | 1080 | قرآن | بازطراحی |
| 37 | suggestions/…/suggestions_screen.dart | 1060 | حساب | بازطراحی |
| 38 | yaqeen/…/yaqeen_lesson_screen.dart | 1047 | دانش | بازطراحی |
| 39 | worship/…/providers/evaluation_provider.dart | 1033 | عبادات | منطق (دست‌نزن) |
| 40 | quran/mushaf/qcf4/qcf4_page_viewer.dart | 1016 | قرآن | **قطعی (frozen)** |
| 41 | tasks/…/tasks_dialog.dart | 1010 | شخصی | بازطراحی |
| 42 | hadeeth_enc/…/hadeeth_enc_screen.dart | 1005 | دانش | بازطراحی |

---

*تهیه‌شده در 2026-10-06 روی `3a532e5`؛ منبع اعداد: گزارش‌های ۵ اسکن + اسکن‌های مکانیکی `wc -l`/grep. به‌روزرسانی این سند بعد از هر موج لازم است.*
