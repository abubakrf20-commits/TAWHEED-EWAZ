# بستهٔ فروشگاه توحید — فهرست کامل

این پوشه همهٔ چیزهایی را دارد که برای انتشار و نگه‌داری توحید در Google Play و
برای استفادهٔ روزانه از هاست شخصی لازم است. مسیر رسمی و عمومی این پوشه:

```
https://abubakrf20-commits.github.io/TAWHEED-EWAZ/store/README.md
```

(فایل‌های متنی را می‌شود مستقیم از `raw.githubusercontent.com` هم خواند؛ رجوع به
«آدرس‌های آماده» پایین‌تر.)

| مسیر در همین پوشه | چیست |
| --- | --- |
| `account-deletion.html` | صفحهٔ «حذف حساب کاربری» برای فرم Play؛ همین آدرس در کنسول و در `data-safety-answers.md` ثبت شده است |
| `listing-fa.md` | متن‌های آمادهٔ صفحهٔ فروشگاه: نام، توضیح کوتاه/بلند، «تازه‌ها»، کلیدواژه‌ها |
| `data-safety-answers.md` | پاسخ‌های فرم «ایمنی داده» با آدرس عمومی صفحهٔ حذف حساب |
| `assets/icon-512.png` | آیکون ۵۱۲×۵۱۲ (۳۲ بیت با شفافیت) — فیلد «App icon» |
| `assets/feature-graphic-1024x500.png` | گرافیک شاخص ۱۰۲۴×۵۰۰ — فیلد «Feature graphic» |
| `assets/screenshots/` | شش تصویر ۱۲۲۰×۲۴۴۰ (نسبت ۲:۱) از دستگاه واقعی — فیلد «Phone screenshots» |
| `SECRETS.md` | فهرست چیزهایی که باید در جای امن نگه داشته شوند (بدون مقدار کلیدها) |

## مشخصات بسته

| مورد | مقدار |
| --- | --- |
| نام برنامه (نام پکیج در Play) | توحید |
| package | `com.islamic.tawheeed` |
| versionName | `1.9.0` |
| versionCode | `2000015041` (`SHIPPED_VERSION_CODE` در `android/app/build.gradle.kts`) |
| کوچک‌ترین اندروید | طبق `android/app/build.gradle.kts` (`minSdk`) |
| امضا | کلید `release-key.jks` (فقط روی رایانهٔ خودتان) |
| دستهٔ Play | سبک زندگی (Lifestyle) |
| سن هدف | ۱۳+ (باغ کودکان قابلیت خانوادگی است) |
| تبلیغات / خرید درون‌برنامه‌ای | ندارد |

## آدرس‌های آماده

| کاربرد | آدرس |
| --- | --- |
| صفحهٔ حذف حساب (فرم Play) | `https://abubakrf20-commits.github.io/TAWHEED-EWAZ/store/account-deletion.html` |
| سیاست حریم خصوصی | `https://abubakrf20-commits.github.io/TAWHEED-EWAZ/privacy.html` |
| شرایط استفاده | `https://abubakrf20-commits.github.io/TAWHEED-EWAZ/terms.html` |
| صفحهٔ اسناد حقوقی | `https://abubakrf20-commits.github.io/TAWHEED-EWAZ/` |
| آیکون | `https://abubakrf20-commits.github.io/TAWHEED-EWAZ/store/assets/icon-512.png` |
| گرافیک شاخص | `https://abubakrf20-commits.github.io/TAWHEED-EWAZ/store/assets/feature-graphic-1024x500.png` |
| تصویر ۱ … ۶ | `…/store/assets/screenshots/01-home.png` … `06-audio-library.png` |
| به‌روزرسانی درون‌برنامه‌ای | `https://raw.githubusercontent.com/abubakrf20-commits/TAWHEED-EWAZ/main/app_version.json` |

## انتشار یک نسخهٔ تازه — گام‌به‌گام

1. `pubspec.yaml` و `SHIPPED_VERSION_CODE` را (با اجازهٔ صریح مالک) بامپ کنید.
2. `env -u http_proxy … flutter build apk --release` (و در صورت نیاز
   `flutter build appbundle --release` برای Play). کلید امضا باید همان
   `android/app/release-key.jks` باشد؛ اگر عوض شود، Play به‌روزرسانی را رد می‌کند.
3. فایل `app_version.json` در ریشهٔ همین هاست را به‌روز کنید: `version`،
   `buildNumber` و `apkUrl`.
4. تصاویر و متن‌های تازهٔ همین پوشه را جایگزین کنید (شمارهٔ نسخه را در
   `listing-fa.md` بخش «تازه‌ها» بنویسید).

## نکتهٔ امنیتی

این هاست **عمومی** است. هیچ‌گاه `release-key.jks`، `key.properties`،
`google-services.json`، `quran_api.env` یا رمز کلید را در آن نگذارید. فقط
فهرست آن‌ها در `SECRETS.md` آمده است، نه خودشان.
