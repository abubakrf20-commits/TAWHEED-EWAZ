package com.islamic.tawheeed.widget

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.WindowManager

/**
 * The prayer card's tap target — a transparent, no-history activity that
 * applies one «خواندم» mark, repaints the card and finishes.
 *
 * ## Why a tap is not a broadcast any more
 *
 * It was: `PendingIntent.getBroadcast` to [PrayerWidget] with
 * [PrayerWidget.ACTION_MARK_READ]. That is the cheaper path — no window, no
 * activity record, no lifecycle — and it works perfectly while the app's
 * process is alive. Measured on the POCO X7 Pro / HyperOS, 2026-11-05: a tap
 * with the process warm commits in +1 ms and paints in +6 ms.
 *
 * The defect is what happens when the process is NOT alive, which on this ROM
 * is the normal state of an app nobody has opened for a while: MIUI's freezer
 * (`Greeze`) holds the widget's broadcast and then drops it. Measured with a
 * single tap after `am force-stop`:
 *
 *   • `D/PendingIntentRecordImpl: notifyGreeze pendingtent from
 *     com.mi.android.globallauncher -> com.islamic.tawheeed` — the PendingIntent
 *     is sent;
 *   • and then **nothing**: no `Start proc`, no receiver, no log line, for 20 s.
 *
 * That is the user's report verbatim — «صبح و ظهر و مغرب و عشا و عصر تیک
 * نمی‌خورند از داخل ویجت» — and it is also why the same tap sometimes worked
 * and sometimes did not: whether it landed depended on whether the app happened
 * to be frozen at that moment.
 *
 * An activity start is not droppable in that way. A `PendingIntent.getActivity`
 * from the launcher forces the process up to run this class, so the tap lands
 * deterministically. This is the same trampoline [TasbihActionActivity] already
 * uses for the same launcher behaviour, and the same load-bearing details apply:
 *
 *  - `FLAG_NOT_TOUCHABLE`, so the card underneath still receives the NEXT tap
 *    while this one renders;
 *  - `onNewIntent` dispatches too — a second tap reuses this instance instead
 *    of stacking another trampoline;
 *  - the render happens BEFORE `finish()`, because a finished activity's process
 *    is frozen almost immediately and a paint queued behind it never lands;
 *  - `FLAG_ACTIVITY_SINGLE_TOP` keeps a quick double tap on one instance.
 *
 * It draws nothing: the theme is translucent, the window is not focusable, and
 * there is no layout, so the home screen never visibly changes.
 */
class PrayerMarkActivity : Activity() {

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Invisible in every sense: no animation, no dim, transparent to touch.
        overridePendingTransition(0, 0)
        window.addFlags(
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
        )
        dispatch(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        dispatch(intent)
    }

    private fun dispatch(source: Intent?) {
        val index = source?.getIntExtra(PrayerWidget.EXTRA_PRAYER_INDEX, -1) ?: -1
        val widgetId = source?.getIntExtra(PrayerNativeViews.EXTRA_APP_WIDGET_ID, -1) ?: -1
        // Consume the intent, so a re-delivery of the SAME intent can never
        // toggle the same prayer twice.
        setIntent(Intent())
        if (index !in 0..4) {
            // A stale or foreign handle. Log it — without this a tap that
            // carried no index would vanish with no trace and look identical
            // to a dead button.
            Log.w(TAG, "mark with a bad index=$index (stale PendingIntent?)")
            finish()
            return
        }
        val startedAt = SystemClock.uptimeMillis()
        try {
            PrayerWidget.applyMarkAndRender(this, index, widgetId, startedAt)
        } catch (error: Throwable) {
            Log.e(TAG, "mark prayer=$index failed: ${error.message}", error)
        }
        mainHandler.post { finishSoon() }
    }

    /** One exit for every path — the trampoline must never linger. */
    private fun finishSoon() {
        if (isFinishing || isDestroyed) return
        finish()
        overridePendingTransition(0, 0)
    }

    override fun onDestroy() {
        // A tap must never leave the trampoline in the back stack.
        finishAndRemoveTask()
        super.onDestroy()
    }

    companion object {
        private const val TAG = "TawheeedPrayerMark"

        /** The intent the tap PendingIntent wraps. */
        fun intent(context: Context, widgetId: Int, index: Int): Intent =
            Intent(context, PrayerMarkActivity::class.java).apply {
                putExtra(PrayerWidget.EXTRA_PRAYER_INDEX, index)
                putExtra(PrayerNativeViews.EXTRA_APP_WIDGET_ID, widgetId)
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_NO_ANIMATION or
                        Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP,
                )
            }
    }
}
