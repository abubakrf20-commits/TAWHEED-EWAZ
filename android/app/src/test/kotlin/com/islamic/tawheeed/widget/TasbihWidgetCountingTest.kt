package com.islamic.tawheeed.widget

import org.junit.Assert.assertEquals
import org.junit.Test

/** Guards the tasbih widget's counter behavior: the count must keep going
 *  past the target (user may count 1000 on a 100-target tasbih) while the
 *  ring progress clamps at the full ring for display. */
class TasbihWidgetCountingTest {

    @Test
    fun nextCount_neverCapsAtTarget() {
        assertEquals(101, TasbihGlanceWidgetReceiver.nextCount(100))
        assertEquals(1000, TasbihGlanceWidgetReceiver.nextCount(999))
        assertEquals(1, TasbihGlanceWidgetReceiver.nextCount(0))
    }

    @Test
    fun progressOf_fillsRingExactlyAtTarget() {
        assertEquals(10000, TasbihGlanceWidgetReceiver.progressOf(100, 100))
        assertEquals(5000, TasbihGlanceWidgetReceiver.progressOf(50, 100))
    }

    @Test
    fun progressOf_clampsAtFullRingBeyondTarget() {
        // Ring stays full while the displayed number keeps growing.
        assertEquals(10000, TasbihGlanceWidgetReceiver.progressOf(150, 100))
        assertEquals(10000, TasbihGlanceWidgetReceiver.progressOf(1000, 100))
        assertEquals(10000, TasbihGlanceWidgetReceiver.progressOf(33, 33))
    }

    @Test
    fun progressOf_handlesZeroTarget() {
        assertEquals(0, TasbihGlanceWidgetReceiver.progressOf(42, 0))
    }
}
