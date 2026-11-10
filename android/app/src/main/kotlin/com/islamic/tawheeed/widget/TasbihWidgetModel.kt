package com.islamic.tawheeed.widget

import android.content.SharedPreferences

/**
 * Everything the tasbih widget *says*, separated from how it looks.
 *
 * The rendering used to read prefs inline inside `provideRemoteViews`, which
 * made every wording rule (the «2/5 · امروز 123» caption, the «✓ کامل شد»
 * badge, the accessibility sentence) reachable only through a RemoteViews
 * assertion. Pulling them here keeps the Glance composable a pure function of
 * this state and lets the JVM tests pin the strings and the progress maths
 * without an Android view tree.
 */
internal data class TasbihWidgetState(
    val index: Int,
    val dhikr: String,
    val count: Int,
    val target: Int,
    val zikrListSize: Int,
    val todayTotal: Int,
) {
    /**
     * The lap arithmetic behind the approved Design 1 (brief P3): the count is
     * UNBOUNDED, so [lapsCompleted] = floor(count / target) and [inLap] = the
     * beads of the lap being counted now. A 100-target tasbih at 103 shows
     * laps=1, inLap=3 — the main ring is full gold, the outer ring shows the
     * lap's 3 %, and the badge reads the lap.
     */
    val lapsCompleted: Int get() = if (target > 0) count / target else 0

    val inLap: Int get() = if (target > 0) count % target else count

    /** 0–10000, the ring's own unit (100.00 %) — clamped at the full ring,
     *  so counting past the goal keeps the gold circle full. */
    val progress: Int
        get() = if (target > 0) {
            ((count.toFloat() / target).coerceIn(0f, 1f) * 10000).toInt()
        } else {
            0
        }

    /**
     * The OUTER ring's progress: the current lap's share, 0..10000, only once
     * at least one lap is complete; -1 means "no outer ring arc at all".
     */
    val lapProgress: Int
        get() = if (lapsCompleted >= 1 && target > 0) {
            (inLap.toFloat() / target * 10000f).toInt().coerceIn(0, 10000)
        } else {
            -1
        }

    /** The count reached (or passed) the target: one success state for the
     *  arc, the number and the badge together. */
    val complete: Boolean get() = target > 0 && count >= target

    /**
     * One compact caption: «2/5 · امروز 123».
     *
     * Kept for the accessibility sentence and for the tests that pinned it;
     * the card itself now renders the two halves as separate pills
     * ([positionLabel] and [todayLabel]), because «2/5» and the day's total are
     * different facts and a slash glued them into one unreadable line.
     */
    val caption: String
        get() {
            val position = if (zikrListSize > 1) {
                "${(index.coerceIn(0, zikrListSize - 1)) + 1}/$zikrListSize · "
            } else {
                ""
            }
            return "${position}امروز $todayTotal"
        }

    /** «ذکر ۲ از ۵» — where we are in the list. Empty for a single-dhikr setup. */
    val positionLabel: String
        get() = if (zikrListSize > 1) {
            "ذکر ${(index.coerceIn(0, zikrListSize - 1)) + 1} از $zikrListSize"
        } else {
            ""
        }

    /** «امروز ۱۲۳» — the day's total across every dhikr, in the accent. */
    val todayLabel: String
        get() = "امروز $todayTotal"

    /**
     * The badge under the ring, per the approved design: the goal before the
     * first lap («از 100»), the lap-in-progress with its beads
     * («+3 · دور 2»), and the completed-lap tick
     * («✓ دور 1 کامل») exactly on a lap boundary.
     */
    val badge: String
        get() = when {
            complete && inLap == 0 -> "✓ دور $lapsCompleted کامل"
            lapsCompleted >= 1 -> "+$inLap · دور ${lapsCompleted + 1}"
            else -> "از $target"
        }

    fun accessibilityLabel(confirming: Boolean): String = when {
        confirming -> "برای بازنشانی شمارنده دوباره بزنید"
        complete -> "شمارنده: $count از $target، کامل شد"
        else -> "شمارنده: $count از $target"
    }
}

internal object TasbihWidgetModel {

    /** Reads the committed counter. Per-zikr values win over the single
     *  `tasbih_count` fallback, which widgets synced before per-zikr targets
     *  still carry. */
    fun read(prefs: SharedPreferences): TasbihWidgetState {
        val index = prefs.getInt("tasbih_zikr_index", 0)
        val zikrList = TasbihGlanceWidgetReceiver.getZikrList(prefs)
        // A BLANK stored name is not a name. It is what a sync that ran before
        // the app's adhkar list had loaded leaves behind, and it renders the
        // card with no title at all — the «عنوان ذکر حذف شده» report. Resolve
        // it from the selection, then the first named entry, then the shipped
        // default: the card must always say which zikr it is counting.
        val dhikr = prefs.getString("tasbih_dhikr", null)?.trim()?.takeIf { it.isNotEmpty() }
            ?: zikrList.getOrNull(index)?.takeIf { it.isNotBlank() }
            ?: zikrList.firstOrNull { it.isNotBlank() }
            ?: "الله أكبر"
        val counts = TasbihGlanceWidgetReceiver.getPerZikrCounts(prefs)
        val count = counts[index] ?: prefs.getInt("tasbih_count", 0)
        val targets = TasbihGlanceWidgetReceiver.getPerZikrTargets(prefs)
        val target = targets.getOrNull(index) ?: prefs.getInt("tasbih_target", 33)
        // «امروز M» must be TODAY's count. The widget keeps its own daily
        // tally (`widget_tasbih_daily_total`, stamped with its date), and the
        // previous implementation ignored it in favour of the sum of the
        // per-zikr counters — which is wrong the moment the app pushes a
        // cumulative (not daily) counter, and wrong again for a zikr the user
        // counted yesterday and never reset. Prefer the daily tally when it
        // belongs to today, and fall back to the sum otherwise.
        val today = TasbihGlanceWidgetReceiver.todayKey()
        val dailyTotal = if (prefs.getString("widget_tasbih_daily_date", "") == today) {
            prefs.getInt("widget_tasbih_daily_total", 0)
        } else {
            0
        }
        val countedToday = counts.values.sum()
        return TasbihWidgetState(
            index = index,
            dhikr = dhikr,
            count = count,
            target = target,
            zikrListSize = zikrList.size,
            todayTotal = maxOf(dailyTotal, countedToday),
        )
    }

    /** Count colour: palette accent normally, green once the target is met
     *  (darkened on the light palette so it stays legible on cream). */
    fun countColor(theme: WidgetTheme.Resolved, state: TasbihWidgetState): Int =
        if (state.complete) {
            if (theme.palette.light) 0xFF2E7D32.toInt() else WidgetTokens.SUCCESS_GREEN
        } else {
            theme.accent
        }

    fun confirmColor(theme: WidgetTheme.Resolved): Int =
        if (theme.palette.light) 0xFFC62828.toInt() else 0xFFFF5252.toInt()
}
