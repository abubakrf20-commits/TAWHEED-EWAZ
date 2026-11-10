# راهنمای انتشار نسخه جدید

تا زمانی که برنامه در گوگل‌پلی منتشر نشده، بروزرسانی مستقیم از طریق صفحهٔ
«درباره توحید» (دکمهٔ بروزرسانی) انجام می‌شود. مانیفست نسخه و فایل APK روی همان
ریپازیتوری محتوای فعلی میزبانی می‌شوند:

```
TAWHEED-EWAZ/app/update.json        ← اطلاعات نسخه
TAWHEED-EWAZ/releases/<apk>         ← فایل نصب مستقیم
```

URL که برنامه چک می‌کند (via `UpdateChecker`):
```
https://raw.githubusercontent.com/abubakrf20-commits/TAWHEED-EWAZ/main/app/update.json
```

## ساختار app/update.json
```json
{
  "revision": 2000012020,
  "versionCode": 2000012020,
  "versionName": "1.8.0",
  "notes": "فهرست تغییرات…",
  "apkUrl": "https://raw.githubusercontent.com/abubakrf20-commits/TAWHEED-EWAZ/main/releases/tawheed-1.8.0.apk",
  "apkSha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "playUrl": "https://play.google.com/store/apps/details?id=com.islamic.tawheeed",
  "mandatory": false
}
```

### `apkSha256` اجباری است

برنامه قبل از باز کردن نصب‌کننده، SHA-256 فایل دانلودشده را با این مقدار
می‌سنجد و در صورت عدم تطابق فایل را حذف می‌کند. **مانیفستی که `apkSha256`
نداشته باشد یا مقدارش ۶۴ کاراکتر hex نباشد، اصلاً به‌عنوان بروزرسانی پیشنهاد
نمی‌شود** (چک موفق برمی‌گردد ولی چیزی نمایش داده نمی‌شود).

```powershell
(Get-FileHash .\tawheeed-1.7.0.apk -Algorithm SHA256).Hash.ToLower()
```

`apkUrl` هم فقط روی میزبان‌های مجاز (`raw.githubusercontent.com`،
`github.com`، `objects.githubusercontent.com`، `dl.google.com`) و فقط با
`https` پذیرفته می‌شود؛ لینک ناشناس حذف و در صورت نبودِ لینک معتبر، کل بروزرسانی
نادیده گرفته می‌شود. `playUrl` هم فقط `play.google.com` است.

## نسخه‌بندی شمارندهٔ منجمد (خلاصه)

- **همهٔ کانال‌ها:** `versionCode` یک عددِ **منجمد** در
  `android/app/build.gradle.kts` (`FROZEN_VERSION_CODE`) است. در طول توسعه ثابت
  می‌ماند و فقط **پیش از هر نشر** ۱ تا ۱۰ واحد بالا می‌رود — پس هر بیلد درجا روی
  نسخهٔ قبلی نصب می‌شود و کاربر هیچ‌وقت مجبور به حذف نیست. «جدید بودن» را همان عدد
  (فیلد `revision`/`versionCode` و `--dart-define=APP_REVISION`) تعیین می‌کند.

چرا یک عددِ بزرگِ منجمد (و نه مثلاً ۴۰۰۹)؟ عدد باید بالایِ هر کدی باشد که ممکن است
روی گوشی‌ها بنشیند؛ در گذشته نسخهٔ منتشرشدهٔ ۱.۷.۱ کد `2000010013`، بیلد مستقیمِ
۱.۷.۰ کد `2000004000`، و بیلدهای خارج از repo کدهای ۶۰۰۹/۸۰۱۰ داشتند. عددِ
کوچک‌تر، نصبِ عددِ بزرگ‌تر روی گوشی‌ها را downgrade می‌کند. عددِ بزرگ برای کاربر
نامرئی است.

شرط مهم دوم: **امضای بیلد همیشه یکسان بماند** (همان `release-key.jks`).
اپدیتِ درجا با امضاهای متفاوت رد می‌شود. دیتای مصحف/دانلودها در اپدیتِ درجا حفظ
می‌شود و فقط با uninstall پاک می‌شود → هیچ‌وقت کاربر را مجبور به uninstall نکنید.

## مراحل انتشار نسخه مستقیم

1. **عددِ منجمد را ۱ تا ۱۰ واحد بالا ببرید** — `FROZEN_VERSION_CODE` در
   `android/app/build.gradle.kts` (و انتظارِ متناظر در
   `test/android/version_code_scheme_test.dart`). پیش از این، گارد را اجرا کنید:
   ```
   python tools/check_release_version.py --fail
   ```
2. ریلیز بیلد مستقیم (کد از گریدل می‌آید؛ **universal** نه split، چون split افست
   +1000/+2000 می‌گیرد):
   ```
   flutter build apk --release --dart-define=APP_REVISION=<FROZEN_VERSION_CODE>
   ```
   یا ساده‌تر `.\tools\prepare_update.ps1 -Repo <path>` که بیلد + مانیفست را با هم
   انجام می‌دهد.
3. فایل را کپی کنید:
   ```
   Copy-Item build\app\outputs\flutter-apk\app-release.apk TAWHEED-EWAZ\releases\tawheeed-<x.y.z>.apk -Force
   ```
4. `TAWHEED-EWAZ/app/update.json` را ویرایش کنید: `revision`، `versionName`,
   `notes`، `apkUrl` و **`apkSha256`**.
   (`versionCode` را همان `FROZEN_VERSION_CODE` بگذارید تا اپ‌های قدیمی که فقط
   versionCode می‌فهمند هم ماشه را بزنند.)
   هش فایلِ *همان* APK که در مرحلهٔ ۳ کپی شد:
   ```
   (Get-FileHash .\tawheeed-1.8.0.apk -Algorithm SHA256).Hash.ToLower()
   ```
   فرستادن `apkUrl` بدون هش یعنی کاربر هیچ بروزرسانی‌ای نمی‌بیند.
5. کامیت و پوش کاتالوگ محتوا.

### مراحل انتشار در گوگل‌پلی

1. `python tools/check_release_version.py --fail` (عددِ منجمد باید از هر کدِ
   نصب‌شده بالاتر باشد).
2. `flutter build appbundle --release --dart-define=APP_CHANNEL=play` — همان
   عددِ منجمد در AAB می‌نشیند. (تعریفِ `APP_CHANNEL=play` ضروری است تا کاربران
   پلی به صفحهٔ فروشگاه هدایت شوند و نه به لینک APK.)
3. آپلود AAB در Play Console (استریم‌های مستقیم و پلی جدا محسوب می‌شوند).

## نکات

- `REQUEST_INSTALL_PACKAGES` در AndroidManifest اضافه شده است.
- نصب از طریق `open_filex` انجام می‌شود؛ کاربر باید «نصب از منابع ناشناس» را
  یک‌بار تایید کند.
- اگر `revision` یا `versionCode` سرور بزرگ‌تر از نسخهٔ نصب‌شده باشد، بروزرسانی
  پیشنهاد می‌شود.
- دانلود APK سقف ۲۵۶ مگابایت دارد و روی دیسک نوشته می‌شود؛ فایل کوچک‌تر از آن
  نیست مگر اینکه بیلد در آینده بزرگ‌تر شود.
- بیلد مستقیم (کد ≥ `2000000000`) `playUrl` را نادیده می‌گیرد و کاربر را به
  `apkUrl` می‌برد؛ بیلد پلی به گوگل‌پلی هدایت می‌کند.
- هرگز کلید امضای release را عوض نکنید (کاربران مجبور به uninstall می‌شوند).