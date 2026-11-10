package com.islamic.tawheeed.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.os.Build
import android.os.SystemClock
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.RemoteViews
import com.islamic.tawheeed.R
import kotlin.math.roundToInt

/**
 * The prayer card's SECOND layout: the five prayers as five ROWS.
 *
 * This is the whole of the «چیدمان عمودی» option. It is deliberately a
 * separate object with its own layout resource and its own budget, because the
 * shipped horizontal card must not change: [PrayerNativeViews] only reaches
 * this file when `widget_prayer_layout == vertical`, and with that key absent
 * it runs exactly the code it ran before this file existed. Nothing here
 * writes to any pref the horizontal card reads.
 *
 * ## What is shared with the horizontal card, and why
 *
 * The five capsule groups keep the horizontal card's IDS
 * (`prayer_capsule_N` / `_name_N` / `_time_N` / `_check_N`), so the tap render
 * is the same partial merge: a «خواندم» tap sets the same five ids' text,
 * colors, fills and check bitmaps and `partiallyUpdateAppWidget` merges them
 * into the tree the launcher already inflated. The only thing that differs is
 * the CONTAINER — a horizontal row (name … time) instead of a vertical box
 * (name over time) — which is exactly what the option is for.
 *
 * The palette, the surface bitmap, the live clock leaf and the countdown
 * Chronometer are the same code paths ([WidgetTheme], [WidgetArt],
 * [PrayerRemoteLeaves]), so both layouts are painted from one palette and one
 * snapshot. A tap on either card writes the same prefs
 * ([PrayerWidget.applyMarkAndRender]) and repaints through the same receiver.
 *
 * ## The tiers
 *
 * A 4×2 cell cannot hold a header, a clock, a date line and five rows of text
 * — the rows alone are ~120 dp. Rather than shrink a row until its time is
 * sliced (the defect [PrayerWidgetBudget] exists to prevent),
 * [PrayerVerticalBudget] drops a TIER: on a cell that can hold everything the
 * full card is drawn, and on a shorter one the five rows and the countdown are
 * drawn without the header, clock and date. The rows are the point of this
 * layout, so they are the last thing to go.
 */
internal object PrayerVerticalViews {

    private const val TAG = "TawheeedPrayerVertical"

    private val CAPSULE_IDS = intArrayOf(
        R.id.prayer_capsule_0, R.id.prayer_capsule_1, R.id.prayer_capsule_2,
        R.id.prayer_capsule_3, R.id.prayer_capsule_4,
    )
    private val CHECK_IDS = intArrayOf(
        R.id.prayer_capsule_check_0, R.id.prayer_capsule_check_1,
        R.id.prayer_capsule_check_2, R.id.prayer_capsule_check_3,
        R.id.prayer_capsule_check_4,
    )
    private val NAME_IDS = intArrayOf(
        R.id.prayer_capsule_name_0, R.id.prayer_capsule_name_1,
        R.id.prayer_capsule_name_2, R.id.prayer_capsule_name_3,
        R.id.prayer_capsule_name_4,
    )
    private val TIME_IDS = intArrayOf(
        R.id.prayer_capsule_time_0, R.id.prayer_capsule_time_1,
        R.id.prayer_capsule_time_2, R.id.prayer_capsule_time_3,
        R.id.prayer_capsule_time_4,
    )

    /** The four inter-row spacers between the five capsules. */
    private val ROW_GAP_IDS = intArrayOf(
        R.id.prayer_row_gap_1, R.id.prayer_row_gap_2,
        R.id.prayer_row_gap_3, R.id.prayer_row_gap_4,
    )

    private const val ONBOARDING_HINT = "برای راه‌اندازی، برنامه را یک بار باز کنید"

    /** The gold the iqamah phase wears — close to the accent family but
     *  distinct from it, per the brief («با رنگ دیگر نزدیک به طلایی»). It used
     *  to colour a SECOND pill; since v3 the one remaining pill turns gold
     *  while it counts to the iqamah, so the phase is still legible. */
    private val IQAMAH_GOLD = 0xFFC9A227.toInt()

    /** True when the stored layout asks for the five-row card. */
    fun isVertical(context: Context): Boolean =
        WidgetPrefs.isVerticalLayout(WidgetRepository.prefs(context))

    /**
     * The single decision point for «is this card the vertical one?».
     *
     * It is asked by BOTH renders — the full one and the tap merge — because
     * they must agree on the layout id, and it answers no in two cases:
     *
     *  - the option is horizontal (the shipped card, untouched);
     *  - the option is vertical but the cell is too short for even the COMPACT
     *    tier. Five rows are ~127 dp and cannot be shaved (a row priced under
     *    one line draws its text sliced), so on a cell smaller than that the
     *    horizontal card is drawn instead of a clipped vertical one. The
     *    settings page tells the user to raise the widget, and the fallback is
     *    logged so a report of «ویجت عمودی نیست» has an answer that does not
     *    depend on guessing.
     */
    fun shouldRenderVertical(
        context: Context,
        widgetId: Int,
        cellOverride: Pair<Float, Float>? = null,
    ): Boolean {
        if (!isVertical(context)) return false
        val (widthDp, heightDp) = cell(context, widgetId, cellOverride)
        val m = budget(context, widthDp, heightDp)
        if (m.overflowDp > 0.5f) {
            Log.w(
                TAG,
                "vertical layout selected but the cell cannot hold it " +
                    "(${widthDp}x$heightDp dp overflows by ${m.overflowDp} dp) " +
                    "— drawing the horizontal card",
            )
            return false
        }
        return true
    }

    /** The layout this build draws for the stored option.
     *
     * `_v3` (2026-11-08) because the second «تا اقامه» pill was deleted: the
     * remaining one now switches its caption and target with the phase. v2 had
     * moved the four inter-row spacers out of the row containers (v1 nested
     * them inside the horizontal rows, where a `match_parent` spacer ate the
     * row's width and pushed every time label off the card). Both are
     * STRUCTURAL changes, so the id changes with them: reusing it would let a
     * launcher recycle an old inflated tree that still holds the gold pill —
     * and since nothing sets it GONE any more, it would stay on screen for the
     * life of that widget instance. */
    fun layoutRes(): Int = R.layout.widget_prayer_native_vertical_v3

    /** The budget for one cell, from the same prefs the renderer reads. */
    private fun budget(
        context: Context,
        widthDp: Float,
        heightDp: Float,
    ): PrayerVerticalBudget.Metrics {
        val prefs = WidgetRepository.prefs(context)
        return PrayerVerticalBudget.metrics(
            widthDp = widthDp,
            heightDp = heightDp,
            hasData = PrayerWidgetModel.read(context).hasData,
            fontScale = fontScale(context),
            showProgress = prefs.getBoolean(WidgetPrefs.KEY_SHOW_PROGRESS, true),
            showGregorian = prefs.getBoolean(WidgetPrefs.KEY_SHOW_GREGORIAN, true),
        )
    }

    // ── Full render ────────────────────────────────────────────────────────

    fun full(
        context: Context,
        widgetId: Int,
        /** Development only: [WidgetAudit] renders for a cell it is not placed
         *  on. Production callers never pass this. */
        cellOverride: Pair<Float, Float>? = null,
    ): RemoteViews {
        val theme = WidgetTheme.resolve(context, WidgetTheme.WidgetTarget.PRAYER, widgetId)
        val model = PrayerWidgetModel.read(context)
        val (widthDp, heightDp) = cell(context, widgetId, cellOverride)
        val m = budget(context, widthDp, heightDp)
        val density = density(context)

        val views = RemoteViews(context.packageName, layoutRes())
        bindSurface(context, views, theme, widthDp, heightDp)
        bindFrame(views, m, density)
        bindClicks(context, views, widgetId)
        bindHeader(context, views, theme, model, m, density)
        bindClock(context, views, theme, model, m, density)
        bindDate(views, theme, model, m, density)
        for (index in 0 until 5) {
            bindRow(context, views, theme, model, index, m, density, applyGeometry = true)
        }
        bindCountdown(views, theme, model, m, density)
        bindHint(views, theme, model)
        Log.d(
            TAG,
            "metrics id=$widgetId cell=${m.widthDp}x${m.heightDp} tier=${m.tier} " +
                "rows=${m.rowsBandDp} clock=${m.clockSizeSp} overflow=${m.overflowDp}",
        )
        return views
    }

    // ── Tap render ─────────────────────────────────────────────────────────

    /**
     * The subset a tap can change, merged into the launcher's existing tree.
     *
     * The layout id MUST be the one the card was inflated from: a partial
     * RemoteViews carrying a different layout id makes the host inflate a new
     * (empty) tree instead of merging, which would blank the card on the first
     * tap. Both renders therefore read the layout from [layoutRes] and the tier
     * from the same budget, and [applyGeometry] is false here so no padding or
     * type size is touched — a tap costs no layout work at all.
     */
    fun capsules(context: Context, widgetId: Int): RemoteViews {
        val theme = WidgetTheme.resolve(context, WidgetTheme.WidgetTarget.PRAYER, widgetId)
        val model = PrayerWidgetModel.read(context)
        val (widthDp, heightDp) = cell(context, widgetId, null)
        val m = budget(context, widthDp, heightDp)
        val views = RemoteViews(context.packageName, layoutRes())
        val density = density(context)
        for (index in 0 until 5) {
            bindRow(
                context, views, theme, model, index, m, density,
                applyGeometry = false,
            )
        }
        return views
    }

    /**
     * A PARTIAL render for the progress tick (see [PrayerNativeViews.progressOnly]).
     * Builds from [layoutRes] and sets ONLY [R.id.prayer_progress]. The vertical
     * card has no compact tier, so it always carries a progress pill.
     */
    fun progressOnly(context: Context, widgetId: Int): RemoteViews? {
        val theme = WidgetTheme.resolve(context, WidgetTheme.WidgetTarget.PRAYER, widgetId)
        val model = PrayerWidgetModel.read(context)
        val (widthDp, heightDp) = cell(context, widgetId, null)
        val m = budget(context, widthDp, heightDp)
        val density = density(context)
        val views = RemoteViews(context.packageName, layoutRes())
        val inIqamah = model.countdown.isIqamahPhase
        val tint = if (inIqamah) IQAMAH_GOLD else theme.accent
        val widthPx = ((m.widthDp - 2f * m.sideInsetDp) * density).roundToInt()
        val heightPx = (PrayerWidgetBudget.lineDp(
            maxOf(m.countdownSizeSp, m.captionSizeSp), m.fontScale,
        ) + 2f).let { (it * density).roundToInt() }
        val fraction = model.countdownFraction() ?: 0f
        views.setImageViewBitmap(
            R.id.prayer_progress,
            WidgetArt.progressPill(
                widthPx = widthPx,
                heightPx = heightPx,
                trackColor = WidgetTokens.withAlpha(theme.text, 0.10f),
                fillColor = WidgetTokens.withAlpha(tint, if (inIqamah) 0.70f else 0.45f),
                headColor = WidgetTokens.withAlpha(tint, 0.95f),
                fraction = (fraction * 10000).toInt(),
            ),
        )
        return views
    }

    // ── Bindings ───────────────────────────────────────────────────────────

    private fun bindSurface(
        context: Context,
        views: RemoteViews,
        theme: WidgetTheme.Resolved,
        widthDp: Float,
        heightDp: Float,
    ) {
        views.setImageViewBitmap(
            R.id.prayer_surface,
            WidgetArt.surface(
                context,
                theme.bg,
                theme.bgEnd,
                WidgetTheme.CORNER_RADIUS_DP.toFloat(),
                widthDp,
                heightDp,
            ),
        )
    }

    private fun bindFrame(
        views: RemoteViews,
        m: PrayerVerticalBudget.Metrics,
        density: Float,
    ) {
        views.setViewPadding(
            R.id.prayer_content,
            (m.sideInsetDp * density).roundToInt(),
            (m.topInsetDp * density).roundToInt(),
            (m.sideInsetDp * density).roundToInt(),
            (PrayerWidgetBudget.CARD_BOTTOM_INSET_DP * density).roundToInt(),
        )
        // The pill carries GAP_PILLS_COUNT on top of its own 2 dp, exactly as
        // the horizontal card prices it — the air is priced, so it is drawn.
        views.setViewPadding(
            R.id.prayer_countdown_pill,
            0,
            ((2f + PrayerWidgetBudget.GAP_PILLS_COUNT_DP) * density).roundToInt(),
            0,
            0,
        )
        // The inter-row gaps are REAL air between the boxes' backgrounds: the
        // four spacers grow from their 1 dp XML placeholder to the priced gap.
        // API 31+ — below S the placeholder stays, which is the tight look the
        // brief replaced; the rows still render.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val gapPx = (m.rowGapDp * density).roundToInt()
            for (id in ROW_GAP_IDS) {
                views.setViewLayoutHeight(id, gapPx.toFloat(), TypedValue.COMPLEX_UNIT_PX)
            }
        }
    }

    /**
     * The two-chip header. Hidden (GONE) on the COMPACT tier — the cell that
     * cannot hold it is a cell where the five rows matter more, and a band
     * that is not drawn is a band that is not charged for.
     */
    private fun bindHeader(
        context: Context,
        views: RemoteViews,
        theme: WidgetTheme.Resolved,
        model: PrayerWidgetModel,
        m: PrayerVerticalBudget.Metrics,
        density: Float,
    ) {
        if (m.isCompact) {
            views.setViewVisibility(R.id.prayer_header, View.GONE)
            return
        }
        views.setViewVisibility(R.id.prayer_header, View.VISIBLE)
        val muted = theme.token("muted", WidgetTokens.withAlpha(theme.text, 0.72f))
        val chipPadH = (PrayerWidgetBudget.CHIP_PAD_H_DP * density).roundToInt()
        val chipPadV = (PrayerWidgetBudget.CHIP_PAD_V_DP * density).roundToInt()
        val chipFill = WidgetTheme.neutralFill(
            context, theme.palette.light, "capsule", 16,
        ).takeIf { it != 0 } ?: context.resources.getIdentifier(
            "widget_capsule_w14", "drawable", context.packageName,
        )
        for (chip in intArrayOf(R.id.prayer_weekday_chip, R.id.prayer_city_chip)) {
            views.setViewPadding(chip, chipPadH, chipPadV, chipPadH, chipPadV)
            views.setInt(chip, "setBackgroundResource", chipFill)
        }
        val iconPx = (PrayerWidgetBudget.HEADER_ICON_DP * m.scale * density).roundToInt()
        val maxTextPx = (((m.widthDp - 2f * m.sideInsetDp) * 0.40f) * density).roundToInt()

        views.setTextViewTextSize(
            R.id.prayer_weekday, TypedValue.COMPLEX_UNIT_SP, m.headerSizeSp,
        )
        views.setTextColor(R.id.prayer_weekday, theme.text)
        views.setTextViewText(R.id.prayer_weekday, model.weekday)
        views.setInt(R.id.prayer_weekday, "setMaxWidth", maxTextPx)
        views.setImageViewBitmap(
            R.id.prayer_header_icon,
            WidgetArt.tintedIcon(
                context, R.drawable.widget_ic_crescent, theme.accent, iconPx,
            ),
        )
        // Under the forced RTL the icon is the chip's first child (right edge),
        // so the air toward the text is its LEFT.
        views.setViewPadding(R.id.prayer_header_icon, (4f * density).roundToInt(), 0, 0, 0)

        views.setTextViewTextSize(
            R.id.prayer_city, TypedValue.COMPLEX_UNIT_SP, m.headerSizeSp,
        )
        views.setTextColor(R.id.prayer_city, muted)
        views.setTextViewText(R.id.prayer_city, model.cityName.ifEmpty { "--" })
        views.setInt(R.id.prayer_city, "setMaxWidth", maxTextPx)
        views.setImageViewBitmap(
            R.id.prayer_city_icon,
            WidgetArt.tintedIcon(
                context, R.drawable.widget_ic_pin, theme.accent,
                (iconPx * 0.85f).roundToInt(),
            ),
        )
    }

    private fun bindClock(
        context: Context,
        views: RemoteViews,
        theme: WidgetTheme.Resolved,
        model: PrayerWidgetModel,
        m: PrayerVerticalBudget.Metrics,
        density: Float,
    ) {
        // removeAllViews FIRST, unconditionally: a tree that flips from FULL to
        // COMPACT must lose the leaf it carried, or the hidden slot would still
        // hold a ticking clock the next full render has to fight.
        views.removeAllViews(R.id.prayer_clock_slot)
        if (m.isCompact) {
            views.setViewVisibility(R.id.prayer_clock_slot, View.GONE)
            return
        }
        views.setViewVisibility(R.id.prayer_clock_slot, View.VISIBLE)
        views.addView(
            R.id.prayer_clock_slot,
            PrayerRemoteLeaves.clock(
                context = context,
                use12Hour = model.use12Hour,
                color = theme.text,
                sizeSp = m.clockSizeSp,
            ),
        )
        // Pin the slot to the PRICED box: the host replaces our TextClock with
        // its own subclass, whose line box is ~1.48 em instead of the 1.03 em
        // the budget prices. Without the pin the band is whatever the host's
        // font measures and the five rows pay for the difference — the exact
        // defect PrayerWidgetBudget.CLOCK_BOX_EM documents from the pixels.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setViewLayoutHeight(
                R.id.prayer_clock_slot,
                (m.clockBoxDp * density),
                TypedValue.COMPLEX_UNIT_PX,
            )
            views.setInt(R.id.prayer_clock, "setGravity", Gravity.CENTER)
        }
    }

    private fun bindDate(
        views: RemoteViews,
        theme: WidgetTheme.Resolved,
        model: PrayerWidgetModel,
        m: PrayerVerticalBudget.Metrics,
        density: Float,
    ) {
        if (m.isCompact) {
            views.setViewVisibility(R.id.prayer_date, View.GONE)
            return
        }
        views.setViewVisibility(R.id.prayer_date, View.VISIBLE)
        views.setTextViewTextSize(
            R.id.prayer_date, TypedValue.COMPLEX_UNIT_SP, m.dateSizeSp,
        )
        views.setTextColor(
            R.id.prayer_date,
            theme.token("muted", WidgetTokens.withAlpha(theme.text, 0.72f)),
        )
        // shamsi → hijri → gregorian: the order PrayerWidgetModel.dateLine
        // joins them in, and the order the app writes them in.
        views.setTextViewText(
            R.id.prayer_date,
            model.dateLine(withGregorian = m.showGregorian),
        )
        views.setViewPadding(
            R.id.prayer_date,
            0,
            (PrayerWidgetBudget.GAP_CLOCK_DATES_DP * density).roundToInt(),
            0,
            density.roundToInt(),
        )    }

    /**
     * One row: [check] name … time. The state half is shared with the tap
     * render; the geometry half runs on a full render only.
     */
    private fun bindRow(
        context: Context,
        views: RemoteViews,
        theme: WidgetTheme.Resolved,
        model: PrayerWidgetModel,
        index: Int,
        m: PrayerVerticalBudget.Metrics,
        density: Float,
        applyGeometry: Boolean,
    ) {
        val onNext = theme.token("onNext", 0xFF08352C.toInt())
        val isNext = model.nextIndex == index
        val isDone = model.isDone(index)
        val isMissed = model.isMissed(index)
        val isPast = model.isPast(index) && !isNext

        views.setTextViewText(NAME_IDS[index], model.label(index))
        views.setTextViewText(TIME_IDS[index], model.timeLabel(index))

        val fillRes = when {
            isNext -> WidgetTheme.nextFillRes(context, theme.palette.id)
                .takeIf { it != 0 }
                ?: WidgetTheme.neutralFill(context, theme.palette.light, "capsule", 14)
            isPast -> WidgetTheme.neutralFill(context, theme.palette.light, "capsule", 8)
            else -> WidgetTheme.neutralFill(context, theme.palette.light, "capsule", 14)
        }
        views.setInt(CAPSULE_IDS[index], "setBackgroundResource", fillRes)

        // The check slot holds its WIDTH without drawing anything on an
        // unticked row.
        //
        // 2026-11-07 brief: «این علامت — حذف شود، فقط وقتی تیک می‌زنم تیک
        // اضافه شود». The slot still reserves the check's size — that is what
        // keeps the five names on one axis («اسم نمازها موازی همدیگر باشند») —
        // but the placeholder is now a genuinely EMPTY bitmap. The previous
        // zero-alpha tint rasterised a faint white glyph, so every unticked
        // row showed a ghost ✓ that read as a «-» against the prayer.
        val checkPx = (m.checkDp * density).roundToInt()
        views.setImageViewBitmap(
            CHECK_IDS[index],
            if (isDone) {
                WidgetArt.tintedIcon(
                    context,
                    R.drawable.widget_ic_check,
                    if (isNext) onNext else theme.accent,
                    checkPx,
                )
            } else {
                WidgetArt.blank(checkPx)
            },
        )
        views.setViewVisibility(CHECK_IDS[index], View.VISIBLE)
        // The check is the name row's first child (right edge under RTL),
        // so the air toward the name is its LEFT — always applied now, so the
        // gap does not pop in when the mark arrives.
        views.setViewPadding(CHECK_IDS[index], 0, 0, (2f * density).roundToInt(), 0)

        val nameColor = when {
            isNext -> onNext
            isDone -> WidgetTokens.withAlpha(theme.text, 0.62f)
            isPast || isMissed -> WidgetTokens.withAlpha(theme.text, 0.55f)
            else -> WidgetTokens.withAlpha(theme.text, 0.85f)
        }
        val timeColor = when {
            isNext -> onNext
            isDone -> WidgetTokens.withAlpha(theme.text, 0.62f)
            isPast || isMissed -> WidgetTokens.withAlpha(theme.text, 0.55f)
            else -> WidgetTokens.withAlpha(theme.text, 0.92f)
        }
        views.setTextColor(NAME_IDS[index], nameColor)
        views.setTextColor(TIME_IDS[index], timeColor)
        views.setContentDescription(
            CAPSULE_IDS[index],
            PrayerWidgetModel.PRAYER_NAMES[index] + " " + model.timeLabel(index) +
                if (isDone) " خوانده شد" else "",
        )

        if (!applyGeometry) return
        views.setTextViewTextSize(
            NAME_IDS[index], TypedValue.COMPLEX_UNIT_SP, m.labelSizeSp,
        )
        views.setTextViewTextSize(
            TIME_IDS[index], TypedValue.COMPLEX_UNIT_SP, m.timeSizeSp,
        )
        val padH = (m.rowPadHDp * density).roundToInt()
        val padV = (m.rowPadDp * density).roundToInt()
        views.setViewPadding(CAPSULE_IDS[index], padH, padV, padH, padV)
    }

    /**
     * ONE countdown pill, two phases (brief 2026-11-08): «پایین دوتا بوکس تا
     * اذان ظهر و تا اقامه ظهر هست … یکی باشد مشترک یعنی تا اذان ظهر نشان دهد
     * وقتی اذان شد تا اقامه ظهر نشان دهد».
     *
     * Both the caption and the chronometer come from the SAME [CountdownInfo],
     * so they can never disagree: outside the iqamah window `targetAtMillis`
     * is the next adhan and the caption names it; inside the window the solver
     * has already retargeted it to the iqamah, and `isIqamahPhase` flips the
     * wording and the colour. There is no second view to hide any more.
     */
    private fun bindCountdown(
        views: RemoteViews,
        theme: WidgetTheme.Resolved,
        model: PrayerWidgetModel,
        m: PrayerVerticalBudget.Metrics,
        density: Float,
    ) {
        val show = model.countdown.targetAtMillis > 0L
        views.setViewVisibility(
            R.id.prayer_countdown_pill,
            if (show) View.VISIBLE else View.GONE,
        )
        if (!show) return

        val inIqamah = model.countdown.isIqamahPhase
        // A pure model function, so the phase switch has a unit test and the
        // shipped horizontal card keeps its longer «تا اقامه نماز …» copy.
        val caption = model.verticalCountdownCaption()
        val tint = if (inIqamah) IQAMAH_GOLD else theme.accent

        views.setTextViewTextSize(
            R.id.prayer_countdown_prefix, TypedValue.COMPLEX_UNIT_SP, m.countdownSizeSp,
        )
        views.setTextColor(
            R.id.prayer_countdown_prefix,
            WidgetTokens.withAlpha(theme.text, 0.85f),
        )
        views.setTextViewText(R.id.prayer_countdown_prefix, caption)
        views.setViewPadding(R.id.prayer_countdown_prefix, (5f * density).roundToInt(), 0, 0, 0)

        val remaining = model.countdown.targetAtMillis - System.currentTimeMillis()
        val base = SystemClock.elapsedRealtime() + remaining.coerceAtLeast(0L)
        views.setChronometer(R.id.prayer_countdown, base, "%s", true)
        views.setChronometerCountDown(R.id.prayer_countdown, true)
        views.setTextColor(R.id.prayer_countdown, tint)
        views.setTextViewTextSize(
            R.id.prayer_countdown, TypedValue.COMPLEX_UNIT_SP, m.countdownSizeSp,
        )

        // The pill's own background IS the bar — one rounded track with the
        // elapsed share filled from the start edge. The fill is ALWAYS drawn
        // (2026-11-07 brief: the old pref gate emptied the pill to a bare
        // track and the user read the bar as gone). In the iqamah phase it
        // wears the gold the deleted second pill used to carry, so merging
        // the two boxes costs nothing in legibility.
        val widthPx = ((m.widthDp - 2f * m.sideInsetDp) * density).roundToInt()
        val heightPx = (PrayerWidgetBudget.lineDp(
            maxOf(m.countdownSizeSp, m.captionSizeSp), m.fontScale,
        ) + 2f).let { (it * density).roundToInt() }
        val fraction = model.countdownFraction() ?: 0f
        views.setImageViewBitmap(
            R.id.prayer_progress,
            WidgetArt.progressPill(
                widthPx = widthPx,
                heightPx = heightPx,
                trackColor = WidgetTokens.withAlpha(theme.text, 0.10f),
                fillColor = WidgetTokens.withAlpha(tint, if (inIqamah) 0.70f else 0.45f),
                // The phase's leading bead: gold during «تا اقامه», accent
                // during «تا اذان» — the same polish the horizontal card got
                // in v4, painted from one shared bitmap helper.
                headColor = WidgetTokens.withAlpha(tint, 0.95f),
                fraction = (fraction * 10000).toInt(),
            ),
        )
    }

    private fun bindHint(
        views: RemoteViews,
        theme: WidgetTheme.Resolved,
        model: PrayerWidgetModel,
    ) {
        val show = !model.hasData
        views.setViewVisibility(R.id.prayer_hint, if (show) View.VISIBLE else View.GONE)
        if (!show) return
        views.setTextViewText(R.id.prayer_hint, ONBOARDING_HINT)
        views.setTextColor(
            R.id.prayer_hint, WidgetTokens.withAlpha(theme.text, 0.72f),
        )
        views.setTextViewTextSize(R.id.prayer_hint, TypedValue.COMPLEX_UNIT_SP, 10f)
    }

    // ── Intents ────────────────────────────────────────────────────────────

    /**
     * The tap map, identical in contract to the horizontal card's: each row
     * owns its own «خواندم» intent, and every other pixel opens the app. The
     * request code is `widgetId * 10 + 30 + index` — the same formula, and it
     * cannot collide, because one widget instance is either the horizontal
     * card or the vertical one, never both.
     */
    private fun bindClicks(context: Context, views: RemoteViews, widgetId: Int) {
        views.setOnClickPendingIntent(R.id.prayer_surface, PrayerRemoteLeaves.openApp(context))
        views.setOnClickPendingIntent(R.id.prayer_native_root, PrayerRemoteLeaves.openApp(context))
        for (index in 0 until 5) {
            views.setOnClickPendingIntent(CAPSULE_IDS[index], markIntent(context, widgetId, index))
        }
    }

    private fun markIntent(context: Context, widgetId: Int, index: Int): PendingIntent {
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getActivity(
            context,
            widgetId * 10 + 30 + index,
            PrayerMarkActivity.intent(context, widgetId, index),
            flags,
        )
    }

    // ── Sizing ─────────────────────────────────────────────────────────────

    private fun density(context: Context): Float =
        context.resources.displayMetrics.density.takeIf { it > 0f && it < 100f } ?: 1f

    private fun fontScale(context: Context): Float =
        context.resources.configuration.fontScale
            .takeIf { it.isFinite() && it > 0f }?.coerceIn(0.85f, 1.6f) ?: 1f

    private fun cell(
        context: Context,
        widgetId: Int,
        override: Pair<Float, Float>?,
    ): Pair<Float, Float> {
        if (override != null) return override
        val options = AppWidgetManager.getInstance(context).getAppWidgetOptions(widgetId)
        val widthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            .takeIf { it > 0 }?.toFloat() ?: 250f
        val heightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
            .takeIf { it > 0 }?.toFloat() ?: 174f
        return widthDp to heightDp
    }
}
