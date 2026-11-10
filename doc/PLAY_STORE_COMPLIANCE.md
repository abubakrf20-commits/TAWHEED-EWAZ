# ✅ چکلیست نهایی انطباق گوگل‌پلی — برنامه «توحید» v1.5.0

> تاریخ: ۲۰ مرداد ۱۴۰۵ — این سند نتیجه بررسی واقعی کد (Dart + Kotlin + مانیفست) است، نه فرض.

---

## ۰) خلاصه مدیریتی

| مجوز | وضعیت در کد | اقدام لازم |
|---|---|---|
| `USE_FULL_SCREEN_INTENT` | ⚠️ اعلام‌شده ولی **هیچ‌جا استفاده نمی‌شود** | **حذف از مانیفست** (ریسک رد شدن) |
| `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | ✅ واقعاً استفاده می‌شود (سرویس پخش اذان) | **بماند** + اعلام صحیح در کنسول |
| `READ_MEDIA_AUDIO` | ⚠️ لازم نیست — انتخاب فایل با SAF انجام می‌شود | **حذف از مانیفست** |
| فرم اعلام داده‌ها (Data safety) | داده‌های کمی دارد | فقط موقعیت مکانی + فایل صوتی انتخابی کاربر (هر دو روی دستگاه) |
| تجزیه‌وتحلیل / تبلیغات / حساب | ندارد | بدون اعلام — خیال‌تان راحت |

**نتیجه:** با ۲ خط حذف از مانیفست + تکمیل ۲ بخش کنسول، برنامه در وضعیت انطباق کامل قرار می‌گیرد.

---

## ۱) `USE_FULL_SCREEN_INTENT` — باید حذف شود 🚩

### وضعیت فعلی
- در `AndroidManifest.xml` اعلام شده است.
- **جستجوی کامل کد (Dart و Kotlin): ۰ نتیجه** برای `fullScreenIntent` / `setFullScreenIntent` / `useFullScreenIntent`.
- اعلان اذان (`AzanForegroundService`) فقط `CATEGORY_ALARM` + `PRIORITY_HIGH` دارد — بدون full-screen intent.

### چرا خطرناک است
- از **اندروید ۱۴ (API 34)** به بعد، گوگل‌پلی مجوز `USE_FULL_SCREEN_INTENT` را **فقط** به اپ‌هایی می‌دهد که «کارکرد اصلی‌شان زنگ هشدار یا تقویم» است.
- اعلام یک مجوز محدودشده بدون استفاده واقعی، شایع‌ترین دلیل **رد شدن خودکار** در بررسی گوگل‌پلی است.

### اقدام
این خط را از `AndroidManifest.xml` حذف کنید:

```xml
<!-- حذف شود -->
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>
```

### نگران نباشید (تجربه کاربر حفظ می‌شود)
- اعلان اذان به‌خاطر `CATEGORY_ALARM` در اندروید ۱۴+ همچنان به‌صورت **Heads-up** با اولویت بالا بالای صفحه ظاهر می‌شود.
- اگر در آینده خواستید اذان واقعاً تمام‌صفحه شود، باید `fullScreenIntent` واقعی پیاده شود **و** برنامه زیرمجموعه «زنگ هشدار» در کنسول ثبت شود — کاری پرمخاطره برای یک اپ جامع عبادی، بهتر است اصلاً سراغش نروید.

---

## ۲) `FOREGROUND_SERVICE_MEDIA_PLAYBACK` — بماند ✅

### شواهد استفاده واقعی (تطابق کامل مانیفست و کد)
| بخش | وضعیت |
|---|---|
| `AzanForegroundService.kt` | روی API 34+ با `FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK` سرویس را foreground می‌کند |
| پخش صوت | `MediaPlayer` با `USAGE_ALARM` — اذان باندل یا فایل شخصی کاربر |
| مانیفست | `<service android:foregroundServiceType="mediaPlayback">` ✅ |
| مجوزها | `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK` ✅ |

### نکات کلیدی برای بررسی گوگل‌پلی (همگی رعایت شده)
1. **سرویس کوتاه‌عمر است:** `START_NOT_STICKY` و `stopSelf()` بلافاصله بعد از پایان اذان → مطابق سیاست «FGS فقط تا زمانی که کار واقعی دارد».
2. **اعلان مداوم با دکمه توقف** دارد → ماهیت media نه‌تیفیکیشن شفاف است.
3. **اجازه شروع از پس‌زمینه:** اذان از `AdhanReceiver` (رویداد exact alarm) شروع می‌شود که در لیست معافیت‌های اندروید ۱۵ است. `BootReceiver` فقط زمان‌ها را دوباره برنامه‌ریزی می‌کند و مستقیم سرویس را صدا نمی‌زند. ✅
4. شروع FGS با **تاخیر بیش از ۵ ثانیه** ممکن نیست — کد با `try/catch` و `ForegroundServiceStartNotAllowedException` محافظت شده است.

### نکته کوچک (اختیاری)
نوع سرویس `mediaPlayback` است ولی صوت با `USAGE_ALARM` پخش می‌شود. اگر بازبینی گوگل‌پلی سؤال کرد، توجیه: «پخش فایل صوتی (اذان) که ممکن است فایل شخصی کاربر باشد و نیاز به foreground + قفل بیداری دارد». این پاسخ پذیرفته‌شده‌ای است.

---

## ۳) `READ_MEDIA_AUDIO` — باید حذف شود 🚩

### وضعیت فعلی
- در مانیفست اعلام شده، اما **هیچ درخواست runtime از آن نمی‌شود** (کد Dart آن را درخواست نمی‌کند).
- تنها مصرف‌کنندهٔ فایل صوتی کاربر: `reminder_editor_screen.dart` با `FilePicker.platform.pickFiles(type: FileType.audio)`.
- **`file_picker` در اندروید از Storage Access Framework (SAF) استفاده می‌کند** — یعنی پنجره سیستم‌عامل باز می‌شود و دسترسی موقت به همان یک فایل انتخابی می‌دهد؛ **به هیچ مجوزی نیاز ندارد**.
- فایل انتخابی بلافاصله به حافظه داخلی اپ (`custom_sounds/`) کپی می‌شود.

### چرا حذفش کنیم
- اعلام مجوزِ بی‌استفاده = سؤال اضافه در فرم اعلام داده‌ها (فایل‌های صوتی) + ظاهر ترسناک در صفحه مجوزها.
- حذف آن **هیچ تأثیری روی عملکرد انتخاب فایل ندارد** (SAF بدون مجوز کار می‌کند).

### اقدام
```xml
<!-- حذف شود -->
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>
```

---

## ۴) فرم اعلام داده‌ها (Data safety form) — پاسخ‌های پیشنهادی

### ۴-۱. داده‌هایی که جمع‌آوری می‌شود
| نوع داده | جمع‌آوری؟ | پردازش | اشتراک با شخص ثالث | فروش | اختیاری؟ | حذف |
|---|---|---|---|---|---|---|
| موقعیت مکانی (تقریبی + دقیق) | ✅ بله | **فقط روی دستگاه** (محاسبه اوقات شرعی و قبله) | ❌ نه | ❌ نه | ✅ بله (مختصات دستی) | ✅ خاموش‌کردن موقعیت یا پاک‌کردن داده اپ |
| فایل‌های صوتی کاربر | ✅ بله (فقط فایلی که خودِ کاربر انتخاب می‌کند) | **فقط روی دستگاه** (پخش اذان شخصی) | ❌ نه | ❌ نه | ✅ بله | ✅ حذف فایل انتخابی از تنظیمات |

### ۴-۲. داده‌هایی که جمع‌آوری **نمی‌شود** (همه این‌ها = «خیر»)
نام، ایمیل، مخاطبین، عکس‌ها، ویدئوها، پیام‌ها، تقویم، اطلاعات سلامتی/تناسب‌اندام، اطلاعات مالی، شناسه‌های دستگاه (device IDs)، سابقه فعالیت، دیاگنوستیک‌ها، هر نوع داده دیگر. — اپ **به‌جز Firebase Cloud Firestore برای «ارسال پیشنهاد» هیچ SDK جمع‌آوری داده/تحلیل/تبلیغات (Analytics، Crashlytics، AdMob و…) ندارد**؛ پیشنهادها داوطلبانه و فقط متن دسته‌بندی‌شده + یک شناسهٔ تصادفی ناشناس دستگاه است (بدون نام، ایمیل یا مکان).

> ⚠️ **به روزرسانی فرم «امنیت داده» در Play Console:** با افزودن قابلیت «ارسال پیشنهاد»، این فرم باید بروز شود:
> - «پیام‌ها (سایر)» → برای Firebase Firestore، «جمع‌آوری و به اشتراک‌گذاری» = بله؛ خصوصاً متن کاربر به‌صورت خودکار ارسال نمی‌شود و کاربر داوطلبانه می‌فرستد (فقط با لمس دکمهٔ ارسال).
> - «شناسه دستگاه» → فقط یک شناسهٔ تصادفی ناشناس با قابلیت حذف (پاک‌کردن دادهٔ اپ).
> - رمزنگاری انتقال: HTTPS (Firestore).

### ۴-۳. سایر بخش‌های فرم
- **تبلیغات:** خیر
- **حساب کاربری:** خیر (بدون ورود/ثبت‌نام)
- **رمزنگاری انتقال:** در عمل داده‌ای ارسال نمی‌شود؛ اگر دانلود صوت قاری فعال باشد (متن قرآن و حدیث باندل است و دانلود نمی‌شود)، ارتباط از HTTPS است. استثنا: «ارسال پیشنهاد» با Firestore از HTTPS استفاده می‌کند.
- **سیاست حفظ حریم خصوصی:** فایل `privacy_policy.md` موجود است ولی باید در یک **URL عمومی** میزبانی شود (پیشنهاد: GitHub Pages یا سایت ساده) و لینکش در کنسول ثبت شود. ⚠️ بدون لینک عمومی، انتشار ممکن نیست.

---

## ۵) اعلام مجوزها در کنسول گوگل‌پلی (Permissions declarations)

کنسول برای هر مجوز حساس می‌پرسد «چرا لازم دارید؟» — متن‌های آماده (انگلیسی، چون فرم کنسول انگلیسی است):

### ۵-۱. موقعیت مکانی (نیازمند ویدئوی نمایش)
> **Core feature:** Computing accurate prayer times and qibla direction based on the user's current location. The user can also enter coordinates manually; location is optional and processed entirely on-device.

### ۵-۲. `SCHEDULE_EXACT_ALARM` — دسته «Alarms & reminders»
> **Core feature:** Scheduling the five daily adhan (call to prayer) alarms and custom reminders at exact times so notifications arrive at the precise prayer moment. Users can revoke this in system settings; the app falls back to inexact scheduling.

### ۵-۳. `POST_NOTIFICATIONS`
> Used to display adhan alarms, prayer reminders, daily azkar and reading reminders.

### ۵-۴. `RECEIVE_BOOT_COMPLETED`
> Re-schedules the daily prayer alarms and reminders after the device reboots so no adhan is missed.

### ۵-۵. `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK`
> Plays the adhan audio (bundled or user-selected personal file) as a short-lived foreground service with a persistent notification and a stop button; the service stops automatically when playback finishes.

### ۵-۶. بدون نیاز به اعلام (Normal permissions)
`INTERNET`، `VIBRATE`، `WAKE_LOCK`، `ACCESS_NOTIFICATION_POLICY` (حالت بی‌صدا قبل از اقامه).

### ۵-۷. «دسترسی به اپ» (App access)
هیچ موردی: بدون سرویس دسترس‌پذیری، بدون Device Admin.

---

## ۶) چک‌لیست نهایی قبل از آپلود AAB

### کد
- [ ] حذف `USE_FULL_SCREEN_INTENT` از مانیفست
- [ ] حذف `READ_MEDIA_AUDIO` از مانیفست
- [ ] (پس از حذف) اجرای `flutter analyze` + `flutter test` — انتظار ۰ خطا و پاس کامل ۵۳۰ تست

### کنسول گوگل‌پلی
- [ ] تکمیل فرم اعلام داده‌ها مطابق بخش ۴
- [ ] تکمیل اعلام مجوزها مطابق بخش ۵ (با ویدئوی کوتاه از جریان موقعیت و اعلان اذان)
- [ ] لینک عمومی سیاست حریم خصوصی (بخش ۴-۳)
- [ ] انتخاب دسته‌بندی «عقاید/مذهب» (Lifestyle → Religion & Spirituality) و علامت «سازگار با خانواده» (Family Policy) اگر مدنظر است — توجه: اعلام Family policy تعهدات بیشتری دارد
- [ ] پرکردن صفحه «محدوده سنی» (Target audience) — این اپ بدون محتوای حساس است
- [ ] اعلام «Alarms & reminders» برای `SCHEDULE_EXACT_ALARM`
- [ ] انتخاب `arm64-v8a` + `armeabi-v7a` (قبلاً در `build.gradle.kts` فعال است) — AAB آپلود شود نه APK

### نکات فنی هدف SDK
- `compileSdk = 36` است؛ `targetSdk` از `flutter.targetSdkVersion` می‌آید (نسخه‌های اخیر Flutter: 35/36). یعنی محدودیت‌های اندروید ۱۴ (full-screen intent) و ۱۵ (شروع FGS از پس‌زمینه) **در حال اعمال‌اند** — تغییرات پیشنهادی این سند دقیقاً برای همین نوشته شده.

---

## ۷) آنچه دست نمی‌خورد (اطمینان)
- محاسبات اوقات شرعی، تقویم، اذان/اقامه، سکوت و همه داده‌های شرعی **بدون تغییر** — هیچ موردی از این چک‌لیست به دقت محاسبات ضربه نمی‌زند.
- قرآن و حدیث **باندل** می‌مانند (تنها دانلود اختیاری، صوت قاری است که خود کاربر درخواست می‌کند).
