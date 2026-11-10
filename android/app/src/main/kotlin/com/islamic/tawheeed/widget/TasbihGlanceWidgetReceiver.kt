package com.islamic.tawheeed.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import org.json.JSONArray
import org.json.JSONObject

/**
 * The tasbih card's receiver.
 *
 * The class name is historical: this used to be a `GlanceAppWidgetReceiver`.
 * It is a plain [AppWidgetProvider] now, because a Glance widget composes once
 * per process on the test device and never repaints on a tap — see
 * [TasbihNativeViews]. The *component* name is deliberately unchanged: a placed
 * widget is keyed by its provider component, so renaming the class would orphan
 * the card already sitting on the user's home screen.
 *
 * A tap is a broadcast into this receiver (no activity, no Flutter, no alarm),
 * which commits the counter and then hands the launcher a *partial* RemoteViews
 * — only the setters that changed — so the bead lands in a frame.
 */
class TasbihGlanceWidgetReceiver : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        WidgetTiming.logProcessReady("tasbih.onUpdate")
        // The widget may be bound before the app ever pushed a snapshot, or
        // re-bound after the OS restricted the app — always render with valid
        // style defaults.
        WidgetTokens.init(context)
        // A new day may have started while the widget was idle — zero the
        // per-zikr counters so the widget never shows yesterday's counts even
        // if the app hasn't synced yet (only when auto-reset is enabled).
        try {
            maybeDailyReset(WidgetRepository.prefs(context), todayKey())
        } catch (e: Throwable) {
            Log.e(TAG, "onUpdate daily reset failed: ${e.message}")
        }
        for (id in appWidgetIds) {
            render(context, appWidgetManager, id, full = true)
        }
        rearmAll(context)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        // The confirm window is a 3 s in-memory deadline that expires by itself.
        for (id in appWidgetIds) {
            TasbihTapEngine.forget(TasbihNativeViews.widgetKey(id))
        }
        super.onDeleted(context, appWidgetIds)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        // A resize changes the cell's dp box, and every size on the card is
        // derived from it — this is one of the few genuine full renders.
        try {
            WidgetTokens.init(context)
            render(context, appWidgetManager, appWidgetId, full = true)
        } catch (t: Throwable) {
            Log.e(TAG, "onOptionsChanged failed: ${t.message}")
        }
    }

    /** Launcher restore (backup/restore or device transfer): the framework
     *  hands the ids here without calling onUpdate. */
    override fun onRestored(
        context: Context,
        oldWidgetIds: IntArray,
        newWidgetIds: IntArray
    ) {
        super.onRestored(context, oldWidgetIds, newWidgetIds)
        onUpdate(context, AppWidgetManager.getInstance(context), newWidgetIds)
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        // Fresh placement: defaults + style tokens must exist before the first
        // render, and the alarms must be armed even if the first render fails.
        WidgetTokens.init(context)
        try {
            maybeDailyReset(WidgetRepository.prefs(context), todayKey())
        } catch (e: Throwable) {
            Log.e(TAG, "onEnabled daily reset failed: ${e.message}")
        }
        rearmAll(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        // Last instance removed — stop waking the process for nothing.
        cancelWatchdog(context)
        cancelMidnightReset(context)
        WidgetRefreshWorker.cancel(context)
    }

    /** Every alarm this widget needs, in one place — called on update, on
     *  enable, and by each alarm as it fires. */
    fun rearmAll(context: Context) {
        scheduleWatchdog(context)
        scheduleMidnightReset(context)
        WidgetRefreshWorker.schedule(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        // AppWidgetProvider dispatches APPWIDGET_UPDATE / ENABLED / DISABLED /
        // DELETED / OPTIONS_CHANGED / RESTORED from here; those already arm or
        // cancel the alarms themselves.
        super.onReceive(context, intent)

        val action = intent.action ?: return
        val isTap = when (action) {
            ACTION_INCREMENT, ACTION_RESET, ACTION_PREV_ZIKR, ACTION_NEXT_ZIKR -> true
            else -> false
        }

        if (isTap) {
            // Sender-verified: this receiver is exported (the launcher needs to
            // reach it), so any app could otherwise broadcast INCREMENT and
            // tamper with the counter.
            val sender = intent.`package`
            if (sender != context.packageName) {
                Log.w(TAG, "dropped foreign tasbih broadcast from: $sender")
                return
            }
            handleTap(context, intent, action)
            return
        }

        // The package-replaced branch is the one that earns its keep: install -r
        // force-stops us, cancelling every alarm, so this pass is the only thing
        // that re-arms the chain without waiting for the app to be opened.
        if (action == ACTION_WATCHDOG || action == ACTION_MIDNIGHT_RESET ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            // Nullable on purpose: `goAsync()` only returns a PendingResult
            // while the framework is dispatching a broadcast to this instance,
            // and it has been observed null on HyperOS 3. An unguarded
            // `.finish()` there is a NullPointerException on a coroutine
            // worker — the process dies and the card blanks.
            val result: BroadcastReceiver.PendingResult? = goAsync()
            try {
                WidgetTokens.init(context)
                maybeDailyReset(WidgetRepository.prefs(context), todayKey())
                renderAll(context)
            } catch (t: Throwable) {
                Log.e(TAG, "system refresh failed: ${t.message}")
            } finally {
                try {
                    result?.finish()
                } catch (t: Throwable) {
                    Log.w(TAG, "system refresh finish failed: ${t.message}")
                }
            }
            rearmAll(context)
        }
    }

    /**
     * One bead.
     *
     * The whole path is: prefs write → one partial RemoteViews → the launcher
     * merges it into the view it already has. No composition, no session, no
     * re-inflation, and no second repaint queued behind it.
     */
    private fun handleTap(context: Context, intent: Intent, action: String) {
        val startedAt = SystemClock.uptimeMillis()
        val widgetId = intent.getIntExtra(EXTRA_APP_WIDGET_ID, -1)
        val widgetKey = intent.getStringExtra(EXTRA_WIDGET_KEY)
            ?: widgetId.takeIf { it >= 0 }?.let { TasbihNativeViews.widgetKey(it) }
            ?: "tasbih"
        // `goAsync` keeps the broadcast alive until the launcher has the new
        // frame, instead of risking the ANR timeout while the process is cold.
        val result: BroadcastReceiver.PendingResult? = goAsync()
        try {
            WidgetTokens.init(context)
            val outcome = TasbihTapEngine.applyTap(context, action, widgetKey)
            WidgetTiming.mark(
                "tap.prefs.committed",
                startedAt,
                "action=$action count=${outcome.count} applied=${outcome.applied}",
            )
            if (!outcome.applied) return
            val manager = AppWidgetManager.getInstance(context)
            if (widgetId >= 0) {
                render(context, manager, widgetId, full = false)
            } else {
                renderAll(context)
            }
            WidgetTiming.mark("tap.render.done", startedAt, "action=$action")
        } catch (t: Throwable) {
            Log.e(TAG, "tap handling failed: ${t.message}")
        } finally {
            try {
                result?.finish()
            } catch (t: Throwable) {
                Log.w(TAG, "tap finish failed: ${t.message}")
            }
        }
    }

    // ── Rendering ──────────────────────────────────────────────────────────

    /**
     * Paints one instance.
     *
     * [full] rebuilds everything; otherwise only the setters a tap can change
     * are applied, through `partiallyUpdateAppWidget`, which merges them into
     * the launcher's existing view.
     */
    private fun render(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
        full: Boolean,
    ) {
        try {
            val views = if (full) {
                TasbihNativeViews.full(context, widgetId)
            } else {
                TasbihNativeViews.partial(context, widgetId)
            }
            if (full) {
                manager.updateAppWidget(widgetId, views)
            } else {
                manager.partiallyUpdateAppWidget(widgetId, views)
            }
        } catch (t: Throwable) {
            // One stale id must not stop the others: a launcher can keep an id
            // for a moment after the user removed the card.
            Log.w(TAG, "render id=$widgetId full=$full failed: ${t.message}")
        }
    }

    companion object {
        private const val TAG = "TasbihWidget"

        /** Paints every placed instance. The app's snapshot push, the watchdog
         *  and the midnight reset all land here. */
        fun renderAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(TasbihNativeViews.component(context))
            if (ids.isEmpty()) {
                Log.w(TAG, "renderAll: no instances")
                return
            }
            for (id in ids) {
                try {
                    manager.updateAppWidget(id, TasbihNativeViews.full(context, id))
                } catch (t: Throwable) {
                    Log.w(TAG, "renderAll id=$id failed: ${t.message}")
                }
            }
        }

        /** The widget instance a tap belongs to. The confirm window and the
         *  daily rollover are keyed by it. */
        const val EXTRA_WIDGET_KEY = "com.tawheeed.TASBIH_WIDGET_KEY"

        /** The instance id the tap came from, so the repaint can be partial. */
        const val EXTRA_APP_WIDGET_ID = "com.tawheeed.TASBIH_APP_WIDGET_ID"

        /** Appends one event to the append-only queue the app drains on sync.
         *
         *  Every widget-side mutation is recorded as a discrete event with a
         *  strictly increasing sequence number, so the app can merge taps
         *  additively onto its own state and stay idempotent across retries
         *  (entries with s <= applied seq are pruned via [prunePending]). If the
         *  app has not drained for a very long time and the queue outgrows
         *  [PENDING_MAX], it collapses into a single "full" event carrying the
         *  committed per-zikr counts — those already include every tap. */
        fun appendEvent(
            prefs: android.content.SharedPreferences,
            type: String,
            zikrIdx: Int,
            delta: Int = 0,
        ) {
            val seq = prefs.getInt(KEY_PENDING_SEQ, 0) + 1
            val ev = JSONObject().put("s", seq).put("k", type).put("z", zikrIdx)
            if (type == EVENT_INC) ev.put("d", delta)
            val queue = try {
                JSONArray(prefs.getString(KEY_PENDING, "[]") ?: "[]")
            } catch (_: Throwable) {
                JSONArray()
            }
            queue.put(ev)
            val editor = prefs.edit().putInt(KEY_PENDING_SEQ, seq)
            if (queue.length() > PENDING_MAX) {
                val counts = getPerZikrCounts(prefs)
                val obj = JSONObject()
                for ((k, v) in counts) obj.put(k.toString(), v)
                val full = JSONArray().put(
                    JSONObject().put("s", seq).put("k", EVENT_FULL).put("c", obj)
                )
                editor.putString(KEY_PENDING, full.toString())
            } else {
                editor.putString(KEY_PENDING, queue.toString())
            }
            editor.apply()
        }

        /** The undrained event queue for the app's sync merge. */
        fun readPending(prefs: android.content.SharedPreferences): JSONArray = try {
            JSONArray(prefs.getString(KEY_PENDING, "[]") ?: "[]")
        } catch (_: Throwable) {
            JSONArray()
        }

        /** The pending queue as plain maps/lists for the Flutter method channel.
         *
         *  org.json values are NOT encodable by the Flutter
         *  StandardMessageCodec: a reply containing a JSONObject fails the
         *  WHOLE reply («Unsupported value: '{...}' of type
         *  'class org.json.JSONObject'» — found on-device 2026-10-16), which
         *  silently disabled the widget→app drain and let taps pile up in the
         *  queue for days. Convert the event tree to
         *  Map/List/String/Number/Boolean/null before it crosses the channel —
         *  no org.json instance may remain. */
        fun plainEvents(
            prefs: android.content.SharedPreferences,
        ): List<Map<String, Any?>> = plainEvents(readPending(prefs))

        /** Pure conversion of a queue payload — test seam for [plainEvents]. */
        fun plainEvents(queue: JSONArray): List<Map<String, Any?>> {
            val out = ArrayList<Map<String, Any?>>(queue.length())
            for (i in 0 until queue.length()) {
                val event = queue.optJSONObject(i) ?: continue
                out.add(plainMap(event))
            }
            return out
        }

        private fun plainMap(obj: JSONObject): Map<String, Any?> {
            val map = LinkedHashMap<String, Any?>()
            for (key in obj.keys()) map[key] = plainValue(obj.get(key))
            return map
        }

        /** StandardMessageCodec's own allow-list — anything else must not
         *  reach the channel. */
        private fun plainValue(value: Any?): Any? = when {
            value == null || value === JSONObject.NULL -> null
            value is JSONObject -> plainMap(value)
            value is JSONArray -> (0 until value.length()).map { plainValue(value.get(it)) }
            value is String || value is Boolean || value is Number -> value
            else -> value.toString()
        }

        /** Drops events the app has durably applied (idempotency window). */
        fun prunePending(prefs: android.content.SharedPreferences, throughSeq: Int) {
            val queue = readPending(prefs)
            val keep = JSONArray()
            for (i in 0 until queue.length()) {
                val e = queue.optJSONObject(i) ?: continue
                if (e.optInt("s", 0) > throughSeq) keep.put(e)
            }
            prefs.edit().putString(KEY_PENDING, keep.toString()).apply()
        }

        /** Today's calendar key in the same YYYY-MM-DD format the app uses for
         *  the tasbih daily-reset tracking. */
        fun todayKey(): String =
            SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

        /** Native daily auto-reset for the widget's own per-zikr counters.
         *
         *  Previously the widget relied entirely on the app pushing zeroed
         *  counts after its own midnight reset, so when the app was closed (or
         *  the Flutter engine paused) the widget kept showing yesterday's
         *  counts all day. This makes the widget reset itself:
         *   - runs at most once per day (guarded by `widget_tasbih_last_active_date`);
         *   - only when the app's «ریست خودکار روزانه» is enabled
         *     (`tasbih_auto_reset`, pushed by the snapshot);
         *   - zeroes every per-zikr counter and the current count;
         *   - stamps `widget_tasbih_last_tap_at` so the next app sync imports
         *     the reset instead of re-importing yesterday's stale counts, and
         *     queues a reset-all event for the app's own counters.
         *
         *  Returns true when a reset was performed. The date key is always
         *  stamped (attempted at most once per day) even when autoReset is
         *  off and no reset happened. */
        fun maybeDailyReset(
            prefs: android.content.SharedPreferences,
            today: String,
        ): Boolean {
            val lastActive = prefs.getString("widget_tasbih_last_active_date", null)
            if (lastActive == today) return false
            prefs.edit().putString("widget_tasbih_last_active_date", today).apply()
            if (!prefs.getBoolean("tasbih_auto_reset", true)) return false
            val counts = getPerZikrCounts(prefs)
            val hadCounts =
                counts.values.any { it > 0 } || prefs.getInt("tasbih_count", 0) > 0
            if (hadCounts) {
                setPerZikrCounts(prefs, counts.keys.associateWith { 0 })
                prefs.edit()
                    .putInt("tasbih_count", 0)
                    .putLong("widget_tasbih_last_tap_at", System.currentTimeMillis())
                    .apply()
                appendEvent(prefs, EVENT_RESET, -1)
            }
            return true
        }

        /** Ring progress (0–10000) for a count — clamped at the full ring,
         *  so counting past the target fills the ring and stays there while
         *  the displayed number keeps growing. */
        fun progressOf(count: Int, target: Int): Int =
            if (target > 0) ((count.toFloat() / target).coerceIn(0f, 1f) * 10000).toInt() else 0

        /** Next count after a tap — never capped at the target, so the user
         *  can keep counting past it (e.g. a 100-target tasbih up to 1000). */
        fun nextCount(current: Int): Int = current + 1

        const val ACTION_INCREMENT = "com.tawheeed.TASBIH_INCREMENT"
        const val ACTION_RESET = "com.tawheeed.TASBIH_RESET"
        const val ACTION_PREV_ZIKR = "com.tawheeed.TASBIH_PREV_ZIKR"
        const val ACTION_NEXT_ZIKR = "com.tawheeed.TASBIH_NEXT_ZIKR"

        /** Self-heal alarm wiring. The request codes sit clear of the
         *  per-widget tap band (appWidgetId × 10) and the activity door
         *  (appWidgetId + 60000), and the actions are delivered by explicit
         *  component, so neither needs a manifest intent-filter entry. */
        const val ACTION_WATCHDOG = "com.tawheeed.TASBIH_WATCHDOG"
        const val ACTION_MIDNIGHT_RESET = "com.tawheeed.TASBIH_MIDNIGHT_RESET"
        private const val WATCHDOG_REQUEST_CODE = 9996
        private const val MIDNIGHT_REQUEST_CODE = 9995
        private const val WATCHDOG_INTERVAL_MS = 6 * 60 * 60 * 1000L

        const val EVENT_INC = "inc"
        const val EVENT_RESET = "reset"
        const val EVENT_ZIKR = "zikr"
        const val EVENT_FULL = "full"
        const val KEY_PENDING = "widget_tasbih_pending"
        const val KEY_PENDING_SEQ = "widget_tasbih_pending_seq"

        /** Events the app is expected to drain before the queue collapses to a
         *  full-state event. At the coalesced UI rate (~5 taps/s max) this is
         *  about a minute of un-drained rapid tapping; any normal app open
         *  drains far earlier. */
        const val PENDING_MAX = 300

        private val DEFAULT_ZIKR_LIST = listOf(
            "سبحان الله",
            "لا اله الا الله",
            "الله اکبر",
            "استغفر الله",
            "الحمد لله",
            "لا حول ولا قوة الا بالله العلی العظیم",
            "استغفر الله العظیم واتوب الیه"
        )

        /** Read per-zikr counts from SharedPreferences as a JSON map {index: count} */
        fun getPerZikrCounts(prefs: android.content.SharedPreferences): MutableMap<Int, Int> {
            val result = mutableMapOf<Int, Int>()
            val json = prefs.getString("tasbih_per_zikr_counts", null) ?: return result
            try {
                val obj = JSONObject(json)
                for (key in obj.keys()) {
                    result[key.toInt()] = obj.getInt(key)
                }
            } catch (_: Exception) {}
            return result
        }

        /** Read per-zikr targets (aligned with the zikr list order). */
        fun getPerZikrTargets(prefs: android.content.SharedPreferences): List<Int> {
            val json = prefs.getString("tasbih_per_zikr_targets", null) ?: return emptyList()
            try {
                val arr = JSONArray(json)
                val list = mutableListOf<Int>()
                for (i in 0 until arr.length()) {
                    list.add(arr.getInt(i))
                }
                return list
            } catch (_: Exception) { return emptyList() }
        }

        /** Write per-zikr counts to SharedPreferences */
        fun setPerZikrCounts(prefs: android.content.SharedPreferences, counts: Map<Int, Int>) {
            val obj = JSONObject()
            for ((k, v) in counts) {
                obj.put(k.toString(), v)
            }
            prefs.edit().putString("tasbih_per_zikr_counts", obj.toString()).apply()
        }

        fun getZikrList(prefs: android.content.SharedPreferences): List<String> {
            val json = prefs.getString("tasbih_zikr_list", null)
            if (json != null) {
                try {
                    val arr = JSONArray(json)
                    val list = mutableListOf<String>()
                    for (i in 0 until arr.length()) {
                        list.add(arr.getString(i))
                    }
                    if (list.isNotEmpty()) return list
                } catch (_: Exception) {}
            }
            return DEFAULT_ZIKR_LIST
        }
    }

    // ── Self-heal: watchdog + midnight reset ───────────────────────────────

    /** Coarse safety net.
     *
     *  Every visible change comes from a render — a tap, an app snapshot, or
     *  these alarms. Without any alarm, a host whose first bind failed kept the
     *  launcher's error view or yesterday's counter until the user happened to
     *  open the app. Re-armed whenever it fires, so this is a worst-case
     *  staleness bound of [WATCHDOG_INTERVAL_MS], not a polling loop:
     *  `updatePeriodMillis` stays 0. */
    private fun scheduleWatchdog(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, TasbihGlanceWidgetReceiver::class.java).apply {
                action = ACTION_WATCHDOG
                setPackage(context.packageName)
            }
            val pi = PendingIntent.getBroadcast(
                context,
                WATCHDOG_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            setAndAllowWhileIdle(
                alarmManager,
                System.currentTimeMillis() + WATCHDOG_INTERVAL_MS,
                pi,
            )
        } catch (t: Throwable) {
            Log.e(TAG, "scheduleWatchdog failed: ${t.message}")
        }
    }

    private fun cancelWatchdog(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, TasbihGlanceWidgetReceiver::class.java).apply {
                action = ACTION_WATCHDOG
                setPackage(context.packageName)
            }
            val pi = PendingIntent.getBroadcast(
                context,
                WATCHDOG_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            alarmManager.cancel(pi)
        } catch (_: Throwable) {}
    }

    /** Resets the widget's per-zikr counters at the day boundary.
     *
     *  [maybeDailyReset] only runs on a render, so without this alarm the first
     *  reset of the day could wait for the 6 h watchdog — the widget would show
     *  yesterday's tally until then even though auto-reset is on. */
    private fun scheduleMidnightReset(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, TasbihGlanceWidgetReceiver::class.java).apply {
                action = ACTION_MIDNIGHT_RESET
                setPackage(context.packageName)
            }
            val pi = PendingIntent.getBroadcast(
                context,
                MIDNIGHT_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val cal = java.util.Calendar.getInstance().apply {
                add(java.util.Calendar.DAY_OF_YEAR, 1)
                set(java.util.Calendar.HOUR_OF_DAY, 0)
                set(java.util.Calendar.MINUTE, 0)
                set(java.util.Calendar.SECOND, 0)
                set(java.util.Calendar.MILLISECOND, 0)
            }
            val target = cal.timeInMillis
            val canScheduleExact =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    alarmManager.canScheduleExactAlarms()
                } else {
                    true
                }
            if (canScheduleExact) {
                try {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target, pi)
                } catch (_: SecurityException) {
                    setAndAllowWhileIdle(alarmManager, target, pi)
                }
            } else {
                setAndAllowWhileIdle(alarmManager, target, pi)
            }
        } catch (t: Throwable) {
            Log.e(TAG, "scheduleMidnightReset failed: ${t.message}")
        }
    }

    private fun cancelMidnightReset(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, TasbihGlanceWidgetReceiver::class.java).apply {
                action = ACTION_MIDNIGHT_RESET
                setPackage(context.packageName)
            }
            val pi = PendingIntent.getBroadcast(
                context,
                MIDNIGHT_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            alarmManager.cancel(pi)
        } catch (_: Throwable) {}
    }

    /** Doze-friendly inexact arm (plain [AlarmManager.set] would be deferred). */
    private fun setAndAllowWhileIdle(
        alarmManager: AlarmManager,
        triggerAtMillis: Long,
        pi: PendingIntent,
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
        } else {
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
        }
    }
}
