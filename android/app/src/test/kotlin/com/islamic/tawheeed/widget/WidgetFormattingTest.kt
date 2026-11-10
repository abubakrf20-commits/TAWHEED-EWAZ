package com.islamic.tawheeed.widget

import java.util.Locale
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

/**
 * The baked-path digits, pinned without an Android view.
 *
 * The reported defect was a launcher-locale leak: on an `ar-*` launcher the
 * platform `TextClock` / `Chronometer` painted Arabic-Indic hours. These
 * helpers are the fallback path, and every string they produce must stay ASCII
 * even when the process default locale is Arabic — so the whole class runs
 * under one.
 *
 * The live leaves themselves are framework views now and cannot be unit
 * tested here; what is testable is the contract they must match.
 */
class WidgetFormattingTest {

    private lateinit var original: Locale

    @Before
    fun useArabicDefault() {
        original = Locale.getDefault()
        Locale.setDefault(Locale.forLanguageTag("ar-EG"))
    }

    @After
    fun restoreDefault() {
        Locale.setDefault(original)
    }

    @Test
    fun `clock digits stay ASCII under an Arabic default locale`() {
        assertEquals("12:05", formatClockTime(hour = 0, minute = 5, use12Hour = true))
        assertEquals("7:40", formatClockTime(hour = 19, minute = 40, use12Hour = true))
        assertEquals("00:05", formatClockTime(hour = 0, minute = 5, use12Hour = false))
        assertEquals("19:40", formatClockTime(hour = 19, minute = 40, use12Hour = false))
    }

    @Test
    fun `countdown digits stay ASCII under an Arabic default locale`() {
        assertEquals("05:05", formatElapsed(305))
        assertEquals("00:00", formatElapsed(0))
        assertEquals("1:02:05", formatElapsed(3_725))
        assertEquals("تا اذان صبح: 05:05", formatCountdown(305, "تا اذان صبح: %s"))
        assertEquals("05:05", formatCountdown(305, "%s"))
    }

    @Test
    fun `a malformed countdown pattern falls back to the bare time`() {
        assertEquals("09:59", formatCountdown(599, "%q"))
    }
}
