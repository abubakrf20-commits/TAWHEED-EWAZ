package com.islamic.tawheeed.widget

import android.content.Context
import android.graphics.Color
import org.json.JSONObject

/**
 * Widget design tokens loaded from [assets/content/widget_tokens.json].
 *
 * Hardcoded defaults serve as fallbacks; calling [init] loads the shared
 * JSON so Dart and Kotlin stay in sync automatically.
 */
object WidgetTokens {
    // ── Palette ──
    const val DEEP_ESPRESSO    = 0xFF3B2316.toInt()
    const val WALNUT_BROWN     = 0xFF5C3D2E.toInt()
    const val COCOA_BROWN      = 0xFF6B4C3B.toInt()
    const val WARM_BROWN       = 0xFF8B6F5E.toInt()
    const val LIGHT_BROWN      = 0xFFA89282.toInt()

    const val ANTIQUE_GOLD     = 0xFFC9A94E.toInt()
    const val MUTED_GOLD       = 0xFFB89B4A.toInt()
    const val SOFT_GOLD        = 0xFFD4B96A.toInt()

    const val SAND             = 0xFFF5EDE3.toInt()
    const val IVORY            = 0xFFFBF8F3.toInt()
    const val PARCHMENT        = 0xFFF0E8DC.toInt()

    const val DARK_COCOA       = 0xFF2A1A10.toInt()
    const val CHARCOAL_BROWN   = 0xFF1E1208.toInt()
    const val DARK_SURFACE     = 0xFF342418.toInt()

    const val TEXT_DARK        = 0xFF3B2316.toInt()
    const val TEXT_SECONDARY   = 0xFF6B4C3B.toInt()
    const val TEXT_MUTED       = 0xFF8B6F5E.toInt()
    const val TEXT_LIGHT       = 0xFFF5EDE3.toInt()
    const val TEXT_MUTED_DARK  = 0xFF9A8A7A.toInt()

    const val SUCCESS_GREEN    = 0xFF4CAF50.toInt()

    // ── Prayer-specific colors ──
    const val FAJR_PRIMARY     = 0xFF5C6BC0.toInt()
    const val FAJR_SECONDARY   = 0xFF7986CB.toInt()
    const val DHUHR_PRIMARY    = 0xFFF9A825.toInt()
    const val DHUHR_SECONDARY  = 0xFFFDD835.toInt()
    const val ASR_PRIMARY      = 0xFFFF8F00.toInt()
    const val ASR_SECONDARY    = 0xFFFFB74D.toInt()
    const val MAGHRIB_PRIMARY  = 0xFFD32F2F.toInt()
    const val MAGHRIB_SECONDARY= 0xFFEF5350.toInt()
    const val ISHA_PRIMARY     = 0xFF5C6BC0.toInt()
    const val ISHA_SECONDARY   = 0xFF7986CB.toInt()

    val PRAYER_COLORS = intArrayOf(FAJR_PRIMARY, DHUHR_PRIMARY, ASR_PRIMARY, MAGHRIB_PRIMARY, ISHA_PRIMARY)
    val PRAYER_COLORS_SECONDARY = intArrayOf(FAJR_SECONDARY, DHUHR_SECONDARY, ASR_SECONDARY, MAGHRIB_SECONDARY, ISHA_SECONDARY)

    val PRAYER_HEX = arrayOf("#5C6BC0", "#F9A825", "#FF8F00", "#D32F2F", "#5C6BC0")
    val PRAYER_BG_HEX = arrayOf("#1A5C6BC0", "#1AF9A825", "#1AFF8F00", "#1AD32F2F", "#1A5C6BC0")

    const val DEFAULT_BG       = "#004F9E"
    // Parsed form of DEFAULT_BG — the single source of truth for the native
    // fallback int, so the brand blue is never restated as a raw literal.
    const val DEFAULT_BG_INT   = 0xFF004F9E.toInt()
    const val DEFAULT_TEXT     = "#FFFFFF"
    const val DEFAULT_ACCENT   = "#C9A94E"
    const val DEFAULT_RADIUS   = 20
    const val DEFAULT_OPACITY  = 0.95f

    // ── JSON overrides ──
    private var _overrides: JSONObject? = null

    /** Volatile so the fast-path read outside the lock cannot observe
     *  [_loaded] before [_overrides] is visible (safe publication). */
    @Volatile
    private var _loaded = false

    /**
     * Load tokens from the shared JSON file.
     *
     * The asset ships inside the APK, so its content cannot change while the
     * process lives — the parse is memoized and every later call is a no-op.
     * [init] runs on the tap trampoline's main thread, in every Glance
     * composition and in the receiver's resize path; an asset read plus a
     * JSON parse on each of those was measurable tap latency on a cheap phone.
     */
    fun init(context: Context) {
        if (_loaded) return
        synchronized(this) {
            if (_loaded) return
            try {
                val json = context.assets.open("content/widget_tokens.json")
                    .bufferedReader().use { it.readText() }
                _overrides = JSONObject(json)
            } catch (_: Exception) {
                _overrides = null
            }
            _loaded = true
        }
    }

    private fun section(name: String): JSONObject? =
        _overrides?.optJSONObject(name)

    fun parseColor(hex: String, fallback: Int = WALNUT_BROWN): Int {
        return try {
            Color.parseColor(hex)
        } catch (_: Exception) {
            fallback
        }
    }

    fun withAlpha(color: Int, opacity: Float): Int {
        val alpha = (opacity * 255).toInt().coerceIn(0, 255)
        return Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))
    }

    /**
     * Multiplies an existing colour's alpha by [factor].
     *
     * Different from [withAlpha], which SETS the alpha: a row that is already
     * at 78 % and then dimmed for «past» must land at 0.78 × 0.65, not at 0.65
     * (which would make a past prayer brighter than an upcoming one).
     */
    fun scaleAlpha(color: Int, factor: Float): Int {
        val current = (color ushr 24) and 0xFF
        val scaled = (current * factor.coerceIn(0f, 1f)).toInt().coerceIn(0, 255)
        return (scaled shl 24) or (color and 0x00FFFFFF)
    }

    /** Multiply each RGB channel by [factor] (0–1), keeping alpha. */
    fun darken(color: Int, factor: Float): Int {
        val f = factor.coerceIn(0f, 1f)
        return Color.rgb(
            (Color.red(color) * f).toInt(),
            (Color.green(color) * f).toInt(),
            (Color.blue(color) * f).toInt(),
        )
    }

    /** Relative luminance (0–1) per WCAG 2.x. */
    fun luminance(color: Int): Float {
        fun channel(v: Int): Float {
            val s = v / 255.0
            return if (s <= 0.03928) (s / 12.92).toFloat()
            else Math.pow((s + 0.055) / 1.055, 2.4).toFloat()
        }
        val r = Color.red(color)
        val g = Color.green(color)
        val b = Color.blue(color)
        return 0.2126f * channel(r) + 0.7152f * channel(g) + 0.0722f * channel(b)
    }

    data class WidgetStyle(
        val textColor: Int = TEXT_LIGHT,
        val bgColor: Int = WALNUT_BROWN,
        val opacity: Float = DEFAULT_OPACITY,
        val cornerRadius: Int = DEFAULT_RADIUS,
    )
}
