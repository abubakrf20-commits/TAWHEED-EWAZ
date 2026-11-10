package com.islamic.tawheeed.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Guards the clock gate in `scheduleBoundaryUpdates`: only a real 24-hour time
 * may arm a boundary alarm. The old check was `time.contains(":")`, which the
 * unreadable "--:--" passes, and the overnight safety net then armed at 00:00.
 */
class PrayerWidgetBoundaryClockTest {
    @Test
    fun `real clock values parse`() {
        assertEquals(Pair(5, 20), PrayerWidget.parseClock("05:20"))
        assertEquals(Pair(5, 20), PrayerWidget.parseClock("5:20"))
        assertEquals(Pair(0, 0), PrayerWidget.parseClock("00:00"))
        assertEquals(Pair(23, 59), PrayerWidget.parseClock("23:59"))
        assertEquals(Pair(7, 5), PrayerWidget.parseClock(" 07:05 "))
    }

    @Test
    fun `the unreadable placeholder is refused`() {
        // Exactly what WidgetRepository.parsePrayerString answers for a value
        // that cannot be read — the string the old contains(":") check let in.
        assertNull(PrayerWidget.parseClock("--:--"))
        assertNull(PrayerWidget.parseClock(WidgetRepository.parsePrayerString("").second))
        assertNull(PrayerWidget.parseClock(WidgetRepository.parsePrayerString("Fajr").second))
    }

    @Test
    fun `out-of-range and malformed values are refused`() {
        for (raw in listOf(
            "",
            "12:",
            ":30",
            "24:00",
            "12:60",
            "12:5",
            "12:345",
            "075:20",
            "05:20 PM",
        )) {
            assertNull("'$raw' must not arm an alarm", PrayerWidget.parseClock(raw))
        }
    }
}
