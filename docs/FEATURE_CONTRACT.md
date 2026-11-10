# قرارداد معماری فیچرها (Feature Contract)

این سند قواعد الزامی توسعه در این مخزن را مشخص می‌کند. رعایت قواعد بخش «بررسی خودکار»
در CI با اسکریپت `tool/check_import_lints.dart` اجباری است.

## ۱. قواعد لایه‌ها (Layer Rules)

هر فیچر سه لایه دارد:

```
lib/features/<feature>/
├── domain/          # قواعد و موجودیت‌های محض — بدون Flutter، بدون دیتابیس
├── data/            # پیاده‌سازی واقعی: DAO، مدل، سرویس، repository-impl
└── presentation/    # UI، Provider، صفحه/اسکرین/ویجت
```

| قانون | توضیح |
|---|---|
| `domain/` نباید `package:flutter` را import کند | حتی `show IconData` هم ممنوع است (بدهی شناخته‌شده: `worship/domain/entities/worship_item.dart` — در allowlist اسکریپت؛ اصلاح شود) |
| `domain/` نباید `features/*/data` یا `features/*/presentation` را import کند | وابستگی domain ⇠ data ممنوع است |
| `domain/` نباید `app_database.dart`، Drift، یا هر runtime فریم‌ورکی را بشناسد | فقط entity و interface (abstract repository) |
| `presentation/` نباید data-impl را مستقیم بگیرد | هدف: presentation فقط از راه domain-interfaces و Providerها به داده دسترسی پیدا کند. استثنائات فعلی (بدهی): چند Provider در books/worship هنوز DAO را مستقیم `ref.read` می‌کنند — هنگام لمس همان فایل، به repository منتقل شود |
| dependency جهت‌دار است | `presentation → domain ← data`؛ `data` پیاده‌سازی interfaceهای domain را می‌سازد |

## ۲. ممنوعیت چرخه بین فیچرها (No feature→feature cycles)

- فیچرها فقط می‌توانند از `lib/core/**`، `lib/shared/**` و `package:` ها import کنند.
- import بین دو فیچر (A → B) مجاز نیست **اگر جفت {A, B} در فهرست `_badPairs` اسکریپت lint باشد — در هر دو جهت.**
- ارجاع تک‌جهتهٔ موجود (مثلاً `home → prayer`) برای فیچرهای محتوایی/نمایشی موقتاً پذیرفته شده، اما:
  - هرگز جهت معکوس اضافه نکنید (چرخه ممنوع);
  - وابستگی جدید بین فیچرها نیازمند به‌روزرسانی همین سند و فهرست `_badPairs` است;
  - ترجیح: نمایش مشترک را به `lib/shared/widgets/` یا `lib/core/` ببرید (نمونه: `SectionHeader`، `GradientButton`، `IconChip`).

## ۳. مدیریت State با Riverpod

- تمام state جدید با **Riverpod** (`@riverpod` یا `FutureProvider`/`Notifier`) پیاده می‌شود.
- اضافه کردن `ChangeNotifier`/`InheritedWidget` برای state جدید ممنوع است.
- Providerهای عمومی در `presentation/providers/` فیچر تعریف می‌شوند — **نه داخل فایل اسکرین** (نمونه اصلاح‌شده: `allBookmarkedIdsProvider` از `ketabkhaneh_screen.dart` به `books/presentation/providers/bookmark_ids_provider.dart` منتقل شد).
- Providerهای دیتابیس (DAO) در سطح data و از طریق `app_database` تعریف و override می‌شوند.

## ۴. الزامات تست هر فیچر

حداقل برای هر فیچر جدید:

1. **unit test دامنه**: entity/service خالص — بدون Flutter binding (پوشش: `test/features/<feature>/domain/**`);
2. **test Provider** (در صورت وجود منطق state) — با override کردن DAOها (الگو: `test/features/books/...`);
3. **smoke test اسکرین**: پرینت شدن اسکرین و یافتن متن کلیدی (الگو: `test/features/*/presentation/...`).

فیچرهای فعلیِ فاقد پوشش یا با پوشش نازک در [`COVERAGE_GAPS.md`](COVERAGE_GAPS.md) فهرست شده‌اند.
تست جدید بنویسید قبل از اینکه پوشش همان فیچر را کاهش دهید.

## ۵. حجم فایل

- هدف: هیچ فایل Dart از **۱۰۰۰ خط** بیشتر نشود (هشدار عملی: ~۷۰۰ خط).
- فایلِ عبوری از ۷۰۰ خط را هنگام لمس، به ویجت/سرویس کوچک‌تر تقسیم کنید.
- کلاس‌های widget بزرگ را به چند فایل در همان پوشه بشکنید (الگو: `*_widgets.dart` بخشی).

## ۶. افزودن فیچر جدید — ساختار پیشنهادی

```
lib/features/<feature>/
├── <feature>.dart                     # barrel (اختیاری): export لایه domain و Providerها
├── domain/
│   ├── entities/<entity>.dart         # موجودیت خالص، بدون Flutter
│   └── repositories/<repo>.dart       # interface انتزاعی
├── data/
│   ├── models/<model>.dart            # مدل Drift/JSON در صورت نیاز
│   ├── daos/<dao>.dart                # دسترسی دیتابیس + provider آن
│   └── repositories/<repo>_impl.dart  # پیاده‌سازی interface دامنه
└── presentation/
    ├── providers/<name>_provider.dart # Riverpod — بیرون از اسکرین
    ├── screens/<name>_screen.dart     # صفحه‌ها (پوشه screens، نه pages)
    └── widgets/<name>_widget.dart     # widgetهای محلی فیچر
```

نکته: پوشهٔ صفحات در این مخزن `presentation/screens/` است.
**استثنای به تعویق افتاده (A2-18):** `settings/presentation/pages/` هنوز به `screens/`
تغییر نام نیافته چون `settings_screen.dart` هم‌زمان توسط کار موازی ویرایش می‌شود
(بازنامگذاری با تداخل merge ریسک دارد). با آرام‌شدن کار موازی، مهاجرت دستی:
فایل را منتقل و importهای `pages/settings_screen.dart` (۴ مورد: `app_router.dart`
و سه تست) را به‌روزرسانی کنید.

## ۷. بررسی خودکار importها (CI lint)

```bash
dart run tool/check_import_lints.dart
```

- خروجی غیرصفر (exit code 1) یعنی نقض قانون وجود دارد — در CI باید fail شود.
- قوانین: (۱) import شدن Flutter از domain، (۲) import شدن `data/` یا `presentation/`
  از domain، (۳) جفت‌های ممنوع بین فیچرها در **هر دو جهت**.
- فرار موقت: افزودن کامنت `// import-lint-allow: <دلیل>` روی همان خط import —
  فقط برای بدهی‌های ثبت‌شده در همین سند.

## ۸. Lintهای `analysis_options.yaml`

هم‌اکنون مجموعه‌ای از lintهای سخت‌گیرانه فعال است (رجوع به `analysis_options.yaml`).
lint جدید فقط در صورتی فعال می‌شود که `dart analyze` را بدون خطای جدید بگذراند.

**اولویت بعدی (پیشنهادی — قبل از فعال‌سازی روی شاخهٔ جدا امتحان کنید):**

| Lint | چرا | ریسک |
|---|---|---|
| `no_leading_underscores_for_local_identifiers` | جلوگیری از `_` اضافه در متغیرهای محلی | کم |
| `prefer_asserts_with_message` | پیام assertهای توضیحی | کم |
| `avoid_returning_null_for_void` | جلوگیری از null برگشتی بی‌معنا | کم |
| `unawaited_futures` | به‌موقع بستن futureها در async | متوسط — ممکن است خطا بسازد |
| `discarded_futures` | جلوگیری از future رهاشده | متوسط |
| `use_colored_box` / `use_decorated_box` | جایگزینی Containerهای بی‌دلیل | زیاد — نیاز به batch fix |
| `prefer_relative_imports` | نتیجه عکس دارد؛ در این مخزن package import استاندارد است — فعال نشود | — |

لیست بالا را به‌صورت مرحله‌ای و با مقایسهٔ شمارش `dart analyze` قبل/بعد فعال کنید.

## ۹. بدهی‌های شناخته‌شده

- `worship_item.dart` (domain) → `package:flutter` (IconCodePoint) — در allowlist اسکریپت.
- `tasks_common.dart` هنوز `IconChip`/`GradientButton` محلی دارد — `lib/features/tasks/**`
  ممنوع از ویرایش در این فاز بود؛ نسخهٔ shared در `lib/shared/widgets/` آمادهٔ مهاجرت است.
- `settings/presentation/pages/` → `screens/` (بند ۶).
