package com.islamic.tawheeed.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The tasbih widget's wording and ring maths, pinned without an Android view.
 *
 * Every string here is user-visible on the home screen: the compact
 * «2/5 · امروز 123» caption, the «✓ کامل شد» badge and the accessibility
 * sentence the ring speaks.
 */
class TasbihWidgetModelTest {

    private fun state(
        index: Int = 1,
        count: Int = 33,
        target: Int = 33,
        zikrListSize: Int = 5,
        todayTotal: Int = 123,
    ) = TasbihWidgetState(
        index = index,
        dhikr = "سبحان الله",
        count = count,
        target = target,
        zikrListSize = zikrListSize,
        todayTotal = todayTotal,
    )

    @Test
    fun `caption carries the position and the day's total`() {
        assertEquals("2/5 · امروز 123", state().caption)
    }

    @Test
    fun `a single zikr list drops the position half`() {
        assertEquals("امروز 7", state(zikrListSize = 1, todayTotal = 7).caption)
    }

    @Test
    fun `an out-of-range index is clamped instead of printing 6 of 5`() {
        assertEquals("5/5 · امروز 3", state(index = 9, todayTotal = 3).caption)
    }

    @Test
    fun `progress is the ring's 0-10000 unit and never passes full`() {
        assertEquals(5000, state(count = 16, target = 32).progress)
        assertEquals(10000, state(count = 999, target = 33).progress)
        assertEquals(0, state(count = 0, target = 33).progress)
    }

    @Test
    fun `a zero target cannot divide by zero`() {
        assertEquals(0, state(count = 5, target = 0).progress)
        assertFalse(state(count = 5, target = 0).complete)
    }

    @Test
    fun `the badge speaks the laps (the 2026-11 brief)`() {
        // Before the first lap: the goal.
        assertEquals("از 33", state(count = 12, target = 33).badge)

        // Exactly on the boundary: the completed lap, ticked.
        val reached = state(count = 33, target = 33)
        assertTrue(reached.complete)
        assertEquals("✓ دور 1 کامل", reached.badge)

        // Inside lap 2: the beads of this lap and its number.
        val lap2 = state(count = 36, target = 33)
        assertEquals(1, lap2.lapsCompleted)
        assertEquals(3, lap2.inLap)
        assertEquals("+3 · دور 2", lap2.badge)
        // The main ring is full gold; the outer ring carries the lap's 9 %.
        assertEquals(10000, lap2.progress)
        assertEquals(909, lap2.lapProgress)

        // No lap yet: no outer arc at all.
        assertEquals(-1, state(count = 5, target = 33).lapProgress)
    }

    @Test
    fun `the ring speaks the counter and the confirm face has its own sentence`() {
        assertEquals("شمارنده: 33 از 33، کامل شد", state().accessibilityLabel(false))
        assertEquals(
            "شمارنده: 12 از 33",
            state(count = 12).accessibilityLabel(false),
        )
        assertEquals(
            "برای بازنشانی شمارنده دوباره بزنید",
            state().accessibilityLabel(true),
        )
    }
}
