package com.islamic.tawheeed.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.drawable.GradientDrawable
import kotlin.math.roundToInt

/**
 * The two things a Glance widget genuinely cannot draw: a rounded diagonal
 * gradient and the beaded progress ring.
 *
 * Glance's modifier vocabulary stops at a flat `background` colour, so both
 * surfaces are painted once into a bitmap and handed over as a Glance
 * image provider. Bitmaps are cached by their full input, so a
 * tap re-render or a resize reuses the previous pixels instead of allocating a
 * new ARGB buffer every frame; the cache is small and self-evicting because a
 * widget can only ever be a handful of distinct sizes.
 */
internal object WidgetArt {

    /** Ring stroke as a fraction of the box — ≈5.3 dp on the 118 dp box. */
    const val RING_STROKE_FRACTION = 0.045f

    /** Below this much room for the box the «از N» badge is dropped. */
    const val MIN_BADGE_BOX_DP = 64f

    /** The smallest ring box worth drawing when the height is squeezed. */
    const val RING_BOX_FLOOR_DP = 36f

    /**
     * The share of the ring BITMAP that actually carries ink.
     *
     * `ringV2` draws its main track at r = 72/176 with a 12/176 stroke, so the
     * outer edge is 78/176 of the radius: the visible circle is
     * `2 * 78 / 176 = 0.886` of the bitmap's edge. The other 11.4 % is a
     * transparent margin. TasbihNativeViews sizes the number from the VISIBLE
     * circle, not from the bitmap, so a digit can never again be sized against
     * a box that is larger on disk than it is on screen.
     */
    const val RING_INK_FRACTION = 0.886f

    /**
     * Absolute ceiling for the ring buffer, whatever the box asks for.
     *
     * 512 px is ~1 MB of ARGB_8888. The old `RING_MAX_DENSITY = 2.5f` cap
     * painted the ring at 2.5× on a 3.25× screen: because the ImageView is
     * `wrap_content` and the BITMAP owns its size, a "119 dp" box rendered at
     * 298 px = 91.7 dp — measured on the device as `ringPx=298` against
     * `density=3.25`. That 23 % shrink, plus the transparent margin above,
     * is the «دایره خیلی کوچک» report. The ring now paints at the REAL device
     * density and is capped in pixels only, so dp and pixels cannot disagree.
     */
    const val RING_MAX_PX = 512

    /** Two surfaces plus a handful of ring steps per widget is the realistic
     *  working set; the cap only guards against a launcher that animates
     *  sizes. Raised from 4 when the ring started quantising its progress
     *  (2026-10-26): the neighbouring steps of a running count are exactly the
     *  entries worth keeping, and they were being evicted after every fourth
     *  bead. */
    private const val CACHE_LIMIT = 8

    /** Ring bitmap pixels per progress step. 0–10000 is the model's range; 1 %
     *  buckets make a tap REUSE the previous bitmap instead of allocating and
     *  redrawing a fresh one, which is what every bead used to cost. */
    private const val RING_PROGRESS_STEP = 100

    private val cache = object : LinkedHashMap<String, Bitmap>(CACHE_LIMIT, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Bitmap>?) =
            size > CACHE_LIMIT
    }

    private fun cached(key: String, build: () -> Bitmap): Bitmap = synchronized(cache) {
        // Glance composes on its own session threads, and the map is an
        // access-ordered LinkedHashMap — not safe for unsynchronised reads.
        cache[key] ?: build().also { cache[key] = it }
    }

    /** Same RGB, scaled alpha. A gradient stop must fade toward TRANSPARENT,
     *  not toward the black that `Color.TRANSPARENT` would interpolate to. */
    private fun scaledAlpha(color: Int, opacity: Float): Int =
        Color.argb(
            (Color.alpha(color) * opacity).roundToInt().coerceIn(0, 255),
            Color.red(color), Color.green(color), Color.blue(color),
        )

    /**
     * Themed widget skin: the palette's diagonal gradient on the shared corner
     * radius, with the opacity step already baked into both stops.
     *
     * The corners are painted into the bitmap rather than clipped by a
     * modifier, so the rounded shape survives on launchers below API 31 that
     * ignore Glance's outline radius.
     */
    fun surface(
        context: Context,
        startColor: Int,
        endColor: Int,
        cornerDp: Float,
        widthDp: Float,
        heightDp: Float,
    ): Bitmap {
        // A smooth gradient carries no detail, so it is painted at half the
        // display density: a 500 dp card costs a quarter of the pixels and the
        // launcher's upscale is invisible on a two-stop ramp. The ring, which
        // has hairline beads, keeps full density.
        val density = context.resources.displayMetrics.density * 0.5f
        val width = (widthDp * density).roundToInt().coerceAtLeast(1)
        val height = (heightDp * density).roundToInt().coerceAtLeast(1)
        val key = "surface:$startColor:$endColor:$cornerDp:${width}x$height"
        return cached(key) {
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val drawable = GradientDrawable(
                GradientDrawable.Orientation.TL_BR,
                intArrayOf(startColor, endColor),
            ).apply {
                cornerRadius = cornerDp * density
            }
            drawable.setBounds(0, 0, width, height)
            drawable.draw(Canvas(bitmap))
            bitmap
        }
    }

    /**
     * An EMPTY bitmap of exactly [sizePx], for a slot that must hold its
     * geometry without drawing anything.
     *
     * This is not the same thing as [tintedIcon] with a zero-alpha colour, and
     * the difference was visible on the device: a tinted vector whose tint is
     * fully transparent still rasterised a faint white glyph (measured
     * 2026-11-07 — every unticked prayer row carried a ghost ✓, which the user
     * read as a «-» mark against the prayer). Nothing is drawn here, so the
     * buffer stays zeroed and the slot is provably invisible while still
     * reserving the check's width and height.
     */
    fun blank(sizePx: Int): Bitmap {
        val size = sizePx.coerceIn(1, RING_MAX_PX)
        val key = "blank:$size"
        return cached(key) {
            Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        }
    }

    /**
     * A vector drawable, tinted to an arbitrary colour and rasterised at
     * [sizePx].
     *
     * Why rasterise at all: a RemoteViews `ImageView` can be handed a resource,
     * but Glance's `Image` has no colour filter — so a white chevron stays
     * white on a cream palette and disappears. Drawing the vector once, tinted,
     * into a ~18 dp bitmap keeps the icon a vector in the APK (no per-density
     * assets) while giving the card exact colour control. The bitmaps are
     * tiny (≈1 KB each) and cached, so a tap never pays for one.
     */
    fun tintedIcon(context: Context, resId: Int, color: Int, sizePx: Int): Bitmap {
        val size = sizePx.coerceAtLeast(8)
        val key = "icon:$resId:$color:$size"
        return cached(key) {
            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            try {
                val drawable = context.getDrawable(resId)
                if (drawable != null) {
                    drawable.mutate()
                    drawable.setTint(color)
                    drawable.setBounds(0, 0, size, size)
                    drawable.draw(Canvas(bitmap))
                }
            } catch (_: Throwable) {
                // A missing icon must never blank the card; an empty bitmap is
                // an invisible icon, which is the least-bad failure.
            }
            bitmap
        }
    }

    /**
     * The ONE shared countdown pill's bar — a PHASE bar since 2026-11-08.
     *
     * One rounded track, filled FROM THE START EDGE (the right edge in RTL),
     * but the fill is no longer a flat slab: it ramps from a soft tail to a
     * brighter head, and the leading edge carries a small glowing bead. The
     * bead is the visual answer to «تا اقامه جالب عرضه نمی‌شود» — it makes the
     * moment the bar RESETS at an adhan legible, then travels across the short
     * gold iqamah window, then resets again when «تا اذان» takes over.
     *
     * [headColor] is the phase tint at near-full opacity, so the bead turns
     * gold during «تا اقامه» and accent during «تا اذان» without a second
     * view, a second pill or a second caption.
     *
     * The fraction is quantised to 1 % (100 of the model's 10000): between
     * steps a re-render reuses the previous bitmap, so the 30-second progress
     * tick costs almost nothing, while the bar still resolves to a visibly
     * moving fill across the long «تا اذان» window. [fillColor] and
     * [trackColor] arrive pre-multiplied with their alpha.
     */
    fun progressPill(
        widthPx: Int,
        heightPx: Int,
        trackColor: Int,
        fillColor: Int,
        fraction: Int, // 0..10000
        /** Brighter phase tint for the moving head; defaults to the fill. */
        headColor: Int = fillColor,
    ): Bitmap {
        val w = widthPx.coerceAtLeast(8)
        val h = heightPx.coerceAtLeast(8)
        val step = (fraction.coerceIn(0, 10000) / 100) * 100
        val key = "pill:$w:$h:$trackColor:$fillColor:$headColor:$step"
        return cached(key) {
            val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val radius = h / 2f
            val pill = RectF(0f, 0f, w.toFloat(), h.toFloat())

            // The halo is taller than the pill on purpose; clipping to the
            // pill's own rounded outline keeps it inside the card's corners.
            // This is a bitmap-backed (software) canvas, so clipPath is safe.
            canvas.save()
            canvas.clipPath(Path().apply {
                addRoundRect(pill, radius, radius, Path.Direction.CW)
            })
            canvas.drawRoundRect(
                pill, radius, radius,
                Paint(Paint.ANTI_ALIAS_FLAG).apply { color = trackColor },
            )

            val f = (step / 10000f).coerceIn(0f, 1f)
            if (f > 0f) {
                // RTL start edge = right. The fill grows leftwards from it.
                val fillWidth = (w * f).coerceAtLeast(radius) // at least the cap
                val left = w - fillWidth
                val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    shader = LinearGradient(
                        w.toFloat(), 0f, left, 0f,
                        scaledAlpha(fillColor, 0.55f), fillColor,
                        Shader.TileMode.CLAMP,
                    )
                }
                canvas.drawRoundRect(
                    RectF(left, 0f, w.toFloat(), h.toFloat()), radius, radius, fill,
                )

                // The leading edge: a soft halo plus a small bright bead. Its
                // centre sits on the fill's LEFT rounded cap, clamped so a
                // nearly-empty or nearly-full bar cannot draw outside the pill.
                val headX = (left + radius).coerceIn(radius, w - radius)
                val glowR = radius * 1.8f
                canvas.drawCircle(
                    headX, radius, glowR,
                    Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        shader = RadialGradient(
                            headX, radius, glowR,
                            scaledAlpha(headColor, 0.85f),
                            scaledAlpha(headColor, 0f),
                            Shader.TileMode.CLAMP,
                        )
                    },
                )
                canvas.drawCircle(
                    headX, radius, (radius * 0.40f).coerceAtLeast(1f),
                    Paint(Paint.ANTI_ALIAS_FLAG).apply { color = headColor },
                )
            }
            canvas.restore()
            bitmap
        }
    }

    /**
     * The approved tasbih ring (Design 1), drawn in the design space the brief
     * fixes: an inner disc, a 12 % track, a gold gradient progress arc with
     * round caps from the top, and — once at least one lap is complete — the
     * thin outer ring carrying the lap's progress.
     *
     * [progress] and [lapProgress] are 0..10000; [lapProgress] < 0 draws no
     * outer arc at all (laps == 0).
     */
    fun ringV2(
        sizePx: Int,
        trackColor: Int,
        arcStart: Int,
        arcEnd: Int,
        progress: Int,
        outerColor: Int,
        outerTrackColor: Int,
        lapProgress: Int, // -1 = no outer ring arc
    ): Bitmap {
        val size = sizePx.coerceIn(96, RING_MAX_PX)
        val pStep = (progress.coerceIn(0, 10000) / 100) * 100
        val lStep = (lapProgress.coerceIn(0, 10000) / 100) * 100
        val key = "ring2:$size:$trackColor:$arcStart:$arcEnd:$pStep:$outerColor:$outerTrackColor:$lStep"
        return cached(key) {
            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val half = size / 2f
            val scale = size / 176f // the brief's design space

            // Inner disc: black@22 %, r = 72/176 of the space.
            val discPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = WidgetTokens.withAlpha(0xFF000000.toInt(), 0.22f)
            }
            canvas.drawCircle(half, half, 72f * scale, discPaint)

            // Main track + gradient arc: 12 dp wide at r = 72.
            val mainStroke = 12f * scale
            val mainRadius = 72f * scale
            val mainTrack = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = trackColor
                this.strokeWidth = mainStroke
                style = Paint.Style.STROKE
                strokeCap = Paint.Cap.ROUND
            }
            canvas.drawCircle(half, half, mainRadius, mainTrack)

            val fraction = (pStep / 10000f).coerceIn(0f, 1f)
            if (fraction > 0f) {
                val arcPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    this.strokeWidth = mainStroke
                    style = Paint.Style.STROKE
                    strokeCap = Paint.Cap.ROUND
                    shader = android.graphics.SweepGradient(
                        half, half,
                        intArrayOf(arcStart, arcEnd, arcStart),
                        floatArrayOf(0f, 0.75f, 1f),
                    )
                }
                val rect = RectF(
                    half - mainRadius, half - mainRadius,
                    half + mainRadius, half + mainRadius,
                )
                // Clockwise from the top; the sweep gradient is rotated with
                // the canvas so its bright end leads the cap.
                canvas.save()
                canvas.rotate(-90f, half, half)
                canvas.drawArc(rect, 0f, 360f * fraction, false, arcPaint)
                canvas.restore()
            }

            // Outer lap ring: 3 dp at r = 83, only once a lap exists.
            if (lapProgress >= 0) {
                val outerStroke = 3f * scale
                val outerRadius = 83f * scale
                val outerTrack = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = outerTrackColor
                    this.strokeWidth = outerStroke
                    style = Paint.Style.STROKE
                }
                canvas.drawCircle(half, half, outerRadius, outerTrack)
                val lap = (lStep / 10000f).coerceIn(0f, 1f)
                if (lap > 0f) {
                    val outerArc = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        color = outerColor
                        this.strokeWidth = outerStroke
                        style = Paint.Style.STROKE
                        strokeCap = Paint.Cap.ROUND
                    }
                    val rect = RectF(
                        half - outerRadius, half - outerRadius,
                        half + outerRadius, half + outerRadius,
                    )
                    canvas.save()
                    canvas.rotate(-90f, half, half)
                    canvas.drawArc(rect, 0f, 360f * lap, false, outerArc)
                    canvas.restore()
                }
            }
            bitmap
        }
    }

    /**
     * The ring: one quiet track and one accent progress arc, nothing else.
     *
     * It used to carry 40 beads plus a leading bead (a port of the in-app
     * dial). On a home screen at 100–140 dp the beads read as noise, and every
     * re-render paid 41 extra draw calls. Two stroked arcs say the same thing
     * with two, and the launcher's fitCenter keeps the caps crisp.
     */
    fun ring(
        sizePx: Int,
        progressColor: Int,
        progress: Int, // 0–10000
    ): Bitmap {
        // Capped on the long edge, whatever the box is.
        //
        // Measured on a POCO X7 Pro: `dumpsys appwidget` reported
        // `views_bitmap_memory=1004692` for this card, and the ring was almost
        // all of it — a 479 px ARGB_8888 buffer is ~918 KB, and a RemoteViews
        // is re-parcelled to the launcher on *every* apply, so each bead pushed
        // about a megabyte across a binder to redraw one number.
        //
        // 512 px is the ceiling now, not 256: the ImageView is `wrap_content`
        // and the bitmap is what sizes it, so the cap is also the ring's
        // on-screen size. At 2.5× density a 119 dp box asks for ~298 px
        // (~355 KB); the two arcs still have no detail to lose.
        // `TasbihNativeViews` derives the count's sp from this same number, so
        // the digit and the ring cannot disagree.
        val size = sizePx.coerceIn(96, RING_MAX_PX)
        val strokeWidth = (size * RING_STROKE_FRACTION).coerceAtLeast(8f)
        // Quantised to 1 %: the arc moves ~1 px per step at this size, so the
        // eye cannot tell the bucket from the exact value, while a tap that
        // does not cross a bucket boundary costs neither a ~0.4 MB ARGB buffer
        // nor a full circle + arc draw. Every bead used to allocate one.
        val step = (progress.coerceIn(0, 10000) / RING_PROGRESS_STEP) * RING_PROGRESS_STEP
        val key = "ring:$size:$progressColor:$step"
        return cached(key) {
            drawRing(size, progressColor, strokeWidth, step)
        }
    }

    private fun drawRing(
        size: Int,
        progressColor: Int,
        strokeWidth: Float,
        progress: Int,
    ): Bitmap {
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val half = size / 2f
        // Half the stroke + the round cap curl, so neither edge clips.
        val radius = half - strokeWidth / 2f - 2f
        val progressFraction = (progress / 10000f).coerceIn(0f, 1f)

        val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = WidgetTokens.withAlpha(progressColor, 0.18f)
            this.strokeWidth = strokeWidth
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
        }
        canvas.drawCircle(half, half, radius, trackPaint)

        if (progressFraction > 0f) {
            val progressPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = progressColor
                this.strokeWidth = strokeWidth
                style = Paint.Style.STROKE
                strokeCap = Paint.Cap.ROUND
            }
            val rect = RectF(half - radius, half - radius, half + radius, half + radius)
            canvas.drawArc(rect, -90f, 360f * progressFraction, false, progressPaint)
        }
        return bitmap
    }
}
