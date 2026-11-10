package com.islamic.tawheeed.core

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.util.Log

/**
 * Handles silent mode before iqamah.
 * Mutes device at scheduled time, unmutes at iqamah time.
 */
class SilentModeReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "SilentModeReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "com.tawheeed.action.SILENT_MODE") return

        val shouldUnmute = intent.getBooleanExtra("unmute", false)
        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val prefs = context.getSharedPreferences("silent_prefs", Context.MODE_PRIVATE)

        if (shouldUnmute) {
            val previousMode = prefs.getInt("previous_ringer_mode", AudioManager.RINGER_MODE_NORMAL)
            audioManager.ringerMode = previousMode
            Log.d(TAG, "Device unmuted, restored ringer mode: $previousMode")
            return
        }

        // Save current ringer mode before muting
        prefs.edit().putInt("previous_ringer_mode", audioManager.ringerMode).apply()

        // Mute
        audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
        Log.d(TAG, "Device muted for iqamah")

        // NOTE: this receiver used to re-arm a MUTE at the iqamah time taken from
        // an "iqamah_time" extra — an extra the mute Intent never carried, so the
        // block was dead code; and had that extra ever been added it would have
        // muted the device again at iqamah with NO unmute, leaving the phone
        // silent indefinitely. Unmuting is owned by the dedicated per-prayer
        // unmute alarm armed in PrayerAlarmScheduler.scheduleSilentModeAlarm.
    }
}
