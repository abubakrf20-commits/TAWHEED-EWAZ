package com.islamic.tawheeed.core

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import com.islamic.tawheeed.AzanForegroundService
import com.islamic.tawheeed.widget.PrayerWidget

/**
 * Receives exact alarm broadcasts and starts the Adhan foreground service.
 * This is the entry point for prayer-time audio playback.
 *
 * Fallback: on Android 12+ and on OEM ROMs (Xiaomi MIUI, Huawei EMUI, Oppo,
 * Vivo, OnePlus, …) aggressive battery managers can block background
 * foreground-service starts (ForegroundServiceStartNotAllowedException) even
 * when every permission is granted — that restriction is NOT a runtime
 * permission the user can toggle. Instead of silently doing nothing, we play
 * the adhan in-process with a wake lock so the azan still sounds.
 */
class AdhanReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "AdhanReceiver"

        // Held across the broadcast so the process (and the wake lock) survives
        // while the fallback player runs after onReceive returns.
        private var fallbackPlayer: MediaPlayer? = null
        private var fallbackWakeLock: PowerManager.WakeLock? = null
        private var fallbackAudioManager: AudioManager? = null
        private var fallbackPinnedVolume = -1
        private var fallbackPinnedLevel = -1
        private var fallbackPreMediaVolume = -1
        private var fallbackPreRingVolume = -1
        private var fallbackPreNotifVolume = -1
        private val fallbackHandler = Handler(Looper.getMainLooper())
        private var fallbackAppContext: Context? = null

        /** True while the in-process fallback is playing (used by tests). */
        @Volatile
        var isFallbackPlaying: Boolean = false
            private set

        /** Stops the fallback adhan when the user presses the power button. */
        private val fallbackScreenOffReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action == Intent.ACTION_SCREEN_OFF && isFallbackPlaying) {
                    Log.d(TAG, "Fallback: screen off, stopping adhan")
                    stopFallback()
                }
            }
        }

        /**
         * Polling fallback for OEMs that suppress VOLUME_CHANGED_ACTION: while
         * the fallback adhan plays we pin the ALARM stream to max, so any
         * hardware volume-key press changes that level and is detected here,
         * which stops (mutes) the adhan — same UX as the foreground service.
         * All ringer-relevant streams are watched because some OEMs route the
         * keys to RING/NOTIFICATION even while alarm audio is active.
         */
        private val volumeWatch = object : Runnable {
            override fun run() {
                val am = fallbackAudioManager ?: return
                if (fallbackPinnedLevel >= 0) {
                    val changed =
                        am.getStreamVolume(AudioManager.STREAM_ALARM) != fallbackPinnedLevel ||
                            (fallbackPreMediaVolume >= 0 &&
                                am.getStreamVolume(AudioManager.STREAM_MUSIC) != fallbackPreMediaVolume) ||
                            (fallbackPreRingVolume >= 0 &&
                                am.getStreamVolume(AudioManager.STREAM_RING) != fallbackPreRingVolume) ||
                            (fallbackPreNotifVolume >= 0 &&
                                am.getStreamVolume(AudioManager.STREAM_NOTIFICATION) != fallbackPreNotifVolume)
                    if (changed) {
                        Log.d(TAG, "Fallback volume key detected, muting adhan")
                        stopFallback()
                        return
                    }
                }
                fallbackHandler.postDelayed(this, 100L)
            }
        }

        private fun stopFallback() {
            isFallbackPlaying = false
            fallbackHandler.removeCallbacks(volumeWatch)
            try {
                fallbackAppContext?.unregisterReceiver(fallbackScreenOffReceiver)
            } catch (_: Exception) {}
            fallbackAppContext = null
            fallbackPlayer?.apply {
                try {
                    if (isPlaying) stop()
                } catch (e: IllegalStateException) {
                    Log.w(TAG, "Fallback stop() failed: ${e.message}")
                }
                release()
            }
            fallbackPlayer = null

            // Restore the alarm volume we pinned.
            if (fallbackPinnedVolume >= 0) {
                try {
                    fallbackAudioManager?.setStreamVolume(
                        AudioManager.STREAM_ALARM,
                        fallbackPinnedVolume,
                        0
                    )
                    Log.d(TAG, "Fallback restored alarm volume to $fallbackPinnedVolume")
                } catch (e: Exception) {
                    Log.w(TAG, "Fallback volume restore failed: ${e.message}")
                }
                fallbackPinnedVolume = -1
            }
            fallbackPinnedLevel = -1
            fallbackPreMediaVolume = -1
            fallbackPreRingVolume = -1
            fallbackPreNotifVolume = -1
            fallbackAudioManager = null

            fallbackWakeLock?.let {
                if (it.isHeld) it.release()
            }
            fallbackWakeLock = null
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "com.tawheeed.action.ADHAN_ALARM") return

        val prayerName = intent.getStringExtra("prayer_name") ?: "اذان"
        val soundName = intent.getStringExtra("sound_name") ?: "kamel"
        val customPath = intent.getStringExtra("custom_path") ?: ""
        val volume = intent.getFloatExtra("volume", 1.0f)

        Log.d(TAG, "Adhan alarm received for: $prayerName")

        // Start foreground service for audio playback
        val serviceIntent = Intent(context, AzanForegroundService::class.java).apply {
            action = AzanForegroundService.ACTION_PLAY
            putExtra("prayer", prayerName)
            putExtra("sound", soundName)
            putExtra("customPath", customPath)
            putExtra("volume", volume)
        }

        val started = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            true
        } catch (e: Exception) {
            // Android 12+ may throw ForegroundServiceStartNotAllowedException
            // when the app is background-restricted; OEM battery managers throw
            // too. Play the azan in-process instead of crashing/going silent.
            Log.e(TAG, "startForegroundService failed: ${e.message} — using in-process fallback")
            false
        }

        if (!started) {
            playFallback(context, soundName, customPath, volume)
        }

        // The azan alarm fires via setAlarmClock() — exact, Doze-immune. Re-render
        // the prayer widget right now so its baked countdown flips from
        // «X دقیقه تا اذان» to «X دقیقه تا اقامه نماز» the very moment the azan
        // rings, even when the widget's own per-minute chain is deferred by Doze.
        PrayerWidget.refreshAll(context)
    }

    /** Best-effort in-process azan playback (no foreground service required). */
    private fun playFallback(
        context: Context,
        sound: String,
        customPath: String,
        volume: Float,
    ) {
        try {
            stopFallback()
            fallbackAppContext = context.applicationContext

            val audioManager =
                context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            fallbackAudioManager = audioManager

            // Pin the ALARM stream to max so the azan is audible even when the
            // phone's alarm volume is 0 (same policy as the foreground service).
            fallbackPinnedVolume = -1
            fallbackPinnedLevel = -1
            fallbackPreMediaVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
            fallbackPreRingVolume = audioManager.getStreamVolume(AudioManager.STREAM_RING)
            fallbackPreNotifVolume =
                audioManager.getStreamVolume(AudioManager.STREAM_NOTIFICATION)
            try {
                val maxAlarm = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                val currentAlarm = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
                if (currentAlarm < maxAlarm) {
                    audioManager.setStreamVolume(AudioManager.STREAM_ALARM, maxAlarm, 0)
                    fallbackPinnedVolume = currentAlarm
                    fallbackPinnedLevel = maxAlarm
                    Log.d(TAG, "Fallback pinned alarm volume to max ($maxAlarm)")
                } else {
                    // Already at max: the level the user can press away from.
                    fallbackPinnedLevel = currentAlarm
                }
            } catch (e: Exception) {
                Log.w(TAG, "Fallback volume pin failed: ${e.message}")
            }

            // Watch for hardware volume-key presses while the fallback plays.
            fallbackHandler.removeCallbacks(volumeWatch)
            fallbackHandler.post(volumeWatch)

            // Also stop on screen-off (power button press).
            try {
                context.applicationContext.registerReceiver(
                    fallbackScreenOffReceiver,
                    IntentFilter(Intent.ACTION_SCREEN_OFF)
                )
            } catch (e: Exception) {
                Log.w(TAG, "Fallback failed to register screen-off receiver: ${e.message}")
            }

            // Wake lock so the CPU stays on during playback.
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            fallbackWakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "tawheeed:adhan_fallback"
            ).apply {
                acquire(5 * 60 * 1000L) // 5 minutes max
            }

            // Same policy as the foreground service: only a real file inside
            // filesDir/custom_azans is honoured, so a stale or restored path
            // cannot make the app open an arbitrary URI.
            val customFile = AzanAudioResolver.customAzanFileOrNull(
                context.filesDir, customPath
            )
            val audioSource = if (customFile != null) {
                Uri.fromFile(customFile)
            } else {
                if (customPath.isNotEmpty()) {
                    Log.w(TAG, "Custom azan not in custom_azans/, using bundled resource")
                }
                Uri.parse(AzanAudioResolver.bundledAzanUri(context.packageName, sound))
            }
            val safeVolume = AzanAudioResolver.safeVolume(volume)

            val player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setDataSource(context, audioSource)
                setOnPreparedListener { mp ->
                    mp.setVolume(safeVolume, safeVolume)
                    mp.start()
                    isFallbackPlaying = true
                    Log.d(TAG, "Fallback adhan playing")
                }
                setOnCompletionListener {
                    Log.d(TAG, "Fallback adhan completed")
                    stopFallback()
                }
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "Fallback MediaPlayer error: $what, $extra")
                    stopFallback()
                    true
                }
                prepareAsync()
            }
            fallbackPlayer = player
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start fallback adhan: ${e.message}")
            stopFallback()
        }
    }
}
