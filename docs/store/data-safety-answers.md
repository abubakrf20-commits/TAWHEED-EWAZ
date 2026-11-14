# پاسخ‌های «ایمنی داده» در Play Console — توحید

پاسخ‌های دقیق فرم Data safety، تا هر بار از صفر پر نشود.
بسته: `com.islamic.tawheeed` — versionCode از `SHIPPED_VERSION_CODE` در
`android/app/build.gradle.kts`، versionName از `pubspec.yaml`.

## جمع‌بندی

- داده جمع‌آوری می‌شود؟ **بله، فقط در دو مسیر اختیاری**: پیشنهاد/انتقاد با حساب، و
  گزارش خطای Sentry وقتی DSN تنظیم شده باشد.
- داده فروخته می‌شود؟ **نه.** تبلیغات؟ **نه.** ردیابی بین اپ‌ها؟ **نه.**
- انتقال رمزنگاری‌شده؟ **بله** (همهٔ درخواست‌ها HTTPS).
- حذف داده؟ **بله** — درون برنامه و از طریق صفحهٔ عمومی
  `https://abubakrf20-commits.github.io/TAWHEED-EWAZ/store/account-deletion.html`
  (نسخهٔ مخزن: `docs/store/account-deletion.html`).

## جدول داده‌ها

| نوع داده | جمع‌آوری | اشتراک‌گذاری | اختیاری | هدف | حذف |
| --- | --- | --- | --- | --- | --- |
| موقعیت (تقریبی/دقیق) | بله | نه | بله (اجازهٔ مکان) | اوقات نماز و قبله | پاک‌کردن دادهٔ اپ |
| شناسهٔ کاربر (حساب) | بله | نه | بله (ورود) | ارسال پیشنهاد | حذف حساب |
| متن پیام کاربر | بله | نه | بله | رسیدگی به بازخورد | حذف حساب |
| گزارش خرابی/عیب‌یابی | بله | بله (Sentry) | فقط نسخهٔ منتشرشده | پایداری برنامه | تا ۹۰ روز |
| سابقهٔ جست‌وجو | نه | نه | — | — | روی دستگاه |
| دادهٔ سلامت (عادت ماهانه) | نه، روی دستگاه | نه | بله | قفل روزهای عادت | پاک‌کردن دادهٔ اپ |

## پاسخ‌های فرم

- «Does your app collect or share any of the required user data types?» → **Yes**
- «Encrypted in transit?» → **Yes**
- «Do you provide a way for users to request data deletion?» → **Yes**
  (`https://abubakrf20-commits.github.io/TAWHEED-EWAZ/store/account-deletion.html`)
- Location (Approximate/Precise): Collected, **not shared**, optional, purpose
  «App functionality», not for ads, **not** ephemeral (شهر انتخابی روی دستگاه).
- Personal info → User IDs: Collected, not shared, optional, «App functionality».
- App activity → Other user-generated content: Collected, not shared, optional.
- App info and performance → Crash logs / Diagnostics: Collected, **shared with
  Sentry**, optional, Analytics → **No**, retention تا ۹۰ روز.
- Designed for children? → **No** (سن هدف ۱۳+؛ «باغ کودکان» قابلیت خانوادگی است).
- Ads → **No**. In-app purchases → **No**.

## نکته‌های بررسی‌شده در کد

- موقعیت با اجازهٔ کاربر و روی دستگاه: `lib/features/prayer/**` و مجوز
  `ACCESS_FINE_LOCATION` در `android/app/src/main/AndroidManifest.xml`.
- Sentry فقط با `--dart-define=SENTRY_DSN=...` روشن می‌شود: `lib/main.dart`
  (`_sentryDsn`)، guide در `docs/ERROR_TRACKING.md`.
- حذف حساب درون برنامه:
  `lib/features/account/presentation/screens/account_screen.dart`.
