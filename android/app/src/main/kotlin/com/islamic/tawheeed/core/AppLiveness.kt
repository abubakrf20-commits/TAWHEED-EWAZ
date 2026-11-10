package com.islamic.tawheeed.core

import android.content.Context
import android.util.Log

/**
 * A cheap "is the app on screen right now?" marker, written by [MainActivity]
 * and read by the boot/rollover receivers.
 *
 * Those receivers set the `needs_reschedule` flag so that some LATER run — a
 * background job, the next app open — knows it must rebuild the schedule from
 * scratch. When the app is already in the foreground that flag can only ever be
 * consumed by that same live process, which is mid-reschedule anyway: the flag
 * was measured forcing a second full rebuild on every launch, right on top of
 * the first one (a few hundred alarms, all re-armed twice).
 *
 * A timestamp in prefs rather than a static field, because the reader is a
 * different component (and can be a different process start) than the writer,
 * and it must expire on its own: a hard process kill while foregrounded leaves
 * the stamp behind, so the window is a few seconds — enough to cover the
 * receiver's own dispatch delay after the launch, far shorter than any real
 * gap between the app resuming and its own reschedule pass. Nothing is ever
 * *unscheduled* by this marker; the receivers still re-arm the persisted
 * alarms exactly as before, they only stop asking for a forced rebuild the live
 * app is already doing.
 */
object AppLiveness {
    private const val TAG = "AppLiveness"
    private const val PREFS = "prayer_alarms"
    private const val KEY = "foreground_at"

    /** How recently the app must have resumed to count as "the user is looking at it". */
    const val LIVENESS_MS = 4_000L

    fun markForeground(context: Context) = stamp(context, System.currentTimeMillis())

    fun markBackground(context: Context) = stamp(context, 0L)

    /**
     * True when the app was resumed within [LIVENESS_MS]. Callers pass [now] so
     * the rule is testable without a wall-clock dependency.
     */
    fun isForegroundNow(context: Context, now: Long = System.currentTimeMillis()): Boolean {
        val at = try {
            prefs(context).getLong(KEY, 0L)
        } catch (e: Exception) {
            Log.w(TAG, "foreground stamp unreadable, treating the app as background: ${e.message}")
            return false
        }
        return at > 0L && now - at < LIVENESS_MS
    }

    private fun stamp(context: Context, at: Long) {
        try {
            prefs(context).edit().putLong(KEY, at).apply()
        } catch (e: Exception) {
            // Losing the marker only means the receivers behave as they used to.
            Log.w(TAG, "foreground stamp not written: ${e.message}")
        }
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
