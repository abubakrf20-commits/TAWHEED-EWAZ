package com.islamic.tawheeed.widget

/**
 * The VERTICAL prayer card's budget — the same discipline as
 * [PrayerWidgetBudget], for the second layout.
 *
 * The horizontal card has one band that can flex (the clock) and five boxes
 * that share the row. The vertical card has five ROWS that are each a fixed
 * line of text, so the arithmetic is different in one important way: **the
 * rows cannot be squeezed.** A row is a name and a time; if it is priced less
 * than one line it draws its text sliced through, which is the exact defect
 * [PrayerWidgetBudget] was created to stop («باکس‌ها مخفی می‌شوند»).
 *
 * So this budget does what the horizontal one does — total every other band
 * first, give the clock what is left — and then, when even the minimum clock
 * does not fit, it drops a TIER instead of shaving a row:
 *
 *  - [Tier.FULL] — header chips, live clock, date line, five rows, countdown
 *    pill. Needs ~246 dp at font scale 1.0 on a 250 dp-wide cell, i.e. a 4×3
 *    placement. This is the card the option is FOR.
 *  - [Tier.COMPACT] — the five rows and the countdown, nothing else. Needs
 *    ~162 dp, so the widget's own 160 dp minimum cell and the default 4×2
 *    (174 dp) both land here. The rows ARE the point of this layout, so they
 *    are the last thing to go; the clock and the header are the first.
 *
 * Both thresholds are computed from the same band arithmetic that draws the
 * card — never a hand-picked number — and `PrayerVerticalBudgetTest` asserts
 * that each tier fits the cell it is selected for and that the next tier down
 * would not have.
 */
internal object PrayerVerticalBudget {

    /** Which of the two vertical cards a cell can hold. */
    enum class Tier {
        /** Header + clock + date + rows + countdown. */
        FULL,

        /** Rows + countdown only — the rows are what this layout is for. */
        COMPACT,
    }

    // ── The row ──
    // A row is one line: [check] name … time. The name and the time share the
    // line, so the row is as tall as the TALLER of the two — which is the time,
    // because it is the larger type. Pricing the name alone would leave every
    // row 4 dp short.
    //
    // These three numbers are load-bearing, and they were chosen against the
    // cell rather than by eye: with 5 rows to pay for, every 1 dp of row air
    // costs the card 5 dp, and the COMPACT tier has to fit the widget's own
    // 160 dp minimum cell. 2026-11-07 brief («ارتفاع باکسها کمتر شود» +
    // «فاصله بگذار»): the row's own padding went 1.5 → 1 dp and the type a
    // step smaller — the box hugs its line — while the gap between boxes
    // became REAL air (drawn by the row-gap spacers, see below) instead of
    // padding folded inside the boxes' backgrounds.
    const val ROW_PAD_V_DP = 1f
    const val ROW_PAD_H_DP = 6f
    /**
     * Air between two rows on the COMPACT tier (the five rows only, no header
     * / clock / date) — the tight default the 160 dp minimum cell requires,
     * and the number [PrayerVerticalBudgetTest] locks in. Drawn by the four
     * `prayer_row_gap_N` spacers, so it is air BETWEEN the backgrounds.
     */
    const val ROW_GAP_DP = 3f

    /**
     * Air between two rows on the FULL tier (header + clock + date + five
     * rows + countdown). The full tier is the design the option is FOR; the
     * gap is wider here than on COMPACT, where every 1 dp of air costs the
     * card 5 dp and the 160 dp cell cannot afford it. Priced in
     * [Bands.rowsBandDp] and drawn by the spacers.
     */
    const val FULL_ROW_GAP_DP = 8f
    const val LABEL_SP = 12f
    const val TIME_SP = 13.5f

    /**
     * The five prayer boxes grow by 8 % (brief 2026-11-08: «بوکس های نماز صبح
     * وظهر و بقیه نمازها … هر کدام 8% بزرگتر و ارتفاع هر کدام بیشتر شود تا این
     * صفحه کامل شود»). One factor on the row's type, check, padding and gap
     * keeps the box a scaled copy of itself rather than a bigger label in the
     * same thin strip, and it is applied in [bands] — where [Metrics.rowsBandDp]
     * is priced — so the tier threshold, the clock's take and the pixels drawn
     * all agree.
     *
     * The deleted second «تا اقامه» pill used to cost the FULL tier its own
     * `iqamahBandDp` (~23 dp at font scale 1); with v3 that band is gone, so
     * the bigger rows are paid for out of the space the second box occupied
     * and no cell loses a tier to them. On COMPACT the cell has no clock to
     * give up, so [compactRowGrowth] grows the rows only as far as the cell
     * can actually pay for — forcing a blind 1.08× there would overflow the
     * provider's own 160 dp minimum and hand the user the horizontal card.
     */
    const val ROW_GROWTH = 1.08f

    // ── The clock ──
    /** The clock's floor on a cell that has room for the full tier. */
    const val CLOCK_MIN_SP = 24f
    /** Below this the clock is not drawn at all: the tier is COMPACT. */
    const val CLOCK_TIGHT_MIN_SP = 16f
    const val CLOCK_MAX_SP = 96f
    /** «۱۲:۰۳» is ~2.25 em, so `width / 2.4` is the widest clock that cannot
     *  touch the card's side inset. */
    const val CLOCK_MAX_WIDTH_DIVISOR = 2.4f

    /** The countdown never becomes a headline — same ceiling as the
     *  horizontal card, so the two layouts read as one family. */
    const val MAX_COUNTDOWN_SP = 15f

    /** The compact tier's own top air; the full tier's lives inside
     *  [PrayerWidgetBudget.CARD_TOP_INSET_DP] + the header band. */
    const val COMPACT_TOP_INSET_DP = 4f

    /**
     * The height at which the vertical card is drawn at «1×» — the default
     * 4×3 placement (243 × 364 dp measured on the POCO X7 Pro).
     *
     * Every size in [Metrics] is priced at this reference and then multiplied
     * by `height / REFERENCE_HEIGHT`, which is what makes a resized card a
     * scaled copy of itself instead of the same small type floating in a
     * bigger box («وقتی بزرگ می‌کنم عناصر متناسب با حجم باکس بزرگ و کوچک
     * بشوند», 2026-11-07). Before this, only the clock absorbed the extra
     * height — the rows stayed 13.5 sp on every cell, so enlarging the widget
     * added air and nothing else.
     */
    const val REFERENCE_HEIGHT_DP = 364f

    /** Ceiling for the growth factor — a card taller than 2.4× the reference
     *  is past any launcher cell this widget is placed on. */
    const val MAX_GROWTH = 2.4f

    data class Metrics(
        val widthDp: Float,
        val heightDp: Float,
        val fontScale: Float,
        val tier: Tier,
        val showGregorian: Boolean,
        val showProgress: Boolean,
        val scale: Float,
        val sideInsetDp: Float,
        val topInsetDp: Float,
        val rowPadDp: Float,
        /** The inter-row air this tier draws, priced inside [rowsBandDp]. */
        val rowGapDp: Float,
        val rowPadHDp: Float,
        val labelSizeSp: Float,
        val timeSizeSp: Float,
        val checkDp: Float,
        val clockSizeSp: Float,
        /** The clock slot's pinned height in dp — 0 on the COMPACT tier. */
        val clockBoxDp: Float,
        val countdownSizeSp: Float,
        val captionSizeSp: Float,
        val dateSizeSp: Float,
        val headerSizeSp: Float,
        val rowsBandDp: Float,
        /**
         * ONE countdown pill only (v3). The second gold «تا اقامه» box was
         * deleted on the 2026-11-08 brief; its band was removed from the whole
         * budget rather than left priced-but-undrawn, which is what freed the
         * height for [ROW_GROWTH]. Its v4 horizontal counterpart does the
         * same now: one phase-aware pill, no second band on either card.
         */
        val countdownBandDp: Float,
        val headerBandDp: Float,
        val dateBandDp: Float,
        val hintBandDp: Float,
        val gapDatesPillsDp: Float,
        val gapPillsCountDp: Float,
    ) {
        val isCompact: Boolean get() = tier == Tier.COMPACT

        /**
         * The same card, enlarged by [g] — every VERTICAL size multiplied, the
         * cell and the tier untouched.
         *
         * This is the whole of «عناصر متناسب با حجم باکس بزرگ و کوچک بشوند»:
         * one factor on the type, the row air, the check and the bands, so a
         * taller cell draws a bigger CARD rather than the same card with more
         * empty space.
         *
         * Two things are deliberately left out, because they are measured
         * against the card's WIDTH and the cell only grew taller:
         *  * the horizontal air ([sideInsetDp], [rowPadHDp]) — [metricsAt]
         *    already priced it from the width, and growing it here would eat
         *    the very width the rows need;
         *  * the clock ([clockSizeSp], [clockBoxDp]) — it is the widest thing
         *    on the card, so [metrics] re-derives it from the leftover height
         *    once everything else has taken its share. Scaling it by height
         *    alone is what drew «10:4» with the minutes off the card.
         */
        fun scaledBy(g: Float): Metrics = copy(
            topInsetDp = topInsetDp * g,
            rowPadDp = rowPadDp * g,
            rowGapDp = rowGapDp * g,
            labelSizeSp = labelSizeSp * g,
            timeSizeSp = timeSizeSp * g,
            checkDp = checkDp * g,
            countdownSizeSp = countdownSizeSp * g,
            captionSizeSp = captionSizeSp * g,
            dateSizeSp = dateSizeSp * g,
            headerSizeSp = headerSizeSp * g,
            rowsBandDp = rowsBandDp * g,
            countdownBandDp = countdownBandDp * g,
            headerBandDp = headerBandDp * g,
            dateBandDp = dateBandDp * g,
            hintBandDp = hintBandDp * g,
            gapDatesPillsDp = gapDatesPillsDp * g,
            gapPillsCountDp = gapPillsCountDp * g,
        )

        /** Positive means the card is taller than the cell and will clip. */
        val overflowDp: Float get() = totalContentDp - heightDp

        /**
         * Every band the card draws, added up.
         *
         * [topInsetDp] is only counted on the COMPACT tier: on FULL it is
         * already the first term of [headerBandDp] (which is the padding plus
         * the chip row, exactly as the horizontal budget prices it), and adding
         * it again would charge the card twice for the same air.
         */
        val totalContentDp: Float
            get() = rowsBandDp + countdownBandDp + hintBandDp +
                headerBandDp + dateBandDp + clockBoxDp +
                gapDatesPillsDp + gapPillsCountDp +
                (if (isCompact) topInsetDp else 0f)
    }

    private fun line(sp: Float, fontScale: Float): Float =
        PrayerWidgetBudget.lineDp(sp, fontScale)

    /**
     * The bands for one «extra height» and one [ROW_GROWTH] share — the ONE
     * place a band is priced.
     *
     * [metricsAt] calls this at `extra = 0` to find the height at which the
     * full card first fits and again at the real extra to price the card that
     * is actually drawn; [compactRowGrowth] calls it twice more at 1× and at
     * the full 8 % to find what a COMPACT cell can afford. Several passes,
     * because the bands grow with the height and the height decides which
     * bands exist — a single pass would be circular.
     */
    private data class Bands(
        val rowPadDp: Float,
        val labelSizeSp: Float,
        val timeSizeSp: Float,
        val checkDp: Float,
        /** The DRAWN inter-row air, already multiplied by [ROW_GROWTH] or by
         *  the compact cell's affordable share of it. [Metrics.rowGapDp] reads
         *  this value so the price and the `prayer_row_gap_N` pixels agree. */
        val rowGapDp: Float,
        val captionSizeSp: Float,
        val countdownSizeSp: Float,
        val rowsBandDp: Float,
        val countdownBandDp: Float,
        val headerBandDp: Float,
        val dateBandDp: Float,
        val topInsetDp: Float,
        val sideInsetDp: Float,
        val compactFixedDp: Float,
    )

    /**
     * How much of [ROW_GROWTH] a COMPACT cell can pay for.
     *
     * The FULL tier's clock absorbs the cost, but COMPACT has no flexible band
     * at all: it is five rows, one pill and the cell. An 8 % row costs ~9 dp
     * there while the 160 dp minimum cell only has ~8 dp of slack, so a blind
     * multiplication would overflow the provider's declared minimum and
     * `PrayerVerticalViews.shouldRenderVertical` would fall back to the
     * horizontal card — a far worse outcome than slightly smaller rows on the
     * smallest possible placement. Interpolating on the card's own priced
     * height keeps COMPACT exact-fitting at every cell, and reaches the full
     * 8 % as soon as the cell can afford it.
     */
    private fun compactRowGrowth(
        h: Float,
        scale: Float,
        fs: Float,
        hasData: Boolean,
    ): Float {
        val base = bands(
            extra = 0f, scale = scale, fs = fs, hasData = hasData,
            rowGapDp = ROW_GAP_DP, rowGrowth = 1f,
        ).compactFixedDp
        val grown = bands(
            extra = 0f, scale = scale, fs = fs, hasData = hasData,
            rowGapDp = ROW_GAP_DP, rowGrowth = ROW_GROWTH,
        ).compactFixedDp
        val cost = grown - base
        if (cost <= 0f) return ROW_GROWTH
        val affordable = ((h - base) / cost).coerceIn(0f, 1f)
        return 1f + (ROW_GROWTH - 1f) * affordable
    }

    private fun bands(
        extra: Float,
        scale: Float,
        fs: Float,
        hasData: Boolean,
        rowGapDp: Float,
        rowGrowth: Float,
    ): Bands {
        // The row's vertical padding is its OWN air — the inter-row gap is
        // drawn by the four `prayer_row_gap_N` spacers and priced below as
        // 4 × rowGapDp on top of the five padded boxes.
        //
        // `rowGrowth` scales the ROW and nothing else: a bigger box is a bigger
        // name, time, check, padding and gap (a scaled copy), while the header,
        // the date and the ONE countdown pill keep their own type. The caps are
        // grown with it so a tall cell's `extra` slope is not silently cut off.
        val rowPad = ((ROW_PAD_V_DP + extra * 0.010f) * rowGrowth)
            .coerceAtMost(6f * rowGrowth)
        val labelSp = ((LABEL_SP + extra * 0.012f) * rowGrowth)
            .coerceAtMost(15.5f * rowGrowth)
        val timeSp = ((TIME_SP + extra * 0.020f) * rowGrowth)
            .coerceAtMost(22f * rowGrowth)
        val captionSp = (12f + extra * 0.010f).coerceAtMost(14f)
        val countdownSp = (13f + extra * 0.012f).coerceAtMost(MAX_COUNTDOWN_SP)
        val checkDp = PrayerWidgetBudget.CHECK_DP * scale * rowGrowth
        val grownGap = rowGapDp * rowGrowth

        val rowLine = maxOf(checkDp, line(labelSp, fs), line(timeSp, fs))
        val rowsBand = 5f * (rowLine + 2f * rowPad) + 4f * grownGap
        // ONE countdown pill (v3). Its own 2 dp of top air, one line of the
        // larger of the caption/value types, and the card's bottom inset. The
        // second gold pill's band is deliberately gone — that is the height
        // that pays for the bigger rows.
        val countdownBand = 2f /* pill top air */ +
            (line(maxOf(countdownSp, captionSp), fs) + 2f) +
            PrayerWidgetBudget.CARD_BOTTOM_INSET_DP
        val hintBand = if (hasData) 0f else PrayerWidgetBudget.HINT_DP

        val headerBand = PrayerWidgetBudget.CARD_TOP_INSET_DP * scale +
            maxOf(
                PrayerWidgetBudget.HEADER_ICON_DP * scale,
                line(PrayerWidgetBudget.HEADER_TEXT_SP, fs),
            ) +
            2f * PrayerWidgetBudget.CHIP_PAD_V_DP
        // The date strip carries GAP_CLOCK_DATES as its own top padding, so the
        // gap is priced INSIDE this band and must not be charged again below.
        val dateBand = PrayerWidgetBudget.GAP_CLOCK_DATES_DP +
            line(PrayerWidgetBudget.DATE_TEXT_SP, fs) + 1f

        val topInset = COMPACT_TOP_INSET_DP * scale
        return Bands(
            rowPadDp = rowPad,
            labelSizeSp = labelSp,
            timeSizeSp = timeSp,
            checkDp = checkDp,
            rowGapDp = grownGap,
            captionSizeSp = captionSp,
            countdownSizeSp = countdownSp,
            rowsBandDp = rowsBand,
            countdownBandDp = countdownBand,
            headerBandDp = headerBand,
            dateBandDp = dateBand,
            topInsetDp = topInset,
            sideInsetDp = PrayerWidgetBudget.CARD_SIDE_INSET_DP * scale,
            compactFixedDp = topInset + rowsBand + countdownBand + hintBand,
        )
    }

    /**
     * Prices one vertical card for one cell.
     *
     * The tier is decided by arithmetic, not by a hand-picked number:
     * `fullMinHeight` is the height at which every band, at its SMALLEST
     * price, plus the smallest clock the full tier will ever draw still fits.
     * Above it the card is full and the extra height is shared between the
     * type and the clock; below it the card is compact, the type stays at its
     * minimum and the spare height reads as air between the rows (the row
     * stack is centred, exactly like the native layout).
     *
     * Anchoring the growth at that threshold rather than at the compact
     * height is what makes the two tiers mutually exclusive: at the threshold
     * the extra is zero, so the bands cannot grow past the cell the tier was
     * chosen for.
     */
    fun metrics(
        widthDp: Float,
        heightDp: Float,
        hasData: Boolean,
        fontScale: Float = 1f,
        showProgress: Boolean = true,
        showGregorian: Boolean = true,
    ): Metrics {
        val w = if (widthDp.isFinite() && widthDp > 0f) widthDp else 250f
        val h = if (heightDp.isFinite() && heightDp > 0f) heightDp else 174f

        // Proportional growth: the card is priced at the reference height and
        // then every size is multiplied by this factor. Because the full tier
        // prices its cell EXACTLY (the clock takes what the bands leave),
        // scaling a card that filled `refHeight` by `g` fills `g * refHeight`
        // — which is the cell. So a resized widget is a true scaled copy:
        // taller rows, larger names, times and clock, wider gaps.
        val growth = (h / REFERENCE_HEIGHT_DP).coerceIn(1f, MAX_GROWTH)
        val base = metricsAt(w, h / growth, hasData, fontScale, showProgress, showGregorian)
        // The card is priced at the REFERENCE height, so the real cell height
        // has to be written back or `overflowDp` would report the growth as an
        // overflow and `shouldRenderVertical` would flip the card back to the
        // horizontal layout.
        if (growth == 1f) return base
        var scaled = base.scaledBy(growth).copy(heightDp = h)

        // The clock is re-derived, not scaled: it is the widest thing the card
        // draws, and the cell grew taller without necessarily growing wider. A
        // 4×4 cell is 1.79× the reference height but only 1.41× its width, so a
        // clock multiplied by the height factor ran off the side and drew
        // «10:4» with the minutes outside the card. Here it simply takes the
        // height the other bands left, bounded by the width — exactly the rule
        // [metricsAt] applies at 1×.
        if (scaled.tier == Tier.FULL) {
            val withoutClock = scaled.totalContentDp - scaled.clockBoxDp
            val available = (h - withoutClock).coerceAtLeast(0f)
            val widthCeiling = (w - 2f * scaled.sideInsetDp) / CLOCK_MAX_WIDTH_DIVISOR
            val clock = minOf(
                available / (PrayerWidgetBudget.CLOCK_BOX_EM * scaled.fontScale),
                CLOCK_MAX_SP * growth,
                widthCeiling,
            ).coerceAtLeast(CLOCK_TIGHT_MIN_SP)
            scaled = scaled.copy(
                clockSizeSp = clock,
                clockBoxDp = clock * PrayerWidgetBudget.CLOCK_BOX_EM * scaled.fontScale,
            )
        }

        // Whatever height the width-capped clock cannot take is left to the
        // layout: `prayer_row_stack` carries weight 1 and centre_vertical, so
        // the rows stay centred and the spare height reads as even air above
        // and below them. Dumping it into the row gaps instead (the first
        // attempt) pushed them to 32 dp and broke the scaled-copy look.
        return scaled
    }

    private fun metricsAt(
        w: Float,
        h: Float,
        hasData: Boolean,
        fontScale: Float,
        showProgress: Boolean,
        showGregorian: Boolean,
    ): Metrics {
        val fs = if (fontScale.isFinite() && fontScale > 0f) {
            fontScale.coerceIn(0.85f, 1.6f)
        } else {
            1f
        }
        val scale = (w / 250f).coerceIn(0.8f, 1.4f)

        val gapDatesPills = PrayerWidgetBudget.GAP_DATES_PILLS_DP
        val gapPillsCount = PrayerWidgetBudget.GAP_PILLS_COUNT_DP

        // Pass one: the smallest price at FULL row growth, and from it the
        // height at which the full card first fits. It is always priced with
        // the FULL tier's row gap, because that is the gap the full card draws.
        // There is NO iqamah band any more: v3 deleted the second pill, so the
        // band it used to consume now belongs to the rows and the clock.
        val min = bands(
            extra = 0f, scale = scale, fs = fs, hasData = hasData,
            rowGapDp = FULL_ROW_GAP_DP, rowGrowth = ROW_GROWTH,
        )
        val fullMinHeight = min.compactFixedDp +
            min.headerBandDp + min.dateBandDp +
            gapDatesPills + gapPillsCount +
            CLOCK_TIGHT_MIN_SP * PrayerWidgetBudget.CLOCK_BOX_EM * fs

        val tier = if (h >= fullMinHeight) Tier.FULL else Tier.COMPACT
        val extra = if (tier == Tier.FULL) (h - fullMinHeight).coerceAtLeast(0f) else 0f

        // Pass two: the card that is actually drawn. FULL keeps its wider gap
        // and the full 8 % — its clock is the band that gives up the height.
        // COMPACT drops to the tight gap and grows the rows only as far as the
        // cell pays for (the 160 dp minimum has ~8 dp of slack, not ~9).
        val b = if (tier == Tier.FULL) {
            if (extra > 0f) {
                bands(
                    extra = extra, scale = scale, fs = fs, hasData = hasData,
                    rowGapDp = FULL_ROW_GAP_DP, rowGrowth = ROW_GROWTH,
                )
            } else {
                min
            }
        } else {
            bands(
                extra = 0f, scale = scale, fs = fs, hasData = hasData,
                rowGapDp = ROW_GAP_DP,
                rowGrowth = compactRowGrowth(h, scale, fs, hasData),
            )
        }

        var clockSize = 0f
        var clockBox = 0f
        val topInset: Float
        if (tier == Tier.FULL) {
            topInset = PrayerWidgetBudget.CARD_TOP_INSET_DP * scale
            // Exact fit: the clock takes the height every other band leaves,
            // bounded by the card's width. A width-capped clock gives the rest
            // back to `prayer_row_stack`, whose weight 1 centres the rows.
            val available = (h - (b.compactFixedDp - b.topInsetDp) - b.headerBandDp -
                b.dateBandDp - gapDatesPills - gapPillsCount).coerceAtLeast(0f)
            val widthCeiling = (w - 2f * b.sideInsetDp) / CLOCK_MAX_WIDTH_DIVISOR
            clockSize = minOf(
                available / (PrayerWidgetBudget.CLOCK_BOX_EM * fs),
                CLOCK_MAX_SP,
                widthCeiling,
            ).coerceAtLeast(CLOCK_TIGHT_MIN_SP)
            clockBox = clockSize * PrayerWidgetBudget.CLOCK_BOX_EM * fs
        } else {
            topInset = b.topInsetDp
        }

        return Metrics(
            widthDp = w,
            heightDp = h,
            fontScale = fs,
            tier = tier,
            // The Gregorian third of the date line only has room on a wide
            // cell — the same 300 dp gate the horizontal card applies.
            showGregorian = showGregorian && w >= 300f,
            showProgress = showProgress,
            scale = scale,
            sideInsetDp = b.sideInsetDp,
            topInsetDp = topInset,
            rowPadDp = b.rowPadDp,
            rowGapDp = b.rowGapDp,
            rowPadHDp = ROW_PAD_H_DP * scale,
            labelSizeSp = b.labelSizeSp,
            timeSizeSp = b.timeSizeSp,
            checkDp = b.checkDp,
            clockSizeSp = clockSize,
            clockBoxDp = clockBox,
            countdownSizeSp = b.countdownSizeSp,
            captionSizeSp = b.captionSizeSp,
            dateSizeSp = PrayerWidgetBudget.DATE_TEXT_SP,
            headerSizeSp = PrayerWidgetBudget.HEADER_TEXT_SP,
            rowsBandDp = b.rowsBandDp,
            countdownBandDp = b.countdownBandDp,
            headerBandDp = if (tier == Tier.FULL) b.headerBandDp else 0f,
            dateBandDp = if (tier == Tier.FULL) b.dateBandDp else 0f,
            hintBandDp = if (hasData) 0f else PrayerWidgetBudget.HINT_DP,
            gapDatesPillsDp = if (tier == Tier.FULL) gapDatesPills else 0f,
            gapPillsCountDp = if (tier == Tier.FULL) gapPillsCount else 0f,
        )
    }
}
