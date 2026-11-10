package com.islamic.tawheeed.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
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
 * The prayer card as hand-built RemoteViews — the architecture the tasbih card
 * proved on this launcher.
 *
 * ## Why not Glance
 *
 * Both facts are device-measured (POCO X7 Pro, HyperOS, Android 16):
 *
 *  1. **Tap latency.** A capsule tap went broadcast → prefs toggle → a FULL
 *     Glance recomposition. Measured 2026-11-04: the receiver committed in
 *     +37 ms, but the composition only reached `compose palette=…` at
 *     +444 ms — the card visibly changed half a second after the tap. Glance
 *     cannot be patched into partial updates either: its decompiled
 *     `RemoteViewsTranslatorKt` inserts every Glance leaf view as a CHILD of
 *     a Glance-generated root (`insertView`), so the root layoutId is never
 *     ours and `AppWidgetHostView.canRecycleView` can never recycle the tree.
 *  2. **Budget honesty.** The Glance card drew bands the budget never priced
 *     (a 34 dp countdown pill, the 20 dp icon holders, the header row, the
 *     card's own paddings). The weighted capsule row absorbed every
 *     shortfall, and on the default cell it rendered ~39 dp for ~70 dp of
 *     content — only icons showed, names and times were sliced
 *     («اوقات نماز در حجم فعلی ظاهر نیستند»).
 *
 * ## The two renders
 *
 * [full] paints everything: the surface, the header, the live clock leaf, the
 * date line, the five capsules, the countdown pill and the tap intents. It
 * runs on placement, resize, snapshot push, and the boundary/minute/watchdog
 * alarms — rare events that already pay for a full pass.
 *
 * [capsules] paints ONLY what a tap can change — the five capsules' texts,
 * colors, fills and glyphs — and is applied with
 * `AppWidgetManager.partiallyUpdateAppWidget`, which merges those setters into
 * the view the launcher already inflated. No re-inflation, no composition: a
 * tap lands in a frame, and the surface bitmap (the largest thing in the tree)
 * never crosses the binder again.
 *
 * Every dimension comes from [PrayerWidgetBudget] — the unit-tested budget
 * whose rule is *every other band is totalled first and the clock takes what
 * is left* — so the card draws exactly what was priced, on every launcher's
 * default and resized cell alike.
 */
internal object PrayerNativeViews {

    private const val TAG = "TawheeedPrayerNative"

    /** The «تا اقامه» phase's gold — close to the accent family but distinct
     *  from it, per the brief («با رنگ دیگر نزدیک به طلایی»). Since v4 the ONE
     *  pill turns gold as a whole while it counts to the iqamah, exactly like
     *  the vertical card; there is no second gold pill any more. */
    private val IQAMAH_GOLD = 0xFFC9A227.toInt()

    /** The per-capsule id groups of [R.layout.widget_prayer_native_v4]. */
    private val CAPSULE_IDS = intArrayOf(
        R.id.prayer_capsule_0, R.id.prayer_capsule_1, R.id.prayer_capsule_2,
        R.id.prayer_capsule_3, R.id.prayer_capsule_4,
    )

    /** The three date boxes, in drawing order: shamsi, hijri, Gregorian. */
    private val DATE_IDS = intArrayOf(
        R.id.prayer_date, R.id.prayer_date_2, R.id.prayer_date_3,
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

    /** The widget-instance key a tap intent carries, so the repaint can be
     *  partial and addressed to exactly the card the user touched. */
    const val EXTRA_APP_WIDGET_ID = "prayer_app_widget_id"

    /** The component every prayer render and intent points at. */
    fun component(context: Context): ComponentName =
        ComponentName(context, PrayerWidget::class.java)

    /**
     * The single layout decision for a widget instance, shared by [full] and
     * [capsules] so a full render and a tap merge can never disagree on the
     * layout id (a disagreement would blank the card on the first tap).
     *
     * A widget whose provider IS [PrayerWidgetVertical] is always vertical —
     * the dedicated provider is an explicit "I want the vertical card" choice,
     * regardless of the legacy global `widget_prayer_layout` pref. Everything
     * else falls back to the pref-driven decision the horizontal provider has
     * always used (so a pre-existing horizontal-provider widget that was set to
     * "vertical" still renders vertical), with its overflow guard.
     */
    private fun useVertical(
        context: Context,
        widgetId: Int,
        cellOverride: Pair<Float, Float>?,
    ): Boolean =
        isVerticalWidget(context, widgetId) ||
            PrayerVerticalViews.shouldRenderVertical(context, widgetId, cellOverride)

    /**
     * True when the widget instance's provider component is the vertical one.
     *
     * The provider class is the authoritative "this card is the vertical one"
     * signal — a dedicated [PrayerWidgetVertical] widget is vertical
     * regardless of the legacy `widget_prayer_layout` pref. The primary check
     * reads `getAppWidgetInfo`, which is transiently null right after a resize
     * or a launcher restore, so on that miss we fall back to id-list
     * membership (cheap, and only run on the rare null case) rather than
     * concluding "not vertical" and routing the card to the horizontal layout.
     */
    private fun isVerticalWidget(context: Context, widgetId: Int): Boolean {
        val manager = AppWidgetManager.getInstance(context)
        val className = try {
            manager.getAppWidgetInfo(widgetId)?.provider?.className
        } catch (_: Throwable) {
            null
        }
        if (className == PrayerWidgetVertical::class.java.name) return true
        return try {
            manager
                .getAppWidgetIds(ComponentName(context, PrayerWidgetVertical::class.java))
                ?.contains(widgetId) == true
        } catch (_: Throwable) {
            false
        }
    }

    // ── Full render ────────────────────────────────────────────────────────

    fun full(
        context: Context,
        widgetId: Int,
        /** Development only: [WidgetAudit] renders the card for a cell it is
         *  not placed on. Production callers never pass this. */
        cellOverride: Pair<Float, Float>? = null,
        /** When non-null, forces the layout decision. `true` always draws the
         *  vertical card (the dedicated [PrayerWidgetVertical] provider),
         *  `false` always draws the horizontal card. When null, the layout is
         *  resolved per widget by [useVertical] — by the widget's actual
         *  provider component (so the two providers never clash) and, for the
         *  horizontal provider, by the legacy `widget_prayer_layout` pref. */
        forceVertical: Boolean? = null,
    ): RemoteViews {
        // «چیدمان ویجت اوقات نماز» — the second layout, purely additive.
        //
        // With `widget_prayer_layout` absent (every install that has never
        // opened the option) this returns false and every line below runs
        // exactly as it did before the option existed. The vertical card is a
        // separate object with its own layout id and its own budget, so it
        // cannot change a single pixel of this one.
        if (forceVertical ?: useVertical(context, widgetId, cellOverride)) {
            return PrayerVerticalViews.full(context, widgetId, cellOverride)
        }
        val theme = WidgetTheme.resolve(context, WidgetTheme.WidgetTarget.PRAYER, widgetId)
        val model = PrayerWidgetModel.read(context)
        val m = metrics(context, widgetId, model, cellOverride)
        val views = RemoteViews(
            context.packageName,
            if (m.isSmall) R.layout.widget_prayer_native_small else R.layout.widget_prayer_native_v4,
        )

        bindSurface(context, views, theme, widgetId)
        bindClicks(context, views, widgetId, m.isSmall)
        bindFrame(views, m)
        if (m.isSmall) {
            bindSmall(context, views, theme, model, m)
        } else {
            bindHeader(context, views, theme, model, m)
            bindDate(views, theme, model, m)
            bindCountdown(views, theme, model, m)
        }
        // The clock leaf LAST among the header-area binds: it is swapped into
        // its slot with removeAllViews + addView, and nothing below depends on
        // slot state.
        bindClock(context, views, model, m)
        // The compact layout has no capsules BY DESIGN. RemoteViews throws an
        // ActionException for a setter addressed to a view that is not in the
        // layout, so a missing id is not a harmless no-op here.
        if (!m.isSmall) {
            for (index in 0 until 5) {
                bindCapsule(context, views, theme, model, index, m, applyGeometry = true)
            }
        }
        bindHint(views, theme, model, m)
        // The one measured trace a frozen or clipped card needs: what sizes
        // THIS render priced, for which cell and tier.
        logRender(widgetId, m.isSmall, m)
        return views
    }

    // ── Tap render ─────────────────────────────────────────────────────────

    /**
     * The subset a tap can change: the five capsules' state fills, glyph
     * bitmaps, name/time texts and colors. Deliberately excludes the surface,
     * the type sizes, the paddings and the clock slot — a tap merge preserves
     * the geometry the launcher already inflated, so the tap costs no layout
     * work at all.
     *
     * Only the full card carries capsule taps, so this is only ever applied
     * to a hierarchy that has the capsule ids.
     */
    fun capsules(context: Context, widgetId: Int, forceVertical: Boolean? = null): RemoteViews {
        // A tap merge must address the layout the card was inflated from: a
        // partial RemoteViews carrying a different layout id makes the host
        // inflate a fresh, empty tree instead of merging the setters, which
        // would blank the card on the first tap. Both renders therefore read
        // the layout from the same source.
        if (forceVertical ?: useVertical(context, widgetId, null)) {
            return PrayerVerticalViews.capsules(context, widgetId)
        }
        val theme = WidgetTheme.resolve(context, WidgetTheme.WidgetTarget.PRAYER, widgetId)
        val model = PrayerWidgetModel.read(context)
        val m = metrics(context, widgetId, model)
        val views = RemoteViews(context.packageName, R.layout.widget_prayer_native_v4)
        for (index in 0 until 5) {
            bindCapsule(context, views, theme, model, index, m, applyGeometry = false)
        }
        return views
    }

    /**
     * A PARTIAL render for the progress tick: builds RemoteViews from the SAME
     * layout the full card used and sets ONLY [R.id.prayer_progress], so the
     * launcher merges the new pill bitmap into the tree it already inflated. The
     * clock leaf, the capsules and the surface are never re-sent. Returns null
     * for a compact widget (it has no progress pill).
     */
    fun progressOnly(
        context: Context,
        widgetId: Int,
        forceVertical: Boolean? = null,
    ): RemoteViews? {
        if (forceVertical ?: useVertical(context, widgetId, null)) {
            return PrayerVerticalViews.progressOnly(context, widgetId)
        }
        val theme = WidgetTheme.resolve(context, WidgetTheme.WidgetTarget.PRAYER, widgetId)
        val model = PrayerWidgetModel.read(context)
        val m = metrics(context, widgetId, model)
        if (m.isSmall) return null
        val views = RemoteViews(context.packageName, R.layout.widget_prayer_native_v4)
        val inIqamah = model.countdown.isIqamahPhase
        val tint = if (inIqamah) IQAMAH_GOLD else theme.accent
        val fraction = model.countdownFraction() ?: 0f
        views.setImageViewBitmap(
            R.id.prayer_progress,
            WidgetArt.progressPill(
                widthPx = m.pillWidthPx,
                heightPx = m.pillHeightPx,
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
        widgetId: Int,
    ) {
        val (widthDp, heightDp) = cell(context, widgetId)
        // The palette's gradient with the corners painted INTO the bitmap, so
        // the rounded shape survives launchers that ignore an outline radius.
        // The generated skin drawables are NOT used here: an ImageView slot
        // takes a bitmap, and WidgetArt.surface caches by size, so a tap
        // partial render (which never re-binds the surface) and a resize both
        // reuse the previous pixels.
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

    /**
     * The card's frame: the side/top inset the budget prices, the capsule
     * row's width cap, and the pill's own row air.
     *
     * Every one of these was priced by the budget and drawn by nothing before
     * 2026-11-04's second brief: the content had NO padding, so the header
     * sat on the card's top edge («اسم شهر و روز زیادی رفته بالا») and ran
     * past both sides («از راست و چپ هم بیرون زده») while the pill's bitmap
     * was computed as `width - 2 × 12 dp`.
     */
    private fun bindFrame(views: RemoteViews, m: Metrics) {
        views.setViewPadding(
            R.id.prayer_content,
            m.sideInsetPx, m.topInsetPx, m.sideInsetPx, m.bottomInsetPx,
        )
        // The compact layout has neither a capsule row nor a countdown pill;
        // a setter for a view that is not in the layout is an ActionException
        // at apply time, not a no-op.
        if (m.isSmall) return
        // On a wide cell the five boxes stop stretching and stay a readable
        // width, centred by equal side padding («در حالت بزرگ کردن ویجت …
        // باکس‌ها خیلی کشیده می‌شوند»).
        // The row carries GAP_DATES_PILLS on top of its own 2 dp. That gap used
        // to be priced as a separate band and drawn by nothing, so the card
        // reserved 4 dp it never used — the same class of defect as the
        // phantom progress and verse bands.
        views.setViewPadding(
            R.id.prayer_capsule_row,
            m.rowSidePadPx,
            m.densityPx(2f + PrayerWidgetBudget.GAP_DATES_PILLS_DP),
            m.rowSidePadPx,
            m.densityPx(2f),
        )
        // ...and the pill carries GAP_PILLS_COUNT on top of its own 2 dp, for
        // the same reason.
        views.setViewPadding(
            R.id.prayer_countdown_pill,
            0,
            m.densityPx(2f + PrayerWidgetBudget.GAP_PILLS_COUNT_DP),
            0,
            0,
        )
    }

    /**
     * Row 1: the weekday chip | the city chip. Two pills of the same fill, the
     * same air and the same icon size — «روز هم مثل شهر در بوکسی قرار بگیرد».
     *
     * Both texts are width-capped: a wrap_content TextView ignores `ellipsize`
     * without a width bound, and that was half of the «از راست و چپ هم بیرون
     * زده» report.
     */
    private fun bindHeader(
        context: Context,
        views: RemoteViews,
        theme: WidgetTheme.Resolved,
        model: PrayerWidgetModel,
        m: Metrics,
    ) {
        val muted = theme.token("muted", WidgetTokens.withAlpha(theme.text, 0.72f))
        // The two chips share one geometry, so they cannot drift apart.
        for (chip in intArrayOf(R.id.prayer_weekday_chip, R.id.prayer_city_chip)) {
            views.setViewPadding(chip, m.chipPadHPx, m.chipPadVPx, m.chipPadHPx, m.chipPadVPx)
            views.setInt(chip, "setBackgroundResource", m.chipFillRes)
        }

        views.setTextViewTextSize(
            R.id.prayer_weekday, TypedValue.COMPLEX_UNIT_SP, PrayerWidgetBudget.HEADER_TEXT_SP,
        )
        views.setTextColor(R.id.prayer_weekday, theme.text)
        views.setTextViewText(R.id.prayer_weekday, model.weekday)
        views.setInt(R.id.prayer_weekday, "setMaxWidth", m.headerTextMaxPx)
        views.setImageViewBitmap(
            R.id.prayer_header_icon,
            WidgetArt.tintedIcon(
                context, R.drawable.widget_ic_crescent, theme.accent, m.headerIconPx,
            ),
        )
        // The gap between a chip's icon and its text. Under the forced RTL the
        // icon is the chip's FIRST child and hugs the RIGHT edge, while padding
        // stays physical — so the air toward the text is its LEFT.
        views.setViewPadding(R.id.prayer_header_icon, m.gap4Px, 0, 0, 0)

        val city = model.cityName.ifEmpty { "--" }
        views.setTextViewTextSize(
            R.id.prayer_city, TypedValue.COMPLEX_UNIT_SP, PrayerWidgetBudget.HEADER_TEXT_SP,
        )
        views.setTextColor(R.id.prayer_city, muted)
        views.setTextViewText(R.id.prayer_city, city)
        views.setInt(R.id.prayer_city, "setMaxWidth", m.headerTextMaxPx)
        views.setImageViewBitmap(
            R.id.prayer_city_icon,
            WidgetArt.tintedIcon(context, R.drawable.widget_ic_pin, theme.accent, m.cityIconPx),
        )
    }

    private fun bindClock(
        context: Context,
        views: RemoteViews,
        model: PrayerWidgetModel,
        m: Metrics,
    ) {
        // removeAllViews BEFORE addView — the order AOSP's own RemoteViews docs
        // demand for predictable re-use of a nested view across updates.
        views.removeAllViews(R.id.prayer_clock_slot)
        if (PrayerRemoteLeaves.enabled(context)) {
            views.addView(
                R.id.prayer_clock_slot,
                PrayerRemoteLeaves.clock(
                    context = context,
                    use12Hour = model.use12Hour,
                    color = m.clockColor,
                    sizeSp = m.clockSizeSp,
                ),
            )
        } else {
            // The host refused the live leaf: bake the value into the SAME slot
            // and let PrayerWidget.scheduleMinuteTick carry the tick. The slot's
            // height is pinned below either way, so the card's bands do not
            // move when the leaf is replaced.
            views.addView(
                R.id.prayer_clock_slot,
                RemoteViews(context.packageName, R.layout.widget_prayer_clock_baked).apply {
                    setTextColor(R.id.prayer_clock_baked, m.clockColor)
                    setTextViewTextSize(
                        R.id.prayer_clock_baked,
                        android.util.TypedValue.COMPLEX_UNIT_SP,
                        m.clockSizeSp,
                    )
                    setTextViewText(
                        R.id.prayer_clock_baked,
                        PrayerRemoteLeaves.bakedClock(model),
                    )
                    setOnClickPendingIntent(
                        R.id.prayer_clock_baked,
                        PrayerRemoteLeaves.openApp(context),
                    )
                },
            )
        }
        // PIN THE SLOT TO THE PRICED BOX.
        //
        // The slot is `wrap_content`, so its height is whatever the host's
        // TextClock measures — and the host replaces our TextClock with its own
        // subclass, whose typeface is a fallback with a ~1.48 em line box rather
        // than the ~1.0 em this card's own text gets. Measured on the POCO at
        // 331×269 dp: a 116.6 dp priced box rendered 174 dp, and the 57 dp came
        // out of the weighted capsule row, which was left 11 dp — five empty
        // boxes and a 60 dp hole above the date line. The pixels that proved it
        // are quoted in PrayerWidgetBudget.CLOCK_BOX_EM.
        //
        // setViewLayoutHeight (API 31) makes the band the budget's number
        // instead of the host's font metric. Below 31 the slot keeps
        // wrap_content: the card is then a little taller at the clock and a
        // little tighter at the boxes, but it still renders.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setViewLayoutHeight(
                R.id.prayer_clock_slot,
                m.clockBoxPx.toFloat(),
                TypedValue.COMPLEX_UNIT_PX,
            )
            // ...and centre the clock inside it. A pinned box is shorter than
            // the host's line box, so a top-aligned line would draw its glyphs
            // against the box's top edge and lose the descender of the box. With
            // CENTER the ink stays centred in the box whatever the line metrics
            // turn out to be — the ink is ~0.72 em and the box 0.86 em, so it
            // always fits with air on both sides.
            views.setInt(R.id.prayer_clock, "setGravity", Gravity.CENTER)
        }
    }

    private fun bindDate(
        views: RemoteViews,
        theme: WidgetTheme.Resolved,
        model: PrayerWidgetModel,
        m: Metrics,
    ) {
        val muted = theme.token("muted", WidgetTokens.withAlpha(theme.text, 0.72f))
        val parts = model.dateParts(withGregorian = m.showGregorian)
            .ifEmpty { listOf("--") }
        // The band is ONE line tall whatever the number of boxes: their fill is
        // the same neutral chip the capsules wear and their vertical padding is
        // 0, so boxing the dates costs the budget nothing. Only the horizontal
        // padding is added, and it is what reads as the gap between boxes.
        views.setViewPadding(R.id.prayer_date_row, 0, m.gapDatesPx, 0, m.densityPx(1f))
        for (index in DATE_IDS.indices) {
            val id = DATE_IDS[index]
            val text = parts.getOrNull(index)
            if (text == null) {
                // RemoteViews refuses a setter on an id the inflated layout
                // does not have, so the extra boxes are GONE, never removed.
                views.setViewVisibility(id, View.GONE)
                continue
            }
            views.setViewVisibility(id, View.VISIBLE)
            views.setTextViewTextSize(
                id, TypedValue.COMPLEX_UNIT_SP, PrayerWidgetBudget.DATE_TEXT_SP,
            )
            views.setTextColor(id, muted)
            views.setTextViewText(id, text)
            views.setInt(id, "setBackgroundResource", m.dateChipRes)
            views.setViewPadding(id, m.dateChipPadPx, 0, m.dateChipPadPx, 0)
        }
    }

    /**
     * Row 5: the ONE countdown pill, with the phase bar inside it.
     *
     * The brief (2026-11-04): «نوشته تا اذان صبح و ساعت باقیمانده یک سایز
     * باشند فونتشون ووسط قرار بگیرند نه سمت راست» — caption and value share
     * ONE type size and sit centred as a single unit.
     *
     * The brief (2026-11-08): «تا اقامه جالب عرضه نمی‌شود … اذان که گفت تا
     * اقامه نوار پیشرفت از اول شروع بشود و نوار پیشرفت که پر شد دوباره بیاید
     * تا اذان و نوار پیشرفت از اول شروع بشود … برای هر دو ویجت اوقات عمودی و
     * افقی … رنگ تا اقامه هم نوارش طلایی باشد». The SECOND gold pill that used
     * to sit under this one is gone (v4 deletes it); this single pill now
     * carries the whole cycle: caption, chronometer tint, bar colour and bar
     * fill all switch together at the same boundary.
     */
    private fun bindCountdown(
        views: RemoteViews,
        theme: WidgetTheme.Resolved,
        model: PrayerWidgetModel,
        m: Metrics,
    ) {
        // The pill shows whenever there is a countdown to show. It is NOT
        // gated on «نمایش نوار پیشرفت»: that setting names the progress FILL,
        // and letting it hide the pill as well took the countdown away with
        // the bar — the «نوار پیشرفت حذف شده» report, where the user lost the
        // remaining time too. The fill below is the only thing it may switch
        // off.
        val show = model.countdown.targetAtMillis > 0L
        views.setViewVisibility(
            R.id.prayer_countdown_pill,
            if (show) View.VISIBLE else View.GONE,
        )
        if (!show) return

        val inIqamah = model.countdown.isIqamahPhase
        // The gold the deleted second pill used to wear. The value, the fill
        // and the leading bead ALL wear the same tint, so the phase is legible
        // at a glance without a second box.
        val tint = if (inIqamah) IQAMAH_GOLD else theme.accent

        // iqamahPrefix already switches between «تا اذان X» and
        // «تا اقامه نماز X» from the same CountdownInfo as the chronometer.
        views.setTextViewTextSize(
            R.id.prayer_countdown_prefix, TypedValue.COMPLEX_UNIT_SP, m.countdownSp,
        )
        views.setTextColor(
            R.id.prayer_countdown_prefix,
            WidgetTokens.withAlpha(theme.text, 0.85f),
        )
        views.setTextViewText(R.id.prayer_countdown_prefix, model.iqamahPrefix)
        // The gap between caption and value: under the forced RTL the caption
        // is the row's first child (right edge), so the air sits on its
        // physical LEFT.
        views.setViewPadding(R.id.prayer_countdown_prefix, m.gap5Px, 0, 0, 0)

        val remaining = model.countdown.targetAtMillis - System.currentTimeMillis()
        // A boundary render that arrives late still clamps to zero: a base in
        // the future would run UP from a wrong value.
        val base = SystemClock.elapsedRealtime() + remaining.coerceAtLeast(0L)
        views.setChronometer(R.id.prayer_countdown, base, "%s", true)
        views.setChronometerCountDown(R.id.prayer_countdown, true)
        views.setTextColor(R.id.prayer_countdown, tint)
        views.setTextViewTextSize(
            R.id.prayer_countdown, TypedValue.COMPLEX_UNIT_SP, m.countdownSp,
        )

        // countdownFraction() measures from the boundary that OPENED this
        // phase, so it is exactly 0 at the adhan (gold bar starts) and exactly
        // 0 again at the iqamah end (accent «تا اذان» bar starts). The old
        // progressFraction() measured adhan→adhan instead — during «تا اقامه»
        // it took the midnight branch and sat at ~full, and on the way back
        // it was already ~7 % full. That is the «جالب عرضه نمی‌شود» report.
        val fraction = model.countdownFraction() ?: 0f
        views.setImageViewBitmap(
            R.id.prayer_progress,
            WidgetArt.progressPill(
                widthPx = m.pillWidthPx,
                heightPx = m.pillHeightPx,
                trackColor = WidgetTokens.withAlpha(theme.text, 0.10f),
                fillColor = WidgetTokens.withAlpha(tint, if (inIqamah) 0.70f else 0.45f),
                headColor = WidgetTokens.withAlpha(tint, 0.95f),
                fraction = (fraction * 10000).toInt(),
            ),
        )
    }

    /**
     * One capsule. [applyGeometry] is the full-render-only half (paddings and
     * type sizes); the state half runs on both renders, which is what makes a
     * tap land in a frame.
     */
    private fun bindCapsule(
        context: Context,
        views: RemoteViews,
        theme: WidgetTheme.Resolved,
        model: PrayerWidgetModel,
        index: Int,
        m: Metrics,
        applyGeometry: Boolean,
    ) {
        val onNext = theme.token("onNext", 0xFF08352C.toInt())
        val isNext = model.nextIndex == index
        val isDone = model.isDone(index)
        val isMissed = model.isMissed(index)
        val isPast = model.isPast(index) && !isNext

        // ── State ──
        views.setTextViewText(NAME_IDS[index], model.label(index))
        views.setTextViewText(TIME_IDS[index], model.timeLabel(index))

        // The state fill: the palette's own nextFill drawable for the next
        // capsule, the shared neutrals for the rest. A 0 id (a palette that
        // predates a generator run) falls back to the mid neutral.
        val fillRes = when {
            isNext -> WidgetTheme.nextFillRes(context, theme.palette.id)
                .takeIf { it != 0 } ?: m.capsuleFillRes14
            isPast -> m.capsuleFillRes8
            else -> m.capsuleFillRes14
        }
        views.setInt(CAPSULE_IDS[index], "setBackgroundResource", fillRes)

        // The done state: a check beside the name, drawn ONLY when the prayer
        // is done.
        //
        // It used to live in a 20 dp icon holder the budget dropped on the
        // default cell, so a tap wrote its mark and showed nothing
        // («فقط نماز مغرب قابل تیک زدن هست» — the mark was in fact written
        // for all five, device-verified). The check is now inline in the name
        // row and costs no band: the budget prices it inside the name line.
        //
        // 2026-11-07 brief, third pass: «وقتی تیک نزدم صبح و ظهر … وسط باشند و
        // وقتی تیک زدم با تیک وسط قرار بگیرند» — the slot is GONE, not a
        // transparent placeholder. The name row is wrap_content inside a
        // centre_horizontal capsule, so an unticked box centres the NAME alone
        // and a ticked one centres the [check + name] pair as a unit. The
        // earlier «always occupied» placeholder kept the names on a common
        // axis but left an unticked box visibly off-centre — and, because a
        // zero-alpha tint still rasterised a ghost glyph, it also showed a
        // mark against the prayers the user had not prayed.
        val showCheck = isDone
        views.setViewVisibility(
            CHECK_IDS[index],
            if (showCheck) View.VISIBLE else View.GONE,
        )
        if (showCheck) {
            views.setImageViewBitmap(
                CHECK_IDS[index],
                WidgetArt.tintedIcon(
                    context,
                    R.drawable.widget_ic_check,
                    if (isNext) onNext else theme.accent,
                    m.checkPx,
                ),
            )
            // Under the forced RTL the check is the name row's FIRST child
            // (right edge), so the air toward the name is its LEFT.
            views.setViewPadding(CHECK_IDS[index], 0, 0, m.checkGapPx, 0)
        }

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
        // ── Geometry (full render only) ──
        views.setTextViewTextSize(
            NAME_IDS[index], TypedValue.COMPLEX_UNIT_SP, m.pillLabelSp,
        )
        views.setTextViewTextSize(
            TIME_IDS[index], TypedValue.COMPLEX_UNIT_SP, m.pillTimeSp,
        )
        views.setViewPadding(
            CAPSULE_IDS[index],
            m.densityPx(1f), m.capsulePadPx, m.densityPx(1f), m.capsulePadPx,
        )
    }

    private fun bindHint(
        views: RemoteViews,
        theme: WidgetTheme.Resolved,
        model: PrayerWidgetModel,
        m: Metrics,
    ) {
        val show = !model.hasData
        views.setViewVisibility(R.id.prayer_hint, if (show) View.VISIBLE else View.GONE)
        if (!show) return
        views.setTextViewText(R.id.prayer_hint, ONBOARDING_HINT)
        views.setTextColor(R.id.prayer_hint, WidgetTokens.withAlpha(theme.text, 0.72f))
        views.setTextViewTextSize(
            R.id.prayer_hint,
            TypedValue.COMPLEX_UNIT_SP,
            if (m.isSmall) 12f else 9f,
        )
    }

    /** The compact tier: clock, city, one date line, hijri line, countdown. */
    private fun bindSmall(
        context: Context,
        views: RemoteViews,
        theme: WidgetTheme.Resolved,
        model: PrayerWidgetModel,
        m: Metrics,
    ) {
        val textColor = theme.text
        val sep = WidgetTokens.withAlpha(textColor, 0.15f)
        views.setTextViewTextSize(R.id.prayer_small_city, TypedValue.COMPLEX_UNIT_SP, 12f)
        views.setTextColor(R.id.prayer_small_city, textColor)
        views.setTextViewText(R.id.prayer_small_city, model.cityName)
        views.setViewPadding(R.id.prayer_small_city, 0, m.densityPx(2f), 0, 0)

        views.setTextViewTextSize(R.id.prayer_small_date, TypedValue.COMPLEX_UNIT_SP, 10f)
        views.setTextColor(R.id.prayer_small_date, WidgetTokens.withAlpha(textColor, 0.72f))
        views.setTextViewText(R.id.prayer_small_date, model.smallDate)
        views.setViewPadding(R.id.prayer_small_date, 0, m.densityPx(1f), 0, 0)

        views.setTextViewTextSize(R.id.prayer_small_hijri, TypedValue.COMPLEX_UNIT_SP, 8f)
        views.setTextColor(R.id.prayer_small_hijri, WidgetTokens.withAlpha(textColor, 0.55f))
        views.setTextViewText(R.id.prayer_small_hijri, model.hijriDate.ifEmpty { "--" })
        views.setViewPadding(R.id.prayer_small_hijri, 0, m.densityPx(1f), 0, 0)

        views.setInt(R.id.prayer_small_divider, "setBackgroundColor", sep)
        views.setViewPadding(R.id.prayer_small_divider, 0, m.densityPx(4f), 0, 0)

        // «تا اذان صبح  ۸:۴۷:۴۴» — one pill, caption and value at the SAME
        // size, centred (the same brief line the full card's pill obeys).
        // The COMPACT tier has no bitmap bar (its row is a plain tinted
        // background), but it still wears the phase: during «تا اقامه» the
        // value and its wash turn the same gold as the two full cards. That
        // is a colour setter only — no structural change, so no rename.
        val inIqamah = model.countdown.isIqamahPhase
        val phaseColor = if (inIqamah) IQAMAH_GOLD else textColor
        val prefix = model.iqamahPrefix
        views.setTextViewTextSize(
            R.id.prayer_countdown_prefix, TypedValue.COMPLEX_UNIT_SP, m.countdownSp,
        )
        views.setTextColor(R.id.prayer_countdown_prefix, WidgetTokens.withAlpha(textColor, 0.85f))
        views.setTextViewText(R.id.prayer_countdown_prefix, prefix)
        views.setViewPadding(R.id.prayer_countdown_prefix, m.gap5Px, 0, 0, 0)

        val remaining = model.countdown.targetAtMillis - System.currentTimeMillis()
        val base = SystemClock.elapsedRealtime() + remaining.coerceAtLeast(0L)
        views.setChronometer(R.id.prayer_countdown, base, "%s", true)
        views.setChronometerCountDown(R.id.prayer_countdown, true)
        views.setTextColor(R.id.prayer_countdown, phaseColor)
        views.setTextViewTextSize(
            R.id.prayer_countdown, TypedValue.COMPLEX_UNIT_SP, m.countdownSp,
        )
        views.setViewPadding(
            R.id.prayer_countdown_row,
            m.densityPx(12f), m.densityPx(2f), m.densityPx(12f), m.densityPx(2f),
        )
        views.setInt(
            R.id.prayer_countdown_row,
            "setBackgroundColor",
            WidgetTokens.withAlpha(phaseColor, if (inIqamah) 0.18f else 0.13f),
        )
    }

    // ── Intents ────────────────────────────────────────────────────────────

    /**
     * The tap map.
     *
     * ## Measured on the device, 2026-11-05
     *
     * A press was injected down one capsule's column at 13 points and the
     * action the app received was logged for each:
     *
     *   • y 580…700 — the pill — `tap.prefs.committed prayer=2`, the tick lands;
     *   • y 560, 720, 740 — outside the pill — the app opens.
     *
     * So the arrangement is exactly what it looks like: each capsule owns its
     * pill, and every other pixel falls through the non-clickable content
     * column to the two intents that open the app — `prayer_surface`, the
     * full-bleed ImageView behind the content, and the root as a backstop.
     *
     * A clickable child DOES win over the clickable root on this launcher. The
     * earlier belief that HyperOS routes every widget touch to the root came
     * from a mis-measurement: `adb shell input tap` injects a ZERO-DURATION tap
     * that this ROM drops silently, so those "no-op" taps were never delivered
     * at all. A 90 ms press is what actually exercises the card, and with it
     * the capsule's own intent fires every time.
     *
     * The real reason ticking failed — «صبح و ظهر و مغرب و عشا و عصر تیک
     * نمی‌خورند از داخل ویجت» — was DELIVERY, not the tap map: the mark intent
     * was a broadcast, and MIUI's freezer drops a frozen app's widget broadcast
     * outright. It is an activity PendingIntent now; see [markIntent].
     */
    private fun bindClicks(context: Context, views: RemoteViews, widgetId: Int, small: Boolean) {
        views.setOnClickPendingIntent(R.id.prayer_surface, PrayerRemoteLeaves.openApp(context))
        // The backstop, so a tap that lands on nothing at all still opens the
        // app instead of reading as a frozen card. A capsule consumes its own
        // touch first (measured above), so this never shadows one.
        views.setOnClickPendingIntent(R.id.prayer_native_root, PrayerRemoteLeaves.openApp(context))
        // The compact card has no capsules, and a click action on a missing id
        // is an ActionException at apply time.
        if (small) return
        for (index in 0 until 5) {
            views.setOnClickPendingIntent(CAPSULE_IDS[index], markIntent(context, widgetId, index))
        }
    }

    /**
     * The «خواندم» tap for one capsule.
     *
     * It is an ACTIVITY PendingIntent, not a broadcast, and that is a measured
     * decision — the whole story is in [PrayerMarkActivity]. A broadcast tap is
     * cheaper and lands in +1 ms while the app's process is alive, but MIUI's
     * freezer drops it once the process is gone: measured 2026-11-05, a single
     * tap after `am force-stop` logged `notifyGreeze` and then no `Start proc`,
     * no receiver and no log line for 20 s. The card simply did not tick. An
     * activity start cannot be dropped that way, and the activity draws nothing.
     *
     * The request code is `widgetId * 10 + 30 + index`: clear of the tasbih
     * band (`widgetId * 10 + 1..4`) so two cards on the same home screen never
     * share a PendingIntent, and of the activity door (`widgetId + 60000`).
     */
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

    private const val ONBOARDING_HINT = "برای راه‌اندازی، برنامه را یک بار باز کنید"

    /**
     * Every dimension of one card, from the budget and the cell. Type is in
     * sp; everything else is raw PIXELS — `setViewPadding` and bitmap
     * intrinsic sizes both work in pixels, and neither can be re-interpreted
     * by a host (the lesson `setViewLayoutWidth` taught the tasbih card).
     */
    private data class Metrics(
        /** The cell the launcher granted — logged, so a size report can be
         *  checked against the cell it was actually rendered for. */
        val cellWidthDp: Float,
        val cellHeightDp: Float,
        val isSmall: Boolean,
        val showGregorian: Boolean,
        val showProgress: Boolean,
        val density: Float,
        val clockSizeSp: Float,
        /**
         * The clock slot's PINNED height, in pixels — the budget's
         * [PrayerWidgetBudget.Metrics.clockBoxDp].
         *
         * It is a pixel height on purpose: `setViewLayoutHeight` takes a float
         * plus a unit, and dp would be re-multiplied by whatever density the
         * host is in. Pixels cannot be reinterpreted.
         */
        val clockBoxPx: Int,
        val clockColor: Int,
        val countdownSp: Float,
        val pillLabelSp: Float,
        val pillTimeSp: Float,
        val headerIconPx: Int,
        val cityIconPx: Int,
        val chipPadHPx: Int,
        val chipPadVPx: Int,
        val gap4Px: Int,
        val gap5Px: Int,
        val gapDatesPx: Int,
        val checkPx: Int,
        val checkGapPx: Int,
        val capsulePadPx: Int,
        val sideInsetPx: Int,
        val topInsetPx: Int,
        val bottomInsetPx: Int,
        val rowSidePadPx: Int,
        val headerTextMaxPx: Int,
        val pillWidthPx: Int,
        val pillHeightPx: Int,
        val chipFillRes: Int,
        /** The box each date sits in — the same neutral chip the capsules use. */
        val dateChipRes: Int,
        /** Horizontal air inside a date box; doubled between two boxes. */
        val dateChipPadPx: Int,
        val capsuleFillRes8: Int,
        val capsuleFillRes14: Int,
    ) {
        fun densityPx(dp: Float): Int = (dp * density).roundToInt()
    }

    private fun cell(
        context: Context,
        widgetId: Int,
        override: Pair<Float, Float>? = null,
    ): Pair<Float, Float> {
        if (override != null) return override
        val options = AppWidgetManager.getInstance(context).getAppWidgetOptions(widgetId)
        val widthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            .takeIf { it > 0 }?.toFloat() ?: 250f
        val heightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
            .takeIf { it > 0 }?.toFloat() ?: 170f
        return widthDp to heightDp
    }

    /**
     * The budget for one cell, run TWICE — pass one finds the clock a cell of
     * this size gives, pass two re-prices the bands with the countdown tied to
     * it. The countdown is a band, and a band drawn bigger than it was priced
     * steals the capsules' room.
     *
     * Shared with [WidgetAudit] on purpose: the audit must price the card with
     * the SAME numbers the render uses, or it would be measuring a different
     * card.
     */
    fun budgetFor(
        context: Context,
        widthDp: Float,
        heightDp: Float,
    ): PrayerWidgetBudget.Metrics {
        val prefs = WidgetRepository.prefs(context)
        val model = PrayerWidgetModel.read(context)
        val fontScale = context.resources.configuration.fontScale
            .takeIf { it.isFinite() && it > 0f }?.coerceIn(0.85f, 1.6f) ?: 1f
        val showProgress = prefs.getBoolean(WidgetPrefs.KEY_SHOW_PROGRESS, true)
        val showGregorian = prefs.getBoolean(WidgetPrefs.KEY_SHOW_GREGORIAN, true)
        val base = PrayerWidgetBudget.metrics(
            widthDp,
            heightDp,
            model.hasData,
            fontScale,
            showProgress = showProgress,
            showGregorian = showGregorian,
        )
        return PrayerWidgetBudget.metrics(
            widthDp,
            heightDp,
            model.hasData,
            fontScale,
            countdownOverrideSp = base.clockSizeSp * PrayerWidgetBudget.COUNTDOWN_TO_CLOCK,
            showProgress = showProgress,
            showGregorian = showGregorian,
        )
    }

    private fun metrics(
        context: Context,
        widgetId: Int,
        model: PrayerWidgetModel,
        override: Pair<Float, Float>? = null,
    ): Metrics {
        val theme = WidgetTheme.resolve(context, WidgetTheme.WidgetTarget.PRAYER, widgetId)
        val prefs = WidgetRepository.prefs(context)
        val (widthDp, heightDp) = cell(context, widgetId, override)
        val fontScale = context.resources.configuration.fontScale
            .takeIf { it.isFinite() && it > 0f }?.coerceIn(0.85f, 1.6f) ?: 1f
        val showProgress = prefs.getBoolean(WidgetPrefs.KEY_SHOW_PROGRESS, true)
        val showGregorian = prefs.getBoolean(WidgetPrefs.KEY_SHOW_GREGORIAN, true)

        val m = budgetFor(context, widthDp, heightDp)

        val density = context.resources.displayMetrics.density
            .takeIf { it > 0f && it < 100f } ?: 1f
        val s = m.scale
        // ONE conversion, and it is the budget's own: a dp the budget priced is
        // a dp this file draws. It used to multiply by `scale` as well, so a
        // 5.07 dp pill padding was PRICED as 5.07 dp and DRAWN as 6.71 dp —
        // every band was a little taller than the number the clock was sized
        // against, and on a tall cell that is exactly where the capsule's time
        // line went. Values the budget already scaled (the side and top
        // insets) arrive here pre-scaled.
        fun px(dp: Float): Int = (dp * density).roundToInt()

        val light = theme.palette.light
        fun fill(percent: Int): Int =
            WidgetTheme.neutralFill(context, light, "capsule", percent)
                .takeIf { it != 0 }
                ?: context.resources.getIdentifier(
                    "widget_capsule_w14", "drawable", context.packageName,
                )

        // The row is capped at ~330 dp of boxes: on a wide cell the boxes stay
        // a readable size and the spare width becomes symmetric side padding
        // instead of stretched boxes.
        val sideInsetDp = m.sideInsetDp
        val rowMaxDp = 330f * s
        val rowSidePadDp =
            (((widthDp - 2f * sideInsetDp) - rowMaxDp) / 2f).coerceAtLeast(0f)
        // The header's texts may take at most 40 % of the content width each —
        // enough for «چهارشنبه» and «تهران، ایران», never enough to overflow.
        val headerTextMaxDp = (widthDp - 2f * sideInsetDp) * 0.40f

        return Metrics(
            cellWidthDp = widthDp,
            cellHeightDp = heightDp,
            isSmall = m.isSmall,
            showGregorian = m.showGregorian,
            showProgress = m.showProgress,
            density = density,
            clockSizeSp = if (m.isSmall) 26f * s else m.clockSizeSp,
            clockBoxPx = px(if (m.isSmall) 26f * s * PrayerWidgetBudget.CLOCK_BOX_EM else m.clockBoxDp),
            clockColor = theme.text,
            countdownSp = m.countdownSizeSp,
            pillLabelSp = m.pillLabelSizeSp,
            pillTimeSp = m.pillTimeSizeSp,
            headerIconPx = px(PrayerWidgetBudget.HEADER_ICON_DP * s),
            cityIconPx = px(PrayerWidgetBudget.HEADER_ICON_DP * 0.85f * s),
            chipPadHPx = px(PrayerWidgetBudget.CHIP_PAD_H_DP),
            chipPadVPx = px(PrayerWidgetBudget.CHIP_PAD_V_DP),
            gap4Px = px(4f),
            gap5Px = px(5f),
            gapDatesPx = px(PrayerWidgetBudget.GAP_CLOCK_DATES_DP),
            // The check sits inside the name line: big enough to read as a
            // state, small enough that five of them cost no band.
            checkPx = px(PrayerWidgetBudget.CHECK_DP * s).coerceAtLeast(8),
            checkGapPx = px(2f),
            capsulePadPx = px(m.pillPadDp),
            sideInsetPx = (sideInsetDp * density).roundToInt(),
            topInsetPx = (PrayerWidgetBudget.CARD_TOP_INSET_DP * s * density).roundToInt(),
            bottomInsetPx = px(PrayerWidgetBudget.CARD_BOTTOM_INSET_DP),
            rowSidePadPx = (rowSidePadDp * density).roundToInt(),
            headerTextMaxPx = (headerTextMaxDp * density).roundToInt(),
            pillWidthPx = ((widthDp - 2f * sideInsetDp) * density).roundToInt(),
            // The pill bitmap's height IS the pill's height: the countdown
            // line plus its 2 dp of air, exactly what the budget's countdown
            // band prices for the bitmap.
            pillHeightPx = (PrayerWidgetBudget.lineDp(
                maxOf(m.countdownSizeSp, m.captionSizeSp), fontScale,
            ) + 2f).let { (it * density).roundToInt() },
            chipFillRes = fill(16),
            dateChipRes = fill(12),
            dateChipPadPx = px(5f).coerceAtLeast(2),
            capsuleFillRes8 = fill(8),
            capsuleFillRes14 = fill(14),
        )
    }

    private fun logRender(widgetId: Int, small: Boolean, m: Metrics) {
        Log.d(
            TAG,
            "metrics id=$widgetId cell=${m.cellWidthDp}x${m.cellHeightDp} small=$small " +
                "clock=${m.clockSizeSp} countdown=${m.countdownSp} " +
                "label=${m.pillLabelSp} time=${m.pillTimeSp} pill=${m.pillHeightPx}px " +
                "check=${m.checkPx}px side=${m.sideInsetPx}px rowPad=${m.rowSidePadPx}px",
        )
    }
}
