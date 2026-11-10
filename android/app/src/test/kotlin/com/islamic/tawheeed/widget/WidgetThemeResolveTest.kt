package com.islamic.tawheeed.widget

import android.app.Application
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * The per-widget selection ladder on a real prefs store: each widget's own
 * keys win; the shared keys are adopted into them exactly once (id verbatim,
 * so an "auto" selection is never frozen into a phase's palette); an adopted
 * widget never retro-adopts; and legacy colors land as a persisted palette id.
 *
 * Palette content is deliberately not pinned here — the id lookup falls back
 * through [WidgetTheme.byId] whether the real asset or the FALLBACK spec
 * loads, so the assertions use the STEP and the persisted keys, which are
 * identical under both.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = Application::class)
class WidgetThemeResolveTest {

    private lateinit var context: Application

    @Before
    fun setUp() {
        context = RuntimeEnvironment.getApplication()
        WidgetRepository.prefs(context).edit().clear().commit()
    }

    private fun prefs() = WidgetRepository.prefs(context)

    @Test
    fun `per-widget keys win over the shared keys`() {
        prefs().edit()
            .putString(WidgetTheme.PREF_PALETTE_ID, "emerald")
            .putInt(WidgetTheme.PREF_OPACITY_STEP, 2)
            .putString(WidgetTheme.WidgetTarget.PRAYER.paletteKey, "night_blue")
            .putInt(WidgetTheme.WidgetTarget.PRAYER.stepKey, 0)
            .commit()

        val resolved = WidgetTheme.resolve(context, WidgetTheme.WidgetTarget.PRAYER)

        // The shared step would have been 2; the per-widget step is 0.
        assertEquals(0, resolved.opacityStep)
    }

    @Test
    fun `adoption persists the shared selection into the per-widget keys once`() {
        prefs().edit()
            .putString(WidgetTheme.PREF_PALETTE_ID, "emerald")
            .putInt(WidgetTheme.PREF_OPACITY_STEP, 3)
            .commit()

        val resolved = WidgetTheme.resolve(context, WidgetTheme.WidgetTarget.PRAYER)

        assertEquals(
            "emerald",
            prefs().getString(WidgetTheme.WidgetTarget.PRAYER.paletteKey, null),
        )
        assertEquals(3, prefs().getInt(WidgetTheme.WidgetTarget.PRAYER.stepKey, -1))
        assertEquals(3, resolved.opacityStep)
    }

    @Test
    fun `an auto adoption is stored verbatim, not frozen into a phase palette`() {
        prefs().edit()
            .putString(WidgetTheme.PREF_PALETTE_ID, WidgetTheme.AUTO_ID)
            .putInt(WidgetTheme.PREF_OPACITY_STEP, 1)
            .commit()

        WidgetTheme.resolve(context, WidgetTheme.WidgetTarget.TASBIH)

        assertEquals(
            WidgetTheme.AUTO_ID,
            prefs().getString(WidgetTheme.WidgetTarget.TASBIH.paletteKey, null),
        )
        assertEquals(1, prefs().getInt(WidgetTheme.WidgetTarget.TASBIH.stepKey, -1))
    }

    @Test
    fun `an adopted widget never retro-adopts`() {
        prefs().edit()
            .putString(WidgetTheme.PREF_PALETTE_ID, "emerald")
            .putInt(WidgetTheme.PREF_OPACITY_STEP, 2)
            .commit()
        WidgetTheme.resolve(context, WidgetTheme.WidgetTarget.PRAYER)

        // The shared keys and the other widget both move afterwards.
        prefs().edit()
            .putString(WidgetTheme.PREF_PALETTE_ID, "sunset")
            .putInt(WidgetTheme.PREF_OPACITY_STEP, 1)
            .putString(WidgetTheme.WidgetTarget.TASBIH.paletteKey, "dawn_purple")
            .putInt(WidgetTheme.WidgetTarget.TASBIH.stepKey, 3)
            .commit()

        val again = WidgetTheme.resolve(context, WidgetTheme.WidgetTarget.PRAYER)

        assertEquals(
            "emerald",
            prefs().getString(WidgetTheme.WidgetTarget.PRAYER.paletteKey, null),
        )
        assertEquals(2, again.opacityStep)
        assertEquals(2, prefs().getInt(WidgetTheme.WidgetTarget.PRAYER.stepKey, -1))
    }

    @Test
    fun `legacy colors migrate and persist as a palette id`() {
        prefs().edit()
            .putString("widget_bg_color", "#004F9E")
            .putFloat("widget_opacity", 0.85f)
            .commit()

        val resolved = WidgetTheme.resolve(context, WidgetTheme.WidgetTarget.PRAYER)

        // The migrated id depends on which spec loaded (the real asset has the
        // exact night_blue match, the FALLBACK spec migrates within dark
        // palettes) — derive the expectation from the same pure function.
        val expected = WidgetTheme.migrateLegacy(
            WidgetTheme.loadSpec(context), "#004F9E", 0.85f,
        )
        assertEquals(
            expected,
            prefs().getString(WidgetTheme.WidgetTarget.PRAYER.paletteKey, null),
        )
        // 0.85 → the nearest stored step (0.85) → index 1.
        assertEquals(1, resolved.opacityStep)
        assertEquals(1, prefs().getInt(WidgetTheme.WidgetTarget.PRAYER.stepKey, -1))
    }

    /**
     * «شفافیت پس‌زمینه هیچ عملکردی ندارد» — the app pushes a full-alpha
     * background ARGB on every sync, and that override used to be returned
     * verbatim, so the palette's own applyOpacity was never reached and every
     * step painted the same. The step must survive the override: the override
     * supplies the colour, the step supplies the alpha.
     */
    @Test
    fun `the opacity step still applies when the app pushes a raw background`() {
        prefs().edit()
            .putString(WidgetTheme.WidgetTarget.PRAYER.paletteKey, "night_blue")
            .putInt(WidgetTheme.WidgetTarget.PRAYER.stepKey, 0)
            .putInt(WidgetPrefs.KEY_BG_ARGB, 0xFF004F9E.toInt())
            .putInt(WidgetPrefs.KEY_BG_END_ARGB, 0xFF00305F.toInt())
            .commit()

        val full = WidgetTheme.resolve(context, WidgetTheme.WidgetTarget.PRAYER)
        assertEquals(0xFF, (full.bg ushr 24) and 0xFF)
        // The pushed colour itself is kept — only its alpha is replaced.
        assertEquals(0x004F9E, full.bg and 0x00FFFFFF)

        val steps = WidgetTheme.loadSpec(context).opacitySteps
        for (step in steps.indices) {
            prefs().edit().putInt(WidgetTheme.WidgetTarget.PRAYER.stepKey, step).commit()
            val resolved = WidgetTheme.resolve(context, WidgetTheme.WidgetTarget.PRAYER)
            val expectedAlpha = (steps[step].coerceIn(0f, 1f) * 255f).toInt()
            assertEquals(
                "step $step must set the background alpha",
                expectedAlpha,
                (resolved.bg ushr 24) and 0xFF,
            )
            assertEquals(
                "step $step must set the gradient end alpha",
                expectedAlpha,
                (resolved.bgEnd ushr 24) and 0xFF,
            )
            assertEquals(0x004F9E, resolved.bg and 0x00FFFFFF)
            assertEquals(0x00305F, resolved.bgEnd and 0x00FFFFFF)
        }
    }
}
