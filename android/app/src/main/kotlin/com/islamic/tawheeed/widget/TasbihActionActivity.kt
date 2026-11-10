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
 * The tasbih widget's **fallback** tap target — a transparent, no-history
 * activity that applies one action, re-renders and finishes.
 *
 * It is not the default path any more. A tap is normally a broadcast to
 * [TasbihGlanceWidgetReceiver], which costs the same process start without a
 * window, an activity record or a lifecycle — the difference between «the bead
 * appears» and «the bead appears after the app boots». This class exists for
 * the one launcher that genuinely drops a frozen app's widget broadcast
 * (observed 2026-10-25), and is selected by
 * [WidgetPrefs.KEY_TAP_DELIVERY] = `activity` so that a device which needs it
 * can be switched over without shipping a new build.
 *
 * Several details are load-bearing, each paid for with a device test:
 *
 *  - the window is `FLAG_NOT_TOUCHABLE`, so while a composition runs the card
 *    underneath still receives the NEXT tap. Without it every other bead was
 *    swallowed by this invisible window;
 *  - `onNewIntent` dispatches too — with the window pass-through, a second tap
 *    reuses this instance instead of starting a new one, and ignoring the new
 *    intent dropped that bead;
 *  - the render starts BEFORE `finish()`, because a finished activity's process
 *    is frozen by the battery manager almost immediately and the composition
 *    then never lands;
 *  - `FLAG_ACTIVITY_SINGLE_TOP` routes a quick second tap into `onNewIntent`
 *    instead of stacking another trampoline on the task.
 *
 * The old «safety heal» alarm is gone, and so is the in-process repaint that
 * briefly replaced it. The alarm was armed here with `FLAG_NO_CREATE`, so every
 * tap after the first armed nothing, while the surviving heal stood down as
 * soon as it saw a newer tap. The in-process repaint that replaced it turned
 * out to be worse than the gap it covered: it queued a second full composition
 * (≈1 MB of bitmaps to the launcher) 1.5 s after *every* bead, which is most of
 * what made a burst of taps feel like a queue draining. See [TasbihNativeViews].
 */
class TasbihActionActivity : Activity() {

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Invisible in every sense: no animation, no dim, and transparent to
        // touch so the widget keeps working while this renders.
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
        val action = source?.getStringExtra(EXTRA_ACTION)
        if (action.isNullOrEmpty()) {
            // Fired with no extras: a stale or foreign handle. Log it —
            // before this line such a tap vanished with no trace and looked
            // identical to a dead button (2026-10-25).
            Log.w(TAG, "tap with no action (stale PendingIntent?), intent=$source")
            finish()
            return
        }
        val widgetKey = source.getStringExtra(EXTRA_WIDGET) ?: DEFAULT_WIDGET_KEY
        // Consume the intent so a re-delivery of the SAME intent can never
        // count the same bead twice.
        setIntent(Intent())
        val startedAt = SystemClock.uptimeMillis()
        Log.i(TAG, "tap action=$action widget=$widgetKey delivery=activity")
        try {
            WidgetTokens.init(this)
            TasbihTapEngine.applyTap(this, action, widgetKey)
        } catch (error: Throwable) {
            Log.e(TAG, "applyTap($action) failed: ${error.message}")
        }
        WidgetTiming.mark("tap.prefs.committed", startedAt, "action=$action delivery=activity")
        // The paint is a binder call that returns once the launcher has the new
        // RemoteViews, so there is nothing to wait for: render, then leave. The
        // activity must not linger — a finished activity's process is frozen by
        // the battery manager almost immediately, and a paint queued behind it
        // would never land.
        try {
            TasbihGlanceWidgetReceiver.renderAll(this)
        } catch (error: Throwable) {
            Log.e(TAG, "render failed: ${error.message}")
        }
        WidgetTiming.mark("tap.render.done", startedAt, "action=$action delivery=activity")
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
        private const val TAG = "TasbihWidget"
        private const val EXTRA_ACTION = "com.tawheeed.TASBIH_EXTRA_ACTION"
        private const val EXTRA_WIDGET = "com.tawheeed.TASBIH_EXTRA_WIDGET"

        /** One card per home screen shares the same counter, so a constant key
         *  is enough for the confirm window and the daily rollover. */
        private const val DEFAULT_WIDGET_KEY = "tasbih"

        /** The intent `actionStartActivity` wraps, for the fallback path. */
        fun intent(context: Context, action: String, widgetKey: String): Intent =
            Intent(context, TasbihActionActivity::class.java).apply {
                putExtra(EXTRA_ACTION, action)
                putExtra(EXTRA_WIDGET, widgetKey)
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_NO_ANIMATION or
                        Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP,
                )
            }
    }
}
