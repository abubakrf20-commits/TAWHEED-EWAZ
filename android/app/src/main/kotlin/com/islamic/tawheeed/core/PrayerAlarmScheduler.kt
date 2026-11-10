package com.islamic.tawheeed.core

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.util.Calendar

/**
 * Exact alarm scheduling via AlarmManager.
 * Uses setExactAndAllowWhileIdle for Doze mode compatibility.
 * Handles Android 12+ exact alarm permissions.
 */
object PrayerAlarmScheduler {
    private const val TAG = "PrayerAlarmScheduler"

    // Request codes for different prayer alarms
    private const val RC_FAJR = 2001
    private const val RC_SHURUQ = 2002
    private const val RC_DHUHR = 2003
    private const val RC_ASR = 2004
    private const val RC_MAGHRIB = 2005
    private const val RC_ISHA = 2006
    private const val RC_SILENT_MUTE = 2007
    private const val RC_SILENT_UNMUTE = 2008
    /** One independent silent window (a mute+unmute pair) per prayer. */
    private const val SILENT_SLOTS = 5
    private const val RC_ROLLOVER = 2099

    /**
     * Schedules the daily "rollover" alarm that fires shortly after midnight.
     * This is the self-healing heartbeat: it re-arms itself for the next day
     * and triggers the Flutter scheduler so today's + tomorrow's prayer
     * notifications and native alarms are (re)computed every day even if the
     * app is never opened and WorkManager is deferred by battery managers.
     */
    fun scheduleDailyRollover(context: Context, triggerTimeMillis: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, RolloverReceiver::class.java).apply {
            action = "com.tawheeed.action.ROLLOVER"
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context, RC_ROLLOVER, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        try {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerTimeMillis,
                pendingIntent
            )
            Log.d(TAG, "Scheduled daily rollover at $triggerTimeMillis")
        } catch (e: SecurityException) {
            Log.e(TAG, "Failed to schedule exact rollover: ${e.message}")
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerTimeMillis, pendingIntent)
        }
    }

    /** Next midnight (00:00:15 local) — the default daily rollover time. */
    fun nextRolloverTime(): Long {
        val cal = Calendar.getInstance()
        cal.add(Calendar.DAY_OF_MONTH, 1)
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 15)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    fun cancelDailyRollover(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, RolloverReceiver::class.java).apply {
            action = "com.tawheeed.action.ROLLOVER"
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context, RC_ROLLOVER, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
        Log.d(TAG, "Cancelled daily rollover alarm")
    }

    private fun prayerRequestCode(prayer: String): Int = when (prayer.lowercase()) {
        "fajr", "فجر" -> RC_FAJR
        "sunrise", "طلوع", "شروق" -> RC_SHURUQ
        "dhuhr", "ظهر" -> RC_DHUHR
        "asr", "عصر" -> RC_ASR
        "maghrib", "مغرب" -> RC_MAGHRIB
        "isha", "عشاء" -> RC_ISHA
        else -> prayer.hashCode()
    }

    fun scheduleAdhanAlarm(
        context: Context,
        prayerName: String,
        triggerTimeMillis: Long,
        soundName: String = "kamel",
        customPath: String = "",
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val intent = Intent(context, AdhanReceiver::class.java).apply {
            action = "com.tawheeed.action.ADHAN_ALARM"
            putExtra("prayer_name", prayerName)
            putExtra("sound_name", soundName)
            putExtra("custom_path", customPath)
        }

        val requestCode = prayerRequestCode(prayerName)
        val pendingIntent = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            // Use setAlarmClock() for reliable firing even on Samsung's aggressive Doze.
            // NOTE (Audit 4.2): this DOES require SCHEDULE_EXACT_ALARM on Android 12+
            // (denied by default from Android 14 for fresh installs) — the old comment
            // claiming otherwise was wrong. The fallback below needs the same grant,
            // so it is nested and can also fail; both failures are contained here.
            val alarmClockInfo = AlarmManager.AlarmClockInfo(triggerTimeMillis, null)
            alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
            Log.d(TAG, "Scheduled $prayerName setAlarmClock at $triggerTimeMillis")
        } catch (e: SecurityException) {
            Log.e(TAG, "Failed to schedule setAlarmClock: ${e.message}")
            try {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerTimeMillis,
                    pendingIntent
                )
            } catch (e2: SecurityException) {
                // Both exact paths denied — degrade to an inexact alarm so the
                // adhan still fires (possibly minutes late under Doze) instead of
                // silently vanishing for that day.
                Log.e(TAG, "Exact alarms denied entirely — inexact fallback: ${e2.message}")
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, triggerTimeMillis, pendingIntent
                )
            }
        }
    }

    fun scheduleSilentModeAlarm(
        context: Context,
        triggerTimeMillis: Long,
        iqamahTimeMillis: Long,
        slot: Int = 0,
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
            return
        }

        // Each silent window needs its OWN request-code pair: with a single fixed
        // pair every prayer overwrote the previous one (FLAG_UPDATE_CURRENT on
        // the same component+action+requestCode), so while the app was closed
        // only the last scheduled prayer of the day was ever muted. slot 0 keeps
        // the historical codes so existing schedules stay addressable.
        val muteRequestCode = RC_SILENT_MUTE + slot * 10
        val unmuteRequestCode = RC_SILENT_UNMUTE + slot * 10

        // Mute alarm (fires SilentModeReceiver with unmute=false)
        val muteIntent = Intent(context, SilentModeReceiver::class.java).apply {
            action = "com.tawheeed.action.SILENT_MODE"
            putExtra("unmute", false)
        }
        val mutePi = PendingIntent.getBroadcast(
            context, muteRequestCode, muteIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Unmute alarm (fires SilentModeReceiver with unmute=true)
        val unmuteIntent = Intent(context, SilentModeReceiver::class.java).apply {
            action = "com.tawheeed.action.SILENT_MODE"
            putExtra("unmute", true)
        }
        val unmutePi = PendingIntent.getBroadcast(
            context, unmuteRequestCode, unmuteIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerTimeMillis,
                mutePi
            )
            if (iqamahTimeMillis > triggerTimeMillis) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    iqamahTimeMillis,
                    unmutePi
                )
            }
            Log.d(TAG, "Scheduled silent mode (mute=$triggerTimeMillis, unmute=$iqamahTimeMillis)")
        } catch (e: SecurityException) {
            Log.e(TAG, "Failed to schedule silent alarm: ${e.message}")
        }
    }

    fun cancelSilentModeAlarm(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        // Cancel every per-prayer pair plus the two historical fixed codes, so
        // schedules written by older builds are cleared as well.
        val requestCodes = mutableListOf(RC_SILENT_MUTE, RC_SILENT_UNMUTE)
        for (slot in 0 until SILENT_SLOTS) {
            requestCodes.add(RC_SILENT_MUTE + slot * 10)
            requestCodes.add(RC_SILENT_UNMUTE + slot * 10)
        }
        requestCodes.forEach { rc ->
            val intent = Intent(context, SilentModeReceiver::class.java).apply {
                action = "com.tawheeed.action.SILENT_MODE"
            }
            val pi = PendingIntent.getBroadcast(
                context, rc, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pi)
        }
        Log.d(TAG, "Cancelled silent mode alarms")
    }

    fun cancelAlarm(context: Context, prayerName: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AdhanReceiver::class.java).apply {
            action = "com.tawheeed.action.ADHAN_ALARM"
        }
        val requestCode = prayerRequestCode(prayerName)
        val pendingIntent = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
        Log.d(TAG, "Cancelled alarm for $prayerName")
    }

    fun cancelAllAlarms(context: Context) {
        listOf("fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha").forEach {
            cancelAlarm(context, it)
        }
    }

    fun hasExactAlarmPermission(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            return alarmManager.canScheduleExactAlarms()
        }
        return true
    }
}
