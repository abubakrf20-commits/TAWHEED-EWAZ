package com.islamic.tawheeed.widget

import android.content.Context
import android.util.Log

/**
 * The app's single "repaint every widget" entry point: the Dart side calls it
 * after a snapshot push or a theme change.
 *
 * The prayer card is still a Glance composition, so it is asked to re-compose;
 * the tasbih card is a hand-built RemoteViews and is rebuilt directly. Both
 * chains re-arm their alarms, because the render is what makes the boundary
 * alarms match the freshly stored times.
 */
object WidgetHub {
    private const val TAG = "WidgetHub"

    fun refreshAll(context: Context) {
        try {
            PrayerWidget.refreshAll(context)
        } catch (e: Throwable) {
            Log.w(TAG, "PrayerWidget refresh failed: ${e.message}")
        }
        // A full rebuild, not a partial one: a snapshot can change the palette,
        // the dhikr list or the targets, and those live in the chrome.
        try {
            TasbihGlanceWidgetReceiver.renderAll(context)
        } catch (e: Throwable) {
            Log.w(TAG, "TasbihWidget refresh failed: ${e.message}")
        }
    }
}
