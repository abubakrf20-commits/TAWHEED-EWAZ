package com.islamic.tawheeed.widget

import java.util.Calendar
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Countdown phase and boundary tests for the prayer widget. */
class PrayerWidgetCountdownTest {
    private val times = listOf("05:20", "12:30", "16:00", "17:45", "19:30")
    private val offsets = listOf(10, 15, 20, 10, 10)

    /** A wall-clock millis for a local HH:mm(:ss), with milliseconds zeroed. */
    private fun nowAt(now: String, seconds: Int = 0): Long {
        val parts = now.split(":").map { it.toInt() }
        return Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, parts[0])
            set(Calendar.MINUTE, parts[1])
            set(Calendar.SECOND, seconds)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    private fun countdown(
        now: String,
        seconds: Int = 0,
        t: List<String> = times,
        offs: List<Int> = offsets,
        def: Int = 10,
    ): CountdownInfo = PrayerWidgetViews.computeCountdown(
        nowMillis = nowAt(now, seconds),
        times = t,
        iqamahOffsets = offs,
        defaultOffset = def,
    )

    private fun assertTarget(result: CountdownInfo, time: String, dayOffset: Int = 0) {
        val parts = time.split(":").map { it.toInt() }
        val expected = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, dayOffset)
            set(Calendar.HOUR_OF_DAY, parts[0])
            set(Calendar.MINUTE, parts[1])
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        assertEquals(expected.timeInMillis, result.targetAtMillis)
    }

    @Test
    fun `before adhan targets the next adhan`() {
        val result = countdown("15:30")
        assertEquals(2, result.targetIdx)
        assertFalse(result.isIqamahPhase)
        assertTarget(result, "16:00")
    }

    @Test
    fun `seconds are preserved at an adhan boundary`() {
        val result = countdown("15:59", seconds = 1)
        assertEquals(2, result.targetIdx)
        assertFalse(result.isIqamahPhase)
        assertTarget(result, "16:00")
    }

    @Test
    fun `between adhan and iqamah targets the same prayer iqamah`() {
        val result = countdown("16:05")
        assertEquals(2, result.targetIdx)
        assertTrue(result.isIqamahPhase)
        assertTarget(result, "16:20")
    }

    @Test
    fun `at adhan the iqamah countdown starts`() {
        val result = countdown("16:00")
        assertEquals(2, result.targetIdx)
        assertTrue(result.isIqamahPhase)
        assertTarget(result, "16:20")
    }

    @Test
    fun `one second before iqamah remains in the iqamah phase`() {
        val result = countdown("16:19", seconds = 59)
        assertEquals(2, result.targetIdx)
        assertTrue(result.isIqamahPhase)
        assertTarget(result, "16:20")
    }

    @Test
    fun `at iqamah switches to the following adhan`() {
        val result = countdown("16:20")
        assertEquals(3, result.targetIdx)
        assertFalse(result.isIqamahPhase)
        assertTarget(result, "17:45")
    }

    @Test
    fun `oversized iqamah names the next adhan instead of itself`() {
        val result = countdown(
            "16:30",
            offs = listOf(10, 15, 120, 10, 10),
        )
        // The configured iqamah (18:00) lands past Asr, so it is never
        // called: the window counts to Asr and must say «تا اذان عصر»,
        // not «تا اقامه».
        assertEquals(3, result.targetIdx)
        assertFalse(result.isIqamahPhase)
        assertTarget(result, "17:45")
    }

    @Test
    fun `at the cap the next prayer takes over`() {
        val result = countdown(
            "17:45",
            offs = listOf(10, 15, 120, 10, 10),
        )
        assertEquals(3, result.targetIdx)
        assertTrue(result.isIqamahPhase)
        assertTarget(result, "17:55")
    }

    @Test
    fun `after iqamah targets the following adhan`() {
        val result = countdown("16:30")
        assertEquals(3, result.targetIdx)
        assertFalse(result.isIqamahPhase)
        assertTarget(result, "17:45")
    }

    @Test
    fun `the last prayer iqamah is still used before it`() {
        val result = countdown("19:35")
        assertEquals(4, result.targetIdx)
        assertTrue(result.isIqamahPhase)
        assertTarget(result, "19:40")
    }

    @Test
    fun `after the last iqamah targets tomorrow's fajr`() {
        val result = countdown("23:00")
        assertEquals(0, result.targetIdx)
        assertFalse(result.isIqamahPhase)
        assertTarget(result, "05:20", dayOffset = 1)
    }

    @Test
    fun `before fajr targets fajr adhan`() {
        val result = countdown("04:50")
        assertEquals(0, result.targetIdx)
        assertFalse(result.isIqamahPhase)
        assertTarget(result, "05:20")
    }

    @Test
    fun `malformed times are skipped safely`() {
        val broken = listOf("05:20", "--:--", "16:00", "17:45", "19:30")
        val result = countdown("15:30", t = broken)
        assertEquals(2, result.targetIdx)
        assertTarget(result, "16:00")
    }

    @Test
    fun `empty times list yields no target`() {
        val result = countdown("15:30", t = emptyList())
        assertEquals(-1, result.targetIdx)
        assertFalse(result.isIqamahPhase)
        assertEquals(0L, result.targetAtMillis)
    }

    // ── The 2026-11-08 phase-cycle brief ─────────────────────────────────
    // «اذان که گفت تا اقامه نوار پیشرفت از اول شروع بشود و نوار پیشرفت که پر
    // شد دوباره بیاید تا اذان و نوار پیشرفت از اول شروع بشود». The bar is a
    // PHASE bar: its zero is the boundary that OPENED the phase, not the
    // previous adhan.

    @Test
    fun `at the adhan the gold phase bar starts at exactly zero`() {
        val at = nowAt("16:00")
        val result = countdown("16:00")
        assertTrue(result.isIqamahPhase)
        assertEquals("the phase must open at the adhan, not the previous one", at, result.phaseStartAtMillis)
        assertEquals(0f, result.fractionAt(at)!!, 0.0001f)
    }

    @Test
    fun `the gold bar actually fills across the iqamah window`() {
        // 16:00 → 16:20 (Asr's 20-minute offset). A 30 s phase tick must find
        // a MOVING value, or the bar would sit at zero for ten minutes.
        val at = nowAt("16:10")
        val result = countdown("16:10")
        assertTrue(result.isIqamahPhase)
        assertEquals(nowAt("16:00"), result.phaseStartAtMillis)
        assertEquals(0.5f, result.fractionAt(at)!!, 0.0005f)
        assertTrue(
            countdown("16:09", seconds = 30)
                .fractionAt(nowAt("16:09", 30))!! < 0.5f,
        )
        assertTrue(
            countdown("16:10", seconds = 30)
                .fractionAt(nowAt("16:10", 30))!! > 0.5f,
        )
    }

    @Test
    fun `at the iqamah end the accent bar restarts at exactly zero`() {
        val at = nowAt("16:20")
        val result = countdown("16:20")
        assertFalse(result.isIqamahPhase)
        assertTarget(result, "17:45")
        assertEquals("the new phase must open at the iqamah end", at, result.phaseStartAtMillis)
        assertEquals(0f, result.fractionAt(at)!!, 0.0001f)
    }

    @Test
    fun `before fajr the bar continues from last night isha iqamah`() {
        // Without yesterday's Isha boundary the bar would silently restart at
        // midnight instead of measuring the whole overnight phase.
        val result = countdown("04:50")
        assertFalse(result.isIqamahPhase)
        val yesterdayIshaIqamah = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, -1)
            set(Calendar.HOUR_OF_DAY, 19)
            set(Calendar.MINUTE, 40) // Isha 19:30 + its 10-minute offset
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        assertEquals(yesterdayIshaIqamah, result.phaseStartAtMillis)
        val fraction = result.fractionAt(nowAt("04:50"))!!
        assertTrue("overnight bar must be partly filled: $fraction", fraction > 0f)
        assertTrue("overnight bar must not be full: $fraction", fraction < 1f)
    }

    @Test
    fun `after the last iqamah the overnight bar starts at zero`() {
        val result = countdown("19:40")
        assertFalse(result.isIqamahPhase)
        assertTarget(result, "05:20", dayOffset = 1)
        assertEquals(nowAt("19:40"), result.phaseStartAtMillis)
        assertEquals(0f, result.fractionAt(nowAt("19:40"))!!, 0.0001f)
        assertTrue(result.fractionAt(nowAt("23:00"))!! > 0f)
    }

    @Test
    fun `a legacy snapshot without a phase start has no phase fraction`() {
        // Old prefs/solver results have phaseStartAtMillis == 0. The model
        // must fall back to its minute-precision window, not divide by an
        // epoch-sized span.
        assertNull(CountdownInfo(1, true, 1_234L).fractionAt(1_000L))
    }
}
