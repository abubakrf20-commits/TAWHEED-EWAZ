package com.islamic.tawheeed.core

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context

/**
 * Native notification channels.
 *
 * Only the two channels native code actually posts on are created here.  Every
 * reminder channel (prayer, azkar, events, daily, quran, khatm, friday …) is
 * created by FlutterLocalNotificationsPlugin in notification_service.dart.
 * When this file re-created the old reminder IDs on every launch they came back
 * beside their Dart `_v3` replacements, so the user saw two entries per topic
 * in Android settings and could silence the wrong one.
 */
object NotificationChannelManager {

    // ─── Channels native code posts on ─────────────────────
    const val CH_ADHAN = "adhan_playback"
    const val CH_GENERAL = "general"

    // ─── Notification IDs ──────────────────────────────────
    const val NOTIF_ID_ADHAN = 5000

    /**
     * IDs created by older builds of THIS file (and by the Dart side before its
     * `_v3` rename).  They are deleted, never re-created — the live reminder
     * channels are owned by [io.flutter.plugins.flutterlocalnotifications].
     */
    private val LEGACY_CHANNEL_IDS = listOf(
        // Created by this manager before 2026-10-19.
        "prayer_reminders",
        "daily_azkar",
        "daily_reminders",
        "quran_reminder",
        "silent_mode",
        // Pre-v3 Dart channels; notification_service.dart deletes the same set.
        "custom_reminders",
        "azkar_reminder",
        "azkar_reminder_v2",
        "islamic_events",
        "islamic_events_v2",
        "daily_reminders_v2",
        "quran_reminder_v2",
        "khatm_reminder",
        "khatm_reminder_v2",
        "friday_reminder",
        "friday_reminder_v2",
        "prayer_times",
    )

    fun createAllChannels(context: Context) {
        val nm =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // ── Adhan channel migration ──────────────────────────────────────────
        // The adhan audio is streamed by the foreground-service MediaPlayer, so the
        // notification channel MUST be silent.  Older builds created this channel
        // with IMPORTANCE_HIGH + an alarm sound, which produced a second unwanted
        // chime on top of the actual adhan.  Android does not let us change the
        // properties of an existing channel, so we delete the old one when it still
        // carries a sound — it will be recreated silently below.
        val oldAdhan = nm.getNotificationChannel(CH_ADHAN)
        if (oldAdhan != null && oldAdhan.sound != null) {
            nm.deleteNotificationChannel(CH_ADHAN)
        }

        // Remove stale channels instead of resurrecting them on every launch.
        LEGACY_CHANNEL_IDS.forEach { id ->
            if (nm.getNotificationChannel(id) != null) {
                nm.deleteNotificationChannel(id)
            }
        }

        val channels = listOf(
            // Adhan playback channel — SILENT.  The foreground service's MediaPlayer
            // handles all audio; the notification only needs to be visible.
            NotificationChannel(
                CH_ADHAN,
                "پخش اذان",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "کانال پخش صدای اذان نماز"
                setShowBadge(false)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            },

            // Fallback channel for native reminders that do not name one.
            NotificationChannel(
                CH_GENERAL,
                "عمومی",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "اعلان‌های عمومی برنامه"
            },
        )

        channels.forEach { nm.createNotificationChannel(it) }
    }
}
