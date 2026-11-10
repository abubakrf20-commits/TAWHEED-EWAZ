# Tawheed — Notification reliability

> **عکس تاریخ‌دار — Historical snapshot.** این سند وضعیت را در شاخه و تاریخ خودش ثبت
> می‌کند و خوانده‌شدنش به‌عنوان «وضعیت امروز» درست نیست. مرجع فعلی فقط `AGENTS.md`
> (ریشهٔ مخزن) و `docs/SECTIONS_1_9_0.md` است؛ فهرست کامل در `docs/README.md`.


Companion to `docs/AUDIT_REPORT.md` (finding F-*). How reminders survive time,
reboots, kills, OEM battery managers and Android's tightening alarm policy —
and what still **needs a real device** to prove. Branch `release/1.7.2`
(worktree `%TEMP%/opencode/merge-172`). Paths relative to that root. Android +
web only; there is **no `ios/` project** and no APNs/iOS-permission wiring.

---

## 1. Architecture

- **No** `android_alarm_manager` / `workmanager` pub packages. Timing is a
  hand-rolled **AndroidX WorkManager** bridge + native `setAlarmClock` via a
  MethodChannel (`pubspec.yaml:67` comment).
- `NotificationService` singleton (`notification_service.dart:28-34`), composed
  from `part` files: daily/period reminders, day scheduling, models
  (`NativeReminderInfo`), and a central ID map (`notification_ids.dart`).
- **Two delivery paths** decided in `_scheduleNotification` (`:1508-1589`):
  1. On Android every reminder is armed natively with `setAlarmClock`
     (`_scheduleNativeExactReminder:1627`, channel `com.tawheeed/exact_reminders`).
     The plugin is *not* trusted for timing because MIUI/HyperOS defer even
     `setExactAndAllowWhileIdle` (`:1539-1545`).
  2. If `SCHEDULE_EXACT_ALARM` isn't granted, the plugin's `zonedSchedule`
     (`inexactAllowWhileIdle`) is *also* armed — "a late reminder beats a missing
     one" (`:1564-1575`).

## 2. Reschedule fingerprint (the invariant to preserve)

`DailyNotificationScheduler._scheduleFingerprint(AppSettings)`
(`daily_notification_scheduler.dart:44-151`) joins ~60 inputs and is compared to
`lastScheduledFingerprint` in prefs (`needsRescheduling():153-156`). It keys on,
among others:

- today's date key, app timezone, and the **device zone** (`localTzName:77`) — so
  travel forces a rebuild;
- calc method, asr method, **`highLatitudeRule.index:83`** and
  **`elevationCorrection:84`** — AGENTS.md-protected: these change *computed*
  prayer times, so the 8-day queue must rebuild (`_applyElevationCorrection`
  fix `9137c6f` stays consistent);
- location/city/lat/lng, custom angles, every per-prayer/iqamah offset, and every
  reminder toggle/time.

The fingerprint is recorded **only at the end of a successful full pass** (`:419`);
a failed prayer-times pass deliberately does **not** record it (`:281-283`), so the
next boot retries. Even when unchanged, `_scheduleIfNeeded` re-runs the daily-content
window, azkar and today's queues every call (`:195-233`) so the 7-day window never
silently expires.

**Triggers:** cold boot/resume (`boot_coordinator.dart:394-425`), app start
(`main.dart:252-259`), WorkManager one-offs (`prayerSync`/`dailyRefresh`/
`azanCheck`/`hourlyNotifCheck` → `background_scheduler.dart:129-180`), settings
edits (`forceReschedule`), daily 00:00:15 rollover, and a denied→granted
exact-alarm transition (`boot_coordinator.dart:171-186`).

## 3. Persistence & recovery

- **Persist before arming**: `ExactReminderScheduler.persist()` (Kotlin, `:223-244`)
  writes each `rem_<id>` (trigger/title/body/channel/sound/payload/repeat) to
  prefs; adhan alarms persist to `prayer_alarms/scheduled_alarms`.
- **BOOT_COMPLETED**: `BootReceiver` (manifest `:173-188`) also handles
  `MY_PACKAGE_REPLACED`, `QUICKBOOT_POWERON`, `TIME_SET`, `TIMEZONE_CHANGED`,
  `SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED`; uses `goAsync()` to survive the
  10 s broadcast window, then `rescheduleEverything()`.
- **Re-arm semantics** (`rescheduleAllAfterBoot:103-139`): repeating reminders roll
  forward from the stored trigger; **one-shot reminders whose time passed are
  dropped, never fired late** (`:122-125`).
- **Self-healing daily chain**: `RolloverReceiver` (~00:00) re-arms itself,
  dedups double-fires within 6 h, restores both alarm registries, and enqueues
  `prayerSync`.
- **Stale-purge**: `schedulePrayerNotifications` (`:806-934`) cancels pending prayer
  ids whose wall-clock already passed (`:893-898`) — this is the missed-notification
  handling at reschedule time.
- **Tap across kill**: `com.tawheeed/notification_tap` warm-start + a
  `flutter.notification_payload` prefs stash for cold start (`MainActivity.kt:135-191`).

## 4. Reminder families (channel + id ranges)

| Family | Path | Ids | Channel |
|---|---|---|---|
| Adhan (audio, authoritative) | `native_prayer_alarm_service.dart` | `2000+day*100+idx` | per-prayer, `AdhanForegroundService` w/ MediaPlayer+wakelock fallback |
| Prayer reminders (silent) | `notification_service.dart:806-934` | 100-104 / 110-114 / 210-214 / `3000+…` | `prayer_times_v5` (silent by design) |
| Pre-adhan «N دقیقه قبل» | `notification_day_scheduling.dart:209-237` | 500-524 / `6000+…` | — |
| Post-prayer azkar | `notification_service.dart:939-988` | 120-124 / 300-304 | `azkar_reminder_v3` |
| Morning/evening azkar | `:1232-1316` | fixed 105/106 daily-repeat | Fajr+45 / Asr+60 unless manual |
| Khatm | `notification_daily_reminders.dart:363-413` | 404 daily-repeat | `khatm_reminder_v3` |
| Daily verse/hadith/dua | `_scheduleDailyContentWindow` | `7000/7400/7900 + dayOfYear`, 7-day one-shot | `daily_reminders_v3` |
| Quran / Friday / Kahf | — | 405 / 403 (weekly) / 406 (weekly) | `quran_/friday_reminder_v3` |
| Islamic events | `:1416-1443` | 410-430 | `islamic_events_v3` |
| Period | `notification_period_reminders.dart:25-80` | 600-603 | `period_reminders_v1` |
| Custom / tasks / goals / pomodoro | `reminder_provider.dart:184-272` | 1000-1999 / 10000-10999 / 12000-12949 / 7843 | `custom_reminders_v2` |

Full reserved map: `notification_ids.dart`.

## 5. Android policy caveats (the real failure modes)

- **Android 12+ `SCHEDULE_EXACT_ALARM`** declared; **`USE_EXACT_ALARM` deliberately
  NOT** (Play policy, manifest `:19-22`). Queried via
  `canScheduleExactNotifications` before every schedule.
- **Android 14 default-denied**: fresh installs get no grant, native arms fail
  *silently* — hence the inexact plugin fallback (`notification_service.dart:1558-1563`).
- **Grant-change recovery**: BootReceiver listens to
  `SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED` so an out-of-app grant re-arms all.
- **Prompt discipline**: `PermissionService.ensureExactAlarmPermission` has a 24 h
  cooldown and is **never** called from the (background) scheduling path
  (`_ensureExactForPostPrayer:280-293`); diagnostics fix button passes `force:true`.
- **POST_NOTIFICATIONS**: manifest `:25`; requested once per install in onboarding,
  not in `init()`. Native posting checks `areNotificationsEnabled()` and
  **silently drops** the notification if revoked (`NotificationHelper.kt:14-20`).
- **Doze/battery**: `setAlarmClock` is Doze-immune; `REQUEST_IGNORE_BATTERY_
  OPTIMIZATIONS` intentionally not declared — exemption surfaced in diagnostics.
  **Force-stop cancels ALL the app's alarms, even adhan** (diagnostics `:248-255`).
- **DND**: `isDndAccessGranted` gates silent mode (`daily_notification_scheduler.dart:401-417`).

## 6. Diagnostics (added this phase, `bc18c5e`)

`notification_diagnostics_screen.dart` re-runs six live checks on every resume
(notifications, exact alarm, battery optimisation, DND, location, GPS), each with a
«رفع» action. The new **armed-reminders card** calls
`NotificationService().armedReminders()` (`:1828`) → native
`ExactReminderScheduler.listReminders` → `List<NativeReminderInfo>`, answering
"what is actually on the OS alarm clock" — the key triage tool that distinguishes
"the phone swallowed a notification" from "it was never scheduled". A test adhan
(id 199) exercises both the Flutter and native `setAlarmClock` paths.

## 7. NEEDS DEVICE (cannot be proven off-hardware — F-1/F-4/F-5/F-6)

End-to-end timing under **Doze**, **OEM autostart** (Samsung/Xiaomi/Huawei),
**reboot recovery**, and **force-stop** must be validated on real hardware; the
code paths and in-app guidance exist and are unit-tested, but no Android device is
connected. Recommended on-device matrix: arm a +5-min exact reminder → kill app →
reboot → confirm it fires; repeat with battery-optimisation on/off and autostart
denied; check the armed-reminders card shows it before and after.

## 8. The 20-second post-launch stall (R1–R5, 2026-10-17)

Measured on device (`4XQCWGBQLVZXTOAE`, Android 16): after launch the UI thread was
saturated for ~14.5 s and scrolling lagged until it drained. The cause was **not**
rendering — it was reminder scheduling. One boot pass awaits ~328 individual
`setAlarmClock` round trips, and every one of them ran on the **Android main
thread**, because a `MethodChannel` handler executes there. The fixes:

- **R1 — one batch, off the main thread.** `NotificationService` now collects every
  native op (`arm`/`cancel`/`cancelRange`) inside `batchNativeReminders` and sends one
  `applyReminderOps` call with `opsJson`. `MainActivity` answers *every* reminders-channel
  method through `replyAsync` on a single FIFO `HandlerThread("reminder-alarms")`
  (`quitSafely()` in `onDestroy`), replying with `runOnUiThread`. Nesting is depth-counted:
  only the outermost exit flushes, and the exact-alarm grant is queried **once per batch**.
- **R2 — an arm that changes nothing costs nothing.** `ExactReminderScheduler.applyOps`
  compares the pending request field-by-field (`isArmCurrent`; `JSONObject` is
  HashMap-backed, so `toString()` cannot be the compare) and returns `"unchanged"`.
  Stamps are **boot-relative** (`armed_at >= bootTimeMillis(now)`, `ARM_FRESH_MS = 6h`) —
  a pre-reboot stamp is never "fresh". Only a **failed** arm purges its own id
  (`cancel(context, request.id)` on `ArmResult.Failed`); a pre-arm cancel was pure waste.
- **R3 — boot emitters coalesce.** At least five emitters call `scheduleIfNeeded` within
  ~0.5 s of launch. `_request` now buffers into a 1200 ms window and runs **one** pass with
  the *newest* service/settings; a `force` (an explicit user reschedule) flushes at once and
  cancels the waiting window, and a force queued behind a plain request still forces.
  The queue is serialised so passes cannot interleave.
- **R4 — the "nothing changed" branch stops re-arming.** The short-circuit path used to
  reconcile the whole daily queue on every boot emitter. It is throttled to
  `reconcileInterval` (2 min) keyed to the **schedule fingerprint** (`_markReconciled(fp)`),
  so a settings change still lands immediately — every notification-affecting input,
  including the calendar date, timezone, `highLatitudeRule`, elevation and each iqamah
  offset, is already inside that fingerprint. A future or corrupt stamp always counts as due.
- **R5 — a foreground app is not asked to rebuild twice.** `AppLiveness` (4 s mark) lets
  `MainActivity` skip writing `needs_reschedule` when the app is already up; the boot and
  rollover receivers keep stamping it and keep calling `rescheduleAllAfterBoot` +
  `scheduleDailyRollover`. This suppresses a **flag**, never an unschedule.

**Accuracy is the constraint here, not an afterthought.** No remedy can drop a reminder:
`setAlarmClock` replaces the `PendingIntent` for an id (keyed `ID_OFFSET + id` +
`FLAG_UPDATE_CURRENT`), so R2's skip only removes redundant binder traffic; a batch that
throws is retried **op by op** through the legacy `scheduleReminder`/`cancelReminder`/
`cancelRangeReminders` names, so one bad op cannot eat the rest; non-Android builds never
queue at all; and the past-time branch cancels the native exact reminder before returning,
so a stale alarm cannot double-fire.

Guards: `test/android/reminder_batch_test.dart` (19 cases — source scans of both sides,
R1–R5 each pinned) and `test/shared/services/daily_notification_scheduler_test.dart`
(10 cases — the coalescer's behaviour and the throttle's stamp table).
`ExactReminderOpsTest.kt` covers `decodeOps`/`isArmCurrent`/`prunePending` on the JVM.

**Test-harness landmine found while writing these.** `flutter_test` runs `setUp`
*outside* `AutomatedTestWidgetsFlutterBinding.runTest`'s FakeAsync zone. A singleton that
stores a pending future chain (`_scheduleQueue`) seeded in `setUp` therefore belongs to the
real zone; a pass chained onto it is delivered on the real microtask queue, which the fake
clock never flushes — the request stalls silently and the case hangs until the framework's
10-minute timeout. **Seed/re-set such a seam as the FIRST statement inside the test body**
(`begin()`), not in `setUp`. Note too that `resetCoalescingForTest()` clears `passOverride`,
so calling it after installing a stub wipes the stub. `--timeout=Ns` cannot rescue a
FakeAsync hang (that timer is fake too) — guard it shell-side.
