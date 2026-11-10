package com.islamic.tawheeed.widget

/**
 * The prayer card's vertical budget, lifted out of the Glance composable so it
 * can be reasoned about — and unit-tested on the JVM — without a launcher.
 *
 * The card is a fixed cell (a plain 4×2 placement on a 3.25 px/dp phone is
 * 174 dp tall). Sizing the clock by its own formula and letting the prayer band
 * take the leftover height overran that cell: the weighted band received ~25 dp
 * for ~50 dp of content, so every pill rendered with its labels sliced through.
 * The rule that replaced it is the one encoded here: **every other band is
 * totalled first and the clock takes exactly what is left**, flexing between
 * [CLOCK_MIN_SP] and [CLOCK_MAX_SP] instead of pushing its siblings past the
 * cell's bottom edge.
 *
 * Two details matter and are easy to lose when editing by eye:
 *
 *  - Every text band is `sp × [TEXT_LINE_HEIGHT] × fontScale`. Both factors are
 *    load-bearing. The Persian text in the pills falls back to Noto Naskh,
 *    whose line box is far taller than the 1.17 em Roboto gets away with, and
 *    a phone set to a large system font scales every sp up while every dp
 *    padding stays put. With either one missing the pills were still sliced
 *    on real devices while the maths said they fit (device report
 *    2026-10-25). The clock box is the same product, which is why the clock
 *    reads *smaller in sp* on a large-font phone — the same physical size.
 *  - [SLACK_DP] is breathing room, not a requirement. On a short cell the clock
 *    falls under [CLOCK_MIN_SP] rather than eat the slack and clip the pills,
 *    but never under [CLOCK_TIGHT_MIN_SP] — the time has to stay the biggest
 *    thing on the card.
 */
internal object PrayerWidgetBudget {

    /**
     * Below this the compact card is drawn instead of the five-pill card.
     *
     * It was 140 dp, and 140 dp is not enough for the five pills plus the
     * three-date strip and the onboarding hint: the fixed bands total ~120 dp,
     * so the clock had to fall under its tight floor and the card still
     * overflowed by 5.7 dp (measured, see PrayerWidgetBudgetTest). 150 dp was
     * the first height where the full card fit — and once the bands were given
     * the air between them (see the GAP_* constants), 160 dp became the first
     * height that still fits with the hint showing. The value is quoted at
     * font scale 1.0; [metrics] moves it with the user's scale, because the
     * full card needs proportionally more room there.
     *
     * 2026-11-04: 165. Two honest-band corrections moved the arithmetic —
     * the weekday/city header row (a band the Glance card drew unpriced) is
     * now paid for, and the legacy «badges» band (priced ~21 dp but drawn by
     * NOTHING on the current card; its composable has been dead for two
     * designs) is no longer charged. The two nearly cancel; what remains is
     * the measured minimum where the clock still clears its tight floor at
     * font scale 1.0.
     *
     * 2026-11-04 (second brief): 172. The header's top inset went 6 → 10 dp
     * because the native card priced it and never applied it, and the capsule
     * icon holder is gone at every height — so the honest minimum moved by
     * exactly the 4 dp the header gained. The POCO's default cell is 174 dp
     * and stays on the full card.
     */
    const val SMALL_MAX_HEIGHT_DP = 172f

    /**
     * The third tier: a cell this tall also carries the daily verse.
     *
     * 300 dp, not 220, because the verse is a BAND — it is paid for before the
     * clock gets its share, and at 220 dp it would have taken the clock's room
     * and pushed the prayer boxes into a slice. A 4×4 placement clears it; a
     * 4×3 (≈260 dp) does not, and keeps the clean five-box card it already had.
     */
    const val LARGE_MIN_HEIGHT_DP = 300f

    // ── Air between the bands ──
    // The bands used to be stacked flush: the date strip touched the clock, a
    // 1 dp hairline was all that separated it from the pills, and the countdown
    // capsule sat on the pills' baseline. Everything read as one block. These
    // four gaps are paid out of the clock's budget, which is why they live here
    // and not in the composable — an eyeballed spacer would silently eat the
    // pills again.
    const val GAP_CLOCK_TOP_DP = 0f
    const val GAP_CLOCK_DATES_DP = 5f
    const val GAP_DATES_PILLS_DP = 4f
    const val GAP_PILLS_COUNT_DP = 2f

    /**
     * The day-progress rule under the prayer boxes («نمایش نوار پیشرفت»).
     *
     * 3 dp is a hairline with room for its own rounded ends; 2 dp of air keeps
     * it off the boxes above and the countdown below. Both are paid out of the
     * clock's budget like every other band — a bar drawn without being priced
     * would slice the pills, which is the defect this file exists to prevent.
     */
    const val PROGRESS_HEIGHT_DP = 3f
    const val PROGRESS_GAP_DP = 2f

    const val CLOCK_MIN_SP = 26f

    /**
     * The capsule's circular icon holder is GONE (2026-11-04 second brief).
     *
     * It was priced only when a tall cell could afford it, which meant the
     * default 4×2 placement drew name+time capsules with no glyph — and the
     * «خواندم» state WAS that glyph. On the default cell a tap therefore
     * changed nothing but a few percent of text alpha, and the report was
     * «فقط نماز مغرب قابل تیک زدن هست»: the mark was being written for every
     * prayer (verified on device: `prayer=0..4 marked=true`), it simply had
     * nowhere to show. The done state is now a small inline check beside the
     * name, priced into the name line, and the 23 dp the holder used to take
     * goes to the clock and to the air between the boxes.
     */

    /**
     * The clock's ceiling.
     *
     * 2026-10-30 (user: «اگر میشود ساعت بزرگتر شود و برود بالاتر بدون اینکه
     * تاثیر بگذارد بر بوکسهای پایین»): raised from 72 to 96 and the top gap
     * closed to 0, so a tall cell spends its extra height on the time instead of
     * on air. The prayer boxes are untouched by construction — every other band
     * is totalled first and the clock takes only what is left, so a bigger
     * ceiling can never push them past the cell's bottom edge.
     */
    const val CLOCK_MAX_SP = 130f

    /**
     * The clock may be at most `width / 2.4` sp.
     *
     * «۱۱:۰۶» is four digits and a colon — about 2.25 em in this font — so a
     * clock of `width / 2.25` sp exactly fills the card's content width. 2.4
     * keeps a margin, which is what stops the time from touching the card's
     * side inset on a wide, tall cell.
     *
     * This is the ceiling that actually binds on a real device: on the POCO's
     * 331 dp card it is 128 sp, below [CLOCK_MAX_SP], so the height alone can
     * never make the clock wider than the card.
     */
    const val CLOCK_MAX_WIDTH_DIVISOR = 2.4f

    /** A short cell may dip under [CLOCK_MIN_SP] to keep the pills whole. */
    const val CLOCK_TIGHT_MIN_SP = 20f

    /**
     * The clock's BOX, as a multiple of its own sp — and it is the INK, not the
     * line box.
     *
     * This constant used to be called `CLOCK_LINE_HEIGHT` and was 1.02, on the
     * assumption that the clock's `TextView` measures one em per line. That
     * assumption holds only for the font the APP expects. The clock is a
     * `TextClock`, and the launcher REPLACES it with its own subclass
     * (`HomeMIUIWidgetTextClock` on HyperOS) — so the typeface is whatever the
     * host falls back to, and with it the line metrics.
     *
     * MEASURED on the POCO (331×269 dp cell, density 3.25), from the pixels of
     * `screencap` — the accessibility tree is stale on this launcher and could
     * not be used:
     *
     *   clock set to 114.3 sp
     *   "12:02" ink ................... 877×277 px = 269.8×85.2 dp
     *   one digit advance ............. 181.7 px = 55.9 dp = 0.489 em
     *   cap height ("1") .............. 266 px = 81.9 dp = 0.716 em
     *
     * 0.489 advance and 0.716 cap is **Roboto Condensed**, not Calibri (whose
     * digits are 0.5068 and 0.6318 em). `@font/calibri` does not reach a
     * host-supplied TextClock, so the card was priced for Calibri's 1.0 em box
     * and drawn with a font whose box is ~1.48 em: the clock slot measured
     * ~174 dp against a 116.6 dp price. That 57 dp came straight out of the
     * weighted capsule row, which was left ~11 dp — five boxes with no room
     * for a name, a time or a check («وقتی سایز ویجت بزرگ می‌کنم بوکس‌های اوقات
     * دچار مشکل می‌شوند و بازم مخفی می‌شوند»), and a 60 dp hole between the
     * clock and the date line («فاصله بین ساعت و تقویم‌ها خیلی زیاد می‌شود»).
     *
     * The fix is not to guess the host's font: it is to stop letting the host
     * decide the band. [PrayerNativeViews.bindClock] PINS the clock slot to
     * exactly [Metrics.clockBoxDp] (`RemoteViews.setViewLayoutHeight`, API 31+),
     * so whatever line box the host draws, the card keeps the shape the budget
     * priced. The clock is then centred inside that pinned box.
     *
     * Which is why the box may be the ink and not the line: 1.03 em holds the
     * ink this card actually meets at the position the host actually draws it.
     * The host draws the clock's ink 0.284 em below the top of its box and
     * 0.716 em tall (both measured), so the ink's bottom sits at exactly
     * 1.00 em and 0.03 em of air is left under it. That is 0.19 em less than
     * the 1.22 em a padded line would need, i.e. the same cell buys a ~19 %
     * larger clock («ساعت را بزرگ‌تر کن»).
     */
    const val CLOCK_BOX_EM = 1.03f

    /**
     * One line of text as a multiple of its own sp — MEASURED ON THE LAUNCHER,
     * not in the app's own process.
     *
     * This constant has been wrong in both directions, so the evidence for 1.48
     * is recorded in full.
     *
     * The app's own text (a `TextView` inflated by `WidgetAudit` in the app's
     * process) is exactly 1.00 em per line: `includeFontPadding="false"` plus
     * Calibri's `hhea` metrics (ascender 0.75 em, descender −0.25 em, parsed
     * from `res/font/calibri.ttf`) give a line box of `descent − ascent` = 1.00.
     * On that basis this constant was lowered 1.42 → 1.02 on 2026-11-04.
     *
     * That was a mistake, and the device proved it twice over. In the LAUNCHER
     * the same `TextView` is ~1.48 em tall, because neither the app's typeface
     * nor its `includeFontPadding` reaches the view the host inflates:
     *
     *   - Persian text falls back to a Naskh face (Calibri has no Arabic
     *     coverage at all), whose ascender/descender are ~1.0/−0.5 em.
     *   - The Latin clock falls back too — its cap height measures 0.716 em,
     *     not Calibri's 0.6318, so the card is never drawing Calibri here.
     *
     * Measured from `screencap` pixels at a 331×269 dp cell (density 3.25), by
     * measuring where each line's ink actually landed inside its box:
     *
     *   capsule name, 14.88 sp ....... 71 px = 21.85 dp = 1.47 em
     *   capsule time, 19.33 sp ....... 93 px = 28.61 dp = 1.48 em
     *
     * With 1.02 the capsule was priced 34.1 dp for 50.6 dp of text, so the
     * weighted row clamped it, the name ate its own overflow, and the time line
     * was left 40 px of a 93 px box — the sliced «٤:٢٢» in every box.
     *
     * 1.48 is therefore the price the launcher charges, and every band that
     * holds host-inflated text is priced with it. Over-pricing a band costs the
     * clock a little height; under-pricing it costs the prayer boxes their
     * text, which is the defect this file exists to prevent.
     */
    const val TEXT_LINE_HEIGHT = 1.48f

    /** The «برنامه را باز کنید» onboarding hint, drawn only before the first push. */
    const val HINT_DP = 14f

    /**
     * Preferred empty space under the clock; the first thing a tight cell gives
     * up. Zero since 2026-10-30: the user asked for a bigger clock, and this is
     * exactly the air it was being denied.
     */
    const val SLACK_DP = 0f

    /** Air between the countdown capsule and the card's bottom edge. */
    const val CARD_BOTTOM_INSET_DP = 3f

    /**
     * Air between the card's top edge and the weekday/city row. The Glance
     * card drew a 10 dp top padding the budget never priced; the native card
     * draws exactly what is priced, so the inset is a band like any other.
     *
     * 2026-11-04 second brief: 6 → 10. The native card priced the inset but
     * never APPLIED it, so the header sat on the card's very edge
     * («اسم شهر و روز زیادی رفته بالا»). It is now applied as the content's
     * top padding and priced at the same scale it is drawn at.
     */
    const val CARD_TOP_INSET_DP = 8f

    /**
     * The weekday and the city each live in a chip, so the header is ONE row of
     * two pills instead of a bare line and a pill («روز هم مثل شهر در بوکسی
     * قرار بگیرد»). These are the chip's own air, priced here and applied by
     * [PrayerNativeViews.bindHeader] as the chip's padding — the two must be the
     * same number or the header band lies by the difference.
     */
    const val CHIP_PAD_V_DP = 2f
    const val CHIP_PAD_H_DP = 6f

    /** The crescent / pin icon in each chip. */
    const val HEADER_ICON_DP = 12f

    /** The «خواندم» check drawn inside the capsule's name line. */
    const val CHECK_DP = 11f

    /** The date strip's one line. */
    const val DATE_TEXT_SP = 11.5f

    /** The card's horizontal inset — the capsules, header and pill all live
     *  inside it. The pill's bitmap width was always computed as
     *  `width - 2 × 12 dp`; the layout never applied those 12 dp, which is
     *  why the header overflowed BOTH edges («از راست و چپ هم بیرون زده»). */
    const val CARD_SIDE_INSET_DP = 12f

    /**
     * The countdown's ceiling.
     *
     * It is tied to the clock (see [COUNTDOWN_TO_CLOCK]), and the clock has a
     * 96 sp ceiling — on a 4×4 placement that made «تا اذان صبح» a headline
     * bigger than the time itself («تا اذان صبح هم خیلی بزرگ می‌شود جالب
     * نیست»). The caption and the value are one sentence; 15 sp is the size
     * at which they still read as a caption on every cell.
     */
    const val MAX_COUNTDOWN_SP = 15f

    /** The weekday/city header's text size — the caption family. */
    const val HEADER_TEXT_SP = 11.5f

    /**
     * The countdown's size as a fraction of the clock's.
     *
     * Not 1.0: «تا اذان عصر · ۵:۰۳:۲۳» at the clock's own size is wider than a
     * 4×2 cell, and the line would clip. 0.55 keeps the two reading as one
     * family — the old fixed 14–17 sp against a 40–70 sp clock is what looked
     * like two unrelated type sizes.
     */
    const val COUNTDOWN_TO_CLOCK = 0.55f

    /** The «تا اذان …» prefix, relative to the countdown value. */
    const val COUNTDOWN_PREFIX_TO_VALUE = 0.52f

    data class Metrics(
        val widthDp: Float,
        val heightDp: Float,
        /** The system font scale the bands were priced at. */
        val fontScale: Float,
        val isSmall: Boolean,
        val showGregorian: Boolean,
        /** The day-progress rule is drawn, and therefore paid for. */
        val showProgress: Boolean = false,
        val scale: Float,
        val extraHeightDp: Float,
        val pillPadDp: Float,
        val pillLabelSizeSp: Float,
        val pillTimeSizeSp: Float,
        val captionSizeSp: Float,
        val countdownSizeSp: Float,
        val dateBandDp: Float,
        val pillsBandDp: Float,
        val countdownBandDp: Float,
        val hintBandDp: Float,
        /** The day-progress rule plus its own air — 0 unless [showProgress]. */
        val progressBandDp: Float = 0f,
        val clockBoxDp: Float,
        val clockSizeSp: Float,
        /** Third tier: the cell is tall enough for the daily verse. */
        val isLarge: Boolean = false,
        /** Height of the verse band — 0 unless [isLarge]. */
        val ayahBandDp: Float = 0f,
        /** Card top inset + the weekday/city header row, priced like any band. */
        val headerBandDp: Float = 0f,
        /** The side inset the content is padded by, at this cell's scale. */
        val sideInsetDp: Float = CARD_SIDE_INSET_DP,
        val clockTopGapDp: Float = GAP_CLOCK_TOP_DP,
        val clockDatesGapDp: Float = GAP_CLOCK_DATES_DP,
        val datesPillsGapDp: Float = GAP_DATES_PILLS_DP,
        val pillsCountGapDp: Float = GAP_PILLS_COUNT_DP,
    ) {
        /** Positive means the card overflows its cell and will clip. */
        val overflowDp: Float
            get() = totalContentDp - heightDp

        /**
         * The air BETWEEN bands that is not already inside one.
         *
         * [GAP_CLOCK_DATES_DP] is deliberately absent: the date strip draws it
         * as its own top padding, so [dateBandDp] already contains it and
         * adding it here would charge the card twice for the same air.
         */
        val totalGapsDp: Float
            get() = clockTopGapDp + datesPillsGapDp + pillsCountGapDp

        val totalContentDp: Float
            get() = headerBandDp + dateBandDp + pillsBandDp +
                countdownBandDp + hintBandDp + progressBandDp + clockBoxDp +
                ayahBandDp + totalGapsDp
    }

    /** One text line, in dp, for a given sp and font scale. */
    fun lineDp(sp: Float, fontScale: Float): Float = sp * TEXT_LINE_HEIGHT * fontScale

    fun metrics(
        widthDp: Float,
        heightDp: Float,
        hasData: Boolean,
        fontScale: Float = 1f,
        /**
         * The countdown's font size, when the caller wants it tied to the
         * clock instead of the fixed 14–17 sp band.
         *
         * It is a *parameter* rather than something the caller applies at draw
         * time on purpose: the countdown is a band, and a band drawn taller than
         * it was priced steals the height the prayer boxes were measured
         * against. Callers that want a proportional countdown run [metrics]
         * twice — once for the clock, once with `clock × fraction` — so the
         * budget stays honest and the boxes keep their room.
         */
        countdownOverrideSp: Float? = null,
        /**
         * «نمایش نوار پیشرفت» — the thin day-progress rule under the prayer
         * boxes. Defaults to true so a caller that knows nothing about the
         * setting still gets the card the user has always seen; the widget
         * passes the stored pref.
         */
        showProgress: Boolean = true,
        /**
         * «نمایش تاریخ میلادی» — combined here with the width gate, because the
         * Gregorian line only has room on a wide cell. Both must agree: the
         * composable draws the line from [Metrics.showGregorian] alone, so a
         * pref turned on in a narrow cell still cannot clip.
         */
        showGregorian: Boolean = true,
    ): Metrics {
        // Defensive: a launcher (or a test) may hand over 0 or NaN; the card
        // must still come out sized, never with NaN heights (which the host
        // rejects at apply time).
        val fs = if (fontScale.isFinite() && fontScale > 0f) {
            fontScale.coerceIn(0.85f, 1.6f)
        } else {
            1f
        }
        // The compact card is the fallback for a cell that cannot hold the five
        // pills, so its threshold has to move with the font scale: otherwise a
        // phone set to a large font draws the full card into a cell that only
        // fits the small one — and the pills get sliced again.
        // A font scale BELOW 1 does not buy the card extra room: the bands only
        // shrink a little while every dp padding stays, so the threshold may
        // only grow. And the onboarding hint is a BAND the full card pays for
        // only while it is drawn (no data yet), so an empty card gets the same
        // HINT_DP of extra compact room — measured overflow 3.5 dp at
        // 189.75 dp / font scale 1.15 without this.
        val isSmall = heightDp <
            (SMALL_MAX_HEIGHT_DP + if (hasData) 0f else HINT_DP) * maxOf(fs, 1f)
        val isLarge = heightDp >= LARGE_MIN_HEIGHT_DP * maxOf(fs, 1f)
        val scale = (widthDp / 250f).coerceIn(0.8f, 1.4f)

        // ── Height-driven type ──
        // Dragging the cell taller is how the user makes the widget readable:
        // EVERYTHING grows a little from that slack — the pills' air, their
        // type, the countdown — and the clock then takes what is left, so it
        // grows more than anything else («مثل ویجت تسبیح همه عناصر هماهنگ بزرگ
        // و کوچک بشوند فقط ساعت بیشتر بزرگ بشود»).
        //
        // The slopes are per dp of extra height and were chosen against the
        // measured card: at a 4×3 placement (≈260 dp) the pills are roughly
        // half again as roomy as on a 4×2, which is what makes a resized card
        // read as "the same card, larger" instead of "the same boxes, more
        // empty space".
        val extraHeight = (heightDp - SMALL_MAX_HEIGHT_DP).coerceAtLeast(0f)
        // 5.14 → 18 dp of padding was priced when the bands were under-priced:
        // on a 4×4 cell the capsule spent 36 of its 70 dp on air, which is the
        // «باکس‌ها خیلی کشیده می‌شوند» the second brief reported. Now that a
        // line is priced at its true 1.48 em the air is the only thing left
        // that can be traded for the clock, and the clock is what the third
        // brief asked to grow. The boxes hug their two lines and the height
        // they give up goes straight to the time.
        val pillPad = (4f + extraHeight * 0.045f).coerceAtMost(9f)
        val pillLabel = (11f + extraHeight * 0.040f).coerceAtMost(16f)
        val pillTime =
            (14f + if (widthDp >= 300f) extraHeight * 0.055f else 0f).coerceAtMost(21f)
        val caption = (12f + extraHeight * 0.020f).coerceAtMost(15.5f)
        // The countdown is a caption, not a headline: whatever the clock does
        // on a tall cell, this line never passes MAX_COUNTDOWN_SP.
        val countdown = (countdownOverrideSp
            ?: (14f + extraHeight * 0.02f).coerceAtMost(17f))
            .coerceAtMost(MAX_COUNTDOWN_SP)

        // ── Band heights, in the order they stack ──
        // Every band below is priced as the view measures it, with the measured
        // line height. Nothing is "reserved for safety" any more: a band that
        // over-prices itself steals the clock's height, which is the whole
        // defect this file exists to prevent.
        val sideInset = CARD_SIDE_INSET_DP * scale
        // Card top inset + one chip row. The chip is taller than its text by
        // its own 2 dp of vertical padding, and the icon may be taller than
        // the text — the row is the taller of the two.
        val headerBand = CARD_TOP_INSET_DP * scale +
            maxOf(HEADER_ICON_DP * scale, lineDp(HEADER_TEXT_SP, fs)) +
            2f * CHIP_PAD_V_DP
        // The date strip carries its own top gap as padding, so the gap is
        // priced INSIDE this band — pricing it again in the gap total would
        // charge the card twice for the same air.
        val dateBand = GAP_CLOCK_DATES_DP + lineDp(DATE_TEXT_SP, fs) + 1f
        val countdownBand =
            2f /* Pill's own top air */ + (lineDp(maxOf(countdown, caption), fs) + 2f) +
                CARD_BOTTOM_INSET_DP
        // NO second iqamah band. v4 deleted the gold «تا اقامه» pill from the
        // horizontal layout too (brief 2026-11-08): the ONE countdown pill
        // carries both phases. Its old band was priced-but-undrawn on any
        // cell that did not show the second pill, so the height now goes back
        // to the clock on every tier.
        val hintBand = if (hasData) 0f else HINT_DP
        // The day-progress rule is NOT a band: it is painted as the countdown
        // pill's own background (see bindCountdown), so it already lives inside
        // [countdownBand]. It used to be priced here as well, which reserved
        // 5 dp of height for a bar that occupies none — 5 dp the clock never
        // got. The flag is kept so a caller can still ask whether it is drawn.
        val progressBand = 0f
        // NO verse band. It was priced at `6 + 2 lines` on every cell of
        // 300 dp or more, but nothing on the native card draws a verse — the
        // price was reserved for a band that has no view, so it silently became
        // 25 dp of empty card. [isLarge] is kept because it still marks the
        // tier; it just no longer charges for anything.
        val ayahBand = 0f

        // The capsule is name + time, nothing above them. The check that marks
        // a done prayer is drawn INSIDE the name line, so it costs no band.
        // The name row is as tall as the taller of its two children: the check
        // bitmap (drawn at CHECK_DP x scale) and the name's line. Pricing the
        // check unscaled made the band 3 dp short of the row it describes.
        val pillsBand = 4f /* Row padding, 2 dp top + 2 dp bottom */ + 2f * pillPad +
            maxOf(CHECK_DP * scale, lineDp(pillLabel, fs)) + 1f + lineDp(pillTime, fs)
        val fixed = headerBand + dateBand + pillsBand +
            countdownBand + hintBand + progressBand + ayahBand + GAP_CLOCK_TOP_DP +
            GAP_DATES_PILLS_DP + GAP_PILLS_COUNT_DP
        val hardAvailable = (heightDp - fixed).coerceAtLeast(0f)

        val clockLine = CLOCK_BOX_EM * fs
        val availableForClock = hardAvailable

        // Prefer a clock that leaves [SLACK_DP] of air; give the air up rather
        // than dip under the floor, and only then let the clock shrink below it.
        val withSlack = (availableForClock - SLACK_DP) / clockLine
        val wanted = if (withSlack >= CLOCK_MIN_SP) {
            withSlack.coerceAtMost(CLOCK_MAX_SP)
        } else {
            (availableForClock / clockLine).coerceIn(CLOCK_TIGHT_MIN_SP, CLOCK_MIN_SP)
        }
        // ...but never more than the cell can hold, and never wider than the
        // card: on a cell just above the compact threshold the tight floor
        // itself can overrun, and an overflowing card clips the pills — the
        // exact defect this budget exists to prevent. The floor is a
        // preference; fitting is a rule.
        val widthCeiling = (widthDp - 2f * sideInset) / CLOCK_MAX_WIDTH_DIVISOR
        val clockSize = minOf(wanted, availableForClock / clockLine, widthCeiling)
        val clockBox = clockSize * clockLine

        return Metrics(
            widthDp = widthDp,
            heightDp = heightDp,
            fontScale = fs,
            isSmall = isSmall,
            showGregorian = showGregorian && widthDp >= 300f,
            showProgress = showProgress && !isSmall,
            scale = scale,
            extraHeightDp = extraHeight,
            pillPadDp = pillPad,
            pillLabelSizeSp = pillLabel,
            pillTimeSizeSp = pillTime,
            captionSizeSp = caption,
            countdownSizeSp = countdown,
            dateBandDp = dateBand,
            pillsBandDp = pillsBand,
            countdownBandDp = countdownBand,
            hintBandDp = hintBand,
            progressBandDp = progressBand,
            clockBoxDp = clockBox,
            clockSizeSp = clockSize,
            isLarge = isLarge,
            ayahBandDp = ayahBand,
            headerBandDp = headerBand,
            sideInsetDp = sideInset,
        )
    }
}
