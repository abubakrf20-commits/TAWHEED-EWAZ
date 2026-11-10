package com.islamic.tawheeed.widget

import android.app.Application
import android.content.Context
import android.content.Intent
import android.os.Looper
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowLog

/**
 * Robolectric harness for the tasbih tap path — the first JVM coverage of
 * [TasbihGlanceWidgetReceiver.onReceive], [TasbihTapEngine.applyTap] and the
 * [TasbihActionActivity] trampoline together.
 *
 * This closes the one known test gap in docs/WIDGETS_PLAN.md (option 5):
 * three shipped tap bugs (the sender guard rejecting its own PendingIntents,
 * the org.json channel reply, the render race) were invisible to every Dart
 * source-scan and the existing JVM suites because onReceive was never invoked.
 *
 * Notes that keep these tests deterministic:
 *  - Robolectric shares ONE classloader across all test methods of this class
 *    (identical @Config), so the engine's JVM statics PERSIST across methods.
 *    Prefs and the Application ARE fresh per method, which is why the event
 *    queue's own sequence numbers ("s") can be asserted exactly while nothing
 *    asserts a process-wide counter.
 *  - `SystemClock.elapsedRealtime()` starts at ~0 and only advances when the
 *    scheduler advances, so the 3 s reset-confirm window armed in a test
 *    stays open through that test, and the activity's 1500 ms finish
 *    fallback and the 1.5 s heal repaint never fire spuriously.
 *  - The main looper is paused; [awaitTrue] pumps it while polling for the
 *    background (Dispatchers.Default) coroutine work to land.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = Application::class)
class TasbihTapPathTest {

    private lateinit var context: Context

    @Before
    fun setUp() {
        context = RuntimeEnvironment.getApplication()
        ShadowLog.stream = System.out
        ShadowLog.clear()
    }

    // ── helpers ────────────────────────────────────────────────────────────

    private fun prefs() = WidgetRepository.prefs(context)

    /** Direct synchronous invocation — safe only for branches that return
     *  BEFORE goAsync (the foreign-tap drop, the superseded safety heal). */
    private fun receive(intent: Intent) {
        TasbihGlanceWidgetReceiver().onReceive(context, intent)
    }

    /** A real sendBroadcast through the shadow instrumentation, with the
     *  explicit component + own package the production intents carry. */
    private fun broadcast(intent: Intent) {
        context.sendBroadcast(
            intent
                .setClass(context, TasbihGlanceWidgetReceiver::class.java)
                .setPackage(context.packageName),
        )
    }

    private fun awaitTrue(timeoutMs: Long = 10_000L, condition: () -> Boolean) {
        val deadline = System.nanoTime() + timeoutMs * 1_000_000L
        while (System.nanoTime() < deadline) {
            shadowOf(Looper.getMainLooper()).idle()
            if (condition()) return
            Thread.sleep(20)
        }
        fail("condition not met within ${timeoutMs}ms")
    }

    private fun logsContain(part: String): Boolean =
        ShadowLog.getLogsForTag(TAG).any { it.msg?.contains(part) == true }

    private fun events(): List<Map<String, Any?>> =
        TasbihGlanceWidgetReceiver.plainEvents(prefs())

    private fun eventInt(ev: Map<String, Any?>, key: String): Int =
        (ev[key] as Number).toInt()

    private fun counts() = TasbihGlanceWidgetReceiver.getPerZikrCounts(prefs())

    private fun seedCounts(vararg pairs: Pair<Int, Int>) {
        TasbihGlanceWidgetReceiver.setPerZikrCounts(prefs(), pairs.toMap())
    }

    private fun seedToday() {
        prefs().edit()
            .putString("widget_tasbih_last_active_date", TasbihGlanceWidgetReceiver.todayKey())
            .apply()
    }

    // ── Receiver: the anti-tamper sender guard ─────────────────────────────

    @Test
    fun `foreign tap broadcast without package is dropped before any state changes`() {
        receive(
            Intent(TasbihTapEngine.ACTION_INCREMENT).putExtra("appWidgetId", 7),
        )
        assertEquals(0, prefs().getInt("tasbih_count", 0))
        assertTrue(events().isEmpty())
        assertTrue(logsContain("dropped foreign tasbih broadcast from: null"))
    }

    // ── Receiver: the goAsync tap path via a real sendBroadcast ────────────

    @Test
    fun `own package tap broadcast counts the bead`() {
        broadcast(
            Intent(TasbihTapEngine.ACTION_INCREMENT).putExtra("appWidgetId", 7),
        )
        // The count write and the event append are two separate prefs writes
        // from the tap thread — await BOTH, or the poll can catch the window
        // between them (flaked once: count==1 with an empty queue).
        awaitTrue { prefs().getInt("tasbih_count", 0) == 1 && events().isNotEmpty() }
        assertEquals(1, counts()[0])
        val evs = events()
        assertEquals(1, evs.size)
        assertEquals("inc", evs[0]["k"])
        assertEquals(0, eventInt(evs[0], "z"))
        assertEquals(1, eventInt(evs[0], "d"))
        assertEquals(1, eventInt(evs[0], "s"))
    }

    // ── Engine: the cycle boundary ────────────────────────────────────────

    @Test
    fun `closing a cycle is reported and the count CONTINUES by default`() {
        seedToday()
        prefs().edit().putString("tasbih_per_zikr_targets", "[2,3,3,3,3,3,3]").apply()
        seedCounts(0 to 1)

        val closing = TasbihTapEngine.applyTap(context, TasbihTapEngine.ACTION_INCREMENT, "t-cycle")
        assertTrue(closing.applied)
        assertTrue(closing.cycleComplete)
        assertEquals(2, closing.count)

        // The 2026-11 brief flips the default to «ادامه شمارش»: the round is
        // reported (cycleComplete, for the haptic pulse) and the counter keeps
        // climbing past the target — the user moves on themselves.
        val next = TasbihTapEngine.applyTap(context, TasbihTapEngine.ACTION_INCREMENT, "t-cycle")
        assertEquals(0, next.zikrIndex)
        assertEquals(3, next.count)
        assertEquals(3, counts()[0])
    }

    @Test
    fun `auto advance is the opt-in that hands the next tap to the next zikr`() {
        seedToday()
        prefs().edit()
            .putString("tasbih_per_zikr_targets", "[2,3,3,3,3,3,3]")
            .putBoolean("tasbih_auto_advance", true)
            .apply()
        seedCounts(0 to 1)

        val closing = TasbihTapEngine.applyTap(context, TasbihTapEngine.ACTION_INCREMENT, "t-adv")
        assertTrue(closing.cycleComplete)
        assertEquals(2, closing.count)

        val next = TasbihTapEngine.applyTap(context, TasbihTapEngine.ACTION_INCREMENT, "t-adv")
        assertEquals(1, next.zikrIndex)
        assertEquals(0, prefs().getInt("tasbih_count", 0))
        assertEquals(2, counts()[0])
    }

    @Test
    fun `a small target keeps counting with the default`() {
        seedToday()
        prefs().edit()
            .putString("tasbih_per_zikr_targets", "[2,3,3,3,3,3,3]")
            .putBoolean("tasbih_auto_advance", false)
            .apply()
        seedCounts(0 to 2)

        val result = TasbihTapEngine.applyTap(context, TasbihTapEngine.ACTION_INCREMENT, "t-noadv")
        assertEquals(0, result.zikrIndex)
        assertEquals(3, result.count)
    }

    // ── Engine: increment ──────────────────────────────────────────────────

    @Test
    fun `increment counts twice and queues one inc event per tap`() {
        TasbihTapEngine.applyTap(context, TasbihTapEngine.ACTION_INCREMENT, "t-inc")
        TasbihTapEngine.applyTap(context, TasbihTapEngine.ACTION_INCREMENT, "t-inc")

        assertEquals(2, prefs().getInt("tasbih_count", 0))
        assertEquals(2, counts()[0])
        assertEquals(2, prefs().getInt("widget_tasbih_daily_total", 0))
        assertEquals(
            TasbihGlanceWidgetReceiver.todayKey(),
            prefs().getString("widget_tasbih_daily_date", null),
        )
        assertTrue(prefs().getLong("widget_tasbih_last_tap_at", 0L) > 0L)

        val evs = events()
        assertEquals(2, evs.size)
        assertEquals(1, eventInt(evs[0], "s"))
        assertEquals(2, eventInt(evs[1], "s"))
        evs.forEach {
            assertEquals("inc", it["k"])
            assertEquals(0, eventInt(it, "z"))
            assertEquals(1, eventInt(it, "d"))
        }
    }

    // ── Engine: the two-tap reset confirm window ───────────────────────────

    @Test
    fun `reset needs two taps within the confirm window`() {
        seedCounts(0 to 4)
        prefs().edit().putInt("tasbih_count", 4).apply()
        seedToday()
        val key = "t-reset"

        TasbihTapEngine.applyTap(context, TasbihTapEngine.ACTION_RESET, key)
        assertTrue(TasbihTapEngine.isConfirming(key))
        assertEquals(4, counts()[0])
        assertEquals(4, prefs().getInt("tasbih_count", 0))
        assertTrue(events().isEmpty())

        TasbihTapEngine.applyTap(context, TasbihTapEngine.ACTION_RESET, key)
        assertFalse(TasbihTapEngine.isConfirming(key))
        assertEquals(0, counts()[0])
        assertEquals(0, prefs().getInt("tasbih_count", 0))
        val evs = events()
        assertEquals(1, evs.size)
        assertEquals("reset", evs[0]["k"])
        assertEquals(0, eventInt(evs[0], "z"))
    }

    @Test
    fun `increment cancels the reset confirm window`() {
        seedCounts(0 to 4)
        prefs().edit().putInt("tasbih_count", 4).apply()
        seedToday()
        val key = "t-cancel"

        TasbihTapEngine.applyTap(context, TasbihTapEngine.ACTION_RESET, key)
        assertTrue(TasbihTapEngine.isConfirming(key))

        TasbihTapEngine.applyTap(context, TasbihTapEngine.ACTION_INCREMENT, key)
        assertFalse(TasbihTapEngine.isConfirming(key))
        assertEquals(5, counts()[0])
        assertEquals(5, prefs().getInt("tasbih_count", 0))
        val evs = events()
        assertEquals(1, evs.size)
        assertEquals("inc", evs[0]["k"])
    }

    // ── Engine: the zikr switch wraps at both ends ─────────────────────────

    @Test
    fun `zikr switch walks forward and wraps at both ends`() {
        seedToday()
        val key = "t-zikr"
        val list = TasbihGlanceWidgetReceiver.getZikrList(prefs())
        assertTrue(list.size >= 3)
        val last = list.size - 1

        TasbihTapEngine.applyTap(context, TasbihTapEngine.ACTION_NEXT_ZIKR, key)
        assertEquals(1, prefs().getInt("tasbih_zikr_index", -1))
        assertEquals(list[1], prefs().getString("tasbih_dhikr", null))
        assertEquals(0, prefs().getInt("tasbih_count", 0))

        TasbihTapEngine.applyTap(context, TasbihTapEngine.ACTION_PREV_ZIKR, key)
        assertEquals(0, prefs().getInt("tasbih_zikr_index", -1))

        TasbihTapEngine.applyTap(context, TasbihTapEngine.ACTION_PREV_ZIKR, key)
        assertEquals(last, prefs().getInt("tasbih_zikr_index", -1))
        assertEquals(list[last], prefs().getString("tasbih_dhikr", null))

        TasbihTapEngine.applyTap(context, TasbihTapEngine.ACTION_NEXT_ZIKR, key)
        assertEquals(0, prefs().getInt("tasbih_zikr_index", -1))

        val evs = events()
        assertEquals(listOf(1, 0, last, 0), evs.map { eventInt(it, "z") })
        evs.forEach { assertEquals("zikr", it["k"]) }
    }

    // ── Engine: the new-day reset leads the tap ────────────────────────────

    @Test
    fun `first tap of a new day resets yesterday's tally first`() {
        prefs().edit().putString("widget_tasbih_last_active_date", "2000-01-01").apply()
        seedCounts(0 to 5)
        prefs().edit().putInt("tasbih_count", 5).apply()

        TasbihTapEngine.applyTap(context, TasbihTapEngine.ACTION_INCREMENT, "t-day")

        assertEquals(
            TasbihGlanceWidgetReceiver.todayKey(),
            prefs().getString("widget_tasbih_last_active_date", null),
        )
        assertEquals(1, counts()[0])
        assertEquals(1, prefs().getInt("tasbih_count", 0))
        val evs = events()
        assertEquals(2, evs.size)
        assertEquals("reset", evs[0]["k"])
        assertEquals(-1, eventInt(evs[0], "z"))
        assertEquals(1, eventInt(evs[0], "s"))
        assertEquals("inc", evs[1]["k"])
        assertEquals(0, eventInt(evs[1], "z"))
        assertEquals(2, eventInt(evs[1], "s"))
    }

    // ── Event queue: append / prune / collapse ─────────────────────────────

    @Test
    fun `event queue round trip and prune`() {
        val p = prefs()
        TasbihGlanceWidgetReceiver.appendEvent(p, TasbihGlanceWidgetReceiver.EVENT_INC, 0, 1)
        TasbihGlanceWidgetReceiver.appendEvent(p, TasbihGlanceWidgetReceiver.EVENT_RESET, 2)

        val evs = TasbihGlanceWidgetReceiver.plainEvents(p)
        assertEquals(2, evs.size)
        assertEquals(1, eventInt(evs[0], "s"))
        assertEquals("inc", evs[0]["k"])
        assertEquals(0, eventInt(evs[0], "z"))
        assertEquals(1, eventInt(evs[0], "d"))
        assertEquals(2, eventInt(evs[1], "s"))
        assertEquals("reset", evs[1]["k"])
        assertEquals(2, eventInt(evs[1], "z"))
        assertEquals(2, p.getInt(TasbihGlanceWidgetReceiver.KEY_PENDING_SEQ, 0))

        TasbihGlanceWidgetReceiver.prunePending(p, 1)
        val pruned = TasbihGlanceWidgetReceiver.plainEvents(p)
        assertEquals(1, pruned.size)
        assertEquals(2, eventInt(pruned[0], "s"))
    }

    @Test
    fun `queue collapses to one full-state event after 300 appends`() {
        seedCounts(0 to 5, 1 to 3)
        seedToday()
        val p = prefs()

        repeat(301) {
            TasbihGlanceWidgetReceiver.appendEvent(p, TasbihGlanceWidgetReceiver.EVENT_INC, 0, 1)
        }

        val evs = TasbihGlanceWidgetReceiver.plainEvents(p)
        assertEquals(1, evs.size)
        assertEquals(301, eventInt(evs[0], "s"))
        assertEquals("full", evs[0]["k"])
        val c = evs[0]["c"] as Map<*, *>
        assertEquals(5, (c["0"] as Number).toInt())
        assertEquals(3, (c["1"] as Number).toInt())
    }

    // ── The trampoline activity (the real tap path) ────────────────────────

    @Test
    fun `trampoline applies the tap and finishes when the paint lands`() {
        val controller = Robolectric.buildActivity(
            TasbihActionActivity::class.java,
            TasbihActionActivity.intent(context, TasbihTapEngine.ACTION_INCREMENT, "tasbih"),
        ).setup()

        // The tap is applied inline during onCreate — before any async work.
        assertEquals(1, prefs().getInt("tasbih_count", 0))
        assertEquals(1, counts()[0])

        awaitTrue { controller.get().isFinishing }
        // The intent is consumed so a stale redelivery can never re-count.
        assertNull(controller.get().intent.getStringExtra(EXTRA_ACTION))
        assertTrue(logsContain("tap action=com.tawheeed.TASBIH_INCREMENT widget=tasbih"))
    }

    @Test
    fun `trampoline ignores an actionless intent`() {
        val controller = Robolectric.buildActivity(
            TasbihActionActivity::class.java,
            Intent(context, TasbihActionActivity::class.java),
        ).setup()

        assertEquals(0, prefs().getInt("tasbih_count", 0))
        assertTrue(controller.get().isFinishing)
        assertTrue(logsContain("tap with no action"))
    }

    companion object {
        private const val TAG = "TasbihWidget"

        // The extra is a private const in the activity; the literal is pinned
        // here once.
        private const val EXTRA_ACTION = "com.tawheeed.TASBIH_EXTRA_ACTION"
    }
}
