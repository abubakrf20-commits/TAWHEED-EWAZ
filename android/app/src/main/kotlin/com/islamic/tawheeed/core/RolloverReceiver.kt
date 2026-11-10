package com.islamic.tawheeed.core

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Self-healing daily heartbeat.
 *
 * Fires shortly after midnight every day and:
 *  1. Re-arms itself for the next midnight (so the chain continues even if the
 *     app is never opened and Android background work is deferred).
 *  2. Sets the `needs_reschedule` flag so any app/background run force-reschedules.
 *  3. Reschedules today's persisted native alarms (covers azan audio after boot).
 *  4. Wakes the Flutter background isolate through native AndroidX WorkManager
 *     so the new day's prayer times are recomputed and notifications re-armed.
 */
class RolloverReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "RolloverReceiver"
        private const val ACTION_ROLLOVER = "com.tawheeed.action.ROLLOVER"
        private const val SYNC_TASK = "prayerSync"
        private const val ROLLOVER_DEDUP_WINDOW_MS = 6L * 60 * 60 * 1000
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_ROLLOVER) return

        // goAsync: the reschedule chain touches persisted alarm JSON and
        // re-arms several alarms — give it the full broadcast window on a
        // background thread instead of risking a mid-flight process kill.
        //
        // Nullable on purpose: `goAsync()` only returns a PendingResult while
        // the framework is dispatching to this instance, and it has been seen
        // null on HyperOS 3. An unguarded `.finish()` is a NullPointerException
        // on the worker thread, which kills the process and breaks the daily
        // self-healing chain at exactly the moment it is needed.
        val pending: BroadcastReceiver.PendingResult? = goAsync()
        Thread {
            try {
                rescheduleAll(context)
            } finally {
                try {
                    pending?.finish()
                } catch (e: Throwable) {
                    Log.w(TAG, "PendingResult.finish() failed: ${e.message}")
                }
            }
        }.start()
    }

    private fun rescheduleAll(context: Context) {
        // Audit 4.5: dedup guard. BOOT_COMPLETED arrives shortly after the
        // device clock crosses midnight on some OEMs, and boot reschedule +
        // a rollover fired just before shutdown would run this twice within
        // minutes — double-notifying the daily content. Ignore repeats
        // within a 6-hour window; a genuine next-day rollover is 24h later.
        val prefs = context.getSharedPreferences("prayer_alarms", Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        val last = prefs.getLong("rollover_time", 0L)
        if (last > 0 && now - last < ROLLOVER_DEDUP_WINDOW_MS) {
            Log.i(TAG, "Rollover skipped — another fired ${now - last}ms ago")
            // Still re-arm the next alarm so the chain is not broken.
            PrayerAlarmScheduler.scheduleDailyRollover(
                context,
                PrayerAlarmScheduler.nextRolloverTime(),
            )
            return
        }

        Log.d(TAG, "Daily rollover fired — re-arming schedule")

        // The stamp tells a LATER run to rebuild from scratch. When the app is on
        // screen, that run is already happening — and the calendar date lives
        // inside the Dart reschedule fingerprint, so the new day forces a full
        // rebuild on its own without this flag. Skipping it here only avoids the
        // duplicate storm; everything below still re-arms exactly as before, so
        // an app that is NOT in the foreground loses nothing.
        if (AppLiveness.isForegroundNow(context)) {
            Log.i(TAG, "needs_reschedule not set — the app is on screen and reschedules itself")
        } else {
            prefs.edit().putBoolean("needs_reschedule", true).apply()
        }
        prefs.edit().putLong("rollover_time", now).apply()

        // 1. Reschedule any persisted native alarms (today's azan audio) AND re-arm
        // every native reminder (repeating ones roll forward to the next
        // occurrence, passed one-shots are dropped) so the daily azkar chain
        // survives even when the app is never opened at midnight.
        try {
            ExactAlarmHelper.rescheduleAllAfterBoot(context)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to reschedule persisted alarms: ${e.message}")
        }
        try {
            ExactReminderScheduler.rescheduleAllAfterBoot(context)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to reschedule native reminders: ${e.message}")
        }

        // 2. Re-arm the next rollover so the daily chain is self-perpetuating.
        PrayerAlarmScheduler.scheduleDailyRollover(
            context,
            PrayerAlarmScheduler.nextRolloverTime(),
        )

        // 3. Wake the same Dart callback through native AndroidX WorkManager.
        try {
            NativeBackgroundScheduler.enqueueOneOff(
                context,
                NativeBackgroundScheduler.TASK_PRAYER_SYNC,
                replace = true,
            )
            Log.d(TAG, "Enqueued $SYNC_TASK background sync")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to enqueue background sync: ${e.message}")
        }
    }
}
