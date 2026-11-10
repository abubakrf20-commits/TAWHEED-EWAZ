# فهرست مستندهای `docs/`

پوشهٔ `docs` هم سند زنده دارد و هم گزارش تاریخ‌دار. قاعده یک خط است:
**هر سندی که یک شاخه/کامیت، یک «انجام شد» یا یک عددِ وضعیت را ثبت می‌کند، عکس تاریخ‌دار است، نه وضعیت امروز.**

همهٔ سندهای عکس‌دار در سربرگ خودشان این نشان را دارند:
`عکس تاریخ‌دار — Historical snapshot`. اگر سندی این نشان را نداشت، یعنی در فهرست
«زندهٔ» پایین است. عددها و «انجام شد»های سندهای عکس‌دار را نقل نکنید.

## مرجع وضعیت فعلی (live)

| سند | چه چیزی را زنده نگه می‌دارد |
| --- | --- |
| `AGENTS.md` (ریشهٔ مخزن) | قواعد کار، نام پروژه (`tawheeed`)، شاخهٔ واحد، وضعیت درخت |
| `SECTIONS_1_9_0.md` | تفکیک بخش‌های «بیشتر» (۵۳ = ۱۸/۱۲/۳/۱۵/۵) و وضعیت هر بخش |
| `FEATURE_CONTRACT.md` | قرارداد معماری فیچرها و بررسی خودکار |
| `CARE_ENGINE.md` · `SHOP_DOMAIN.md` · `WIDGET_DATA.md` | قرارداد موتور مراقبت، دامنهٔ «حساب مغازه» و کانال دادهٔ ویجت |
| `WIDGETS_PLAN.md` | مرجع پایدار ویجت‌ها (خودش را مرجع معرفی می‌کند) |
| `QURAN_TEACHER_ROADMAP.md` · `QURAN_READER_ROADMAP.md` · `ROADMAP.md` | کارهای آینده، نه کارنامهٔ گذشته |
| `APP_UPDATE_GUIDE.md` · `PUSH_GUIDE.md` · `ERROR_TRACKING.md` · `AUDIO_LIBRARY_HOSTING.md` · `COLD_START_TTI.md` · `versioning.md` | راهنمای کار جاری (انتشار، پوش، خطا، صدا، TTI، نسخه‌بندی) |
| `SECURITY_PRIVACY.md` | اینکه داده امروز کجا و چگونه نگه داشته می‌شود |

## عکس‌های تاریخ‌دار (historical snapshots)

این‌ها وضعیت لحظهٔ خودشان را ثبت می‌کنند و نشان سربرگ دارند:

- **گزارش‌های صفحه و بخش:** `MORE_REPORT.md` · `MORE_ICONS_REPORT.md` · `HOME_FINAL_REPORT.md` ·
  `HOME_POLISH_REPORT.md` · `SETTINGS_REPORT.md` · `SETTINGS_INVENTORY.md` · `SCREEN_INVENTORY.md` ·
  `SPLASH_REPORT.md` · `PAGE_TURN_REPORT.md` · `PER_PRAYER_CARD_REPORT.md` · `BOOKS_READER_REVIEW.md` ·
  `DHIKR_COLLECTIONS_INVENTORY.md` · `DHIKR_VIEW_MODES_REPORT.md` · `ARC_STYLES_REPORT.md` ·
  `MAALIM_RIYAD_BOOKS.md` · `KAFFARA_CONTENT.md`
- **قرآن:** `QURAN_REDESIGN_REPORT.md` · `QURAN_SCREEN_INVENTORY.md` · `QURAN_WS_UPGRADE_PROPOSALS.md`
- **ویجت‌ها:** `GLANCE_FINAL_PLAN.md` · `GLANCE_WIDGETS_REPORT.md` · `WIDGETS_AUDIT_2026-10-26.md` ·
  `WIDGETS_MIGRATION_2026-10-26.md` · `WIDGETS_THEMING_REPORT.md`
- **ابزارهای شخصی و خانواده:** `PERSONAL_STAGE1_REPORT.md` · `PERSONAL_STAGE2_PLAN.md` ·
  `PERSONAL_STAGE2_REPORT.md` · `PERSONAL_STAGE3_PLAN.md` · `PERSONAL_STAGE3_REPORT.md` ·
  `PERSONAL_TOOLS_INVENTORY.md` · `PERSONAL_TOOLS_ROADMAP.md` · `PERSONAL_TOOLS_DELIVERY.md` ·
  `PERSONAL2_INVENTORY.md` · `PERSONAL2_STAGE1_REPORT.md` · `PERSONAL2_STAGE2_REPORT.md` ·
  `PERSONAL2_STAGE3_REPORT.md` · `PERSONAL2_FINAL_REPORT.md`
- **ممیزی و تجمیع:** `AUDIT_REPORT.md` · `ACCURACY_REPORT.md` · `DATA_SOURCES.md` ·
  `NOTIFICATION_RELIABILITY.md` · `COVERAGE_GAPS.md` · `PRE_LAUNCH_AUDIT.md` · `BASELINE.md` ·
  `PHASE1_SPEC.md` · `MERGE_1_8_0_REPORT.md` · `RELEASE_MERGE_PLAN.md`

## قاعدهٔ نگهداری

وقتی کاری تمام می‌شود: گزارش آن در همین پوشه می‌ماند و نشان «عکس تاریخ‌دار» می‌گیرد؛
وضعیت تازه فقط در `AGENTS.md` و سند زندهٔ همان بخش (`SECTIONS_1_9_0.md` و…) به‌روز می‌شود.
اگر عددی در یک سند زنده عوض شد، همان کامیت باید سندهای زندهٔ دیگر را هم اصلاح کند و
سندهای عکس‌دار را دست نزند.
