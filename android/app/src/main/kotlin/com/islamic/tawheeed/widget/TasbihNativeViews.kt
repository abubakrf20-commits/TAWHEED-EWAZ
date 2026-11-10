package com.islamic.tawheeed.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.ColorStateList
import android.os.Build
import android.util.TypedValue
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import com.islamic.tawheeed.R
import kotlin.math.min

/**
 * The tasbih card as RemoteViews, built by hand.
 *
 * ## Why not Glance
 *
 * A counter repaints on every bead, and on this project's test device a Glance
 * widget composes **once per process**. `GlanceAppWidget.update()` against an
 * already-open session re-applies the session's cached tree and never calls
 * `provideGlance` again — measured with a `compose` log inside `provideContent`:
 * four taps, four `paint` calls, one composition, and the card sat on the first
 * tap's number until the process was killed. See the header of
 * `widget_tasbih_native.xml` for the full note.
 *
 * ## The two renders
 *
 * [full] paints everything: the gradient surface, the type sizes, the three
 * icons, and the tap intents. It runs on placement, on resize, after an app
 * snapshot, and from the watchdog — events that are rare and already slow.
 *
 * [partial] paints only what a tap can change, and is applied with
 * `AppWidgetManager.partiallyUpdateAppWidget`, which **merges the setters into
 * the view the launcher already inflated**. No re-inflation, no composition,
 * and the surface bitmap — by far the largest thing in the tree — never crosses
 * the binder again. That is what makes a bead land in a frame instead of half a
 * second.
 *
 * Nothing here reads the clock, keeps state, or allocates per tap beyond the
 * ring bitmap, which [WidgetArt] caches by progress step.
 */
internal object TasbihNativeViews {

    private const val TAG = "TasbihNativeViews"

    /**
     * EVERY dimension of one card, derived from the cell it was given and one
     * shared `scale`. Type is in sp; everything else is in raw PIXELS because
     * `RemoteViews.setViewPadding` and `setImageViewBitmap` both work in
     * pixels. Nothing in the layout XML carries a fixed dp size any more, so
     * shrinking the widget really does shrink the dhikr, the pill, the ring,
     * the badge, the three buttons, their icons and every gap.
     */
    private data class Metrics(
        val dhikrSp: Float,
        val pillSp: Float,
        val countSp: Float,
        val badgeSp: Float,
        val confirmSp: Float,
        val boxDp: Float,
        /** The ring bitmap's edge, in PIXELS. It is also the view's size —
         *  the layout is `wrap_content`, so the bitmap owns the box. */
        val ringPx: Int,
        val showBadge: Boolean,
        val padH: Int,
        val padV: Int,
        val gap: Int,
        val pillPadH: Int,
        val pillPadV: Int,
        val badgePadH: Int,
        val badgePadV: Int,
        val chipPad: Int,
        val iconPx: Int,
        val buttonGap: Int,
    )

    /** The key the confirm window and the tap intents agree on. */
    fun widgetKey(widgetId: Int): String = "w$widgetId"

    // ── Full render ────────────────────────────────────────────────────────

    fun full(context: Context, widgetId: Int): RemoteViews {
        val theme = WidgetTheme.resolve(context, WidgetTheme.WidgetTarget.TASBIH)
        val metrics = metrics(context, widgetId)
        val views = RemoteViews(context.packageName, R.layout.widget_tasbih_native_v2)

        bindSurface(context, views, theme, widgetId)
        bindMetrics(views, metrics)
        bindClicks(context, views, widgetId, metrics)
        bindState(context, views, theme, metrics, widgetId)
        return views
    }

    // ── Tap render ─────────────────────────────────────────────────────────

    /**
     * The subset a tap can change.
     *
     * Deliberately excludes the surface, the type sizes and the prev/next
     * icons: none of them can differ after a bead, and the surface alone is
     * ~750 KB. A zikr switch changes the dhikr line and the two pills, so those
     * are here — it is still a merge, not a re-inflation.
     */
    fun partial(context: Context, widgetId: Int): RemoteViews {
        val theme = WidgetTheme.resolve(context, WidgetTheme.WidgetTarget.TASBIH)
        val metrics = metrics(context, widgetId)
        val views = RemoteViews(context.packageName, R.layout.widget_tasbih_native_v2)
        bindState(context, views, theme, metrics, widgetId)
        return views
    }

    // ── Bindings ───────────────────────────────────────────────────────────

    private fun bindSurface(
        context: Context,
        views: RemoteViews,
        theme: WidgetTheme.Resolved,
        widgetId: Int,
    ) {
        // The palette's gradient, with the corners painted in: a launcher below
        // API 31 ignores an outline radius, and a bitmap corner survives
        // everywhere.
        val options = AppWidgetManager.getInstance(context).getAppWidgetOptions(widgetId)
        val widthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            .takeIf { it > 0 }?.toFloat() ?: 200f
        val heightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
            .takeIf { it > 0 }?.toFloat() ?: 200f
        val surface = WidgetArt.surface(
            context,
            theme.bg,
            theme.bgEnd,
            WidgetTheme.CORNER_RADIUS_DP.toFloat(),
            widthDp,
            heightDp,
        )
        views.setImageViewBitmap(R.id.tasbih_surface, surface)
    }

    /**
     * Geometry lives here and ONLY here. `partial()` deliberately does not
     * call it: a tap merge preserves the paddings and type sizes the launcher
     * already inflated, so a bead costs no layout work at all.
     *
     * `setViewLayoutWidth(id, dp, 0)` is documented as dp, but on this
     * launcher the number landed as PIXELS — with box=119 dp the ring rendered
     * 117 px (36 dp) and the count at 44 sp overflowed it. So no layout-param
     * setter is used anywhere: the ring/chip sizes are owned by BITMAPS
     * (`wrap_content` views) and every gap by `setViewPadding` (raw pixels).
     * Both are unambiguous across launchers.
     */
    private fun bindMetrics(views: RemoteViews, m: Metrics) {
        // 1. Type. The top dhikr and the «ذکر N از M» pill are the two the
        //    brief asks to make smaller; both now scale down to 8/6 sp at the
        //    provider's 120 dp minResize instead of being floored at 13.5/8.5.
        //    2026-11-04 second pass: the dhikr went 13.5 → 12.5 at scale 1 —
        //    every dp the header bands give up goes straight into the ring.
        views.setTextViewTextSize(R.id.tasbih_dhikr, TypedValue.COMPLEX_UNIT_SP, m.dhikrSp)
        views.setTextViewTextSize(R.id.tasbih_pill_position, TypedValue.COMPLEX_UNIT_SP, m.pillSp)
        views.setTextViewTextSize(R.id.tasbih_badge, TypedValue.COMPLEX_UNIT_SP, m.badgeSp)

        // 2. Card padding and the vertical gaps of the fixed rhythm: dhikr →
        //    pill → ring → badge → controls. The badge row's gap is only
        //    charged when the badge is drawn, which is the same condition the
        //    budget uses to price it.
        views.setViewPadding(R.id.tasbih_content, m.padH, m.padV, m.padH, m.padV)
        views.setViewPadding(R.id.tasbih_pill_row, 0, m.gap, 0, 0)
        views.setViewPadding(R.id.tasbih_ring_area, 0, m.gap, 0, 0)
        views.setViewPadding(R.id.tasbih_badge_row, 0, if (m.showBadge) m.gap else 0, 0, 0)
        views.setViewPadding(R.id.tasbih_controls, 0, m.gap, 0, 0)

        // 3. The one remaining pill and the badge inside the ring.
        views.setViewPadding(
            R.id.tasbih_pill_position,
            m.pillPadH, m.pillPadV, m.pillPadH, m.pillPadV,
        )
        views.setViewPadding(
            R.id.tasbih_badge,
            m.badgePadH, m.badgePadV, m.badgePadH, m.badgePadV,
        )

        // 4. The three footer buttons. Horizontal padding on the tap targets
        //    is the inter-button spacing; padding on the inner chips turns the
        //    `wrap_content` oval shape into a scaled circle around the icon.
        val halfGap = m.buttonGap / 2
        for (id in intArrayOf(
            R.id.tasbih_prev,
            R.id.tasbih_reset,
            R.id.tasbih_next,
        )) {
            views.setViewPadding(id, halfGap, 0, halfGap, 0)
        }
        for (id in intArrayOf(
            R.id.tasbih_prev_chip,
            R.id.tasbih_reset_chip,
            R.id.tasbih_next_chip,
        )) {
            views.setViewPadding(id, m.chipPad, m.chipPad, m.chipPad, m.chipPad)
        }
    }

    /**
     * Tints a white `<shape>` background.
     *
     * `RemoteViews.setColorStateList` is **API 31+**, and this module ships
     * minSdk 24 — an unguarded call is a `NoSuchMethodError` on Android 7–11,
     * thrown while the launcher applies the update. Below 31 the pill loses
     * its corner radius (a flat colour replaces the shape drawable) but the
     * card still draws, which is the right trade for a decorative capsule.
     */
    private fun tintBackground(views: RemoteViews, id: Int, color: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setColorStateList(
                id,
                "setBackgroundTintList",
                ColorStateList.valueOf(color),
            )
        } else {
            views.setInt(id, "setBackgroundColor", color)
        }
    }

    private fun bindClicks(
        context: Context,
        views: RemoteViews,
        widgetId: Int,
        metrics: Metrics,
    ) {
        val theme = WidgetTheme.resolve(context, WidgetTheme.WidgetTarget.TASBIH)

        // The icons are rasterised and tinted once per colour; a RemoteViews
        // ImageView has no colour filter, and a white vector would vanish on
        // the cream palette. The BITMAP owns the icon's size now, so it scales
        // with the card instead of being pinned to the old fixed 18 dp.
        views.setImageViewBitmap(
            R.id.tasbih_prev_icon,
            WidgetArt.tintedIcon(context, R.drawable.widget_ic_prev, theme.accent, metrics.iconPx),
        )
        views.setImageViewBitmap(
            R.id.tasbih_next_icon,
            WidgetArt.tintedIcon(context, R.drawable.widget_ic_next, theme.accent, metrics.iconPx),
        )
        // The two chevron chips keep their white oval from the layout. Tinting
        // the OUTER tap targets was a no-op above API 31 (they have no
        // background) and painted a coloured rectangle below it; neither is
        // wanted now that those targets carry scaled padding. The reset chip
        // is still tinted in bindState(), because its face changes on confirm.

        // The increment lives on the ROOT, not on the ring.
        //
        // It used to sit on `tasbih_ring_box`, so only the disc counted and a
        // tap on the dhikr name, the pills or the badge did nothing — the
        // report was «هرجای بوکس تسبیح کلیک کنم شماره بیفتد، الان فقط روی شماره
        // که میزنم کلیک میخورد». A container listener still yields to the
        // three buttons below, because they are clickable children and take
        // the touch first.
        views.setOnClickPendingIntent(
            R.id.tasbih_root,
            tapIntent(context, widgetId, TasbihTapEngine.ACTION_INCREMENT),
        )
        views.setOnClickPendingIntent(
            R.id.tasbih_prev,
            tapIntent(context, widgetId, TasbihTapEngine.ACTION_PREV_ZIKR),
        )
        views.setOnClickPendingIntent(
            R.id.tasbih_reset,
            tapIntent(context, widgetId, TasbihTapEngine.ACTION_RESET),
        )
        views.setOnClickPendingIntent(
            R.id.tasbih_next,
            tapIntent(context, widgetId, TasbihTapEngine.ACTION_NEXT_ZIKR),
        )
    }

    /** Everything that depends on the committed counter. */
    private fun bindState(
        context: Context,
        views: RemoteViews,
        theme: WidgetTheme.Resolved,
        metrics: Metrics,
        widgetId: Int,
    ) {
        val prefs = WidgetRepository.prefs(context)
        val state = TasbihWidgetModel.read(prefs)
        val key = widgetKey(widgetId)
        val confirming = TasbihTapEngine.isConfirming(key)
        val textColor = theme.text
        val accent = theme.accent
        val countColor = if (confirming) {
            TasbihWidgetModel.confirmColor(theme)
        } else {
            TasbihWidgetModel.countColor(theme, state)
        }

        // The two chevron chips wear the same soft accent wash as the idle
        // reset chip (brief 2026-11-07: «قبلی و بعدی با رنگی متناسب») — three
        // harmonious buttons instead of two bare white ovals around one
        // tinted one. Applied here (the state bind) so a partial tap merge
        // re-asserts it and the chips can never drift back to plain.
        tintBackground(
            views,
            R.id.tasbih_prev_chip,
            WidgetTokens.withAlpha(accent, 0.12f),
        )
        tintBackground(
            views,
            R.id.tasbih_next_chip,
            WidgetTokens.withAlpha(accent, 0.12f),
        )

        // 1. The dhikr name.
        views.setTextViewText(R.id.tasbih_dhikr, state.dhikr)
        views.setTextColor(R.id.tasbih_dhikr, textColor)

        // 2. The ONE remaining pill. «امروز N» is gone from the layout for
        //    good (brief «امروز 10 حذف کنید»); the day's total is still kept in
        //    TasbihWidgetModel for the app's own UI, it is simply no longer
        //    painted on the home-screen card. The position pill is smaller and
        //    quieter now, so the ring is the card's one focal point.
        val position = state.positionLabel
        views.setViewVisibility(
            R.id.tasbih_pill_position,
            if (position.isEmpty()) View.GONE else View.VISIBLE,
        )
        views.setTextViewText(R.id.tasbih_pill_position, position)
        views.setTextColor(
            R.id.tasbih_pill_position,
            WidgetTokens.withAlpha(textColor, 0.62f),
        )
        tintBackground(
            views,
            R.id.tasbih_pill_position,
            WidgetTokens.withAlpha(textColor, 0.09f),
        )

        // 3. The ring and the number in it. The approved Design 1 ring: an
        // inner disc, a gold gradient arc from the top, and the outer lap ring
        // once at least one lap is complete. The count stays a Glance-free
        // TextView layered dead-centre on the bitmap (layout: one FrameLayout,
        // both children centered) — P4's concentric fix.
        val density = context.resources.displayMetrics.density
        val trackColor = WidgetTokens.withAlpha(textColor, 0.12f)
        val outerTrack = WidgetTokens.withAlpha(textColor, 0.10f)
        val arcStart = theme.token("accentStart", accent)
        val arcEnd = theme.token("accentEnd", accent)
        val outerColor = theme.token("outerRing", 0xFF7FD6C4.toInt())
        val ring = WidgetArt.ringV2(
            sizePx = metrics.ringPx,
            trackColor = trackColor,
            arcStart = arcStart,
            arcEnd = arcEnd,
            progress = state.progress,
            outerColor = outerColor,
            outerTrackColor = outerTrack,
            lapProgress = state.lapProgress,
        )
        views.setImageViewBitmap(R.id.tasbih_ring, ring)
        val countText = if (confirming) "تأیید؟" else "${state.count}"
        views.setTextViewText(R.id.tasbih_count, countText)
        // The count's size is FIXED per dhikr (brief 2026-11-07: «شمارنده …
        // حجم ثابت»). Sizing by the live count's glyph run made the number
        // breathe while tapping — «7» large, «17» smaller, back and forth.
        // The run is now sized for the dhikr's TARGET (the widest number this
        // dhikr can ever show), so the type never changes between taps: one
        // dhikr, one size, every count. Confirming keeps its own cap.
        //
        // Sizing by the ring alone fits «7» and overflows «100»: a Calibri
        // digit is ~0.52 em wide, so the run is capped at 64 % of the VISIBLE
        // ring diameter at the target's digit count. The visible diameter (not
        // the bitmap edge) matters: 11.4 % of that bitmap is transparent
        // margin (WidgetArt.RING_INK_FRACTION).
        val digits = if (confirming) {
            5
        } else {
            maxOf(countText.length, state.target.toString().length).coerceAtLeast(1)
        }
        val visiblePx = metrics.ringPx * WidgetArt.RING_INK_FRACTION
        val byWidth = 0.64f * visiblePx / (digits * 0.52f * density)
        views.setTextViewTextSize(
            R.id.tasbih_count,
            TypedValue.COMPLEX_UNIT_SP,
            if (confirming) {
                min(metrics.confirmSp, byWidth)
            } else {
                min(metrics.countSp, byWidth)
            },
        )
        views.setTextColor(R.id.tasbih_count, countColor)
        views.setContentDescription(R.id.tasbih_count, state.accessibilityLabel(confirming))

        // 4. The badge — a row of its OWN under the ring (brief 2026-11-07:
        //    «از ۱۰۰ زیر دایره باشد نه روی دایره»): the goal before the first
        //    lap, the lap's beads on later laps, the completed-lap tick exactly
        //    on a boundary. The count above is therefore alone at the ring's
        //    true centre and needs no re-centring padding any more — v1 padded
        //    the centre group by the badge's height to compensate for a badge
        //    drawn INSIDE the circle, and that padding is gone with it.
        views.setViewVisibility(
            R.id.tasbih_badge_row,
            if (metrics.showBadge) View.VISIBLE else View.GONE,
        )
        views.setTextViewText(
            R.id.tasbih_badge,
            if (confirming) "برای ریست دوباره بزنید" else state.badge,
        )
        val badgeFill = theme.token("badgeFill", accent)
        val badgeText = theme.token("badgeText", theme.text)
        views.setTextColor(R.id.tasbih_badge, badgeText)
        views.setInt(R.id.tasbih_badge, "setBackgroundResource", badgeRes(context, theme))

        // 5. The reset chip doubles as the confirm face.
        val resetColor = if (confirming) TasbihWidgetModel.confirmColor(theme) else accent
        tintBackground(
            views,
            R.id.tasbih_reset_chip,
            WidgetTokens.withAlpha(resetColor, if (confirming) 0.22f else 0.12f),
        )
        views.setImageViewBitmap(
            R.id.tasbih_reset_icon,
            WidgetArt.tintedIcon(
                context,
                R.drawable.widget_ic_reset,
                resetColor,
                metrics.iconPx,
            ),
        )
        views.setContentDescription(
            R.id.tasbih_reset,
            if (confirming) "تأیید ریست" else "ریست شمارنده",
        )
    }

    /** The generated badge fill for the palette, or 0 when absent. */
    private fun badgeRes(context: Context, theme: WidgetTheme.Resolved): Int =
        context.resources.getIdentifier(
            "widget_tasbih_badge_${theme.palette.id}",
            "drawable",
            context.packageName,
        )

    // ── Intents ────────────────────────────────────────────────────────────

    /**
     * The tap intent for one view.
     *
     * The request code is `widgetId * 10 + action`, so two cards on the same
     * home screen never share a PendingIntent — with a shared code the second
     * card's tap would land on the first card's id and move the wrong counter.
     */
    private fun tapIntent(context: Context, widgetId: Int, action: String): PendingIntent {
        val key = widgetKey(widgetId)
        val useActivity = WidgetPrefs.useActivityTaps(WidgetRepository.prefs(context))
        val intent = if (useActivity) {
            TasbihActionActivity.intent(context, action, key)
        } else {
            Intent(context, TasbihGlanceWidgetReceiver::class.java).apply {
                this.action = action
                putExtra(TasbihGlanceWidgetReceiver.EXTRA_WIDGET_KEY, key)
                putExtra(TasbihGlanceWidgetReceiver.EXTRA_APP_WIDGET_ID, widgetId)
                setPackage(context.packageName)
            }
        }
        val requestCode = widgetId * 10 + actionCode(action)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return if (useActivity) {
            PendingIntent.getActivity(context, requestCode, intent, flags)
        } else {
            PendingIntent.getBroadcast(context, requestCode, intent, flags)
        }
    }

    private fun actionCode(action: String): Int = when (action) {
        TasbihTapEngine.ACTION_INCREMENT -> 1
        TasbihTapEngine.ACTION_RESET -> 2
        TasbihTapEngine.ACTION_PREV_ZIKR -> 3
        TasbihTapEngine.ACTION_NEXT_ZIKR -> 4
        else -> 5
    }

    /** The component every tasbih render and intent points at. */
    fun component(context: Context): ComponentName =
        ComponentName(context, TasbihGlanceWidgetReceiver::class.java)

    // ── Sizing ─────────────────────────────────────────────────────────────

    /**
     * ONE scale drives the whole card, from the cell the launcher granted.
     *
     * Measured before this rewrite on the POCO X7 Pro (density 3.25):
     * `cell=243x269 scale=1.215 box=119.3 ringPx=298 count=84 badge=true`.
     * Two things were wrong:
     *  - `scale` was floored at 0.75, so a resize down to the provider's
     *    120 dp minResize (0.60) did not shrink ANY element;
     *  - `ringPx = boxDp * 2.5` while `density = 3.25`. Because the ImageView
     *    is `wrap_content`, the 298 px bitmap rendered as 91.7 dp, not the
     *    119.3 dp the budget had reserved — a 23 % shrink, on top of the
     *    transparent margin in the art, is the «دایره خیلی کوچک» report.
     *
     * Now every band above and below the ring is priced in the SAME scaled dp
     * units the padding is applied in, and the ring is painted at the REAL
     * device density. The count is sized from the visible circle in dp, not
     * from a raw pixel count: the old `ringPx * 0.30` mixed pixels with sp and
     * is why the «0» overflowed the ring in the device screenshot.
     *
     * 2026-11-04 second pass («دایره هنوز باید بزرگتر شود»): the fixed bands
     * above and below the ring were trimmed — padV 8→6, gap 7→5, chip 36→33,
     * dhikr 13.5→12.5 at scale 1 — which on the measured POCO cell moves the
     * box from 139.5 dp to ~160 dp. The ring bitmap then hits its 512 px cap
     * (≈157.5 dp at density 3.25): about 28 % more visible ring than the
     * first pass, at identical bitmap cost.
     */
    private fun metrics(context: Context, widgetId: Int): Metrics {
        val options = AppWidgetManager.getInstance(context).getAppWidgetOptions(widgetId)
        val widthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            .takeIf { it > 0 }?.toFloat() ?: 200f
        val heightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
            .takeIf { it > 0 }?.toFloat() ?: 200f
        // 0.55 reaches (and passes) the 120 dp / 200 dp = 0.60 minResize the
        // provider declares; the old 0.75 floor swallowed that whole resize.
        val scale = (min(widthDp, heightDp) / 200f).coerceIn(0.55f, 1.6f)
        val density = context.resources.displayMetrics.density
            .takeIf { it > 0f && it < 100f } ?: 1f
        fun px(dpAtScaleOne: Float): Int = (dpAtScaleOne * scale * density).toInt()

        // Type — the brief: «ذکر کوچک کنید» and «ذکر 5 از 8 هم کوچکتر شود».
        // 12.5/8 sp at scale 1 (was 13.5/8), and the floors now let them
        // fall to 8/6 sp on a small card instead of freezing at 13.5/8.5.
        val dhikrSp = (12.5f * scale).coerceIn(8f, 21f)
        val pillSp = (8f * scale).coerceIn(6f, 12f)
        val badgeSp = (7.5f * scale).coerceIn(6f, 11f)
        val confirmSp = (13f * scale).coerceIn(8f, 20f)

        // Geometry, all from the same scale. px() is used by setViewPadding
        // and by the chip/ring bitmaps, so gaps and sizes can never disagree.
        val padH = px(12f)
        val padV = px(6f)
        val gap = px(5f)
        val pillPadH = px(7f)
        val pillPadV = px(1.5f)
        val badgePadH = px(8f)
        val badgePadV = px(1.5f)
        val buttonGap = px(6f)

        val iconDp = 15f * scale
        val chipDp = 33f * scale
        val iconPx = (iconDp * density).toInt().coerceAtLeast(8)
        val chipPad = ((chipDp - iconDp) * density / 2f).toInt().coerceAtLeast(1)

        // The vertical budget. A text line is ~1.42 sp tall in dp; the pill's
        // padding is priced in the same dp units. There are exactly three
        // scaled gaps in the fixed rhythm (pill row, ring area, controls) plus
        // the badge row's, which is only charged when the badge is drawn.
        val padVDp = 6f * scale
        val gapDp = 5f * scale
        val pillPadVDp = 1.5f * scale
        val padHDp = 12f * scale
        val badgePadVDp = 1.5f * scale
        val fixedDp = 2f * padVDp +
            dhikrSp * 1.42f +
            (pillSp * 1.42f + 2f * pillPadVDp) +
            chipDp +
            3f * gapDp
        val widthCapDp = widthDp - 2f * padHDp
        // The badge is a band of its own BELOW the ring now (v2), so it is
        // priced out of the ring's take instead of being drawn on top of it.
        // It is dropped when paying for it would shrink the circle below
        // WidgetArt.MIN_BADGE_BOX_DP — the badge is the smaller thing.
        val badgeBandDp = badgeSp * 1.42f + 2f * badgePadVDp + gapDp
        val boxWithoutBadge = min(heightDp - fixedDp, widthCapDp)
        val showBadge = boxWithoutBadge - badgeBandDp >= WidgetArt.MIN_BADGE_BOX_DP
        val availableDp = if (showBadge) heightDp - fixedDp - badgeBandDp else heightDp - fixedDp
        val boxDp = min(availableDp, widthCapDp)
            .coerceAtLeast(WidgetArt.RING_BOX_FLOOR_DP)

        // Full device density: dp reserved == dp drawn. Capped in PIXELS only,
        // so a very large card stops growing at a ~1 MB buffer rather than
        // pushing a multi-megabyte bitmap across the binder on every bead.
        val ringPx = (boxDp * density).toInt()
            .coerceIn(96, WidgetArt.RING_MAX_PX)
        val visibleRingDp = ringPx * WidgetArt.RING_INK_FRACTION / density
        // A Calibri digit's ink is ~0.74 sp in dp on this screen (measured:
        // 44 sp drew a 105 px digit at density 3.25). 0.60 of the visible
        // diameter puts the digit at ~45 % of the ring's height, leaving room
        // for the «از N» badge UNDER it inside the same circle; 0.68 pushed
        // the two-line group past the arc on device (2026-11-04). The old
        // 84 sp against an 81 dp ring overflowed outright.
        val countSp = (visibleRingDp * 0.60f).coerceIn(11f, 88f)

        Log.d(
            TAG,
            "metrics cell=${widthDp}x$heightDp density=$density scale=$scale " +
                "box=$boxDp ringPx=$ringPx visible=${visibleRingDp}dp " +
                "count=$countSp dhikr=$dhikrSp pill=$pillSp " +
                "icon=${iconPx}px chipPad=${chipPad}px badge=$showBadge",
        )

        return Metrics(
            dhikrSp = dhikrSp,
            pillSp = pillSp,
            countSp = countSp,
            badgeSp = badgeSp,
            confirmSp = confirmSp,
            boxDp = boxDp,
            ringPx = ringPx,
            showBadge = showBadge,
            padH = padH,
            padV = padV,
            gap = gap,
            pillPadH = pillPadH,
            pillPadV = pillPadV,
            badgePadH = badgePadH,
            badgePadV = badgePadV,
            chipPad = chipPad,
            iconPx = iconPx,
            buttonGap = buttonGap,
        )
    }
}
