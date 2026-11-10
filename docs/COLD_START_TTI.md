# راهنمای اندازه‌گیری TTI / TTFD (فاز ۱ — Cold Start)

اندازهٔ عددی Time-To-Interactive و Time-To-First-Frame **بدون دستگاه فیزیکی یا اجرای profile قابل بررسی نبود**. این سند روش استاندارد اندازه‌گیری روی دستگاه واقعی است.

## ۱) پیش‌نیاز

- دستگاه اندروید فیزیکی (نه emulator برای اعداد نهایی)
- Flutter SDK نصب‌شده + `adb`
- DevTools از طریق `flutter run`

## ۲) اجرای profile

```bash
flutter run --profile --trace-startup
```

خروجی در پایان اجرا شبیه این است:

```
** OUTPUT TO FILE: build/start_up_info<...>.json **
{
  "engineEnterTimestampMicros": ...,
  "timeToFrameworkInitMicros": ...,
  "timeToFirstFrameMicros": ...,
  ...
}
```

- **timeToFirstFrameMicros** → TTFD (اولین فریم)
- **timeToEngineInit → framework init** → بخش native/engine

## ۳) TTI تعاملی (دستی)

1. `flutter run --profile`
2. در DevTools تب **Performance** را باز کنید
3. اپ را **کاملاً بک‌شید** (`adb shell am force-stop com.islamic.tawheeed`)
4. آیکون اپ را لمس کنید و **همزمان** استاپ‌واچ بزنید
5. تا زمانی ادامه دهید که:
   - اسپلش تمام شده باشد
   - تب خانه لمس‌پذیر باشد (اسکرول/تب پاسخ دهد)

این عدد **TTI تقریبی کاربر** است.

## ۴) مسیر بحرانی فعلی (پس از فاز ۱)

| مرحله | وضعیت |
|-------|--------|
| Error handler install | ابتدای `_bootstrap` — بدون await |
| PackageInfo | فقط مسیر Sentry؛ غیر از آن `unawaited` |
| Firebase + FCM | `unawaited` — خارج از critical path |
| `NotificationService.init` + `handleColdStartTap` | awaited (لازم برای تپ سرد) |
| `loadQuranData` (۲.۵MB JSON) | `unawaited` — بعد از/همزمان با `runApp` |
| BackgroundScheduler | `unawaited` |
| مجوزها در BootCoordinator | تأخیر ۸۰۰ms پس از اولین فریم |
| timeout تنظیمات در اسپلش | ۴ ثانیه (قبلاً ۸) |

## ۵) معیارهای پیشنهادی قبول

| متریک | هدف (گوشی میان‌رده) |
|-------|---------------------|
| TTFD (trace-startup) | < ۱۰۰۰ms |
| TTI دستی (اسپلش→خانه لمس‌پذیر) | < ۲۵۰۰ms |
| تپ سرد نماز → تب خانه با نماز هایلایت | < ۳۰۰۰ms |

## ۶) مقایسه قبل/بعد

1. روی کامیت پایه: `flutter run --profile --trace-startup` → ذخیرهٔ JSON
2. پس از تغییرات: همان دستور، همان دستگاه، همان حالت شارژ/دمای تقریبی
3. مقایسهٔ `timeToFirstFrameMicros` و TTI دستی

> نکته: `--release` برای اعداد واقعی کاربر نهایی؛ `--profile` برای DevTools بدون افت شدید رفتار.

## ۷) آنچه بدون دستگاه قابل بررسی نیست

- اعداد خام TTI/TTFD
- رفتار Doze / exact-alarm روی سخت‌افزار واقعی
- FPS frame build در لحظهٔ اول اسپلش
