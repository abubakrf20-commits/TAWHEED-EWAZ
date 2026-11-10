# نقشه تجمیع در release/1.8.0 — ✅ اجرا شد (2026-10-10)

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


مقصد `release/1.8.0` است (از نوک `release/1.7.2` ساخته شد — چون از
`1.7.2+10014` قبلاً APK ریلیز بیرون رفته، فیچرها نباید در همان شاخه قاطی
شود). تمام کارهای آینده روی `release/1.8.0` می‌نشیند.

وضعیت نهایی: خط `merge/release-1.8.0-all` در `release/1.8.0` ادغام شد؛
APK نهایی `1.8.0+10015` (45.8MB، sha1 `38604CEC…`) در
`Desktop/tawheeed-release-apks/1.8.0-merge/`. جزئیات در
`docs/MERGE_1_8_0_REPORT.md`.

## موجودی شاخه‌ها (وضعیت 2026-10-09، `unique` = کامیتِ مختص شاخه نسبت به release/1.7.2 — همان پایه release/1.8.0)

| شاخه | unique | تصمیم |
|---|---|---|
| fix/announcements-publish | 1 | merge |
| fix/document-photos-test | 3 | merge (شامل ۳ فیکس پرامپتر قدیمی — با کار جدید پرامپتر چک شود) |
| fix/quran-mushaf-paging | 1 | merge |
| polish/announcements-rows | 2 | merge |
| polish/suggestions-rows | 2 | merge |
| rescue/friday-clean | 1 | merge (کارت آداب جمعه) |
| rescue/friday-work | 1 | فقط WIP بکاپ — merge نشود، نگه داشته شود |
| integration/friday-on-2a12863 | 1 | تکراریِ friday-clean — merge نشود |
| wip/pre-audit-merge | 1 | فقط بکاپ — merge نشود |
| home/polish-v2 | 27 | merge (تلاوة؛ بزرگ — آخرِ صف، با دقت) |
| freebuff/task-7cf24759 | 16 | بررسی تک‌تک کامیت، بعد merge انتخابی |
| freebuff/task-5dec4f13 | 4 | **merge نشود** — قبلاً آدیت شد: کهنه و پس‌رونده است |
| freebuff/https-prompter-… | 0 | قبلاً merge شده — کاری ندارد |
| release/1.7.1 | 0 | کاری ندارد |
| phase1/redesign | 0 | کاری ندارد |
| remove/recitation-companion | 5 | merge (مستندات + حذف‌های تأییدشده) |
| home/polish-v2-ui | ~17 | merge (کار همین سشن) |

## ترتیب اجرا (کم‌ریسک به پرریسک)

0. **فریز**: اعلام توقف کار موازی؛ `git status` همه worktreeها؛ تغییرات
   uncommitted هر سشن با `git stash -u` تگ‌دارِ جداگانه کنار گذاشته شود
   (هرگز bare stash).
1. مقصد: `release/1.8.0`؛ اول یک کامیت bump نسخه (`1.7.2+10014` →
   `1.8.0+10015`، صعودیِ build number)؛ بعد یک برنچ
   `merge/release-1.8.0-all` از روی آن برای تجمیع.
2. به ترتیب: fixها (تک‌تک + تست) → polishها → friday-clean →
   remove/recitation-companion → home/polish-v2-ui →
   freebuff/task-7cf24759 (انتخابی) → home/polish-v2 (آخر).
3. بعد از **هر** merge: `flutter analyze` + تست‌های ناحیه + بیلد دیباگ؛
   سبز نبود → همان‌جا نگه دار و گزارش بده، جلو نرو.
4. پایان: فول‌سوئیت + `flutter build apk --release` + گزارش نهایی.

## قوانین درگیری و ایمنی

- Stage تک‌فایل (`git add <file>`)، هرگز `add -A`؛ بین add و commit حتماً
  `git diff --cached --stat`.
- فایل‌های محافظت‌شده AGENTS.md فقط با تأیید صریح.
- تاگ/تاریخ بازنویسی نشود (merge معمولی، نه rebase شاخه‌های دیگران).
- Push هرگز (رپو remote ندارد؛ ریلیز = بیلد APK).
- رول‌بک: هر مرحله merge-commit جداست؛ برگشت = `git revert` همان کامیت.
