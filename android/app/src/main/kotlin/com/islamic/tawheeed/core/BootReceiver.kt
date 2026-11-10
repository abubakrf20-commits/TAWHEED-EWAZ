package com.islamic.tawheeed.core

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.islamic.tawheeed.widget.WidgetHub

/**
 * Reschedules all prayer alarms after device reboot and refreshes the home-screen
 * widgets from the last persisted snapshot so they never show an empty/broken state.
 * Also triggered when the app is updated.
 */
class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED &&
            action != "android.intent.action.QUICKBOOT_POWERON" &&
            action != "android.intent.action.REBOOT" &&
            action != Intent.ACTION_TIME_CHANGED &&
            action != Intent.ACTION_TIMEZONE_CHANGED &&
            action != "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED") {
            return
        }

        // goAsync: the reschedule chain below touches SharedPreferences, JSON
        // alarm queues and widget rendering — all synchronous work that can
        // exceed the ~10s broadcast window on slow devices. Without goAsync
        // the system can kill the process mid-reschedule and alarms after a
        // reboot would be silently lost. Keep the work on a background thread
        // and finish() the PendingResult when done.
        //
        // Nullable on purpose: `goAsync()` only hands out a PendingResult while
        // the framework is actually dispatching to this instance, and it has
        // been observed returning null on HyperOS 3. An unguarded `.finish()`
        // there is a NullPointerException on the worker thread — the process
        // dies right after boot, taking the whole reschedule chain with it, and
        // the crash log points at a receiver whose own code never ran.
        val pending: BroadcastReceiver.PendingResult? = goAsync()
        Thread {
            try {
                rescheduleEverything(context, action)
            } finally {
                try {
                    pending?.finish()
                } catch (e: Throwable) {
                    Log.w(TAG, "PendingResult.finish() failed: ${e.message}")
                }
            }
        }.start()
    }

    private fun rescheduleEverything(context: Context, action: String?) {
        Log.d(TAG, "Boot/update/timezone received — rescheduling prayers & refreshing widgets")

        // Signal the Flutter side to reschedule — except for the plain boot-ish
        // actions when the app is demonstrably on screen right now: its own
        // scheduler is already mid-rebuild in that case, and the stamp only made
        // it arm the whole set a second time. A clock or timezone correction and
        // an exact-alarm grant change always set it, because those genuinely can
        // move every prayer time and must never be taken on the app's word.
        val prefs = context.getSharedPreferences("prayer_alarms", Context.MODE_PRIVATE)
        val bootOnly = action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            action == "android.intent.action.QUICKBOOT_POWERON" ||
            action == Intent.ACTION_REBOOT
        if (bootOnly && AppLiveness.isForegroundNow(context)) {
            Log.i(TAG, "needs_reschedule not set — the app is on screen and reschedules itself")
        } else {
            prefs.edit().putBoolean("needs_reschedule", true).apply()
        }
        prefs.edit().putLong("boot_time", System.currentTimeMillis()).apply()

        // Actually reschedule ANY persisted prayer alarms right now. The
        // returned count skips alarms that could only be armed inexact, so a
        // missing SCHEDULE_EXACT_ALARM grant is visible in the log.
        val armedExact = ExactAlarmHelper.rescheduleAllAfterBoot(context)
        Log.i(TAG, "Native alarms restored: $armedExact armed exactly")

        // Re-arm native exact reminders (Doze-immune fallback for reminders that
        // were armed with setAlarmClock because SCHEDULE_EXACT_ALARM was denied).
        // Native alarms are volatile across reboot, so without this they would be
        // lost until the app is opened.
        ExactReminderScheduler.rescheduleAllAfterBoot(context)

        // Re-arm the self-healing daily rollover (reboot clears it otherwise).
        PrayerAlarmScheduler.scheduleDailyRollover(
            context,
            PrayerAlarmScheduler.nextRolloverTime()
        )

        // Refresh all home-screen widgets from the persisted snapshot.
        try {
            // Guarantee style defaults survive a reboot/app-update even if the
            // app hasn't been opened since (see PrayerWidget.onUpdate). MIUI
            // re-binds the provider after boot and records any failure as
            // "couldn't load widget", so render with safe defaults.
            com.islamic.tawheeed.widget.WidgetTokens.init(context)
            WidgetHub.refreshAll(context)
            // The 15-minute WorkManager backstop. Reboot clears every alarm and
            // Doze (or a power-saving OEM) can swallow the boundary ones, so
            // this is the only tick that is still guaranteed to repaint the
            // cards — and it re-arms everything it touches.
            com.islamic.tawheeed.widget.WidgetRefreshWorker.schedule(context)
        } catch (e: Exception) {
            Log.w(TAG, "Widget refresh after boot failed: ${e.message}")
        }
    }
}
