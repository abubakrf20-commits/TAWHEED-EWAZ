package com.islamic.tawheeed.widget

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Resolves the user-selected widget palette + opacity step into concrete
 * colors, from the same assets/widget_palettes.json the Flutter preview and
 * the drawable generator read.
 *
 * Selection keys live in the widget prefs file. Each widget has its own pair
 * ([WidgetTarget.paletteKey]/[WidgetTarget.stepKey]); the shared keys
 * ([PREF_PALETTE_ID]/[PREF_OPACITY_STEP]) are the previous build's storage and
 * remain only as an adoption source for existing installs — the settings page
 * no longer writes them.
 *
 * Resolve ladder for a target widget: its own keys → the shared keys (adopted
 * once, persisted into the target's keys) → legacy color migration. A widget
 * that has adopted never retro-adopts, so changing one widget's palette can
 * never move the other's.
 *
 * Legacy keys (widget_bg_color / widget_text_color / widget_opacity) are
 * migrated on first resolve: when nothing else is stored but legacy colors
 * are, the closest preset (exact bg match first, then nearest color among
 * palettes of the same lightness) wins and is written back.
 *
 * The pure core ([parseSpec], [resolveSelection], [phaseFor]) takes plain
 * values so the JVM unit test can drive it without an Android context.
 */
object WidgetTheme {
    const val PREF_PALETTE_ID = "widget_palette_id"
    const val PREF_OPACITY_STEP = "widget_opacity_step"
    private const val PREF_LEGACY_BG = "widget_bg_color"
    private const val PREF_LEGACY_OPACITY = "widget_opacity"
    const val AUTO_ID = "auto"

    /** Which home-screen widget a palette selection belongs to. The wire
     *  values mirror the Flutter channel ("prayer" / "tasbih"). */
    enum class WidgetTarget(val keySuffix: String) {
        PRAYER("prayer"),
        TASBIH("tasbih");

        val paletteKey: String get() = "widget_palette_id_$keySuffix"
        val stepKey: String get() = "widget_opacity_step_$keySuffix"

        companion object {
            fun fromWire(value: String?): WidgetTarget =
                entries.firstOrNull { it.keySuffix == value } ?: PRAYER
        }
    }

    /** Corner radius of the widget backgrounds. The single source: the
     *  generated skin drawables bake it in (`tool/widget_palette_generator.dart`
     *  reads this constant) and the Flutter preview mirrors it as
     *  `WidgetTokens.widgetRadius`, so the three never disagree. */
    const val CORNER_RADIUS_DP = 22

    data class Palette(
        val id: String,
        val bg: Int,
        val bgEnd: Int,
        val text: Int,
        val accent: Int,
        val light: Boolean,
        val autoPhases: List<String>,
        /** The brief's per-widget tokens (2026-11): `prayer.{muted,accentLight,
         *  nextFill,onNext}` and `tasbih.{muted,accentStart,accentEnd,
         *  accentLight,outerRing,badgeFill,badgeText}`. Missing entries fall
         *  back at the call site — the map only carries what the JSON said. */
        val prayerTokens: Map<String, Int> = emptyMap(),
        val tasbihTokens: Map<String, Int> = emptyMap(),
    )

    data class ThemeSpec(
        val palettes: List<Palette>,
        val opacitySteps: List<Float>,
        val defaultId: String,
        /** The brief's per-widget defaults: prayer → «زمردی», tasbih →
         *  «شب آبی». Falls back to [defaultId] when absent. */
        val defaultPrayer: String? = null,
        val defaultTasbih: String? = null,
    )

    data class Resolved(
        val palette: Palette,
        val bg: Int,
        val bgEnd: Int,
        val text: Int,
        val accent: Int,
        val opacity: Float,
        val opacityStep: Int,
        /** The target widget's own tokens, with text-derived fallbacks at the
         *  call site (`muted`, `nextFill`/`onNext`, `accentLight`, the tasbih
         *  ring/badge colors). */
        val tokens: Map<String, Int> = emptyMap(),
    ) {
        fun token(key: String, fallback: Int): Int = tokens[key] ?: fallback
    }

    // ── Pure core ──

    fun parseSpec(json: String): ThemeSpec {
        val root = JSONObject(json)
        val stepsJson = root.optJSONArray("opacitySteps") ?: JSONArray()
        val steps = ArrayList<Float>()
        for (i in 0 until stepsJson.length()) {
            steps.add(stepsJson.getDouble(i).toFloat())
        }
        val palettes = ArrayList<Palette>()
        val palettesJson = root.optJSONArray("palettes") ?: JSONArray()
        for (i in 0 until palettesJson.length()) {
            val p = palettesJson.getJSONObject(i)
            if (p.optBoolean("auto", false)) continue
            val phases = ArrayList<String>()
            val phasesJson = p.optJSONArray("autoPhases") ?: JSONArray()
            for (j in 0 until phasesJson.length()) {
                phases.add(phasesJson.getString(j))
            }
            palettes.add(
                Palette(
                    id = p.getString("id"),
                    bg = parseColor(p.optString("bg", "#000000"), 0xFF3B2316.toInt()),
                    bgEnd = parseColor(p.optString("bgEnd", "#000000"), 0xFF2A1A10.toInt()),
                    text = parseColor(p.optString("text", "#FFFFFF"), 0xFFF5EDE3.toInt()),
                    accent = parseColor(p.optString("accent", "#FFFFFF"), 0xFFC9A94E.toInt()),
                    light = p.optBoolean("light", false),
                    autoPhases = phases,
                    prayerTokens = parseTokens(p.optJSONObject("prayer")),
                    tasbihTokens = parseTokens(p.optJSONObject("tasbih")),
                )
            )
        }
        return ThemeSpec(
            palettes = palettes,
            opacitySteps = if (steps.isEmpty()) listOf(1f, 0.85f, 0.7f, 0.55f) else steps,
            defaultId = root.optString("defaultPalette", "brown_gold"),
            defaultPrayer = root.optString("defaultPrayer", "").ifEmpty { null },
            defaultTasbih = root.optString("defaultTasbih", "").ifEmpty { null },
        )
    }

    private fun parseTokens(obj: JSONObject?): Map<String, Int> {
        if (obj == null) return emptyMap()
        val out = LinkedHashMap<String, Int>()
        for (key in obj.keys()) {
            val parsed = parseColor(obj.optString(key, ""), 0)
            if (parsed != 0) out[key] = parsed
        }
        return out
    }

    /** Time-of-day phase name from the five adhan boundaries + sunrise. */
    fun phaseFor(
        nowMinutesOfDay: Int,
        fajr: Int?,
        sunrise: Int?,
        dhuhr: Int?,
        asr: Int?,
        maghrib: Int?,
        isha: Int?,
    ): String {
        if (isha != null && (nowMinutesOfDay >= isha || (fajr != null && nowMinutesOfDay < fajr))) {
            return "night"
        }
        if (fajr != null && sunrise != null && nowMinutesOfDay >= fajr && nowMinutesOfDay < sunrise) return "dawn"
        if (sunrise != null && dhuhr != null && nowMinutesOfDay >= sunrise && nowMinutesOfDay < dhuhr) return "morning"
        if (dhuhr != null && asr != null && nowMinutesOfDay >= dhuhr && nowMinutesOfDay < asr) return "afternoon"
        if (asr != null && maghrib != null && nowMinutesOfDay >= asr && nowMinutesOfDay < maghrib) return "sunset"
        if (maghrib != null && isha != null && nowMinutesOfDay >= maghrib && nowMinutesOfDay < isha) return "evening"
        return "night"
    }

    /** Picks the palette + effective opacity step for a selection (pure). */
    fun resolveSelection(
        spec: ThemeSpec,
        paletteId: String?,
        opacityStep: Int,
        legacyBg: String?,
        legacyOpacity: Float,
        phase: String,
    ): Pair<Palette, Int> {
        if (paletteId == null) {
            // First run after the legacy style keys: migrate the stored colors
            // to the closest preset and derive the step from the old opacity.
            val migratedId = migrateLegacy(spec, legacyBg, legacyOpacity)
            return byId(spec, migratedId) to stepFromOpacity(spec, legacyOpacity)
        }
        val palette = when (paletteId) {
            AUTO_ID -> paletteForPhase(spec, phase)
            else -> byId(spec, paletteId)
        }
        return palette to opacityStep.coerceIn(0, spec.opacitySteps.size - 1)
    }

    private fun stepFromOpacity(spec: ThemeSpec, opacity: Float): Int {
        if (opacity < 0f) return 0
        return spec.opacitySteps.withIndex()
            .minByOrNull { (_, s) -> kotlin.math.abs(s - opacity) }?.index ?: 0
    }

    fun paletteForPhase(spec: ThemeSpec, phase: String): Palette =
        spec.palettes.firstOrNull { it.autoPhases.contains(phase) }
            ?: byId(spec, spec.defaultId)

    fun byId(spec: ThemeSpec, id: String?): Palette =
        spec.palettes.firstOrNull { it.id == id }
            // The 2026-11 palette table retired «طلایی» (gold); its readers'
            // nearest neighbour is the gold-accent brown preset.
            ?: spec.palettes.firstOrNull { it.id == "brown_gold" && id == "gold" }
            ?: spec.palettes.firstOrNull { it.id == spec.defaultId }
            ?: spec.palettes.first()

    /** The default palette for one widget type — prayer → «زمردی», tasbih →
     *  «شب آبی» when the JSON names them, the shared default otherwise. */
    fun defaultFor(spec: ThemeSpec, target: WidgetTarget): String =
        when (target) {
            WidgetTarget.PRAYER -> spec.defaultPrayer
            WidgetTarget.TASBIH -> spec.defaultTasbih
        } ?: spec.defaultId

    /**
     * Legacy widget_bg_color → preset migration: exact bg match first, then
     * the nearest palette among those of the same lightness (a light legacy
     * skin must never migrate onto a dark preset or vice versa).
     */
    fun migrateLegacy(spec: ThemeSpec, legacyBg: String?, legacyOpacity: Float): String {
        if (legacyBg != null) {
            val legacy = parseColor(legacyBg, 0)
            if (legacy != 0) {
                spec.palettes.firstOrNull { it.bg == legacy }?.let { return it.id }
                val legacyLight = luminance(legacy) > 0.5f
                val sameLightness = spec.palettes.filter { it.light == legacyLight }
                if (sameLightness.isNotEmpty()) {
                    return sameLightness.minByOrNull { colorDistance(it.bg, legacy) }!!.id
                }
            }
        }
        return byId(spec, spec.defaultId).id
    }

    fun applyOpacity(color: Int, opacity: Float): Int {
        val alpha = (opacity.coerceIn(0f, 1f) * 255f).toInt().coerceIn(0, 255)
        return (alpha shl 24) or (color and 0x00FFFFFF)
    }

    fun luminance(color: Int): Float {
        fun channel(v: Int): Float {
            val s = v / 255.0
            return if (s <= 0.03928) (s / 12.92).toFloat()
            else Math.pow((s + 0.055) / 1.055, 2.4).toFloat()
        }
        return 0.2126f * channel((color shr 16) and 0xFF) +
            0.7152f * channel((color shr 8) and 0xFF) +
            0.0722f * channel(color and 0xFF)
    }

    private fun colorDistance(a: Int, b: Int): Int {
        val dr = ((a shr 16) and 0xFF) - ((b shr 16) and 0xFF)
        val dg = ((a shr 8) and 0xFF) - ((b shr 8) and 0xFF)
        val db = (a and 0xFF) - (b and 0xFF)
        return dr * dr + dg * dg + db * db
    }

    /** Pure #RRGGBB / #AARRGGBB parser — android.graphics.Color is stubbed
     *  in JVM unit tests and throws there, so the core must not depend on it. */
    private fun parseColor(hex: String, fallback: Int): Int {
        val h = hex.trim().removePrefix("#")
        return when (h.length) {
            6 -> h.toLongOrNull(16)?.let { (0xFF000000L or it).toInt() } ?: fallback
            8 -> h.toLongOrNull(16)?.toInt() ?: fallback
            else -> fallback
        }
    }

    // ── Android wiring ──

    private var cachedSpec: ThemeSpec? = null

    fun loadSpec(context: Context): ThemeSpec {
        cachedSpec?.let { return it }
        val json = readAsset(context) ?: return parseSpec(FALLBACK_JSON).also { cachedSpec = it }
        return try {
            parseSpec(json).also { cachedSpec = it }
        } catch (_: Exception) {
            parseSpec(FALLBACK_JSON).also { cachedSpec = it }
        }
    }

    private fun readAsset(context: Context): String? {
        // Pubspec assets are merged under flutter_assets/ in the APK; the
        // un-prefixed variants keep the resolver working in unit / robolectric
        // setups where the asset may sit at the Android asset root.
        for (path in listOf(
            "flutter_assets/assets/widget_palettes.json",
            "assets/widget_palettes.json",
            "widget_palettes.json",
        )) {
            try {
                return context.assets.open(path).bufferedReader().use { it.readText() }
            } catch (_: Exception) {
            }
        }
        return null
    }

    fun resolve(context: Context, target: WidgetTarget, widgetId: Int? = null): Resolved {
        val prefs = WidgetRepository.prefs(context)
        val spec = loadSpec(context)
        // A per-widget-instance override — written by the pin-time config
        // activity and keyed by the exact instance id — wins over the
        // target-level selection, which wins over the shared/legacy adoption.
        // This is what lets the horizontal and vertical prayer cards (and
        // several copies of either) each carry their own palette.
        val instancePalette = widgetId?.let { prefs.getString("${target.paletteKey}_$it", null) }
        val perWidgetId = instancePalette ?: prefs.getString(target.paletteKey, null)
        var selectionId: String?
        val selectionStep: Int
        var legacyBg: String? = null
        var legacyOpacity = -1f
        var adoptedRawId: String? = null
        if (perWidgetId != null) {
            selectionId = perWidgetId
            selectionStep = if (instancePalette != null) {
                prefs.getInt("${target.stepKey}_$widgetId", 0)
            } else {
                prefs.getInt(target.stepKey, 0)
            }
        } else {
            // Adoption: the shared keys are the previous build's storage; once
            // adopted into the per-widget keys this target never reads them
            // again, so the other widget's later edits cannot move it.
            selectionId = prefs.getString(PREF_PALETTE_ID, null)
            if (selectionId != null) {
                selectionStep = prefs.getInt(PREF_OPACITY_STEP, 0)
                adoptedRawId = selectionId
            } else if (legacyBg != null || prefs.contains(PREF_LEGACY_BG)) {
                selectionStep = 0
                legacyBg = prefs.getString(PREF_LEGACY_BG, null)
                legacyOpacity = prefs.getFloat(PREF_LEGACY_OPACITY, -1f)
            } else {
                // Nothing stored at all: the brief's per-widget default
                // (prayer → «زمردی», tasbih → «شب آبی»), not the shared one.
                selectionId = defaultFor(spec, target)
                selectionStep = 0
            }
        }
        val phase = phaseForNow(context)
        val (palette, step) = resolveSelection(spec, selectionId, selectionStep, legacyBg, legacyOpacity, phase)
        if (perWidgetId == null) {
            // Persist the adoption once so the settings page reads the same
            // selection the widget renders with. The adopted shared id is kept
            // verbatim (an "auto" selection must not be frozen into a phase's
            // concrete palette); the legacy path has no raw id, so the
            // migrated palette id is stored.
            prefs.edit()
                .putString(target.paletteKey, adoptedRawId ?: palette.id)
                .putInt(target.stepKey, step)
                .apply()
        }
        val opacity = spec.opacitySteps[step]
        // ── Raw ARGB wins over the palette ──
        // The app resolves the final colours (its own theme, its own accent
        // picker) and pushes them as ints. Reading them here — rather than
        // hardcoding a colour in the widget — is what keeps the card in step
        // with the app when the user changes theme. A 0 means "never pushed",
        // in which case the palette's own value stands.
        val textOverride = WidgetPrefs.argb(prefs, WidgetPrefs.KEY_TEXT_ARGB)
        val accentOverride = WidgetPrefs.argb(prefs, WidgetPrefs.KEY_ACCENT_ARGB)
        val bgOverride = WidgetPrefs.argb(prefs, WidgetPrefs.KEY_BG_ARGB)
        val bgEndOverride = WidgetPrefs.argb(prefs, WidgetPrefs.KEY_BG_END_ARGB)
        val text = textOverride.takeIf { it != 0 } ?: palette.text
        val accent = accentOverride.takeIf { it != 0 } ?: palette.accent
        val tokens = when (target) {
            WidgetTarget.PRAYER -> palette.prayerTokens
            WidgetTarget.TASBIH -> palette.tasbihTokens
        }
        return Resolved(
            palette = palette,
            // The override supplies the COLOUR; the step still supplies the
            // ALPHA. Reading the pushed ARGB verbatim is what made
            // «شفافیت پس‌زمینه» do nothing at all: the app pushes a full-alpha
            // ARGB on every sync, so the palette's own applyOpacity was never
            // reached and every step rendered identical.
            bg = applyOpacity(bgOverride.takeIf { it != 0 } ?: palette.bg, opacity),
            bgEnd = applyOpacity(bgEndOverride.takeIf { it != 0 } ?: palette.bgEnd, opacity),
            text = text,
            accent = accent,
            opacity = opacity,
            opacityStep = step,
            tokens = tokens,
        )
    }

    /**
     * Drawable name of the generated skin for a palette + opacity, e.g.
     * `widget_emerald_bg_o70`. The suffix rule mirrors
     * `tool/widget_palette_generator.dart` exactly (full opacity has none), and
     * all 28 files are generator output — never hand-edit one.
     */
    fun skinName(paletteId: String, opacity: Float): String {
        val suffix = if (opacity >= 1f) "" else "_o${Math.round(opacity * 100)}"
        return "widget_${paletteId}_bg$suffix"
    }

    /** [skinName] resolved against the app's drawables, or 0 when the palette
     *  has no generated skin (e.g. an id added to the JSON before a generator
     *  run) so callers keep their fallback path. */
    fun skinFor(context: Context, paletteId: String, opacity: Float): Int =
        context.resources.getIdentifier(
            skinName(paletteId, opacity),
            "drawable",
            context.packageName,
        )

    /**
     * A generated NEUTRAL fill for one shape and alpha step, chosen by the
     * palette's lightness: white@alpha on dark presets, black@alpha on light
     * ones (brief §theming 3). [shape] is `capsule` (radius 22), `circle`
     * (oval) or `pill` (radius 17); [percent] is the design's nominal step
     * (8/12/14/16 for dark, mapped to 6/8/12/16 black on light).
     */
    fun neutralFill(
        context: Context,
        light: Boolean,
        shape: String,
        percent: Int,
    ): Int {
        val mapped = when {
            !light -> percent
            percent <= 8 -> 6
            percent <= 12 -> 8
            else -> 12
        }
        val family = if (light) "b" else "w"
        val name = "widget_${shape}_$family$mapped"
        return context.resources.getIdentifier(name, "drawable", context.packageName)
    }

    /** The generated next-capsule fill for a palette, or 0 (callers fall back
     *  to a neutral fill when the palette predates the generator run). */
    fun nextFillRes(context: Context, paletteId: String): Int =
        context.resources.getIdentifier(
            "widget_prayer_next_$paletteId",
            "drawable",
            context.packageName,
        )

    internal fun phaseForNow(context: Context): String {
        val prefs = WidgetRepository.prefs(context)
        val cal = java.util.Calendar.getInstance()
        val now = cal.get(java.util.Calendar.HOUR_OF_DAY) * 60 + cal.get(java.util.Calendar.MINUTE)
        fun minutes(key: String): Int? =
            WidgetRepository.parsePrayerString(prefs.getString(key, "") ?: "").second
                .split(":").takeIf { it.size == 2 }
                ?.let { (h, m) -> h.toIntOrNull()?.times(60)?.plus(m.toIntOrNull() ?: return null) }
        return phaseFor(
            nowMinutesOfDay = now,
            fajr = minutes("prayer_1"),
            sunrise = minutes("sunrise"),
            dhuhr = minutes("prayer_2"),
            asr = minutes("prayer_3"),
            maghrib = minutes("prayer_4"),
            isha = minutes("prayer_5"),
        )
    }

    /** Minimal spec for the unlikely case the asset cannot be opened. */
    private const val FALLBACK_JSON = """{
      "defaultPalette": "brown_gold",
      "opacitySteps": [1.0, 0.85, 0.7, 0.55],
      "palettes": [
        {"id": "brown_gold", "bg": "#3B2316", "bgEnd": "#2A1A10", "text": "#F5EDE3", "accent": "#C9A94E", "light": false, "autoPhases": ["afternoon"]}
      ]
    }"""
}
