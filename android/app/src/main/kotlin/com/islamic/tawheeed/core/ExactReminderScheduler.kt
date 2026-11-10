package com.islamic.tawheeed.core

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.SystemClock
import android.util.Log
import org.json.JSONObject

/**
 * Arms native exact alarms that deliver time-sensitive reminders on time even
 * under aggressive OEM Doze (Xiaomi MIUI, Samsung, …). It mirrors the azan
 * path: prefer [AlarmManager.setAlarmClock] (the most Doze/OEM-friendly exact
 * alarm), falling back to [AlarmManager.setExactAndAllowWhileIdle] when that
 * throws. NOTE: both calls require SCHEDULE_EXACT_ALARM on Android 12+ and that
 * grant is denied by default from Android 14 for newly installed apps — when it
 * is missing NOTHING can be armed exactly here, so callers must surface the
 * degraded state (the Dart side arms an inexact plugin fallback for that case).
 *
 * setAlarmClock is what the prayer path uses (ExactAlarmHelper / 
 * PrayerAlarmScheduler), and OEMs (especially MIUI) defer even 
 * setExactAndAllowWhileIdle for backgrounded apps, which was the root cause
 * of late reminders. ReminderReceiver posts the notification with the same
 * id/channel the Flutter plugin would have used.
 */
object ExactReminderScheduler {
    private const val TAG = "ExactReminderScheduler"

    /** Namespace so native watchdog ids never collide with Flutter plugin ids. */
    private const val ID_OFFSET = 2_000_000

    private const val PREFS = "exact_reminder_prefs"

    /**
     * How long a persisted spec may vouch for "this exact alarm is already armed"
     * before we re-arm it. An AlarmManager alarm does not survive an app
     * reinstall or an OEM task-force-stop, so the stamp must expire long before
     * the reminder itself is due — a few hours of skipping re-arms is still safe,
     * a day is not. (Reboots are handled separately and exactly, by
     * [isArmCurrent]'s boot-time comparison.)
     */
    private const val ARM_FRESH_MS = 6L * 60 * 60 * 1000

    fun canUseExact(context: Context): Boolean {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return try {
            am.canScheduleExactAlarms()
        } catch (_: Throwable) {
            false
        }
    }

    /**
     * Persists the reminder content and arms an exact alarm. [repeatDailyMillis]
     * re-arms the same reminder daily from [triggerTimeMillis] (for repeating
     * reminders the caller must pass the UTC epoch of the *next* occurrence).
     *
     * Always arms — this is the self-heal entry point the boot receivers and
     * [ReminderReceiver] roll-forward path use, where skipping would silently
     * drop the alarm. The Flutter side batches through [applyOps], which
     * re-arms only when the stored spec does not already describe this alarm.
     */
    fun schedule(
        context: Context,
        id: Int,
        triggerTimeMillis: Long,
        title: String,
        body: String,
        channelId: String,
        sound: String?,
        payload: String?,
        repeatDailyMillis: Long?,
    ) {
        arm(
            context,
            ReminderRequest(
                id, triggerTimeMillis, title, body, channelId, sound, payload, repeatDailyMillis
            ),
            force = true,
        )
    }

    /**
     * Applies a decoded batch in one call: the whole per-launch reschedule storm
     * (previously hundreds of awaited method-channel round trips, each doing
     * binder work on the Android main thread) collapses into a handful of batch
     * calls that run on the caller's worker thread.
     *
     * Returns counts so the Dart side can log what actually happened; a dropped
     * count above zero means the payload was malformed and is reported loudly.
     */
    fun applyOps(context: Context, opsJson: String?): Map<String, Int> {
        val (ops, dropped) = decodeOps(opsJson)
        var armed = 0
        var unchanged = 0
        var failed = 0
        var cancelOps = 0
        for (op in ops) {
            when (op) {
                is ReminderOp.Arm ->
                    when (arm(context, op.request, force = false)) {
                        ArmResult.Armed -> armed++
                        ArmResult.AlreadyCurrent -> unchanged++
                        ArmResult.Failed -> failed++
                    }
                is ReminderOp.Cancel -> {
                    cancel(context, op.id)
                    cancelOps++
                }
                is ReminderOp.CancelRange -> {
                    cancelRange(context, op.startId, op.endId)
                    cancelOps++
                }
            }
        }
        if (dropped > 0) {
            Log.w(TAG, "applyOps dropped $dropped malformed ops of ${ops.size + dropped}")
        }
        if (failed > 0) {
            Log.e(TAG, "applyOps could not arm $failed reminder(s) — exact-alarm grant missing?")
        }
        Log.d(TAG, "applyOps: $armed armed, $unchanged already current, $cancelOps cancel ops")
        return mapOf(
            "armed" to armed,
            "unchanged" to unchanged,
            "failed" to failed,
            "cancelOps" to cancelOps,
        )
    }

    /**
     * Parses the wire format into ops, skipping (never throwing on) anything
     * unusable so one bad entry cannot abort a whole batch. Pure — JVM-tested.
     */
    fun decodeOps(opsJson: String?): Pair<List<ReminderOp>, Int> {
        val out = ArrayList<ReminderOp>()
        var dropped = 0
        if (opsJson.isNullOrEmpty()) return out to 0
        val arr = try {
            org.json.JSONArray(opsJson)
        } catch (e: Exception) {
            Log.w(TAG, "applyOps got unparseable batch payload: ${e.message}")
            return out to 1
        }
        for (i in 0 until arr.length()) {
            val obj = arr.optJSONObject(i)
            val type = obj?.optString("type", "")
            val id = obj?.opt("id") as? Number
            when (type) {
                "arm" -> {
                    val req = obj?.let { requestFrom(it) }
                    if (req == null) dropped++ else out.add(ReminderOp.Arm(req))
                }
                "cancel" ->
                    if (id == null) dropped++ else out.add(ReminderOp.Cancel(id.toInt()))
                "cancelRange" -> {
                    val s = obj?.opt("startId") as? Number
                    val e = obj?.opt("endId") as? Number
                    if (s == null || e == null) dropped++
                    else out.add(ReminderOp.CancelRange(s.toInt(), e.toInt()))
                }
                else -> dropped++
            }
        }
        return out to dropped
    }

    /**
     * True when [stored] is the spec written for exactly this request, its alarm
     * is still in the future and the stamp is trustworthy — i.e. arming again
     * would be pure binder traffic. Field-by-field: JSONObject.toString()
     * ordering is HashMap-backed, so a string comparison would flake.
     *
     * [bootTimeMillis] (wall clock of the current boot, 0 when unknown) is what
     * makes the stamp honest: AlarmManager clears every alarm on reboot, so an
     * arm that predates this boot does not exist no matter how fresh its stamp
     * looks. Without that check a reboot the receivers somehow missed (a killed
     * process, a blocked BOOT_COMPLETED) would leave the reminders disarmed and
     * the app refusing to re-arm them. Pure — JVM-tested.
     */
    fun isArmCurrent(
        stored: JSONObject,
        request: ReminderRequest,
        now: Long,
        bootTimeMillis: Long,
    ): Boolean {
        if (request.triggerTimeMillis <= now) return false
        val armedAt = stored.optLong("armed_at", -1L)
        if (armedAt < 0L) return false
        if (now - armedAt > ARM_FRESH_MS) return false
        if (bootTimeMillis > 0L && armedAt < bootTimeMillis) return false
        if (stored.optLong("trigger", -1L) != request.triggerTimeMillis) return false
        if (stored.optString("title", "") != request.title) return false
        if (stored.optString("body", "") != request.body) return false
        if (stored.optString("channel", "") != request.channelId) return false
        if (stored.optString("sound", "") != (request.sound ?: "")) return false
        if (stored.optString("payload", "") != (request.payload ?: "")) return false
        return stored.optLong("repeat_daily", -1L) == (request.repeatDailyMillis ?: -1L)
    }

    /**
     * The real arm. [force] false is the idempotent path: a current spec is left
     * alone. Persisting before arming is deliberate — a spec with no alarm behind
     * it only ever re-arms on the next pass, while an alarm with no spec would
     * post a title-less notification at fire time.
     *
     * There is no `am.cancel()` before arming: the PendingIntent is keyed by
     * `ID_OFFSET + id`, so `setAlarmClock` replaces whatever that id held. The
     * one case that DOES need a cancel is a failed arm — without it the previous
     * alarm would stay armed and fire with the OLD time or text, which is exactly
     * the kind of inaccuracy the replacing optimisation must never introduce.
     */
    private fun arm(context: Context, request: ReminderRequest, force: Boolean): ArmResult {
        val now = System.currentTimeMillis()
        if (!force) {
            val stored = load(context, request.id)
            if (stored != null && isArmCurrent(stored, request, now, bootTimeMillis(now))) {
                return ArmResult.AlreadyCurrent
            }
        }
        persist(context, request, now)

        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            action = "com.tawheeed.action.REMINDER_ALARM"
            putExtra("id", request.id)
        }
        val pi = PendingIntent.getBroadcast(
            context,
            ID_OFFSET + request.id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        var failure: Exception? = null
        try {
            // setAlarmClock() first — the most Doze/OEM-friendly exact alarm. It
            // still requires SCHEDULE_EXACT_ALARM on Android 12+ (denied by
            // default from Android 14 for fresh installs); the nested fallback
            // below covers that case without escaping the receiver.
            val info = AlarmManager.AlarmClockInfo(request.triggerTimeMillis, null)
            am.setAlarmClock(info, pi)
            Log.d(TAG, "Reminder ${request.id} scheduled via setAlarmClock @ ${request.triggerTimeMillis}")
        } catch (e: SecurityException) {
            Log.w(TAG, "setAlarmClock failed for ${request.id} — using setExactAndAllowWhileIdle")
            try {
                am.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, request.triggerTimeMillis, pi
                )
            } catch (e2: Exception) {
                failure = e2
                Log.e(TAG, "setExactAndAllowWhileIdle fallback failed too: ${e2.message}")
            }
        } catch (e: Exception) {
            failure = e
            Log.e(TAG, "Could not schedule reminder ${request.id}: ${e.message}")
        }
        if (failure != null) {
            // Nothing is armed for this id now. Purge the spec we just wrote so
            // the next pass re-arms it instead of treating it as current, and so
            // no leftover alarm from the previous arm can fire wrongly.
            cancel(context, request.id)
            return ArmResult.Failed
        }
        return ArmResult.Armed
    }

    /** An arm stamped before this wall clock cannot exist any more. */
    private fun bootTimeMillis(now: Long): Long {
        val up = try {
            SystemClock.elapsedRealtime()
        } catch (_: Throwable) {
            0L
        }
        return if (up <= 0L) 0L else now - up
    }

    private fun requestFrom(obj: JSONObject): ReminderRequest? {
        val id = obj.opt("id") as? Number ?: return null
        val trigger = obj.opt("timeMillis") as? Number ?: return null
        if (!obj.has("title") || !obj.has("body")) return null
        val repeat = obj.opt("repeatDailyMillis") as? Number
        return ReminderRequest(
            id = id.toInt(),
            triggerTimeMillis = trigger.toLong(),
            title = obj.optString("title", ""),
            body = obj.optString("body", ""),
            channelId = obj.optString("channelId", "general"),
            sound = (obj.opt("sound") as? String)?.ifEmpty { null },
            payload = obj.opt("payload") as? String,
            repeatDailyMillis = repeat?.toLong(),
        )
    }

    /**
     * Re-arms every persisted reminder after a reboot / timezone change so
     * native fallback notifications survive without the app being opened (the
     * Flutter plugin restores its own schedules, but native setAlarmClock is
     * volatile). One-shot reminders that have already passed are dropped;
     * repeating ones are rolled forward to the next occurrence from [now].
     */
    fun rescheduleAllAfterBoot(context: Context, now: Long = System.currentTimeMillis()) {
        val prefs = prefs(context)
        val all = prefs.all.keys
            .filter { it.startsWith("rem_") }
            .mapNotNull { key -> prefs.getString(key, null)?.let { raw -> key to raw } }
        for ((key, raw) in all) {
            val id = key.removePrefix("rem_").toIntOrNull() ?: continue
            val spec = try {
                JSONObject(raw)
            } catch (e: Exception) {
                Log.w(TAG, "Corrupt reminder $id on boot: ${e.message}")
                continue
            }
            val originalTrigger = spec.optLong("trigger", -1)
            val repeat = spec.optLong("repeat_daily", -1)
            var next = originalTrigger
            if (next <= 0) continue
            if (repeat > 0) {
                while (next <= now) next += repeat
            } else if (next <= now) {
                // One-shot already passed — drop it so it never rings late.
                prefs.edit().remove(key).apply()
                continue
            }
            schedule(
                context = context,
                id = id,
                triggerTimeMillis = next,
                title = spec.optString("title", ""),
                body = spec.optString("body", ""),
                channelId = spec.optString("channel", "general"),
                sound = spec.optString("sound", "").ifEmpty { null },
                payload = spec.optString("payload", ""),
                repeatDailyMillis = if (repeat > 0) repeat else null,
            )
        }
    }

    /**
     * Returns a JSON array describing every persisted reminder (id, trigger,
     * minutes until fire, repeat, title, channel, payload) — surfaced by the
     * in-app diagnostics page so the user can verify what is actually armed
     * instead of guessing from the Flutter plugin's pending list (which no
     * longer contains native alarms).
     */
    fun listReminders(context: Context): String {
        val prefs = prefs(context)
        val now = System.currentTimeMillis()
        val arr = org.json.JSONArray()
        prefs.all.keys
            .filter { it.startsWith("rem_") }
            .forEach { key ->
                val id = key.removePrefix("rem_").toIntOrNull() ?: return@forEach
                val raw = prefs.getString(key, null) ?: return@forEach
                val spec = try {
                    JSONObject(raw)
                } catch (e: Exception) {
                    return@forEach
                }
                val trigger = spec.optLong("trigger", 0)
                val obj = JSONObject().apply {
                    put("id", id)
                    put("trigger", trigger)
                    put("fireInMinutes", (trigger - now) / 60000)
                    put("repeatDaily", spec.optLong("repeat_daily", -1))
                    put("title", spec.optString("title", ""))
                    put("channel", spec.optString("channel", ""))
                    put("payload", spec.optString("payload", ""))
                }
                arr.put(obj)
            }
        return arr.toString()
    }

    fun cancel(context: Context, id: Int) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ReminderReceiver::class.java)
        intent.action = "com.tawheeed.action.REMINDER_ALARM"
        val pi = PendingIntent.getBroadcast(
            context,
            ID_OFFSET + id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        am.cancel(pi)
        prefs(context).edit().remove("rem_$id").apply()
    }

    /**
     * Cancels every persisted reminder whose numeric id falls in
     * [startId]..[endId]. Used to clear whole windows of one-shot ids
     * (e.g. the daily-content per-day range) in a single native call.
     */
    fun cancelRange(context: Context, startId: Int, endId: Int) {
        val keys = prefs(context).all.keys.filter { it.startsWith("rem_") }
        for (key in keys) {
            val id = key.removePrefix("rem_").toIntOrNull() ?: continue
            if (id in startId..endId) cancel(context, id)
        }
    }

    /** Cancels every armed reminder and clears the native registry. */
    fun cancelAll(context: Context) {
        val keys = prefs(context).all.keys.filter { it.startsWith("rem_") }
        for (key in keys) {
            val id = key.removePrefix("rem_").toIntOrNull() ?: continue
            cancel(context, id)
        }
    }

    fun load(context: Context, id: Int): JSONObject? {
        val raw = prefs(context).getString("rem_$id", null) ?: return null
        return try {
            JSONObject(raw)
        } catch (e: Exception) {
            Log.w(TAG, "Corrupt reminder payload for $id: ${e.message}")
            null
        }
    }

    private fun persist(context: Context, request: ReminderRequest, armedAt: Long) {
        val obj = JSONObject().apply {
            put("trigger", request.triggerTimeMillis)
            put("title", request.title)
            put("body", request.body)
            put("channel", request.channelId)
            put("sound", request.sound ?: "")
            put("payload", request.payload ?: "")
            request.repeatDailyMillis?.let { put("repeat_daily", it) }
            put("armed_at", armedAt)
        }
        prefs(context).edit().putString("rem_${request.id}", obj.toString()).apply()
    }

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}

/** Everything needed to arm (or recognise an already-armed) exact reminder. */
data class ReminderRequest(
    val id: Int,
    val triggerTimeMillis: Long,
    val title: String,
    val body: String,
    val channelId: String,
    val sound: String?,
    val payload: String?,
    val repeatDailyMillis: Long?,
)

/** One entry of a batched native reminder call from Dart. */
sealed class ReminderOp {
    data class Arm(val request: ReminderRequest) : ReminderOp()
    data class Cancel(val id: Int) : ReminderOp()
    data class CancelRange(val startId: Int, val endId: Int) : ReminderOp()
}

/** Outcome of one [ExactReminderScheduler.arm] call, reported back per batch. */
private enum class ArmResult { Armed, AlreadyCurrent, Failed }

