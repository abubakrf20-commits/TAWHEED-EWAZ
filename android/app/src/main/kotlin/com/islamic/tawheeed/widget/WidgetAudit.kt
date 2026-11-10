package com.islamic.tawheeed.widget

import android.content.Context
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.islamic.tawheeed.R
import java.util.Locale
import kotlin.math.roundToInt

/**
 * The prayer card's budget, MEASURED instead of reasoned about.
 *
 * ## Why this exists
 *
 * [PrayerWidgetBudget] prices every band in dp and [PrayerNativeViews] draws
 * them. The two are written by hand in different files, and every defect the
 * user has reported on this card — sliced capsule names, a countdown that grew
 * into a headline, boxes that hid their times on a tall cell — was the same
 * class of bug: **a band that is priced differently from the way it is drawn**.
 * Arithmetic over font metrics cannot catch that, because the launcher's
 * `TextView` is not the one the arithmetic imagines: `includeFontPadding`,
 * `textStyle="bold"` synthetic emboldening, the RTL `LinearLayout` measure
 * order and the capsule row's weight all move the real numbers.
 *
 * So this object inflates the REAL RemoteViews at a REAL cell size, measures
 * it, and prints the price next to the measurement for every band. It is a
 * development instrument, reachable only through an explicit broadcast, and it
 * costs a production render nothing.
 *
 * ## What it also proves
 *
 * A capsule's tap. `RemoteViews.setOnClickPendingIntent` attaches a listener
 * that fires the mark broadcast; [probeClick] performs that click on the
 * inflated tree, so "the tap does nothing" can be answered without a launcher
 * in the loop — the PendingIntent either fires (the receiver logs) or it does
 * not (the action never applied).
 *
 * ## What it CANNOT prove — read this before trusting a number here
 *
 * The type metrics. This object measures in the APP's process, where
 * `android:fontFamily="@font/calibri"` resolves and a line is exactly 1.00 em.
 * In the LAUNCHER neither the typeface nor `includeFontPadding="false"`
 * reaches the inflated view: Persian falls back to a Naskh face and the Latin
 * clock to a face whose cap height is 0.716 em, and both lay out at ~1.48 em
 * per line. So a band that measures 34 dp here is 50 dp on the card.
 *
 * That gap is exactly how the 2026-11-04 regression got in: this instrument
 * reported every band 1.00 em and `PrayerWidgetBudget.TEXT_LINE_HEIGHT` was
 * lowered to match, and the capsules' times were sliced on the device while
 * the audit said they fitted. **A height number from this file is a lower
 * bound, not the truth.** The truth comes from `screencap` pixels — see the
 * derivation in [PrayerWidgetBudget.TEXT_LINE_HEIGHT].
 */
internal object WidgetAudit {

    private const val TAG = "TawheeedAudit"

    /** The bands, in the order they stack down the card. */
    private val BANDS = linkedMapOf(
        "header" to R.id.prayer_header,
        "weekday_chip" to R.id.prayer_weekday_chip,
        "clock_slot" to R.id.prayer_clock_slot,
        "date" to R.id.prayer_date,
        "capsule_row" to R.id.prayer_capsule_row,
        "capsule_0" to R.id.prayer_capsule_0,
        "name_row_0" to R.id.prayer_capsule_name_row_0,
        "check_0" to R.id.prayer_capsule_check_0,
        "name_0" to R.id.prayer_capsule_name_0,
        "time_0" to R.id.prayer_capsule_time_0,
        "pill" to R.id.prayer_countdown_pill,
        "progress" to R.id.prayer_progress,
        "countdown_row" to R.id.prayer_countdown_row,
        "prefix" to R.id.prayer_countdown_prefix,
        "countdown" to R.id.prayer_countdown,
        "hint" to R.id.prayer_hint,
    )

    /** The five capsules, in prayer order (0 = fajr … 4 = isha). */
    private val CAPSULE_PROBES = intArrayOf(
        R.id.prayer_capsule_0, R.id.prayer_capsule_1, R.id.prayer_capsule_2,
        R.id.prayer_capsule_3, R.id.prayer_capsule_4,
    )

    /**
     * Inflates the card for [widthDp] × [heightDp], measures it, and logs the
     * price of every band beside its measured height.
     */
    fun measure(context: Context, widgetId: Int, widthDp: Float, heightDp: Float) {
        val density = context.resources.displayMetrics.density
        val budget = PrayerNativeViews.budgetFor(context, widthDp, heightDp)
        val rv = try {
            PrayerNativeViews.full(context, widgetId, widthDp to heightDp)
        } catch (t: Throwable) {
            Log.e(TAG, "inflate failed: ${t.message}", t)
            return
        }
        val root: View = try {
            rv.apply(context, FrameLayout(context))
        } catch (t: Throwable) {
            Log.e(TAG, "apply failed: ${t.message}", t)
            return
        } ?: return

        val w = (widthDp * density).roundToInt()
        val h = (heightDp * density).roundToInt()
        root.measure(
            View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY),
        )
        root.layout(0, 0, w, h)

        Log.d(
            TAG,
            "cell=${widthDp}x${heightDp}dp px=${w}x$h small=${budget.isSmall} " +
                "clock=${budget.clockSizeSp}sp box=${fmt(budget.clockBoxDp)}dp " +
                "overflow=${fmt(budget.overflowDp)}dp",
        )
        Log.d(
            TAG,
            "priced: header=${fmt(budget.headerBandDp)} date=${fmt(budget.dateBandDp)} " +
                "pills=${fmt(budget.pillsBandDp)} countdown=${fmt(budget.countdownBandDp)} " +
                "progress=${fmt(budget.progressBandDp)} hint=${fmt(budget.hintBandDp)} " +
                "gaps=${fmt(budget.totalGapsDp)} total=${fmt(budget.totalContentDp)}",
        )
        Log.d(
            TAG,
            "type: label=${fmt(budget.pillLabelSizeSp)} time=${fmt(budget.pillTimeSizeSp)} " +
                "pad=${fmt(budget.pillPadDp)} countdown=${fmt(budget.countdownSizeSp)} " +
                "scale=${fmt(budget.scale)} fs=${fmt(budget.fontScale)}",
        )
        for ((name, id) in BANDS) {
            val v = root.findViewById<View>(id) ?: continue
            val vis = if (v.visibility == View.VISIBLE) "" else " GONE"
            Log.d(
                TAG,
                "  %-13s top=%4d h=%4dpx (%6sdp) padT=%3d padB=%3d%s".format(
                    Locale.US, name, v.top, v.height, fmt(v.height / density),
                    v.paddingTop, v.paddingBottom, vis,
                ),
            )
        }
        // The capsule row's children, so a clipped time is visible as numbers.
        val row = root.findViewById<ViewGroup>(R.id.prayer_capsule_row)
        if (row != null) {
            Log.d(
                TAG,
                "  row h=${row.height}px pad=${row.paddingTop}/${row.paddingBottom} " +
                    "children=" + (0 until row.childCount).joinToString {
                        "${row.getChildAt(it).height}"
                    },
            )
        }
        val capsule = root.findViewById<ViewGroup>(R.id.prayer_capsule_0)
        if (capsule != null) {
            Log.d(
                TAG,
                "  capsule_0 h=${capsule.height}px children=" + (0 until capsule.childCount)
                    .joinToString { "${capsule.getChildAt(it).height}" },
            )
        }
        probeClick(root, widgetId)
    }

    /**
     * Reports the tap map of the inflated tree, then clicks capsule 0.
     *
     * The report exists because a widget's taps are the one thing on this card
     * that cannot be exercised from a desk: `adb shell input tap` injects a
     * ZERO-DURATION tap that this ROM drops silently, so "the tap does nothing"
     * was believed for a day when in fact nothing had been delivered. What this
     * prints is the state the launcher receives — which views are clickable and
     * where they sit — and the click itself is the one part that has to be
     * verified by hand (a 90 ms press).
     *
     * If `setOnClickPendingIntent` reached the view, the mark fires and
     * `PrayerWidget` logs `tap.prefs.committed`. If it did not, this is silent —
     * which is exactly the difference between «تیک زدن کار نمی‌کند» being a
     * click-attachment bug or a delivery bug.
     */
    private fun probeClick(root: View, widgetId: Int) {
        val rootView = root.findViewById<View>(R.id.prayer_native_root)
        val surface = root.findViewById<View>(R.id.prayer_surface)
        Log.d(
            TAG,
            "probe: root clickable=${rootView?.isClickable} " +
                "surface clickable=${surface?.isClickable}",
        )
        for (index in CAPSULE_PROBES.indices) {
            val v = root.findViewById<View>(CAPSULE_PROBES[index])
            val bounds = v?.let { "${it.left},${it.top}-${it.right},${it.bottom}" }
            Log.d(
                TAG,
                "probe: capsule$index clickable=${v?.isClickable} h=${v?.height}px bounds=$bounds",
            )
        }
        val capsule = root.findViewById<View>(R.id.prayer_capsule_0) ?: run {
            Log.w(TAG, "probe: no capsule 0")
            return
        }
        val fired = capsule.performClick()
        Log.d(TAG, "probe: performClick handled=$fired id=$widgetId")
    }

    /** Latin digits whatever the phone's locale is — this output is read
     *  in a terminal, not by the user. */
    private fun fmt(v: Float): String = String.format(Locale.US, "%.2f", v)
}
