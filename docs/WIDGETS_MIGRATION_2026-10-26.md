# گزارش اجرای مهاجرت ویجت‌های توحید — Glance، کلیک، ساعت، دیزاین

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


> تاریخ: 2026-10-26 · مبنا: `docs/WIDGETS_AUDIT_2026-10-26.md`
> وضعیت لحظهٔ تحویل: `:app:compileDebugKotlin` سبز · `:app:testDebugUnitTest` → **۱۲۴ تست، ۰ خطا** · `flutter analyze` روی فایل‌های تغییر‌یافته سبز · `python tools/quality_check.py --strict` → **هر ۸ چک = ۰**
> تصمیم شما که بر همه‌چیز حاکم شد: **«فقط وقت نماز فعلی ساعت طلایی شود نه بوکس»**

---

## ۰) خلاصهٔ اجرایی

هر سه مشکل گزارش‌شده ریشهٔ مشترک داشتند: **تمام حالت ویجت از یک رندر می‌آمد.** ساعت، شمارش معکوس، شمارندهٔ تسبیح و حتی «کلیک کار نکرد» همه خوانندهٔ همان یک فریم بودند. اگر رندر دیر می‌آمد یا اصلاً نمی‌آمد، هر چهار نشانه با هم خراب می‌شدند — و همان اتفاقی است که دیدید.

کاری که انجام شد، حذف آن وابستگی در سه لایه است:

| لایه | قبل | بعد |
|---|---|---|
| مسیر کلیک | `PendingIntent` → **Activity ترامپولین** → استارت سرد پروسهٔ اپ → کل کار روی main → composition کامل | `PendingIntent` → **broadcast به receiver خود ویجت** (بدون پنجره، بدون activity record، بدون lifecycle) → prefs → یک composition |
| ساعت و شمارش معکوس | رشتهٔ **پخته‌شده** در زمان رندر؛ تنها تیک‌دهنده یک آلارم دقیق که در Doze تا ۹ دقیقه throttle می‌شود | `AndroidRemoteViews` با `LatinClockView` که **خودش در پروسهٔ لانچر تیک می‌زند**؛ شمارش معکوس روی `elapsedRealtime` نه ساعت دیواری |
| داده | زمان‌ها هنگام composition از prefs خوانده و ساخته می‌شد | Flutter **امروز + فردا** را به‌صورت JSON می‌نویسد؛ Kotlin فقط «نماز فعلی / بعدی / باقی‌مانده» را مشتق می‌کند — **هیچ حل نجومی داخل composition نیست** |

و تصمیم شما در کد این‌طور نشسته است (`PrayerGlanceWidget.kt:534`):

```kotlin
val timeColor = when {
    // Gold belongs to the highlighted prayer's time and to nothing else.
    isNext -> accentColor
    …
}
```

باکسِ همان نماز فقط یک **لایهٔ خنثی از رنگ متن** می‌گیرد (`withAlpha(textColor, 0.17f)` تیره / `0.13f` روشن) — هیچ طلایی در پس‌زمینه نیست، چون طلایی‌کردن بوکس ردیف را به یک نوار اکسنت تبدیل می‌کرد و با کپسول شمارش معکوس رقابت می‌کرد.

---

## ۱) مرحله ۰ — تشخیص، با ابزار دائمی

`widget/WidgetTiming.kt` (جدید) یک کرنومتر همیشه‌روشن است، تگ `TW_TIMING`، و مهم‌تر از همه این تفکیک:

```
tap → process.start   ← هزینهٔ استارت سرد (هیچ معماری ویجتی حذفش نمی‌کند)
process.start → painted ← هزینهٔ کار داخل پروسه (این همان چیزی است که مهاجرت حذف می‌کند)
```

`Process.getStartUptimeMillis()` (API 24+) این دو را از هم جدا می‌کند؛ بدون آن، «۳۰ ثانیه» و «۲۰۰ میلی‌ثانیه» در لاگ یکسان دیده می‌شوند. هر خط `I/TW_TIMING <event> +<ms>ms <detail>` است و `detail` همیشه origin را نام می‌برد.

---

## ۲) مرحله ۱ — کلیک فقط Kotlin

**چه چیزی حذف شد:** `TasbihActionActivity` از مسیر پیش‌فرض. `PrayerWidget` هیچ‌وقت activity نداشت ولی کال‌بکش هم نبود.

**چه چیزی جایش آمد:** `actionSendBroadcast(Intent(context, TasbihGlanceWidgetReceiver::class.java)…)` — همان الگویی که خودِ Glance برای `actionSendBroadcast` توصیه می‌کند. کلیک دیگر Flutter را بیدار نمی‌کند.

**چیزهایی که سر راه درست شدند:**

- **باگ B1 (safety-heal خنثی می‌شد):** آلارم heal با `FLAG_NO_CREATE` ساخته می‌شد، پس بعد از اولین heal دیگر هیچ‌وقت دوباره مسلح نمی‌شد — یعنی دقیقاً در burst دوم به بعد هیچ جبرانی وجود نداشت. کل آن مکانیزم (آلارم + `tapSeq` + `ACTION_SAFETY_REFRESH`) حذف شد و جایش یک repaint درون‌پروسه‌ای ۱۵۰۰ms آمد که نمی‌تواند فریم جدیدتر را بشوید.
- **صف رندر:** `TasbihTapEngine.requestRender()` burst را coalesce می‌کند (حداکثر ۲ composition در هر burst). Glance partial update ندارد (`partiallyUpdateAppWidget` در دسترس نیست)، پس هر تپ یک composition کامل است؛ coalescing تنها اهرم واقعی است.
- **debounce تحویل حذف شد:** اول یک پنجرهٔ ۸۰ms روی `applyTap` گذاشتم، بعد خودم پسش گرفتم — پنجره‌ای که دوبار-تپِ لانچر را بگیرد، تپِ واقعی انسان را هم می‌خورد. debounce جای درستش صف رندر است، نه شمارش.
- **قفل:** `applyTap` حالا `synchronized(tapLock)` است تا دو تپ هم‌زمان (broadcast + render) شمارنده را گم نکنند.

**قرارداد prefs** در `widget/WidgetPrefs.kt` به‌صورت جدول کامل مستند شده (کلید، نوع، نویسنده، خواننده) و دو قاعدهٔ سخت بالای آن نوشته شده: Flutter هرگز `tasbih_per_zikr_counts` یا `widget_tasbih_pending*` را بازنویسی نمی‌کند (merge می‌کند)، و ویجت هرگز `prayer_statuses` را نمی‌نویسد.

---

## ۳) مرحله ۲ — ساعت و شمارش معکوسِ خودتیک

`widget/WidgetLiveLeaves.kt` (جدید) **تنها** دروازه‌ای است که اجازه دارد `AndroidRemoteViews` بسازد. دو برگ دارد:

- `clock(context, use12Hour, colorArgb, sizeSp)` → `R.layout.widget_live_clock` با `LatinClockView`؛ فرمت را خودش می‌سازد (۱۲/۲۴ ساعته)، هر ثانیه به `HH:mm` تیک می‌زند و ثانیه‌ها را بی‌دلیل repaint نمی‌کند.
- `countdown(context, targetAtMillis, prefix, inlinePrefix, colorArgb, sizeSp)` → `R.layout.widget_live_countdown` با `LatinCountdownView`؛ ورودی «زمان دیواری هدف» است و به **پایهٔ `SystemClock.elapsedRealtime()`** تبدیل می‌شود، چون تغییر ساعت/منطقه نباید شمارش را بپراند.

**سقوط امن:** پرچم `widget_live_leaves` (پیش‌فرض `true`). اگر host از برگ تودرتو سر باز بزند، `disableLiveLeaves()` یک‌بار و برای همیشه آن را خاموش می‌کند و ویجت به رشتهٔ پخته برمی‌گردد **و `rearmAll` دقیقه‌تیک را دوباره مسلح می‌کند** (`PrayerWidget.rearmAll` روی `WidgetPrefs.liveLeaves` گیت شده). یعنی برگشتن به حالت قدیم بدون انتشار نسخهٔ جدید ممکن است، و در حالت جدید آلارم دقیقه عمداً کنسل می‌شود تا دو تیک‌دهنده هم‌زمان وجود نداشته باشد.

**قاعده‌ای که شکسته نشد:** هیچ‌جا در `provideGlance` تابع `recomputeTimesIfStale` صدا زده نمی‌شود — این را گیت کیفیت هم چک می‌کند.

---

## ۴) مرحله ۳ — داده

**قرارداد JSON** (`WidgetPrefs.PrayerTimesPayload`):

```json
{ "date": "2026-10-26",
  "today":    { "fajr":"04:31","dhuhr":"12:05","asr":"15:40","maghrib":"18:12","isha":"19:42","sunrise":"06:01" },
  "tomorrow": { "fajr":"04:33", … } }
```

`tomorrow` فقط برای یک چیز است: بعد از عشا، شمارش معکوس باید به **فجر فردا** اشاره کند، نه به فجر امروز. اگر نبود، `nextFajr` به فجر امروز fallback می‌کند (حداکثر یک دقیقه خطا، هرگز ناپدید نمی‌شود).

**سمت Flutter (این جلسه):**

- `WidgetSnapshot` چهار کانال ARGB (`accentArgb/textArgb/bgArgb/bgEndArgb`) و `prayerTimesJson` گرفت.
- `WidgetSyncService._timesPayload()` امروز را از `allTimes` و فردا را از `prayerTimesForDate(DateTime(y, m, d+1))` می‌سازد. `d+1` عمداً به‌جای `add(Duration(days:1))` است تا در DST روزِ دیواری حفظ شود.
- `WidgetSyncService._paletteArgb()` رنگ‌ها را از پالت واقعی می‌خواند و برای پالت **«خودکار» صفر می‌فرستد**. دلیلش مهم است: فازِ شب/سحر/صبح/… با آلارم‌های مرزی خودِ ویجت تعیین می‌شود؛ اگر این‌جا هم حساب شود، دو طرف می‌توانند یک نماز کامل با هم اختلاف پیدا کنند. صفر = «تصمیم با Kotlin».
- `WidgetRepository.persistSnapshot` این کلیدها را می‌نویسد و اگر اپ قدیمی فقط `prayer_1..5` بفرستد، خودش payload را از آن‌ها می‌سازد.

**«خواندم» (جدید):** تپ روی باکس نماز یک نشان تاریخ‌دار در `widget_prayer_read` می‌گذارد و **هرگز `prayer_statuses` را نمی‌نویسد** — وگرنه push بعدی اپ تپ را پاک می‌کرد. حالا دو متد کانال اضافه شد:

- `getPrayerMarks` → `{date, indices:[0..4]}` (تاریخ داخل خودِ payload است، نه از `widget_times_date` حدس زده می‌شود)
- `drainPrayerMarks(date, indices)` → **فقط همان ایندکس‌هایی** را پاک می‌کند که اپ نوشت. تپی که بین read و ack برسد زنده می‌ماند.

سمت اپ `reconcilePrayerMarksFromWidget()` این‌ها را در `prayerTracker` می‌نویسد (`pending → done`؛ هرگز `done/qada` را پایین نمی‌آورد، هرگز `missed` نمی‌نویسد) و نشان تاریخ دیروز را بدون اعمال دور می‌ریزد. این drain **قبل** از ساخت snapshot اجرا می‌شود، وگرنه کارت نمازی را که همین حالا تپ شده تا sync بعدی «نخوانده» نشان می‌داد.

---

## ۵) مرحله ۴ — زمان‌بندی

| مکانیزم | نقش |
|---|---|
| `setExactAndAllowWhileIdle` برای هر اذان + نیمه‌شب | حرکت طلایی به نماز بعدی، تاریخ‌ها |
| ۱۳ اسلات مرزی (شامل طلوع وقتی پالت `auto` است) | تغییر فاز پالت خودکار |
| `WidgetRefreshWorker` (WorkManager، ۱۵ دقیقه، `UPDATE`) | **کفِ تضمینی**. دقیقاً همان چیزی که وقتی `SCHEDULE_EXACT_ALARM` رد شود (اندروید ۱۴ به‌صورت پیش‌فرض رد می‌کند) یا OEM آلارم‌ها را بخواباند باقی می‌ماند |
| `BOOT_COMPLETED` / `QUICKBOOT` / `MY_PACKAGE_REPLACED` / `TIME_SET` / `TIMEZONE_CHANGED` / `DATE_CHANGED` | بازسازی کل زنجیره |
| `updatePeriodMillis` | عمداً کوتاه **نیست** — هر مقدار کمتر از ۳۰ دقیقه بی‌فایده است و باتری می‌خورد |

این جلسه: `BootReceiver` بعد از `WidgetHub.refreshAll` حالا `WidgetRefreshWorker.schedule(context)` را هم صدا می‌زند (ری‌بوت هر آلارمی را پاک می‌کند؛ بدون این خط، backstop تا باز شدن اپ وجود نداشت).

---

## ۶) مرحله ۵ — دیزاین ویجت نماز

- **ردیف ۰:** چیپ روز هفته (start) + چیپ شهر (end).
- **ساعت:** بزرگ، `FontFamily.Monospace` + `fontFeatureSettings="tnum"` (ارقام هم‌عرض، تا ساعت موقع تیک نلرزد)، ارتفاعش به خط‌کشِ بودجه پین شده تا هرگز روی باکس‌ها رشد نکند.
- **نوار تاریخ سه‌بخشی:** شمسی | قمری | میلادی، با جداکنندهٔ **0.5dp**، `cornerRadius(14.dp)`. ترتیب به شمسی‌اول اصلاح شد (قبلاً میلادی اول بود).
- **پنج باکس RTL** با آیکون وکتور، **طلایی فقط روی زمان نماز فعلی**، `Bold` برای آن یکی، و `65%` آلفا برای نمازهای گذشته (که همان‌جا `scaleAlpha` است، نه `withAlpha` — چون باید آلفای موجود را ضرب کند نه جایگزین).
- **تپ باکس = «خواندم»** با یک ✓ کوچک، کاملاً Kotlin-only.
- **کپسول پایین:** «تا اقامه نماز X · mm:ss» با `Chronometer` (خودتیک، بدون نیاز به رندر).
- **سه تیر (small / medium / large)** با `PrayerWidgetBudget.metrics`؛ تیر large یک آیهٔ روزانه اضافه می‌کند (`Ayah()`), و `LARGE_MIN_HEIGHT_DP = 300f`.
- **RTL:** `android:supportsRtl="true"` در مانیفست + پدینگ منطقی `start/end` (نه `left/right`).

## مرحله ۶ — دیزاین ویجت تسبیح

- نام ذکر ۱۸sp، دو پیل («ذکر X از N» و «امروز M»).
- حلقهٔ پیشرفت با شمارش **داخل** حلقه و بَج «از ۱۰۰».
- سه دکمهٔ ≥48dp با آیکون وکتور (`widget_ic_prev/next/reset`) که با `WidgetArt.tintedIcon` رنگ می‌گیرند (بیت‌مپ کوچک کش‌شده، نه بیت‌مپ بزرگ در RemoteViews).
- حلقه = **+1**؛ لرزش ۱۸ms در هر تپ و لرزش دوتایی (`createWaveform([0,22,70,22])`) + ✓ در پایان دور.
- تپ بعد از پایان دور، خودکار به ذکر بعدی می‌رود (اگر `tasbih_auto_advance` روشن باشد)، و شمارندهٔ روزانه در نیمه‌شب صفر می‌شود.

**قواعد فنی‌ای که رعایت شد:** بدون gradient و بدون shadow (Glance ندارد) → `ColorProvider` + `cornerRadius`؛ فونت سفارشی در RemoteViews غیرقابل‌اعتماد → فونت سیستم + monospace برای ارقام؛ فقط آیکون وکتور.

---

## ۷) مرحله ۷ — پاک‌سازی

- `initialLayout` هر دو ویجت به `widget_placeholder_prayer.xml` / `widget_placeholder_tasbih.xml` رفت — **layout صرفاً فریم‌ورک، بدون تیک، بدون receiver**. قبلاً به `widget_live_clock.xml` اشاره می‌کرد؛ یعنی `LatinClockView` داخل پروسهٔ **لانچر** inflate می‌شد و یک تیکر و یک receiver دائمی آن‌جا جا می‌گذاشت (و روی hostهایی که view سفارشی تودرتو را قبول نمی‌کنند، همان مسیر «couldn't load widget»).
- `WidgetRepository`: `Snapshot`، `readSnapshot`، `readStyle`، `readStringList` (~۷۰۰۰ کاراکتر کد مرده) حذف شد.
- `MainActivity`: `registerWidgetRefreshReceiver()` و فیلدش حذف شد — این همان تیک `ACTION_TIME_TICK` تکراری بود که با آلارم مرزی دو composition هم‌زمان می‌ساخت (باگ B5).
- `TasbihGlanceWidgetReceiver`: `ACTION_SAFETY_REFRESH`, `SAFETY_REQUEST_CODE`, `EXTRA_TAP_SEQ`, `cancelSafetyRefresh`, `updateAllAwait` حذف شدند.
- **گیت کیفیت:** دو ممنوعیت مطلق (`AndroidRemoteViews` در هر فایل ویجت، و `actionRunCallback`) تبدیل شدند به **قواعد مهار**: `AndroidRemoteViews` فقط در `WidgetLiveLeaves.kt` مجاز است و آن فایل باید `KEY_LIVE_LEAVES` را ذکر کند و آن کلید باید در `WidgetPrefs.kt` وجود داشته باشد. درسِ گوشی MIUI (یک دروازه، پشت پرچم) حفظ شد، بدون اینکه معماری مورد نظر شما غیرقابل‌کامپایل شود. به‌علاوه ۵ چک جدید اضافه شد: ثبت `TasbihActionActivity`، استفادهٔ `TasbihGlanceWidget.kt` از `actionSendBroadcast` **و** `useActivityTaps`، نگه‌داشتن `setInexactRepeating`/`MINUTE_BACKSTOP_REQUEST_CODE` در `PrayerWidget.kt` **و** گیت‌شدنش روی `liveLeaves`، و نبودِ `recomputeTimesIfStale` در `PrayerGlanceWidget.kt`.

---

## ۸) فایل‌ها

**جدید (Kotlin)**
```
widget/WidgetPrefs.kt          ← قرارداد prefs + payload امروز/فردا + نشان‌ها
widget/WidgetTiming.kt         ← کرنومتر TW_TIMING (مرحله ۰)
widget/WidgetLiveLeaves.kt     ← تنها دروازهٔ AndroidRemoteViews (TextClock/Chronometer چارچوب)
widget/WidgetRefreshWorker.kt  ← backstop ۱۵ دقیقه‌ای
widget/WidgetRender.kt         ← تنها مسیر رندر برای هر فراخوانِ غیرسیستمی (ویجت نماز)
widget/WidgetFormatting.kt     ← قالب‌بندی ASCII-pinned برای مسیر بیکد
widget/TasbihNativeViews.kt    ← کارت تسبیح به‌صورت RemoteViews دست‌ساز: full و partial
```

**حذف‌شده (Kotlin)**
```
widget/LatinWidgetViews.kt        ← برگ سفارشی @RemoteViews.RemoteView؛ MIUI بی‌صدا ردش کرد
test/.../LatinWidgetViewsTest.kt
widget/TasbihGlanceWidget.kt      ← Glance در هر پروسه یک‌بار compose می‌کند؛ جایگزین: TasbihNativeViews
```

**جدید (منابع/تست)**
```
res/layout/widget_tasbih_native.xml   ← چیدمان دست‌ساز کارت تسبیح
res/drawable/widget_tasbih_pill.xml · widget_tasbih_chip.xml · widget_tasbih_badge.xml
res/layout/widget_placeholder_prayer.xml
res/layout/widget_placeholder_tasbih.xml
res/drawable/widget_ic_prev.xml · widget_ic_next.xml · widget_ic_reset.xml · widget_ic_check.xml
test/.../WidgetPrefsTest.kt    ← ۱۱ تست روی قرارداد prefs
test/.../WidgetFormattingTest.kt ← ۳ تست: ارقام ASCII زیر locale پیش‌فرض ar-EG، fallback الگوی خراب
docs/WIDGETS_MIGRATION_2026-10-26.md (همین فایل)
```

**تغییر‌یافته (Kotlin)**
```
PrayerGlanceWidget.kt          ← بازنویسی کامل سه تیر + طلایی‌فقط-زمان + تپ «خواندم» + noteComposed
PrayerWidget.kt                ← onUpdate: recompute → super → rearmAll؛ ACTION_MARK_READ؛ ACTION_SAFE_MODE؛ گیت دقیقه‌تیک
PrayerWidgetModel.kt           ← خواندن payload؛ currentIndex/markedIndices/isPast
PrayerWidgetViews.kt           ← countdown با فجر فردا
PrayerWidgetBudget.kt          ← تیر large + باند آیه
TasbihGlanceWidgetReceiver.kt  ← بازنویسی به AppWidgetProvider ساده (نام کلاس عمداً حفظ شد) + full/partial
TasbihTapEngine.kt             ← synchronized + auto-advance + لرزش؛ صف رندر و heal repaint حذف شد
TasbihActionActivity.kt        ← فقط fallback؛ رندر همگام جای join روی صف
TasbihWidgetModel.kt · WidgetArt.kt · WidgetTheme.kt · WidgetTokens.kt · WidgetRepository.kt
MainActivity.kt                ← حذف refresh receiver؛ + getPrayerMarks / drainPrayerMarks؛
                                 + getWidgetCompatibility / setWidgetCompatibility (سوییچ حالت سازگاری)
core/BootReceiver.kt           ← + WidgetRefreshWorker.schedule؛ goAsync نال‌پذیر
core/RolloverReceiver.kt       ← goAsync نال‌پذیر
AndroidManifest.xml            ← supportsRtl؛ توضیح fallback بودن Activity
res/layout/widget_live_clock.xml · widget_live_countdown.xml   ← TextClock / Chronometer چارچوب
res/xml/widget_prayer_info.xml · widget_tasbih_info.xml
```

**تغییر‌یافته (Flutter)**
```
lib/features/home/domain/entities/widget_snapshot.dart  ← ۴ کانال ARGB + prayerTimesJson
lib/features/home/services/widget_bridge.dart           ← getPrayerMarks / drainPrayerMarks
                                                          + getCompatibilityMode / setCompatibilityMode
lib/features/home/services/widget_sync.dart             ← همان دو، به‌صورت wrapper
                                                          + getCompatibilityMode / setCompatibilityMode
lib/shared/services/widget_sync_service.dart            ← _timesPayload، _paletteArgb، reconcilePrayerMarksFromWidget
lib/features/settings/presentation/screens/widget_settings_screen.dart
                                                        ← ردیف SwitchTile «حالت سازگاری» (تب نماز)
test/features/settings/presentation/screens/widget_settings_screen_test.dart
                                                        ← ۳ تست: نوشتن سوییچ، سوییچ بی‌اثر وقتی مقدار نرسیده، فقط تب نماز
test/features/settings/presentation/pages/settings_highlight_test.dart
                                                        ← استاب‌ها دو متد جدید را override می‌کنند (وگرنه کانال جواب نمی‌دهد)
tools/widget_tap_latency.py                             ← سنجش قاب‌به‌قاب بازرندر روی کلیپ screenrecord
tools/quality_check.py                                  ← دو ممنوعیت → قواعد مهار + ۵ چک جدید
test/features/home/domain/entities/widget_snapshot_test.dart
```

---

## ۹) تست

`./gradlew :app:testDebugUnitTest` → **۱۲۱ تست، ۰ شکست، ۰ خطا** (از `build/app/test-results/testDebugUnitTest/*.xml` شمرده شد). عدد قبلی ۱۲۴ بود؛ با حذف `LatinWidgetViewsTest` (−۳) و اضافه‌شدن `WidgetFormattingTest` (+۳) و بازنویسی تست live-leaves، به ۱۲۱ رسید.

| فایل | تست | چه چیزی را قفل می‌کند |
|---|---|---|
| `WidgetPrefsTest` | ۱۱ | round-trip امروز+فردا، فقدان فردا → فجر امروز، payload خراب → EMPTY، نشان مخصوص روز خودش، نشان دیروز نادیده، **ack فقط آنچه اپ نوشت**، **ack تاریخ دیگر به امروز دست نمی‌زند**، live-leaves پیش‌فرض روشن + **سوییچ دوطرفه با `setLiveLeaves`**، تحویل broadcast پیش‌فرض (`_v2`) |
| `WidgetFormattingTest` | ۳ | ارقام ASCII حتی زیر locale پیش‌فرض `ar-EG`، قالب شمارش معکوس، fallback الگوی خراب |
| `TasbihTapPathTest` | ۱۳ | پایان دور → تحویل به ذکر بعد؛ خاموش‌کردن auto-advance؛ (تست‌های `tapSeq`/safety-heal که مکانیزمش حذف شد، حذف شدند) |
| `PrayerWidgetModelTest` / `BudgetTest` / `CountdownTest` / `BoundaryClockTest` | ۳۲ | مدل، بودجهٔ سه تیر، شمارش معکوس، ساعت مرزی |

`flutter test` در این محیط اجرا نشد — `flutter_tester` نمی‌تواند WebSocket بگیرد (`Invalid WebSocket upgrade request`, اثر پراکسی محیط). تست‌های Dart تغییر نکرده‌اند جز دو assertion اضافه در `widget_snapshot_test.dart` که فقط کلیدهای جدید را چک می‌کنند.

---

## ۱۰) اندازه‌گیری — روی دستگاه واقعی

دستگاه: **POCO X7 Pro، اندروید ۱۶ (SDK 36)، HyperOS V816**، لانچر `com.mi.android.globallauncher`، ویجت‌ها با id `223` (نماز) و `224` (تسبیح)، صفحهٔ ۱۲۲۰×۲۷۱۲ در ۵۲۰dpi. نصب با `adb install -r` روی یک APK یونیورسال (`2_000_015_020`، بند ۱۰٫۱٫۶) — پیش از این روی split `arm64-v8a` نصب می‌شد.

```bash
adb logcat -c && adb logcat -s TW_TIMING
adb shell am broadcast -a com.tawheeed.TASBIH_INCREMENT \
    -p com.islamic.tawheeed -n com.islamic.tawheeed/.widget.TasbihGlanceWidgetReceiver
```

> نکته: `-p com.islamic.tawheeed` اجباری است. گیرنده بستهٔ فرستنده را چک می‌کند
> (`intent.package == packageName`) تا اپ دیگری نتواند شمارنده را دستکاری کند؛
> بدون آن لاگ `dropped foreign tasbih broadcast from: null` می‌آید و تپ اعمال نمی‌شود.

| سنجه | خط لاگ | هدف | اندازه‌گیری‌شده |
|---|---|---|---|
| تپ گرم تسبیح (۵ تپ پشت‌سرهم) | `tap.prefs.committed` → `tap.render.done` | < ۲۰۰ms | **+۴، +۸، +۴، +۷، +۶ ms** (render ۱۹/۲/۲/۳ ms) |
| تپ گرم تسبیح — پس از خروج از Glance | همان | < ۲۰۰ms | **commit +۲..+۵ms، render.done +۶..+۱۲ms** (۷ تپ) |
| **تپ به صفحه می‌رسد؟ (قاب‌به‌قاب)** | `screenrecord --bugreport` + `signalstats` روی برشِ ارقام | هر تپ = یک بازرندر | **۷ تپ → ۷ تغییر؛ فاصله‌ها ۹۴۰/۸۶۱/۷۹۵/۷۹۷/۸۵۰/۸۴۲ms در برابر ۹۳۵/۸۵۱/۷۷۹/۸۱۱/۸۴۵/۸۴۶ms تپ‌ها — بدون دریفت تجمعی** |
| شمارندهٔ نمایش‌داده‌شده = ذخیره‌شده | اسکرین‌شات پس از ۱۰ تپ | برابر | **۱۱ → ۲۱ و ۱۴ روی کارت، دقیقاً برابر prefs** |
| تپ سرد | `process.ready origin=…` سپس `tap.render.done` | تفکیک دو عدد | پروسه در حال اجرا بود؛ تپ سرد اندازه‌گیری نشد |
| تپ نماز «خواندم» | `tap.prefs.committed` → `tap.render.done` | < ۲۰۰ms | **+۱ms → +۶ms** (و `onWidgetUpdate` در لانچر) |
| رندر مرزی (refresh) | `prayer.render.done` | < ۵۰۰ms | **+۲۱ms**، و `provideGlance live=true` ۲۱۰ms بعد |
| دقت ساعت پس از ۳۰ دقیقه | چشمی | ۰ ثانیه اختلاف | **۱۱:۳۸ → ۱۱:۳۹** در ۳۳ ثانیه؛ `TextClock` خودتیک |
| شمارش معکوس پس از ۳۰ دقیقه | چشمی | زنده (نه یخ‌زده) | **۵:۰۵:۳۸ → ۵:۰۳:۲۳** در ۳۳ ثانیه؛ `Chronometer` زنده |
| حرکت طلایی در اذان | `prayer.render.done origin=…` | ≤ ۵s بعد از اذان | آلارم‌ها مسلح می‌شوند (`Armed 2 boundary refresh alarms`)؛ خودِ لحظهٔ اذان دیده نشد |
| ری‌بوت | `prayer.render.done origin=refreshAll` | کارت درست، بدون باز کردن اپ | اندازه‌گیری نشد |
| تغییر منطقهٔ زمانی | همان | کارت بازسازی شود | اندازه‌گیری نشد |
| Battery Saver / Doze | — | طلایی حداکثر ۱۵ دقیقه عقب | اندازه‌گیری نشد |
| کرش هنگام رندر | `logcat -b crash` | صفر | **صفر** — پیش از اصلاح ۱۰۰٪ بازتولیدپذیر بود |
| پروسهٔ سرد تا آمادهٔ رندر | `process.ready origin=…provideGlance` | < ۱s | **+۳۱۸ms** (نماز) و **+۴۲۳ms** (تسبیح) بعد از `force-stop` |

عدد «۳۰ ثانیه» گزارش اولیه در مسیر رندر بازتولید نشد: بدترین حالت اندازه‌گیری‌شده
**۲۴ میلی‌ثانیه** بود. چیزی که کاربر به‌عنوان کندی حس می‌کرد، رندر نبود؛
پروسهٔ سرد + کرش‌های تکراری بود (بند ۱۱٫۱).

**دربارهٔ سطر «قاب‌به‌قاب» — چه چیزی را ثابت می‌کند و چه چیزی را نه.** عدد مطلقِ
تأخیر را این روش نمی‌دهد: `screenrecord` فریم را فقط وقتی می‌نویسد که صفحه عوض شود،
و در این کلیپ ۳۷ فریم در ۱۴٫۳ ثانیه یعنی حدود یک فریم هر ۴۰۰ms بود؛ پس تأخیر
دیداری فقط تا حدود یک فریم (۴۰۰ms) محدود می‌شود، نه بیشتر. چیزی که *دقیقاً*
اندازه‌گیری می‌شود **دریفت** است: اگر لانچر عقب می‌افتاد یا صفی می‌ساخت، فاصلهٔ
تغییرها از فاصلهٔ تپ‌ها کم‌کم عقب می‌ماند. نماند — مجموع اختلاف در ۷ تپ در
±۱۶ms ماند، که همان جیتر زمان‌مهر فریم است. یعنی هر تپ **قبل از رسیدن تپ بعدی**
روی صفحه است.

عدد مطلق را از `tap.render.done` داریم که فقط **dispatch** را می‌سنجد (۶ تا ۱۲ms)
و در بند ۱۰٫۱٫۳ توضیح داده شد چرا عدد قبلی «۴ تا ۲۴ms» گمراه‌کننده بود: کارت
یخ‌زده بود، پس رندر سریع بی‌معنی بود. حالا که یخ‌زدگی رفع شده، همان عدد معنی دارد.

ابزار این اندازه‌گیری به‌صورت اسکریپت در مخزن است:
`tools/widget_tap_latency.py` (برشِ ناحیه + `scene`/`signalstats` روی کلیپ
`--bugreport`).

---

## ۱۰٫۱) سه نقص واقعی که روی گوشی پیدا و برطرف شد

### ۱. کرش حلقه‌ای هر ۶ ثانیه (`PendingResult` نال)

```
java.lang.NullPointerException: Attempt to invoke virtual method
'void android.content.BroadcastReceiver$PendingResult.finish()' on a null object reference
    at iw.invokeSuspend(SourceFile:81)
```

سه پروسهٔ پیاپی، هر ۶ ثانیه یکی. علت با `dexdump` روی APK نصب‌شده پیدا شد:
کلاس `Liw;` لامبدای `launchBroadcast` خودِ **Glance** است
(`const-string "Error thrown when trying to finish broadcast"`، تگ `GlanceAppWidget`).
`GlanceAppWidgetReceiver.onUpdate` بدنهٔ کار را در `launchBroadcast(this, …)` می‌پیچد
که با `goAsync()` شروع می‌شود؛ و `goAsync()` فقط وقتی PendingResult می‌دهد که
فریم‌ورک در حال dispatch به همان نمونه باشد.

اصلاح اول این پروژه (`WidgetRender` که `receiver.onUpdate(...)` را روی یک نمونهٔ
تازه صدا می‌زد) دقیقاً همین را می‌ساخت: `goAsync()` نال برمی‌گشت، Glance فقط
`IllegalStateException` را می‌گیرد، و NPE بقیهٔ مسیر را می‌کشت.

اصلاح نهایی: `GlanceAppWidget.update(context, AppWidgetId(id))` — API عمومی،
بدون گیرنده، بدون `goAsync`. `AppWidgetId` همان `GlanceId` عمومی است، پس نقشهٔ
DataStore هم دور زده می‌شود.

### ۲. `goAsync()` نال در گیرنده‌های خودمان

شش نقطه (`PrayerWidget` ×۲، `TasbihGlanceWidgetReceiver` ×۲، `BootReceiver`،
`RolloverReceiver`) به `val pending: BroadcastReceiver.PendingResult? = goAsync()`
با `try { pending?.finish() }` تبدیل شد. در `BootReceiver`/`RolloverReceiver` این
باگ بدتر بود: NPE روی ترد کارگر بعد از ری‌بوت، کل زنجیرهٔ reschedule را می‌کشت.

### ۳. ویجت تسبیح بعد از اولین رندر یخ می‌زد — Glance در هر پروسه یک‌بار compose می‌کند

**این همان «کلیک‌ها روان کار نمی‌کنند» بود، و تأخیر نبود: تپ اصلاً به صفحه
نمی‌رسید.**

با یک لاگ داخل `provideContent` اندازه‌گیری شد. چهار تپ، چهار `paint id=224`،
**یک** `compose`، و کارت روی شمارهٔ تپ اول ایستاد تا پروسه کشته شد:

```
I/TW_TIMING  tap.prefs.committed +2ms count=25 applied=true
I/TawheeedWidget  paint id=224 ok=1 instance(s)
I/TW_TIMING  tap.render.done +5ms
I/TW_TIMING  tap.prefs.committed +2ms count=26 applied=true
I/TawheeedWidget  paint id=224 ok=1 instance(s)
I/TW_TIMING  tap.render.done +5ms          ← و هیچ compose ای بعد از آن
```

یعنی `GlanceAppWidget.update()` روی سشنی که باز است، درخت کش‌شده را دوباره
اعمال می‌کند و `provideGlance` را هرگز دوباره صدا نمی‌زند. نوشتن
`updateAppWidgetState` + خواندن `currentState` (اصلاح دور قبل) این را عوض نکرد.

از دی‌کامپایل `androidx.glance:glance-appwidget:1.2.0` تأیید شد:

```
GlanceAppWidget.update(ctx, id)
  → getOrCreateAppWidgetSession(ctx, AppWidgetId(id), options, block)
      → block = GlanceAppWidget$update$4 → AppWidgetSession.updateGlance()
          → sendEvent(UpdateGlanceState)      // فقط یک رویداد به سشن
```

و `GlanceAppWidgetReceiver.onUpdate` هم همان `update()` را صدا می‌زند
(`doUpdate$2$1` → `GlanceAppWidget.update$glance_appwidget$default`)، پس فرستادن
`ACTION_APPWIDGET_UPDATE` به خودمان هم راه فرار نیست.

**اصلاح:** کارت تسبیح از Glance بیرون آمد و RemoteViews دست‌ساز شد —
`TasbihNativeViews` + `res/layout/widget_tasbih_native.xml`. یک تپ حالا:

```
prefs write  →  AppWidgetManager.partiallyUpdateAppWidget(id, partial)
             →  لانچر setterها را روی view موجود merge می‌کند (بدون inflate دوباره)
```

`partiallyUpdateAppWidget` فقط setterهایی را که صدا زده‌ایم اعمال می‌کند، پس
`partial()` عمداً سطح گرادیان، اندازه‌های تایپ و آیکون‌های قبلی/بعدی را شامل
نمی‌شود — هیچ‌کدام بعد از یک تپ عوض نمی‌شوند.

**پیلود هم اندازه‌گیری شد:** `dumpsys appwidget` برای همین کارت
`views_bitmap_memory=1004692` گزارش می‌کرد — یعنی هر apply حدود یک مگابایت
بیت‌مپ از بایندر رد می‌کرد تا یک عدد عوض شود. حلقه حالا حداکثر ۱۹۲px رندر
می‌شود (`WidgetArt.ring`)، چون دو کمانِ نرم بدون جزئیات مویی‌اند و بزرگ‌نمایی
لانچر دیده نمی‌شود: ۹۱۸KB → ~۱۴۷KB.

نام کلاس گیرنده عمداً عوض نشد (`TasbihGlanceWidgetReceiver`)، هرچند دیگر Glance
نیست: کامپوننت provider کلیدِ ویجتِ نصب‌شده روی صفحهٔ خانه است و تغییر نامش
کارتِ موجود را یتیم می‌کرد.

**هزینهٔ باقی‌مانده:** یک `full` render (سطح گرادیان ~۷۵۰KB) فقط روی
placement/resize/snapshot/watchdog اجرا می‌شود، نه روی تپ.

### ۴. خطای تایپ Dart که بیلد ریلیز را می‌شکست

هنگام بیلد، `compileFlutterBuildRelease` با این خطا رد شد:

```
lib/features/taraghib/presentation/screens/taraghib_matter_screen.dart:210:40:
Error: The argument type 'List<dynamic>' can't be assigned to the parameter
type 'List<Map<String, dynamic>>'.
```

علت: `para is int ? (_footnotesByPara[para] ?? const []) : const []` — شاخهٔ
`const []` بدون نوع است و کل ternary را `List<dynamic>` می‌کند، در حالی که
`InlineFootnotes.footnotes` نوع `List<Map<String, dynamic>>` می‌خواهد.
اصلاح: هر دو شاخه با `const <Map<String, dynamic>>[]` تایپ شدند.

این با ویجت‌ها ارتباطی ندارد، ولی **بیلد release را کامل بلاک می‌کرد** — یعنی
نسخهٔ قابل نصب وجود نداشت. چون بیلدهای قبلی از کش AOT استفاده می‌کردند، خطا
پنهان مانده بود.

### ۵. سوییچ «حالت سازگاری» در تنظیمات ویجت

> **منسوخ — ۲۰۲۶-۱۰-۳۰.** یک روز بعد، خودِ برگ‌های تیک‌زن حذف شدند (بند ۱۰٫۱٫۷)،
> پس این سوییچ چیزی برای سوییچ کردن نداشت و با `ACTION_SAFE_MODE` و
> `KEY_LIVE_LEAVES` پاک شد. این بند می‌ماند چون الگوی «یک مقدار ناشناخته = کنترل
> بی‌اثر، نه یک دروغ» در بقیهٔ صفحه‌ها هم استفاده می‌شود.

`ACTION_SAFE_MODE` تا امروز فقط از `adb shell am broadcast` در دسترس بود؛ برای
کاربر عادی یعنی هیچ. حالا یک ردیف در صفحهٔ تنظیمات ویجت است (فقط تب اوقات
نماز، چون کارت تسبیح دیگر Glance نیست و برگ زنده ندارد):

```
Flutter: SwitchTile «حالت سازگاری»
  → MethodChannel com.tawheeed/widgets · setWidgetCompatibility {compatibilityMode}
      → WidgetPrefs.setLiveLeaves(prefs, !compatibilityMode)
      → WidgetHub.refreshAll(ctx)      // هر نمونهٔ نصب‌شده دوباره رندر می‌شود
```

- `getWidgetCompatibility` مقدار را به‌صورت `{compatibilityMode, tapDelivery}`
  برمی‌گرداند. تا وقتی جواب نرسیده سوییچ **بی‌اثر** رندر می‌شود
  (`SwitchTile.onChanged == null`) تا هیچ‌وقت حالتی را نشان ندهد که ویجت ندارد.
- `_compatBusy` جلوی تپ دوم در میانهٔ نوشتن را می‌گیرد، و اگر کانال خطا بدهد
  سوییچ به مقدار قبلی برمی‌گردد.
- متن زیرنویس خودش وضعیت را می‌گوید، نه نام فنی را: «ساعت و شمارش معکوس خودکار
  تیک می‌خورند» در برابر «ساعت هر دقیقه از اپ به‌روز می‌شود».

**آنچه عوض نشد:** برگ زنده در `res/layout/widget_live_*.xml` دست‌نخورده ماند.
سوییچ فقط انتخاب می‌کند کدام مسیر رندر استفاده شود.

### ۶. اسپلیت arm64 اصلاً APK نبود — و نسخه‌ها قفل شده بودند

هنگام نصب، دو نقص مستقل بیرون آمد که هر دو ربطی به ویجت نداشتند ولی **نصب نسخهٔ
جدید را غیرممکن می‌کردند**:

```
$ adb install -r app-arm64-v8a-release.apk
Failure [INSTALL_PARSE_FAILED_UNEXPECTED_EXCEPTION: Failed to parse
         /data/app/.../base.apk: AndroidManifest.xml]

$ aapt2 dump badging app-arm64-v8a-release.apk
error: could not identify format of APK.
```

**الف) اسپلیت arm64 روی AGP 9.1.1 ناقص ساخته می‌شود.** فایل یک zip سالم است
(`unzip -t` بدون خطا) ولی فقط ۳۳۹ ورودی دارد و در آن **نه `AndroidManifest.xml`
هست، نه `resources.arsc`، نه `res/`** — یعنی dex + libs + assets بدون منابع.
از همان اجرا، اسپلیت armeabi (۱۸۰۳ ورودی) و APK یونیورسال (۱۸۱۰ ورودی) سالم‌اند،
پس نقص مخصوص خروجی arm64 است؛ یعنی همان ABI که تقریباً هر گوشی واقعی می‌خواهد.
یعنی هر کاربر arm64 یک فایل غیرقابل‌نصب می‌گرفت.

**ب) قفل نسخه.** اسپلیت‌ها کد `base+1000`/`base+2000` می‌گرفتند
(`2_000_013_020` / `2_000_014_020`) ولی APK یونیورسال فقط `base`
(`2_000_012_020`) داشت. پس دستگاهی که یک‌بار اسپلیت نصب کرده باشد **هرگز** نمی‌تواند
یونیورسال را نصب کند:

```
Failure [INSTALL_FAILED_VERSION_DOWNGRADE: Update version code 2000012020
         is older than current 2000014020]
```

و `adb install -d` هم کمکی نمی‌کند چون `-d` فقط برای بستهٔ **debuggable** مجاز است.
برای کاربر واقعی این یعنی «بسته نامعتبر» بدون راه خروج جز حذف اپ و از دست دادن
داده. کامنت قدیمی `build.gradle.kts` دقیقاً همین را نوشته بود که با `-d` حل
می‌شود — که غلط است.

**اصلاح:**

1. `splits.abi.isEnable = false` — یک خروجی، همان APK یونیورسال. `ndk.abiFilters`
   از قبل فقط `armeabi-v7a` + `arm64-v8a` را نگه می‌دارد، پس این کار **پشتیبانی**
   را کم نمی‌کند، فقط حجم را بالا می‌برد (۵۲MB به‌جای ۳۲MB — هنوز زیر سقف ۷۲MB در CI).
2. `SHIPPED_VERSION_CODE = FROZEN_VERSION_CODE + 3_000` = `2_000_015_020`، بالاتر از
   هر کدی که در دنیای واقعی نصب شده (`base+2000`). **ثابت `FROZEN_VERSION_CODE`
   دست نخورد** — قانون «فقط ۱..۱۰ و فقط موقع انتشار» محفوظ ماند؛ این آفست یک
   اصلاح یک‌باره برای کدهای نشت‌کردهٔ اسپلیت است.
3. `ci.yml` دیگر `--split-per-abi` نمی‌سازد.
4. `test/android/version_code_scheme_test.dart` سه انتظار جدید دارد: کد ارسالی
   باید از `+2000` بیشتر باشد، مقدارش `2_000_015_020`، و اسپلیت‌ها خاموش بمانند.

درس کلی: با دو نوع آرتیفکت، همیشه یکی هست که بعضی نصب‌ها نمی‌توانند بگیرند.
یک آرتیفکت، یک کد، بدون قفل.

---

### ۷. تیک زدن حذف شد، ساعت بزرگ‌تر شد، و فونتِ خودِ اپ

درخواست: «تیک زدن اوقات را کاملا حذف کنید زیرا خیلی ضعیف عمل میکند … تا اذان
عصر و ساعت یک سایز باشند و وسط قرار بگیرند … ساعت لاتین باشد … فونت‌ها کالیبری
مثل فونت تعیین شده در برنامه … ساعت بزرگ‌تر شود و برود بالاتر بدون اینکه تاثیر
بگذارد بر بوکس‌های پایین».

**الف) برگ‌های تیک‌زن حذف شدند.** `WidgetLiveLeaves.kt` و
`widget_live_clock.xml` / `widget_live_countdown.xml` پاک شدند. سه دلیل، هر سه
اندازه‌گیری‌شده:

1. `TextClock`/`Chronometer` ارقام را با locale **لانچر** می‌سازند، نه اپ — پس
   روی دستگاه `fa`/`ar` ساعت فارسی می‌شد در حالی که بقیهٔ اپ لاتین است.
2. `Chronometer` در صفر **بی‌صدا** می‌ایستد و به کسی خبر نمی‌دهد؛ پس روی
   دستگاهی که `SCHEDULE_EXACT_ALARM` رد شده، طلایی می‌توانست عقب بیفتد.
3. برگ زنده و رشتهٔ بیکد می‌توانستند یک دقیقه با هم اختلاف داشته باشند، چون
   یکی در پروسهٔ لانچر تیک می‌خورد و دیگری در لحظهٔ composition ساخته می‌شد.

حالا `formatClockTime` / `formatCountdownMinutes` (با `Locale.US`) تنها مسیرند،
و `PrayerWidget.rearmAll` **همیشه** دقیقه‌تیک را مسلح می‌کند. `ACTION_SAFE_MODE`،
`KEY_LIVE_LEAVES` و سوییچ «حالت سازگاری» که دور قبل اضافه شده بود هم حذف شدند —
چیزی نمانده بود که سوییچ کند.

**ب) ساعت بزرگ‌تر و بالاتر، بدون دست زدن به بوکس‌ها.** سه عدد در
`PrayerWidgetBudget`:

| ثابت | قبل | بعد | چرا |
|---|---|---|---|
| `SLACK_DP` | ۲ | **۰** | همان هوایی که به ساعت داده نمی‌شد |
| `GAP_CLOCK_TOP_DP` | ۱ | **۰** | ساعت می‌رود بالاتر |
| `CLOCK_MAX_SP` | ۷۲ | **۹۶** | سقف قبلی روی سلول ۴×۳ هم فعال می‌شد |

بوکس‌ها **به‌طور ساختاری** دست‌نخورده‌اند: در این بودجه اول همهٔ باندهای دیگر
جمع می‌شوند و ساعت فقط آنچه مانده را می‌گیرد، پس سقف بزرگ‌تر هرگز باندها را از
لبهٔ سلول بیرون نمی‌برد. (تست `the clock is the biggest thing…` حالا فقط
**داخل** هر تیر monotonic است: در `LARGE_MIN_HEIGHT_DP` باند آیه ظاهر می‌شود و
طبق همان قاعده از سهم ساعت پرداخت می‌شود، پس یک پلهٔ کوچک رو به پایین در مرز تیر
طراحی است، نه نقص.)

**ج) شمارش معکوس هم‌اندازهٔ ساعت شد — تا جایی که جا می‌شود.** قبلاً ۱۴ تا ۱۷sp
ثابت بود در برابر ساعتی ۴۰ تا ۹۰sp؛ همین «دو تایپ متفاوت» به نظر می‌رسید.
شمارش معکوس یک **باند** است، پس نمی‌شود بعد از محاسبهٔ بودجه بزرگش کرد (ارتفاعش
از بوکس‌ها کم می‌شود و آنها را می‌بُرد). راه‌حل: `metrics()` یک
`countdownOverrideSp` گرفت و کارت **دو پاس** حساب می‌کند — پاس اول ساعت را
پیدا می‌کند، پاس دوم باندها را با `countdown = clock × 0.55` دوباره قیمت می‌زند:

```
سلول ۴×۲ (۱۷۴dp):  ساعت ۲۹.۴sp   شمارش ۱۹.۳sp
سلول ۴×۳ (۲۶۰dp):  ساعت ۵۲.۲sp   شمارش ۴۹.۸sp   ← عملاً یک سایز
```

یعنی روی سلولی که جا دارد، دقیقاً همان چیزی است که خواسته شد؛ روی سلول کوتاه
شمارش معکوس زیر ساعت می‌ماند چون برابر بودن واقعاً جا نمی‌شود (خط
«تا اذان عصر · ۵:۰۳:۲۳» در اندازهٔ ساعت از عرض ۴×۲ بیرون می‌زند). پیشوند هم
نسبت به مقدار گرفته می‌شود (`0.52 ×`) نه یک ۱۲sp ثابت.

**و یک واقعیت ریاضی که باید صریح گفته شود:** روی سلول ۴×۲ (۱۷۷dp، همان چیزی که
الان روی گوشی نصب است) «ساعت بزرگ‌تر» و «شمارش معکوس هم‌اندازه» با هم **جمع
نمی‌شوند**. ارتفاع ثابت است و باندها اول جمع می‌شوند:

```
clock = 51.3 − 39.8 × fraction        (۱۷۴dp، عرض ۲۵۰dp، fs=1)
fraction = 0.42 → ساعت ۳۴.۶sp، شمارش ۱۴.۷sp   (همان وضع قبلی)
fraction = 0.55 → ساعت ۲۹.۴sp، شمارش ۱۹.۳sp   (وضع فعلی)
```

یعنی هر sp که به شمارش معکوس داده شود از ساعت کم می‌شود. انتخاب فعلی `0.55` است
چون شکایت اصلی «دو تایپ متفاوت» بود. **یک ردیف بلندتر (۴×۳) هر دو را می‌دهد**:
ساعت ۵۲sp و شمارش ۵۰sp — همان چیزی که خواسته شد. اگر کاربر ساعتِ بزرگ‌تر
می‌خواهد، راهش کشیدن ویجت یک ردیف بلندتر است، نه تغییر نسبت.

(یک بار باند «أذّن/جمعه» حذف شد تا ۲۱dp آزاد شود و ساعت روی همان ۴×۲ بزرگ‌تر
شود؛ برگردانده شد: آن ردیف بج فاز و شهر را حمل می‌کند و حذف اطلاعات برای
بزرگ‌کردن یک عدد معاملهٔ بدی است.)

**د) عدد تسبیح از حلقه اندازه می‌گیرد، نه از سلول.** با بالا بردن عدد به ۴۶sp،
روی همین گوشی رقم به خطِ حلقه چسبید (اسکرین‌شات ۲۰۲۶-۱۰-۳۰). ریشه عمیق‌تر بود:
لاگ نشان داد `box=119dp` ولی حلقه روی صفحه ~۳۶dp رندر می‌شد — یعنی
`setViewLayoutWidth(id, dp, 0)` که مستنداتش می‌گوید dp، روی این لانچر مقدار را
**پیکسل** می‌گیرد. جای حدس‌زدن دربارهٔ واحد، مالکیت اندازه به بیت‌مپ داده شد:

```xml
<ImageView android:id="@+id/tasbih_ring"
           android:layout_width="wrap_content" ... />
```

```kotlin
// metrics()
val ringPx  = (boxDp * density).toInt().coerceIn(96, 256)   // بیت‌مپ = جعبه
val countSp = (ringPx * 0.30f).coerceIn(18f, 84f)           // لنگر عمودی، بر حسب sp

// bindState() — چون تعداد رقم‌ها هم مهم است
val byWidth = 0.64f * ringPx / (digits * 0.52f * density)    // ۰.۵۲em عرض هر رقم
sp = min(countSp, byWidth)
```

یک عدد، یک مالک. دو نکته که فقط روی دستگاه معلوم شد: تقسیم بر `density` در
`countSp` غلط بود (رقم ≈ ۲.۴ پیکسل به ازای هر sp، یعنی ۰.۷۴×sp×density)، و
اندازهٔ «فقط از حلقه» برای «۷» درست است ولی «۱۷» از دو طرف از کمان بیرون می‌زند
چون عرض دو رقم دو برابر ارتفاعشان است. سقف `WidgetArt.ring` هم از ۱۹۲ به ۲۵۶
رفت (حالا که بیت‌مپ اندازهٔ روی صفحه را هم تعیین می‌کند): ~۲۶۲KB در هر تپ، در
برابر ~۹۱۸KB طرح اولیه.

**ه) فونت کالیبری — روی تسبیح بله، روی نماز فعلاً نه.** این یک محدودیت واقعی
Glance است، نه انتخاب: با `javap` روی `glance-1.2.0` تأیید شد که

```
public androidx.glance.text.FontFamily(java.lang.String);
public final java.lang.String getFamily();
```

یعنی `FontFamily` فقط **نام یک خانوادهٔ سیستمی** را می‌گیرد و به
`Typeface.create(name, style)` می‌دهد؛ فونت داخل APK (`res/font` یا asset) با
این مسیر قابل ارجاع نیست. `FontFamily("Calibri")` هم روی اندروید به Roboto
برمی‌گردد چون چنین خانواده‌ای در سیستم ثبت نشده.

پس:

- **کارت تسبیح** که RemoteViews دست‌ساز است، حالا `@font/calibri` دارد
  (`assets/fonts/calibri.ttf` به `res/font/calibri.ttf` کپی شد؛ ۱.۶MB، و
  `android:fontFamily` در inflate با منابع **خودِ اپ** حل می‌شود). `monospace`
  برداشته شد و جایش `tnum` ماند، چون Calibri تناسبی است و بدون ارقام جدولی عدد
  با هر تپ می‌پرید.
- **کارت نماز** تا وقتی Glance است نمی‌تواند کالیبری بگیرد. برای اینکه بگیرد
  باید مثل تسبیح از Glance بیرون بیاید — که یک بازنویسی کامل کارت است، نه یک
  تنظیم. عمداً در همین دور انجام نشد تا کارتِ کارکنان خراب نشود.

**و) هر جای کارت تسبیح = یک تسبیح.** لیسنر افزایش از `tasbih_ring_box` به
`tasbih_root` منتقل شد. دکمه‌های قبلی/ریست/بعد فرزندِ clickable هستند و اول
لمس را می‌گیرند، پس رفتارشان عوض نشده. گزارش: «هرجای بوکس تسبیح کلیک کنم شماره
بیفتد، الان فقط روی شماره که می‌زنم کلیک می‌خورد».

**ز) پولیش تسبیح.** نام ذکر و عدد bold شدند، پدینگ افقی ۱۰dp، بج کمی
نزدیک‌تر، و همه با Calibri. (عدد عمداً روی ۴۰sp ماند — بند «د» بالا.)

**ح) یک باگ نهفته که همین حذف لو داد.** `res/xml-v31/widget_prayer_info.xml` و
`widget_tasbih_info.xml` هنوز `android:initialLayout="@layout/widget_live_clock"`
داشتند. تا وقتی آن layout وجود داشت، `aapt2` قبول می‌کرد و هیچ‌کس نمی‌فهمید که
کارتِ تازه‌گذاشته‌شده یک لحظه **ساعت** نشان می‌دهد (همان چیزی که کامنت خودِ
`widget_tasbih_info.xml` ادعا می‌کرد حل شده). با حذف layout، بیلد با
`resource layout/widget_live_clock not found` شکست و معلوم شد هر دو فایل v31
هیچ‌وقت به‌روز نشده بودند. حالا به `widget_placeholder_prayer` /
`widget_placeholder_tasbih` اشاره می‌کنند.

---

## ۱۱) مسائل باقی‌مانده

1. **چهار سنجه هنوز اندازه‌گیری نشده‌اند**: ری‌بوت، تغییر منطقهٔ زمانی، Battery Saver/Doze، و تپ سرد (پروسهٔ مرده). سه تای اول فقط با گذاشتن گوشی در آن وضعیت‌ها قابل اندازه‌گیری‌اند؛ جدول §۱۰ عمداً جای خالی‌شان را نگه داشته تا با عدد پر شود، نه با حدس.
2. **کارت نماز هنوز Glance است، و همین دو محدودیت می‌گذارد.** (الف) فونت
   کالیبری: `androidx.glance.text.FontFamily` فقط نام یک خانوادهٔ **سیستمی** را
   می‌گیرد (`javap` روی `glance-1.2.0`)، پس `@font/calibri` در آن مسیر قابل
   ارجاع نیست — بند ۱۰٫۱٫۷٫د. (ب) برگ تیک‌زن: حذف شد، ولی اگر روزی برگردد
   همان MIUI که `@RemoteViews.RemoteView` را بی‌صدا رد می‌کرد برمی‌گردد.
   بیرون آوردن این کارت از Glance (مثل تسبیح) هر دو را حل می‌کند و یک بازنویسی
   کامل است، نه یک تنظیم.
3. **ساعت و شمارش معکوس حالا به دقیقه‌تیک وابسته‌اند.** با حذف برگ زنده، تنها
   چیزی که کارت را جلو می‌برد `ACTION_MINUTE_REFRESH` است. اگر OEM آلارم‌ها را
   throttle کند، بدترین حالت `WidgetRefreshWorker` (۱۵ دقیقه) است. این هزینهٔ
   آگاهانهٔ حذف تیک است، و آلارم‌های مرزی + watchdog پوشش می‌دهند.
4. **در Doze سخت‌گیرانه، برجسته‌سازی طلایی می‌تواند عقب بیفتد.** ساعت و شمارش معکوس هم مثل بقیه به همان آلارم‌ها وابسته‌اند، و *اینکه کدام باکس طلایی است* از composition می‌آید؛ اگر آلارم مرزی throttle شود، تا اجرای backstop (۱۵ دقیقه) ممکن است طلایی روی نماز قبلی بماند. با صفحهٔ خاموش دیده نمی‌شود، ولی روی `SCHEDULE_EXACT_ALARM` ردشده یک نقص واقعی است.
5. **`Chronometer` در صفر می‌ایستد و خبر نمی‌دهد — این هم دلیل حذفش بود.** حالا شمارش معکوس رشته است و به صفر رسیدنش را آلارم مرزی می‌گیرد، نه خودِ ویو.
6. **هر تپ یک composition کامل بود — برای تسبیح حل شد.** Glance partial update ندارد؛ کارت تسبیح حالا RemoteViews دست‌ساز است و یک تپ فقط یک `partiallyUpdateAppWidget` می‌فرستد (بند ۱۰٫۱٫۳). ویجت نماز همچنان Glance است، ولی آن کارت روی تپ رندر نمی‌شود — فقط روی دقیقه/مرز/آلارم، که چند بار در روز است.
7. **فونت:** کارت تسبیح `@font/calibri` دارد (بند ۱۰٫۱٫۷٫د) و `monospace` را با `tnum` عوض کرد. کارت نماز تا وقتی Glance است فونت سفارشی نمی‌گیرد.
8. **`_paletteArgb` یک round-trip کانال به هر sync اضافه می‌کند** (فقط برای خواندن انتخاب پالت). ارزان است ولی صفر نیست.
9. **`WidgetRepository.readStringMap`** هنوز توسط `readPrayerStatuses` استفاده می‌شود — عمداً نگه داشته شد، مرده نیست.

---

## ۱۲) پیشنهاد بعدی

با گوشی وصل، ترتیب کار این شد و بقیه‌اش مانده: (۱) ✅ تپ تسبیح سرد و گرم، (۲) ✅ ۳۰ دقیقه رها کردن برای ساعت/شمارش، (۳) ⬜ ری‌بوت + تغییر منطقه، (۴) ⬜ Battery Saver، (۵) ⬜ بررسی «خواندم» تا رسیدن به tracker در اپ.

سه پیشنهاد بند قبل انجام شد؛ سرنوشت هرکدام:

1. ✅ **سوییچ «حالت سازگاری» در تنظیمات ویجت** — بند ۱۰٫۱٫۵. از `adb` به یک ردیف واقعی در UI تبدیل شد، با حالت «بی‌اثر تا وقتی مقدار خوانده نشده» تا هرگز دروغ نگوید.
2. ✅ **یکسان‌سازی ظاهر دو حالت** — بررسی شد و معلوم شد قرص شمارش معکوس و الگوی `format` و فونت `monospace` از قبل در هر دو شاخه یکی‌اند؛ تنها تفاوت ارقام locale است که با برگ چارچوبی قابل رفع نیست (بند ۱۱٫۳ بازنویسی شد). کاری که مانده بود انجام شده بود.
3. ✅ **پاک‌کردن `updateAll`** — جست‌وجو شد: هیچ فراخوانی واقعی در `android/app/src/main/kotlin` نمانده. تنها ارجاع‌ها **کامنت**های توضیحی در `WidgetRender.kt` و `PrayerWidget.kt` هستند که دقیقاً می‌گویند چرا نباید استفاده شود. کاری برای حذف نبود.

کارهای باقی‌مانده از فهرست بالا (۳ تا ۵) فقط با گذاشتن گوشی در آن وضعیت‌ها اندازه‌گیری می‌شوند؛ عددسازی نمی‌کنم.

**پیشنهاد بعدی، به ترتیب فایده:**

1. **بیرون آوردن کارت نماز از Glance** — همان کاری که برای تسبیح جواب داد. سه
   چیز را یک‌جا حل می‌کند: فونت کالیبری (که در Glance ممکن نیست، بند ۱۰٫۱٫۷٫د)،
   رندر تضمینی روی هر دقیقه‌تیک (بدون وابستگی به recompose)، و حذف آخرین
   `GlanceAppWidget` پروژه. هزینه‌اش یک بازنویسی کامل کارت است (۸۲۰ خط
   composition + بودجه + پنج باند)، پس در دوری جدا و با تست روی گوشی انجام شود.
2. **اندازه‌گیری چهار سنجهٔ باقی‌مانده** (ری‌بوت، تغییر منطقه، Battery Saver، تپ
   سرد) — هر کدام فقط با گذاشتن گوشی در آن وضعیت.

