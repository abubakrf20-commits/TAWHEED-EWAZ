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
 * «عنوان ذکر از ویجت تسبیح حذف شده» — the card's title is `tasbih_dhikr`, and
 * a sync that lands before the app's adhkar list has loaded writes it as an
 * empty string. The card then renders with no name at all: the ring, the
 * «ذکر N از M» pill and the counter, but nothing saying WHICH zikr.
 *
 * The model now treats a blank stored name as "unknown" and resolves it from
 * the list — the selected entry first, then the first named one, then the
 * shipped default — so the card always names what it is counting.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = Application::class)
class TasbihWidgetTitleTest {

    private lateinit var context: Application

    @Before
    fun setUp() {
        context = RuntimeEnvironment.getApplication()
        WidgetRepository.prefs(context).edit().clear().commit()
    }

    private fun prefs() = WidgetRepository.prefs(context)

    private fun list() = TasbihGlanceWidgetReceiver.getZikrList(prefs())

    @Test
    fun `a blank stored name falls back to the selected zikr`() {
        prefs().edit()
            .putString("tasbih_dhikr", "")
            .putInt("tasbih_zikr_index", 2)
            .commit()

        val state = TasbihWidgetModel.read(prefs())

        assertEquals(list()[2], state.dhikr)
    }

    @Test
    fun `a whitespace-only name is treated as missing`() {
        prefs().edit()
            .putString("tasbih_dhikr", "   ")
            .putInt("tasbih_zikr_index", 0)
            .commit()

        assertEquals(list()[0], TasbihWidgetModel.read(prefs()).dhikr)
    }

    @Test
    fun `no stored name at all still titles the card`() {
        val state = TasbihWidgetModel.read(prefs())

        assertEquals(list()[0], state.dhikr)
    }

    @Test
    fun `an out-of-range index falls back to the first named zikr`() {
        prefs().edit()
            .putString("tasbih_dhikr", "")
            .putInt("tasbih_zikr_index", 99)
            .commit()

        assertEquals(list()[0], TasbihWidgetModel.read(prefs()).dhikr)
    }

    @Test
    fun `a real stored name is never overridden`() {
        prefs().edit()
            .putString("tasbih_dhikr", "سبحان الله و بحمده")
            .putInt("tasbih_zikr_index", 0)
            .commit()

        assertEquals("سبحان الله و بحمده", TasbihWidgetModel.read(prefs()).dhikr)
    }
}
