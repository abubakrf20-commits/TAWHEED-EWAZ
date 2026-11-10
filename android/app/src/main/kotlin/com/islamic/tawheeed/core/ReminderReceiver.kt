package com.islamic.tawheeed.core

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.islamic.tawheeed.MainActivity
import org.json.JSONObject

/**
 * Fires an exact-time reminder notification. Called by the native alarm armed in
 * [ExactReminderScheduler] and by the shared Flutter→native bridge. Reads the
 * reminder content that was persisted at schedule time and posts a notification
 * on the same channel ID the Flutter plugin uses, so the two never conflict.
 */
class ReminderReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ReminderReceiver"

        /** Broadcast that the notification's «توقف صدا» action sends back here. */
        const val ACTION_STOP_SOUND = "com.tawheeed.action.STOP_REMINDER_SOUND"

        private val channelImports = mapOf(
            "custom_reminders_v2" to NotificationManager.IMPORTANCE_HIGH,
            "prayer_times_v5" to NotificationManager.IMPORTANCE_HIGH,
            "azkar_reminder_v3" to NotificationManager.IMPORTANCE_HIGH,
            "islamic_events_v3" to NotificationManager.IMPORTANCE_HIGH,
            "daily_reminders_v3" to NotificationManager.IMPORTANCE_HIGH,
            "quran_reminder_v3" to NotificationManager.IMPORTANCE_HIGH,
            "khatm_reminder_v3" to NotificationManager.IMPORTANCE_HIGH,
            "friday_reminder_v3" to NotificationManager.IMPORTANCE_HIGH,
        )

        /** In-process player for a reminder's custom sound file (see [post]). */
        private var customPlayer: MediaPlayer? = null

        /** Wake lock held while a custom reminder sound plays. */
        private var customWakeLock: PowerManager.WakeLock? = null

        fun ensureChannel(context: Context, channelId: String, soundName: String?) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(channelId) != null) return
            val importance = channelImports[channelId] ?: NotificationManager.IMPORTANCE_HIGH
            val ch = NotificationChannel(channelId, channelId, importance).apply {
                describeContents()
            }
            if (isCustomSound(soundName) || isSystemSound(soundName)) {
                // A file path (or a system `content://` URI) cannot be a
                // channel sound at all, and channels are immutable once
                // created: the sound plays in-process in post(), so the
                // channel itself stays silent.
                ch.setSound(null, null)
            } else if (!soundName.isNullOrEmpty() && soundName != "silent") {
                val uri = notificationSoundUri(context, soundName)
                if (uri != null) ch.setSound(uri, null)
            } else {
                ch.setSound(null, null)
            }
            try {
                nm.createNotificationChannel(ch)
            } catch (e: Exception) {
                Log.w(TAG, "create channel $channelId failed: ${e.message}")
            }
        }

        private fun isCustomSound(soundName: String?): Boolean =
            soundName?.startsWith("custom:") == true

        private fun customPathOf(soundName: String?): String =
            if (isCustomSound(soundName)) soundName!!.substringAfter("custom:") else ""

        /** `system:<kind>:<uri>` — a phone tone chosen from the picker. */
        private fun isSystemSound(soundName: String?): Boolean =
            soundName?.startsWith("system:") == true

        /** The URI half of `system:<kind>:<uri>`; kind is `alarm` or a tone. */
        private fun systemUriOf(soundName: String?): Uri? {
            if (!isSystemSound(soundName)) return null
            val rest = soundName!!.substringAfter("system:")
            val uri = rest.substringAfter(":", "")
            if (uri.isBlank()) return null
            return try {
                Uri.parse(uri)
            } catch (_: Exception) {
                null
            }
        }

        private fun isAlarmSound(soundName: String?): Boolean =
            soundName?.startsWith("system:alarm:") == true

        /** Stops any custom reminder sound still playing (a new fire or a
         *  re-arm must never layer over the previous file). */
        fun stopCustom() {
            try {
                customPlayer?.stop()
            } catch (_: Throwable) {}
            try {
                customPlayer?.release()
            } catch (_: Throwable) {}
            customPlayer = null
            try {
                if (customWakeLock?.isHeld == true) customWakeLock?.release()
            } catch (_: Throwable) {}
            customWakeLock = null
        }

        private fun notificationSoundUri(context: Context, soundName: String): Uri? {
            return when (soundName) {
                "ios17", "notif", "azan_takbir", "azan_takbir_short", "azan_kamel" ->
                    Uri.parse("android.resource://${context.packageName}/raw/$soundName")
                else ->
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            }
        }

        fun post(
            context: Context,
            id: Int,
            title: String,
            body: String,
            channelId: String,
            soundName: String?,
            payload: String,
        ) {
            if (!NotificationHelper.isPermissionGranted(context)) return
            ensureChannel(context, channelId, soundName)

            val openIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
                putExtra("notification_payload", payload)
                flags =
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val contentPi = PendingIntent.getActivity(
                context,
                id,
                openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // Tawheed logo as the large icon so reminders are instantly
            // recognizable — same artwork as the Flutter-plugin notifications.
            val logo = BitmapFactory.decodeResource(
                context.resources,
                com.islamic.tawheeed.R.drawable.ic_notification_logo
            )

            val builder = NotificationCompat.Builder(context, channelId)
                .setSmallIcon(com.islamic.tawheeed.R.drawable.ic_notification)
                .setLargeIcon(logo)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setColor(0xFFC48A27.toInt())
                .setAutoCancel(true)
                .setContentIntent(contentPi)

            // A custom file or a phone tone plays in-process below: the
            // notification itself must stay silent, or the channel default
            // would sound on top of (or, on channels created with a sound,
            // instead of) the chosen sound. A missing file falls back to the
            // default ringtone so the reminder is never silent.
            if (isCustomSound(soundName)) {
                val customFile = AzanAudioResolver.customReminderFileOrNull(
                    context.filesDir, customPathOf(soundName)
                )
                if (customFile != null) {
                    builder.setSilent(true)
                    builder.addAction(
                        android.R.drawable.ic_media_pause,
                        "توقف صدا",
                        stopSoundIntent(context, id)
                    )
                    playCustomFile(context.applicationContext, customFile)
                } else {
                    Log.w(TAG, "Custom reminder sound missing for $id, using default")
                    builder.setSound(
                        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                    )
                }
            } else if (isSystemSound(soundName)) {
                val uri = systemUriOf(soundName)
                if (uri != null) {
                    builder.setSilent(true)
                    builder.addAction(
                        android.R.drawable.ic_media_pause,
                        "توقف صدا",
                        stopSoundIntent(context, id)
                    )
                    playUri(
                        context.applicationContext,
                        uri,
                        alarm = isAlarmSound(soundName)
                    )
                } else {
                    Log.w(TAG, "System reminder sound malformed for $id, using default")
                    builder.setSound(
                        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                    )
                }
            }

            try {
                NotificationManagerCompat.from(context).notify(id, builder.build())
                Log.d(TAG, "Posted reminder $id: $title (channel $channelId)")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to post reminder $id: ${e.message}")
            }
        }

        /** The «توقف صدا» action: a broadcast straight back to this receiver. */
        private fun stopSoundIntent(context: Context, id: Int): PendingIntent =
            PendingIntent.getBroadcast(
                context,
                id + 900000,
                Intent(context, ReminderReceiver::class.java).apply {
                    action = ACTION_STOP_SOUND
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

        /**
         * Plays a reminder's custom sound file in-process.
         *
         *  A `file://` path can never work as a notification-channel sound:
         *  channels only resolve raw resources, and the system process that
         *  plays channel sounds cannot read app-private files at all — which
         *  is why custom reminder sounds always degraded to the default.
         *  Playing here (USAGE_NOTIFICATION, so the user's notification volume
         *  and Do-Not-Disturb apply) is the only path that honours the file.
         */
        private fun playCustomFile(context: Context, file: java.io.File) {
            playUri(context, Uri.fromFile(file), alarm = false)
        }

        /** In-process playback for a picked file or a system tone URI. */
        private fun playUri(context: Context, uri: Uri, alarm: Boolean) {
            stopCustom()
            try {
                val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                customWakeLock = pm.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK, "tawheeed:reminder_custom"
                ).apply { acquire(3 * 60 * 1000L) }
            } catch (e: Exception) {
                Log.w(TAG, "Custom wake lock failed: ${e.message}")
            }
            try {
                customPlayer = MediaPlayer().apply {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(
                                if (alarm) AudioAttributes.USAGE_ALARM
                                else AudioAttributes.USAGE_NOTIFICATION
                            )
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    setDataSource(context, uri)
                    setOnPreparedListener { mp -> mp.start() }
                    setOnCompletionListener { stopCustom() }
                    setOnErrorListener { _, what, extra ->
                        Log.e(TAG, "Reminder sound player error: $what, $extra")
                        stopCustom()
                        true
                    }
                    prepareAsync()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Reminder sound playback failed: ${e.message}")
                stopCustom()
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        // The notification's stop action: silence the in-process player only.
        if (intent.action == ACTION_STOP_SOUND) {
            stopCustom()
            return
        }
        if (intent.action != "com.tawheeed.action.REMINDER_ALARM") return
        val id = intent.getIntExtra("id", -1)
        if (id < 0) return

        val spec = ExactReminderScheduler.load(context, id) ?: run {
            Log.w(TAG, "Reminder $id fired but had no persisted content; dropping")
            return
        }

        val title = spec.optString("title", "")
        val body = spec.optString("body", "")
        val channel = spec.optString("channel", "general")
        val sound = spec.optString("sound", "").ifEmpty { null }
        val payload = spec.optString("payload", "")
        post(context, id, title, body, channel, sound, payload)

        // Self-healing repeat: roll the next occurrence forward from the stored
        // trigger (not now+interval, so the wall-clock hour stays put) and re-arm.
        val trigger = spec.optLong("trigger", -1)
        val repeat = spec.optLong("repeat_daily", -1)
        if (repeat > 0) {
            var next = if (trigger > 0) trigger else System.currentTimeMillis()
            while (next <= System.currentTimeMillis()) next += repeat
            ExactReminderScheduler.schedule(
                context = context,
                id = id,
                triggerTimeMillis = next,
                title = title,
                body = body,
                channelId = channel,
                sound = sound,
                payload = payload,
                repeatDailyMillis = repeat,
            )
        }
    }
}
