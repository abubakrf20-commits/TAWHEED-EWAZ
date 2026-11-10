package com.islamic.tawheeed.core

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.concurrent.futures.CallbackToFutureAdapter
import androidx.work.Constraints
import androidx.work.Data
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.ListenableWorker
import androidx.work.PeriodicWorkRequest
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.work.OneTimeWorkRequest
import com.google.common.util.concurrent.ListenableFuture
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.plugin.common.MethodCall
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.view.FlutterCallbackInformation
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

object NativeBackgroundScheduler {
    const val TASK_PRAYER_SYNC = "prayerSync"
    const val TASK_DAILY_REFRESH = "dailyRefresh"
    const val TASK_AZAN_CHECK = "azanCheck"
    const val TASK_HOURLY_NOTIF_CHECK = "hourlyNotifCheck"
    val ALL_TASKS = listOf(
        TASK_PRAYER_SYNC, TASK_DAILY_REFRESH, TASK_AZAN_CHECK,
        TASK_HOURLY_NOTIF_CHECK,
    )
    const val INPUT_TASK = "task"

    private const val TAG = "NativeBackgroundScheduler"
    const val PREFS = "native_background_scheduler"
    const val CALLBACK_HANDLE = "callback_handle"

    fun registerCallback(context: Context, callbackHandle: Long) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putLong(CALLBACK_HANDLE, callbackHandle)
            .apply()
    }

    fun enqueueOneOff(
        context: Context,
        task: String,
        delayMillis: Long = 0L,
        replace: Boolean = true,
    ) {
        val request = OneTimeWorkRequest.Builder(NativeBackgroundWorker::class.java)
            .setInputData(Data.Builder().putString(INPUT_TASK, task).build())
            .setInitialDelay(delayMillis.coerceAtLeast(0L), TimeUnit.MILLISECONDS)
            .setConstraints(Constraints.NONE)
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork(
            task,
            if (replace) ExistingWorkPolicy.REPLACE else ExistingWorkPolicy.KEEP,
            request,
        )
    }

    fun enqueuePeriodic(
        context: Context,
        task: String,
        frequencyHours: Long,
        initialDelayMillis: Long = 0L,
        keep: Boolean = false,
    ) {
        val request = PeriodicWorkRequest.Builder(
            NativeBackgroundWorker::class.java,
            frequencyHours.coerceAtLeast(1L),
            TimeUnit.HOURS,
        )
            .setInputData(Data.Builder().putString(INPUT_TASK, task).build())
            .setInitialDelay(initialDelayMillis.coerceAtLeast(0L), TimeUnit.MILLISECONDS)
            .setConstraints(Constraints.NONE)
            .build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            task,
            if (keep) ExistingPeriodicWorkPolicy.KEEP else ExistingPeriodicWorkPolicy.UPDATE,
            request,
        )
    }

    /// Cancels only the work enqueued by THIS scheduler (unique names are the
    /// task names themselves). Never use WorkManager.cancelAllWork() — that
    /// would also kill every other component's jobs (cloud backup, widget
    /// upkeep) until the next app launch. (Audit 4.3-1)
    fun cancelAll(context: Context) {
        val wm = WorkManager.getInstance(context)
        for (task in ALL_TASKS) {
            wm.cancelUniqueWork(task)
        }
    }
}

/** Runs the existing Dart background handlers without a Flutter WorkManager plugin. */
class NativeBackgroundWorker(
    applicationContext: Context,
    workerParams: WorkerParameters,
) : ListenableWorker(applicationContext, workerParams), MethodChannel.MethodCallHandler {
    companion object {
        private const val TAG = "NativeBackgroundWorker"
        private const val CHANNEL = "com.tawheeed/native_background"
        private const val READY = "ready"
        private const val RUN_TASK = "runTask"
        private const val COMPLETED = "completed"

        private val flutterLoader = FlutterLoader()
    }

    private var engine: FlutterEngine? = null
    private var backgroundChannel: MethodChannel? = null
    private var completer: CallbackToFutureAdapter.Completer<Result>? = null
    private var startTime = 0L

    private val task: String
        get() = inputData.getString(NativeBackgroundScheduler.INPUT_TASK) ?: ""

    private val resultFuture: ListenableFuture<Result> = CallbackToFutureAdapter.getFuture { completer ->
        this.completer = completer
        null
    }

    override fun startWork(): ListenableFuture<Result> {
        startTime = System.currentTimeMillis()
        val mainHandler = Handler(Looper.getMainLooper())
        mainHandler.post {
            try {
                if (!flutterLoader.initialized()) {
                    flutterLoader.startInitialization(applicationContext)
                }
                flutterLoader.ensureInitializationCompleteAsync(
                    applicationContext,
                    null,
                    mainHandler,
                ) {
                    startFlutterEngine(flutterLoader.findAppBundlePath())
                }
            } catch (error: Throwable) {
                Log.e(TAG, "Failed to initialize Flutter for task $task", error)
                complete(Result.retry())
            }
        }
        return resultFuture
    }

    private fun startFlutterEngine(bundlePath: String) {
        try {
            val callbackHandle = applicationContext
                .getSharedPreferences(NativeBackgroundScheduler.PREFS, Context.MODE_PRIVATE)
                .getLong(NativeBackgroundScheduler.CALLBACK_HANDLE, -1L)
            if (callbackHandle == -1L) {
                Log.w(TAG, "No Dart callback registered for task $task")
                complete(Result.failure())
                return
            }
            val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(callbackHandle)
            if (callbackInfo == null) {
                Log.w(TAG, "Dart callback handle is invalid for task $task")
                complete(Result.failure())
                return
            }
            val startedEngine = FlutterEngine(applicationContext)
            engine = startedEngine
            GeneratedPluginRegistrant.registerWith(startedEngine)
            backgroundChannel = MethodChannel(startedEngine.dartExecutor, CHANNEL)
            backgroundChannel?.setMethodCallHandler(this)
            startedEngine.dartExecutor.executeDartCallback(
                DartExecutor.DartCallback(
                    applicationContext.assets,
                    bundlePath,
                    callbackInfo,
                ),
            )
        } catch (error: Throwable) {
            Log.e(TAG, "Failed to start Dart callback for task $task", error)
            complete(Result.retry())
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            READY -> {
                backgroundChannel?.invokeMethod(RUN_TASK, task)
                result.success(true)
            }
            COMPLETED -> {
                val success = call.argument<Boolean>("success") == true
                complete(if (success) Result.success() else Result.retry())
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun complete(result: Result) {
        completer?.set(result)
        completer = null
        Handler(Looper.getMainLooper()).post {
            backgroundChannel?.setMethodCallHandler(null)
            backgroundChannel = null
            engine?.destroy()
            engine = null
        }
        Log.d(TAG, "Task $task completed in ${System.currentTimeMillis() - startTime}ms: $result")
    }

    override fun onStopped() {
        complete(Result.failure())
    }
}
