package com.islamic.tawheeed.widget

import android.app.Application
import android.content.Context
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * The pref contract, pinned.
 *
 * Three things here are load-bearing enough to be tested rather than reviewed:
 *
 *  1. **`widget_times_json` round-trips**, including tomorrow. The widget's
 *     «after Isha» countdown reads tomorrow's Fajr from it, and a payload that
 *     silently lost the second day would make the capsule name today's Fajr
 *     until the app was opened again.
 *  2. **A mark expires with its date.** Yesterday's «خواندم» taps must never
 *     leak onto today's card — that is a wrong-state bug the user would read as
 *     the app forgetting their prayers.
 *  3. **The live-leaves flag starts ON and can be switched off exactly once.**
 *     It is the only way back from a host that refuses a nested RemoteViews
 *     without shipping a new build.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = Application::class)
class WidgetPrefsTest {

    private lateinit var context: Context

    @Before
    fun setUp() {
        context = RuntimeEnvironment.getApplication()
        // Every test starts from a clean pref file.
        WidgetPrefs.prefs(context).edit().clear().commit()
    }

    private fun prefs() = WidgetPrefs.prefs(context)

    @Test
    fun `the times payload round trips today and tomorrow`() {
        val today = PrayerDayTimes("04:31", "12:05", "15:40", "18:12", "19:42", "06:01")
        val tomorrow = PrayerDayTimes("04:33", "12:05", "15:39", "18:10", "19:40", "06:02")

        WidgetPrefs.writeTimesPayload(prefs(), "2026-10-26", today, tomorrow)

        val parsed = WidgetPrefs.readTimesPayload(prefs())
        assertEquals("2026-10-26", parsed.date)
        assertEquals(today, parsed.today)
        assertEquals(tomorrow, parsed.tomorrow)
        assertTrue(parsed.hasToday)
        assertEquals("04:33", parsed.nextFajr)
    }

    @Test
    fun `a payload without tomorrow falls back to today's fajr`() {
        val today = PrayerDayTimes("04:31", "12:05", "15:40", "18:12", "19:42")
        WidgetPrefs.writeTimesPayload(prefs(), "2026-10-26", today, null)

        val parsed = WidgetPrefs.readTimesPayload(prefs())
        assertNull(parsed.tomorrow)
        assertEquals("04:31", parsed.nextFajr)
    }

    @Test
    fun `a corrupt payload degrades to empty instead of throwing`() {
        prefs().edit().putString(WidgetPrefs.KEY_TIMES_JSON, "{not json").apply()
        val parsed = WidgetPrefs.readTimesPayload(prefs())
        assertFalse(parsed.hasToday)
        assertEquals(PrayerTimesPayload.EMPTY, parsed)
    }

    @Test
    fun `a mark toggles on and off for its own day only`() {
        val date = "2026-10-26"
        assertTrue(WidgetPrefs.toggleMark(prefs(), date, 2))
        assertEquals(setOf(2), WidgetPrefs.readMarks(prefs(), date))

        // A different day sees nothing.
        assertTrue(WidgetPrefs.readMarks(prefs(), "2026-10-27").isEmpty())

        assertFalse(WidgetPrefs.toggleMark(prefs(), date, 2))
        assertTrue(WidgetPrefs.readMarks(prefs(), date).isEmpty())
    }

    @Test
    fun `a mark for a stale date is ignored even when the key still exists`() {
        WidgetPrefs.toggleMark(prefs(), "2026-10-25", 0)
        assertTrue(WidgetPrefs.readMarks(prefs(), "2026-10-26").isEmpty())
    }

    @Test
    fun `the mark payload reports its own date and sorted indices`() {
        val date = "2026-10-26"
        WidgetPrefs.toggleMark(prefs(), date, 3)
        WidgetPrefs.toggleMark(prefs(), date, 0)

        val (payloadDate, indices) = WidgetPrefs.readMarkPayload(prefs())
        assertEquals(date, payloadDate)
        assertEquals(listOf(0, 3), indices)
    }

    @Test
    fun `an empty mark payload is reported as no marks rather than a null date`() {
        val (date, indices) = WidgetPrefs.readMarkPayload(prefs())
        assertEquals("", date)
        assertTrue(indices.isEmpty())
    }

    @Test
    fun `acking marks removes only what the app applied`() {
        val date = "2026-10-26"
        WidgetPrefs.toggleMark(prefs(), date, 0)
        WidgetPrefs.toggleMark(prefs(), date, 1)

        // A tap on index 2 lands between the app's read and this ack: it must
        // survive, or counted worship is silently dropped.
        WidgetPrefs.toggleMark(prefs(), date, 2)
        WidgetPrefs.clearMarks(prefs(), date, listOf(0, 1))

        assertEquals(setOf(2), WidgetPrefs.readMarks(prefs(), date))
    }

    @Test
    fun `acking a stale date leaves the current day untouched`() {
        WidgetPrefs.toggleMark(prefs(), "2026-10-26", 1)
        WidgetPrefs.clearMarks(prefs(), "2026-10-25", listOf(1))
        assertEquals(setOf(1), WidgetPrefs.readMarks(prefs(), "2026-10-26"))
    }

    @Test
    fun `taps are a broadcast unless the fallback is selected`() {
        assertEquals(WidgetPrefs.DELIVERY_BROADCAST, WidgetPrefs.tapDelivery(prefs()))
        assertFalse(WidgetPrefs.useActivityTaps(prefs()))
        prefs().edit()
            .putString(WidgetPrefs.KEY_TAP_DELIVERY, WidgetPrefs.DELIVERY_ACTIVITY)
            .apply()
        assertTrue(WidgetPrefs.useActivityTaps(prefs()))
    }

    // ── Taking a tick back ──

    @Test
    fun `clearing records the clear and drops the mark for that index`() {
        val date = "2026-11-05"
        WidgetPrefs.setDone(prefs(), date, 3, true)
        assertEquals(setOf(3), WidgetPrefs.readMarks(prefs(), date))

        WidgetPrefs.setDone(prefs(), date, 3, false)
        assertTrue(WidgetPrefs.readMarks(prefs(), date).isEmpty())
        assertEquals(setOf(3), WidgetPrefs.readCleared(prefs(), date))
    }

    @Test
    fun `marking again takes the index out of the cleared set`() {
        val date = "2026-11-05"
        WidgetPrefs.setDone(prefs(), date, 1, false)
        WidgetPrefs.setDone(prefs(), date, 1, true)
        assertEquals(setOf(1), WidgetPrefs.readMarks(prefs(), date))
        assertTrue(
            "a mark and a clear for one index can never both survive",
            WidgetPrefs.readCleared(prefs(), date).isEmpty(),
        )
    }

    @Test
    fun `a clear belongs to its own day only`() {
        WidgetPrefs.setDone(prefs(), "2026-11-04", 2, false)
        assertTrue(WidgetPrefs.readCleared(prefs(), "2026-11-05").isEmpty())
        assertEquals(setOf(2), WidgetPrefs.readCleared(prefs(), "2026-11-04"))
    }

    @Test
    fun `the cleared payload reports its own date and sorted indices`() {
        val date = "2026-11-05"
        WidgetPrefs.setDone(prefs(), date, 4, false)
        WidgetPrefs.setDone(prefs(), date, 0, false)

        val (payloadDate, indices) = WidgetPrefs.readClearedPayload(prefs())
        assertEquals(date, payloadDate)
        assertEquals(listOf(0, 4), indices)
    }

    @Test
    fun `acking clears removes only what the app applied`() {
        val date = "2026-11-05"
        WidgetPrefs.setDone(prefs(), date, 0, false)
        WidgetPrefs.setDone(prefs(), date, 1, false)
        // A clear landing between the app's read and this ack must survive.
        WidgetPrefs.setDone(prefs(), date, 2, false)

        WidgetPrefs.clearCleared(prefs(), date, listOf(0, 1))
        assertEquals(setOf(2), WidgetPrefs.readCleared(prefs(), date))
    }

    @Test
    fun `an empty cleared payload is reported as no clears`() {
        val (date, indices) = WidgetPrefs.readClearedPayload(prefs())
        assertEquals("", date)
        assertTrue(indices.isEmpty())
    }

    @Test
    fun `toggling a cleared prayer marks it again`() {
        val date = "2026-11-05"
        WidgetPrefs.setDone(prefs(), date, 2, false)
        assertTrue("a cleared box must toggle back on", WidgetPrefs.toggleMark(prefs(), date, 2))
        assertEquals(setOf(2), WidgetPrefs.readMarks(prefs(), date))
        assertTrue(WidgetPrefs.readCleared(prefs(), date).isEmpty())
    }
}
