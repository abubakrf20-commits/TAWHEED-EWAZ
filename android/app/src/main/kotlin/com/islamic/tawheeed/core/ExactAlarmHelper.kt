package com.islamic.tawheeed.core

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.islamic.tawheeed.core.AdhanReceiver
import com.islamic.tawheeed.core.BootReceiver
import org.json.JSONArray
import org.json.JSONObject

object ExactAlarmHelper {
    private const val TAG = "ExactAlarmHelper"

    fun scheduleExactAlarm(
        context: Context,
        alarmId: Int,
        triggerTimeMillis: Long,
        prayerName: String,
        sound: String,
        customPath: String,
        volume: Float = 1.0f,
    ): Boolean {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val intent = Intent(context, AdhanReceiver::class.java).apply {
            action = "com.tawheeed.action.ADHAN_ALARM"
            putExtra("prayer_name", prayerName)
            putExtra("sound_name", sound)
            putExtra("custom_path", customPath)
            putExtra("volume", volume)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context, alarmId, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return try {
            // setAlarmClock() is the most OEM-friendly exact alarm (survives
            // Samsung's aggressive Doze), but it is NOT permission-free: on
            // Android 12+ it demands SCHEDULE_EXACT_ALARM/USE_EXACT_ALARM and on
            // Android 14+ that grant is denied by default for fresh installs.
            // The showIntent opens the app so the status-bar alarm icon that
            // setAlarmClock always displays can be dismissed by opening us.
            val launch = context.packageManager
                .getLaunchIntentForPackage(context.packageName) ?: Intent()
            val alarmClockInfo = AlarmManager.AlarmClockInfo(
                triggerTimeMillis,
                PendingIntent.getActivity(
                    context, alarmId, launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
            alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
            Log.d(TAG, "Scheduled setAlarmClock $alarmId for $prayerName at $triggerTimeMillis")
            true
        } catch (e: SecurityException) {
            // NESTED guard on purpose: the fallback below requires the SAME
            // permission, so it can throw too — and an exception escaping a
            // catch block inside a receiver turns a missing grant into a hard
            // failure of the whole scheduling batch.
            try {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, triggerTimeMillis, pendingIntent
                )
                Log.e(TAG, "setAlarmClock denied — fell back to setExactAndAllowWhileIdle")
                true
            } catch (e2: SecurityException) {
                Log.e(TAG, "Exact alarms unavailable (permission denied): ${e2.message}")
                false
            }
        }
    }

    /**
     * Arms every alarm in [alarmsJson]. Returns how many armed through an
     * EXACT path (setAlarmClock or setExactAndAllowWhileIdle); alarms that hit
     * the inexact fallback after a double SecurityException are NOT counted.
     * Callers (boot/rollover restore) log this so a missing
     * SCHEDULE_EXACT_ALARM grant shows up instead of degrading silently.
     */
    fun scheduleAlarmsFromJson(context: Context, alarmsJson: String): Int {
        val array = JSONArray(alarmsJson)
        var exactCount = 0
        for (i in 0 until array.length()) {
            val obj = array.getJSONObject(i)
            val exact = scheduleExactAlarm(
                context = context,
                alarmId = obj.getInt("id"),
                triggerTimeMillis = obj.getLong("timeMillis"),
                prayerName = obj.getString("prayer"),
                sound = obj.optString("sound", "takbir"),
                customPath = obj.optString("customPath", ""),
                volume = obj.optDouble("volume", 1.0).toFloat(),
            )
            if (exact) exactCount++
        }
        return exactCount
    }

    fun cancelAlarm(context: Context, alarmId: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AdhanReceiver::class.java)
        intent.action = "com.tawheeed.action.ADHAN_ALARM"
        val pendingIntent = PendingIntent.getBroadcast(
            context, alarmId, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
    }

    fun cancelAll(context: Context) {
        // Cancel every persisted alarm by its id, then clear the registry.
        val prefs = context.getSharedPreferences("prayer_alarms", Context.MODE_PRIVATE)
        val json = prefs.getString("scheduled_alarms", null)
        if (json != null) {
            try {
                val array = JSONArray(json)
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    cancelAlarm(context, obj.getInt("id"))
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to cancel persisted alarms: ${e.message}")
            }
        }
        prefs.edit().remove("scheduled_alarms").apply()
    }

    fun canScheduleExactAlarms(context: Context): Boolean {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }
    }

    fun openExactAlarmSettings(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val intent = android.content.Intent(
                android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM
            ).apply {
                data = android.net.Uri.parse("package:${context.packageName}")
                addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
        }
    }

    /**
     * Re-arms every persisted future alarm (boot / rollover / exact-permission
     * change). Returns how many armed through an exact path — 0 with a
     * non-empty registry is the fingerprint of a missing
     * SCHEDULE_EXACT_ALARM grant; -1 means the registry was unreadable.
     */
    fun rescheduleAllAfterBoot(context: Context): Int {
        val prefs = context.getSharedPreferences("prayer_alarms", Context.MODE_PRIVATE)
        val json = prefs.getString("scheduled_alarms", null) ?: return 0

        return try {
            val future = filterFutureAlarms(json, System.currentTimeMillis())
            val armed = if (future.length() > 0) {
                val exact = scheduleAlarmsFromJson(context, future.toString())
                Log.d(TAG, "Rescheduled ${future.length()} future alarms ($exact exact)")
                exact
            } else 0
            armed
        } catch (e: Exception) {
            Log.e(TAG, "Failed to reschedule alarms: ${e.message}")
            -1
        }
    }

    /**
     * Pure (JVM-testable) part of the boot restore: keeps only alarms whose
     * [timeMillis] is after [now]. Malformed entries are dropped so one bad
     * record cannot abort the whole restore.
     */
    fun filterFutureAlarms(alarmsJson: String, now: Long): JSONArray {
        val future = JSONArray()
        val array = try {
            JSONArray(alarmsJson)
        } catch (e: Exception) {
            // A corrupt registry string degrades to "nothing to restore"
            // instead of aborting the whole boot/rollover chain.
            Log.e(TAG, "Persisted alarm registry unreadable: ${e.message}")
            return future
        }
        for (i in 0 until array.length()) {
            try {
                val obj = array.getJSONObject(i)
                if (obj.optLong("timeMillis", -1L) > now) future.put(obj)
            } catch (e: Exception) {
                Log.w(TAG, "Skipping malformed persisted alarm #$i: ${e.message}")
            }
        }
        return future
    }

    fun persistAlarms(context: Context, alarmsJson: String) {
        context.getSharedPreferences("prayer_alarms", Context.MODE_PRIVATE)
            .edit()
            .putString("scheduled_alarms", alarmsJson)
            .putBoolean("exact_granted_at_schedule", canScheduleExactAlarms(context))
            .apply()
    }
}
