# 🚀 چک‌لیست نهایی انتشار گوگل‌پلی — برنامه «توحید» v1.5.0

> تاریخ: ۱۷ مرداد ۱۴۰۵ — همهٔ وضعیت‌های این سند از **کد واقعی، مانیفست و بیلد نهایی** چک شده‌اند، نه حدس.

---

## ۱) مشخصات بیلد (تأییدشده ✅)

| مورد | مقدار | منبع تأیید |
|---|---|---|
| **Application ID** | `com.islamic.tawheeed` | `build.gradle.kts` + `aapt2 dump badging` |
| **versionName** | `1.5.0` | `build.gradle.kts` + badging |
| **versionCode** | `2003` | `build.gradle.kts` + badging |
| **minSdk / targetSdk / compileSdk** | Flutter default / Flutter default / **36** | `build.gradle.kts` |
| **فایل آپلود** | `releases/app-release-v1.5.0.aab` (۱۲۲.۱MB) | بیلد از شاخهٔ `release/1.5.0` |
| **تأیید bundletool** | ✅ `validate` PASS + ساخت APK موفق | bundletool 1.18.3 |
| **امضا (Signing)** | ✅ V1+V2+V3 — `CN=Tawheed, O=TawheedApp, C=IR` | `apksigner verify --print-certs` |
| **گواهی upload** | کلید SHA-256: `d99cb552c424…78f1b` | apksigner |
| **ABI ها** | `arm64-v8a` + `armeabi-v7a` | `build.gradle.kts` splits |
| **R8/minify** | ✅ فعال (`isMinifyEnabled=true`) | build.gradle.kts |

**⚠️ مهم:** شماره گواهی و keystore را در جای امن نگه دارید — بدون آن نمی‌توانید نسخهٔ بعدی را آپلود کنید.

---

## ۲) مجوزها (از مانیفست نهایی چک شد)

### وضعیت مطلوب: ✅ دو مجوز مشکوک قبلاً حذف شده‌اند

| مجوز | وضعیت | توضیح |
|---|---|---|
| ~~`USE_FULL_SCREEN_INTENT`~~ | ✅ **حذف شده** | در مانیفست فعلی نیست — ریسک رد خودکار رفع شد |
| ~~`READ_MEDIA_AUDIO`~~ | ✅ **حذف شده** | انتخاب فایل صوتی با SAF انجام می‌شود، مجوز لازم نیست |
| `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` | ✅ در مانیفست | محاسبهٔ اوقات شرعی و قبله — **نیازمند ویدئوی نمایش** |
| `SCHEDULE_EXACT_ALARM` | ✅ در مانیفست | اذان‌های دقیق — دسته «Alarms & reminders» در کنسول |
| `POST_NOTIFICATIONS` | ✅ در مانیفست | اعلان اذان، یادآورها، اذکار روزانه |
| `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | ✅ در مانیفست | پخش اذان (سرویس کوتاه‌عمر با دکمه توقف) |
| `RECEIVE_BOOT_COMPLETED` | ✅ در مانیفست | برنامه‌ریزی مجدد اذان پس از ری‌استارت |
| `ACCESS_NOTIFICATION_POLICY` | ✅ در مانیفست | سکوت قبل از اقامه |
| `VIBRATE` / `WAKE_LOCK` / `INTERNET` | ✅ (عادی — بدون اعلام) | |

### نتیجهٔ چک: مانیفست از نظر مجوزها **آماده است**. باقی‌مانده فقط اعلام‌ها در کنسول است (بخش ۴).

---

## ۳) فرم اعلام داده‌ها (Data safety form) — پاسخ‌های پیشنهادی

### داده‌های «جمع‌آوری می‌شود»

| نوع داده | پردازش | اشتراک | فروش | اختیاری؟ | حذف |
|---|---|---|---|---|---|
| **موقعیت مکانی** (تقریبی + دقیق) | فقط روی دستگاه (اوقات شرعی، قبله) | نه | نه | بله (مختصات دستی) | خاموش‌کردن موقعیت |
| **فایل صوتی کاربر** (فقط فایلی که خودش انتخاب می‌کند) | فقط روی دستگاه (اذان شخصی) | نه | نه | بله | حذف از تنظیمات |

### همهٔ موارد زیر = **«خیر»** (چون در کد وجود ندارند)
نام، ایمیل، مخاطبین، عکس‌ها، ویدئوها، پیام‌ها، تقویم، سلامتی، مالی، Device IDs، سابقهٔ فعالیت، دیاگنوستیک، تبلیغات، حساب کاربری، SDK تحلیل/کراش (بدون Firebase/Crashlytics/AdMob در pubspec).

### سایر بخش‌های فرم
- **تبلیغات:** خیر
- **حساب کاربری:** خیر
- **رمزنگاری انتقال:** داده‌ای ارسال نمی‌شود؛ دانلود اختیاری صوت قاری از HTTPS است
- **سیاست حریم خصوصی:** ⚠️ **باید URL عمومی داشته باشد** (بخش ۵)

---

## ۴) اعلام مجوزها در کنسول (متون آماده، انگلیسی)

- **موقعیت مکانی:** `Computing accurate prayer times and qibla direction based on the user's current location. Location is optional (manual coordinates supported) and processed entirely on-device.` + **ویدئوی کوتاه** از جریان درخواست موقعیت.
- **SCHEDULE_EXACT_ALARM:** `Scheduling the five daily adhan alarms and reminders at exact times so notifications arrive at the precise prayer moment. Users can revoke it in system settings.`
- **POST_NOTIFICATIONS:** `Displaying adhan alarms, prayer reminders, daily azkar and reading reminders.`
- **FOREGROUND_SERVICE_MEDIA_PLAYBACK:** `Playing adhan audio (bundled or user-selected personal file) as a short-lived foreground service with a stop button; stops automatically when playback ends.`
- **RECEIVE_BOOT_COMPLETED:** `Re-schedules daily prayer alarms and reminders after reboot.`
- **دسترسی به اپ (App access):** هیچ (بدون Accessibility/Device Admin).

---

## ۵) سیاست حریم خصوصی ⚠️ — تنها مانع واقعی انتشار

### وضعیت فعلی
- فایل `privacy_policy.md` در repo موجود است ✅
- در اپ، صفحهٔ «حریم خصوصی و دسترسی‌ها» فقط یک **دیالوگ داخلی** است
- **آدرس تماس:** فقط کانال تلگرام `t.me/TAWHEED_EWAZ1` — **ایمیل عمومی در اپ نیست**

### اقدامات لازم (به‌ترتیب)
1. **میزبانی `privacy_policy.md` در یک URL عمومی** — ساده‌ترین راه GitHub Pages:
   - یک ریپوی عمومی بسازید (مثلاً `tawheeed/privacy-policy`)
   - `privacy_policy.md` را آپلود کنید
   - در Settings → Pages، برنچ را انتخاب کنید
   - آدرس می‌شود: `https://<username>.github.io/privacy-policy/`
2. **یک ایمیل عمومی بسازید** (مثلاً `tawheeed.app@gmail.com`) و در `privacy_policy.md` و صفحهٔ «درباره» اپ قرار دهید — گوگل‌پلی به یک راه تماس معتبر نیاز دارد.
3. لینک نهایی را در کنسول (App content → Privacy policy) ثبت کنید.

> بدون URL عمومی معتبر، دکمهٔ «Submit for review» فعال نمی‌شود.

---

## ۶) موارد متفرقهٔ کنسول

- [ ] **دسته‌بندی:** Lifestyle → Religion & Spirituality
- [ ] **ردهٔ سنی (Target audience):** تکمیل پرسشنامه — این اپ محتوای حساس ندارد
- [ ] **Alarms & reminders:** اعلام برای `SCHEDULE_EXACT_ALARM`
- [ ] **Family Policy:** فقط اگر می‌خواهید زیر ۱۳ سال مخاطب داشته باشید (تعهدات بیشتر — پیشنهاد: فعلاً نه)
- [ ] **حساب توسعه‌دهنده:** هزینهٔ یک‌بارهٔ ۲۵$ پرداخت شده باشد
- [ ] **نام و توضیحات فروشگاه:** فارسی + انگلیسی (میتوانم متن آماده بنویسم)

---

## ۷) جمع‌بندی وضعیت

| بخش | وضعیت |
|---|---|
| بیلد + امضا + bundletool | ✅ **کامل** |
| مجوزهای مانیفست | ✅ **کامل** (دو مجوز اضافی حذف شده) |
| فرم اعلام داده‌ها | 🟡 فقط پاسخ‌ها در کنسول — این سند راهنماست |
| اعلام مجوزها + ویدئوها | 🟡 نیاز به کار در کنسول |
| **Privacy policy URL** | ❌ **نیاز به میزبانی + ایمیل تماس** |
| ۵۷۴ تست / analyze | ✅ ۰ خطا — قبل از بیلد نهایی پاس شد |

**قدم بعدی پیشنهادی:** میزبانی `privacy_policy.md` روی GitHub Pages (راهنمای گام‌به‌گام آماده است) و بعد ثبت لینک در کنسول — بقیهٔ مراحل کنسول فقط «تایپ پاسخ‌ها» است.
