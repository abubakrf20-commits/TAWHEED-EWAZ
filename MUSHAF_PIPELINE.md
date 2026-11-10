# پایپ‌لاین مصحف — رندر زندهٔ QCF4 (تنها مسیر)

> **به‌روزرسانی:** مسیر قدیمی WebP (SVG-BR ← بیت‌مپ + SQLite/`ayah_boxes.json`) به‌طور کامل
> حذف شد. مصحف اکنون فقط به‌صورت **فونت زندهٔ QCF4** رندر می‌شود؛ هیچ تصویر پیش‌رندرشده‌ای
> دانلود/کش نمی‌شود و `mushaf.db` / `ayah_boxes.json` دیگر لازم نیستند.

## چرا QCF4؟

QCF4 (Quran Complex Font v4، مصحف مدینه ۱۴۴۱هـ، خط عثمان طه) فونت زندهٔ رسمی مصحف است:

* هر صفحه یک فایل JSON (`pages/NNN.json`) دارد که خطوط/واژه‌ها با glyph های PUA و فونتِ
  متعلق بهشان را توصیف می‌کند (منبع: `MohamadHajjRabee/quran-qcf4`).
* **۴۷ فایل فونت Hafs** + فونت `QCF4_QBSML` (سر سوره‌ها/بسمله) هنگام نیاز از CDN دانلود و در
  کش نگه داشته می‌شوند.
* فاصلهٔ بین واژه‌ها در عرضِ advance خودِ هر glyph ذخیره است → ردیف‌ها بدون padding افقی
  دقیقاً مثل چاپ ردیف می‌شوند.

## جریان داده

```
quran-qcf4 (raw.githubusercontent.com + cdn.jsdelivr.net)
        │
        ├── pages/NNN.json   → کپسی در Documents/quran_content/qcf4/pages/ (Qcf4DataStore)
        ├── fonts/*.ttf      → کپسی در Documents/quran_content/qcf4/fonts/ (Qcf4FontLoader)
        └── font-map.json    → (اختیاری؛ ایدهٔ صفحه → فونت)
```

* صفحه‌یاب/هایلایت/تپ کاملاً روی دادهٔ زندهٔ QCF4 است؛ نیاز به `ayah_boxes` یا `mushaf.db` نیست.

## سر سوره‌ها

* سر سوره (= `surah_header`) با فونت باندل‌شدهٔ **SurahNameV4** رندر می‌شود: سورهٔ N به
  glyph ی PUA با کد `0xE000 + N` نگاشت می‌شود (مستقیم از cmap، بدون نیاز به shaping).
  پس هدر در حالت آفلاین هم هست (فونت داخل اپ است).
* بسمله و بقیهٔ سربرگ‌ها با فونت QCF4 اصلی (`QCF4_QBSML`) طبق دادهٔ dataset رندر می‌شوند.

## سمت Flutter (موجود)

| فایل | نقش |
|---|---|
| `lib/features/quran/mushaf/qcf4/qcf4_models.dart` | مدل‌های `pages/*.json` (واژه/خط/سوره) |
| `lib/features/quran/mushaf/qcf4/qcf4_data_store.dart` | خواندن/کش صفحه (دیسک سپس CDN) |
| `lib/features/quran/mushaf/qcf4/qcf4_font_loader.dart` | دانلود/ثبت فونت‌های QCF4 (دیسک سپس CDN) |
| `lib/features/quran/mushaf/qcf4/qcf4_download_manager.dart` | پیش‌دانلود کل مصحف (۶۰۴ صفحه + فونت‌ها) |
| `lib/features/quran/mushaf/qcf4/qcf4_page_viewer.dart` | رندر یک صفحه (FittedBox contain + ردیف RTL) |
| `lib/features/quran/mushaf/qcf4/qcf4_config.dart` | سرورها + نگاشت فونت (+ `surahNameGlyph`) |
| `lib/features/quran/mushaf/quran_mushaf_view.dart` | نمایش صفحه + هایلایت واژه/آیه + تپ |

## وضعیت مراحل

| مرحله | وضعیت |
|---|---|
| WebP/SVG-BR قدیمی | ❌ حذف شد (اکنون فقط QCF4) |
| رندر زندهٔ QCF4 | ✅ فعال |
| سر سوره با SurahNameV4 | ✅ فعال (باندل‌شده، آفلاین) |
| شماره آیه (circled) | ✅ قهوه‌ای |
