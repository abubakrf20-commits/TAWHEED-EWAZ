package com.islamic.tawheeed.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs

/**
 * Guards the VERTICAL prayer card's budget — the second layout.
 *
 * The horizontal card's bug was a band drawn bigger than it was priced, which
 * sliced the five pills. The vertical card's failure mode is the mirror image
 * and just as bad: it has FIVE rows of text that cannot be compressed, so a
 * card that prices them short draws five names and times sliced through, and a
 * card that is asked for more height than the cell has clips its countdown off
 * the bottom edge.
 *
 * So these assertions are about three things:
 *
 *  1. **The tier is chosen by arithmetic.** The full card (header + clock +
 *     date + five rows + countdown) is only drawn on a cell where every band
 *     plus the smallest clock it would ever draw actually fits; anything
 *     shorter gets the compact card, and a cell too short for THAT is refused
 *     outright by `PrayerVerticalViews.shouldRenderVertical`, which falls back
 *     to the horizontal card rather than clipping.
 *  2. **A row is never priced below one line.** [PrayerVerticalBudget.ROW_PAD_V_DP]
 *     and [PrayerVerticalBudget.TIME_SP] are load-bearing: with five rows,
 *     every 1 dp of row air costs the card 5 dp, which is why they are small.
 *  3. **A taller cell never steps the tier back down.** The bands grow with
 *     height, so a bad slope could make a bigger cell report a smaller tier.
 */
class PrayerVerticalBudgetTest {

    private val fontScales = listOf(0.85f, 1.0f, 1.15f, 1.3f, 1.5f, 1.6f)
    private val widths = listOf(250f, 300f, 338f, 420f, 500f)

    /** The widget's own declared minimum cell (`widget_prayer_info.xml`). */
    private val minCellHeight = 160f
    private val minCellWidth = 250f

    @Test
    fun `the compact card fits the widget's minimum cell at font scale 1`() {
        val m = PrayerVerticalBudget.metrics(minCellWidth, minCellHeight, hasData = true)
        assertEquals(PrayerVerticalBudget.Tier.COMPACT, m.tier)
        assertTrue(
            "the five rows + countdown must fit the 160 dp minimum cell, " +
                "overflowed by ${m.overflowDp} dp: $m",
            m.overflowDp <= 0.01f,
        )
    }

    @Test
    fun `the full card is drawn on a tall cell and prices exactly the cell`() {
        val m = PrayerVerticalBudget.metrics(320f, 300f, hasData = true)
        assertEquals(
            "a 320x300 cell has room for header + clock + date + rows + countdown",
            PrayerVerticalBudget.Tier.FULL,
            m.tier,
        )
        // The clock takes exactly what the other bands left, so the card is the
        // cell — no phantom band, no leftover hole.
        assertTrue(
            "the full card must price its cell exactly, off by ${m.overflowDp} dp: $m",
            abs(m.overflowDp) <= 0.01f,
        )
        assertTrue(
            "the clock may never fall under the tight floor: ${m.clockSizeSp} sp",
            m.clockSizeSp >= PrayerVerticalBudget.CLOCK_TIGHT_MIN_SP,
        )
    }

    @Test
    fun `a card that reports the full tier always fits its cell`() {
        for (fontScale in fontScales) {
            for (width in widths) {
                var height = minCellHeight
                while (height <= 420f) {
                    for (hasData in listOf(true, false)) {
                        val m = PrayerVerticalBudget.metrics(
                            width, height, hasData, fontScale,
                        )
                        // The full card is only ever selected when every band
                        // plus its smallest clock fits — if that ever stops
                        // being true the countdown clips off the bottom edge,
                        // which is the one thing this tier rule exists to
                        // prevent. (A COMPACT card may overflow, and
                        // PrayerVerticalViews.shouldRenderVertical then refuses
                        // the vertical layout entirely rather than clip.)
                        if (m.tier == PrayerVerticalBudget.Tier.FULL) {
                            assertTrue(
                                "cell ${width}x$height @$fontScale " +
                                    "(hasData=$hasData) drew the full card and " +
                                    "overflowed by ${m.overflowDp} dp: $m",
                                m.overflowDp <= 0.01f,
                            )
                        }
                        assertTrue(
                            "cell ${width}x$height @$fontScale priced a " +
                                "non-positive band: $m",
                            m.rowsBandDp > 0f && m.countdownBandDp > 0f,
                        )
                    }
                    height += 1f
                }
            }
        }
    }

    @Test
    fun `a row is never priced below one line of its own time`() {
        for (fontScale in fontScales) {
            for (width in widths) {
                var height = minCellHeight
                while (height <= 420f) {
                    val m = PrayerVerticalBudget.metrics(width, height, true, fontScale)
                    val oneLine = PrayerWidgetBudget.lineDp(m.timeSizeSp, fontScale)
                    val rowBand = m.rowsBandDp / 5f
                    assertTrue(
                        "row priced ${rowBand} dp for a ${oneLine} dp line " +
                            "at ${width}x$height @$fontScale: $m",
                        rowBand >= oneLine,
                    )
                    height += 1f
                }
            }
        }
    }

    @Test
    fun `the tier never steps back down as the cell grows`() {
        for (fontScale in fontScales) {
            for (width in widths) {
                var sawFull = false
                var height = minCellHeight
                while (height <= 420f) {
                    val m = PrayerVerticalBudget.metrics(width, height, true, fontScale)
                    if (m.tier == PrayerVerticalBudget.Tier.FULL) {
                        sawFull = true
                    } else if (sawFull) {
                        throw AssertionError(
                            "the tier fell back to COMPACT at ${width}x$height " +
                                "@$fontScale after the full card had fitted: $m",
                        )
                    }
                    height += 1f
                }
            }
        }
    }

    @Test
    fun `a taller cell never shrinks the rows`() {
        // Every band is monotone in height: the slope hands the extra dp to the
        // type, and the clock takes the remainder. A band that shrank as the
        // cell grew would make a resize look like a different card.
        for (fontScale in fontScales) {
            var previous = PrayerVerticalBudget.metrics(
                minCellWidth, minCellHeight, true, fontScale,
            )
            var height = minCellHeight + 1f
            while (height <= 420f) {
                val m = PrayerVerticalBudget.metrics(minCellWidth, height, true, fontScale)
                assertTrue(
                    "rows shrank from ${previous.rowsBandDp} to ${m.rowsBandDp} " +
                        "at ${minCellWidth}x$height @$fontScale",
                    m.rowsBandDp >= previous.rowsBandDp - 0.001f,
                )
                previous = m
                height += 1f
            }
        }
    }

    @Test
    fun `degenerate cells still price a card`() {
        for ((w, h) in listOf(0f to 0f, -5f to -5f, Float.NaN to Float.NaN)) {
            val m = PrayerVerticalBudget.metrics(w, h, true)
            assertTrue("NaN width leaked into the budget: $m", m.widthDp.isFinite())
            assertTrue("NaN height leaked into the budget: $m", m.heightDp.isFinite())
            assertTrue("NaN rows band: $m", m.rowsBandDp.isFinite())
            assertTrue("NaN clock: $m", m.clockSizeSp.isFinite())
        }
    }

    @Test
    fun `a taller cell scales the whole card instead of adding air`() {
        // The 2026-11-07 brief: «وقتی بزرگ می‌کنم عناصر متناسب با حجم باکس
        // بزرگ و کوچک بشوند». Every drawn size — the type, the row air, the
        // check — must grow by the SAME factor as the cell, which is what makes
        // a resized card a scaled copy of itself. Before this the rows stayed at
        // 13.5 sp on every cell and only the clock grew, so enlarging the
        // widget added empty space.
        //
        // The clock is deliberately NOT in this list: it is bounded by the
        // card's WIDTH, and this cell only grew taller. That bound is the next
        // test's job.
        val reference = PrayerVerticalBudget.REFERENCE_HEIGHT_DP
        val small = PrayerVerticalBudget.metrics(243f, reference, hasData = true)
        val big = PrayerVerticalBudget.metrics(243f, reference * 1.5f, hasData = true)
        val g = 1.5f

        assertEquals(
            "the cell grew 1.5x but the times grew ${big.timeSizeSp / small.timeSizeSp}x",
            g,
            big.timeSizeSp / small.timeSizeSp,
            0.02f,
        )
        assertEquals(g, big.labelSizeSp / small.labelSizeSp, 0.02f)
        assertEquals(g, big.rowGapDp / small.rowGapDp, 0.02f)
        assertEquals(g, big.checkDp / small.checkDp, 0.02f)
        assertEquals(
            "the grown card must still price exactly its cell",
            PrayerVerticalBudget.Tier.FULL,
            big.tier,
        )
        assertTrue("the grown card overflowed by ${big.overflowDp} dp: $big", big.overflowDp <= 0.01f)
    }

    @Test
    fun `the full card's five prayer boxes are 8 percent larger`() {
        // 2026-11-08: «بوکس های نماز صبح وظهر و بقیه نمازها … هر کدام 8%
        // بزرگتر و ارتفاع هر کدام بیشتر شود». The first cell that can hold the
        // full card is the one whose `extra` is zero, so every row size there
        // is exactly the base × ROW_GROWTH — no slope to confuse the ratio.
        var threshold = minCellHeight
        while (threshold <= 420f &&
            PrayerVerticalBudget.metrics(minCellWidth, threshold, true).tier !=
            PrayerVerticalBudget.Tier.FULL
        ) {
            // A fine step lands within 0.05 dp of the real threshold, so the
            // type's `extra` slope is negligible and the ratio is exactly 8 %.
            threshold += 0.05f
        }
        val m = PrayerVerticalBudget.metrics(minCellWidth, threshold, hasData = true)
        assertEquals(PrayerVerticalBudget.Tier.FULL, m.tier)
        val g = PrayerVerticalBudget.ROW_GROWTH

        assertEquals(
            "the prayer names did not grow by 8 %",
            PrayerVerticalBudget.LABEL_SP * g, m.labelSizeSp, 0.02f,
        )
        assertEquals(
            "the prayer times did not grow by 8 %",
            PrayerVerticalBudget.TIME_SP * g, m.timeSizeSp, 0.02f,
        )
        assertEquals(
            "each box's own height did not grow by 8 %",
            PrayerVerticalBudget.ROW_PAD_V_DP * g, m.rowPadDp, 0.02f,
        )
        assertEquals(
            "the check did not grow with its box",
            PrayerWidgetBudget.CHECK_DP * m.scale * g, m.checkDp, 0.02f,
        )
        assertEquals(
            "the air between boxes did not grow with them",
            PrayerVerticalBudget.FULL_ROW_GAP_DP * g, m.rowGapDp, 0.02f,
        )

        // The box the launcher draws must be the box the budget priced: five
        // lines of the grown type plus four grown gaps. A row grown in type but
        // priced at the old height is exactly the slicing bug this class exists
        // to prevent.
        val drawn = 5f * (
            maxOf(
                m.checkDp,
                PrayerWidgetBudget.lineDp(m.labelSizeSp, m.fontScale),
                PrayerWidgetBudget.lineDp(m.timeSizeSp, m.fontScale),
            ) + 2f * m.rowPadDp
        ) + 4f * m.rowGapDp
        assertEquals(
            "the rows band priced ${m.rowsBandDp} dp but draws $drawn dp: $m",
            drawn, m.rowsBandDp, 0.02f,
        )
    }

    @Test
    fun `only one countdown pill is priced`() {
        // v3 deleted the second gold «تا اقامه» box. Its band must be gone from
        // the budget too, or the card would price a box it never draws and the
        // clock would give up ~23 dp to empty air. The deleted band is what
        // pays for the 8 % larger rows.
        // Up to the reference height the growth factor is 1×, so the band is
        // exactly the formula below. Above it `scaledBy(g)` multiplies the
        // whole card (including the 2 dp constants), which the clock-width
        // test covers separately.
        for (h in listOf(minCellHeight, 200f, 260f, 300f, 364f)) {
            val m = PrayerVerticalBudget.metrics(minCellWidth, h, hasData = true)
            val onePill = 2f /* top air */ +
                (PrayerWidgetBudget.lineDp(
                    maxOf(m.countdownSizeSp, m.captionSizeSp), m.fontScale,
                ) + 2f) +
                PrayerWidgetBudget.CARD_BOTTOM_INSET_DP
            assertEquals(
                "a second pill's band leaked back in at ${minCellWidth}x$h: $m",
                onePill, m.countdownBandDp, 0.02f,
            )
            assertTrue(
                "the merged card overflows at ${minCellWidth}x$h by " +
                    "${m.overflowDp} dp: $m",
                m.overflowDp <= 0.01f,
            )
        }
        // 250x260 was COMPACT before the merge (the second pill's band lifted
        // the full threshold to ~270 dp). With one pill it holds the full card.
        assertEquals(
            PrayerVerticalBudget.Tier.FULL,
            PrayerVerticalBudget.metrics(minCellWidth, 260f, hasData = true).tier,
        )
    }

    @Test
    fun `the smallest cell grows the rows only as far as it can pay for`() {
        // An 8 % row costs ~9 dp on COMPACT while the 160 dp minimum has ~8 dp
        // of slack. Forcing the full factor there would overflow the provider's
        // own minimum and `shouldRenderVertical` would hand back the horizontal
        // card — worse than rows 7 % larger instead of 8 %.
        val min = PrayerVerticalBudget.metrics(minCellWidth, minCellHeight, true)
        assertEquals(PrayerVerticalBudget.Tier.COMPACT, min.tier)
        assertTrue(
            "the minimum cell must fit exactly after the growth (${min.overflowDp} dp): $min",
            abs(min.overflowDp) <= 0.01f,
        )
        assertTrue(
            "the rows were not grown at all on the smallest cell: $min",
            min.timeSizeSp > PrayerVerticalBudget.TIME_SP,
        )
        assertTrue(
            "the rows grew past the brief's 8 %: $min",
            min.timeSizeSp <= PrayerVerticalBudget.TIME_SP *
                PrayerVerticalBudget.ROW_GROWTH + 0.01f,
        )

        // The grown COMPACT card is priced at 161.892 dp, so the 162 dp cell
        // is the first one that can afford the whole 8 % (the 160 dp minimum
        // settles for ~6.4 %).
        val roomy = PrayerVerticalBudget.metrics(minCellWidth, minCellHeight + 2f, true)
        assertEquals(
            PrayerVerticalBudget.TIME_SP * PrayerVerticalBudget.ROW_GROWTH,
            roomy.timeSizeSp, 0.02f,
        )
        assertTrue(
            "the roomier compact cell overflowed by ${roomy.overflowDp} dp: $roomy",
            roomy.overflowDp <= 0.01f,
        )
    }

    @Test
    fun `the clock stops at the card's width instead of running off it`() {
        // The device caught this one: a 4×4 cell is 1.79× taller than the
        // reference but only 1.41× wider, so a clock scaled by height alone
        // drew «10:4» with the minutes outside the card. The clock is bounded
        // by width, so it must clamp there — and the height it gives back has
        // to become air between the rows, not a hole at the foot.
        val reference = PrayerVerticalBudget.REFERENCE_HEIGHT_DP
        for (w in listOf(243f, 300f, 342f, 400f, 480f)) {
            for (factor in listOf(1.0f, 1.2f, 1.5f, 1.8f, 2.4f)) {
                val m = PrayerVerticalBudget.metrics(w, reference * factor, hasData = true)
                val ceiling =
                    (w - 2f * m.sideInsetDp) / PrayerVerticalBudget.CLOCK_MAX_WIDTH_DIVISOR
                assertTrue(
                    "a ${w}dp card drew a ${m.clockSizeSp}sp clock past its " +
                        "${ceiling}sp ceiling: $m",
                    m.clockSizeSp <= ceiling + 0.01f,
                )
                assertTrue(
                    "the card must still fill its cell (${m.overflowDp} dp): $m",
                    m.overflowDp <= 0.01f,
                )
            }
        }
    }
}
