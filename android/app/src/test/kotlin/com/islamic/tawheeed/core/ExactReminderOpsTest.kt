package com.islamic.tawheeed.core

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pure JVM coverage for the batched reminder channel: [ExactReminderScheduler.decodeOps]
 * turns ONE Dart list into ops without ever aborting a batch, and
 * [ExactReminderScheduler.isArmCurrent] decides whether an alarm described by the
 * stored spec still exists — the check that makes a repeated launch free instead
 * of re-arming 27 alarms on the platform thread eight times over.
 *
 * Both are Context-free on purpose, which is why they are testable at all: the
 * arming itself needs AlarmManager and only runs on a device.
 */
class ExactReminderOpsTest {

    private val day = 86_400_000L

    private fun armEntry(
        id: Int = 4100,
        timeMillis: Long = 5_000_000L,
        title: String = "یادآوری قرآن",
        body: String = "یک صفحه بخوانید",
        channelId: String? = "quran",
        sound: String? = null,
        payload: String? = null,
        repeatDailyMillis: Long? = null,
    ): JSONObject = JSONObject().apply {
        put("type", "arm")
        put("id", id)
        put("timeMillis", timeMillis)
        put("title", title)
        put("body", body)
        if (channelId != null) put("channelId", channelId)
        if (sound != null) put("sound", sound)
        if (payload != null) put("payload", payload)
        if (repeatDailyMillis != null) put("repeatDailyMillis", repeatDailyMillis)
    }

    private fun request(
        trigger: Long = 5_000_000L,
        title: String = "یادآوری قرآن",
        body: String = "یک صفحه بخوانید",
        channel: String = "quran",
        sound: String? = null,
        payload: String? = null,
        repeatDailyMillis: Long? = null,
    ) = ReminderRequest(
        id = 4100,
        triggerTimeMillis = trigger,
        title = title,
        body = body,
        channelId = channel,
        sound = sound,
        payload = payload,
        repeatDailyMillis = repeatDailyMillis,
    )

    /** Exactly what [ExactReminderScheduler.persist] writes for [request]. */
    private fun spec(
        request: ReminderRequest,
        armedAt: Long,
    ): JSONObject = JSONObject().apply {
        put("trigger", request.triggerTimeMillis)
        put("title", request.title)
        put("body", request.body)
        put("channel", request.channelId)
        put("sound", request.sound ?: "")
        put("payload", request.payload ?: "")
        request.repeatDailyMillis?.let { put("repeat_daily", it) }
        put("armed_at", armedAt)
    }

    // --- decodeOps: the wire format -----------------------------------------

    @Test
    fun `reads every op type in the order sent`() {
        val ops = JSONArray().apply {
            put(armEntry(id = 4100, timeMillis = 11L))
            put(JSONObject().apply {
                put("type", "cancel"); put("id", 4101)
            })
            put(JSONObject().apply {
                put("type", "cancelRange"); put("startId", 5000); put("endId", 5100)
            })
            put(armEntry(id = 4102, timeMillis = 12L, repeatDailyMillis = day))
        }
        val (parsed, dropped) = ExactReminderScheduler.decodeOps(ops.toString())
        assertEquals(0, dropped)
        assertEquals(4, parsed.size)

        val first = (parsed[0] as ReminderOp.Arm).request
        assertEquals(4100, first.id)
        assertEquals(11L, first.triggerTimeMillis)
        assertEquals("یادآوری قرآن", first.title)
        assertEquals("quran", first.channelId)
        assertNull(first.sound)
        assertNull(first.repeatDailyMillis)
        assertEquals(4101, (parsed[1] as ReminderOp.Cancel).id)
        assertEquals(5000, (parsed[2] as ReminderOp.CancelRange).startId)
        assertEquals(5100, (parsed[2] as ReminderOp.CancelRange).endId)
        assertEquals(day, (parsed[3] as ReminderOp.Arm).request.repeatDailyMillis)
    }

    @Test
    fun `one malformed entry is dropped without losing the rest of the batch`() {
        val ops = JSONArray().apply {
            put(armEntry(id = 4100))
            // No title/body: ReminderReceiver could only post an empty card.
            put(JSONObject().apply { put("type", "arm"); put("id", 1); put("timeMillis", 2L) })
            // cancel with no id
            put(JSONObject().apply { put("type", "cancel") })
            // cancelRange missing endId
            put(JSONObject().apply { put("type", "cancelRange"); put("startId", 1) })
            // unknown type
            put(JSONObject().apply { put("type", "somethingElse"); put("id", 7) })
            put(armEntry(id = 4105))
        }
        val (parsed, dropped) = ExactReminderScheduler.decodeOps(ops.toString())
        assertEquals(2, parsed.size)
        assertEquals(4100, (parsed[0] as ReminderOp.Arm).request.id)
        assertEquals(4105, (parsed[1] as ReminderOp.Arm).request.id)
        assertEquals(4, dropped)
    }

    @Test
    fun `an unparseable payload is reported, never thrown`() {
        // A batch is armed while the app is starting: an exception here would
        // surface on the UI thread and take the whole pass with it.
        val (parsed, dropped) = ExactReminderScheduler.decodeOps("{not json")
        assertTrue(parsed.isEmpty())
        assertEquals(1, dropped)
    }

    @Test
    fun `empty and null batches decode to nothing`() {
        assertEquals(0, ExactReminderScheduler.decodeOps(null).first.size)
        assertEquals(0, ExactReminderScheduler.decodeOps(null).second)
        assertEquals(0, ExactReminderScheduler.decodeOps("").first.size)
        assertEquals(0, ExactReminderScheduler.decodeOps("[]").first.size)
    }

    @Test
    fun `defaults and blank fields survive the round trip`() {
        val ops = JSONArray().apply {
            put(armEntry(channelId = null, sound = "", payload = null))
        }
        val req = (ExactReminderScheduler.decodeOps(ops.toString()).first.single()
                as ReminderOp.Arm).request
        // A reminder with no channel of its own belongs to the general channel.
        assertEquals("general", req.channelId)
        // An empty sound means "no override", not the file named "".
        assertNull(req.sound)
        assertNull(req.payload)
    }

    // --- isArmCurrent: the idempotence gate ---------------------------------

    @Test
    fun `a future alarm armed during this boot is already current`() {
        val now = 1_000_000L
        val req = request()
        assertTrue(
            ExactReminderScheduler.isArmCurrent(spec(req, armedAt = now - 1000), req, now, now - 50_000)
        )
    }

    @Test
    fun `an alarm whose time has passed is never current`() {
        val now = 1_000_000L
        val req = request(trigger = now - 1)
        assertFalse(ExactReminderScheduler.isArmCurrent(spec(req, now - 5000), req, now, 0L))
    }

    @Test
    fun `an arm from before this boot is not current — AlarmManager wiped it`() {
        // The reboot case is the dangerous one: trusting the stamp would leave
        // every reminder silently disarmed until the fingerprint next changed.
        val now = 1_000_000L
        val req = request()
        val armedBeforeReboot = now - 60_000
        val bootedAfterThat = now - 10_000
        assertFalse(
            ExactReminderScheduler.isArmCurrent(
                spec(req, armedBeforeReboot), req, now, bootedAfterThat
            )
        )
        // With no boot time available the check cannot say anything, so the
        // stamp is honoured rather than the batch being re-armed forever.
        assertTrue(ExactReminderScheduler.isArmCurrent(spec(req, armedBeforeReboot), req, now, 0L))
    }

    @Test
    fun `a stamp older than the fresh window is not trusted`() {
        val now = 1_000_000_000L
        val req = request(trigger = now + day)
        // Reinstall / OEM task-force-stop: past the window the alarm may be gone.
        assertFalse(
            ExactReminderScheduler.isArmCurrent(
                spec(req, armedAt = now - 7L * 60 * 60 * 1000), req, now, 0L
            )
        )
        assertTrue(
            ExactReminderScheduler.isArmCurrent(
                spec(req, armedAt = now - 5L * 60 * 60 * 1000), req, now, 0L
            )
        )
    }

    @Test
    fun `every field that changes what the user sees defeats the stamp`() {
        val now = 1_000_000L
        val base = request()
        val stored = spec(base, now - 1000)
        val changed = mapOf(
            "time" to base.copy(triggerTimeMillis = base.triggerTimeMillis + 60_000),
            "title" to base.copy(title = "اذان صبح"),
            "body" to base.copy(body = "بدون متن"),
            "channel" to base.copy(channelId = "adhkar"),
            "sound" to base.copy(sound = "kamel.mp3"),
            "payload" to base.copy(payload = "verse:2:255"),
            "repeat" to base.copy(repeatDailyMillis = day),
        )
        for ((name, req) in changed) {
            assertFalse("$name must force a re-arm", ExactReminderScheduler.isArmCurrent(stored, req, now, 0L))
        }
    }

    @Test
    fun `a spec written by the old version without a stamp is re-armed once`() {
        val now = 1_000_000L
        val req = request()
        val legacy = spec(req, -1L)
        assertFalse(ExactReminderScheduler.isArmCurrent(legacy, req, now, 0L))
    }

    @Test
    fun `blank and absent sound and payload describe the same alarm`() {
        // Otherwise the first pass after upgrading would re-arm the whole queue
        // once for the "" / null difference alone.
        val now = 1_000_000L
        val req = request(sound = null, payload = null)
        val stored = JSONObject().apply {
            put("trigger", req.triggerTimeMillis)
            put("title", req.title)
            put("body", req.body)
            put("channel", req.channelId)
            put("sound", "")
            put("payload", "")
            put("armed_at", now - 1000)
        }
        assertTrue(ExactReminderScheduler.isArmCurrent(stored, req, now, 0L))
    }
}
