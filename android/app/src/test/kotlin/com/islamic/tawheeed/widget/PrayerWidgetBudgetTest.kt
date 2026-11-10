package com.islamic.tawheeed.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Guards the prayer card's vertical budget.
 *
 * The bug this pins: the clock used to be sized by its own formula and the
 * prayer band took the leftover height, so on a real 174 dp cell the five pills
 * received ~25 dp for ~50 dp of content and every label rendered sliced through
 * (the widget looked broken, not merely tight). Every assertion here is about
 * the card FITTING its cell, in dp, across the whole resize range — and, since
 * 2026-10-25, across the system font scale too, because sp grows with it while
 * every dp padding stays put.
 */
class PrayerWidgetBudgetTest {

    /** The cell a plain 4×2 placement gets on a 3.25 px/dp phone. */
    private val phoneCellHeight = 174f
    private val phoneCellWidth = 338f

    private val fontScales = listOf(0.85f, 1.0f, 1.15f, 1.3f, 1.5f, 1.6f)

    @Test
    fun `medium card never overflows its cell`() {
        for (fontScale in fontScales) {
            var height = PrayerWidgetBudget.SMALL_MAX_HEIGHT_DP * fontScale
            while (height <= 400f) {
                for (width in listOf(250f, 300f, 338f, 420f, 500f)) {
                    for (hasData in listOf(true, false)) {
                        val m = PrayerWidgetBudget.metrics(width, height, hasData, fontScale)
                        assertTrue(
                            "cell ${width}x$height @$fontScale (hasData=$hasData) " +
                                "overflows by ${m.overflowDp} dp: $m",
                            m.overflowDp <= 0.01f,
                        )
                    }
                }
                height += 1f
            }
        }
    }

    @Test
    fun `the pills keep their full content height on a real phone cell`() {
        val m = PrayerWidgetBudget.metrics(phoneCellWidth, phoneCellHeight, hasData = true)
        // Row padding + both capsule paddings + label line + gap + time line,
        // every text line priced at the MEASURED line height. The capsule is
        // name + time only since 2026-11-04: the check that marks a done prayer
        // lives INSIDE the name line and costs no band.
        val needed = 4f + 2f * m.pillPadDp +
            maxOf(PrayerWidgetBudget.CHECK_DP * m.scale, PrayerWidgetBudget.lineDp(m.pillLabelSizeSp, m.fontScale)) +
            1f + PrayerWidgetBudget.lineDp(m.pillTimeSizeSp, m.fontScale)
        assertEquals(needed, m.pillsBandDp, 0.001f)
        assertTrue(
            "the prayer band is the band that was being clipped",
            m.pillsBandDp >= 38f,
        )
    }

    @Test
    fun `no cell ever pays for a capsule icon holder`() {
        // 2026-11-04 second brief: the 20 dp holder was the only place the
        // «خواندم» check could show, and the budget dropped it on the default
        // cell — so the mark was written for all five prayers and visible on
        // none («فقط نماز مغرب قابل تیک زدن هست»). The holder is gone at every
        // height; the inline check is priced inside the name line instead.
        var height = PrayerWidgetBudget.SMALL_MAX_HEIGHT_DP
        while (height <= 400f) {
            val m = PrayerWidgetBudget.metrics(phoneCellWidth, height, hasData = true)
            val needed = 4f + 2f * m.pillPadDp +
                maxOf(PrayerWidgetBudget.CHECK_DP * m.scale, PrayerWidgetBudget.lineDp(m.pillLabelSizeSp, m.fontScale)) +
                1f + PrayerWidgetBudget.lineDp(m.pillTimeSizeSp, m.fontScale)
            assertEquals("at $height dp", needed, m.pillsBandDp, 0.001f)
            assertTrue("at $height dp", m.overflowDp <= 0.01f)
            height += 5f
        }
    }

    @Test
    fun `the countdown never grows past its caption ceiling`() {
        // «تا اذان صبح هم خیلی بزرگ می‌شود جالب نیست»: the countdown is tied to
        // the clock, and the clock has a 96 sp ceiling — so without its own cap
        // the pill became a headline on a 4×4 placement.
        for (height in listOf(174f, 220f, 300f, 400f)) {
            val m = PrayerWidgetBudget.metrics(phoneCellWidth, height, hasData = true)
            assertTrue(
                "countdown at $height dp: ${m.countdownSizeSp}",
                m.countdownSizeSp <= PrayerWidgetBudget.MAX_COUNTDOWN_SP + 0.001f,
            )
        }
    }

    @Test
    fun `a larger system font buys the pills more height, not less`() {
        val normal = PrayerWidgetBudget.metrics(phoneCellWidth, 220f, true, 1.0f)
        val large = PrayerWidgetBudget.metrics(phoneCellWidth, 220f, true, 1.3f)
        // The TEXT the user reads must grow with the font scale, and with the
        // icon holder gone the band grows with it — nothing is dropped to make
        // room any more.
        fun textLine(m: PrayerWidgetBudget.Metrics): Float =
            maxOf(PrayerWidgetBudget.CHECK_DP * m.scale, PrayerWidgetBudget.lineDp(m.pillLabelSizeSp, m.fontScale)) +
                1f + PrayerWidgetBudget.lineDp(m.pillTimeSizeSp, m.fontScale)
        assertTrue(
            "the pill text must grow with the font scale " +
                "(${textLine(normal)} -> ${textLine(large)})",
            textLine(large) > textLine(normal),
        )
        assertTrue(
            "the clock pays for it instead (${normal.clockSizeSp} -> ${large.clockSizeSp})",
            large.clockSizeSp < normal.clockSizeSp,
        )
        assertTrue(large.overflowDp <= 0.01f)
    }

    @Test
    fun `a broken font scale never produces NaN heights`() {
        for (bad in listOf(0f, -1f, Float.NaN, Float.POSITIVE_INFINITY)) {
            val m = PrayerWidgetBudget.metrics(phoneCellWidth, phoneCellHeight, true, bad)
            assertEquals(1f, m.fontScale, 0.001f)
            assertTrue(m.clockBoxDp.isFinite())
            assertTrue(m.overflowDp <= 0.01f)
        }
    }

    @Test
    fun `the clock is the biggest thing on the card and grows with the cell`() {
        var previous = 0f
        var previousLarge = false
        var height = PrayerWidgetBudget.SMALL_MAX_HEIGHT_DP
        while (height <= 400f) {
            val m = PrayerWidgetBudget.metrics(phoneCellWidth, height, hasData = true)
            // A tier boundary legitimately REPRICES the card: at
            // LARGE_MIN_HEIGHT_DP the verse band appears, and it is paid for
            // out of the clock's share (that is the rule this file exists to
            // enforce), so the clock takes a small step down exactly once at
            // that boundary. Within a tier it must never shrink.
            if (m.isLarge == previousLarge) {
                assertTrue(
                    "clock must not shrink as the cell grows ($height dp)",
                    m.clockSizeSp >= previous,
                )
            }
            assertTrue("clock above the cap", m.clockSizeSp <= PrayerWidgetBudget.CLOCK_MAX_SP)
            assertTrue(
                "clock below the tight floor at $height dp",
                m.clockSizeSp >= PrayerWidgetBudget.CLOCK_TIGHT_MIN_SP,
            )
            previous = m.clockSizeSp
            previousLarge = m.isLarge
            height += 2f
        }
    }

    @Test
    fun `the clock box in the composable is the one the budget paid for`() {
        val m = PrayerWidgetBudget.metrics(phoneCellWidth, phoneCellHeight, true, 1.15f)
        // The render PINS the clock slot to `clockBoxDp` (setViewLayoutHeight),
        // so this product is not an estimate of what the host will draw — it is
        // literally the height the band is given, in dp. The budget must price
        // the same number the render pins, or the card's shape moves by the
        // difference.
        assertEquals(
            m.clockSizeSp * PrayerWidgetBudget.CLOCK_BOX_EM * m.fontScale,
            m.clockBoxDp,
            0.01f,
        )
    }

    @Test
    fun `the pinned clock box is taller than the tallest ink it can meet`() {
        // The host draws the clock's ink 0.284 em below the top of its box and
        // 0.716 em tall — both measured from screencap pixels on the POCO at a
        // 331×269 dp cell (see PrayerWidgetBudget.CLOCK_BOX_EM). The ink's
        // bottom therefore lands at 1.00 em, so anything under that clips the
        // digits; that is exactly what the first pinned build did.
        val inkOffsetEm = 0.284f
        val tallestInkEm = 0.716f
        assertTrue(
            "the clock box must clear the ink it draws " +
                "(box=${PrayerWidgetBudget.CLOCK_BOX_EM}, needs ${inkOffsetEm + tallestInkEm})",
            PrayerWidgetBudget.CLOCK_BOX_EM > inkOffsetEm + tallestInkEm,
        )
        // ...but it must stay well under the ~1.22 em a padded line would need,
        // or pinning the box buys nothing back for the clock.
        assertTrue(
            "the box must be smaller than a padded line",
            PrayerWidgetBudget.CLOCK_BOX_EM < 1.22f,
        )
    }

    @Test
    fun `a 4x3 placement spends its extra height instead of leaving a gap`() {
        val two = PrayerWidgetBudget.metrics(phoneCellWidth, 174f, hasData = true)
        val three = PrayerWidgetBudget.metrics(phoneCellWidth, 260f, hasData = true)
        assertTrue("pills get roomier padding", three.pillPadDp > two.pillPadDp)
        assertTrue("pills get bigger type", three.pillTimeSizeSp >= two.pillTimeSizeSp)
        assertTrue("the clock grows", three.clockSizeSp > two.clockSizeSp)
        assertTrue("the taller card must not overflow", three.overflowDp <= 0.01f)
        // 2026-11-30: the cap moved to 96 sp and the slack went to zero, so a
        // 4x3 no longer reaches it — the clock simply takes everything the
        // bands do not. The cap is asserted on a 4x4 cell instead — 400 dp,
        // not 340: with the icon holder honestly priced (2026-11-04) a 340 dp
        // cell hands the clock 119.9 dp of leftover = 95.9 sp, 0.07 short of
        // the cap.
        assertTrue(
            "a 4x3 clock stays under the cap",
            three.clockSizeSp < PrayerWidgetBudget.CLOCK_MAX_SP,
        )
        // 400 dp is past both ceilings. The HEIGHT ceiling is CLOCK_MAX_SP;
        // the WIDTH ceiling is `(width - 2 x sideInset) / 2.4`, and on a real
        // card that one binds first — a clock that is taller than it is wide
        // would run off the card's sides. So the assertion is "it is at a
        // ceiling, and never past the hard one".
        val four = PrayerWidgetBudget.metrics(phoneCellWidth, 400f, hasData = true)
        assertTrue(
            "a 4x4 clock reaches a ceiling (${four.clockSizeSp})",
            four.clockSizeSp >= 120f,
        )
        assertTrue(four.clockSizeSp <= PrayerWidgetBudget.CLOCK_MAX_SP + 0.001f)
        assertTrue(four.overflowDp <= 0.01f)
    }

    @Test
    fun `the countdown can be tied to the clock without stealing the boxes`() {
        // Two-pass sizing: the countdown is a BAND, so a caller that draws it
        // bigger must have the budget re-priced — otherwise the extra height
        // comes out of the prayer boxes and slices them.
        //
        // 200 dp, not 260: the countdown has a caption ceiling now
        // (MAX_COUNTDOWN_SP), and on a tall cell BOTH passes land on the cap —
        // the rule is only observable where the tied value is still below it.
        val base = PrayerWidgetBudget.metrics(phoneCellWidth, 200f, hasData = true)
        val tied = PrayerWidgetBudget.metrics(
            phoneCellWidth,
            200f,
            hasData = true,
            countdownOverrideSp = base.clockSizeSp * PrayerWidgetBudget.COUNTDOWN_TO_CLOCK,
        )
        assertTrue(
            "the countdown must be priced in",
            tied.countdownBandDp > base.countdownBandDp,
        )
        assertTrue(
            "the clock pays for the bigger countdown, not the pills",
            tied.clockSizeSp < base.clockSizeSp,
        )
        assertEquals(
            "the pills keep their measured room",
            base.pillsBandDp,
            tied.pillsBandDp,
            0.001f,
        )
        assertTrue("the taller band still fits", tied.overflowDp <= 0.01f)
        assertTrue(
            "the countdown stays under the clock",
            tied.countdownSizeSp < tied.clockSizeSp,
        )
    }

    @Test
    fun `the gregorian date only joins the strip on a wide cell`() {
        assertTrue(PrayerWidgetBudget.metrics(338f, 174f, true).showGregorian)
        assertTrue(!PrayerWidgetBudget.metrics(260f, 174f, true).showGregorian)
    }

    @Test
    fun `a short cell switches to the compact card`() {
        assertTrue(PrayerWidgetBudget.metrics(250f, 120f, true).isSmall)
        assertTrue(PrayerWidgetBudget.metrics(250f, 140f, true).isSmall)
        assertTrue(!PrayerWidgetBudget.metrics(250f, 174f, true).isSmall)
    }

    @Test
    fun `a large font moves the compact-card threshold with it`() {
        // 174 dp is a full card at 1.0, but not enough room for five pills at
        // 1.5 — the compact card takes over instead of slicing them.
        assertTrue(!PrayerWidgetBudget.metrics(338f, 174f, true, 1.0f).isSmall)
        assertTrue(PrayerWidgetBudget.metrics(338f, 174f, true, 1.5f).isSmall)
    }
}
