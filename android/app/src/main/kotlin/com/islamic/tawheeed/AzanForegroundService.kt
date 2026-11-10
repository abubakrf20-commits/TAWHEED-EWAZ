package com.islamic.tawheeed

import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.islamic.tawheeed.core.AzanAudioResolver
import com.islamic.tawheeed.core.NotificationChannelManager

/**
 * Foreground service for Adhan audio playback.
 * - Runs as foreground service with persistent notification
 * - Requests audio focus
 * - Holds wake lock during playback
 * - Auto-stops when adhan finishes
 * - Survives Doze mode and screen-off
 * - Adhan loudness follows ONLY the app's volume setting (alarm stream is
 *   pinned to max while playing and restored afterwards)
 * - Hardware volume keys act as a mute switch: any volume change stops the
 *   adhan (broadcast + polling fallback)
 */
class AzanForegroundService : Service() {
    companion object {
        private const val TAG = "AzanForegroundService"
        const val ACTION_PLAY = "com.tawheeed.action.PLAY_ADHAN"
        const val ACTION_STOP = "com.tawheeed.action.STOP_ADHAN"

        private var _isPlaying = false
        fun isPlaying() = _isPlaying
    }

    private var mediaPlayer: MediaPlayer? = null
    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var playbackVolume = 1.0f
    private var useMusicStream = false
    private var pinnedMusicVolume = -1
    private val mainHandler = Handler(Looper.getMainLooper())

    // ── Volume-key mute support ──────────────────────────────────────────────
    // While the adhan plays we pin the ALARM stream to max so the adhan sounds
    // exactly as configured in the app; any hardware volume-key press changes
    // that level and therefore mutes (stops) the adhan. The previous levels
    // are restored on stop so the rest of the phone is unaffected.
    private var preAdhanAlarmVolume = -1
    private var pinnedAlarmVolume = -1
    private var preAdhanMediaVolume = -1
    private var preAdhanRingVolume = -1
    private var preAdhanNotifVolume = -1

    /** Immediate detection of any volume change while the adhan is playing. */
    private val volumeKeyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == "android.media.VOLUME_CHANGED_ACTION") {
                Log.d(TAG, "Volume changed while adhan playing, muting")
                stopAdhan()
            }
        }
    }

    /** Stops the adhan when the user presses the power button (screen off). */
    private val screenOffReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == Intent.ACTION_SCREEN_OFF) {
                Log.d(TAG, "Screen off while adhan playing, muting")
                stopAdhan()
            }
        }
    }

    /** Polling fallback for OEMs that suppress the VOLUME_CHANGED broadcast.
     *  Watches ALL ringer-relevant streams: some OEMs route the hardware keys
     *  to RING/NOTIFICATION even while USAGE_ALARM audio plays, so watching
     *  only ALARM/MUSIC misses the press and the adhan keeps playing.
     *
     * Cadence: 300 ms, not the old 100 ms. A human cannot press a volume key
     * and release it inside 300 ms, so a press is still caught within a third
     * of a second — but the main thread stops running a 10 Hz loop for the
     * whole adhan, which is minutes of sustained wakeups per prayer. */
    private val volumePollIntervalMs = 300L

    private val volumeWatch = object : Runnable {
        override fun run() {
            val am = audioManager
            if (am != null && pinnedAlarmVolume >= 0) {
                val alarmVol = am.getStreamVolume(AudioManager.STREAM_ALARM)
                val mediaVol = am.getStreamVolume(AudioManager.STREAM_MUSIC)
                val ringVol = am.getStreamVolume(AudioManager.STREAM_RING)
                val notifVol = am.getStreamVolume(AudioManager.STREAM_NOTIFICATION)
                // When the muted-alarm fallback raised the music volume, compare
                // against the raised level so our own boost isn't mistaken for a
                // volume-key press.
                val expectedMedia =
                    if (pinnedMusicVolume >= 0) pinnedMusicVolume
                    else preAdhanMediaVolume
                val changed =
                    alarmVol != pinnedAlarmVolume ||
                        (expectedMedia >= 0 && mediaVol != expectedMedia) ||
                        (preAdhanRingVolume >= 0 && ringVol != preAdhanRingVolume) ||
                        (preAdhanNotifVolume >= 0 && notifVol != preAdhanNotifVolume)
                if (changed) {
                    Log.d(TAG, "Volume key detected (poll), muting adhan")
                    stopAdhan()
                    return
                }
            }
            mainHandler.postDelayed(this, volumePollIntervalMs)
        }
    }

    /** Watches for an active phone call (ringing / in-call / VoIP) and stops the
     *  adhan immediately. `USAGE_ALARM` keeps the adhan under the hardware
     *  volume buttons, but it must NEVER play over a phone conversation.
     *  Polling [AudioManager.mode] needs no extra permission (unlike
     *  PhoneStateListener).
     */
    private val callWatch = object : Runnable {
        override fun run() {
            val mode = audioManager?.mode ?: AudioManager.MODE_NORMAL
            if (mode == AudioManager.MODE_RINGTONE ||
                mode == AudioManager.MODE_IN_CALL ||
                mode == AudioManager.MODE_IN_COMMUNICATION
            ) {
                Log.d(TAG, "Phone call detected (mode=$mode), stopping adhan")
                stopAdhan()
            } else {
                mainHandler.postDelayed(this, 1000L)
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        // Safety net: ensure the FGS notification channel exists even when the
        // process was spawned directly by an alarm without a full app init.
        try {
            NotificationChannelManager.createAllChannels(this)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to create channels: ${e.message}")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY -> {
                val prayer = intent.getStringExtra("prayer") ?: "اذان"
                val sound = intent.getStringExtra("sound") ?: "kamel"
                val customPath = intent.getStringExtra("customPath") ?: ""
                val volume = intent.getFloatExtra("volume", 1.0f)
                startAdhan(prayer, sound, customPath, volume)
            }
            ACTION_STOP -> {
                stopAdhan()
            }
        }
        return START_NOT_STICKY
    }

    private fun startAdhan(prayer: String, sound: String, customPath: String, volume: Float = 1.0f) {
        Log.d(TAG, "Starting adhan: $prayer, sound: $sound")

        // Start foreground immediately (required within 5 seconds on Android 8+).
        // Guarded so a restrictive OEM / Android 12+ background limit can't crash
        // the whole process (ForegroundServiceStartNotAllowedException). This also
        // satisfies the FGS contract BEFORE the call check below, so skipping the
        // audio during a call can never trigger ForegroundServiceDidNotStartInTimeException.
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                try {
                    startForeground(NotificationChannelManager.NOTIF_ID_ADHAN, buildNotification(prayer), android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
                } catch (e: Exception) {
                    // Some OEMs reject a typed mediaPlayback FGS when started from
                    // the background (Android 14 restrictions). Retry without the
                    // type so the adhan still plays on those phones.
                    Log.w(TAG, "Typed startForeground failed, retrying plain: ${e.message}")
                    startForeground(NotificationChannelManager.NOTIF_ID_ADHAN, buildNotification(prayer))
                }
            } else {
                startForeground(NotificationChannelManager.NOTIF_ID_ADHAN, buildNotification(prayer))
            }
        } catch (e: Exception) {
            Log.e(TAG, "startForeground failed: ${e.message}")
            stopSelf()
            return
        }

        // Never play over an active call — check before starting and keep
        // watching while playing (see [callWatch]). The prayer-time notification
        // scheduled by the Flutter layer still appears, so the user is reminded
        // without the azan audio (only the notification comes through).
        val initialMode = audioManager?.mode ?: AudioManager.MODE_NORMAL
        if (initialMode == AudioManager.MODE_RINGTONE ||
            initialMode == AudioManager.MODE_IN_CALL ||
            initialMode == AudioManager.MODE_IN_COMMUNICATION
        ) {
            Log.d(TAG, "Already in a call (mode=$initialMode), skipping adhan audio")
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return
        }

        // Acquire wake lock
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "tawheeed:adhan_wakelock"
        ).apply {
            acquire(5 * 60 * 1000L) // 5 minutes max
        }

        // Request audio focus
        requestAudioFocus()

        // Start watching for an incoming/active phone call.
        mainHandler.post(callWatch)

        // Pin the ALARM stream to max so the adhan volume follows ONLY the app
        // setting (and volume-key presses become detectable as a mute gesture).
        pinAlarmVolume()

        // If the ALARM stream is still muted after pinning (some OEMs block
        // programmatic volume changes, or the device has no alarm stream),
        // fall back to the MUSIC stream so the azan is still audible.
        val alarmVol =
            audioManager?.getStreamVolume(AudioManager.STREAM_ALARM) ?: 0
        useMusicStream = alarmVol == 0
        if (useMusicStream) {
            Log.w(TAG, "Alarm stream muted after pin — playing on music stream")
            try {
                val maxMusic =
                    audioManager?.getStreamMaxVolume(AudioManager.STREAM_MUSIC) ?: 0
                val currentMusic =
                    audioManager?.getStreamVolume(AudioManager.STREAM_MUSIC) ?: 0
                if (currentMusic == 0 && maxMusic > 0) {
                    audioManager?.setStreamVolume(AudioManager.STREAM_MUSIC, maxMusic, 0)
                    pinnedMusicVolume = maxMusic
                }
            } catch (e: Exception) {
                Log.w(TAG, "Music volume boost failed: ${e.message}")
            }
        }

        // Watch for hardware volume-key presses while the adhan is playing.
        // Registered after pinAlarmVolume() so our own volume change is not
        // mistaken for a user press.
        try {
            ContextCompat.registerReceiver(
                this,
                volumeKeyReceiver,
                IntentFilter("android.media.VOLUME_CHANGED_ACTION"),
                ContextCompat.RECEIVER_NOT_EXPORTED
            )
            ContextCompat.registerReceiver(
                this,
                screenOffReceiver,
                IntentFilter(Intent.ACTION_SCREEN_OFF),
                ContextCompat.RECEIVER_NOT_EXPORTED
            )
            mainHandler.post(volumeWatch)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to register volume receiver: ${e.message}")
        }

        // Build audio source. A custom azan is only honoured when it is a real
        // file inside filesDir/custom_azans — see AzanAudioResolver — otherwise
        // we fall back to the bundled resource instead of parsing whatever URI
        // the extras happened to carry.
        val customFile = AzanAudioResolver.customAzanFileOrNull(filesDir, customPath)
        val audioSource = if (customFile != null) {
            // Uri.fromFile: a bare absolute path parsed as a URI has no scheme
            // and fails on some OEM MediaPlayer builds (adhan silently skipped).
            Uri.fromFile(customFile)
        } else {
            if (customPath.isNotEmpty()) {
                Log.w(TAG, "Custom azan not in custom_azans/, using bundled resource")
            }
            Uri.parse(AzanAudioResolver.bundledAzanUri(packageName, sound))
        }

        // Play audio on the ALARM stream (USAGE_ALARM) so it is independent of
        // the media volume: the adhan always sounds exactly as configured in
        // the app, and the hardware volume buttons act as a mute switch.
        // Falls back to the MUSIC stream when the alarm stream is muted.
        try {
            playbackVolume = AzanAudioResolver.safeVolume(volume)
            mediaPlayer?.release()
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(AudioAttributes.Builder()
                    .setUsage(
                        if (useMusicStream) AudioAttributes.USAGE_MEDIA
                        else AudioAttributes.USAGE_ALARM
                    )
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build())
                setDataSource(this@AzanForegroundService, audioSource)
                setOnPreparedListener { mp ->
                    mp.setVolume(volume, volume)
                    mp.start()
                    _isPlaying = true
                    Log.d(TAG, "Adhan playing")
                }
                setOnCompletionListener {
                    Log.d(TAG, "Adhan completed")
                    stopAdhan()
                }
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "MediaPlayer error: $what, $extra")
                    stopAdhan()
                    true
                }
                prepareAsync()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start adhan: ${e.message}")
            stopAdhan()
        }
    }

    private fun pinAlarmVolume() {
        val am = audioManager ?: return
        try {
            val maxAlarm = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            preAdhanAlarmVolume = am.getStreamVolume(AudioManager.STREAM_ALARM)
            preAdhanMediaVolume = am.getStreamVolume(AudioManager.STREAM_MUSIC)
            preAdhanRingVolume = am.getStreamVolume(AudioManager.STREAM_RING)
            preAdhanNotifVolume =
                am.getStreamVolume(AudioManager.STREAM_NOTIFICATION)
            if (preAdhanAlarmVolume < maxAlarm) {
                am.setStreamVolume(AudioManager.STREAM_ALARM, maxAlarm, 0)
                pinnedAlarmVolume = maxAlarm
                Log.d(TAG, "Pinned alarm volume to max ($maxAlarm) for adhan")
            } else {
                pinnedAlarmVolume = preAdhanAlarmVolume
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to pin alarm volume: ${e.message}")
            pinnedAlarmVolume = preAdhanAlarmVolume
        }
    }

    private fun restoreAlarmVolume() {
        // Restore the music volume raised by the muted-alarm fallback.
        if (useMusicStream && preAdhanMediaVolume >= 0) {
            try {
                val current = audioManager?.getStreamVolume(AudioManager.STREAM_MUSIC) ?: 0
                if (current != preAdhanMediaVolume) {
                    audioManager?.setStreamVolume(
                        AudioManager.STREAM_MUSIC,
                        preAdhanMediaVolume,
                        0
                    )
                    Log.d(TAG, "Restored music volume to $preAdhanMediaVolume")
                }
            } catch (e: Exception) {
                Log.w(TAG, "Failed to restore music volume: ${e.message}")
            }
            pinnedMusicVolume = -1
            useMusicStream = false
        }
        if (pinnedAlarmVolume < 0 || preAdhanAlarmVolume < 0) return
        try {
            val current = audioManager?.getStreamVolume(AudioManager.STREAM_ALARM) ?: return
            if (current != preAdhanAlarmVolume) {
                audioManager?.setStreamVolume(AudioManager.STREAM_ALARM, preAdhanAlarmVolume, 0)
                Log.d(TAG, "Restored alarm volume to $preAdhanAlarmVolume")
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to restore alarm volume: ${e.message}")
        } finally {
            pinnedAlarmVolume = -1
        }
    }

    private fun stopAdhan() {
        _isPlaying = false
        mainHandler.removeCallbacks(callWatch)
        mainHandler.removeCallbacks(volumeWatch)

        try {
            unregisterReceiver(volumeKeyReceiver)
        } catch (e: Exception) {
            // Not registered (never started or already unregistered).
        }
        try {
            unregisterReceiver(screenOffReceiver)
        } catch (e: Exception) {
            // Not registered.
        }

        // Undo the volume pinning so the phone behaves normally afterwards.
        restoreAlarmVolume()

        mediaPlayer?.apply {
            try {
                if (isPlaying) stop()
            } catch (e: IllegalStateException) {
                Log.w(TAG, "MediaPlayer.stop() failed: ${e.message}")
            }
            release()
        }
        mediaPlayer = null

        releaseAudioFocus()
        releaseWakeLock()

        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun requestAudioFocus() {
        val focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
            .setAudioAttributes(AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build())
            .setOnAudioFocusChangeListener { focusChange ->
                when (focusChange) {
                    AudioManager.AUDIOFOCUS_LOSS -> {
                        // Permanent loss — another app definitively took over the
                        // audio (a real phone call, a voice assistant, etc.).
                        Log.d(TAG, "Audio focus lost permanently, stopping")
                        stopAdhan()
                    }
                    AudioManager.AUDIOFOCUS_LOSS_TRANSIENT,
                    AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                        // Transient loss from a notification / message tone or
                        // other momentary sound: KEEP the adhan ringing. A real
                        // phone call is still caught by the mode-based callWatch
                        // (MODE_RINGTONE / IN_CALL / IN_COMMUNICATION), so the
                        // adhan only stops on an actual call or a volume-key tap.
                        Log.d(TAG, "Transient audio focus loss — keeping adhan")
                    }
                    AudioManager.AUDIOFOCUS_GAIN -> {
                        mediaPlayer?.setVolume(playbackVolume, playbackVolume)
                    }
                }
            }
            .build()

        audioFocusRequest = focusRequest
        audioManager?.requestAudioFocus(focusRequest)
    }

    private fun releaseAudioFocus() {
        audioFocusRequest?.let {
            audioManager?.abandonAudioFocusRequest(it)
        }
    }

    private fun acquireWakeLock() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "tawheeed:adhan_wakelock"
        ).apply {
            acquire(5 * 60 * 1000L)
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
    }

    private fun buildNotification(prayer: String): Notification {
        val stopIntent = Intent(this, AzanForegroundService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 0, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Tapping the notification opens the app
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            this, 1, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Map English prayer names to Farsi for display
        val displayPrayer = when (prayer.lowercase()) {
            "fajr" -> "فجر"
            "dhuhr" -> "ظهر"
            "asr" -> "عصر"
            "maghrib" -> "مغرب"
            "isha" -> "عشاء"
            else -> prayer // Already Farsi or custom
        }

        val largeIcon = BitmapFactory.decodeResource(resources, R.drawable.ic_notification_logo)

        return NotificationCompat.Builder(this, NotificationChannelManager.CH_ADHAN)
            .setContentTitle("اذان $displayPrayer")
            .setContentText("در حال پخش اذان...")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setLargeIcon(largeIcon)
            .setColor(0xFFC48A27.toInt())
            .setContentIntent(openAppPendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .addAction(android.R.drawable.ic_media_pause, "توقف اذان", stopPendingIntent)
            .build()
    }

    private fun getResId(assetPath: String): Int {
        val name = assetPath.substringAfterLast('/').substringBeforeLast('.')
        return resources.getIdentifier(name, "raw", packageName)
    }

    override fun onDestroy() {
        stopAdhan()
        super.onDestroy()
    }
}
