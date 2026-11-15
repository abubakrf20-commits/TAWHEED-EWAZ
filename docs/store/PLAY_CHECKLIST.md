# چک‌لیست انتشار در Google Play — توحید (tawheeed)

این فایل تنها مرجعی است که برای فرستادن نسخه به Play لازم دارید: هر فایلی که
باید آپلود شود، هر فیلدی که باید پر شود، و مقدار دقیقش.

- بستهٔ برنامه: `com.islamic.tawheeed`
- نام نمایشی: **توحید** (Tawheed)
- نسخهٔ فعلی: `versionName 1.9.0` · `versionCode 2000015041` · pubspec `1.9.0+10021`
- اثر انگشت گواهی امضا (SHA-256):
  `D9:9C:B5:52:C4:24:57:4A:AC:7F:76:59:8D:D9:71:81:9A:07:2D:D9:8B:12:B2:0F:FA:0C:3E:13:58:D7:8F:1B`
  (alias `upload`، معتبر تا ۲۰۵۳)

## ۱. چه فایلی آپلود می‌شود؟

| خروجی | دستور | جای آپلود |
| --- | --- | --- |
| **AAB** (الزامی برای Play) | `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab` | Production → Create new release → App bundle |
| APK (توزیع مستقیم/آپدیت درون‌برنامه‌ای) | `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk` | روی هاست، و `app_version.json` |
| آیکون فروشگاه | `assets/icon-512.png` (۵۱۲×۵۱۲ PNG) | Store listing → App icon |
| گرافیک شاخص | `assets/feature-graphic-1024x500.png` | Store listing → Feature graphic |
| تصاویر گوشی | `assets/screenshots/01-home.png` … `06-audio-library.png` (۱۲۲۰×۲۴۴۰) | Store listing → Phone screenshots (حداقل ۲) |

بیلد فقط با کلید `android/app/release-key.jks` (alias `upload`). اگر کلید عوض
شود، Play به‌روزرسانی را رد می‌کند؛ مسیر بیلد و نگه‌داری کلید در `SECRETS.md`.

## ۲. فیلدهای Store listing

| فیلد | مقدار | از کجا |
| --- | --- | --- |
| App name | `توحید — قرآن، اذکار و عبادت روزانه` | `listing-fa.md` |
| Short description | همان فایل، بخش «توضیح کوتاه» (≤۸۰ کاراکتر) | `listing-fa.md` |
| Full description | بخش «توضیح بلند» | `listing-fa.md` |
| App category | Lifestyle (یا Books & Reference) | — |
| Contact email | همان که در کنسول ثبت است | — |
| Privacy policy | `https://abubakrf20-commits.github.io/TAWHEED-EWAZ/privacy.html` | زنده ✅ |
| Terms | `https://abubakrf20-commits.github.io/TAWHEED-EWAZ/terms.html` | زنده ✅ |
| Account deletion URL | `https://abubakrf20-commits.github.io/TAWHEED-EWAZ/store/account-deletion.html` | زنده ✅ |

## ۳. ایمنی داده (Data safety)

فرم را دقیقاً از `data-safety-answers.md` پر کنید. خلاصه:

- داده‌های شخصی جمع‌آوری نمی‌شود؛ حساب کاربری **محلی** است (بدون سرور توحید).
- فقط «برنامه‌ریزی اعلان‌ها» و «مکان تقریبی برای اوقات شرعی» استفاده می‌شود.
- هیچ داده‌ای فروخته یا با تبلیغات شریک نمی‌شود.
- امکان حذف حساب درون برنامه + صفحهٔ وب بالا.

## ۴. ترتیب کار در کنسول

1. **Create app** → نام، زبان پیش‌فرض فارسی، App/Game = App، Free.
2. **Store listing** → همهٔ فیلدهای بخش ۲ + آیکون/گرافیک/تصاویر.
3. **App content**:
   - Privacy policy → آدرس بالا.
   - Account deletion → آدرس بالا (و همین آدرس در `data-safety-answers.md`).
   - Data safety → طبق فایل.
   - Content rating → پرسش‌نامه؛ پاسخ‌ها: بدون خشونت/محتوای جنسی/مواد،
     «اشتراک‌گذاری مکان» فقط برای اوقات شرعی.
   - Target audience → ۱۳+ (یا بزرگسال)؛ برنامه محتوای کودک‌محور نیست.
   - Ads → **No ads**.
   - App access → همهٔ امکانات بدون ورود قابل استفاده‌اند (اگر ورود گذاشتید،
     حساب آزمایشی بدهید).
   - Government apps / Financial features / Health → خیر.
4. **Testing → Internal testing** → آپلود AAB → افزودن ایمیل خودتان →
   نصب از لینک تست روی گوشی واقعی.
5. **Production → Create release** → همان AAB → Release notes از
   `listing-fa.md` بخش «تازه‌ها» → Rollout.

## ۵. پیش از هر انتشار، این‌ها را ببینید

- [ ] `python tools/quality_check.py --strict` سبز است.
- [ ] `flutter analyze --no-pub lib` صفر error/warning دارد.
- [ ] تست‌های بخش‌های تغییرکرده سبزند.
- [ ] `flutter build appbundle --release` موفق است.
- [ ] شمارهٔ نسخه **بالاتر** از نسخهٔ منتشرشده است (`versionCode` یکتا).
- [ ] `app_version.json` روی هاست با APK تازه هم‌گام است.
- [ ] صفحهٔ حذف حساب و سیاست حریم خصوصی باز می‌شوند (۲۰۰).
- [ ] تصاویر فروشگاه با ظاهر نسخهٔ تازه هم‌خوان‌اند.

## ۶. فهرست کامل فایل‌های این پوشه

| فایل | کاربرد |
| --- | --- |
| `README.md` | نقشهٔ پوشه، مشخصات بسته، آدرس‌های آماده، گام‌های انتشار |
| `PLAY_CHECKLIST.md` | همین فایل — چک‌لیست کامل کنسول |
| `listing-fa.md` | متن‌های آمادهٔ صفحهٔ فروشگاه (نام، کوتاه، بلند، تازه‌ها، کلیدواژه) |
| `data-safety-answers.md` | پاسخ‌های فرم ایمنی داده |
| `account-deletion.html` | صفحهٔ حذف حساب (فرم Play این را می‌خواهد) |
| `SECRETS.md` | فهرست چیزهایی که باید امن بمانند (بدون مقدار) |
| `assets/icon-512.png` | آیکون فروشگاه ۵۱۲×۵۱۲ |
| `assets/feature-graphic-1024x500.png` | گرافیک شاخص |
| `assets/screenshots/*.png` | شش تصویر ۱۲۲۰×۲۴۴۰ |

## ۷. به‌روزرسانی‌های آینده

1. بامپ نسخه در `pubspec.yaml` و `SHIPPED_VERSION_CODE` (فقط با اجازهٔ مالک).
2. `flutter build appbundle --release` و `flutter build apk --release`.
3. AAB → Play (Internal → Production)؛ APK → هاست + `app_version.json`.
4. بخش «تازه‌ها» در `listing-fa.md` را با نسخهٔ تازه بنویسید.
5. اگر صفحهٔ تازه‌ای اضافه شد، تصاویر ۱۲۲۰×۲۴۴۰ را جایگزین کنید.
