# گزارش تحویل ابزارهای شخصی — ۱.۸.۰+۱۰۰۱۷

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


همهٔ ابزارهای شخصی (خودرو، خانه، دفتر مالی/دَین، صله رحم، کفاره، قلک،
قضایار، مغازه، کودک، مربی، تبدیل واحد) حالا در بخش «ابزارها و پیشرفت» صفحهٔ
بیشتر هستند و مسیر فازبندی‌شدهٔ `docs/PERSONAL_TOOLS_ROADMAP.md` تا آخر رفته
است. این سند فقط چیزی را می‌گوید که در همین درخت **تأیید شده** است.

## ۱. فازها و هش‌ها

| فاز | کار | هش |
| --- | --- | --- |
| ۰ | کاشی خودرو/خانه در `MoreGroup.tools`، `tool_identity.dart`، رفع تداخل بازهٔ اعلان‌ها | `0006bb2` |
| نقشه | ماتریس ۱۱ ابزار + G-2…G-9 | `c35c439` |
| ۱ | گزارش مغازه: پنجرهٔ شمسی، شش رقم + مقایسه، drill-down، کندگردها، PDF + ZIP CSV | `963c0a9` |
| ۲ | پک فصلی خانه با پنجرهٔ خودِ پک (G-3) | `445fdbd` |
| ۳ | گزارش ماهانهٔ کودک + خلاصهٔ شب + سه یادآور مربی (G-4، G-5) | `f582e6a`، `43f2b53` |
| ۴ | ویرایشگر «تنظیم پیش‌فرض‌ها» برای قالب‌های سرویس (G-6) | `01ba249` |
| ۵ | مرور شش ابزار + انباری محتوای کفاره (`docs/KAFFARA_CONTENT.md`) | `1c824bb` |
| ۶ | رفع چهار رگرسیون گیت + بیلد ریلیس | `04d9a7d` |
| ۷ | همین سند + `PROGRESS.md` + نقشه | همین کامیت |

## ۲. فایل‌های تازه

- `lib/features/personal/care_engine/care_season_plan.dart` — پنجرهٔ فصلی،
  وضعیت «در پنجره / پیش / گذشته»، بنر.
- `lib/features/personal/care_engine/care_template_overrides.dart` +
  `presentation/widgets/care_defaults_sheet.dart` — ویرایش فاصله‌های
  پیشنهادی و بازگردانی.
- `lib/features/personal2/kids/services/kid_evening_summary.dart` — هفت شب،
  کلید per-day، احترام به ساعات سکوت.
- `lib/features/personal2/teacher/services/teacher_reminders.dart` — شروع
  کلاس، ثبت درس، خلاصهٔ جمعه.
- گزارش مغازه در همان `shop_report_tab.dart` بازنویسی شد (فایل تازه ندارد).
- تست‌ها: `care_season_plan_test`، `care_template_overrides_test`،
  `kid_report_window_test`، `kid_evening_summary_test`،
  `teacher_reminders_test`، `shop_report_range_test`، `shop_report_dao_test`،
  `shop_report_tab_test` و هارنس `fake_care_template_overrides.dart`.

## ۳. باگ واقعی که تست‌ها گرفتند

`kidDayKeyOf`/`teacherDayKeyOf` سال میلادی را به `Jalali(year, month, day)`
می‌دادند؛ آن سازنده اجزای **شمسی** می‌خواهد، پس کلید ۲۰۲۶-۱۱-۰۵ به
`3648-…` تبدیل می‌شد و هر روز کلید تازه‌ای برای اعلان می‌ساخت. حالا هر دو از
`Jalali.fromDateTime` می‌آیند (۲۰۲۶-۱۱-۰۵ → `1405-08-14`).

## ۴. عددهای تأیید

- `flutter test test/features/personal test/features/personal2` = **۷۰۶ سبز**.
- `type_scale_guard_test`, `sheet_contract_test`, `latin_digits_guard_test` =
  **۱۱ سبز**.
- `flutter analyze lib test` = **۰ خطا / ۰ هشدار** (۳۰۶ info که همه از پیش
  بودند).
- `python tools/quality_check.py --strict` = فقط همان قرمزهای پایه
  (۹ silent catch، ۲ `]!`، ۲ provider در screen، ۲ widget wiring، ۱
  failure surface) — هیچ‌کدام در فایل‌های این کار نیست.
- تست کامل `flutter test --exclude-tags network` روی `1c824bb`:
  ۵۸۱۷ سبز / ۹ skip / ۲۰ شکست؛ از آن ۲۰، سه‌تا مال این کار بود (بالا رفع شد)
  و بقیه در `release/1.8.0` هم قرمزند: google-services در worktree نیست،
  schema v47 در حالی که دیتابیس به ۴۹ رسیده، پالت ویجت (۹ → ۸)، تست
  `AndroidRemoteViews`، و دو تست صفحهٔ حساب/اطلاعات شخصی.

## ۵. ریلیس

از درخت تمیز detached روی `04d9a7d`، با چهار فایل gitignored کپی‌شده
(`android/key.properties`، `android/app/release-key.jks`،
`android/app/google-services.json`، `assets/env/quran_api.env`)، بدون
dart-define (Sentry خاموش: DSN در ریپو نیست):

- `app-release.apk` — ۴۹٬۹۹۵٬۴۴۴ بایت (۴۷٫۷ مگابایت)،
  sha1 `4c919b826f3797c69c46fae554d9a4293cd022ae`، `version: 1.8.0+10017`.
- ABI split ساخته نمی‌شود: بلوک `splits` در `android/app/build.gradle` عمداً
  خاموش است و هر دو ABI با `ndk.abiFilters` در همین یک فایل هستند.
- نسخهٔ پایدار در `Desktop/tawheeed-release-apks/1.8.0-04d9a7d/` همراه
  `SHA1SUMS.txt` و `BINARY_PROOF.txt`.
- اثبات باینری روی `lib/arm64-v8a/libapp.so` با UTF-16LE در **هر دو**
  alignment: ۱۲ رشتهٔ درست FOUND («تنظیم پیش‌فرض‌ها»، «هر چند روز»،
  «بازگردانی»، «این ماه»، «بازهٔ دلخواه»، «کالاهای کندگرد»، «سرمایهٔ خوابیده»،
  «گزارش ماهانه»، «نیم ساعت وقت دارید.»، «ثبت درس»، «خلاصهٔ هفته»،
  «یادآورها») و ۳ شکل CP1256 همان رشته‌ها ABSENT.

## ۶. چیزهایی که فقط با شما بسته می‌شود

1. **G-7 / کفاره** — هر دو قاعده در `assets/data/kaffara_rules.json` هنوز
   `reviewed:false` هستند، پس ابزار عمداً «این حکم هنوز در برنامه موجود نیست»
   نشان می‌دهد. متن و عدد باید از شما بیاید؛ مسیر تأیید در
   `docs/KAFFARA_CONTENT.md` نوشته شده.
2. **G-8 / دستگاه** — هیچ گوشی اندرویدی وصل نیست، پس هیچ‌کدام از ادعاهای بالا
   روی دستگاه آزمایش نشده: گلدن‌ها هم فونت بارگذاری نمی‌کنند (شکل حروف
   دیده نمی‌شود) و فقط چیدمان و رنگ را نگه می‌دارند.
3. **ادغام در `release/1.8.0`** — شاخهٔ `release/1.8.0` جلوتر رفته
   (`d2de107`) و یک نشست موازی روی همان درخت کار می‌کند؛ این شاخه
   (`move/stage3-tools`) هنوز merge نشده است.
