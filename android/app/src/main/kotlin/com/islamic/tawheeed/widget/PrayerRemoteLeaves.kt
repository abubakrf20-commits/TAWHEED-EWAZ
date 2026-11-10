package com.islamic.tawheeed.widget

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.islamic.tawheeed.MainActivity
import com.islamic.tawheeed.R

/**
 * The prayer card's LIVE leaf: a framework `TextClock` that ticks inside the
 * LAUNCHER's process, so no widget update, alarm or Doze grant is involved in
 * the one value that must never fall behind.
 *
 * The leaf is added into the native card's `prayer_clock_slot` by
 * [PrayerNativeViews] with `removeAllViews` + `addView` — the order AOSP's
 * own `RemoteViews.addView` docs demand for predictable re-use, so a full
 * re-render can swap the leaf's layout variant safely.
 *
 * ## Why there are no format setters here (2026-11-04, device-measured)
 *
 * `RemoteViews.setString(id, "setFormat12Hour", ...)` resolves the method
 * with `java.lang.String`, but `TextClock` declares
 * `setFormat12Hour(CharSequence)`. On the POCO X7 Pro / HyperOS (Android 16)
 * the launcher inflates its OWN `HomeMIUIWidgetTextClock` in place of ours,
 * and `RemoteViews.getMethod` threw:
 *
 * ```
 * W/AppWidgetHostView: Error inflating RemoteViews
 *   android.widget.RemoteViews$ActionException: view:
 *   ...HomeMIUIWidgetTextClock doesn't have method:
 *   setFormat12Hour(class java.lang.String)
 * E/Launcher.Widget: widget load error: ...PrayerWidget
 * ```
 *
 * `AppWidgetHostView` turns that exception into its error view — the
 * «لا یمكن تحمیل التطبيق المصغّر» the user reported. Both switches (12/24
 * and fa/latin) are therefore INFLATE-TIME layout variants, and only
 * dedicated typed RemoteViews setters (color, text size, click) are used
 * here. Nothing calls a generic reflection setter with a hand-written method
 * name any more.
 *
 * The countdown's leaf is gone from this object: the native card hosts its
 * Chronometer DIRECTLY in its root layout (`widget_prayer_native*.xml`) and
 * re-bases it with the dedicated `setChronometer`/`setChronometerCountDown`
 * setters on every full render.
 */
internal object PrayerRemoteLeaves {

    private const val KEY_FA_DIGITS = "widget_fa_digits"

    /** The live clock. The four layouts carry BOTH formats (see their
     *  headers), so the app's 12/24 setting wins over the system's without a
     *  single runtime format call. */
    fun clock(
        context: Context,
        use12Hour: Boolean,
        color: Int,
        sizeSp: Float,
    ): RemoteViews {
        val fa = WidgetRepository.prefs(context).getBoolean(KEY_FA_DIGITS, false)
        val layout = when {
            fa && use12Hour -> R.layout.widget_prayer_clock_fa_12
            fa -> R.layout.widget_prayer_clock_fa
            use12Hour -> R.layout.widget_prayer_clock_12
            else -> R.layout.widget_prayer_clock
        }
        val views = RemoteViews(context.packageName, layout)
        // setTextColor / setTextViewTextSize / setOnClickPendingIntent are
        // dedicated RemoteViews actions; they do not depend on a method name
        // we supply, so a host-supplied TextClock subclass cannot reject them.
        views.setTextColor(R.id.prayer_clock, color)
        views.setTextViewTextSize(
            R.id.prayer_clock,
            android.util.TypedValue.COMPLEX_UNIT_SP,
            sizeSp,
        )
        views.setOnClickPendingIntent(R.id.prayer_clock, openApp(context))
        return views
    }

    /**
     * Whether this install may host the live leaf. Reads
     * [WidgetPrefs.KEY_LIVE_LEAVES] on every render, so turning it off takes
     * effect on the next update.
     *
     * The flag exists because a launcher CAN refuse to inflate a nested
     * `RemoteViews` — the host then shows its own error view for the WHOLE
     * card, not just the leaf. With the flag off the card still renders, using
     * [bakedClock] and the minute tick.
     */
    fun enabled(context: Context): Boolean =
        WidgetPrefs.liveLeaves(WidgetRepository.prefs(context))

    /**
     * The fallback clock string for a host that refused the live leaf: the
     * model's own minute-of-day in the app's 12/24 format. A model that could
     * not read the clock ([PrayerWidgetModel.nowMinutesOfDay] = -1) falls back
     * to the wall clock at render time — a minute-at-a-time value is coarse,
     * but it must never be blank.
     */
    fun bakedClock(model: PrayerWidgetModel): String {
        val minutesOfDay = model.nowMinutesOfDay.takeIf { it >= 0 }
            ?: java.util.Calendar.getInstance().let {
                it.get(java.util.Calendar.HOUR_OF_DAY) * 60 +
                    it.get(java.util.Calendar.MINUTE)
            }
        return formatClockTime(minutesOfDay / 60, minutesOfDay % 60, model.use12Hour)
    }

    fun openApp(context: Context): PendingIntent = PendingIntent.getActivity(
        context,
        0,
        Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            putExtra(MainActivity.EXTRA_SHORTCUT, "prayer")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        },
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}
