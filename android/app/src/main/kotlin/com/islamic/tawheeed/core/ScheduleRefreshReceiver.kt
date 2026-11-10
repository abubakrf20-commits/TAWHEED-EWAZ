package com.islamic.tawheeed.core

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Receiver for schedule refresh broadcasts.
 * Used by native background scheduling as a fallback when exact alarms fail.
 * Also triggered by the Flutter side to force reschedule.
 */
class ScheduleRefreshReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "ScheduleRefreshReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "com.tawheeed.action.REFRESH_SCHEDULE") return

        Log.d(TAG, "Schedule refresh requested")

        val prefs = context.getSharedPreferences("prayer_alarms", Context.MODE_PRIVATE)
        prefs.edit().putBoolean("needs_reschedule", true).apply()
        prefs.edit().putLong("refresh_time", System.currentTimeMillis()).apply()
    }
}
