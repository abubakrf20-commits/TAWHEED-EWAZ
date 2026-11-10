package com.islamic.tawheeed.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class WidgetThemeTest {

    private val spec = WidgetTheme.parseSpec(SPEC_JSON)

    @Test
    fun `parses palettes, opacity steps and the default id`() {
        assertEquals(
            listOf("brown_gold", "night_blue", "emerald", "sunset", "dawn_purple", "auto_ghost", "cream_light"),
            spec.palettes.map { it.id })
        assertEquals(listOf(1f, 0.85f, 0.7f, 0.55f), spec.opacitySteps)
        assertEquals("brown_gold", spec.defaultId)
        val brown = spec.palettes.first()
        assertEquals(0xFF3B2316.toInt(), brown.bg)
        assertEquals(0xFFC9A94E.toInt(), brown.accent)
        assertTrue(brown.autoPhases.contains("afternoon"))
    }

    @Test
    fun `phase covers the whole day around fixed adhan times`() {
        // fajr 05:00, sunrise 06:20, dhuhr 12:10, asr 15:30, maghrib 18:00, isha 19:20
        fun phase(minuteOfDay: Int) = WidgetTheme.phaseFor(
            minuteOfDay, fajr = 300, sunrise = 380, dhuhr = 730,
            asr = 930, maghrib = 1080, isha = 1160,
        )
        assertEquals("night", phase(0)) // after midnight, before fajr
        assertEquals("dawn", phase(300))
        assertEquals("dawn", phase(379))
        assertEquals("morning", phase(380))
        assertEquals("afternoon", phase(730))
        assertEquals("sunset", phase(930))
        assertEquals("evening", phase(1080))
        assertEquals("night", phase(1160))
        assertEquals("night", phase(1439))
    }

    @Test
    fun `phase falls back to night when boundaries are missing`() {
        assertEquals("night", WidgetTheme.phaseFor(600, null, null, null, null, null, null))
    }

    @Test
    fun `auto resolves each phase to its palette`() {
        assertEquals("dawn_purple", WidgetTheme.paletteForPhase(spec, "dawn").id)
        assertEquals("cream_light", WidgetTheme.paletteForPhase(spec, "morning").id)
        assertEquals("brown_gold", WidgetTheme.paletteForPhase(spec, "afternoon").id)
        assertEquals("sunset", WidgetTheme.paletteForPhase(spec, "sunset").id)
        assertEquals("sunset", WidgetTheme.paletteForPhase(spec, "evening").id)
        assertEquals("night_blue", WidgetTheme.paletteForPhase(spec, "night").id)
    }

    @Test
    fun `explicit selection wins and step is clamped`() {
        val (palette, step) = WidgetTheme.resolveSelection(
            spec, "emerald", 9, legacyBg = null, legacyOpacity = -1f, phase = "night",
        )
        assertEquals("emerald", palette.id)
        assertEquals(3, step) // clamped to the last of 4 steps

        val (auto, _) = WidgetTheme.resolveSelection(
            spec, "auto", 0, legacyBg = null, legacyOpacity = -1f, phase = "sunset",
        )
        assertEquals("sunset", auto.id)
    }

    @Test
    fun `legacy brand blue migrates exactly onto night_blue`() {
        val (palette, step) = WidgetTheme.resolveSelection(
            spec, null, 0,
            legacyBg = "#004F9E", legacyOpacity = 0.95f, phase = "afternoon",
        )
        assertEquals("night_blue", palette.id)
        assertEquals(0, step) // 0.95 → nearest stored step 1.0 → index 0
    }

    @Test
    fun `legacy light skin migrates only onto light palettes`() {
        val (palette, _) = WidgetTheme.resolveSelection(
            spec, null, 0,
            legacyBg = "#F1EDE4", legacyOpacity = -1f, phase = "afternoon",
        )
        assertTrue(palette.light)
    }

    @Test
    fun `no legacy colors migrates to the default palette`() {
        val (palette, step) = WidgetTheme.resolveSelection(
            spec, null, 0, legacyBg = null, legacyOpacity = -1f, phase = "night",
        )
        assertEquals("brown_gold", palette.id)
        assertEquals(0, step)
    }

    @Test
    fun `opacity is baked into the alpha channel`() {
        val bg = 0xFF3B2316.toInt()
        assertEquals(0xFF3B2316.toInt(), WidgetTheme.applyOpacity(bg, 1f))
        val step55 = WidgetTheme.applyOpacity(bg, 0.55f) // 0.55 * 255 = 140.25 → 140
        assertEquals(140, (step55 ushr 24) and 0xFF)
        assertEquals(bg and 0x00FFFFFF, step55 and 0x00FFFFFF)
    }

    @Test
    fun `skin names mirror the generator suffix rule`() {
        // tool/widget_palette_generator.dart writes
        // widget_<id>_bg[_o<round(step*100)>] — full opacity has no suffix.
        assertEquals("widget_emerald_bg", WidgetTheme.skinName("emerald", 1f))
        assertEquals("widget_emerald_bg_o85", WidgetTheme.skinName("emerald", 0.85f))
        assertEquals("widget_emerald_bg_o70", WidgetTheme.skinName("emerald", 0.7f))
        assertEquals("widget_emerald_bg_o55", WidgetTheme.skinName("emerald", 0.55f))
        assertEquals("widget_brown_gold_bg_o70", WidgetTheme.skinName("brown_gold", 0.7f))
    }

    @Test
    fun `wire values map to targets with a prayer fallback`() {
        assertEquals(WidgetTheme.WidgetTarget.TASBIH, WidgetTheme.WidgetTarget.fromWire("tasbih"))
        assertEquals(WidgetTheme.WidgetTarget.PRAYER, WidgetTheme.WidgetTarget.fromWire("prayer"))
        assertEquals(WidgetTheme.WidgetTarget.PRAYER, WidgetTheme.WidgetTarget.fromWire(null))
        assertEquals(WidgetTheme.WidgetTarget.PRAYER, WidgetTheme.WidgetTarget.fromWire("unknown"))
        assertEquals("widget_palette_id_prayer", WidgetTheme.WidgetTarget.PRAYER.paletteKey)
        assertEquals("widget_opacity_step_prayer", WidgetTheme.WidgetTarget.PRAYER.stepKey)
        assertEquals("widget_palette_id_tasbih", WidgetTheme.WidgetTarget.TASBIH.paletteKey)
        assertEquals("widget_opacity_step_tasbih", WidgetTheme.WidgetTarget.TASBIH.stepKey)
    }

    private companion object {
        const val SPEC_JSON = """{
          "defaultPalette": "brown_gold",
          "opacitySteps": [1.0, 0.85, 0.7, 0.55],
          "palettes": [
            {"id": "brown_gold", "bg": "#3B2316", "bgEnd": "#2A1A10", "text": "#F5EDE3", "accent": "#C9A94E", "light": false, "autoPhases": ["afternoon"]},
            {"id": "night_blue", "bg": "#004F9E", "bgEnd": "#003A73", "text": "#FFFFFF", "accent": "#E8D08A", "light": false, "autoPhases": ["night"]},
            {"id": "emerald", "bg": "#1B4332", "bgEnd": "#122E23", "text": "#F5EDE3", "accent": "#95D5B2", "light": false, "autoPhases": []},
            {"id": "sunset", "bg": "#7C2D12", "bgEnd": "#5A1F0C", "text": "#FFF7ED", "accent": "#FDBA74", "light": false, "autoPhases": ["sunset", "evening"]},
            {"id": "dawn_purple", "bg": "#4C1D95", "bgEnd": "#35156B", "text": "#F3E8FF", "accent": "#D8B4FE", "light": false, "autoPhases": ["dawn"]},
            {"id": "auto_ghost", "bg": "#112233", "bgEnd": "#000000", "text": "#FFFFFF", "accent": "#FFFFFF", "light": false, "autoPhases": []},
            {"id": "cream_light", "bg": "#F8F5F0", "bgEnd": "#EDE4D3", "text": "#3B2316", "accent": "#8A5A2B", "light": true, "autoPhases": ["morning"]}
          ]
        }"""
    }
}
