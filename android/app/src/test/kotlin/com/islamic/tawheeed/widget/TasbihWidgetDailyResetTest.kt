package com.islamic.tawheeed.widget

import android.content.SharedPreferences
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Guards the widget's native daily auto-reset: it must zero the per-zikr
 *  counters at most once per day, only when the app's «ریست خودکار روزانه» is
 *  enabled, and always stamp the reset so the app-side merge imports it. */
class TasbihWidgetDailyResetTest {

    private fun prefs(
        lastActiveDate: String? = null,
        autoReset: Boolean = true,
        counts: Map<Int, Int> = emptyMap(),
        currentCount: Int = 0,
    ): FakeSharedPreferences {
        val fake = FakeSharedPreferences()
        if (lastActiveDate != null) {
            fake.edit().putString("widget_tasbih_last_active_date", lastActiveDate).apply()
        }
        fake.edit().putBoolean("tasbih_auto_reset", autoReset).apply()
        if (counts.isNotEmpty()) {
            TasbihGlanceWidgetReceiver.setPerZikrCounts(fake, counts)
        }
        fake.edit().putInt("tasbih_count", currentCount).apply()
        return fake
    }

    @Test
    fun sameDay_noReset() {
        val fake = prefs(
            lastActiveDate = "2026-08-19",
            counts = mapOf(0 to 30, 1 to 33),
            currentCount = 30,
        )
        assertFalse(TasbihGlanceWidgetReceiver.maybeDailyReset(fake, "2026-08-19"))
        assertEquals(30, TasbihGlanceWidgetReceiver.getPerZikrCounts(fake)[0])
        assertEquals(30, fake.getInt("tasbih_count", -1))
    }

    @Test
    fun newDay_autoResetEnabled_zeroesCountsAndStampsReset() {
        val fake = prefs(
            lastActiveDate = "2026-08-18",
            autoReset = true,
            counts = mapOf(0 to 30, 1 to 33),
            currentCount = 30,
        )
        assertTrue(TasbihGlanceWidgetReceiver.maybeDailyReset(fake, "2026-08-19"))
        val after = TasbihGlanceWidgetReceiver.getPerZikrCounts(fake)
        assertEquals(0, after[0])
        assertEquals(0, after[1])
        assertEquals(0, fake.getInt("tasbih_count", -1))
        assertTrue(fake.getLong("widget_tasbih_last_tap_at", 0) > 0)
        assertEquals("2026-08-19", fake.getString("widget_tasbih_last_active_date", null))
    }

    @Test
    fun newDay_autoResetDisabled_keepsCounts() {
        val fake = prefs(
            lastActiveDate = "2026-08-18",
            autoReset = false,
            counts = mapOf(0 to 50),
            currentCount = 50,
        )
        assertFalse(TasbihGlanceWidgetReceiver.maybeDailyReset(fake, "2026-08-19"))
        assertEquals(50, TasbihGlanceWidgetReceiver.getPerZikrCounts(fake)[0])
        assertEquals(50, fake.getInt("tasbih_count", -1))
        assertEquals("2026-08-19", fake.getString("widget_tasbih_last_active_date", null))
    }

    @Test
    fun firstRun_stampsDateKeyEvenWithNoCounts() {
        val fake = prefs(autoReset = true)
        assertTrue(TasbihGlanceWidgetReceiver.maybeDailyReset(fake, "2026-08-19"))
        assertEquals("2026-08-19", fake.getString("widget_tasbih_last_active_date", null))
        assertEquals(0, fake.getInt("tasbih_count", -1))
    }

    private class FakeSharedPreferences : SharedPreferences {
        private val store = mutableMapOf<String, Any?>()

        override fun getAll(): MutableMap<String, *> = store.toMutableMap()
        override fun getString(key: String, defValue: String?): String? =
            store[key] as? String ?: defValue
        @Suppress("UNCHECKED_CAST")
        override fun getStringSet(key: String, defValue: MutableSet<String>?): MutableSet<String>? =
            store[key] as? MutableSet<String> ?: defValue
        override fun getInt(key: String, defValue: Int): Int =
            store[key] as? Int ?: defValue
        override fun getLong(key: String, defValue: Long): Long =
            (store[key] as? Int)?.toLong() ?: (store[key] as? Long) ?: defValue
        override fun getFloat(key: String, defValue: Float): Float =
            store[key] as? Float ?: defValue
        override fun getBoolean(key: String, defValue: Boolean): Boolean =
            store[key] as? Boolean ?: defValue
        override fun contains(key: String): Boolean = store.containsKey(key)

        override fun edit(): SharedPreferences.Editor = FakeEditor()

        override fun registerOnSharedPreferenceChangeListener(
            listener: SharedPreferences.OnSharedPreferenceChangeListener?
        ) = Unit
        override fun unregisterOnSharedPreferenceChangeListener(
            listener: SharedPreferences.OnSharedPreferenceChangeListener?
        ) = Unit

        private inner class FakeEditor : SharedPreferences.Editor {
            private val pending = mutableMapOf<String, Any?>()

            override fun putString(key: String, value: String?): SharedPreferences.Editor {
                pending[key] = value
                return this
            }
            override fun putStringSet(
                key: String,
                values: MutableSet<String>?
            ): SharedPreferences.Editor {
                pending[key] = values
                return this
            }
            override fun putInt(key: String, value: Int): SharedPreferences.Editor {
                pending[key] = value
                return this
            }
            override fun putLong(key: String, value: Long): SharedPreferences.Editor {
                pending[key] = value
                return this
            }
            override fun putFloat(key: String, value: Float): SharedPreferences.Editor {
                pending[key] = value
                return this
            }
            override fun putBoolean(key: String, value: Boolean): SharedPreferences.Editor {
                pending[key] = value
                return this
            }
            override fun remove(key: String): SharedPreferences.Editor {
                pending[key] = null
                return this
            }
            override fun clear(): SharedPreferences.Editor {
                pending.clear()
                return this
            }
            override fun commit(): Boolean {
                store.putAll(pending)
                return true
            }
            override fun apply() {
                store.putAll(pending)
            }
        }
    }
}