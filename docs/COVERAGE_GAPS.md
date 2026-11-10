# شکاف‌های پوشش تست (Coverage Gaps)

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


فهرست فیچرهایی که **صفر یا یک** فایل تست دارند (یا به‌تازگی پوشش گرفته‌اند و باید
پایداری‌شان بررسی شود). اعداد بر اساس شمارش `test/features/**/*_test.dart` در
زمان نگارش است. اولویت افزودن تست: unit test دامنه ← Provider ← smoke test اسکرین
(الگوها در `FEATURE_CONTRACT.md` بند ۴).

## دقیقاً یک فایل تست (شکننده — با هر حذف تست، به صفر می‌رسد)

| فیچر | تست فعلی | چه چیزی پوشش ندارد |
|---|---|---|
| `dua_from_quran` | `data/dua_from_quran_data_test.dart` | اسکرین‌ها (`dua_from_quran_screen`, `dua_from_quran_share_screen`) و entity بدون تست |
| `fasting` | `presentation/fitr_zakat_tab_test.dart` | `fasting_screen.dart`، `ramadan_tracker_tab.dart`، `data/fasting_content.dart` — پوشش فقط یک تب |
| `fatwa` | `services/fatwa_service_test.dart` | `fatwa_screen.dart` بدون smoke test |
| `hajj_umrah` | `presentation/hajj_umrah_screen_test.dart` | منطق/دادهٔ فیچر (فقط اسکرین) |
| `onboarding` | `presentation/onboarding_screen_test.dart` | منطق مسیریابی/پیشرفت بعد از onboarding |
| `splash` | `presentation/splash_screen_test.dart` | منطق bootstrap/هدایت (فقط یک تست اسکرین) |
| `yaqeen` | `yaqeen_content_test.dart` | `yaqeen_progress`، `yaqeen_gamification`، `yaqeen_quiz_data` و اسکرین‌ها |
| `tools/calendar` | `calendar_logic_test.dart` | اسکرین و ویجت‌های تقویم (محتوای تست نازک) |
| `tools/purification` | `purification_screen_test.dart` | دامنه/منطق محاسباتی (فقط smoke اسکرین) |

## به‌تازگی پوشش اضافه شده — پایداری را بررسی کنید

| فیچر | تعداد تست | وضعیت |
|---|---|---|
| `account` | ۳ تست (+ `test/diag_account_test.dart`) | پوشهٔ `test/features/account/` تازه اضافه شده — اطمینان از پایداری در CI |
| `search` | ۲ تست | پوشهٔ `test/features/search/` تازه اضافه شده — اطمینان از پایداری در CI |

## تست‌های امنیتی (مرتبط با ممیزی)

این تست‌ها قراردادهای امنیتی را قفل می‌کنند؛ اگر عمداً تغییرشان دادید، بدانید که
سفتی سیستم را کم کرده‌اید:

| فایل | چه چیزی را تضمین می‌کند |
|---|---|
| `test/features/settings/services/update_checker_test.dart` | بروزرسانی بدون `apkSha256` معتبر هرگز پیشنهاد نمی‌شود؛ `apkUrl`/`playUrl` فقط از میزبان‌های مجاز و `https` |
| `test/features/settings/services/backup_restore_limits_test.dart` | سقف حجم/تعداد از دایرکتوری مرکزی zip *قبل* از decode؛ کلیدهای vault/اعتبار در پشتیبان نمی‌روند |
| `test/features/quran/services/quran_content_security_test.dart` | نام فایل کاتالوگ نمی‌تواند از پوشهٔ محتوا بیرون بزند؛ کاتالوگ بزرگ/خراب رد می‌شود؛ gzip bomb حین باد کردن متوقف می‌شود |
| `test/core/database/failed_migration_recovery_test.dart` | پاکسازی سیگنال ناموفق، بازیابی از اسنپ‌شات و حفظ فایل‌های فورENSیک |
| `test/features/prayer/services/azan_service_test.dart` | انتخاب و اعتبارسنجی فایل اذان سفارشی |

`tools/fcm_server.mjs` و `firestore.rules` تست واحد ندارند (خارج از `flutter test`)؛
پس از تغییر دستی، رفتارشان را با اجرای محلی بررسی کنید.

## بدون هیچ تستی

همهٔ فیچرهای سطح بالای `lib/features/` در زمان نگارش ≥۱ فایل تست دارند؛ بنابراین
فعلاً فیچرِ **کاملاً بدون تست** وجود ندارد. پس از حذف/انتقال تست‌ها این بخش را
به‌روزرسانی کنید.

## پوشش‌های نازک بر اساس لایه (فراتر از شمارش فایل)

- `fasting`: فقط تب زکات فطر — کل اسکرین اصلی روزه پوشش ندارد.
- `yaqeen`: فقط محتوا — progress/gamification که state دارند تست ندارند.
- `dua_from_quran`: فقط داده — هیچ widget test برای دو اسکرین نیست.
- `splash`/`onboarding`: یک تست هر کدام — مسیرهای خطای bootstrap پوشش ندارند.
- `tools/calendar`: منطق خالص دارد ولی تعامل UI تست نشده است.

نکته: `lib/features/tasks/**` و `lib/features/expenses/**` (ممنوع از ویرایش در این فاز)
به‌ترتیب ۵ و ۴ تست دارند — خارج از محدودهٔ این گزارش.
