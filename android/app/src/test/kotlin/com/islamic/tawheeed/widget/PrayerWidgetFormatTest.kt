package com.islamic.tawheeed.widget

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * The prayer rows follow the widget's 12/24-hour setting, and they carry NO
 * «ق.ظ/ب.ظ» marker: the five boxes sit side by side, and the marker widened
 * the line by ~55 % so the times clipped on a 3-column placement. The prayer
 * name above each time already names the period. Hour stays un-zero-padded,
 * minutes padded, exactly like TimeFormatters' 12-hour path
 * (lib/features/home/presentation/utils/time_formatters.dart) minus the marker.
 */
class PrayerWidgetFormatTest {

    @Test
    fun `afternoon times are converted without a marker`() {
        assertEquals("1:45", PrayerWidgetViews.convertTo12h("13:45"))
        assertEquals("12:00", PrayerWidgetViews.convertTo12h("12:00"))
        assertEquals("11:59", PrayerWidgetViews.convertTo12h("23:59"))
    }

    @Test
    fun `midnight and morning times are converted without a marker`() {
        assertEquals("12:05", PrayerWidgetViews.convertTo12h("00:05"))
        assertEquals("5:20", PrayerWidgetViews.convertTo12h("05:20"))
        assertEquals("5:20", PrayerWidgetViews.convertTo12h("5:20"))
    }

    @Test
    fun `the line never carries the period markers`() {
        for (raw in listOf("00:00", "05:30", "12:00", "13:45", "23:59")) {
            val label = PrayerWidgetViews.convertTo12h(raw)
            org.junit.Assert.assertFalse(label, label.contains("ظ"))
        }
    }

    @Test
    fun `unparseable input passes through unchanged`() {
        assertEquals("--:--", PrayerWidgetViews.convertTo12h("--:--"))
        assertEquals("", PrayerWidgetViews.convertTo12h(""))
        assertEquals("05:20:00", PrayerWidgetViews.convertTo12h("05:20:00"))
    }
}
