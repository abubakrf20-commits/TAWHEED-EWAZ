package com.islamic.tawheeed.core

import org.json.JSONArray
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pure JVM coverage for the boot/rollover restore path of the native azan
 * alarms: which persisted alarms survive the "future only" filter. A bug here
 * silently drops every adhan after a reboot, so the filter is pinned by tests.
 */
class ExactAlarmRegistryTest {

    private fun obj(id: Int, timeMillis: Long?): org.json.JSONObject {
        val o = org.json.JSONObject()
        o.put("id", id)
        o.put("prayer", "اذان ظهر")
        if (timeMillis != null) o.put("timeMillis", timeMillis)
        return o
    }

    @Test
    fun `keeps only alarms after now`() {
        val now = 1_000_000L
        val input = JSONArray().apply {
            put(obj(2000, now - 5_000))
            put(obj(2100, now + 5_000))
            put(obj(2200, now + 60_000))
        }
        val out = ExactAlarmHelper.filterFutureAlarms(input.toString(), now)
        assertEquals(2, out.length())
        assertEquals(2100, out.getJSONObject(0).getInt("id"))
        assertEquals(2200, out.getJSONObject(1).getInt("id"))
    }

    @Test
    fun `drops entries without a usable timestamp instead of aborting`() {
        val now = 1_000_000L
        val input = JSONArray().apply {
            put(org.json.JSONObject().put("id", 2000).put("timeMillis", "not-a-number"))
            put(obj(2100, now + 1_000))
            put(org.json.JSONObject().put("prayer", "no time field"))
        }
        val out = ExactAlarmHelper.filterFutureAlarms(input.toString(), now)
        assertEquals(1, out.length())
        assertEquals(2100, out.getJSONObject(0).getInt("id"))
    }

    @Test
    fun `a corrupt registry string degrades to nothing instead of throwing`() {
        // org.json cannot recover entries from a syntactically invalid array;
        // the requirement is only that the restore survives it gracefully.
        val out = ExactAlarmHelper.filterFutureAlarms("[not json at all", 1_000L)
        assertEquals(0, out.length())
    }

    @Test
    fun `empty registry filters to an empty array`() {
        val out = ExactAlarmHelper.filterFutureAlarms("[]", 1_000_000L)
        assertTrue(out.length() == 0)
    }

    @Test
    fun `alarm exactly at now is dropped (already fired)`() {
        val now = 1_000_000L
        val input = JSONArray().apply { put(obj(2000, now)) }
        val out = ExactAlarmHelper.filterFutureAlarms(input.toString(), now)
        assertEquals(0, out.length())
    }
}
