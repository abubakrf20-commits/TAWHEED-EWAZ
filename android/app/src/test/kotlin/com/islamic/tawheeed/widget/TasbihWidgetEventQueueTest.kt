package com.islamic.tawheeed.widget

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Guards the widget→app tap queue crossing the Flutter method channel.
 *
 *  StandardMessageCodec cannot encode org.json values: a reply containing a
 *  JSONObject fails the WHOLE reply with «Unsupported value: '{...}' of type
 *  'class org.json.JSONObject'» — found on-device 2026-10-16, where every
 *  `getTasbihData` failed, the drain never ran and 119 taps sat in the queue
 *  for days. plainEvents() must hand back only Map/List/String/Number/
 *  Boolean/null. */
class TasbihWidgetEventQueueTest {

    @Test
    fun plainEvents_convertsEveryEventToPlainTypes() {
        val queue = JSONArray()
            .put(JSONObject().put("s", 1).put("k", "inc").put("z", 7).put("d", 1))
            .put(JSONObject().put("s", 2).put("k", "zikr").put("z", 0))
            .put(
                JSONObject()
                    .put("s", 3)
                    .put("k", "full")
                    .put("c", JSONObject().put("0", 2).put("7", 9))
            )
            .put(JSONObject().put("s", 4).put("k", "reset").put("z", -1))

        val events = TasbihGlanceWidgetReceiver.plainEvents(queue)

        assertEquals(4, events.size)
        assertEquals(mapOf("s" to 1, "k" to "inc", "z" to 7, "d" to 1), events[0])
        assertEquals("zikr", events[1]["k"])
        // The full event's committed per-zikr object must be a plain map too.
        assertEquals(mapOf("0" to 2, "7" to 9), events[2]["c"])
        assertEquals(-1, (events[3]["z"] as Number).toInt())

        // The contract the on-device failure violated: nothing org.json may
        // remain anywhere in the tree.
        for (event in events) assertCodecEncodable(event)
    }

    @Test
    fun plainEvents_skipsNonObjectEntries() {
        val queue = JSONArray().put(JSONObject().put("s", 1).put("k", "inc"))
        queue.put("corrupt")
        assertEquals(1, TasbihGlanceWidgetReceiver.plainEvents(queue).size)
    }

    @Test
    fun plainEvents_emptyQueueStaysEmpty() {
        assertTrue(TasbihGlanceWidgetReceiver.plainEvents(JSONArray()).isEmpty())
    }

    /** StandardMessageCodec's writeValue allow-list — anything else fails the
     *  whole reply. */
    private fun assertCodecEncodable(value: Any?) {
        when (value) {
            null, is String, is Boolean, is Number -> Unit
            is List<*> -> value.forEach { assertCodecEncodable(it) }
            is Map<*, *> -> {
                for ((key, item) in value) {
                    assertTrue(
                        "map keys must be strings, got ${key?.let { it::class.java.name }}",
                        key is String
                    )
                    assertCodecEncodable(item)
                }
            }
            else -> throw AssertionError(
                "not codec-encodable: ${value::class.java.name} = $value"
            )
        }
    }
}
