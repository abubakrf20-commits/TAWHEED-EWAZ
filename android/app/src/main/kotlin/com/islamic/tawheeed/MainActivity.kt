package com.islamic.tawheeed

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.app.NotificationManager
import android.util.Log
import android.media.AudioManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.HandlerThread
import android.os.StatFs
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.edit
import com.islamic.tawheeed.core.AppLiveness
import com.islamic.tawheeed.core.AzanAudioResolver
import com.islamic.tawheeed.core.ExactAlarmHelper
import com.islamic.tawheeed.core.ExactReminderScheduler
import com.islamic.tawheeed.core.NotificationHelper
import com.islamic.tawheeed.core.SystemSoundCatalog
import com.islamic.tawheeed.widget.PrayerWidget
import com.islamic.tawheeed.widget.PrayerWidgetVertical
import com.islamic.tawheeed.widget.TasbihGlanceWidgetReceiver
import com.islamic.tawheeed.widget.WidgetRepository
import com.islamic.tawheeed.widget.WidgetHub
import com.islamic.tawheeed.widget.WidgetPrefs
import com.islamic.tawheeed.widget.WidgetTheme
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.tawheeed/widgets"
        private const val AZAN_CHANNEL = "com.tawheeed/azan"
        private const val ALARMS_CHANNEL = "com.tawheeed/alarms"
        private const val SETTINGS_CHANNEL = "com.tawheeed/settings"
        private const val SILENT_CHANNEL = "com.tawheeed/silent"
        private const val SCHEDULER_CHANNEL = "com.tawheeed/prayer_scheduler"
        private const val STORAGE_CHANNEL = "com.tawheeed/storage"
        private const val MAGNETIC_CHANNEL = "com.tawheeed/magnetic_declination"
        private const val NATIVE_BACKGROUND_CHANNEL = "com.tawheeed/native_background"
        private const val REMINDERS_CHANNEL = "com.tawheeed/exact_reminders"
        private const val PICK_AUDIO_REQUEST = 1001
        private const val PICK_BACKUP_REQUEST = 1002
        private const val PICK_DIR_REQUEST = 1003
        private const val SPLASH_EXIT_FADE_MS = 200L
        const val EXTRA_SHORTCUT = "com.islamic.tawheeed.SHORTCUT"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        fadeOutSystemSplash()
        super.onCreate(savedInstanceState)
        handleWidgetShortcut(intent)
        handleNotificationTapIntent(intent)
    }

    /**
     * Android 12+ (API 31) keeps its system splash until the window has drawn,
     * then cuts to the app hard. That window is now the bare gradient field
     * with no icon in it (see values-v31/styles.xml) — the same picture the
     * Flutter splash paints — so the only thing this fade smooths is the edge
     * where the two windows meet, and the coin appears once, on the real
     * splash. Without the fade the cut would blink the status-bar and
     * navigation-bar tint.
     * Must be installed before [super.onCreate]: the listener has to be in
     * place by the time the system decides to dismiss.
     */
    private fun fadeOutSystemSplash() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        try {
            // The splash handle is an Activity member (Activity.getSplashScreen(),
            // API 31+), not a Window property; and the exit callback hands over
            // the splash view itself — android.window.SplashScreenView extends
            // FrameLayout, so it animates directly and there is no wrapper to
            // unwrap.
            splashScreen?.setOnExitAnimationListener { splashView ->
                splashView.animate()
                    .alpha(0f)
                    .setDuration(SPLASH_EXIT_FADE_MS)
                    .withEndAction { splashView.remove() }
                    .start()
            }
        } catch (e: Exception) {
            // A missing/incompatible OEM splash implementation must never be
            // able to block the launch — the default hard cut stays in place.
            Log.w("MainActivity", "splash exit listener not installed: ${e.message}")
        }
    }

    /**
     * The liveness marker the boot/rollover receivers read (see [AppLiveness]):
     * while the user is on screen, the Dart scheduler owns the reschedule and a
     * `needs_reschedule` stamp only buys a second, identical full rebuild.
     * `onStop` (not `onPause`) is the background edge — a dialog or the recents
     * peek keeps the app visible and its scheduler live.
     */
    override fun onResume() {
        super.onResume()
        AppLiveness.markForeground(applicationContext)
    }

    override fun onStop() {
        AppLiveness.markBackground(applicationContext)
        super.onStop()
    }

    override fun onDestroy() {
        SystemSoundCatalog.stop()
        super.onDestroy()
        reminderThread?.quitSafely()
        reminderThread = null
    }

    /**
     * The single worker every reminder call runs on. One thread (not a pool)
     * keeps the arms FIFO, so a `cancel` can never overtake the `arm` that was
     * issued before it, and the alarm state stays in the order Dart asked for.
     */
    private fun reminders(): Handler {
        val existing = reminderThread
        if (existing != null) return Handler(existing.looper)
        val thread = HandlerThread("reminder-alarms").apply { start() }
        reminderThread = thread
        return Handler(thread.looper)
    }

    /**
     * Runs [work] on the reminder worker and posts the reply back on the UI
     * thread — [MethodChannel.Result] must be called on the platform thread, so
     * the handover is mandatory, not a nicety. The work gets the application
     * context, never this Activity, so a queue that outlives the window cannot
     * hold it.
     */
    private fun replyAsync(result: MethodChannel.Result, work: (Context) -> Any?) {
        val appContext = applicationContext
        reminders().post {
            var failure: Throwable? = null
            var value: Any? = null
            try {
                value = work(appContext)
            } catch (e: Exception) {
                failure = e
            }
            val error = failure
            runOnUiThread {
                when {
                    error is IllegalArgumentException ->
                        result.error("BAD_ARG", error.message, null)
                    error != null -> {
                        Log.e("MainActivity", "reminder op failed: ${error.message}")
                        result.error("REMINDER_ERROR", error.message, null)
                    }
                    else -> result.success(value)
                }
            }
        }
    }

    /** Backs [reminders()]; created on the first reminder call, quit in [onDestroy]. */
    private var reminderThread: HandlerThread? = null

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleWidgetShortcut(intent)
        handleNotificationTapIntent(intent)
    }

    /// While the adhan plays, ANY hardware volume-key press silences it —
    /// even in the foreground where the service's stream polling can miss the
    /// press on OEMs that route keys to another stream. The key is NOT
    /// consumed so the user still adjusts the volume normally.
    override fun dispatchKeyEvent(event: android.view.KeyEvent): Boolean {
        if (AzanForegroundService.isPlaying() &&
            event.action == android.view.KeyEvent.ACTION_DOWN &&
            (event.keyCode == android.view.KeyEvent.KEYCODE_VOLUME_DOWN ||
                event.keyCode == android.view.KeyEvent.KEYCODE_VOLUME_UP)
        ) {
            Log.d("MainActivity", "Volume key pressed while adhan playing — stopping")
            try {
                val stopIntent = Intent(this, AzanForegroundService::class.java).apply {
                    action = AzanForegroundService.ACTION_STOP
                }
                startService(stopIntent)
            } catch (_: Exception) {
            }
        }
        return super.dispatchKeyEvent(event)
    }

    private fun handleWidgetShortcut(intent: Intent?) {
        val route = intent?.getStringExtra(EXTRA_SHORTCUT) ?: return
        getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            .edit()
            .putString("flutter.widget_shortcut", route)
            .apply()
    }

    /**
     * Routes a tap on a native-posted reminder notification to Flutter.
     * Stashes the payload for cold start (the foreground reads + clears it via
     * NotificationService.handleColdStartTap after init) and delivers it
     * immediately on warm start through the notification_tap channel.
     */
    private fun handleNotificationTapIntent(intent: Intent?) {
        val payload = intent?.getStringExtra("notification_payload") ?: return
        if (payload.isEmpty()) return
        val messenger = flutterEngine?.dartExecutor?.binaryMessenger
        if (messenger == null) {
            // Cold start: the engine is not up yet, so stash the payload for
            // NotificationService.handleColdStartTap() to consume after init().
            stashPendingNotificationPayload(payload)
            return
        }
        // Warm start: deliver straight away and clear the stash once Dart has
        // confirmed the handoff. Leaving it behind would replay this tap on the
        // next cold start (app running → tap → kill → reopen).
        try {
            MethodChannel(messenger, "com.tawheeed/notification_tap")
                .invokeMethod("deliver", payload, object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        clearPendingNotificationPayload()
                    }

                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        // Delivered-but-failed is still consumed; replaying it
                        // would navigate the user somewhere unexpected later.
                        clearPendingNotificationPayload()
                    }

                    override fun notImplemented() {
                        // The Dart handler is not registered yet, so nothing was
                        // delivered: keep it stashed for the cold-start path.
                        stashPendingNotificationPayload(payload)
                    }
                })
        } catch (e: Exception) {
            Log.w("MainActivity", "deliver notification payload: ${e.message}")
            stashPendingNotificationPayload(payload)
        }
    }

    private fun stashPendingNotificationPayload(payload: String) {
        getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            .edit()
            .putString("flutter.notification_payload", payload)
            .apply()
    }

    private fun clearPendingNotificationPayload() {
        getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            .edit()
            .remove("flutter.notification_payload")
            .apply()
    }

    private var filePickerResult: MethodChannel.Result? = null
    private var dirPickerResult: MethodChannel.Result? = null
    private var azanCopyResult: MethodChannel.Result? = null
    private var reminderCopyResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── SETTINGS CHANNEL ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SETTINGS_CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "openBatteryOptimization" -> {
                        val intent = Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:$packageName")
                        )
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    }
                    "checkPermission" -> {
                        val perm = call.argument<String>("permission") ?: ""
                        val granted = when (perm) {
                            "notifications" -> NotificationHelper.isPermissionGranted(this)
                            "exactAlarm" -> ExactAlarmHelper.canScheduleExactAlarms(this)
                            "batteryOptimization" -> {
                                val powerManager = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                                powerManager.isIgnoringBatteryOptimizations(packageName)
                            }
                            "location" -> {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                    checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) ==
                                        android.content.pm.PackageManager.PERMISSION_GRANTED
                                } else true
                            }
                            "dnd" -> {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                                    nm.isNotificationPolicyAccessGranted
                                } else true
                            }
                            else -> false
                        }
                        result.success(granted)
                    }
                    "deviceManufacturer" -> {
                        // Audit 4.7: let the Dart diagnostics surface the
                        // OEM-specific battery guide for THIS device first.
                        result.success(android.os.Build.MANUFACTURER ?: "")
                    }
                    "requestPermission" -> {
                        val perm = call.argument<String>("permission") ?: ""
                        when (perm) {
                            "notifications" -> {
                                NotificationHelper.openNotificationSettings(this)
                                result.success(true)
                            }
                            "exactAlarm" -> {
                                ExactAlarmHelper.openExactAlarmSettings(this)
                                result.success(true)
                            }
                            "batteryOptimization" -> {
                                // Open the system's battery-optimization list (no special
                                // permission needed — REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                                // is not declared for Play Store compliance).
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                    val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    startActivity(intent)
                                }
                                result.success(true)
                            }
                            "dnd" -> {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                    val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    startActivity(intent)
                                }
                                result.success(true)
                            }
                            "location" -> {
                                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                    Uri.parse("package:$packageName"))
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(intent)
                                result.success(true)
                            }
                            else -> result.success(false)
                        }
                    }
                    "isBatteryOptimizationDisabled" -> {
                        val powerManager = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                        result.success(powerManager.isIgnoringBatteryOptimizations(packageName))
                    }
                    "getDeviceTimezone" -> {
                        // Olson zone id of the device (e.g. Asia/Tehran). Dart
                        // aligns tz.local with this so zoned notifications fire
                        // at the real device wall-clock, not a hardcoded zone.
                        result.success(java.util.TimeZone.getDefault().id)
                    }
                    "consumeNeedsReschedule" -> {
                        // Set natively by BootReceiver after boot/update/time or
                        // timezone changes. Read-and-clear so one Dart
                        // reschedule consumes each native signal exactly once.
                        val prefs = getSharedPreferences("prayer_alarms", Context.MODE_PRIVATE)
                        val needed = prefs.getBoolean("needs_reschedule", false)
                        if (needed) {
                            prefs.edit().putBoolean("needs_reschedule", false).apply()
                        }
                        result.success(needed)
                    }
                    "createNotificationChannels" -> {
                        com.islamic.tawheeed.core.NotificationChannelManager.createAllChannels(this)
                        result.success(true)
                    }
                    "checkGpsEnabled" -> {
                        val locationManager = getSystemService(Context.LOCATION_SERVICE) as android.location.LocationManager
                        result.success(locationManager.isProviderEnabled(android.location.LocationManager.GPS_PROVIDER) ||
                                       locationManager.isProviderEnabled(android.location.LocationManager.NETWORK_PROVIDER))
                    }
                    "openLocationSettings" -> {
                        val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("SETTINGS_ERROR", e.message, null)
            }
        }

        // ── STORAGE CHANNEL ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "hasAllFilesAccess" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            result.success(Environment.isExternalStorageManager())
                        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            result.success(
                                checkSelfPermission(android.Manifest.permission.WRITE_EXTERNAL_STORAGE) ==
                                    android.content.pm.PackageManager.PERMISSION_GRANTED
                            )
                        } else {
                            result.success(true)
                        }
                    }
                    "openAllFilesAccessSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                            intent.data = Uri.parse("package:$packageName")
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    "pickDirectory" -> {
                        dirPickerResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
                        intent.addFlags(
                            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
                        )
                        startActivityForResult(intent, PICK_DIR_REQUEST)
                    }
                    "freeSpaceMb" -> {
                        // Dart has no statfs binding, and the reader's storage
                        // hero promises real free space — measure it here.
                        val stat = StatFs(filesDir.path)
                        result.success(stat.availableBytes / (1024L * 1024L))
                    }
                    "isOnWifi" -> {
                        // null means "cannot tell" so the Dart side fails OPEN
                        // and never blocks a download on an unknown transport.
                        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                        val caps = cm.activeNetwork?.let { cm.getNetworkCapabilities(it) }
                        result.success(
                            when {
                                caps == null -> null
                                caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                                    caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> true
                                caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> false
                                else -> null
                            }
                        )
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("STORAGE_ERROR", e.message, null)
            }
        }

        // ── AZAN CHANNEL ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AZAN_CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "playAzan" -> {
                        val sound = call.argument<String>("sound") ?: "takbir"
                        val customPath = call.argument<String>("customPath") ?: ""
                        val source = call.argument<String>("source")
                        val isAsset = call.argument<Boolean>("isAsset") ?: true
                        val volume = (call.argument<Double>("volume") ?: 1.0).toFloat()
                        val resolvedSound = if (isAsset) sound else "custom"
                        val resolvedCustom = if (!isAsset && source != null) source else customPath
                        val intent = Intent(this, AzanForegroundService::class.java).apply {
                            action = AzanForegroundService.ACTION_PLAY
                            putExtra("prayer", "اذان")
                            putExtra("sound", resolvedSound)
                            putExtra("customPath", resolvedCustom)
                            putExtra("volume", volume)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    }
                    "stopAzan" -> {
                        val intent = Intent(this, AzanForegroundService::class.java).apply {
                            action = AzanForegroundService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(true)
                    }
                    "bundledAzanPath" -> {
                        val sound = call.argument<String>("sound") ?: "takbir"
                        result.success(bundledAzanFile(sound)?.absolutePath)
                    }
                    // The phone's own tones for the reminder picker. Read-only
                    // system data (no permission); titles come localized.
                    "listSystemSounds" -> {
                        result.success(SystemSoundCatalog.list(this))
                    }
                    "previewSystemSound" -> {
                        val rawUri = call.argument<String>("uri")
                        val alarm = call.argument<Boolean>("alarm") ?: false
                        if (rawUri.isNullOrBlank()) {
                            result.success(false)
                        } else {
                            result.success(
                                SystemSoundCatalog.preview(
                                    this,
                                    Uri.parse(rawUri),
                                    alarm
                                )
                            )
                        }
                    }
                    "stopPreviewSound" -> {
                        SystemSoundCatalog.stop()
                        result.success(true)
                    }
                    "isPreviewSoundPlaying" -> {
                        result.success(SystemSoundCatalog.isPreviewing())
                    }
                    "isPlaying" -> {
                        result.success(AzanForegroundService.isPlaying())
                    }
                    "pickAudioFile" -> {
                        filePickerResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "audio/*"
                        }
                        startActivityForResult(intent, PICK_AUDIO_REQUEST)
                    }
                    // Picks an audio file via SAF and copies its bytes into the
                    // app-private custom_azans/ dir, returning the absolute path.
                    // Unlike file_picker 3.x this never yields a bytes-only
                    // result, and the copy survives reboots / provider grants.
                    "pickAndCopyAzanFile" -> {
                        azanCopyResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "audio/*"
                        }
                        startActivityForResult(intent, PICK_AUDIO_REQUEST)
                    }
                    "pickAndCopyReminderSound" -> {
                        reminderCopyResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "audio/*"
                        }
                        startActivityForResult(intent, PICK_AUDIO_REQUEST)
                    }
                    "pickFile" -> {
                        val mimeType = call.argument<String>("mimeType") ?: "*/*"
                        filePickerResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = mimeType
                        }
                        startActivityForResult(intent, PICK_AUDIO_REQUEST)
                    }
                    "pickBackupFile" -> {
                        filePickerResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "application/zip"
                            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/zip", "application/json"))
                        }
                        startActivityForResult(intent, PICK_BACKUP_REQUEST)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("AZAN_ERROR", e.message, null)
            }
        }

        // ── ALARMS CHANNEL ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARMS_CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "scheduleExactAlarms" -> {
                        // Cancel ALL previously-persisted alarms first so that
                        // disabled prayers (or removed alarms) don't keep firing.
                        ExactAlarmHelper.cancelAll(this)

                        val alarmsList = call.argument<List<Any>>("alarms") ?: emptyList()
                        val jsonArray = JSONArray()
            for (alarm in alarmsList) {
                val map = alarm as Map<*, *>
                val obj = JSONObject().apply {
                    put("id", (map["id"] as Number).toInt())
                    put("prayer", map["prayer"].toString())
                    put("timeMillis", (map["timeMillis"] as Number).toLong())
                    put("sound", map["sound"].toString())
                    put("customPath", map["customPath"].toString())
                    put("volume", (map["volume"] as? Number)?.toDouble() ?: 1.0)
                }
                jsonArray.put(obj)
            }

                        ExactAlarmHelper.persistAlarms(this, jsonArray.toString())
                        ExactAlarmHelper.scheduleAlarmsFromJson(this, jsonArray.toString())
                        // Audit 4.1: report the real grant state so the Dart side
                        // can warn the user instead of silently missing adhan audio.
                        result.success(
                            mapOf(
                                "scheduled" to jsonArray.length(),
                                "exactAllowed" to ExactAlarmHelper.canScheduleExactAlarms(this),
                            )
                        )
                    }
                    "cancelAllAlarms" -> {
                        ExactAlarmHelper.cancelAll(this)
                        getSharedPreferences("prayer_alarms", Context.MODE_PRIVATE)
                            .edit()
                            .remove("scheduled_alarms")
                            .apply()
                        result.success(true)
                    }
                    "cancelAlarm" -> {
                        val prayer = call.argument<String>("prayer") ?: ""
                        val alarmId = prayer.hashCode()
                        ExactAlarmHelper.cancelAlarm(this, alarmId)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("ALARMS_ERROR", e.message, null)
            }
        }

        // ── EXACT REMINDERS CHANNEL ──
        // Guarantees on-time delivery (Doze-immune) for EVERY non-adhan
        // notification the same way the azan works: post-prayer azkar,
        // pre-adhan reminders, morning/evening azkar, daily verse/hadith/dua,
        // quran, friday, khatm, personal reminders, tasks, pomodoro. All are
        // armed natively with setAlarmClock (exact and Doze/OEM-friendly; note
        // it still requires SCHEDULE_EXACT_ALARM on Android 12+ — denied by
        // default from Android 14 — and the Dart side arms an inexact plugin
        // fallback when that grant is missing), mirroring the azan path.
        //
        // Every case here answers on the reminder worker thread (see
        // [replyAsync]): setAlarmClock, PendingIntent.getBroadcast,
        // canScheduleExactAlarms and the prefs writes are binder/IO calls, and a
        // MethodChannel handler that answers inline runs them on the Android
        // main thread — a full launch reschedule of a few hundred alarms used to
        // stall the UI for seconds while the user was already scrolling. Dart
        // batches the whole storm into `applyReminderOps` calls, so the worker
        // is handed a list and the UI thread only ever gets the reply.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, REMINDERS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "applyReminderOps" -> replyAsync(result) { ctx ->
                    ExactReminderScheduler.applyOps(ctx, call.argument<String>("opsJson"))
                }
                "scheduleReminder" -> replyAsync(result) { ctx ->
                    val id = call.argument<Number>("id")?.toInt()
                        ?: throw IllegalArgumentException("missing id")
                    ExactReminderScheduler.schedule(
                        context = ctx,
                        id = id,
                        triggerTimeMillis = (call.argument<Number>("triggerTimeMillis")?.toLong()) ?: 0L,
                        title = call.argument<String>("title") ?: "",
                        body = call.argument<String>("body") ?: "",
                        channelId = call.argument<String>("channelId") ?: "general",
                        sound = call.argument<String>("sound"),
                        payload = call.argument<String>("payload"),
                        repeatDailyMillis = (call.argument<Number>("repeatDailyMillis") as? Number)?.toLong(),
                    )
                    true
                }
                "cancelReminder" -> replyAsync(result) { ctx ->
                    val id = (call.argument<Number>("id")?.toInt()) ?: 0
                    ExactReminderScheduler.cancel(ctx, id)
                    true
                }
                "cancelRangeReminders" -> replyAsync(result) { ctx ->
                    val start = (call.argument<Number>("startId")?.toInt()) ?: 0
                    val end = (call.argument<Number>("endId")?.toInt()) ?: 0
                    ExactReminderScheduler.cancelRange(ctx, start, end)
                    true
                }
                "cancelAllReminders" -> replyAsync(result) { ctx ->
                    ExactReminderScheduler.cancelAll(ctx)
                    true
                }
                "canUseExact" -> replyAsync(result) { ctx ->
                    ExactReminderScheduler.canUseExact(ctx)
                }
                "listReminders" -> replyAsync(result) { ctx ->
                    ExactReminderScheduler.listReminders(ctx)
                }
                else -> result.notImplemented()
            }
        }

        // ── WIDGETS CHANNEL ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "syncWidget" -> {
                        val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                        // Audit 5.3: fingerprint guard. The 30-min Dart timer
                        // pushes an identical snapshot when nothing changed;
                        // skipping the persist+refreshAll saves IPC and a full
                        // widget re-render. Tasbih taps touch tasbih_* keys, so
                        // their own channel still triggers refresh regardless.
                        val fp = args.hashCode()
                        val prefs = WidgetRepository.prefs(this)
                        if (fp == prefs.getInt("last_snapshot_fp", 0)) {
                            result.success(true)
                            return@setMethodCallHandler
                        }
                        WidgetRepository.persistSnapshot(this, args)
                        prefs.edit().putInt("last_snapshot_fp", fp).apply()
                        WidgetHub.refreshAll(this)
                    }
                    "updateTasbihWidget" -> {
                        val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                        val prefs = WidgetRepository.prefs(this)
                        prefs.edit {
                            args["dhikr"]?.let { putString("tasbih_dhikr", it.toString()) }
                            args["count"]?.let { putInt("tasbih_count", (it as Number).toInt()) }
                            args["target"]?.let { putInt("tasbih_target", (it as Number).toInt()) }
                            args["isActive"]?.let { putBoolean("tasbih_active", it.toString().toBoolean()) }
                            // Keep the widget's selected zikr in lock-step
                            // with the app's selection.
                            args["zikrIndex"]?.let { putInt("tasbih_zikr_index", (it as Number).toInt()) }
                            // Audit 8.15: the id is authoritative when present —
                            // an index can be stale after the list was reordered.
                            args["zikrId"]?.let { putString("tasbih_zikr_id", it.toString()) }
                        }
                        // Mirror the count into the per-zikr map as well: the map is
                        // what the widget reads when the user switches zikr on the
                        // home screen, so a count pushed only to the flat key was
                        // lost on the next zikr switch (the switch rewrites
                        // tasbih_count from that stale map).
                        val pushedId = args["zikrId"] as? String
                        val zikrList0 = TasbihGlanceWidgetReceiver.getZikrList(prefs)
                        // Audit 8.15: prefer the id; fall back to the pushed index.
                        val pushedIndex = pushedId?.let { id -> zikrList0.indexOf(id) }
                            ?.takeIf { it >= 0 } ?: (args["zikrIndex"] as? Number)?.toInt()
                        val pushedCount = args["count"] as? Number
                        if (pushedIndex != null && pushedCount != null) {
                            val perZikr =
                                TasbihGlanceWidgetReceiver.getPerZikrCounts(prefs)
                            perZikr[pushedIndex] = pushedCount.toInt()
                            TasbihGlanceWidgetReceiver.setPerZikrCounts(prefs, perZikr)
                        }
                        WidgetHub.refreshAll(this)
                    }
                    "incrementTasbih" -> {
                        val prefs = WidgetRepository.prefs(this)
                        val current = prefs.getInt("tasbih_count", 0)
                        val target = prefs.getInt("tasbih_target", 33)
                        prefs.edit().putInt("tasbih_count", (current + 1).coerceAtMost(target)).apply()
                        WidgetHub.refreshAll(this)
                    }
                    "resetTasbih" -> {
                        WidgetRepository.prefs(this).edit().putInt("tasbih_count", 0).apply()
                        WidgetHub.refreshAll(this)
                    }
                    "getTasbihCount" -> {
                        result.success(WidgetRepository.prefs(this).getInt("tasbih_count", 0))
                        return@setMethodCallHandler
                    }
                    "getTasbihData" -> {
                        val prefs = WidgetRepository.prefs(this)
                        val zikrList = TasbihGlanceWidgetReceiver.getZikrList(prefs)
                        val zikrIndex = prefs.getInt("tasbih_zikr_index", 0)
                        val perZikrCounts = TasbihGlanceWidgetReceiver.getPerZikrCounts(prefs)
                        val countsMap = mutableMapOf<String, Int>()
                        for ((index, count) in perZikrCounts) {
                            if (index < zikrList.size) {
                                countsMap[zikrList[index]] = count
                            }
                        }
                        // The queue must cross the method channel as plain maps:
                        // org.json types are not encodable by
                        // StandardMessageCodec and kill the whole reply (see
                        // TasbihGlanceWidgetReceiver.plainEvents).
                        val pendingList = TasbihGlanceWidgetReceiver.plainEvents(prefs)
                        result.success(mapOf(
                            "count" to prefs.getInt("tasbih_count", 0),
                            "target" to prefs.getInt("tasbih_target", 33),
                            "dhikr" to (prefs.getString("tasbih_dhikr", "") ?: ""),
                            "zikrIndex" to zikrIndex,
                            "perZikrCounts" to countsMap,
                            "zikrList" to zikrList,
                            "lastTapAt" to prefs.getLong("widget_tasbih_last_tap_at", 0L),
                            "widgetTasbihDaily" to prefs.getInt("widget_tasbih_daily_total", 0),
                            "widgetTasbihDailyDate" to (prefs.getString("widget_tasbih_daily_date", "") ?: ""),
                            // Append-only tap log: the app merges events with
                            // s > appliedSeq idempotently, then acks via
                            // drainTasbihEvents.
                            "pendingEvents" to pendingList,
                            "pendingSeq" to prefs.getInt(
                                TasbihGlanceWidgetReceiver.KEY_PENDING_SEQ, 0),
                        ))
                        return@setMethodCallHandler
                    }
                    "drainTasbihEvents" -> {
                        val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                        val throughSeq = (args["appliedSeq"] as? Number)?.toInt() ?: 0
                        TasbihGlanceWidgetReceiver.prunePending(
                            WidgetRepository.prefs(this), throughSeq
                        )
                    }
                    // The prayer widget records «خواندم» taps in its own
                    // date-scoped list and never writes the app's
                    // `prayer_statuses` (a snapshot push would undo the tap).
                    // These two methods are the only bridge: read the marks,
                    // let the tracker write the rows, then ack exactly the
                    // indices that were written.
                    "getPrayerMarks" -> {
                        val prefs = WidgetRepository.prefs(this)
                        val (date, indices) = WidgetPrefs.readMarkPayload(prefs)
                        val (clearedDate, cleared) = WidgetPrefs.readClearedPayload(prefs)
                        result.success(
                            mapOf(
                                "date" to date,
                                "indices" to indices,
                                // Ticks taken BACK on the card. Carried with its
                                // own date, so a clear from yesterday can never
                                // reset a prayer on a day it does not belong to.
                                "clearedDate" to clearedDate,
                                "cleared" to cleared,
                            )
                        )
                        return@setMethodCallHandler
                    }
                    "drainPrayerMarks" -> {
                        val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                        val date = args["date"] as? String ?: ""
                        val indices = (args["indices"] as? List<*>)
                            ?.mapNotNull { (it as? Number)?.toInt() }
                            ?: emptyList()
                        if (date.isNotEmpty() && indices.isNotEmpty()) {
                            WidgetPrefs.clearMarks(
                                WidgetRepository.prefs(this), date, indices
                            )
                        }
                    }
                    "drainPrayerCleared" -> {
                        val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                        val date = args["date"] as? String ?: ""
                        val indices = (args["indices"] as? List<*>)
                            ?.mapNotNull { (it as? Number)?.toInt() }
                            ?: emptyList()
                        if (date.isNotEmpty() && indices.isNotEmpty()) {
                            WidgetPrefs.clearCleared(
                                WidgetRepository.prefs(this), date, indices
                            )
                        }
                    }
                    // Clears the home-screen widgets' mirrored worship state
                    // after an evaluation reset so the reset is not resurrected
                    // by the next widget→app sync (the 10 s retry timer or app
                    // resume). The widgets keep their own copy of today's
                    // tasbih daily total, per-zikr counts and prayer «خواندم»
                    // marks; without clearing them,
                    // WidgetSyncService.reconcileTasbihFromWidget /
                    // reconcilePrayerMarksFromWidget re-import them right after
                    // resetRange() deletes the app's rows. The pending tap
                    // queue is dropped (its seq is kept) so pre-reset taps are
                    // not re-drained; post-reset taps start a fresh queue.
                    "clearEvaluationState" -> {
                        val prefs = WidgetRepository.prefs(this)
                        prefs.edit {
                            putInt("tasbih_count", 0)
                            remove("tasbih_per_zikr_counts")
                            putInt("widget_tasbih_daily_total", 0)
                            putString("widget_tasbih_daily_date", "")
                            remove(WidgetPrefs.KEY_PRAYER_READ)
                            remove(WidgetPrefs.KEY_PRAYER_CLEARED)
                            remove(TasbihGlanceWidgetReceiver.KEY_PENDING)
                        }
                        WidgetHub.refreshAll(this)
                    }
                    "setWidgetTheme" -> {
                        val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                        // Each widget owns its palette: the target's per-widget
                        // keys are the only thing written here. The shared
                        // widget_palette_id/_step keys stay untouched — they are
                        // the adoption source for pre-split installs, and
                        // rewriting them would leak one widget's save into the
                        // other's not-yet-adopted state.
                        val target = WidgetTheme.WidgetTarget.fromWire(args["widget"] as? String)
                        val prefs = WidgetRepository.prefs(this)
                        prefs.edit {
                            args["paletteId"]?.let {
                                putString(target.paletteKey, it.toString())
                            }
                            args["opacityStep"]?.let {
                                putInt(
                                    target.stepKey,
                                    (it as Number).toInt().coerceIn(0, 3),
                                )
                            }
                        }
                        WidgetHub.refreshAll(this)
                    }
                    "getWidgetTheme" -> {
                        val prefs = WidgetRepository.prefs(this)
                        fun targetState(t: WidgetTheme.WidgetTarget) = mapOf(
                            "paletteId" to prefs.getString(t.paletteKey, null),
                            // -1 = not yet persisted (the resolver adopts the
                            // shared selection or the migrated default on the
                            // next render).
                            "opacityStep" to prefs.getInt(t.stepKey, -1),
                        )
                        result.success(mapOf(
                            // Shared keys: the previous build's storage, kept so
                            // the settings page can preview what a not-yet-
                            // adopted widget will resolve to.
                            "paletteId" to prefs.getString(WidgetTheme.PREF_PALETTE_ID, null),
                            "opacityStep" to prefs.getInt(WidgetTheme.PREF_OPACITY_STEP, -1),
                            "prayer" to targetState(WidgetTheme.WidgetTarget.PRAYER),
                            "tasbih" to targetState(WidgetTheme.WidgetTarget.TASBIH),
                        ))
                        return@setMethodCallHandler
                    }
                    "requestPinWidget" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                            val widgetType = args["widgetType"] as? String ?: "prayer"
                            val manager = AppWidgetManager.getInstance(this)
                            val component = when (widgetType) {
                                "tasbih" -> ComponentName(this, TasbihGlanceWidgetReceiver::class.java)
                                "prayer_vertical" -> ComponentName(this, PrayerWidgetVertical::class.java)
                                else -> ComponentName(this, PrayerWidget::class.java)
                            }
                            result.success(manager.requestPinAppWidget(component, null, null))
                        } else {
                            result.success(false)
                        }
                        return@setMethodCallHandler
                    }
                    else -> result.notImplemented()
                }
                result.success(true)
            } catch (e: Exception) {
                result.error("WIDGET_ERROR", e.message, null)
            }
        }

        // ── SILENT MODE CHANNEL ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SILENT_CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "muteNow" -> {
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        // Save current ringer mode to restore later
                        val prefs = getSharedPreferences("silent_prefs", Context.MODE_PRIVATE)
                        prefs.edit().putInt("previous_ringer_mode", audioManager.ringerMode).apply()
                        // Set to silent
                        audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
                        result.success(true)
                    }
                    "unmuteNow" -> {
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        val prefs = getSharedPreferences("silent_prefs", Context.MODE_PRIVATE)
                        val previousMode = prefs.getInt("previous_ringer_mode", AudioManager.RINGER_MODE_NORMAL)
                        audioManager.ringerMode = previousMode
                        result.success(true)
                    }
                    "setDoNotDisturb" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                            if (notificationManager.isNotificationPolicyAccessGranted) {
                                notificationManager.setInterruptionFilter(
                                    if (enabled) NotificationManager.INTERRUPTION_FILTER_PRIORITY
                                    else NotificationManager.INTERRUPTION_FILTER_ALL
                                )
                                result.success(true)
                            } else {
                                val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(intent)
                                result.success(false)
                            }
                        } else {
                            result.success(false)
                        }
                    }
                    "isDndAccessGranted" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                            result.success(notificationManager.isNotificationPolicyAccessGranted)
                        } else {
                            result.success(true)
                        }
                    }
                    "getRingerMode" -> {
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        result.success(audioManager.ringerMode)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("SILENT_ERROR", e.message, null)
            }
        }

        // ── PRAYER SCHEDULER CHANNEL ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCHEDULER_CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "scheduleAdhan" -> {
                        val prayerName = call.argument<String>("prayer_name") ?: ""
                        val triggerTime = call.argument<Long>("trigger_time") ?: 0L
                        val soundName = call.argument<String>("sound_name") ?: "kamel"
                        val customPath = call.argument<String>("custom_path") ?: ""
                        com.islamic.tawheeed.core.PrayerAlarmScheduler.scheduleAdhanAlarm(
                            this, prayerName, triggerTime, soundName, customPath
                        )
                        result.success(true)
                    }
                    "cancelAlarm" -> {
                        val prayerName = call.argument<String>("prayer_name") ?: ""
                        com.islamic.tawheeed.core.PrayerAlarmScheduler.cancelAlarm(this, prayerName)
                        result.success(true)
                    }
                    "cancelAllAlarms" -> {
                        com.islamic.tawheeed.core.PrayerAlarmScheduler.cancelAllAlarms(this)
                        result.success(true)
                    }
                    "hasExactAlarmPermission" -> {
                        result.success(com.islamic.tawheeed.core.PrayerAlarmScheduler.hasExactAlarmPermission(this))
                    }
                    "openExactAlarmSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val intent = Intent(android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                            intent.data = Uri.parse("package:$packageName")
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                        }
                        result.success(true)
                    }
                    "scheduleSilentMode" -> {
                        val muteTime = call.argument<Long>("mute_time") ?: 0L
                        val iqamahTime = call.argument<Long>("iqamah_time") ?: 0L
                        // One slot per prayer so each silent window keeps its own
                        // alarm pair (a missing slot = 0 = legacy behaviour).
                        val slot = call.argument<Number>("slot")?.toInt() ?: 0
                        com.islamic.tawheeed.core.PrayerAlarmScheduler.scheduleSilentModeAlarm(
                            this, muteTime, iqamahTime, slot
                        )
                        result.success(true)
                    }
                    "cancelAllSilent" -> {
                        com.islamic.tawheeed.core.PrayerAlarmScheduler.cancelSilentModeAlarm(this)
                        result.success(true)
                    }
                    "scheduleRollover" -> {
                        com.islamic.tawheeed.core.PrayerAlarmScheduler.scheduleDailyRollover(
                            this,
                            com.islamic.tawheeed.core.PrayerAlarmScheduler.nextRolloverTime()
                        )
                        result.success(true)
                    }
                    "cancelRollover" -> {
                        com.islamic.tawheeed.core.PrayerAlarmScheduler.cancelDailyRollover(this)
                        result.success(true)
                    }
                    "createNotificationChannels" -> {
                        com.islamic.tawheeed.core.NotificationChannelManager.createAllChannels(this)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("SCHEDULER_ERROR", e.message, null)
            }
        }

        // ── NATIVE BACKGROUND WORK CHANNEL ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NATIVE_BACKGROUND_CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "registerCallback" -> {
                        val callbackHandle = call.argument<Number>("callbackHandle")?.toLong()
                            ?: throw IllegalArgumentException("callbackHandle is required")
                        com.islamic.tawheeed.core.NativeBackgroundScheduler.registerCallback(
                            this, callbackHandle
                        )
                        result.success(true)
                    }
                    "enqueueOneOff" -> {
                        val task = call.argument<String>("task") ?: throw IllegalArgumentException("task is required")
                        val delayMillis = call.argument<Number>("delayMillis")?.toLong() ?: 0L
                        val replace = call.argument<Boolean>("replace") ?: true
                        com.islamic.tawheeed.core.NativeBackgroundScheduler.enqueueOneOff(
                            this, task, delayMillis, replace
                        )
                        result.success(true)
                    }
                    "enqueuePeriodic" -> {
                        val task = call.argument<String>("task") ?: throw IllegalArgumentException("task is required")
                        val frequencyHours = call.argument<Number>("frequencyHours")?.toLong() ?: 24L
                        val initialDelayMillis = call.argument<Number>("initialDelayMillis")?.toLong() ?: 0L
                        val keep = call.argument<Boolean>("keep") ?: false
                        com.islamic.tawheeed.core.NativeBackgroundScheduler.enqueuePeriodic(
                            this, task, frequencyHours, initialDelayMillis, keep
                        )
                        result.success(true)
                    }
                    "cancelAll" -> {
                        com.islamic.tawheeed.core.NativeBackgroundScheduler.cancelAll(this)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("NATIVE_BACKGROUND_ERROR", e.message, null)
            }
        }

        // ── MAGNETIC DECLINATION CHANNEL ──
        // Local magnetic declination (degrees, east positive) via Android's
        // GeomagneticField (World Magnetic Model). Replaces the unmaintained
        // `magnetic_declination` plugin so the app no longer depends on a
        // third-party plugin that applies the legacy Kotlin Gradle Plugin.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MAGNETIC_CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "calculateDeclination" -> {
                        val latitude = call.argument<Double>("latitude")
                            ?: throw IllegalArgumentException("latitude is required")
                        val longitude = call.argument<Double>("longitude")
                            ?: throw IllegalArgumentException("longitude is required")
                        val altitude = call.argument<Double>("altitude") ?: 0.0
                        // StandardMessageCodec sends a Dart int that fits signed
                        // 32 bits as java.lang.Integer, so a typed Long read
                        // throws for epoch seconds (~1.7e9) and every lookup
                        // failed. Read the Number and widen it.
                        val timestamp = call.argument<Number>("timestamp")?.toLong()
                            ?: throw IllegalArgumentException("timestamp is required")
                        val field = android.hardware.GeomagneticField(
                            latitude.toFloat(),
                            longitude.toFloat(),
                            altitude.toFloat(),
                            timestamp * 1000 // milliseconds
                        )
                        result.success(field.declination.toDouble())
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("MAGNETIC_ERROR", e.message, null)
            }
        }
    }


    /// Resolves a SAF document-tree URI to a real filesystem path so the app
    /// can use plain File/Directory APIs (needs "All files access" on 11+).
    /// - `primary:Download` -> `/storage/emulated/0/Download`
    /// - `1234-5678:TAWHEED` (SD card volume) -> `/storage/1234-5678/TAWHEED`
    private fun resolveDirectoryPath(uri: Uri): String {
        try {
            val docId = android.provider.DocumentsContract.getTreeDocumentId(uri)
            val parts = docId.split(":")
            if (parts.size >= 2) {
                val volume = parts[0]
                val rest = parts.drop(1).joinToString(":")
                if (volume == "primary") {
                    return "/storage/emulated/0/$rest"
                }
                return "/storage/$volume/$rest"
            }
            return docId
        } catch (e: Exception) {
            return uri.toString()
        }
    }

    private fun getFileName(uri: Uri): String {
        var name = "backup"
        try {
            val cursor = contentResolver.query(uri, null, null, null, null)
            cursor?.use {
                if (it.moveToFirst()) {
                    val nameIndex = it.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                    if (nameIndex >= 0) {
                        name = it.getString(nameIndex)
                    }
                }
            }
        } catch (_: Exception) {
            // fallback to URI last segment
            val seg = uri.lastPathSegment
            if (seg != null) name = seg
        }
        return name
    }

    /// Copies a SAF-picked audio file into filesDir/custom_azans/ and returns
    /// the absolute path (or null when the user cancelled). Only one variant
    /// (azan_custom.<ext>) is kept so stale extensions never linger.
    private fun handleAzanCopyPick(uri: Uri?, out: MethodChannel.Result) {
        if (uri == null) {
            out.success(null)
            return
        }
        try {
            val rawName = getFileName(uri)
            val ext = rawName.substringAfterLast('.', "").lowercase()
            val known = setOf("mp3", "wav", "aac", "ogg", "m4a", "3gp", "amr", "flac")
            val safeExt = if (ext in known) ext else "mp3"
            val dir = java.io.File(filesDir, "custom_azans").apply { mkdirs() }
            dir.listFiles()?.forEach { it.delete() }
            val dest = java.io.File(dir, "azan_custom.$safeExt")
            contentResolver.openInputStream(uri)?.use { input ->
                dest.outputStream().use { output -> input.copyTo(output) }
            } ?: throw IllegalStateException("Cannot open selected file")
            if (!dest.exists() || dest.length() == 0L) {
                throw IllegalStateException("Copied file is empty")
            }
            out.success(dest.absolutePath)
        } catch (e: Exception) {
            out.error("AZAN_COPY_ERROR", e.message ?: "copy failed", null)
        }
    }

    /// Copies a SAF-picked audio file into filesDir/custom_sounds/ — one file
    /// per reminder (timestamp-named) so multiple reminders keep their own
    /// sounds. Mirrors handleAzanCopyPick but does NOT delete siblings.
    private fun handleReminderCopyPick(uri: Uri?, out: MethodChannel.Result) {
        if (uri == null) {
            out.success(null)
            return
        }
        try {
            val rawName = getFileName(uri)
            val ext = rawName.substringAfterLast('.', "").lowercase()
            val known = setOf("mp3", "wav", "aac", "ogg", "m4a", "3gp", "amr", "flac")
            val safeExt = if (ext in known) ext else "mp3"
            val dir = java.io.File(filesDir, "custom_sounds").apply { mkdirs() }
            val dest = java.io.File(dir, "reminder_${System.currentTimeMillis()}.$safeExt")
            contentResolver.openInputStream(uri)?.use { input ->
                dest.outputStream().use { output -> input.copyTo(output) }
            } ?: throw IllegalStateException("Cannot open selected file")
            if (!dest.exists() || dest.length() == 0L) {
                throw IllegalStateException("Copied file is empty")
            }
            out.success(dest.absolutePath)
        } catch (e: Exception) {
            out.error("REMINDER_COPY_ERROR", e.message ?: "copy failed", null)
        }
    }

    /// Copies a bundled `res/raw` adhan into cacheDir once and returns it, so
    /// the Dart preview player can open it as a file. Notifications, alarms and
    /// [AzanForegroundService] keep playing the `android.resource` URI directly;
    /// this exists only because MediaPlayer's URL form cannot open it.
    private fun bundledAzanFile(sound: String): java.io.File? {
        val uriString = AzanAudioResolver.bundledAzanUri(packageName, sound)
        val uri = Uri.parse(uriString)
        val name = uri.lastPathSegment ?: return null
        val dir = java.io.File(cacheDir, "bundled_azan").apply { mkdirs() }
        val out = java.io.File(dir, "$name.mp3")
        if (out.isFile && out.length() > 0L) return out
        return try {
            contentResolver.openInputStream(uri).use { input ->
                if (input == null) {
                    Log.w("MainActivity", "bundled azan has no stream: $uriString")
                    return null
                }
                out.outputStream().use { output -> input.copyTo(output) }
            }
            out
        } catch (e: Exception) {
            Log.w("MainActivity", "bundled azan copy failed: ${e.message}")
            out.delete()
            null
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            PICK_DIR_REQUEST -> {
                if (resultCode == RESULT_OK && data?.data != null) {
                    val uri: Uri = data.data!!
                    try {
                        contentResolver.takePersistableUriPermission(
                            uri,
                            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                        )
                    } catch (_: Exception) {
                        // Non-persistable tree — the resolved path still works
                        // while the user keeps "All files access" granted.
                    }
                    dirPickerResult?.success(resolveDirectoryPath(uri))
                } else {
                    dirPickerResult?.success(null)
                }
                dirPickerResult = null
            }
            PICK_AUDIO_REQUEST -> {
                val reminderResult = reminderCopyResult
                if (reminderResult != null) {
                    reminderCopyResult = null
                    handleReminderCopyPick(
                        if (resultCode == RESULT_OK) data?.data else null,
                        reminderResult
                    )
                    return
                }
                val copyResult = azanCopyResult
                if (copyResult != null) {
                    azanCopyResult = null
                    handleAzanCopyPick(
                        if (resultCode == RESULT_OK) data?.data else null,
                        copyResult
                    )
                    return
                }
                if (resultCode == RESULT_OK && data?.data != null) {
                    val uri: Uri = data.data!!
                    // The azan file is read later by the alarm receiver / foreground
                    // service from a cold process, so the picked URI grant MUST
                    // persist across reboots. Without this, the grant expires and
                    // MediaPlayer.setDataSource(content://…) fails → azan silent on
                    // some phones / after a while.
                    try {
                        contentResolver.takePersistableUriPermission(
                            uri,
                            Intent.FLAG_GRANT_READ_URI_PERMISSION
                        )
                    } catch (_: Exception) {
                        // Provider may not support persistable grants (rare).
                    }
                    val path = uri.toString()
                    filePickerResult?.success(path)
                } else {
                    filePickerResult?.success(null)
                }
                filePickerResult = null
            }
            PICK_BACKUP_REQUEST -> {
                if (resultCode == RESULT_OK && data?.data != null) {
                    val uri: Uri = data.data!!
                    try {
                        val filename = getFileName(uri)
                        val maxSize = 50L * 1024 * 1024 // 50 MB
                        val size = contentResolver.openAssetFileDescriptor(uri, "r")?.use {
                            it.length
                        } ?: 0L
                        if (size > maxSize) {
                            filePickerResult?.error("TOO_LARGE", "File exceeds 50 MB limit", null)
                        } else {
                            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                            if (bytes != null) {
                                filePickerResult?.success(mapOf(
                                    "name" to filename,
                                    "bytes" to bytes
                                ))
                            } else {
                                filePickerResult?.error("READ_ERROR", "Failed to read file", null)
                            }
                        }
                    } catch (e: Exception) {
                        filePickerResult?.error("READ_ERROR", e.message, null)
                    }
                } else {
                    filePickerResult?.success(null)
                }
                filePickerResult = null
            }
        }
    }
}
