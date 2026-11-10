package com.islamic.tawheeed.widget

/**
 * The prayer widget's pure formatting, kept where the JVM tests have always
 * found it.
 *
 * Rendering moved to [PrayerNativeViews]: the RemoteViews builder that used to
 * live here interleaved prefs reads, palette maths and `setTextViewText` calls,
 * and none of that survives as an API. What does survive — and is the only
 * thing the tests ever exercised — is the countdown boundary solver and the
 * 12-hour cut, so they stay here verbatim while every view-shaped call is gone.
 */
class PrayerWidgetViews private constructor() {

    companion object {
        /**
         * Computes the next adhan/iqamah boundary from the five prayer times
         * rendered in the boxes and returns its absolute wall-clock timestamp.
         *
         * The current prayer's iqamah window takes priority, but it ends at the
         * next adhan so an oversized offset cannot carry Asr into Maghrib. After
         * Isha the next boundary is tomorrow's Fajr.
         */
        fun computeCountdown(
            nowMillis: Long,
            times: List<String>,
            iqamahOffsets: List<Int>,
            defaultOffset: Int,
            tomorrowFajr: String? = null,
        ): CountdownInfo {
            val valid = times.mapIndexedNotNull { index, raw ->
                val clock = PrayerWidget.parseClock(raw) ?: return@mapIndexedNotNull null
                val adhan = java.util.Calendar.getInstance().apply {
                    timeInMillis = nowMillis
                    set(java.util.Calendar.HOUR_OF_DAY, clock.first)
                    set(java.util.Calendar.MINUTE, clock.second)
                    set(java.util.Calendar.SECOND, 0)
                    set(java.util.Calendar.MILLISECOND, 0)
                }
                val offset = (iqamahOffsets.getOrNull(index) ?: defaultOffset).coerceAtLeast(0)
                val iqamah = (adhan.clone() as java.util.Calendar).apply {
                    add(java.util.Calendar.MINUTE, offset)
                }
                Triple(index, adhan, iqamah)
            }
            if (valid.isEmpty()) return CountdownInfo(-1, false, 0L)

            var targetAtMillis = 0L
            var targetIdx = -1
            var isIqamahPhase = false

            for (position in valid.indices) {
                val (index, adhan, iqamah) = valid[position]
                val nextAdhan = valid.getOrNull(position + 1)?.second
                val iqamahEnd = minOf(
                    iqamah.timeInMillis,
                    nextAdhan?.timeInMillis ?: Long.MAX_VALUE,
                )
                if (nowMillis >= adhan.timeInMillis && nowMillis < iqamahEnd) {
                    if (nextAdhan != null && iqamah.timeInMillis > nextAdhan.timeInMillis) {
                        // The configured offset lands past the next prayer, so
                        // this iqamah is never called: the window is counting to
                        // that adhan and must name it, not «تا اقامه».
                        targetAtMillis = nextAdhan.timeInMillis
                        targetIdx = valid[position + 1].first
                        isIqamahPhase = false
                    } else {
                        targetAtMillis = iqamahEnd
                        targetIdx = index
                        isIqamahPhase = true
                    }
                    break
                }
            }

            // Otherwise choose the first adhan still ahead today.
            if (targetAtMillis == 0L) {
                for ((index, adhan, _) in valid) {
                    if (adhan.timeInMillis > nowMillis) {
                        targetAtMillis = adhan.timeInMillis
                        targetIdx = index
                        break
                    }
                }
            }

            // After Isha, the next adhan is tomorrow's Fajr. When the app
            // pushed tomorrow's clock (widget_times_json) it is used verbatim;
            // otherwise today's Fajr is reused, which is within a minute of the
            // truth across most of the year and — crucially — never leaves the
            // capsule empty.
            if (targetAtMillis == 0L) {
                val (index, firstAdhan, _) = valid.first()
                val tomorrowClock = tomorrowFajr?.let { PrayerWidget.parseClock(it) }
                val base = if (tomorrowClock != null) {
                    (firstAdhan.clone() as java.util.Calendar).apply {
                        set(java.util.Calendar.HOUR_OF_DAY, tomorrowClock.first)
                        set(java.util.Calendar.MINUTE, tomorrowClock.second)
                    }
                } else {
                    firstAdhan
                }
                targetAtMillis = (base.clone() as java.util.Calendar).apply {
                    add(java.util.Calendar.DAY_OF_YEAR, 1)
                }.timeInMillis
                targetIdx = index
            }

            // ── The phase window ──────────────────────────────────────────
            // The ONE shared countdown pill is a PHASE bar (brief 2026-11-08:
            // «اذان که گفت تا اقامه نوار پیشرفت از اول شروع بشود … نوار پیشرفت
            // که پر شد دوباره بیاید تا اذان و نوار پیشرفت از اول شروع بشود»).
            // Its start is therefore NOT the previous adhan: it is the boundary
            // that OPENED the current phase.
            //
            //   [adhan_i, iqamahEnd_i)      → «تا اقامه»      starts at adhan_i
            //   [iqamahEnd_i, adhan_{i+1})  → «تا اذان i+1»  starts at iqamahEnd_i
            //   [iqamahEnd_isha, fajr+1d)   → «تا اذان صبح»  starts at Isha's iqamah
            //
            // Measuring the adhan phase from the previous ADHAN (what the old
            // progressFraction() did) left the bar at ~7 % the instant it came
            // back from a full gold iqamah bar — a jump, not a reset. The
            // second pill that used to carry its own «تا اقامه» bar is gone on
            // BOTH layouts now, so this one window serves both orientations.
            val boundaries = ArrayList<Long>(valid.size * 2 + 1)
            for ((position, item) in valid.withIndex()) {
                val (_, adhan, iqamah) = item
                val nextAdhan = valid.getOrNull(position + 1)?.second
                val iqamahEnd = minOf(
                    iqamah.timeInMillis,
                    nextAdhan?.timeInMillis ?: Long.MAX_VALUE,
                )
                boundaries.add(adhan.timeInMillis)
                // An iqamah clamped onto the next adhan (oversized offset) IS
                // that adhan; adding the same instant twice is harmless.
                if (iqamahEnd > adhan.timeInMillis) boundaries.add(iqamahEnd)
            }
            // Before Fajr the phase opened at YESTERDAY's Isha iqamah, not at
            // midnight. Without this the bar would silently restart at 00:00.
            val yesterdayIshaIqamah =
                (valid.last().third.clone() as java.util.Calendar).apply {
                    add(java.util.Calendar.DAY_OF_YEAR, -1)
                }.timeInMillis
            boundaries.add(yesterdayIshaIqamah)

            // The last boundary at or before now that still belongs to THIS
            // phase. At an adhan this is that adhan; at an iqamah end it is
            // that iqamah end — in both cases the fraction is exactly 0.
            val phaseStartAtMillis = boundaries
                .asSequence()
                .filter { it <= nowMillis && it < targetAtMillis }
                .maxOrNull() ?: 0L

            return CountdownInfo(
                targetIdx = targetIdx,
                isIqamahPhase = isIqamahPhase,
                targetAtMillis = targetAtMillis,
                phaseStartAtMillis = phaseStartAtMillis,
            )
        }

        /**
         * 12-hour clock label with no «ق.ظ/ب.ظ» marker — the five boxes sit side
         * by side and the marker cost ~55 % of their width, which is what made
         * the times clip on a 3-column placement. The names above each time
         * carry the period instead: صبح and عشاء cannot be afternoon, ظهر cannot
         * be night. Unparseable input passes through.
         */
        fun convertTo12h(timeStr: String): String {
            // Exactly one colon: "05:20:00" is not a clock this widget ever
            // renders, and the tests pin that it passes through untouched.
            val parts = timeStr.split(':')
            if (parts.size != 2) return timeStr
            val h = parts[0].toIntOrNull() ?: return timeStr
            val m = parts[1].toIntOrNull() ?: return timeStr
            if (h !in 0..23 || m !in 0..59) return timeStr
            val h12 = when {
                h == 0 -> 12
                h > 12 -> h - 12
                else -> h
            }
            return "$h12:${m.toString().padStart(2, '0')}"
        }
    }
}

/** Result of [PrayerWidgetViews.computeCountdown]. */
data class CountdownInfo(
    val targetIdx: Int,
    val isIqamahPhase: Boolean,
    val targetAtMillis: Long,
    /**
     * The wall-clock instant the CURRENT phase opened — the boundary from
     * which the one shared progress bar must start at zero. 0 when the solver
     * could not read any clock; the model then falls back to its minute-based
     * day window rather than drawing a made-up bar.
     */
    val phaseStartAtMillis: Long = 0L,
) {
    /**
     * How far the CURRENT phase has travelled, 0..1.
     *
     * This is the whole of the phase cycle: at the adhan phaseStart is that
     * adhan (0), the gold «تا اقامه» bar fills to 1 at iqamahEnd, and at that
     * same instant phaseStart becomes iqamahEnd — so the accent «تا اذان»
     * bar starts at 0 again. Pure wall-clock arithmetic, so a 10-minute
     * iqamah window has 600 seconds of fill, not 10 minute-sized steps.
     */
    fun fractionAt(nowMillis: Long): Float? {
        val span = targetAtMillis - phaseStartAtMillis
        if (phaseStartAtMillis <= 0L || span <= 0L) return null
        return ((nowMillis - phaseStartAtMillis).toFloat() / span.toFloat())
            .coerceIn(0f, 1f)
    }
}
