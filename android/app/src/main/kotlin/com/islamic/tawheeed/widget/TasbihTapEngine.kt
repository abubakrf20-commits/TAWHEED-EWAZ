package com.islamic.tawheeed.widget

import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log

/**
 * The widget's tap state machine.
 *
 * A tap is **one committed prefs write plus one partial RemoteViews**. Nothing
 * else: no activity, no Flutter engine, no network, no dialog, and — since the
 * card stopped being a Glance composition — no composition either. The old bead
 * animation re-rendered the ring ~12 times per tap, which is what made counting
 * feel slow on a cheap phone; the old tap path also started a whole activity,
 * which cost a cold process start before the first byte of work happened.
 *
 * **Every tap counts, and every tap paints.** A time-based tap filter cannot
 * tell a launcher's duplicate delivery from a fast human — the fastest double
 * tap is ~120 ms — so a window wide enough to catch the duplicate would also
 * eat a real bead. There is nothing to coalesce any more: the repaint is a
 * merge of a few setters, cheaper than the bookkeeping a debounce would need.
 * See [TasbihNativeViews].
 */
internal object TasbihTapEngine {

    const val ACTION_INCREMENT = "com.tawheeed.TASBIH_INCREMENT"
    const val ACTION_RESET = "com.tawheeed.TASBIH_RESET"
    const val ACTION_PREV_ZIKR = "com.tawheeed.TASBIH_PREV_ZIKR"
    const val ACTION_NEXT_ZIKR = "com.tawheeed.TASBIH_NEXT_ZIKR"

    private const val TAG = "TasbihWidget"

    private const val RESET_CONFIRM_MS = 3000L

    private val confirmUntil = HashMap<String, Long>()
    private val confirmJobs = HashMap<String, Runnable>()

    /** What one tap did, for the caller's timing log and for tests. */
    data class TapResult(
        /** False when the tap was a duplicate delivery or a no-op. */
        val applied: Boolean = false,
        /** The counter after the tap. */
        val count: Int = 0,
        /** This tap closed a full cycle (count reached the target). */
        val cycleComplete: Boolean = false,
        /** The zikr the widget is showing now. */
        val zikrIndex: Int = 0,
    )

    /** True while the reset window is open for this widget instance. */
    fun isConfirming(widgetKey: String): Boolean =
        (confirmUntil[widgetKey] ?: 0L) > SystemClock.elapsedRealtime()

    /**
     * One lock for every tap, because a tap is a read-modify-write.
     *
     * Two quick taps could both read the same per-zikr counts, both write
     * `count + 1`, and one bead vanished without a trace — «دو بار زدم، یکی کم
     * شد». Serialising the whole state machine makes a burst count exactly once
     * each, and keeps the reset-confirm window honest when two taps race.
     */
    private val tapLock = Any()

    /**
     * Applies one tap.
     *
     * **The debounce is on the RENDER, not on the tap.** A time-based tap
     * filter would be indistinguishable from a fast human: the fastest double
     * tap is ~120 ms, and a launcher that re-delivers a PendingIntent does so
     * within a few frames of the same gesture, so any window wide enough to
     * catch the duplicate is also wide enough to eat a real bead. Counting is
     * sacred here — a lost bead is a silent data bug the user cannot see or
     * undo — so every delivered tap counts, and every tap repaints. That is
     * what «debounce for rapid taps» has to mean for a counter.
     */
    fun applyTap(context: Context, action: String, widgetKey: String): TapResult =
        synchronized(tapLock) { applyTapLocked(context, action, widgetKey) }

    // ── Confirm window ─────────────────────────────────────────────────────

    /** Drops the confirm window for an instance that no longer exists. */
    fun forget(widgetKey: String) {
        cancelConfirm(widgetKey)
    }

    // ── State machine ──────────────────────────────────────────────────────

    private fun applyTapLocked(context: Context, action: String, widgetKey: String): TapResult {
        val prefs = WidgetRepository.prefs(context)
        // A tap on the first minute of a new day must count from zero, not
        // from yesterday's tally.
        TasbihGlanceWidgetReceiver.maybeDailyReset(
            prefs,
            TasbihGlanceWidgetReceiver.todayKey(),
        )
        val idx = prefs.getInt("tasbih_zikr_index", 0)

        when (action) {
            ACTION_INCREMENT -> {
                cancelConfirm(widgetKey)
                val counts = TasbihGlanceWidgetReceiver.getPerZikrCounts(prefs)
                val targets = TasbihGlanceWidgetReceiver.getPerZikrTargets(prefs)
                val target = targets.getOrNull(idx) ?: prefs.getInt("tasbih_target", 33)
                val current = counts[idx] ?: 0

                // «بعد از رسیدن به هدف» — when ON (tasbih_auto_advance = true)
                // a finished cycle hands the next tap to the NEXT zikr instead
                // of counting past the target: the round is over, and the
                // user's next intention is the next dhikr. The default is OFF
                // («ادامه شمارش»): the counter keeps climbing past the target
                // until the user picks «ذکر بعدی» themselves.
                if (target > 0 && current >= target &&
                    prefs.getBoolean("tasbih_auto_advance", false)
                ) {
                    return advanceZikr(prefs, idx, forward = true)
                }

                counts[idx] = current + 1
                TasbihGlanceWidgetReceiver.setPerZikrCounts(prefs, counts)
                val newCount = counts[idx] ?: 0
                val today = TasbihGlanceWidgetReceiver.todayKey()
                val dailyKey = "widget_tasbih_daily_total"
                val dailyDateKey = "widget_tasbih_daily_date"
                val existingDaily = if (prefs.getString(dailyDateKey, "") == today) {
                    prefs.getInt(dailyKey, 0)
                } else {
                    0
                }
                prefs.edit()
                    .putInt("tasbih_count", newCount)
                    .putInt(dailyKey, existingDaily + 1)
                    .putString(dailyDateKey, today)
                    // Record that the WIDGET was the most recent editor, so the
                    // next app sync keeps this tap instead of overwriting it
                    // with the app's (possibly older) counter.
                    .putLong("widget_tasbih_last_tap_at", System.currentTimeMillis())
                    .apply()
                TasbihGlanceWidgetReceiver.appendEvent(
                    prefs,
                    TasbihGlanceWidgetReceiver.EVENT_INC,
                    idx,
                    1,
                )
                val cycleComplete = target > 0 && newCount == target
                vibrate(context, cycleComplete)
                return TapResult(
                    applied = true,
                    count = newCount,
                    cycleComplete = cycleComplete,
                    zikrIndex = idx,
                )
            }

            ACTION_RESET -> {
                if (isConfirming(widgetKey)) {
                    cancelConfirm(widgetKey)
                    performReset(prefs, idx)
                    vibrate(context, double = false)
                    return TapResult(applied = true, count = 0, zikrIndex = idx)
                }
                // First tap only arms the window; the caller's re-render paints
                // «تأیید؟» from isConfirming().
                armConfirm(context, widgetKey)
                return TapResult(applied = true, count = prefs.getInt("tasbih_count", 0), zikrIndex = idx)
            }

            ACTION_PREV_ZIKR -> {
                cancelConfirm(widgetKey)
                return advanceZikr(prefs, idx, forward = false)
            }

            ACTION_NEXT_ZIKR -> {
                cancelConfirm(widgetKey)
                return advanceZikr(prefs, idx, forward = true)
            }
        }
        return TapResult()
    }

    /** Moves to the neighbouring zikr, wrapping, and republishes the flat keys. */
    private fun advanceZikr(
        prefs: SharedPreferences,
        idx: Int,
        forward: Boolean,
    ): TapResult {
        val zikrList = TasbihGlanceWidgetReceiver.getZikrList(prefs)
        if (zikrList.isEmpty()) return TapResult()
        val newIdx = if (forward) {
            if (idx < zikrList.size - 1) idx + 1 else 0
        } else {
            if (idx > 0) idx - 1 else zikrList.size - 1
        }
        val counts = TasbihGlanceWidgetReceiver.getPerZikrCounts(prefs)
        val zikrTargets = TasbihGlanceWidgetReceiver.getPerZikrTargets(prefs)
        val newCount = counts[newIdx] ?: 0
        prefs.edit()
            .putInt("tasbih_zikr_index", newIdx)
            .putString("tasbih_dhikr", zikrList.getOrNull(newIdx) ?: "")
            .putInt("tasbih_count", newCount)
            .putInt(
                "tasbih_target",
                zikrTargets.getOrNull(newIdx) ?: prefs.getInt("tasbih_target", 33),
            )
            .putLong("widget_tasbih_last_tap_at", System.currentTimeMillis())
            .apply()
        TasbihGlanceWidgetReceiver.appendEvent(
            prefs,
            TasbihGlanceWidgetReceiver.EVENT_ZIKR,
            newIdx,
        )
        return TapResult(applied = true, count = newCount, zikrIndex = newIdx)
    }

    private fun performReset(prefs: SharedPreferences, idx: Int) {
        val counts = TasbihGlanceWidgetReceiver.getPerZikrCounts(prefs)
        counts[idx] = 0
        TasbihGlanceWidgetReceiver.setPerZikrCounts(prefs, counts)
        prefs.edit()
            .putInt("tasbih_count", 0)
            .putLong("widget_tasbih_last_tap_at", System.currentTimeMillis())
            .apply()
        TasbihGlanceWidgetReceiver.appendEvent(
            prefs,
            TasbihGlanceWidgetReceiver.EVENT_RESET,
            idx,
        )
    }

    // ── Reset confirmation (3 s window) ────────────────────────────────────

    private fun armConfirm(context: Context, widgetKey: String) {
        cancelConfirm(widgetKey)
        confirmUntil[widgetKey] = SystemClock.elapsedRealtime() + RESET_CONFIRM_MS
        val job = Runnable {
            confirmUntil.remove(widgetKey)
            confirmJobs.remove(widgetKey)
            // Re-render the closed window: the confirm face is gone either way.
            TasbihGlanceWidgetReceiver.renderAll(context)
        }
        confirmJobs[widgetKey] = job
        Handler(Looper.getMainLooper()).postDelayed(job, RESET_CONFIRM_MS)
    }

    private fun cancelConfirm(widgetKey: String) {
        confirmUntil.remove(widgetKey)
        confirmJobs.remove(widgetKey)?.let { Handler(Looper.getMainLooper()).removeCallbacks(it) }
    }

    // ── Haptics ────────────────────────────────────────────────────────────

    /**
     * One short tick per bead; a **double** tick when the round closes.
     *
     * The double pulse is the only feedback a home-screen widget can give at
     * the moment the target is reached — the ✓ appears, but the user's eyes are
     * on their hand, not the card.
     */
    private fun vibrate(context: Context, double: Boolean) {
        try {
            if (!WidgetRepository.prefs(context).getBoolean("azkar_haptic", true)) return
            val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                if (double) {
                    vibrator.vibrate(
                        VibrationEffect.createWaveform(
                            longArrayOf(0L, 22L, 70L, 22L),
                            -1,
                        ),
                    )
                } else {
                    vibrator.vibrate(
                        VibrationEffect.createOneShot(18, VibrationEffect.DEFAULT_AMPLITUDE),
                    )
                }
            } else {
                @Suppress("DEPRECATION")
                if (double) {
                    vibrator.vibrate(longArrayOf(0L, 22L, 70L, 22L), -1)
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(18)
                }
            }
        } catch (_: Throwable) {
            // Haptics are decoration; never let a missing vibrator kill a tap.
        }
    }
}
