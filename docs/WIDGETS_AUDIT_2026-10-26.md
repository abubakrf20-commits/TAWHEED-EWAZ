# گزارش تشخیصی ویجت‌های توحید — Glance، کلیک، ساعت و دیزاین

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


> تاریخ: 2026-10-26 · شاخه: `release/1.8.0` · دامنه: `android/app/src/main/kotlin/.../widget/**` + پل Flutter
> وضعیت گیت کیفیت در لحظهٔ بررسی: `python tools/quality_check.py --strict` → هر ۸ چک = ۰ (سبز)
> این گزارش **فقط تشخیص** است؛ هیچ فایلی تغییر نکرده.

---

## ۰) خلاصهٔ اجرایی

سیستم فعلی «خراب» نیست — **معماری‌اش عمداً حول سه فرض ساخته شده که با هدف جدید شما در تضاد است**، و همان سه فرض در `tools/quality_check.py` به‌صورت گیت سخت‌کد شده‌اند. تا وقتی آن گیت باز نشود، مرحلهٔ ۱ و ۲ نقشهٔ شما حتی کامپایل هم نمی‌شود (گیت فیل می‌کند).

| مشکل گزارش‌شده | علت ریشه‌ای (تشخیصی) | اطمینان |
|---|---|---|
| کلیک تا ۳۰ ثانیه | مسیر کلیک یک **Activity ترامپولین** است ⇒ استارت سرد پروسهٔ اپ (۷ ContentProvider: Firebase/Sentry/WorkManager) + کل کار روی main thread قبل از اولین فریم + یک composition کامل Glance + **باگ خنثی‌شدن safety-heal در burst** | بالا (کد) / متوسط (۳۰s) |
| ساعت ۶ دقیقه عقب | ساعت و شمارش معکوس **رشتهٔ پخته‌شده در زمان رندر**‌اند؛ تنها تیک‌دهنده یک آلارم دقیق است که بدون مجوز `SCHEDULE_EXACT_ALARM` به `setAndAllowWhileIdle` تنزل می‌کند و در Doze تا **۹ دقیقه** throttle می‌شود | بالا |
| شمارش معکوس ثابت | عمدی است: `minuteElapsed()` در زمان composition حساب می‌شود، تا رندر بعدی یخ می‌زند (granularity دقیقه، با خطای +۱ دقیقه از ceil) | قطعی |
| دیزاین | پایهٔ خوبی هست (چیپ، نوار تاریخ، ۵ باکس، حلقه)؛ شکاف‌ها: تپِ «خواندم»، تیر بزرگ، آیکون وکتور دکمه‌ها، RTL تضمین‌شده، فونت، حالت خطا | متوسط |

سه نکته‌ای که فکر می‌کنم هنوز ندیده‌اید:

1. **`tools/quality_check.py:394` عبارت `AndroidRemoteViews` را در هر فایل ویجت ممنوع می‌کند** و `actionRunCallback` را هم (`:400`). یعنی مرحلهٔ ۲ («TextClock با AndroidRemoteViews») و مرحلهٔ ۱ (کال‌بک سبک به‌جای Activity) هر دو توسط گیت خودتان بلاک می‌شوند.
2. **مدرک آن دو ممنوعیت از یک گوشی MIUI/شیائومی است** (اسکرین‌شات `w1.png` در ریشهٔ ریپو: «لا يمكن تحميل التطبيق المصغّر») — نه از A13/A32 که هدف شماست. معماری فعلی حول یک باگ روی گوشی غیرهدف قالب خورده و بعد با lint قفل شده.
3. **باگ safety-heal**: بعد از دو تپ سریع، هیچ heal‌ای برای burst وجود ندارد (توضیح کامل در §۵، باگ B1). این تنها مکانیزمی بود که «رندر گم‌شده» را جبران می‌کرد.

---

## ۱) نقشهٔ کدِ امروز

### زنده (در مسیر رندر/کلیک)
| فایل | نقش |
|---|---|
| `widget/PrayerGlanceWidget.kt` (675) | Composable کارت اوقات، `SizeMode.Exact` |
| `widget/PrayerWidget.kt` (564) | Receiver + زنجیرهٔ آلارم: minute tick، midnight، boundary×13، watchdog 6h |
| `widget/PrayerWidgetBudget.kt` (214) | بودجهٔ ارتفاع/فونت کارت (ارزشمند — نگه دارید) |
| `widget/PrayerWidgetModel.kt` (109) | snapshot خالص برای composable |
| `widget/PrayerWidgetViews.kt` (132) | `computeCountdown` + `convertTo12h` (خالص، تست‌شده) |
| `widget/PrayerTimesCalculator.kt` (556) | محاسبهٔ آفلاین اوقات — **داخل مسیر رندر اجرا می‌شود** (§۵ باگ B6) |
| `widget/TasbihGlanceWidget.kt` (356) | Composable تسبیح |
| `widget/TasbihGlanceWidgetReceiver.kt` (633) | Receiver + صف رخداد + ریست نیمه‌شب + watchdog |
| `widget/TasbihActionActivity.kt` (217) | ترامپولین شفاف تپ |
| `widget/TasbihTapEngine.kt` (295) | ماشین حالت تپ + صف رندر coalesced |
| `widget/WidgetTheme.kt` (365) | پالت/شفافیت از `assets/widget_palettes.json` |
| `widget/WidgetArt.kt` (167) | بیت‌مپ گرادیان + حلقه (کش‌شده) |
| `widget/WidgetRepository.kt` (505) | کلیدهای prefs + recompute بومی |
| `widget/IslamicCalendars.kt` (150) | تبدیل جلالی/هجری |

### مرده (مرحلهٔ ۷ — آمادهٔ حذف، همه تأییدشده با grep)
- `LatinWidgetViews.kt` → `LatinCountdownView` هیچ‌جا استفاده نمی‌شود؛ `LatinClockView` **فقط** به‌عنوان `android:initialLayout` در دو `*_info.xml` زنده است (§۵ باگ B4).
- `res/layout/widget_live_countdown.xml` — هیچ ارجاعی ندارد.
- `WidgetRepository.readStyle()` — صفر ارجاع.
- `WidgetRepository.readSnapshot()` + `data class Snapshot` (۳۳ فیلد) — صفر ارجاع. کلیدهای `khatm_*`، `timeline_*`، `dynamic_*`، `widget_calendar_events` نوشته می‌شوند و **هیچ‌وقت خوانده نمی‌شوند**.
- `MainActivity.registerWidgetRefreshReceiver()` (`:181-202`) — مسیر تیکِ موازی که با آلارم دقیقه دو composition هم‌زمان می‌سازد (§۵ باگ B5).
- `%TEMP%/opencode/prayer-widget-wip/` — نسخهٔ RemoteViews قدیمی بیرون ریپو؛ مرجع تاریخی، نه کد.

---

## ۲) تشخیص ۱ — چرا کلیک کند است

مسیر واقعی یک تپ تسبیح، امروز:

```
Launcher tap
  └─ PendingIntent.getActivity → TasbihActionActivity (process start سرد)
       ├─ Application.onCreate → 7 ContentProvider (Firebase, Sentry, WorkManager/startup, …)
       ├─ Activity.onCreate  ← همهٔ این‌ها روی main thread، قبل از اولین فریم:
       │    ├─ WidgetTokens.init()            → asset + JSON
       │    ├─ applyTap()                     → read-modify-write prefs
       │    │    └─ appendEvent()             → parse کل صف JSON + re-serialize  ← O(n)
       │    ├─ armSafetyRender()              → AlarmManager + PendingIntent (binder)
       │    └─ requestRender()                → coroutine (Default)
       └─ wait ≤1500ms برای paint → finish()
            └─ Glance: provideGlance → WidgetTheme.resolve (asset JSON هر بار)
                 → WidgetArt.ring (بیت‌مپ ARGB ~0.4–0.8MB) → updateAll → IPC لانچر
```

عوامل به‌ترتیب سهم (تخمینی، برای تأیید با لاگ در §۶):

| # | عامل | شاهد در کد | هزینه |
|---|---|---|---|
| C1 | **Activity = استارت سرد کل اپ** برای هر دانهٔ تسبیح | `TasbihActionActivity` در manifest؛ `application android:name="android.app.Application"` + ۷ provider | ۳۰۰–۱۵۰۰ms (A13، اپ فریزشده) |
| C2 | کل تپ+رندر روی **main thread داخل `onCreate`** | `TasbihActionActivity.kt:99-123` | همان بازه، بدون فریم |
| C3 | **`appendEvent` در هر تپ کل صف را parse و دوباره serialize می‌کند** (تا ۳۰۰ رخداد) | `TasbihTapEngine.kt:188` → `TasbihGlanceWidgetReceiver.kt:403-431` | ۲–۱۵ms در هر تپ، رشد با طول صف |
| C4 | **composition کامل Glance در هر تپ** — Glance API جزئی ندارد (`partiallyUpdateAppWidget` ممکن نیست) | `TasbihTapEngine.kt:138` `updateAll` | ۵۰–۱۵۰ms گرم، بیشتر سرد |
| C5 | `WidgetTheme.resolve` هر رندر asset را می‌خواند و JSON parse می‌کند؛ کش `cachedSpec` **بین تپ‌ها** با کشته‌شدن پروسه صفر می‌شود | `WidgetTheme.kt:239-247` | ۵–۳۰ms سرد |
| C6 | بیت‌مپ حلقه در هر رندر (کش ۸تایی، با burst سریع thrash می‌شود) | `WidgetArt.kt:111-132` | ۳–۱۰ms + GC |
| C7 | **باگ: در burst هیچ safety-heal وجود ندارد** | §۵ باگ B1 | ⇒ اگر paint بیفتد، تا تپ بعدی/۶ ساعت چیزی جبران نمی‌کند |
| C8 | در سطح سیستم: «Sleeping apps» سامسونگ / Battery Saver | خارج از کد | می‌تواند تنها عامل یک تأخیر ۳۰ ثانیه‌ای باشد |

**قضاوت:** ۳۰ ثانیه از یک عامل نمی‌آید. ترکیب C1+C7 روی گوشی‌ای که اپ را خوابانده، «تپ‌ها بی‌اثر، بعد یک‌جا ظاهر می‌شوند» می‌سازد — که دقیقاً همان چیزی است که گزارش کرده‌اید. **بدون logcat روی A13 نمی‌توان C1 را از C8 جدا کرد** — و همین دلیل وجود مرحلهٔ ۰ است.

**دربارهٔ هدف «زیر ۲۰۰ms»:** این عدد را باید دو بخشی تعریف کنیم، وگرنه غیرقابل‌دستیابی است:

- **warm** (پروسه زنده): با مسیر broadcast + حذف Activity، ۶۰–۱۵۰ms واقع‌بینانه است. ✅
- **cold** (پروسه مرده): کفِ مطلق = زمان استارت پروسه (۳۰۰ms+ روی A13). هیچ معماری Glance‌ای این را زیر ۲۰۰ms نمی‌آورد.
- **زیر ۲۰۰ms حتی در cold** فقط با `partiallyUpdateAppWidget` روی یک درخت RemoteViews با id ثابت ممکن است (تپ = `setTextViewText` + `setImageViewBitmap` ≈ ۲۰–۴۰ms) — که یعنی کارت تسبیح نباید Glance باشد. این تنها راه رسیدن به عدد شماست و باید صریح تصمیم بگیرید (§۷، گزینهٔ B).

---

## ۳) تشخیص ۲ — ساعت عقب و شمارش ثابت

### چرا ساعت عقب می‌ماند (۶ دقیقه = امضای Doze، نه باگ)
ساعت یک `Text` با رشتهٔ پخته است (`PrayerGlanceWidget.kt:568-573`). تازگی‌اش فقط از این چهار مسیر می‌آید:

| مسیر | کد | چه‌وقت می‌میرد |
|---|---|---|
| آلارم دقیق هر دقیقه | `PrayerWidget.kt:196-220` | بدون `SCHEDULE_EXACT_ALARM` → `setAndAllowWhileIdle` → در Doze **حداکثر یک بار در ۹ دقیقه** |
| `setInexactRepeating` ۶۰s | `:227-242` | Doze/App Standby آن را batch و تا پنجرهٔ maintenance عقب می‌اندازد |
| `ACTION_TIME_TICK` | `MainActivity.kt:186` | فقط تا وقتی پروسهٔ اپ زنده است |
| watchdog ۶ ساعت | `:116-134` | فقط سقف بدترین حالت |

`SCHEDULE_EXACT_ALARM` از Android 14 برای اپ‌های غیرساعت‌زنگ **پیش‌فرض رد** است. روی A13/A32 با Battery Saver، سناریوی «۶ دقیقه عقب» خروجی موردانتظار همین طراحی است. یعنی **این باگ نیست، پیامد معماریِ «رشتهٔ پخته + آلارم» است** — و راه‌حلش دقیقاً همان چیزی است که خودتان نوشته‌اید: لِیفِ خودتیک.

### چرا شمارش معکوس ثابت است
`CountdownChip` مقدار را در زمان composition حساب می‌کند (`:608`)، `minuteElapsed` هم به بالا ceil می‌کند (`:645-654`). بین دو رندر، عدد یخ است و تا ۶۰ ثانیه خطا دارد. اگر رندر بیفتد، ساعت‌ها یخ می‌ماند.

### تناقض درونی که باید بدانید
`PrayerGlanceWidget.kt:50-60` صریحاً می‌گوید لِیفِ تودرتوی RemoteViews را حذف کرده چون MIUI کل آپدیت را رد می‌کرد. یعنی **راه‌حل درست (TextClock/Chronometer) قبلاً پیاده شده بود و به‌خاطر یک گوشی غیرهدف حذف شد.** `LatinClockView`/`LatinCountdownView` هنوز در ریپو هستند و همان کار را می‌کنند (با مزیت: ارقام ASCII، حتی روی لانچر عربی).

---

## ۴) تشخیص ۳ — دیزاین: چه هست، چه کم است

| خواستهٔ نقشه | وضعیت فعلی | شاهد |
|---|---|---|
| چیپ روز (راست) + چیپ شهر (چپ) | ✅ هست (Badge، سفید ۶٪) | `:290-297` |
| ساعت بزرگ tabular با TextClock | ❌ `Text` پخته؛ tabular نیست | `:568` |
| نوار تاریخ ۳ بخش + جداکننده ۰.۵dp | ⚠️ هست ولی جداکننده ۱dp و ترتیب hijri→shamsi→gregorian | `:317-332`, `:458-465` |
| ۵ باکس با آیکون وکتور | ✅ آیکون وکتور هست | `PRAYER_ICONS`, `:669` |
| نماز فعلی: طلایی ۱۶٪ + قاب ۱dp | ⚠️ **عمداً حذف شده**: فقط wash خنثی + ساعت طلایی (بازخورد کاربر ۲۰۲۶-۱۰-۲۵) | `:126-133` |
| گذشته‌ها شفافیت ۶۵٪ | ✅ (۰.۵–۰.۵۲) | `:496-500` |
| تپ باکس = ثبت «خواندم» (Kotlin-only) + تیک | ❌ وجود ندارد؛ تیک فقط از اپ می‌آید | `prayer_statuses` push |
| قرص پایین با Chronometer | ⚠️ متن ثابت با فرمت `%s` | `:398-404` |
| ۳ تیر (کوچک/متوسط/بزرگ + آیه) | ⚠️ فقط دو تیر (small/medium)، `SizeMode.Exact`؛ تیر بزرگ ندارد | `:64`, `SMALL_MAX_HEIGHT_DP=160` |
| نام ذکر ۱۸sp وسط | ⚠️ ۱۰.۵–۱۴sp مقیاس‌پذیر | `:104` |
| دو قرص «ذکر X از N» و «امروز M» | ⚠️ یک خط caption «2/5 · امروز N» | `TasbihWidgetModel.kt:43-51` |
| حلقهٔ Bitmap کش‌شده | ✅ (۱٪ کوانتیزه، کش ۸) | `WidgetArt.kt:52,127` |
| ۳ دکمه با آیکون وکتور، ارتفاع ≥۴۸dp | ⚠️ گلیف متنی `‹ ↻ ›`، ارتفاع ۴۴dp در scale 0.7 | `:112, 274-310` |
| کل حلقه = +۱ | ✅ | `:221` |
| لرزش سبک + دوتایی در پایان دور | ⚠️ فقط تک‌لرزش ۲۰ms | `TasbihTapEngine.kt:278-294` |
| ریست روزانه در نیمه‌شب | ✅ آلارم + maybeDailyReset | `:288-327` |
| گرادیان/سایه با drawable شکل‌دار fallback | ✅ (بیت‌مپ گرادیان؛ نه shape XML) | `WidgetArt.surface` |
| فونت سفارشی | ❌ `res/font` وجود ندارد | — |
| RTL کامل | ❌ `android:supportsRtl` ست نشده؛ ترتیب باکس‌ها LTR است | manifest |
| حالت loading/خطا | ⚠️ فقط hint «برنامه را باز کنید»؛ حالت خطا/کهنه ندارد | `ONBOARDING_HINT` |

نکتهٔ ظریف دیزاین: چیدمان فعلی **در تضاد با spec شما در یک جا** است — spec می‌گوید نماز فعلی «پس‌زمینه طلایی ۱۶٪ + قاب ۱dp»، ولی کامنت کد می‌گوید کاربر در ۲۰۲۶-۱۰-۲۵ صریحاً گفت «بوکس وقت نماز فعلی طلایی نشود، فقط ساعتش». **این را باید قبل از پیاده‌سازی روشن کنیم**، وگرنه همان شکایت برمی‌گردد.

---

## ۵) باگ‌های مشخص (مستقل از سه شکایت اصلی)

| # | شدت | محل | مکانیزم | اثر |
|---|---|---|---|---|
| **B1** | 🔴 بحرانی | `TasbihActionActivity.kt:146-153` + `TasbihGlanceWidgetReceiver.kt:141-149` | `armSafetyRender` با `FLAG_NO_CREATE` چک می‌کند؛ تا وقتی heal قبلی pending است، تپ‌های بعدی **اصلاً heal جدید arm نمی‌کنند**. heal قدیمی `armedSeq < currentSeq` را می‌بیند و **stand down** می‌کند. ⇒ در یک burst، هیچ heal‌ای اجرا نمی‌شود. | رندر گم‌شده = شمارنده تا تپ بعدی (یا ۶ ساعت) کهنه می‌ماند — دقیقاً «کند عمل می‌کند» |
| **B2** | 🔴 بالا | `quality_check.py:394-406` | گیت `AndroidRemoteViews` و `actionRunCallback` را ممنوع می‌کند | مرحلهٔ ۱ و ۲ نقشهٔ شما غیرقابل‌اجرا می‌شود |
| **B3** | 🟠 متوسط | `PrayerGlanceWidget.kt:71` → `WidgetRepository.kt:378-429` | محاسبهٔ نجومی اوقات + ۷ نوشتن prefs **داخل `provideGlance`** | نقض «هیچ I/O سنگین در provideGlance»؛ هر رندرِ روزِ نو، محاسبهٔ کامل |
| **B4** | 🟠 متوسط | `res/xml/widget_prayer_info.xml` + `widget_tasbih_info.xml` | `initialLayout` به `LatinClockView` اشاره می‌کند — یک **ویو سفارشی با Handler تیک و registerReceiver** | اگر هاست نتواند inflate کند ⇒ همان «couldn't load widget»؛ در حالت موفق هم یک تیکر و یک receiver داخل پروسهٔ **لانچر** باقی می‌گذارد. ضمناً placeholder کارت تسبیح، یک ساعت است |
| **B5** | 🟠 متوسط | `MainActivity.kt:181-202` + `PrayerWidget.kt:175` | `ACTION_TIME_TICK` و آلارم دقیقه هر دو `refreshAll` ⇒ **دو composition در دقیقه**، بدون coalescing (برخلاف تسبیح) | رندر قدیمی می‌تواند روی جدید بیفتد؛ باتری |
| **B6** | 🟠 متوسط | `PrayerWidget.kt:341-450` | در هر رندر: `cancelBoundaryUpdates` (۱۳ cancel) + ۱۳ `setExact` جدید + `scheduleMinuteTick` (۲ arm) + watchdog | ۱۶+ عملیات binder در هر رندر؛ هر دقیقه تکرار می‌شود |
| **B7** | 🟡 کم | `TasbihWidgetModel.kt:83` | `todayTotal = counts.values.sum()` — مجموع شمارنده‌های per-zikr، در حالی که کلید مجزای `widget_tasbih_daily_total` وجود دارد و نادیده گرفته می‌شود | اگر اپ شمارندهٔ تجمعی (نه روزانه) push کند، «امروز M» غلط می‌شود |
| **B8** | 🟡 کم | `PrayerWidget.kt:505` vs `TasbihGlanceWidgetReceiver.kt:388` | هر دو request code `9993` | امروز بی‌ضرر (کامپوننت متفاوت)؛ ولی شماره‌گذاری شکننده |
| **B9** | 🟡 کم | `WidgetTheme.kt:300-304` | `resolve()` هنگام adoption داخل رندر prefs می‌نویسد | I/O در مسیر رندر |
| **B10** | 🟡 کم | `TasbihGlanceWidget.kt:221` | تپ روی حلقه = `boxDp` که تا `RING_BOX_FLOOR_DP=36dp` کوچک می‌شود | زیر حد لمس ۴۸dp |
| **B11** | 🟡 کم | `widget_prayer_info.xml` | `minHeight=120dp` < آستانهٔ ۱۶۰dp کارت متوسط | **پلیس‌هولد پیش‌فرض همیشه کارت کوچک است** — کاربر برای دیدن ۵ باکس باید دستی بزرگ کند |
| **B12** | 🟡 کم | `PrayerWidgetModel.kt:37` | `timeLabel` به `PrayerWidgetViews` (کلاس غیر-object) وابسته است | کوپلینگ بی‌دلیل؛ تست‌پذیری کمتر |

---

## ۶) طرح اندازه‌گیری (مرحلهٔ ۰) — دقیقاً چه لاگ‌هایی اضافه شود

بدون این، هر عددی در گزارش تخمین است. چهار خط لاگ با تگ واحد و یک ستون `ms`:

```
W/TW_TIMING  tap.received   t=0            (اولین خط onCreate ترامپولین / اول onReceive)
W/TW_TIMING  process.ready  +Xms           (اختلاف SystemClock.uptimeMillis با Process.getStartUptimeMillis())
W/TW_TIMING  prefs.committed +Xms          (بعد از applyTap)
W/TW_TIMING  render.start    +Xms
W/TW_TIMING  render.done     +Xms  bytes=<RemoteViews byte size>
W/TW_TIMING  launcher.painted (تخمین: پایان finish() ترامپولین)
```

نکات اجرایی:
- `Process.getStartUptimeMillis()` (API 24+) فاصلهٔ «تپ → استارت پروسه» را از «استارت → آماده» جدا می‌کند — همان چیزی که C1 را از C8 تفکیک می‌کند.
- یک `Trace.beginSection("glance.compose")` در `provideGlance` برای systrace.
- برای ساعت: هر رندر `now=HH:mm:ss` و `renderedFor=HH:mm` را لاگ کند تا drift قابل محاسبه باشد؛ به‌علاوه `alarmManager.canScheduleExactAlarms()` یک بار در `onUpdate`.
- خروجی: `adb shell dumpsys alarm | grep tawheeed` برای دیدن throttle و deferred alarms.

---

## ۷) تناقض‌های بنیادی با نقشهٔ ۸ مرحله‌ای (باید تصمیم بگیرید)

| نقشهٔ شما | مانع واقعی | پیشنهاد من |
|---|---|---|
| م۲: TextClock/Chronometer با `AndroidRemoteViews` | گیت B2 + تجربهٔ MIUI | گیت را از «ممنوع» به «مجاز فقط پشت پرچم قابلیت» تغییر بده؛ لِیف را با fallback برگشت‌پذیر اضافه کن. `LatinClockView` موجود را ترجیح بده (ارقام ASCII — TextClock روی لانچر عربی/فارسی ارقام عربی-هندی می‌دهد) |
| م۱: کلیک Kotlin-only، بدون Flutter | از قبل برقرار است (هیچ فراخوانی موتور Flutter نیست) | مسئله «Flutter» نیست، «Activity + استارت سرد» است |
| م۱: زیر ۲۰۰ms | Glance هیچ partial-update ندارد | warm <200ms؛ cold فقط با RemoteViews-native (گزینهٔ B در §۸) |
| م۵: `SizeMode.Responsive` | در Responsive، `LocalSize` = سایز spec انتخابی، **نه سلول واقعی** ⇒ `PrayerWidgetBudget` بی‌معنا می‌شود و کلیپ برمی‌گردد | `Exact` را نگه دار و تیر سوم (large) را با آستانهٔ ارتفاع اضافه کن. سه تیر لازم نیست Responsive باشد |
| م۳: محاسبهٔ اوقات در ویجت ممنوع | امروز `PrayerTimesCalculator` داخل رندر اجرا می‌شود (B3) | محاسبه را از مسیر رندر بیرون ببر (به `onUpdate`/receiver) و JSON امروز+فردا را از Flutter بگیر |
| م۴: WorkManager ۱۵ دقیقه | `work-runtime:2.10.2` موجود و `InitializationProvider` فعال است ⇒ آماده | ✅ بدون کار اضافه |
| م۷: پاکسازی | فهرست مرده در §۱ آماده است | با یک کامیت جدا |
| م۵: باکس فعلی طلایی | بازخورد کاربر ۲۰۲۶-۱۰-۲۵ مخالف است | **قبل از پیاده‌سازی تأیید بگیرید** |

---

## ۸) معماری هدف (دو گزینه، تصمیم با شما)

### گزینهٔ A — Glance بماند + لِیفِ خودتیک (کم‌ریسک، سازگار با spec)
```
Flutter ──(JSON امروز+فردا، رنگ ARGB، وضعیت نمازها)──► prefs
                                                          │
Receiver (BOOT/TIME_SET/TZ/PACKAGE_REPLACED/ALARM) ───────┤
                                                          ▼
                        Glance composition (فقط وقتی داده عوض شد)
                          ├─ چیپ‌ها، نوار تاریخ، ۵ باکس  ← Glance Text
                          ├─ ساعت          ← AndroidRemoteViews(LatinClockView)   خودتیک
                          └─ شمارش معکوس   ← AndroidRemoteViews(LatinCountdownView) خودتیک
                        ⇒ هیچ رندر دوره‌ای لازم نیست؛ آلارم فقط برای flip فاز/تاریخ
```
- کلیک: `actionRunCallback` (broadcast، بدون Activity) → prefs → `updateAll` یک‌بار.
- ساعت: حتی اگر همهٔ آلارم‌ها بمیرند، **درست می‌ماند**. این تنها راه حذف کامل polling است.
- ریسک: MIUI. با پرچم `widget_live_leaves` + fallback به رشتهٔ پخته.

### گزینهٔ B — کارت تسبیح RemoteViews-native (تنها راه <200ms در cold)
```
tap → broadcast receiver → prefs → partiallyUpdateAppWidget(count Text + ring Image)
```
- ۲۰–۴۰ms بعد از استارت پروسه؛ بدون composition.
- هزینه: کارت تسبیح از Glance خارج می‌شود (خلاف «مهاجرت به Glance»)، ولی spec شما «کلیک فوری» را بالاتر از خلوص معماری گذاشته.
- توصیه: **اول A را بساز و اندازه بگیر**؛ اگر warm زیر ۲۰۰ms شد، B لازم نیست.

---

## ۹) قرارداد کلیدهای prefs (پیشنهاد `WidgetPrefs.kt`)

| کلید | نوع | نویسنده | خواننده |
|---|---|---|---|
| `prayer_1..5` | String `"فجر 04:31"` | Flutter (+Kotlin recompute) | هر دو |
| `iqamah_offsets` | JSON int[5] | Flutter | Kotlin |
| `sunrise` / `sunset` | String `HH:mm` | Flutter | Kotlin |
| `widget_times_json` ⭐جدید | JSON `{today:{fajr,…},tomorrow:{…}}` | Flutter | Kotlin (فقط خواندن) |
| `widget_times_date` | `YYYY-MM-DD` | Flutter | Kotlin |
| `shamsi_date` / `hijri_date` / `gregorian_date` | String | Flutter | Kotlin |
| `city_name`, `widget_use_12_hour` | String/Bool | Flutter | Kotlin |
| `prayer_statuses` | JSON map | Flutter | Kotlin |
| `widget_accent_argb` / `widget_text_argb` / `widget_bg_argb` ⭐جدید | Int ARGB | Flutter | Kotlin |
| `widget_palette_id_{prayer,tasbih}` | String | Flutter (setWidgetTheme) | Kotlin |
| `widget_opacity_step_{prayer,tasbih}` | Int 0..3 | Flutter | Kotlin |
| `tasbih_dhikr`, `tasbih_zikr_index`, `tasbih_count`, `tasbih_target` | — | هر دو | هر دو |
| `tasbih_per_zikr_counts` / `_targets` | JSON | Kotlin می‌نویسد، Flutter merge می‌کند | هر دو |
| `tasbih_zikr_list` | JSON string[] | Flutter | Kotlin |
| `tasbih_auto_reset`, `azkar_haptic` | Bool | Flutter | Kotlin |
| `widget_tasbih_daily_total` / `_date` | Int / String | Kotlin | Kotlin ⚠️ (B7) |
| `widget_tasbih_pending` / `_seq` | JSON / Int | Kotlin | Kotlin + Flutter drain |
| `widget_tasbih_last_tap_at` | Long | هر دو | هر دو |
| `widget_live_leaves` ⭐جدید | Bool | Kotlin (probe) | Kotlin |

قاعده: **هر کلید یک مالک نوشتن دارد**؛ خواندن آزاد. Flutter هرگز کلیدهای `tasbih_per_zikr_*` و `widget_tasbih_pending*` را بازنویسی نکند (فقط merge).

---

## ۱۰) برنامهٔ اجرا با اولویت

**P0 — قبل از هر دیزاین (۱–۲ ساعت):**
1. B1 (safety-heal) را درست کن: arm همیشه با `UPDATE_CURRENT` و آخرین seq؛ شرط stand-down حذف شود.
2. لاگ‌های §۶ را اضافه کن (بدون تغییر رفتار).
3. `initialLayout` را به یک layout ساده/استاتیک عوض کن (B4) و `widget_live_countdown.xml` را حذف کن.

**P1 — مرحلهٔ ۱+۲ (اصلی، ۱–۲ روز):**
4. گیت B2 را به «مجاز پشت پرچم» تغییر بده.
5. مسیر تپ را از Activity به broadcast ببر؛ Activity را برای سازگاری نگه دار ولی خاموش (پرچم).
6. لِیفِ ساعت/شمارش با `AndroidRemoteViews` + `LatinClockView`/`LatinCountdownView` + fallback.
7. حذف `scheduleMinuteTick` و backstop تکرارشونده؛ آلارم فقط برای boundary/نیمه‌شب/فاز.
8. حذف `MainActivity.registerWidgetRefreshReceiver` (B5).

**P2 — داده و زمان‌بندی (مرحلهٔ ۳+۴):**
9. `widget_times_json` (امروز+فردا) + `WidgetPrefs.kt` + حذف محاسبه از مسیر رندر (B3).
10. رنگ‌ها به‌صورت ARGB از Flutter.
11. WorkManager ۱۵ دقیقه‌ای به‌عنوان پشتیبان + receiverهای BOOT/TIME_SET/TZ/PACKAGE_REPLACED.

**P3 — دیزاین (مرحلهٔ ۵+۶):**
12. کارت اوقات: تیر سوم، تپ «خواندم»، آیکون وکتور، tabular numerals.
13. کارت تسبیح: ۳ دکمهٔ وکتور ۴۸dp، لرزش دوتایی، ✓، قرص‌های جدا.
14. RTL صریح (نه اتکا به mirroring) + تست فونت بزرگ + حالت خطا.

**P4 — پاکسازی (مرحلهٔ ۷):** فهرست §۱.

---

## ۱۱) چک‌لیست تست روی A13/A32 (مرحلهٔ ۸)

| سناریو | معیار قبولی |
|---|---|
| ۲۰ تپ پشت‌سرهم (warm) | p95 < 200ms، شمارنده = ۲۰ |
| ۲۰ تپ پس از kill اپ (cold) | p95 < 700ms، شمارنده = ۲۰ |
| ساعت پس از ۳۰ دقیقه بدون تعامل | اختلاف ۰ دقیقه |
| پس از reboot | ساعت درست + شمارنده حفظ + ریست روزانه arm |
| تغییر timezone | تاریخ‌ها و اوقات در < ۵s درست |
| Battery Saver روشن | ساعت همچنان درست (لِیف خودتیک) |
| اپ kill شده + ۳ روز بی‌استفاده | اوقات روز جاری درست (JSON فردا) |
| فونت سیستم ۱.۳× | هیچ کلیپی در ۴×۲ و ۴×۳ |
| زبان دستگاه انگلیسی | چیدمان همچنان RTL و ترتیب باکس‌ها درست |
| Samsung sleeping apps | رفتار مستند + پیام راهنما |

---

## ۱۲) ریسک‌ها و «نکن»ها

- ⛔ `widget_palette_*_bg*.xml`ها خروجی ژنراتورند (`tool/widget_palette_generator.dart`) — دست نزنید.
- ⛔ `WidgetTokens.DEFAULT_BG_INT` منبع واحد پس‌زمینهٔ ویجت است.
- ⛔ بودجهٔ `PrayerWidgetBudget` را دور نزنید؛ هر sp/dp جدید باید در بودجه حساب شود.
- ⛔ بدون `build_runner`/codegen.
- ⚠️ هیچ‌کدام از فایل‌های ویجت در فهرست protected نیستند، ولی `pubspec.yaml`، `main.dart`، `app_settings.dart` و باندل مصحف هستند — لمس نشوند.
- ⚠️ موازی‌سازی: `git status` قبل از هر کامیت؛ `git add <file>` تک‌تک.

---

## ۱۳) جمع‌بندی در یک پاراگراف

سه مشکل شما یک ریشهٔ مشترک دارند: **همهٔ حالت ویجت از «رندر» می‌آید.** کلیک کند است چون رندر یک Activity سرد را بالا می‌آورد؛ ساعت عقب است چون رندر به آلارمی وابسته است که در Doze throttle می‌شود؛ شمارش ثابت است چون رندر تنها تیک‌دهنده است. راه‌حل هم یک کلمه است: **حالتِ خودتیک** (ساعت/شمارش داخل RemoteViews) + **کلیکِ بی‌رندر** (broadcast، و اگر لازم شد partial update). هر دو مسیر امروز توسط گیت خودتان بلاک شده‌اند و مدرکشان از گوشی غیرهدف آمده — این اولین چیزی است که باید باز شود.
