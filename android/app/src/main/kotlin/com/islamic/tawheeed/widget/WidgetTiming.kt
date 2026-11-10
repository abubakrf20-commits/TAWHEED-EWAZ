package com.islamic.tawheeed.widget

import android.os.Process
import android.os.SystemClock
import android.util.Log

/**
 * The stage 0 stopwatch: one tag, one format, so a «it takes 30 seconds» report
 * can be settled from `adb logcat -s TW_TIMING` instead of guessed at.
 *
 * The split that matters is **process start vs. everything after it**:
 * [processStartUptimeMillis] is when the kernel spawned this process, so
 * `tap → process` and `process → painted` are separate numbers. Without that
 * split a cold start (which no widget architecture can avoid) is indistinguishable
 * from slow work inside the process (which this migration does remove).
 *
 * Every line is `I/TW_TIMING  <event>  +<ms>ms  <detail>`. `+` is measured from
 * the tap that started the burst where a tap is involved, and from process
 * start otherwise — the detail field always names the origin, so a log can be
 * read without the code beside it.
 *
 * Cost: one `Log.i` per stage, a handful per tap. Deliberately not behind a
 * flag — the value of a timing log is highest exactly when nobody remembered to
 * turn it on.
 */
internal object WidgetTiming {

    const val TAG = "TW_TIMING"

    /** Kernel spawn instant of this process, on the same clock as
     *  [SystemClock.uptimeMillis]. API 24+ (our minSdk). */
    fun processStartUptimeMillis(): Long = Process.getStartUptimeMillis()

    /** Milliseconds between process spawn and now — the cold-start floor. */
    fun processReadyMillis(): Long =
        (SystemClock.uptimeMillis() - processStartUptimeMillis()).coerceAtLeast(0L)

    fun mark(event: String, sinceUptimeMillis: Long, detail: String = "") {
        val delta = (SystemClock.uptimeMillis() - sinceUptimeMillis).coerceAtLeast(0L)
        if (detail.isEmpty()) {
            Log.i(TAG, "$event +${delta}ms")
        } else {
            Log.i(TAG, "$event +${delta}ms $detail")
        }
    }

    /** Logs the cold-start floor once per process, on the first widget entry. */
    fun logProcessReady(origin: String) {
        Log.i(
            TAG,
            "process.ready +${processReadyMillis()}ms origin=$origin " +
                "pid=${Process.myPid()}",
        )
    }
}
