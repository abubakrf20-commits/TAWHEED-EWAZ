package com.islamic.tawheeed.core

import android.content.Context
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat

/**
 * Notification helpers. All notification channel IDs live in
 * [NotificationChannelManager] (single source of truth shared with Dart).
 */
object NotificationHelper {

    fun isPermissionGranted(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            NotificationManagerCompat.from(context).areNotificationsEnabled()
        } else {
            true
        }
    }

    fun openNotificationSettings(context: Context) {
        val intent = android.content.Intent(
            Settings.ACTION_APP_NOTIFICATION_SETTINGS
        ).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
        }
        context.startActivity(intent)
    }
}
