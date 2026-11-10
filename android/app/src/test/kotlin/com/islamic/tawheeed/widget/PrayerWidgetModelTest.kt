package com.islamic.tawheeed.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The prayer widget's rows and wording, pinned without an Android view.
 *
 * The pill marks and the «تا اذان / تا اقامه» caption are the two things the
 * app's tracker and the countdown solver feed into the widget, so a regression
 * here is a silently wrong home screen.
 */
class PrayerWidgetModelTest {

    private fun model(
        statuses: Map<String, String> = emptyMap(),
        use12Hour: Boolean = true,
        times: List<String> = listOf("04:30", "12:05", "15:40", "18:12", "19:42"),
        shamsiDate: String = "۲ آبان ۱۴۰۵",
        hijriDate: String = "۱۲ جمادی‌الاول ۱۴۴۸",
        countdown: CountdownInfo = CountdownInfo(0, false, 0L),
        prefix: String = "تا اذان صبح",
        marked: Set<Int> = emptySet(),
        cleared: Set<Int> = emptySet(),
        currentIndex: Int = -1,
        nowMinutesOfDay: Int = -1,
        readAtMillis: Long = 0L,
    ) = PrayerWidgetModel(
        cityName = "تهران",
        weekday = "شنبه",
        shamsiDate = shamsiDate,
        hijriDate = hijriDate,
        gregorianDate = "24 Oct 2026",
        use12Hour = use12Hour,
        times = times,
        statuses = statuses,
        countdown = countdown,
        iqamahPrefix = prefix,
        hasData = true,
        markedIndices = marked,
        clearedIndices = cleared,
        currentIndex = currentIndex,
        nowMinutesOfDay = nowMinutesOfDay,
        readAtMillis = readAtMillis,
    )

    @Test
    fun `the bar fills across the day between two adhans`() {
        // 12:05 → 15:40, standing at 13:00: 55 of 215 minutes.
        val m = model(
            currentIndex = 1,
            nowMinutesOfDay = 13 * 60,
            countdown = CountdownInfo(2, false, 0L),
        )
        assertEquals(55f / 215f, m.progressFraction()!!, 0.0005f)
    }

    @Test
    fun `the bar fills through the night instead of going empty`() {
        // The 2026-11-07 report: after Isha the bar had nothing to fill, so
        // the pill read as a bare track every evening («نوار باقیمانده کار
        // نمی‌کند»). The window now wraps midnight — Isha → tomorrow's Fajr.
        val tomorrowFajr = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, 4)
            set(java.util.Calendar.MINUTE, 30)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
            add(java.util.Calendar.DAY_OF_YEAR, 1)
        }.timeInMillis
        val m = model(
            currentIndex = 4,
            nowMinutesOfDay = 21 * 60,
            countdown = CountdownInfo(0, false, tomorrowFajr),
        )
        // 19:42 → 04:30 is 528 minutes; 21:00 is 78 of them.
        assertEquals(78f / 528f, m.progressFraction()!!, 0.0005f)
    }

    @Test
    fun `the bar stays empty before Fajr and without a clock`() {
        assertNull(model(currentIndex = -1, nowMinutesOfDay = 3 * 60).progressFraction())
        assertNull(model(currentIndex = 1, nowMinutesOfDay = -1).progressFraction())
    }

    @Test
    fun `a done prayer and a missed one both read plain`() {
        // 2026-11-04: the ✓ is gone («بجای تیک بنظرم چیز زیباتر باشد») — a
        // done prayer shows a check beside the name with dimmed text, painted
        // by PrayerNativeViews. 2026-11-07: the «— » prefix that a MISSED
        // prayer used to wear is gone as well («وقتی تیک نزدم این علامت هست
        // حذف شود») — the row only dims. The label is the bare name, always.
        val m = model(statuses = mapOf("فجر" to "done", "ظهر" to "missed"))
        assertEquals("صبح", m.label(0))
        assertTrue("done state must stay queryable", m.isDone(0))
        assertEquals("ظهر", m.label(1))
        assertTrue("missed state must stay queryable", m.isMissed(1))
        assertEquals("عصر", m.label(2))
    }

    @Test
    fun `a tap ticks a prayer the app never recorded`() {
        assertFalse(model().isDone(2))
        assertTrue(model(marked = setOf(2)).isDone(2))
        // ...and only that one.
        assertFalse(model(marked = setOf(2)).isDone(3))
    }

    @Test
    fun `a tick the user took back beats the app's done status`() {
        // The app says done, the user tapped the box to untick it on the card.
        // Without the veto the box would keep its check forever, because
        // clearing the mark leaves `statuses` saying «done».
        val m = model(statuses = mapOf("عصر" to "done"), cleared = setOf(2))
        assertFalse("a clear must beat the app's own record", m.isDone(2))
        // The other prayers are untouched.
        assertTrue(model(statuses = mapOf("فجر" to "done"), cleared = setOf(2)).isDone(0))
    }

    @Test
    fun `12-hour labels drop the period marker, 24-hour labels keep the clock`() {
        assertEquals("12:05", model().timeLabel(1))
        assertEquals("6:12", model().timeLabel(3))
        assertEquals("18:12", model(use12Hour = false).timeLabel(3))
    }

    @Test
    fun `a missing time renders the placeholder instead of an empty pill`() {
        assertEquals("--:--", model(times = listOf("", "", "", "", "")).timeLabel(0))
        assertEquals("--:--", model(times = emptyList()).timeLabel(4))
    }

    @Test
    fun `the small card's date line prefers the shamsi date and falls back`() {
        assertEquals("شنبه • ۲ آبان ۱۴۰۵", model().smallDate)
        assertEquals("۱۲ جمادی‌الاول ۱۴۴۸", model(shamsiDate = "").smallDate)
        assertEquals("--", model(shamsiDate = "", hijriDate = "").smallDate)
    }

    @Test
    fun `the countdown is one line on the small card and caption plus value on the big one`() {
        assertEquals("تا اقامه نماز عصر: %s", PrayerWidgetModel.countdownFormat("تا اقامه نماز عصر", true))
        assertEquals("%s", PrayerWidgetModel.countdownFormat("تا اقامه نماز عصر", false))
    }

    /** A wall-clock millis whose HOUR/MINUTE the fraction maths reads back. */
    private fun todayAt(hour: Int, minute: Int): Long =
        java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, hour)
            set(java.util.Calendar.MINUTE, minute)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }.timeInMillis

    @Test
    fun `the one vertical pill names the coming adhan before it happens`() {
        // 2026-11-08: «یکی باشد مشترک یعنی تا اذان ظهر نشان دهد». `targetIdx`
        // is the UPCOMING prayer outside the iqamah window.
        val m = model(
            currentIndex = 0,
            nowMinutesOfDay = 11 * 60,
            countdown = CountdownInfo(1, false, todayAt(12, 5)),
        )
        assertEquals("تا اذان ظهر", m.verticalCountdownCaption())
        // Outside the iqamah window the shared pill measures the ordinary
        // adhan → adhan day window, exactly as it did before the merge.
        assertEquals(m.progressFraction()!!, m.countdownFraction()!!, 0.0001f)
        assertEquals(390f / 455f, m.countdownFraction()!!, 0.0005f)
    }

    @Test
    fun `the same one vertical pill names the iqamah after the adhan`() {
        // «وقتی اذان شد تا اقامه ظهر نشان دهد». During the iqamah phase the
        // solver leaves `targetIdx` on the prayer whose adhan just passed, so
        // the SAME caption slot names ظهر — no second box, no second caption.
        val m = model(
            currentIndex = 1,
            nowMinutesOfDay = 12 * 60 + 8,
            countdown = CountdownInfo(1, true, todayAt(12, 15)),
        )
        assertEquals("تا اقامه ظهر", m.verticalCountdownCaption())
        assertEquals("تا اذان صبح", model(countdown = CountdownInfo(0, false, 0L))
            .verticalCountdownCaption())
    }

    @Test
    fun `the shared pill measures the iqamah window and not the overnight one`() {
        // Merging the two boxes would have been a visual change only if the
        // bar kept the adhan→adhan maths: `nextIndex == currentIndex` sends
        // progressFraction() down its midnight-wrapping branch, so at 12:08
        // the bar would snap to ~99 % while the caption counts to a 12:15
        // iqamah. countdownFraction() measures 12:05 → 12:15 instead.
        val m = model(
            currentIndex = 1,
            nowMinutesOfDay = 12 * 60 + 8,
            countdown = CountdownInfo(1, true, todayAt(12, 15)),
        )
        assertEquals(3f / 10f, m.countdownFraction()!!, 0.0005f)
        assertTrue(
            "the old overnight window read ${m.progressFraction()} for a " +
                "10-minute iqamah countdown",
            m.progressFraction()!! > 0.9f,
        )
        assertTrue(m.countdownFraction()!! < 0.5f)
    }

    @Test
    fun `an unreadable clock leaves the shared pill unfilled but never crashes`() {
        val m = model(
            currentIndex = 1,
            nowMinutesOfDay = -1,
            countdown = CountdownInfo(1, true, todayAt(12, 15)),
        )
        assertNull(m.countdownFraction())
        assertEquals("تا اقامه ظهر", m.verticalCountdownCaption())
    }

    @Test
    fun `the one shared pill resets at the adhan and resets again at the iqamah`() {
        // 2026-11-08: «اذان که گفت تا اقامه نوار پیشرفت از اول شروع بشود و
        // نوار پیشرفت که پر شد دوباره بیاید تا اذان و نوار پیشرفت از اول
        // شروع بشود». Both orientations read this ONE fraction.
        val adhan = todayAt(12, 5)
        val iqamahEnd = todayAt(12, 15)
        val nextAdhan = todayAt(15, 40)

        // At the adhan: caption switches to gold «تا اقامه», bar at ZERO.
        val atAdhan = model(
            currentIndex = 1,
            nowMinutesOfDay = 12 * 60 + 5,
            readAtMillis = adhan,
            countdown = CountdownInfo(1, true, iqamahEnd, adhan),
        )
        assertEquals("تا اقامه ظهر", atAdhan.verticalCountdownCaption())
        assertEquals(0f, atAdhan.countdownFraction()!!, 0.0001f)

        // Five minutes in: the bar has actually moved, so a phase tick has
        // something new to draw.
        val midway = atAdhan.copy(readAtMillis = adhan + 5 * 60_000L)
        assertEquals(0.5f, midway.countdownFraction()!!, 0.0001f)

        // At the iqamah end: caption back to accent «تا اذان», bar at ZERO
        // again — not the ~7 % the old adhan→adhan window would have shown.
        val backToAdhan = model(
            currentIndex = 1,
            nowMinutesOfDay = 12 * 60 + 15,
            readAtMillis = iqamahEnd,
            countdown = CountdownInfo(2, false, nextAdhan, iqamahEnd),
        )
        assertEquals("تا اذان عصر", backToAdhan.verticalCountdownCaption())
        assertEquals(0f, backToAdhan.countdownFraction()!!, 0.0001f)
        assertTrue(
            "the old day window would already be part-filled",
            backToAdhan.progressFraction()!! > 0f,
        )
    }
}
