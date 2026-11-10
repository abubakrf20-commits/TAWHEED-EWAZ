package com.islamic.tawheeed.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import java.util.Calendar
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * The prayer card's receiver: the only thing that arms alarms, and the only
 * thing that writes state on a tap.
 *
 * The class is a plain [AppWidgetProvider] now — the same conversion the
 * tasbih card made. The *component* name is deliberately unchanged: a placed
 * widget is keyed by its provider component, so the class keeps its name and
 * the cards already on users' home screens survive the update. Three
 * responsibilities, in order of importance:
 *
 *  1. **Keep the stored data fresh** — [WidgetRepository.recomputeTimesIfStale]
 *     runs here (and in [WidgetRefreshWorker]), never inside a render. The
 *     render is a pure function of stored data; anything that costs a solar
 *     calculation happens before it.
 *  2. **Arm the boundaries** — exact alarms at every adhan, iqamah and sunrise
 *     flip the phase, the «next prayer» wash and the dates, plus a per-minute
 *     tick that re-bases the countdown Chronometer.
 *  3. **Record a tap** — [ACTION_MARK_READ] flips one prayer's «خواندم» mark
 *     in [WidgetPrefs.KEY_PRAYER_READ] and hands the launcher a PARTIAL
 *     RemoteViews (only the five capsules) through
 *     [PrayerNativeViews.capsules]. Measured on the POCO X7 Pro 2026-11-04:
 *     the old Glance path committed the mark in +37 ms but only repainted at
 *     +444 ms; the partial merge lands in a frame. No activity, no Flutter,
 *     no dialog.
 *
 * The card itself is [PrayerNativeViews]'s hand-built RemoteViews: a live
 * TextClock and a count-down Chronometer tick inside the LAUNCHER between
 * renders, and the minute tick re-bases the Chronometer and refreshes the
 * baked parts (dates, phases, the countdown target).
 */
open class PrayerWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        WidgetTiming.logProcessReady("prayer.onUpdate")
        WidgetTokens.init(context)
        // Data first, render second: the render reads what this writes.
        try {
            WidgetRepository.recomputeTimesIfStale(context)
        } catch (e: Throwable) {
            Log.e(TAG, "onUpdate recompute failed, rendering stored data: ${e.message}")
        }
        for (id in appWidgetIds) {
            render(context, appWidgetManager, id)
        }
        rearmAll(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        // A resize changes the cell's dp box, and every size on the card is
        // derived from it — this is one of the few genuine full renders. The
        // old Glance path recomposed through LocalSize; the native card reads
        // the same options itself.
        try {
            WidgetTokens.init(context)
            render(context, appWidgetManager, appWidgetId)
        } catch (e: Throwable) {
            Log.e(TAG, "onOptionsChanged failed: ${e.message}")
        }
    }

    /** Launcher restore (backup/restore or device transfer): the framework
     *  hands the ids here without calling onUpdate. */
    override fun onRestored(
        context: Context,
        oldWidgetIds: IntArray,
        newWidgetIds: IntArray
    ) {
        super.onRestored(context, oldWidgetIds, newWidgetIds)
        onUpdate(context, AppWidgetManager.getInstance(context), newWidgetIds)
    }

    override fun onReceive(context: Context, intent: Intent) {
        // AppWidgetProvider dispatches APPWIDGET_UPDATE / ENABLED / DISABLED /
        // DELETED / OPTIONS_CHANGED / RESTORED from here; those already arm or
        // cancel the alarms themselves.
        super.onReceive(context, intent)
        // The BROADCAST tap path, logged once per tap.
        //
        // Taps now arrive through [PrayerMarkActivity], because a broadcast is
        // dropped outright while the app is frozen — but a PendingIntent built
        // by an older build still points here, and `adb shell am broadcast -a
        // com.tawheeed.WIDGET_MARK_READ --ei prayer_idx N` is the only way to
        // drive this path from a desk. One line, so "did the tap arrive at all"
        // has an answer that does not depend on guessing.
        if (intent.action == ACTION_MARK_READ) {
            WidgetTiming.mark(
                "tap.broadcast",
                WidgetTiming.processStartUptimeMillis(),
                "idx=${intent.getIntExtra(EXTRA_PRAYER_INDEX, -1)} " +
                    "widget=${intent.getIntExtra(PrayerNativeViews.EXTRA_APP_WIDGET_ID, -1)}",
            )
        }
        when (intent.action) {
            // Development instrument only: inflate the card for an explicit
            // cell, measure every band, and probe a capsule's tap. It renders
            // nothing to any widget and changes no state.
            ACTION_AUDIT -> {
                val id = intent.getIntExtra(EXTRA_AUDIT_ID, -1)
                val w = intent.getFloatExtra(EXTRA_AUDIT_WIDTH, 250f)
                val h = intent.getFloatExtra(EXTRA_AUDIT_HEIGHT, 170f)
                if (id >= 0) WidgetAudit.measure(context, id, w, h)
            }
            // A tap on one of the five capsules. Cheap on purpose: one prefs
            // write plus one partial RemoteViews merge, no data recompute and
            // no alarm churn.
            ACTION_MARK_READ -> markReadAndRender(context, intent)
            // A boundary render request. The countdown leaf is a framework
            // Chronometer and cannot call back, so the boundary alarms are the
            // one thing that repaints *without* touching stored data: they,
            // the safe-mode switch and a manual `adb broadcast` all land here,
            // and it holds the broadcast open until the card is painted.
            ACTION_BOUNDARY_REFRESH -> {
                WidgetTiming.mark(
                    "boundary.refresh.request",
                    WidgetTiming.processStartUptimeMillis(),
                    "origin=${intent.action}",
                )
                // `goAsync()` is a platform type that **can return null** — the
                // framework only hands out a PendingResult while it is actually
                // dispatching a broadcast to this instance. It has been observed
                // null on HyperOS 3, and an unguarded `.finish()` there is not a
                // missed repaint, it is a NullPointerException on a coroutine
                // worker: the process dies, the card blanks, and the crash log
                // points at a receiver that looks perfectly fine.
                val pending: BroadcastReceiver.PendingResult? = goAsync()
                CoroutineScope(Dispatchers.Default).launch {
                    try {
                        refreshAllAwait(context)
                    } catch (e: Throwable) {
                        Log.e(TAG, "boundary refresh failed: ${e.message}")
                    } finally {
                        try {
                            pending?.finish()
                        } catch (e: Throwable) {
                            Log.w(TAG, "boundary finish failed: ${e.message}")
                        }
                    }
                }
            }
            // The 30-second progress tick: re-bakes ONLY the countdown pill's
            // bitmap (a PARTIAL merge, not a full re-render) so the baked phase
            // bar actually FILLS between the hourly boundary renders. Without
            // this the bar is frozen for up to 15 minutes — the only other
            // refresh in the long «تا اذان» phase is the WorkManager backstop,
            // and `liveLeaves` cancels the per-minute tick, so the bitmap sits
            // still and the user sees a stuck bar («نوار پیشرفت حرکت نمیکند و
            // گیر کرده»). Self-rearms at the end of every delivery.
            ACTION_PROGRESS_TICK -> {
                WidgetTiming.mark(
                    "progress.tick.request",
                    WidgetTiming.processStartUptimeMillis(),
                    "origin=${intent.action}",
                )
                val pending: BroadcastReceiver.PendingResult? = goAsync()
                CoroutineScope(Dispatchers.Default).launch {
                    try {
                        refreshProgress(context)
                    } catch (e: Throwable) {
                        Log.e(TAG, "progress tick failed: ${e.message}")
                    } finally {
                        try {
                            scheduleProgressTicks(context)
                        } catch (e: Throwable) {
                            Log.e(TAG, "progress tick rearm failed: ${e.message}")
                        }
                        try {
                            pending?.finish()
                        } catch (e: Throwable) {
                            Log.w(TAG, "progress tick finish failed: ${e.message}")
                        }
                    }
                }
            }

            // Clock/timezone changes move every stored clock, so they must
            // recompute before they repaint.
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            ACTION_MIDNIGHT_REFRESH,
            ACTION_WATCHDOG,
            ACTION_MINUTE_REFRESH -> refreshAll(context)
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        WidgetTokens.init(context)
        try {
            WidgetRepository.recomputeTimesIfStale(context)
        } catch (e: Throwable) {
            Log.e(TAG, "onEnabled recompute failed: ${e.message}")
        }
        rearmAll(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        cancelWatchdog(context)
        cancelMidnightUpdate(context)
        cancelBoundaryUpdates(context)
        cancelMinuteTick(context)
        cancelProgressTicks(context)
        WidgetRefreshWorker.cancel(context)
    }

    // ── Tap ────────────────────────────────────────────────────────────────

    /**
     * «خواندم» from the home screen, on the BROADCAST path.
     *
     * A tap normally arrives through [PrayerMarkActivity] instead — a broadcast
     * is dropped while the app is frozen, which is exactly why the card stopped
     * ticking («صبح و ظهر و مغرب و عشا و عصر تیک نمی‌خورند از داخل ویجت»). This
     * branch stays for the PendingIntents an older build already baked, and for
     * `adb shell am broadcast -a com.tawheeed.WIDGET_MARK_READ`.
     *
     * The mark goes into the widget's own key, not into the app's
     * `prayer_statuses`: the app pushes that map on every snapshot, so a tap
     * written there would be silently reverted within thirty minutes. The app
     * drains [WidgetPrefs.KEY_PRAYER_READ] and merges it into its own tracker.
     *
     * The repaint is PARTIAL — [PrayerNativeViews.capsules] merged with
     * `partiallyUpdateAppWidget` — which is the whole point of the native
     * rewrite. The tap intent carries [PrayerNativeViews.EXTRA_APP_WIDGET_ID]
     * precisely so the merge can be addressed to the touched card; a missing
     * id (an intent built before the native rewrite, or a hand-rolled adb
     * broadcast) falls back to a full render of every instance.
     */
    private fun markReadAndRender(context: Context, intent: Intent) {
        // Synchronous: the paint must be on its way to the launcher before this
        // broadcast is finished, or the process is frozen and the render never
        // lands. See [applyMarkAndRender].
        applyMarkAndRender(
            context = context,
            index = intent.getIntExtra(EXTRA_PRAYER_INDEX, -1),
            widgetId = intent.getIntExtra(PrayerNativeViews.EXTRA_APP_WIDGET_ID, -1),
            startedAt = android.os.SystemClock.uptimeMillis(),
        )
    }

    // ── Rendering ──────────────────────────────────────────────────────────

    /**
     * Paints one instance. A full render is the only kind this receiver
     * issues outside a tap; the tap path applies [PrayerNativeViews.capsules]
     * through `partiallyUpdateAppWidget`, which merges the setters into the
     * launcher's existing view.
     */
    private fun render(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
    ) {
        try {
            // `this is PrayerWidgetVertical` forces the dedicated vertical
            // provider to always draw the vertical card; the horizontal
            // provider leaves the decision to the pref (forceVertical = null).
            manager.updateAppWidget(
                widgetId,
                PrayerNativeViews.full(
                    context,
                    widgetId,
                    forceVertical = this is PrayerWidgetVertical,
                ),
            )
        } catch (t: Throwable) {
            // One stale id must not stop the others: a launcher can keep an id
            // for a moment after the user removed the card.
            Log.w(TAG, "render id=$widgetId failed: ${t.message}")
        }
    }

    // ── Alarms ─────────────────────────────────────────────────────────────

    /**
     * Arms everything this widget needs, in one place.
     *
     * Called on every update, every enable and after every refresh, so a
     * dropped alarm can never strand the card without a successor. The minute
     * tick re-bases the countdown Chronometer and refreshes the baked parts.
     */
    fun rearmAll(context: Context) {
        scheduleWatchdog(context)
        scheduleMidnightUpdate(context)
        scheduleBoundaryUpdates(context)
        scheduleMinuteTick(context)
        scheduleProgressTicks(context)
        WidgetRefreshWorker.schedule(context)
    }

    /**
     * A coarse safety net for the whole alarm chain: if the OS silently drops
     * every exact alarm (battery saver, an OEM task killer, a revoked
     * permission), this is the worst-case staleness for the *phase* — the
     * clock itself ticks on its own.
     */
    private fun scheduleWatchdog(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, javaClass).apply {
                action = ACTION_WATCHDOG
                setPackage(context.packageName)
            }
            val pi = PendingIntent.getBroadcast(
                context, WATCHDOG_REQUEST_CODE, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            setAndAllowWhileIdle(
                alarmManager,
                System.currentTimeMillis() + WATCHDOG_INTERVAL_MS,
                pi,
            )
        } catch (e: Throwable) {
            Log.e(TAG, "scheduleWatchdog failed: ${e.message}")
        }
    }

    /** Doze-friendly inexact arm (plain [AlarmManager.set] would be deferred for hours). */
    private fun setAndAllowWhileIdle(
        alarmManager: AlarmManager,
        triggerAtMillis: Long,
        pi: PendingIntent,
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
        } else {
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
        }
    }

    /**
     * The per-minute re-render. The live leaves (TextClock, Chronometer) tick
     * inside the launcher between renders, so a missed minute costs a stale
     * re-base at worst — but the tick also refreshes the BAKED parts (dates,
     * phase, the «next» wash).
     *
     * It is armed ONLY while the card has to carry the clock itself: with the
     * live leaf hosted, 1440 wake-ups a day would buy nothing the launcher does
     * not already do, so the tick is skipped and a backstop left over from a
     * host that refused the leaf is cancelled here rather than left firing.
     */
    private fun scheduleMinuteTick(context: Context) {
        try {
            if (WidgetPrefs.liveLeaves(WidgetRepository.prefs(context))) {
                cancelMinuteTick(context)
                return
            }
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val target = nextMinuteBoundary(System.currentTimeMillis()) + 500L
            armMinuteAlarm(context, alarmManager, target)
            armMinuteBackstop(context, alarmManager, target)
        } catch (e: Throwable) {
            Log.e(TAG, "scheduleMinuteTick failed: ${e.message}")
        }
    }

    /** Next whole minute, in wall-clock millis. */
    private fun nextMinuteBoundary(nowMillis: Long): Long =
        (nowMillis / 60_000L + 1L) * 60_000L

    private fun minuteTickIntent(context: Context): Intent =
        Intent(context, javaClass).apply {
            action = ACTION_MINUTE_REFRESH
            setPackage(context.packageName)
        }

    /** The precise tick: exact when the OS allows it, allow-while-idle otherwise. */
    private fun armMinuteAlarm(
        context: Context,
        alarmManager: AlarmManager,
        atMillis: Long,
    ) {
        val pi = PendingIntent.getBroadcast(
            context, MINUTE_REFRESH_REQUEST_CODE, minuteTickIntent(context),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val canExact =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                alarmManager.canScheduleExactAlarms()
            } else {
                true
            }
        if (canExact) {
            try {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pi)
            } catch (e: SecurityException) {
                setAndAllowWhileIdle(alarmManager, atMillis, pi)
            }
        } else {
            setAndAllowWhileIdle(alarmManager, atMillis, pi)
        }
    }

    /**
     * The backstop that cannot die: one repeating inexact alarm. It is armed on
     * every render (same PendingIntent, so this re-aligns rather than stacks),
     * and the OS keeps re-delivering it even if a delivery was dropped.
     */
    private fun armMinuteBackstop(
        context: Context,
        alarmManager: AlarmManager,
        atMillis: Long,
    ) {
        val pi = PendingIntent.getBroadcast(
            context, MINUTE_BACKSTOP_REQUEST_CODE, minuteTickIntent(context),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.setInexactRepeating(
            AlarmManager.RTC_WAKEUP,
            atMillis,
            MINUTE_BACKSTOP_INTERVAL_MS,
            pi,
        )
    }

    private fun cancelMinuteTick(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            for (requestCode in intArrayOf(
                MINUTE_REFRESH_REQUEST_CODE,
                MINUTE_BACKSTOP_REQUEST_CODE,
            )) {
                val pi = PendingIntent.getBroadcast(
                    context, requestCode, minuteTickIntent(context),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                alarmManager.cancel(pi)
            }
        } catch (_: Throwable) {}
    }

    /**
     * Re-bakes the countdown pill every [PROGRESS_TICK_INTERVAL_MS] so the
     * PHASE bar visibly FILLS — the fix for «نوار پیشرفت حرکت نمیکند و گیر
     * کرده».
     *
     * The bar is a BITMAP. Every other refresh in the long «تا اذان» phase is
     * too coarse to move it: the boundary alarms fire only AT an adhan/iqamah
     * (hours apart), `liveLeaves` cancels the per-minute tick (the clock is a
     * live leaf, so it does not need it), and the 15-minute WorkManager
     * backstop leaves the bar sitting still for up to a quarter hour. A baked
     * bitmap cannot tick inside the launcher, so the bar needs a frequent
     * re-render of its own.
     *
     * This is ONE self-rearming alarm, armed whenever there is a countdown to
     * show (both phases — the gold «تا اقامه» window and the long accent
     * «تا اذان» window). It does NOT re-render the whole card:
     * [refreshProgress] merges a partial RemoteViews that sets ONLY the pill
     * bitmap, so the clock leaf, the capsules and the surface never cross the
     * binder again. The phase tint (gold during «تا اقامه», accent during
     * «تا اذان») is read fresh from the solver on every tick, so the gold bar
     * fills inside the iqamah window and the accent bar fills across the
     * adhan→adhan window without a single full render in between. The exact
     * boundary alarm still owns the caption/chronometer colour switch at the
     * phase edge.
     *
     * 30 s gives a smooth fill, and [WidgetArt.progressPill] quantises the fill
     * to 1 % buckets, so the bitmap cache stays small.
     */
    private fun scheduleProgressTicks(context: Context) {
        try {
            val model = PrayerWidgetModel.read(context)
            val hasCountdown = model.hasData && model.countdown.targetAtMillis > 0L
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pi = progressTickIntent(context)
            if (!hasCountdown) {
                alarmManager.cancel(pi)
                return
            }
            val atMillis = System.currentTimeMillis() + PROGRESS_TICK_INTERVAL_MS
            val canExact =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    alarmManager.canScheduleExactAlarms()
                } else {
                    true
                }
            if (canExact) {
                try {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pi)
                } catch (_: SecurityException) {
                    setAndAllowWhileIdle(alarmManager, atMillis, pi)
                }
            } else {
                setAndAllowWhileIdle(alarmManager, atMillis, pi)
            }
        } catch (e: Throwable) {
            Log.e(TAG, "scheduleProgressTicks failed: ${e.message}")
        }
    }

    /**
     * ONE PendingIntent for the whole progress chain, deliberately addressed to
     * the BASE provider component: [refreshProgress] re-arms both providers,
     * and a `javaClass`-scoped intent here would stack two 30 s alarms where
     * one is enough.
     */
    private fun progressTickIntent(context: Context): PendingIntent {
        val intent = Intent(context, PrayerWidget::class.java).apply {
            action = ACTION_PROGRESS_TICK
            setPackage(context.packageName)
        }
        return PendingIntent.getBroadcast(
            context, PROGRESS_TICK_REQUEST_CODE, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun cancelProgressTicks(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(progressTickIntent(context))
        } catch (_: Throwable) {}
    }

    private fun scheduleMidnightUpdate(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, javaClass).apply {
                action = ACTION_MIDNIGHT_REFRESH
                setPackage(context.packageName)
            }
            val pi = PendingIntent.getBroadcast(
                context, MIDNIGHT_REFRESH_REQUEST_CODE, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val cal = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val target = cal.timeInMillis
            val canScheduleExact =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    alarmManager.canScheduleExactAlarms()
                } else {
                    true
                }
            if (canScheduleExact) {
                try {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target, pi)
                } catch (e: SecurityException) {
                    setAndAllowWhileIdle(alarmManager, target, pi)
                }
            } else {
                setAndAllowWhileIdle(alarmManager, target, pi)
            }
        } catch (e: Throwable) {
            Log.e(TAG, "scheduleMidnightUpdate failed: ${e.message}")
        }
    }

    private fun cancelMidnightUpdate(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, javaClass).apply {
                action = ACTION_MIDNIGHT_REFRESH
                setPackage(context.packageName)
            }
            val pi = PendingIntent.getBroadcast(
                context, MIDNIGHT_REFRESH_REQUEST_CODE, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pi)
        } catch (_: Throwable) {}
    }

    private fun cancelWatchdog(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, javaClass).apply {
                action = ACTION_WATCHDOG
                setPackage(context.packageName)
            }
            val pi = PendingIntent.getBroadcast(
                context, WATCHDOG_REQUEST_CODE, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pi)
        } catch (_: Throwable) {}
    }

    /**
     * Arms exact alarms at today's stored adhan, iqamah and sunrise boundaries
     * (plus tomorrow's Fajr as an overnight safety net) so the widget
     * re-renders EXACTLY when a phase changes — the «next prayer» wash moves,
     * the dates roll, and the countdown is handed a new target on the next
     * render.
     *
     * Uses exact alarms when the user granted the "Alarms & reminders"
     * permission, otherwise falls back to
     * [AlarmManager.setAndAllowWhileIdle] (the phase may then be late; the
     * clock and the countdown inside the card are still exact, because they
     * tick inside the launcher).
     */
    private fun scheduleBoundaryUpdates(context: Context) {
        try {
            val prefs = WidgetRepository.prefs(context)
            val offsets = WidgetRepository.readIqamahOffsets(prefs)
            // parsePrayerString answers "--:--" when the stored value cannot be
            // read, and that string still CONTAINS a colon — accepting it here
            // armed the overnight safety net at 00:00 and its iqamah at the
            // default offset. Only a real 24-hour clock may enter the set.
            val valid = (1..5).mapNotNull { i ->
                val raw = prefs.getString("prayer_$i", "") ?: ""
                val time = WidgetRepository.parsePrayerString(raw).second
                val clock = parseClock(time) ?: return@mapNotNull null
                Triple(i - 1, clock.first, clock.second)
            }
            if (valid.isEmpty()) return

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            cancelBoundaryUpdates(context)
            val now = System.currentTimeMillis()
            val canExact =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    alarmManager.canScheduleExactAlarms()
                } else {
                    true
                }
            var idx = 0
            for ((position, item) in valid.withIndex()) {
                val (prayerIdx, h, m) = item
                val cal = Calendar.getInstance().apply {
                    set(Calendar.HOUR_OF_DAY, h)
                    set(Calendar.MINUTE, m)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }
                val adhanMillis = cal.timeInMillis
                if (adhanMillis > now) {
                    armBoundary(context, alarmManager, idx++, adhanMillis, canExact)
                }
                val off = if (prayerIdx < offsets.size) offsets[prayerIdx] else 10
                val configuredIqamahMillis = adhanMillis + off * 60_000L
                val nextAdhanMillis = valid.getOrNull(position + 1)?.let { next ->
                    Calendar.getInstance().apply {
                        set(Calendar.HOUR_OF_DAY, next.second)
                        set(Calendar.MINUTE, next.third)
                        set(Calendar.SECOND, 0)
                        set(Calendar.MILLISECOND, 0)
                    }.timeInMillis
                }
                val iqamahMillis = minOf(
                    configuredIqamahMillis,
                    nextAdhanMillis ?: Long.MAX_VALUE,
                )
                if (iqamahMillis > now) {
                    armBoundary(context, alarmManager, idx++, iqamahMillis, canExact)
                }
            }
            // Overnight safety net: tomorrow's Fajr + its iqamah, so the widget
            // still flips to «اذان صبح» even if the midnight alarm is deferred.
            val (_, fh, fm) = valid.first()
            val tomorrowFajr = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, fh)
                set(Calendar.MINUTE, fm)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val tf = tomorrowFajr.timeInMillis
            armBoundary(context, alarmManager, idx++, tf, canExact)
            val fajrOffset = if (offsets.isNotEmpty()) offsets[0] else 10
            armBoundary(context, alarmManager, idx++, tf + fajrOffset * 60_000L, canExact)

            // Sunrise boundary: the «خودکار» palette flips out of the dawn
            // phase at sunrise, and sunrise is the one daily boundary with no
            // adhan/iqamah alarm of its own. One extra slot, armed only when
            // the auto palette is actually selected.
            if (prefs.getString(WidgetTheme.PREF_PALETTE_ID, null) == WidgetTheme.AUTO_ID ||
                prefs.getString(WidgetTheme.WidgetTarget.PRAYER.paletteKey, null) == WidgetTheme.AUTO_ID
            ) {
                val sunriseRaw = prefs.getString("sunrise", "") ?: ""
                val sunrise = WidgetRepository.parsePrayerString(sunriseRaw).second
                val clock = parseClock(sunrise)
                if (clock != null) {
                    val sunriseMillis = Calendar.getInstance().apply {
                        set(Calendar.HOUR_OF_DAY, clock.first)
                        set(Calendar.MINUTE, clock.second)
                        set(Calendar.SECOND, 0)
                        set(Calendar.MILLISECOND, 0)
                    }.timeInMillis
                    if (sunriseMillis > now) {
                        armBoundary(context, alarmManager, idx++, sunriseMillis, canExact)
                    }
                }
            }
            Log.d(TAG, "Armed $idx boundary refresh alarms")
        } catch (e: Throwable) {
            Log.e(TAG, "scheduleBoundaryUpdates failed: ${e.message}")
        }
    }

    private fun armBoundary(
        context: Context,
        alarmManager: AlarmManager,
        index: Int,
        atMillis: Long,
        canExact: Boolean,
    ) {
        if (index >= BOUNDARY_SLOTS) return
        val intent = Intent(context, javaClass).apply {
            action = ACTION_BOUNDARY_REFRESH
            putExtra("boundary_idx", index)
            setPackage(context.packageName)
        }
        val pi = PendingIntent.getBroadcast(
            context, BOUNDARY_REQUEST_CODE_BASE + index, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        if (canExact) {
            try {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pi)
            } catch (e: SecurityException) {
                setAndAllowWhileIdle(alarmManager, atMillis, pi)
            }
        } else {
            setAndAllowWhileIdle(alarmManager, atMillis, pi)
        }
    }

    private fun cancelBoundaryUpdates(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            for (i in 0 until BOUNDARY_SLOTS) {
                val intent = Intent(context, javaClass).apply {
                    action = ACTION_BOUNDARY_REFRESH
                    setPackage(context.packageName)
                }
                val pi = PendingIntent.getBroadcast(
                    context, BOUNDARY_REQUEST_CODE_BASE + i, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                alarmManager.cancel(pi)
            }
        } catch (_: Throwable) {}
    }

    companion object {
        private const val TAG = "TawheeedPrayer"
        private const val MIDNIGHT_REFRESH_REQUEST_CODE = 9998
        private const val WATCHDOG_REQUEST_CODE = 9997
        // The minute tick's request code sits clear of the tasbih band
        // (9995/9996) and the boundary base (8900..8912).
        private const val MINUTE_REFRESH_REQUEST_CODE = 9994
        // The repeating backstop sits next to the precise tick but must be its
        // own PendingIntent (a repeating alarm cannot also be an exact
        // one-shot), so it gets its own request code.
        private const val MINUTE_BACKSTOP_REQUEST_CODE = 9993
        private const val MINUTE_BACKSTOP_INTERVAL_MS = 60_000L
        // The progress tick: re-bakes the countdown pill every 30 s so the
        // baked phase bar fills. Armed whenever there is a countdown to show;
        // clear of the minute band (9993/9994), the watchdog (9997), midnight
        // (9998) and boundaries (8900..8912).
        private const val PROGRESS_TICK_REQUEST_CODE = 9991
        private const val PROGRESS_TICK_INTERVAL_MS = 30_000L

        // The last-resort heal: 6h is the worst-case staleness for the PHASE if
        // every other alarm is silently dropped. The clock itself is no longer
        // covered by this bound — it ticks on its own.
        private const val WATCHDOG_INTERVAL_MS = 6 * 60 * 60 * 1000L
        private const val ACTION_MIDNIGHT_REFRESH = "com.tawheeed.WIDGET_MIDNIGHT_REFRESH"
        private const val ACTION_WATCHDOG = "com.tawheeed.WIDGET_WATCHDOG"
        private const val ACTION_MINUTE_REFRESH = "com.tawheeed.WIDGET_MINUTE_REFRESH"
        private const val ACTION_PROGRESS_TICK = "com.tawheeed.WIDGET_PROGRESS_TICK"

        /** A tap on one of the five prayer capsules: «خواندم». */
        const val ACTION_MARK_READ = "com.tawheeed.WIDGET_MARK_READ"
        const val EXTRA_PRAYER_INDEX = "prayer_idx"

        /**
         * Development instrument ([WidgetAudit]): render the card for an
         * explicit cell and log every band's measured height beside its price.
         * Nothing is sent to any widget and no state is written, so a stray
         * broadcast is harmless.
         */
        private const val ACTION_AUDIT = "com.tawheeed.WIDGET_AUDIT"
        private const val EXTRA_AUDIT_ID = "audit_id"
        private const val EXTRA_AUDIT_WIDTH = "audit_w"
        private const val EXTRA_AUDIT_HEIGHT = "audit_h"

        // Boundary (adhan/iqamah) exact refresh: 10 slots for today's 5 adhans +
        // 5 iqamahs, 2 more for tomorrow's Fajr, 1 for the sunrise flip of the
        // «خودکار» palette. Distinct request codes so each PendingIntent stays
        // unique.
        const val ACTION_BOUNDARY_REFRESH = "com.tawheeed.WIDGET_BOUNDARY_REFRESH"
        private const val BOUNDARY_REQUEST_CODE_BASE = 8900
        private const val BOUNDARY_SLOTS = 13

        /**
         * Strict 24-hour clock parser. `parsePrayerString` answers "--:--"
         * when the stored value cannot be read, and that string still
         * contains a colon — the old `contains(":")` test let it through and
         * the overnight safety net armed at 00:00. A regex-shaped value with
         * out-of-range fields ("25:70") is refused too, because Calendar is
         * lenient and would roll it into the next day.
         */
        fun parseClock(value: String): Pair<Int, Int>? {
            val match = Regex("""^(\d{1,2}):(\d{2})$""").matchEntire(value.trim())
                ?: return null
            val hour = match.groupValues[1].toIntOrNull() ?: return null
            val minute = match.groupValues[2].toIntOrNull() ?: return null
            if (hour !in 0..23 || minute !in 0..59) return null
            return Pair(hour, minute)
        }

        /** Re-renders every instance and re-arms the whole alarm chain.
         *  Fire-and-forget: alarm broadcasts and launcher taps must not block
         *  the binder thread on a render. */
        fun refreshAll(context: Context) {
            CoroutineScope(Dispatchers.Default).launch { refreshAllAwait(context) }
        }

        /**
         * The same work, synchronous.
         *
         * Needed by the one caller that must not be cut short: the boundary
         * broadcast arrives while the app may be *cold*, and a fire-and-forget
         * coroutine can be killed with the process the instant `onReceive`
         * returns — leaving the card exactly as stale as before. That caller
         * wraps this in `goAsync()` and finishes the pending result afterwards.
         */
        fun refreshAllAwait(context: Context) {
            val startedAt = android.os.SystemClock.uptimeMillis()
            try {
                WidgetTokens.init(context)
                // Data before paint.
                try {
                    WidgetRepository.recomputeTimesIfStale(context)
                } catch (e: Throwable) {
                    Log.e(TAG, "refresh recompute failed, painting stored data: ${e.message}")
                }
                renderAll(context)
                WidgetTiming.mark("prayer.render.done", startedAt, "origin=refreshAll")
            } catch (e: Throwable) {
                Log.e(TAG, "refreshAll render FAILED: ${e.message}")
            }
            try {
                // Re-arm BOTH prayer providers. `refreshAllAwait` lives in the
                // companion object (it is called as `PrayerWidget.refreshAll`
                // from AdhanReceiver / WidgetHub), so `this` here is the
                // companion, not a provider instance — `rearmAll` is an instance
                // method, so each provider is re-armed on its own instance. The
                // render above is shared, but the alarms are scoped per provider
                // via `javaClass`, so re-arming both keeps neither stranded.
                PrayerWidget().rearmAll(context)
                PrayerWidgetVertical().rearmAll(context)
            } catch (e: Throwable) {
                Log.e(TAG, "refreshAll arming FAILED: ${e.message}")
            }
        }

        /**
         * Flips one prayer's tick and repaints the card that was touched.
         *
         * The flip is of what the BOX IS SHOWING, not of the widget-local mark.
         * A prayer the app recorded as done shows a tick with no mark at all,
         * so flipping the mark alone would leave it ticked forever — the tap
         * has to be able to take a tick back, and that is what
         * [WidgetPrefs.setDone] records: a mark when the box was empty, a
         * CLEAR when it was ticked. [PrayerWidgetModel.isDone] then lets the
         * clear beat the app's own status until the app drains it.
         *
         * **Synchronous on purpose.** A tap arrives through
         * [PrayerMarkActivity], which must have the paint on its way to the
         * launcher BEFORE it calls `finish()`: a finished activity's process is
         * frozen almost immediately, and a render queued behind that freeze
         * never lands. (The tasbih trampoline paid for that lesson first.) The
         * work is one prefs write, one model read and one binder call — a few
         * milliseconds — so running it on the caller's thread costs nothing.
         *
         * The repaint is PARTIAL — [PrayerNativeViews.capsules] merged with
         * `partiallyUpdateAppWidget` — which is the whole point of the native
         * rewrite. The intent carries [PrayerNativeViews.EXTRA_APP_WIDGET_ID]
         * so the merge is addressed to the touched card; a missing id (an
         * intent built before the native rewrite, or a hand-rolled `adb
         * broadcast`) falls back to a full render of every instance.
         *
         * @return the new state of the box (true = ticked), or null when
         *   [index] is not a prayer.
         */
        internal fun applyMarkAndRender(
            context: Context,
            index: Int,
            widgetId: Int,
            startedAt: Long,
        ): Boolean? {
            if (index !in 0..4) {
                Log.w(TAG, "mark-read with a bad index: $index")
                return null
            }
            val prefs = WidgetRepository.prefs(context)
            // The tap is a TOGGLE of what the box is actually showing, not a
            // flip of the widget-local mark. A prayer the app recorded as done
            // is showing a tick with no mark at all, so flipping the mark alone
            // would leave it ticked forever («تیک برداشت برای هر ۵ نماز»). The
            // model is the only thing that knows all three sources.
            val doneNow = PrayerWidgetModel.read(context).isDone(index)
            val marked = WidgetPrefs.setDone(
                prefs, WidgetRepository.todayKey(), index, !doneNow,
            )
            WidgetTiming.mark(
                "tap.prefs.committed", startedAt,
                "prayer=$index was=$doneNow marked=$marked",
            )
            try {
                WidgetTokens.init(context)
                val manager = AppWidgetManager.getInstance(context)
                if (widgetId >= 0) {
                    try {
                        manager.partiallyUpdateAppWidget(
                            widgetId,
                            PrayerNativeViews.capsules(context, widgetId),
                        )
                    } catch (e: Throwable) {
                        // A stale id (the card was just removed) must not turn
                        // a tap into a crash.
                        Log.w(TAG, "tap partial render id=$widgetId failed: ${e.message}")
                    }
                } else {
                    renderAll(context)
                }
                WidgetTiming.mark("tap.render.done", startedAt, "prayer=$index")
            } catch (e: Throwable) {
                Log.e(TAG, "mark-read render failed: ${e.message}")
            }
            return marked
        }

        /**
         * Paints every instance of this widget, addressed **by component** —
         * `AppWidgetManager.getAppWidgetIds` is authoritative and cannot be
         * empty-but-silent, unlike the Glance session bookkeeping this
         * replaced (see the retired WidgetRender notes in git history).
         */
        fun renderAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            // Both prayer providers — the horizontal [PrayerWidget] and the
            // dedicated vertical [PrayerWidgetVertical] — share this one
            // repaint pass, so a single refresh (a boundary alarm, a snapshot
            // push, the periodic backstop) repaints every placed prayer card
            // regardless of which provider it belongs to. Each provider's own
            // alarms are still scoped to its own component (built against
            // `javaClass`), so arming or cancelling one never touches the
            // other's; only the render is shared.
            val components = listOf(
                ComponentName(context, PrayerWidget::class.java),
                ComponentName(context, PrayerWidgetVertical::class.java),
            )
            var any = false
            for (component in components) {
                val ids = manager.getAppWidgetIds(component) ?: continue
                if (ids.isEmpty()) continue
                any = true
                // The layout decision is known from the component we enumerated
                // by, so it is passed explicitly rather than re-guessed by
                // `useVertical` inside `full`. Guessing mattered because
                // `isVerticalWidget` reads `getAppWidgetInfo`, which is
                // transiently null right after a resize or restore; on such a
                // hiccup the legacy `widget_prayer_layout` pref (which a
                // dedicated vertical-provider widget never sets) would decide
                // "horizontal" and a vertical widget would flip on resize.
                val forceVertical = component.className == PrayerWidgetVertical::class.java.name
                for (id in ids) {
                    try {
                        manager.updateAppWidget(
                            id,
                            PrayerNativeViews.full(context, id, forceVertical = forceVertical),
                        )
                    } catch (t: Throwable) {
                        Log.w(TAG, "renderAll id=$id failed: ${t.message}")
                    }
                }
            }
            if (!any) {
                Log.w(TAG, "renderAll: no instances")
            }
        }

        /**
         * Re-bakes ONLY the countdown pill's bitmap for every placed prayer
         * card, via a PARTIAL merge — the clock leaf, the capsules and the
         * surface are untouched. Driven by [ACTION_PROGRESS_TICK] so the baked
         * phase bar fills in real time; the full [renderAll] still owns every
         * structural change (caption, chronometer colour, layout).
         *
         * Returns early for a compact widget that has no progress pill.
         */
        fun refreshProgress(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val components = listOf(
                ComponentName(context, PrayerWidget::class.java),
                ComponentName(context, PrayerWidgetVertical::class.java),
            )
            for (component in components) {
                val ids = manager.getAppWidgetIds(component) ?: continue
                if (ids.isEmpty()) continue
                val forceVertical = component.className == PrayerWidgetVertical::class.java.name
                for (id in ids) {
                    try {
                        val partial = PrayerNativeViews.progressOnly(
                            context, id, forceVertical = forceVertical,
                        ) ?: continue
                        manager.partiallyUpdateAppWidget(id, partial)
                    } catch (t: Throwable) {
                        Log.w(TAG, "refreshProgress id=$id failed: ${t.message}")
                    }
                }
            }
        }
    }
}
