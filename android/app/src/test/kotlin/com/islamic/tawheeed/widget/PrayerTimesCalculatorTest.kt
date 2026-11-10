package com.islamic.tawheeed.widget

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

/**
 * Cross-checks the Kotlin prayer-time port and calendar conversions against the
 * Dart `adhan` + `shamsi_date`/`HijriUtils` reference values (computed with
 * `PrayerTimes.utc` for Tehran 35.6892, 51.3890 on 2026-08-11).
 *
 * The local timezone is pinned to UTC so the port's final local conversion
 * matches the Dart UTC output exactly.
 */
class PrayerTimesCalculatorTest {

    @Before
    fun setUp() {
        TimeZone.setDefault(TimeZone.getTimeZone("UTC"))
    }

    private fun fmt(c: Calendar): String {
        val h = c.get(Calendar.HOUR_OF_DAY).toString().padStart(2, '0')
        val m = c.get(Calendar.MINUTE).toString().padStart(2, '0')
        return "$h:$m"
    }

    private fun assertTimes(
        expected: List<String>,
        actual: PrayerTimesCalculator.Times,
    ) {
        assertEquals("fajr", expected[0], fmt(actual.fajr))
        assertEquals("sunrise", expected[1], fmt(actual.sunrise))
        assertEquals("dhuhr", expected[2], fmt(actual.dhuhr))
        assertEquals("asr", expected[3], fmt(actual.asr))
        assertEquals("maghrib", expected[4], fmt(actual.maghrib))
        assertEquals("isha", expected[5], fmt(actual.isha))
    }

    private fun calc(params: PrayerTimesCalculator.Parameters): PrayerTimesCalculator.Times =
        PrayerTimesCalculator.calculate(2026, 8, 11, 35.6892, 51.3890, params)

    @Test
    fun muslimWorldLeague_shafi_matchesAdhanDart() {
        val params = PrayerTimesCalculator.Parameters(
            method = PrayerTimesCalculator.Method.MUSLIM_WORLD_LEAGUE,
            fajrAngle = 18.0,
            ishaAngle = 17.0,
            methodAdjustments = intArrayOf(0, 0, 1, 0, 0, 0),
        )
        assertTimes(listOf("03:45", "05:20", "12:11", "15:54", "18:59", "20:28"), calc(params))
    }

    @Test
    fun muslimWorldLeague_hanafi_matchesAdhanDart() {
        val params = PrayerTimesCalculator.Parameters(
            method = PrayerTimesCalculator.Method.MUSLIM_WORLD_LEAGUE,
            fajrAngle = 18.0,
            ishaAngle = 17.0,
            madhab = 1,
            methodAdjustments = intArrayOf(0, 0, 1, 0, 0, 0),
        )
        assertTimes(listOf("03:45", "05:20", "12:11", "17:00", "18:59", "20:28"), calc(params))
    }

    @Test
    fun tehran_matchesAdhanDart() {
        val params = PrayerTimesCalculator.Parameters(
            method = PrayerTimesCalculator.Method.TEHRAN,
            fajrAngle = 17.7,
            ishaAngle = 14.0,
            maghribAngle = 4.5,
        )
        assertTimes(listOf("03:47", "05:20", "12:10", "15:54", "19:18", "20:10"), calc(params))
    }

    @Test
    fun ummAlQura_ishaInterval_matchesAdhanDart() {
        val params = PrayerTimesCalculator.Parameters(
            method = PrayerTimesCalculator.Method.UMM_AL_QURA,
            fajrAngle = 18.5,
            ishaAngle = 18.0,
            ishaInterval = 90,
        )
        assertTimes(listOf("03:42", "05:20", "12:10", "15:54", "18:59", "20:29"), calc(params))
    }

    @Test
    fun customAngles_matchesAdhanDart() {
        val params = PrayerTimesCalculator.Parameters(
            method = PrayerTimesCalculator.Method.CUSTOM,
            fajrAngle = 19.0,
            ishaAngle = 16.0,
        )
        assertTimes(listOf("03:39", "05:20", "12:10", "15:54", "18:59", "20:22"), calc(params))
    }

    @Test
    fun jalaliConversion_matchesShamsiDate() {
        assertArrayEquals(intArrayOf(1405, 5, 20), IslamicCalendars.jalaliFromGregorian(2026, 8, 11))
        // A couple of extra sanity dates.
        assertArrayEquals(intArrayOf(1405, 1, 1), IslamicCalendars.jalaliFromGregorian(2026, 3, 21))
        assertArrayEquals(intArrayOf(1404, 12, 29), IslamicCalendars.jalaliFromGregorian(2026, 3, 20))
    }

    @Test
    fun hijriConversion_matchesHijriUtils() {
        assertArrayEquals(intArrayOf(1448, 2, 28), IslamicCalendars.hijriFromGregorian(2026, 8, 11, 2))
        assertArrayEquals(intArrayOf(1448, 2, 26), IslamicCalendars.hijriFromGregorian(2026, 8, 11, 0))
    }
}
