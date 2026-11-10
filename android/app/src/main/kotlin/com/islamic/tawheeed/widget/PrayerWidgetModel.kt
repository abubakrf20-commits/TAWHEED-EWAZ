package com.islamic.tawheeed.widget

import android.content.Context
import android.content.SharedPreferences
import java.util.Calendar

/**
 * The prayer widget's snapshot, read once per render.
 *
 * The RemoteViews build interleaved prefs reads, palette maths and
 * `setTextViewText` calls, so the only way to test «which box is the current
 * prayer» was to assert on a RemoteViews object. Separating the snapshot makes
 * the render a pure function of it, and keeps every wording rule (the — mark
 * for missed prayers, the «تا اقامه» caption, the 12-hour cut) in one place.
 *
 * **Where the times come from.** `widget_times_json` — a tiny payload of
 * today's five clocks plus tomorrow's Fajr, written by the app (or by the
 * native recompute outside the render path). The widget itself never runs the
 * astronomical solver: a composition must stay a pure function of stored data,
 * or every midnight would pay for a full solar calculation inside the launcher's
 * broadcast window. The legacy `prayer_1..5` strings remain as a fallback for
 * installs that have not synced since the migration.
 */
internal data class PrayerWidgetModel(
    val cityName: String,
    val weekday: String,
    val shamsiDate: String,
    val hijriDate: String,
    val gregorianDate: String,
    val use12Hour: Boolean,
    val times: List<String>,
    val statuses: Map<String, String>,
    val countdown: CountdownInfo,
    val iqamahPrefix: String,
    val hasData: Boolean,
    /** Index of the prayer whose adhan has most recently passed — the one the
     *  user can pray right now. -1 before Fajr. */
    val currentIndex: Int = -1,
    /** Prayers the user tapped «خواندم» on, on this card. */
    val markedIndices: Set<Int> = emptySet(),
    /** Prayers the user tapped to UNtick on this card. Beats every other
     *  source — see [isDone]. */
    val clearedIndices: Set<Int> = emptySet(),
    /** Minutes since local midnight at read time; -1 when unknown. Drives the
     *  «past» dimming without needing another clock read in the composable. */
    val nowMinutesOfDay: Int = -1,
    /**
     * Wall-clock instant this snapshot was read at. The phase bar is measured
     * against [CountdownInfo.phaseStartAtMillis] in real millis, so the render
     * must not call the clock a second time and disagree with [nowMinutesOfDay].
     */
    val readAtMillis: Long = 0L,
) {
    /** The boundary the capsule counts down to — a prayer whose name the boxes
     *  already carry. This is also the box whose TIME turns gold. */
    val nextIndex: Int get() = countdown.targetIdx

    val smallDate: String
        get() = if (shamsiDate.isNotEmpty()) "$weekday • $shamsiDate" else hijriDate.ifEmpty { "--" }

    /**
     * The approved design's one date line: shamsi, hijri and Gregorian joined
     * with the middot, each half already formatted by the app. [withGregorian]
     * drops the third half on narrow cells; empty halves are skipped so a
     * missing read never prints a dangling separator.
     */
    /**
     * The three dates as separate parts — shamsi, hijri, then Gregorian when
     * the option is on. The card draws each in its own box (the brief:
     * «هر تاریخ در یک بوکس خاص خودش … مثل اوقات»), so the split belongs here
     * rather than in the renderer, and [dateLine] stays the single-string form
     * for anything that still wants one line.
     */
    fun dateParts(withGregorian: Boolean): List<String> =
        listOf(shamsiDate, hijriDate, gregorianDate.takeIf { withGregorian } ?: "")
            .filter { it.isNotEmpty() }

    fun dateLine(withGregorian: Boolean): String =
        dateParts(withGregorian)
            .joinToString("  •  ")
            .ifEmpty { "--" }

    fun timeLabel(index: Int): String {
        val raw = times.getOrNull(index)?.takeIf { it.isNotEmpty() } ?: return "--:--"
        return if (use12Hour) PrayerWidgetViews.convertTo12h(raw) else raw
    }

    /** Raw 24-hour clock for the box, used by the accessibility sentence. */
    fun rawTime(index: Int): String = times.getOrNull(index) ?: ""

    /**
     * The box's name, and NOTHING else — «صبح», never «— صبح».
     *
     * The dash that used to prefix a missed prayer was removed on the user's
     * 2026-11-07 brief («نمازها هم وقتی تیک نزدم — این علامت هست حذف شود»): on
     * a card whose whole job is five names in a row, a mark that appears on
     * the prayers the user has NOT prayed read as a minus sign against them.
     * Missed state still exists ([isMissed]) — it only dims the row now.
     *
     * A DONE prayer carries no suffix either (2026-11-04: «بجای تیک بنظرم چیز
     * زیباتر باشد»): the card draws the check beside the name. The wording
     * rules stay here; the visual state lives in [PrayerNativeViews].
     */
    fun label(index: Int): String = PRAYER_NAMES[index]

    /**
     * The tick: the app's tracker, OR a tap on this card, UNLESS the user
     * tapped that same box again to take it back.
     *
     * The veto is what makes the box a real toggle. Before it, a prayer the app
     * had recorded as done could never be unticked from the home screen: the
     * tap cleared [markedIndices] and `statuses` still said «done», so the box
     * did not change («تیک برداشت برای هر ۵ نماز»).
     */
    fun isDone(index: Int): Boolean {
        if (clearedIndices.contains(index)) return false
        return statuses[STATUS_KEYS[index]] == "done" || markedIndices.contains(index)
    }

    fun isMissed(index: Int): Boolean =
        statuses[STATUS_KEYS[index]] == "missed" && !markedIndices.contains(index)

    /** True once this prayer's adhan is behind us — the row dims to 65 %. */
    fun isPast(index: Int): Boolean {
        if (nowMinutesOfDay < 0) return false
        val minutes = minuteOfDay(index) ?: return false
        return minutes < nowMinutesOfDay
    }

    fun minuteOfDay(index: Int): Int? {
        val clock = PrayerWidget.parseClock(times.getOrNull(index) ?: "") ?: return null
        return clock.first * 60 + clock.second
    }

    /**
     * How far the day has travelled from the previous adhan to the next one,
     * 0..1 — what the rounded pill under the prayer boxes fills with.
     *
     * Null whenever the window the bar claims to show does not exist:
     *  - before Fajr ([currentIndex] is -1, so there is no «previous» today),
     *  - when the clock was unreadable ([nowMinutesOfDay] is -1).
     * A bar that guessed in those cases would be a number the card cannot
     * justify, so it is simply not drawn.
     *
     * **After Isha the window wraps midnight** — Isha → tomorrow's Fajr — and
     * it is drawn instead of left empty. It used to return null there (the
     * `next <= currentIndex` guard), which is why the bar read as broken every
     * evening («پیشرفت نوار باقیمانده هنوز کار نمی‌کند», 2026-11-07): the one
     * moment a user looks at the card after dark was the one moment the bar
     * had nothing to fill. `countdown.targetAtMillis` already IS tomorrow's
     * Fajr at that point, so the window needs no extra data.
     */
    fun progressFraction(): Float? {
        if (nowMinutesOfDay < 0) return null
        val next = nextIndex
        if (next > currentIndex) {
            val previous = minuteOfDay(currentIndex) ?: return null
            val upcoming = minuteOfDay(next) ?: return null
            if (upcoming <= previous) return null
            val elapsed = (nowMinutesOfDay - previous).toFloat()
            val span = (upcoming - previous).toFloat()
            return (elapsed / span).coerceIn(0f, 1f)
        }
        // The midnight-spanning window: the day's last adhan → the next Fajr.
        val start = minuteOfDay(PRAYER_NAMES.lastIndex) ?: return null
        val target = countdown.targetAtMillis
        if (target <= 0L || start <= 0) return null
        val endCalendar = Calendar.getInstance().apply { timeInMillis = target }
        val end = endCalendar.get(Calendar.HOUR_OF_DAY) * 60 +
            endCalendar.get(Calendar.MINUTE)
        val span = (24 * 60 - start) + end
        if (span <= 0) return null
        val now = if (nowMinutesOfDay < start) nowMinutesOfDay + 24 * 60 else nowMinutesOfDay
        return ((now - start).toFloat() / span).coerceIn(0f, 1f)
    }

    /**
     * The fill for the ONE shared countdown pill — the PHASE cycle both
     * orientations now draw (brief 2026-11-08).
     *
     * [CountdownInfo.fractionAt] measures from the boundary that opened the
     * current phase to [CountdownInfo.targetAtMillis]. That gives the exact
     * behaviour the brief asks for:
     *
     *  - at the adhan, phaseStart IS the adhan → the gold «تا اقامه» bar is at
     *    ZERO, whatever the adhan→adhan bar was showing a second earlier;
     *  - it fills to 1 across the short iqamah window;
     *  - at the iqamah boundary phaseStart becomes that boundary → the accent
     *    «تا اذان» bar is at ZERO again.
     *
     * Asking [progressFraction] here is wrong twice over: outside the iqamah
     * phase it measures from the previous ADHAN (so the bar would already be
     * ~7 % full when it comes back), and inside it `nextIndex == currentIndex`
     * sends it down the midnight-wrapping branch, which snaps the bar to
     * ~full at the very moment the user starts watching the iqamah countdown.
     *
     * The minute-based helpers below remain as a FALLBACK for a snapshot
     * whose solver could not produce a phase boundary (an empty/legacy
     * `widget_times_json`), so a card with partial data still draws a bar
     * rather than a blank pill.
     */
    fun countdownFraction(): Float? {
        val at = if (readAtMillis > 0L) readAtMillis else System.currentTimeMillis()
        val phase = countdown.fractionAt(at)
        if (phase != null) return phase
        return if (countdown.isIqamahPhase) iqamahWindowFraction() else progressFraction()
    }

    /** Minute-precision iqamah window, used only when no phase boundary was
     *  computed. Kept so a legacy snapshot never loses its bar entirely. */
    private fun iqamahWindowFraction(): Float? {
        if (nowMinutesOfDay < 0) return null
        val start = minuteOfDay(currentIndex) ?: return null
        val target = countdown.targetAtMillis
        if (target <= 0L) return null
        val endCalendar = Calendar.getInstance().apply { timeInMillis = target }
        val end = endCalendar.get(Calendar.HOUR_OF_DAY) * 60 +
            endCalendar.get(Calendar.MINUTE)
        val span = end - start
        if (span <= 0) return null
        return ((nowMinutesOfDay - start).toFloat() / span).coerceIn(0f, 1f)
    }

    /**
     * The VERTICAL card's ONE countdown pill (brief 2026-11-08: «یکی باشد
     * مشترک یعنی تا اذان ظهر نشان دهد وقتی اذان شد تا اقامه ظهر نشان دهد»).
     *
     * The horizontal card keeps its longer [iqamahPrefix] («تا اقامه نماز …»);
     * this shorter copy is the vertical layout's own. Both halves come from
     * [countdown], so the caption and the chronometer can never name different
     * boundaries: before an adhan [CountdownInfo.targetIdx] is the UPCOMING
     * prayer and the countdown targets its adhan; inside the iqamah window the
     * solver re-targets [CountdownInfo.targetAtMillis] to the iqamah and leaves
     * `targetIdx` on the prayer whose adhan just passed.
     *
     * Kept here rather than inline in `PrayerVerticalViews.bindCountdown` so
     * the phase switch is testable without a RemoteViews host.
     */
    fun verticalCountdownCaption(): String {
        val name = PRAYER_NAMES[nextIndex.coerceIn(0, PRAYER_NAMES.lastIndex)]
        return if (countdown.isIqamahPhase) "تا اقامه $name" else "تا اذان $name"
    }

    companion object {
        val PRAYER_NAMES = listOf("صبح", "ظهر", "عصر", "مغرب", "عشاء")
        private val STATUS_KEYS = listOf("فجر", "ظهر", "عصر", "مغرب", "عشاء")

        private val WEEK_DAYS = arrayOf(
            "یکشنبه", "دوشنبه", "سه‌شنبه", "چهارشنبه", "پنجشنبه", "جمعه", "شنبه",
        )

        fun read(context: Context, nowMillis: Long = System.currentTimeMillis()): PrayerWidgetModel {
            val prefs: SharedPreferences = WidgetRepository.prefs(context)
            return read(prefs, nowMillis)
        }

        /** Pure-ish seam for tests: same logic, no Context. */
        fun read(
            prefs: SharedPreferences,
            nowMillis: Long = System.currentTimeMillis(),
            todayKey: String = WidgetRepository.todayKey(),
        ): PrayerWidgetModel {
            val cal = Calendar.getInstance().apply { timeInMillis = nowMillis }
            val weekday = WEEK_DAYS.getOrElse(cal.get(Calendar.DAY_OF_WEEK) - 1) { "--" }
            val nowMinutes =
                cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)

            val payload = WidgetPrefs.readTimesPayload(prefs)
            // The payload is the fast path; the legacy per-prayer strings keep a
            // not-yet-migrated install (or a failed encode) rendering.
            val times = if (payload.hasToday) {
                (0 until 5).map { payload.today.at(it) }
            } else {
                (1..5).map { i ->
                    WidgetRepository.parsePrayerString(prefs.getString("prayer_$i", "") ?: "").second
                }
            }
            val iqamahOffsets = WidgetRepository.readIqamahOffsets(prefs)
            val defaultOffset = prefs.getInt("next_prayer_iqamah_offset", 10)
            val countdown = PrayerWidgetViews.computeCountdown(
                nowMillis = nowMillis,
                times = times,
                iqamahOffsets = iqamahOffsets,
                defaultOffset = defaultOffset,
                tomorrowFajr = payload.nextFajr,
            )
            val target = countdown.targetIdx.coerceIn(0, PRAYER_NAMES.lastIndex)
            val prefix = if (countdown.isIqamahPhase) {
                "تا اقامه نماز ${PRAYER_NAMES[target]}"
            } else {
                "تا اذان ${PRAYER_NAMES[target]}"
            }

            // The prayer we are inside right now: the last adhan at or before
            // now. `-1` before Fajr, which is what makes «هیچ‌کدام» renderable.
            var currentIndex = -1
            for (i in 0 until 5) {
                val clock = PrayerWidget.parseClock(times.getOrNull(i) ?: "") ?: continue
                if (clock.first * 60 + clock.second <= nowMinutes) currentIndex = i
            }

            return PrayerWidgetModel(
                cityName = (prefs.getString("city_name", "") ?: "").trim(),
                weekday = weekday,
                shamsiDate = prefs.getString("shamsi_date", "") ?: "",
                hijriDate = prefs.getString("hijri_date", "") ?: "",
                gregorianDate = prefs.getString("gregorian_date", "") ?: "",
                use12Hour = prefs.getBoolean("widget_use_12_hour", true),
                times = times,
                statuses = WidgetRepository.readPrayerStatuses(prefs),
                countdown = countdown,
                iqamahPrefix = prefix,
                hasData = payload.hasToday ||
                    (prefs.getString("prayer_1", "")?.isNotEmpty() ?: false),
                currentIndex = currentIndex,
                markedIndices = WidgetPrefs.readMarks(prefs, todayKey),
                clearedIndices = WidgetPrefs.readCleared(prefs, todayKey),
                nowMinutesOfDay = nowMinutes,
                readAtMillis = nowMillis,
            )
        }

        /** The countdown pattern the countdown leaf applies, e.g. «تا اذان صبح: %s».
         *  The compact card keeps the caption and value on one line; the full
         *  one renders the caption as its own label. */
        fun countdownFormat(prefix: String, inlineSeconds: Boolean): String =
            if (inlineSeconds) "$prefix: %s" else "%s"
    }
}
