# ابزارهای شخصی — مرحلهٔ ۲: دفتر مالی و تبدیل واحد

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


شاخه: `personal/stage2-finance` (شاخه از `personal/stage1-care`، tip `6accd53`).
بدون push (مخزن هیچ ریموتی ندارد). بدون build_runner.

## ۱) چه چیزی ساخته شد

همه‌چیز داخل ساختار موجود می‌ماند: **هیچ هاب یا داشبوردی اضافه نشد** و چیزی به
خانه/بیشتر اضافه نشد.

- **«دفتر مالی»** فقط به‌عنوان یک ورودی در بخش «ابزارهای شخصی» صفحهٔ «اطلاعات من»
  ثبت شد (همان قفل/`VaultGuard` مرحلهٔ ۱). مسیرها:
  `/personal-info/finance` و `/personal-info/finance/person/:id`.
- **«تبدیل واحد»** یک تب در همان ماشین‌حساب موجود است (`_CalcTab.calc` /
  `_CalcTab.converter`)؛ چیپ قدیمی `_CalcMode.unit` حذف شد و مقدار ذخیره‌شدهٔ
  `unit` به `standard` نگاشت می‌شود. صفحه‌کلید مشترک است: رقم‌ها به تبدیل واحد
  تزریق می‌شوند (`GlobalKey<UnitConverterViewState>.applyKeypad`).

### دفتر مالی

| فایل | نقش |
| --- | --- |
| `finance_models.dart` | `Obligation`, `InstallmentPlan`, `Person`, `DebtEntry`, `DebtPayment`, `FinanceSnapshot` + برچسب‌های فارسی |
| `finance_engine.dart` | خالص Dart: روزهای مانده/تأخیر، سبدهای زمانی، جمع‌ها، ماه‌های جلالی، ساخت اقساط، ماندهٔ هر شخص |
| `finance_tables.dart` | DDL خام SQL، همه `IF NOT EXISTS` (بدون Drift codegen) |
| `finance_repository.dart` | خواندن/نوشتن با `customSelect`/`customStatement` روی همان `AppDatabase` |
| `finance_providers.dart` | Riverpod: snapshot، فیلترها، تب، تنظیمات یادآوری |
| `finance_reminder_planner.dart` | ساخت رخدادها (خالص، قابل تست) |
| `finance_reminder_scheduler.dart` | ثبت روی `NotificationService().scheduleExactReminder` |
| `finance_settings.dart` | SharedPreferences برای تنظیمات یادآوری |
| `presentation/*` | `FinanceScreen` (هیرو + تایم‌لاین + پیش‌نمایش ماه)، `DebtPersonScreen`، شیت‌ها، ویجت‌ها |

قواعد رعایت‌شده: **هیچ حکم فقهی و هیچ محاسبهٔ سود/ربا** در کد نیست؛ دفتر دَین فقط
مبلغ/تاریخ/یادداشت ثبت می‌کند؛ برنامه هیچ پیامی نمی‌فرستد (فقط share sheet) و
هیچ‌وقت مخاطبین را نمی‌خواند.

### تبدیل واحد

`assets/data/units.json` هفت دسته (طول، وزن، مساحت، حجم، دما، سرعت، محلی).
ساختار: `unit_models.dart` (کاتالوگ + تبدیل، شامل دما به‌صورت affine)،
`local_unit.dart`، `local_units_repository.dart` (جدول `unit_local_override`)،
`unit_providers.dart`، `unit_prefs.dart` (آخرین تب/دسته/علاقه‌مندی‌ها، غیرحیاتی).

## ۲) پیش‌فرض‌هایی که باید تأیید شوند (flagged for review)

اینها همه **قابل ویرایش در برنامه** هستند و پیشنهادند، نه فتوا یا استاندارد:

1. **واحدهای محلی** — فقط همین شش مورد با مقدار اولیه می‌آیند، همه
   `verified:false`: من (تبریز) = ۳ کیلوگرم، سیر = ۷۵ گرم، مثقال = ۴٫۶۰۸ گرم،
   نخود = ۰٫۱۹۲ گرم، خروار = ۳۰۰ کیلوگرم. هر واحد محلی دیگری که کاربر اضافه کند
   با ردیف خالی «مبنا را وارد کنید» شروع می‌شود. یادداشت بالای این دسته:
   «مبنای واحدهای محلی در هر منطقه فرق دارد.»
2. **یادآوری مالی**: فعال، ساعت ۹، سکوت ۲۲ تا ۷. هر تعهد سه رخداد می‌سازد:
   `due − remindBeforeDays`، روز سررسید، و روز بعد (تنبیه تأخیر)؛ رخدادهای گذشته
   دور ریخته می‌شوند.
3. **`remindBeforeDays` پیش‌فرض ۳ روز** برای هر تعهد تازه.
4. **متن سه قالب یادآوری دَین** (`assets/data/debt_message_templates.json`:
   مؤدبانه/کوتاه/نرم و همراه) فقط جای‌نگهدار `{name}`, `{amount}`, `{date}`
   دارند و از share sheet بیرون می‌روند — ادبیاتشان را لطفاً یک‌بار بخوانید.
5. **واحد پول** «تومان» است (قابل تغییر در snapshot تنظیمات صفحه).

## ۳) پایگاه داده و پشتیبان

- Schema **۴۵ → ۴۶**، افزایشی: `finance_plan`, `finance_obligation`,
  `finance_person`, `finance_debt_entry`, `finance_debt_payment`,
  `unit_local_override` + ۴ ایندکس. هر دستور `IF NOT EXISTS` است، پس مهاجرت
  نیمه‌کاره قابل تکرار است و نصب تازه no-op می‌شود.
- مبناهای واحد محلی **در database** ذخیره می‌شوند، نه SharedPreferences، چون
  پشتیبان‌گیری یک snapshot کل‌فایل است (`VACUUM INTO`) و باید آن‌ها را هم ببرد.
  تست `app_database_schema_v46_test.dart` همین رفت‌وبرگشت را ثابت می‌کند.

## ۴) یادآوری‌ها

- بازهٔ شناسهٔ اختصاصی **۱۴۰۰۰–۱۴۹۹۹** (`14000 + day-of-year`)، همراه با کامنت
  در `lib/shared/services/notification_ids.dart`. Payload با پیشوند `finance_`.
- کانال `finance_reminders_v1` با نام «یادآوری مالی» — جدا از کانال مرحلهٔ ۱
  (۱۳۰۰۰–۱۳۹۹۹) و بقیهٔ برنامه.
- ثبت با `NotificationService().scheduleExactReminder` انجام می‌شود، نه
  `zonedSchedule` خام؛ همان اجازه‌ها و همان سیاست اندروید ۱۳.

## ۵) تست‌ها

| فایل | تعداد |
| --- | --- |
| `test/features/personal/finance/finance_engine_test.dart` | ۴۰ |
| `finance_reminder_test.dart` | ۱۲ |
| `finance_repository_test.dart` | ۱۳ |
| `finance_screen_test.dart` (۳۲۰/۳۶۰/۴۱۲ dp، مقیاس ۱٫۰/۱٫۳) | ۸ |
| `test/features/tools/calculator/units/unit_converter_test.dart` | ۲۶ |
| `test/features/tools/calculator/unit_converter_view_test.dart` | ۶ |
| `test/core/database/app_database_schema_v46_test.dart` | ۵ |
| **جمع تازه** | **۱۱۰** |

پوشش: موتور (سبدها، تأخیر، جمع‌ها، ماه جلالی و کبیسه، ساخت اقساط، undo،
ماندهٔ شخص)، پلنر (سه رخداد، حذف گذشته، سقف تعداد، گروه‌بندی، ساعت سکوت)،
واحدها (طول/وزن/مساحت/حجم/دما/سرعت، مبنای محلی، قالب عدد)، ویجت (بدون overflow
در سه عرض و دو مقیاس، حالت خالی، تب دَین، فیلتر نوع) و schema/backup.

گلدن‌ها (tofu، بدون فونت در binding — نگهبان چیدمان و پالت، نه شکل حروف):
`finance_timeline_day.png`, `finance_debt_day.png`, `unit_converter_day.png`.

`flutter analyze lib test` = **۰ error / ۰ warning** (بقیهٔ infoهای از قبل موجود
در فایل‌های لمس‌نشده). `python tools/quality_check.py --strict` = **همه صفر**.

کل مجموعه: `flutter test --exclude-tags network` = **۴۸۲۰ passed / ۹ skipped /
۲ failed**؛ هر دو شکست همان `chrome_follows_theme_test` از قبل موجودند (در HEAD
مرحلهٔ ۱ هم ناموفق بودند و به قرآن/ناوبری مربوط‌اند، نه به این کار).

## ۶) کارایی

دستگاه اندرویدی متصل نبود، پس **هیچ عدد on-device اندازه‌گیری نشد**. کارهای
سنگین عمداً در لایهٔ داده‌اند (`customSelect` مستقیم، بدون rebuild کل صفحه) و
رخدادهای یادآوری یک‌بار در planner ساخته می‌شوند. عددهای واقعی پس از نصب APK
باید گرفته شود.

## ۷) پرسش‌های باز

- سقف تعداد یادآوری فعال در مرحلهٔ ۱ (۲۴) برای مالی کافی است یا باید بیشتر شود؟
- آیا یادآوریِ روزِ بعد از سررسید (تنبیه تأخیر) خواسته است یا آزاردهنده؟
- آیا «خروار = ۳۰۰ کیلوگرم» برای منطقهٔ کاربر درست است؟ (تبریز ۳۰۰، جاهای دیگر
  تفاوت دارد — به همین دلیل قابل ویرایش است.)
