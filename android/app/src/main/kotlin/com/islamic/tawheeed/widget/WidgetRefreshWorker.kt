package com.islamic.tawheeed.widget

import android.content.Context
import android.util.Log
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/**
 * The 15-minute backstop, and the only periodic signal the widgets have.
 *
 * It exists because the exact-alarm chain is the one part of this design the
 * OS can silently take away: `SCHEDULE_EXACT_ALARM` is denied by default from
 * Android 14, battery saver batches `setAndAllowWhileIdle`, and a revoked
 * permission cancels every armed alarm at once. Without a periodic floor the
 * card could show yesterday's dates until the app was opened.
 *
 * What it deliberately does NOT do is act as a clock tick. WorkManager's
 * minimum period is 15 minutes and Doze can stretch it, so using it to keep a
 * clock honest would be a guarantee of ±15 minutes. The clock and the
 * countdown tick themselves; this only makes sure the *data* behind them
 * (today's clocks, tomorrow's Fajr, the dates) and the alarm chain are still
 * there.
 */
class WidgetRefreshWorker(
    context: Context,
    params: WorkerParameters,
) : Worker(context, params) {

    override fun doWork(): Result {
        val context = applicationContext
        val startedAt = android.os.SystemClock.uptimeMillis()
        WidgetTiming.logProcessReady("worker")
        return try {
            WidgetTokens.init(context)
            // Recompute first: the render reads what this writes.
            WidgetRepository.recomputeTimesIfStale(context)
            WidgetHub.refreshAll(context)
            PrayerWidget().rearmAll(context)
            PrayerWidgetVertical().rearmAll(context)
            TasbihGlanceWidgetReceiver().rearmAll(context)
            WidgetTiming.mark("worker.done", startedAt, "backstop")
            Result.success()
        } catch (e: Throwable) {
            // Retrying is cheap and the next periodic run would happen anyway;
            // a failure here must never surface as a widget error.
            Log.e(TAG, "widget backstop failed: ${e.message}")
            Result.retry()
        }
    }

    companion object {
        private const val TAG = "WidgetWorker"

        /** Unique name — one periodic job for both widgets, never two. */
        const val WORK_NAME = "tawheeed-widget-refresh"

        /** 15 minutes is WorkManager's minimum period, and the interval the
         *  spec asks for. `UPDATE` (not `KEEP`) so a re-arm after an app
         *  update replaces the old request instead of silently keeping a
         *  cancelled one. */
        fun schedule(context: Context) {
            try {
                val request = PeriodicWorkRequestBuilder<WidgetRefreshWorker>(
                    15,
                    TimeUnit.MINUTES,
                ).build()
                WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                    WORK_NAME,
                    ExistingPeriodicWorkPolicy.UPDATE,
                    request,
                )
            } catch (e: Throwable) {
                // WorkManager may be unavailable in a direct-boot window or a
                // unit test; the alarm chain is the primary path either way.
                Log.w(TAG, "schedule failed: ${e.message}")
            }
        }

        fun cancel(context: Context) {
            try {
                WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
            } catch (_: Throwable) {
            }
        }
    }
}
