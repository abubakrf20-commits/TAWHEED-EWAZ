package com.islamic.tawheeed.widget

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/**
 * Pin-time picker that lets each prayer widget instance carry its own palette.
 *
 * It does NOT render the widget itself. It only persists a per-instance palette
 * id (`widget_palette_id_prayer_<appWidgetId>`, read by [WidgetTheme.resolve`),
 * then returns [Activity.RESULT_OK] with the widget id. The system calls the
 * provider's `onUpdate` afterwards, which repaints the card with the chosen
 * palette. The «پیش‌فرض» button removes the override so the card falls back to
 * the shared prayer palette.
 *
 * Both the horizontal ([PrayerWidget]) and vertical ([PrayerWidgetVertical])
 * prayer providers use this activity (via `android:configure`), so a single
 * picker serves every prayer card regardless of orientation.
 */
class PrayerWidgetConfigureActivity : Activity() {
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        appWidgetId = intent?.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        // Launched without a widget id → nothing to configure; cancel so the
        // system does not strand a half-added widget.
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            setResult(RESULT_CANCELED)
            finish()
            return
        }

        val spec = WidgetTheme.loadSpec(this)
        val prefs = WidgetRepository.prefs(this)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(0xFFF2F2F2.toInt())
            setPadding(36, 36, 36, 36)
        }

        TextView(this).apply {
            text = "انتخاب تم ویجت"
            textSize = 18f
            setTextColor(0xFF1B1B1F.toInt())
            setPadding(0, 0, 0, 24)
            root.addView(this)
        }

        val bottomMargin = 16
        for (palette in spec.palettes) {
            val btn = Button(this).apply {
                text = palette.id
                setBackgroundColor(palette.bg)
                setTextColor(palette.text)
                setPadding(0, 24, 0, 24)
                val lp = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { this.bottomMargin = bottomMargin }
                layoutParams = lp
                setOnClickListener {
                    prefs.edit()
                        .putString("widget_palette_id_prayer_$appWidgetId", palette.id)
                        .apply()
                    finishWithResult()
                }
            }
            root.addView(btn)
        }

        // Use the shared prayer palette (no per-instance override).
        Button(this).apply {
            text = "پیش‌فرض"
            setBackgroundColor(0xFFE0E0E0.toInt())
            setTextColor(0xFF1B1B1F.toInt())
            setPadding(0, 24, 0, 24)
            val lp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { this.bottomMargin = bottomMargin }
            layoutParams = lp
            setOnClickListener {
                prefs.edit().remove("widget_palette_id_prayer_$appWidgetId").apply()
                finishWithResult()
            }
        }.also { root.addView(it) }

        setContentView(ScrollView(this).apply { addView(root) })
    }

    private fun finishWithResult() {
        val result = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        setResult(RESULT_OK, result)
        finish()
    }
}
