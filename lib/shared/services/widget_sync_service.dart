import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/features/home/services/widget_sync_provider.dart';
import 'package:tawheeed/features/home/domain/entities/widget_snapshot.dart';
import 'package:tawheeed/features/adhkar/tasbih/data/daos/tasbih_dao.dart';
import 'package:tawheeed/features/adhkar/tasbih/domain/entities/tasbih_model.dart'
    as domain;
import 'package:tawheeed/features/adhkar/tasbih/tasbih.dart';
import 'package:tawheeed/features/worship/data/daos/daily_status_dao.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:tawheeed/shared/services/widget_calc_params.dart';
import 'package:tawheeed/features/settings/settings.dart';
import 'package:tawheeed/features/prayer/prayer.dart';
import 'package:tawheeed/features/prayer/domain/entities/prayer_info.dart' as pi;
import 'package:tawheeed/features/prayer/domain/prayer_windows.dart';
import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/core/constants/month_display.dart';
import 'package:tawheeed/shared/utils/date_key.dart';
import 'package:tawheeed/features/settings/presentation/widgets/widget_palettes.dart';
import 'package:tawheeed/shared/utils/hijri_utils.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/friday_prayer_label.dart';
import 'package:tawheeed/features/tools/calendar/presentation/widgets/calendar_widgets.dart';
import 'package:tawheeed/features/home/domain/entities/calendar_event.dart';
import 'package:tawheeed/features/khatm/presentation/providers/khatm_provider.dart';
import 'package:tawheeed/features/quran/data/quran_helpers.dart';

/// Singleton access to [WidgetSyncService] so screens and providers can
/// trigger a widget refresh without owning the service's timers.
final widgetSyncServiceProvider =
    Provider<WidgetSyncService>((ref) => WidgetSyncService());

/// Pure «last interaction wins» decision for the tasbih counter sync — returns
/// the count the app DB should take from the widget's per-zikr counter:
///  - the widget's counter predates the daily reset boundary
///    ([widgetBeforeResetBoundary]) → yesterday's/stale counts must never
///    resurrect — the app's (already reset) count wins exactly;
///  - the widget is the most recent editor → take its count exactly (this is
///    what lets a reset performed on the widget reach the app);
///  - otherwise only ever advance (a stale or lower widget value must never
///    erase counts the user recorded in the app).
int mergedTasbihCount({
  required bool widgetIsLatest,
  required int widgetCount,
  required int appCount,
  required bool widgetBeforeResetBoundary,
}) {
  if (widgetBeforeResetBoundary) return appCount;
  if (widgetIsLatest) return widgetCount;
  return widgetCount > appCount ? widgetCount : appCount;
}

/// Pure planner for the widget's pending tap events (see
/// [WidgetSyncService] — the drain): folds every event with a seq above
/// [appliedSeq] onto [appCounts] and returns the resulting count per dhikr
/// text. Events are the widget's queue shapes: `inc` (`s`,`z`,`d`), `reset`
/// (`s`,`z`; -1 zeroes every zikr), `zikr` (selection only — no counter) and
/// `full` (`s`,`c` = committed per-zikr counts keyed by index). Event
/// indices resolve through [zikrList]; out-of-range indices are skipped.
Map<String, int> drainedTasbihCounts({
  required List<Map<String, dynamic>> events,
  required List<String> zikrList,
  required Map<String, int> appCounts,
  required int appliedSeq,
}) {
  final result = Map<String, int>.of(appCounts);
  for (final event in events) {
    final seq = (event['s'] as num?)?.toInt() ?? 0;
    if (seq <= appliedSeq) continue;
    final kind = event['k']?.toString() ?? '';
    final zikrIdx = (event['z'] as num?)?.toInt() ?? -1;
    if (kind == 'full') {
      final committed = event['c'];
      if (committed is Map) {
        for (final entry in committed.entries) {
          final idx = int.tryParse(entry.key.toString());
          if (idx == null || idx < 0 || idx >= zikrList.length) continue;
          result[zikrList[idx]] = (entry.value as num?)?.toInt() ?? 0;
        }
      }
    } else if (kind == 'reset') {
      if (zikrIdx < 0) {
        for (final dhikr in zikrList) {
          result[dhikr] = 0;
        }
      } else if (zikrIdx < zikrList.length) {
        result[zikrList[zikrIdx]] = 0;
      }
    } else if (kind == 'inc') {
      final delta = (event['d'] as num?)?.toInt() ?? 0;
      if (zikrIdx >= 0 && zikrIdx < zikrList.length && delta != 0) {
        final dhikr = zikrList[zikrIdx];
        result[dhikr] = (result[dhikr] ?? 0) + delta;
      }
    }
  }
  return result;
}

/// [FardhPrayer] → the widget's own prayer names ([WidgetSnapshot.prayerOrder]).
const Map<FardhPrayer, String> _fardhWidgetNames = {
  FardhPrayer.fajr: 'فجر',
  FardhPrayer.dhuhr: 'ظهر',
  FardhPrayer.asr: 'عصر',
  FardhPrayer.maghrib: 'مغرب',
  FardhPrayer.isha: 'عشاء',
};

/// The widget's tap index → [FardhPrayer]. The widget stores the index of the
/// prayer box that was tapped (`WidgetPrefs.KEY_PRAYER_READ`), so this list is
/// the *only* place that ordering is interpreted — keep it aligned with
/// [WidgetSnapshot.prayerOrder] and with the Kotlin five-box row.
const List<FardhPrayer> _widgetPrayerOrder = [
  FardhPrayer.fajr,
  FardhPrayer.dhuhr,
  FardhPrayer.asr,
  FardhPrayer.maghrib,
  FardhPrayer.isha,
];

class WidgetSyncService {
  Timer? _syncTimer;
  Timer? _refreshTimer;
  Timer? _debounceTimer;
  Timer? _retryTimer;
  final Duration _minSyncGap = const Duration(seconds: 1);
  DateTime? _lastSyncAt;

  void dispose() {
    _syncTimer?.cancel();
    _refreshTimer?.cancel();
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
  }

  /// Stops the periodic cycles while the app is not in the foreground.
  ///
  /// They used to run for the whole process lifetime, so on Android — which
  /// commonly keeps the process alive long after the user leaves — the app
  /// kept waking the isolate every 30 minutes for nothing. [startAutoSync]
  /// restarts them on resume and syncs immediately, which is exactly the
  /// catch-up the background gap needs.
  void pauseAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  void startAutoSync(WidgetRef ref) {
    _syncNow(ref);
    _syncTimer =
        Timer.periodic(const Duration(minutes: 30), (_) => _syncNow(ref));
    _refreshTimer = Timer.periodic(
        const Duration(hours: 24), (_) => _refreshPrayerTimes(ref));

    // تلاش مجدد بعد از 10 ثانیه
    _retryTimer = Timer(const Duration(seconds: 10), () => _syncNow(ref));
  }

  /// Millis of the last time the app changed any tasbih counter (increment,
  /// manual add, reset, daily reset). Compared against the widget's own tap
  /// timestamp in the merge — the most recent interaction wins.
  static Future<int> _tasbihAppChangedAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('tasbih_widget_last_changed_at') ?? 0;
    } catch (e) {
      AppLogger.warning('WidgetSync', 'int parse failed: $e');
      return 0;
    }
  }

  /// Records «the app just changed the counters» for the widget merge.
  ///
  /// Called after a drain import and after every snapshot push: a push
  /// carries the app's counts, so it is an app-side edit — not a user tap.
  /// 2026-10-16 device finding: [WidgetRepository.persistSnapshot] stamps
  /// the widget's `last_tap_at` on every push, and without this stamp the
  /// next reconcile read that push time as "the user tapped the widget
  /// after the app" and let the widget's just-pushed copy roll a freshly
  /// drained import back — a 103-tap import became 0 one sync pass later.
  static Future<void> _markAppChangedNow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'tasbih_widget_last_changed_at',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      AppLogger.warning('WidgetSync', 'app-change stamp failed: $e');
    }
  }

  /// Whether the widget's counters were last written BEFORE today's daily
  /// reset boundary. The widget stamps `widget_tasbih_last_tap_at` on every
  /// tap AND on every app push, so this reliably distinguishes "counts from
  /// yesterday / before the reset" (must not resurrect after a reset) from
  /// "counts recorded today after the reset boundary" (must be imported).
  static Future<bool> _tasbihWidgetStaleForToday(int nativeTapAt) async {
    try {
      if (nativeTapAt <= 0) return false;
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('azkar_autoReset') ?? true)) return false;
      final now = DateTime.now();
      final hour = prefs.getInt('azkar_resetHour') ?? 0;
      final minute = prefs.getInt('azkar_resetMinute') ?? 0;
      final boundary = DateTime(now.year, now.month, now.day, hour, minute);
      return nativeTapAt < boundary.millisecondsSinceEpoch;
    } catch (e) {
      AppLogger.warning('WidgetSync', 'flag read failed: $e');
      return false;
    }
  }

  /// Seq of the last widget tap event this app durably applied.
  static const _kTasbihAppliedSeq = 'widget_tasbih_applied_seq';

  /// Applies the widget's undrained tap events (seq > persisted applied seq)
  /// additively onto the app's counters, then acks the native queue.
  ///
  /// The per-zikr counts alone cannot express «+5 taps» versus «counter
  /// replaced», so a wholesale count-merge loses taps the app's later edits
  /// were unaware of. Event shapes fold through [drainedTasbihCounts].
  /// Applied seq is persisted after the DB writes and before the ack, so a
  /// crash in that window re-applies a batch (visible, resettable) rather
  /// than silently dropping counted worship.
  ///
  /// Returns the dhikr texts whose app counter this drain wrote. The counts
  /// merge that runs right after must skip them: the widget's per-zikr
  /// snapshot still holds the pre-drain values (the push that re-aligns it
  /// happens at the end of the sync), so re-merging would roll the freshly
  /// imported taps back — on the 2026-10-16 device state that would have
  /// wiped a 103-tap import to the widget's stale 0 one line after the ack
  /// pruned the queue.
  Future<Set<String>> _drainPendingTasbihEvents(
    WidgetRef ref,
    Map<String, dynamic> data,
  ) async {
    try {
      final events = (data['pendingEvents'] as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
      final nativeSeq = (data['pendingSeq'] as num?)?.toInt() ?? 0;
      if (events.isEmpty || nativeSeq <= 0) return const <String>{};

      final prefs = await SharedPreferences.getInstance();
      final appliedSeq = prefs.getInt(_kTasbihAppliedSeq) ?? 0;
      if (!events.any((e) => ((e['s'] as num?)?.toInt() ?? 0) > appliedSeq)) {
        // Everything already applied (retry after a crash past the ack) —
        // just re-ack so the native side can prune.
        await ref.read(widgetSyncProvider).drainTasbihEvents(appliedSeq);
        return const <String>{};
      }

      final zikrList =
          (data['zikrList'] as List<dynamic>?)?.cast<String>() ?? const [];
      if (zikrList.isEmpty) return const <String>{};

      final dao = ref.read(tasbihDaoProvider);
      final appTasbihs = await dao.getAllDomain();
      final appCounts = <String, int>{
        for (final t in appTasbihs) t.targetDhikr: t.currentCount,
      };
      final drained = drainedTasbihCounts(
        events: events,
        zikrList: zikrList,
        appCounts: appCounts,
        appliedSeq: appliedSeq,
      );

      final claimedAppIds = <String>{};
      final appliedTexts = <String>{};
      for (final entry in drained.entries) {
        if (entry.value == (appCounts[entry.key] ?? 0)) continue;
        domain.TasbihModel? app;
        for (final candidate in appTasbihs) {
          if (claimedAppIds.contains(candidate.id)) continue;
          if (candidate.targetDhikr != entry.key) continue;
          if (app == null || candidate.createdAt.isBefore(app.createdAt)) {
            app = candidate;
          }
        }
        if (app == null) {
          AppLogger.warning(
            'WidgetSync.drainPendingTasbihEvents',
            'no app row for «${entry.key}» — its taps stay on the widget',
          );
          continue;
        }
        claimedAppIds.add(app.id);
        await dao.saveDomain(app.copyWith(currentCount: entry.value));
        appliedTexts.add(entry.key);
      }

      // These writes are app-side counter changes: stamp the app-change time
      // so the counts merge cannot later read the widget's older copy as the
      // most recent editor and roll the import back. 2026-10-16: without
      // this, a sync pass after the ack pruned the queue re-wrote the
      // widget's pre-import zeros over a fresh drain import.
      if (appliedTexts.isNotEmpty) await _markAppChangedNow();

      await prefs.setInt(_kTasbihAppliedSeq, nativeSeq);
      await ref.read(widgetSyncProvider).drainTasbihEvents(nativeSeq);
      ref.invalidate(tasbihProvider);
      return appliedTexts;
    } catch (e) {
      AppLogger.error('WidgetSyncService.drainPendingTasbihEvents', e);
      return const <String>{};
    }
  }

  Future<void> _refreshPrayerTimes(WidgetRef ref) async {
    try {
      final legacyPrayer = ref.read(prayerTimeServiceProvider);
      await legacyPrayer.loadPrayerTimes(forceRefresh: true);
      _syncNow(ref);
    } catch (e) {
      AppLogger.error('WidgetSyncService._refreshPrayerTimes', e);
    }
  }

  void scheduleSync(WidgetRef ref) {
    _debounceTimer?.cancel();
    _debounceTimer =
        Timer(const Duration(milliseconds: 800), () => _syncNow(ref));
  }

  Future<void> syncWidgetsNow(WidgetRef ref) async {
    await _syncNow(ref);
  }

  /// Pulls counters the user recorded directly on the home-screen tasbih
  /// widget into the app database, so the widget and the app tab always agree
  /// (the widget keeps its own prefs counters; this is the only writer that
  /// imports them into the DB).
  ///
  /// «Last interaction wins» — the same rule the snapshot merge uses:
  ///  - widget is the most recent editor (its tap timestamp is newer than the
  ///    app's) → its per-zikr counters are written EXACTLY (handles resets),
  ///    and unknown zikrs the user counted on the widget are created.
  ///  - app is the most recent editor → counters only ever advance (a stale
  ///    widget snapshot must never erase counts recorded in the app).
  ///
  /// The event drain runs first and its freshly written dhikrs are excluded
  /// from the per-zikr merge (see [_drainPendingTasbihEvents]).
  ///
  /// Also imports the widget's daily tap total into the evaluation stats
  /// (`tasbih_daily`) so the گزارش اذکار/ارزیابی reflects widget taps.
  Future<void> reconcileTasbihFromWidget(WidgetRef ref) async {
    try {
      final data = await ref.read(widgetSyncProvider).getTasbihData();
      final perZikrCounts =
          (data['perZikrCounts'] as Map<dynamic, dynamic>?) ?? {};
      final zikrList =
          (data['zikrList'] as List<dynamic>?)?.cast<String>() ?? [];

      // Import the widget's discrete tap events FIRST — the counts merge
      // below then runs on top of the imported deltas. Dhikrs the drain just
      // wrote are excluded from that merge (see _drainPendingTasbihEvents).
      final drainedTexts = await _drainPendingTasbihEvents(ref, data);

      if (perZikrCounts.isEmpty || zikrList.isEmpty) return;

      final appChangedAt = await _tasbihAppChangedAt();
      final nativeTapAt = (data['lastTapAt'] as num?)?.toInt() ?? 0;
      // The widget is the latest editor only when the user actually tapped it
      // AFTER the last app-side change — otherwise the app's counters win.
      final widgetIsLatest = nativeTapAt > appChangedAt;
      // Counts written before today's reset boundary are yesterday's — after a
      // daily reset they must NOT be imported back (the max() merge would
      // otherwise resurrect them and undo the reset).
      final widgetBeforeResetBoundary =
          await _tasbihWidgetStaleForToday(nativeTapAt);

      final dao = ref.read(tasbihDaoProvider);
      final appTasbihs = await dao.getAllDomain();

      var changed = false;
      // The native per-zikr map is keyed by dhikr TEXT. A custom dhikr that
      // duplicates a default's text must resolve to the SAME app row on every
      // reconcile, so duplicates are handed out in a stable order (earliest
      // createdAt) and claimed rows are excluded from later matches — instead
      // of `where(...).first`, which silently depended on the DAO's ordering.
      final claimedAppIds = <String>{};
      for (final entry in perZikrCounts.entries) {
        final dhikrText = entry.key.toString();
        // The drain above already wrote this dhikr's authoritative count; the
        // widget's per-zikr snapshot still holds the pre-drain value (the
        // push that re-aligns it runs at the end of this sync), so merging it
        // here would roll the freshly imported taps back.
        if (drainedTexts.contains(dhikrText)) continue;
        final widgetCount = (entry.value as num).toInt();
        domain.TasbihModel? app;
        for (final candidate in appTasbihs) {
          if (claimedAppIds.contains(candidate.id)) continue;
          if (candidate.targetDhikr != dhikrText) continue;
          if (app == null || candidate.createdAt.isBefore(app.createdAt)) {
            app = candidate;
          }
        }
        if (app != null) {
          claimedAppIds.add(app.id);
          final target = mergedTasbihCount(
            widgetIsLatest: widgetIsLatest,
            widgetCount: widgetCount,
            appCount: app.currentCount,
            widgetBeforeResetBoundary: widgetBeforeResetBoundary,
          );
          if (target != app.currentCount) {
            await dao.saveDomain(app.copyWith(currentCount: target));
            changed = true;
          }
        } else if (widgetIsLatest &&
            widgetCount > 0 &&
            !widgetBeforeResetBoundary) {
          // The user counted a zikr on the widget that the app doesn't know
          // yet — create it so the tab shows the same value.
          final now = DateTime.now();
          await dao.saveDomain(domain.TasbihModel(
            id: now.millisecondsSinceEpoch.toString(),
            name: dhikrText,
            targetDhikr: dhikrText,
            targetCount: 100,
            currentCount: widgetCount,
            totalLifetimeCount: widgetCount,
            createdAt: now,
          ));
          changed = true;
        }
      }

      if (changed) ref.invalidate(tasbihProvider);

      // Import today's widget tap total into the evaluation stats so the
      // روزانه گزارش in the app counts widget taps too.
      final widgetDaily = data['widgetTasbihDaily'] as int? ?? 0;
      final widgetDailyDate = data['widgetTasbihDailyDate'] as String? ?? '';
      if (widgetDaily > 0 && widgetDailyDate.isNotEmpty) {
        final now = DateTime.now();
        final todayStr =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        if (widgetDailyDate == todayStr) {
          final statusDao = ref.read(dailyStatusDaoProvider);
          final existing =
              await statusDao.getValue('tasbih_daily', todayStr, '') ?? 0;
          if (widgetDaily > existing) {
            await statusDao.set('tasbih_daily', todayStr, '', widgetDaily);
          }
        }
      }
    } catch (e) {
      AppLogger.error('WidgetSyncService.reconcileTasbih', e);
    }
  }

  /// Imports the «خواندم» taps made on the home-screen prayer widget.
  ///
  /// The widget owns two date-scoped lists: `widget_prayer_read` (ticks the
  /// user ADDED on the card) and `widget_prayer_cleared` (ticks the user took
  /// BACK). It deliberately never rewrites the app's `prayer_statuses`: a
  /// snapshot push landing between the tap and the next sync would undo it, and
  /// the tracker would lose the distinction between «recorded in the app» and
  /// «tapped on the home screen». This is the only writer that turns either
  /// list into a tracker row, and it acks exactly the indices it wrote — a tap
  /// that lands mid-drain therefore survives to the next pass instead of being
  /// cleared unread.
  ///
  /// Clears are applied FIRST, and the marks pass then DEFERS to them (see
  /// [_applyMarksFromWidget]'s `vetoed` argument). The two lists are mutually
  /// exclusive per index at the source — `WidgetPrefs.setDone` writes both in
  /// one commit — but the pair is read with two separate `getString` calls, so
  /// a tap landing between them can hand us `marks=[2]` and `cleared=[2]`
  /// together. The user's last word is the clear, so the clear wins and the
  /// stale mark is acked without being applied.
  Future<void> reconcilePrayerMarksFromWidget(WidgetRef ref) async {
    try {
      final marks = await ref.read(widgetSyncProvider).getPrayerMarks();
      final today = dateKeyOf(DateTime.now());
      final clearedDate = marks['clearedDate'] as String? ?? '';
      final cleared = ((marks['cleared'] as List?) ?? const [])
          .whereType<num>()
          .map((e) => e.toInt())
          .toList();
      await _applyClearedFromWidget(ref, clearedDate, cleared, today);

      final date = marks['date'] as String? ?? '';
      final indices = ((marks['indices'] as List?) ?? const [])
          .whereType<num>()
          .map((e) => e.toInt())
          .toList();
      // A clear only vetoes a mark for the SAME day: a clear belonging to
      // yesterday says nothing about today's box.
      final vetoed = clearedDate == date ? cleared.toSet() : const <int>{};
      await _applyMarksFromWidget(ref, date, indices, today, vetoed);
    } catch (e) {
      AppLogger.error('WidgetSyncService.reconcilePrayerMarks', e);
    }
  }

  /// Ticks the user took BACK on the card → the tracker row goes to `pending`.
  ///
  /// `pending`, never `missed`: a clear means «I did not pray this after all»,
  /// and the tracker raises «missed» on its own once the day is over. Writing
  /// `missed` here would put words in the user's mouth.
  Future<void> _applyClearedFromWidget(
    WidgetRef ref,
    String date,
    List<int> indices,
    String today,
  ) async {
    if (date.isEmpty || indices.isEmpty) return;
    // Yesterday's clears are history: drop them, never apply them to today.
    if (date != today) {
      await ref
          .read(widgetSyncProvider)
          .drainPrayerCleared(date: date, indices: indices);
      return;
    }
    final tracker = ref.read(prayerTrackerProvider.notifier);
    final applied = <int>[];
    for (final index in indices) {
      if (index < 0 || index >= _widgetPrayerOrder.length) continue;
      final prayer = _widgetPrayerOrder[index];
      if (tracker.getStatus(prayer) != PrayerStatus.pending) {
        tracker.setStatus(prayer, PrayerStatus.pending);
      }
      applied.add(index);
    }
    if (applied.isNotEmpty) {
      await ref
          .read(widgetSyncProvider)
          .drainPrayerCleared(date: date, indices: applied);
    }
  }

  /// Ticks the user ADDED on the card → the tracker row goes to `done`.
  ///
  /// [vetoed] holds indices the user cleared for the same day. They are acked
  /// (so the stale mark cannot be replayed on the next pass) but NOT applied:
  /// the clear is the user's last word, and it already set the row to
  /// `pending`.
  Future<void> _applyMarksFromWidget(
    WidgetRef ref,
    String date,
    List<int> indices,
    String today,
    Set<int> vetoed,
  ) async {
    if (date.isEmpty || indices.isEmpty) return;
    // Yesterday's marks are history: drop them, never apply them to today.
    if (date != today) {
      await ref
          .read(widgetSyncProvider)
          .drainPrayerMarks(date: date, indices: indices);
      return;
    }
    final tracker = ref.read(prayerTrackerProvider.notifier);
    final applied = <int>[];
    for (final index in indices) {
      if (index < 0 || index >= _widgetPrayerOrder.length) continue;
      if (vetoed.contains(index)) {
        // Ack it away, but leave the row alone: the clear already decided.
        applied.add(index);
        continue;
      }
      final prayer = _widgetPrayerOrder[index];
      final current = tracker.getStatus(prayer);
      // A tap means «I prayed it». It never downgrades a prayer the app
      // already recorded (done or qada) and never writes «missed».
      if (current != PrayerStatus.done && current != PrayerStatus.qada) {
        tracker.setStatus(prayer, PrayerStatus.done);
      }
      applied.add(index);
    }
    if (applied.isNotEmpty) {
      await ref
          .read(widgetSyncProvider)
          .drainPrayerMarks(date: date, indices: applied);
    }
  }

  /// The widget's time input: `{date, today:{…}, tomorrow:{…}}`, `HH:mm`.
  ///
  /// Tomorrow is computed here rather than in Kotlin so the widget never runs
  /// the astronomical solver inside a composition — and so the «after Isha»
  /// countdown points at tomorrow's real Fajr instead of repeating today's.
  /// Returns null when today's five clocks are not all known: a partial
  /// payload would make the widget show «--:--» for the missing ones.
  String? _timesPayload(
    WidgetRef ref,
    AppSettings settings,
    DateTime now,
    Map<String, String> today,
  ) {
    String? clock(Map<String, String> map, String key) {
      final value = map[key];
      return (value == null || value.isEmpty || value.contains('--'))
          ? null
          : value;
    }

    final todayJson = <String, String>{
      'fajr': clock(today, 'فجر') ?? '',
      'dhuhr': clock(today, 'ظهر') ?? '',
      'asr': clock(today, 'عصر') ?? '',
      'maghrib': clock(today, 'مغرب') ?? '',
      'isha': clock(today, 'عشاء') ?? '',
      'sunrise': clock(today, 'طلوع') ?? '',
    };
    // A partial payload is worse than none: the widget would paint «--:--»
    // for the missing clocks instead of keeping the times it already has.
    const adhanKeys = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
    if (adhanKeys.any((key) => (todayJson[key] ?? '').isEmpty)) return null;
    Map<String, String>? tomorrowJson;
    try {
      // `DateTime(y, m, d + 1)` normalises month/year rollover and keeps the
      // wall-clock day, which `add(Duration(days: 1))` does not across DST.
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final times = ref
          .read(prayerTimeServiceProvider)
          .prayerTimesForDate(tomorrow, settings: settings);
      if (times != null) {
        String hhmm(pi.PrayerInfo info) =>
            '${info.time.hour.toString().padLeft(2, '0')}:'
            '${info.time.minute.toString().padLeft(2, '0')}';
        tomorrowJson = <String, String>{
          'fajr': hhmm(times.fajr),
          'dhuhr': hhmm(times.duhr),
          'asr': hhmm(times.asr),
          'maghrib': hhmm(times.maghrib),
          'isha': hhmm(times.isha),
          'sunrise': hhmm(times.shorouq),
        };
      }
    } catch (e) {
      // Tomorrow is an optimisation, not a requirement: the widget falls back
      // to today's Fajr for the post-Isha countdown.
      AppLogger.warning('WidgetSync', 'tomorrow times failed: $e');
    }

    return jsonEncode(<String, dynamic>{
      'date': dateKeyOf(now),
      'today': todayJson,
      if (tomorrowJson != null) 'tomorrow': tomorrowJson,
    });
  }

  /// The four ARGB channels are always `0`: «no override».
  ///
  /// These are ONE set for the whole widget host, and the native resolver
  /// applies them to every card it draws. Pushing the PRAYER palette here —
  /// what the old code did, reading `theme['prayer']` — painted the tasbih
  /// card in the prayer's colours and made an independently chosen tasbih
  /// palette look ignored, which is exactly the reported «تسبیح سبز، اوقات
  /// آبی نمی‌شود». Each widget now resolves its own
  /// `widget_palette_id_{prayer,tasbih}` natively from the same
  /// `assets/widget_palettes.json`, so the app must not override either.
  ///
  /// An «خودکار» palette already needed `0` here: its *phase* (night / dawn /
  /// … / evening) is decided by the widget's own boundary alarms, and
  /// re-deriving it here would let the two sides drift a whole prayer apart.
  List<int> _paletteArgb() => const [0, 0, 0, 0];

  Future<void> _syncNow(WidgetRef ref) async {
    final now = DateTime.now();
    if (_lastSyncAt != null && now.difference(_lastSyncAt!) < _minSyncGap) {
      return;
    }

    try {
      _lastSyncAt = now;
      // Import any taps made directly on the widget into the app DB before
      // building the snapshot, so the push-back merge is consistent.
      await reconcileTasbihFromWidget(ref);
      // «خواندم» taps on the prayer widget are app-owned data the widget must
      // never write itself — drain them into the tracker here, before the
      // snapshot is built, so the pushed `prayerStatuses` already includes
      // them (otherwise the card would repaint a just-tapped prayer as
      // unread until the *next* sync).
      await reconcilePrayerMarksFromWidget(ref);
      // The drain above invalidates [tasbihProvider]; await its rebuild so
      // the snapshot below carries the freshly imported counts instead of
      // the stale pre-import value an invalidated future would hand back.
      // 2026-10-16: that staleness pushed the widget's counts backwards by
      // one sync, which the next pass then treated as the widget's "latest"
      // edit and wrote over the drain's import.
      try {
        await ref.read(tasbihProvider.future);
      } catch (e) {
        AppLogger.warning('WidgetSync._syncNow', 'fresh tasbih read failed: $e');
      }
      final widgetSync = ref.read(widgetSyncProvider);
      final prayerState = ref.read(prayerTimesProvider);
      final settings = ref.read(settingsProvider).value ?? const AppSettings();

      final snapshot = await buildSnapshot(ref, prayerState, settings);
      await widgetSync.syncSnapshot(snapshot);
      // A push carries the app's counts, so it IS an app-side edit: stamp
      // the app-change time after it. WidgetRepository.persistSnapshot
      // stamps the widget's own last_tap_at on every push, and without this
      // stamp the next reconcile reads that push time as "the user tapped
      // the widget after the app" and lets the widget's just-pushed copy
      // win the merge (the 2026-10-16 rollback path above).
      await _markAppChangedNow();
    } catch (e) {
      AppLogger.error('WidgetSyncService._syncNow', e);
    }
  }

  Future<WidgetSnapshot> buildSnapshot(
    WidgetRef ref,
    AsyncValue<dynamic> prayerState,
    AppSettings settings,
  ) async {
    final now = DateTime.now();
    final jalali = Jalali.fromDateTime(now);
    const gregorianMonths = DateConstants.gregorianMonths;
    // The widget is rendered by Android without the app running, so it must
    // carry the month names of the user's choice at push time.
    final persianMonths = DateConstants.monthsFor(
      await readStoredMonthDisplay(),
    );
    final hijri = HijriUtils.hijriFromGreg(now.year, now.month, now.day,
        offset: settings.hijriOffset);
    const hijriMonths = DateConstants.hijriMonths;

    // Today's Islamic occasions — rendered on the home-screen widget.
    final todayEvents =
        occasionsForDay(CalendarKind.hijri, hijri.month, hijri.day)
            .map((o) => CalendarEvent(title: o.label, date: 'امروز'))
            .toList();

    String? nextPrayerName;
    int? nextPrayerMinutes;
    String? nextPrayerTime;
    final Map<String, String> allTimes = {};
    Map<String, String>? prayerStatuses;
    String currentPrayerName = '';
    int timelineProgress = 0;

    if (prayerState.value != null) {
      final prayerTimes = prayerState.value;
      final sunriseAt = DateTime(now.year, now.month, now.day,
          prayerTimes.shorouq.time.hour, prayerTimes.shorouq.time.minute);
      final asrAt = DateTime(now.year, now.month, now.day,
          prayerTimes.asr.time.hour, prayerTimes.asr.time.minute);
      final maghribAt = DateTime(now.year, now.month, now.day,
          prayerTimes.maghrib.time.hour, prayerTimes.maghrib.time.minute);
      final ishaAt = DateTime(now.year, now.month, now.day,
          prayerTimes.isha.time.hour, prayerTimes.isha.time.minute);
      final times = <String, DateTime>{
        'فجر': DateTime(now.year, now.month, now.day,
            prayerTimes.fajr.time.hour, prayerTimes.fajr.time.minute),
        'طلوع': sunriseAt,
        'ظهر': DateTime(now.year, now.month, now.day,
            prayerTimes.duhr.time.hour, prayerTimes.duhr.time.minute),
        'عصر': asrAt,
        'مغرب': maghribAt,
        'عشاء': ishaAt,
      };

      // Per-prayer completion for the widget's five rows: "done" (done or
      // qada), "missed" (window closed with nothing logged) or "pending".
      // Pushed only when the tracker has loaded — a map built from an empty
      // state would repaint real checks as unknown.
      final tracker = ref.read(prayerTrackerProvider).value;
      if (tracker != null) {
        final endsAt = fardhWindowEnds(
          sunrise: sunriseAt,
          asr: asrAt,
          maghrib: maghribAt,
          isha: ishaAt,
          today: now,
        );
        // حیض/نفاس suspend prayer, so their days must never read as missed.
        // While the period provider is still loading the answer is unknown;
        // suppressing the red dash is the safe side (the home card rebuilds
        // when the period loads, the widget only at the next sync).
        final periodKnown = ref.read(periodProvider).value != null;
        final exempt = periodKnown &&
            ref.read(periodProvider.notifier).isDateInPeriod(now);
        final widgetStatuses = fardhWidgetStatuses(
          statuses: tracker.fardStatuses,
          endsAt: endsAt,
          now: now,
          exempt: exempt || !periodKnown,
        );
        prayerStatuses = {
          for (final entry in _fardhWidgetNames.entries)
            entry.value: widgetStatuses[entry.key] ?? 'pending',
        };
      }

      const arabicToDisplay = <String, String>{
        'فجر': 'اذان صبح',
        'ظهر': 'اذان ظهر',
        'عصر': 'اذان عصر',
        'مغرب': 'اذان مغرب',
        'عشاء': 'اذان عشاء',
      };

      final prayerKeys = <String, String>{
        'فجر': 'fajr',
        'طلوع': 'sunrise',
        'ظهر': 'dhuhr',
        'عصر': 'asr',
        'مغرب': 'maghrib',
        'عشاء': 'isha'
      };

      for (final entry in prayerKeys.entries) {
        final time = times[entry.key];
        if (time != null) {
          allTimes[entry.key] =
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
        }
      }

      // The countdown must always target the next *adhan* — the five prayers
      // only. Sunrise (طلوع) is kept in [times] for display/`sunrise` but must
      // never be the countdown target, otherwise between Fajr and sunrise the
      // snapshot would pair «اذان صبح» with the minutes-until-sunrise.
      const adhanNames = ['فجر', 'ظهر', 'عصر', 'مغرب', 'عشاء'];
      final todayPrayerDates = [
        for (final n in adhanNames)
          if (times[n] case final DateTime t) t,
      ]..sort((a, b) => a.compareTo(b));
      final next = _nextPrayerTime(todayPrayerDates);
      if (next != null) {
        nextPrayerMinutes = next.difference(now).inMinutes;
        final matching = times.entries.where((e) {
          final dt = DateTime(e.value.year, e.value.month, e.value.day,
              e.value.hour, e.value.minute);
          return dt.difference(next).inMilliseconds == 0;
        }).toList();
        if (matching.isNotEmpty) {
          nextPrayerName = arabicToDisplay[matching.first.key];
        } else if (next.day != now.day ||
            next.month != now.month ||
            next.year != now.year) {
          nextPrayerName = 'اذان صبح';
        }
        nextPrayerTime =
            '${next.hour.toString().padLeft(2, '0')}:${next.minute.toString().padLeft(2, '0')}';
      }

      if (nextPrayerName == null && times.isNotEmpty) {
        nextPrayerName = 'اذان صبح';
        nextPrayerTime =
            '${times['فجر']?.hour.toString().padLeft(2, '0') ?? '--'}:${times['فجر']?.minute.toString().padLeft(2, '0') ?? '--'}';
      }

      const prayerTimeNames = ['فجر', 'ظهر', 'عصر', 'مغرب', 'عشاء'];
      for (final name in prayerTimeNames.reversed) {
        final t = times[name];
        if (t != null && t.isBefore(now)) {
          currentPrayerName = arabicToDisplay[name] ?? name;
          final nextIdx = prayerTimeNames.indexOf(name) + 1;
          if (nextIdx < prayerTimeNames.length) {
            final nextT = times[prayerTimeNames[nextIdx]];
            if (nextT != null) {
              final total = nextT.difference(t).inSeconds;
              if (total > 0) {
                timelineProgress =
                    ((now.difference(t).inSeconds / total) * 10000)
                        .round()
                        .clamp(0, 10000);
              }
            }
          } else {
            final nextT = times['فجر'];
            if (nextT != null) {
              final nextDay = DateTime(
                  now.year, now.month, now.day + 1, nextT.hour, nextT.minute);
              final total = nextDay.difference(t).inSeconds;
              if (total > 0) {
                timelineProgress =
                    ((now.difference(t).inSeconds / total) * 10000)
                        .round()
                        .clamp(0, 10000);
              }
            }
          }
          break;
        }
      }
      if (currentPrayerName.isEmpty) {
        currentPrayerName = 'اذان عشاء';
      }
    }

    String tasbihDhikr = '';
    int tasbihCount = 0;
    int tasbihTarget = 33;
    bool tasbihActive = false;
    int tasbihZikrIndex = 0;
    List<String> tasbihZikrList = [];
    List<int> tasbihZikrTargets = [];
    List<int> tasbihZikrCounts = [];

    try {
      final tasbihState = ref.read(tasbihProvider);
      final tasbihData = tasbihState.value;
      if (tasbihData != null && tasbihData.isNotEmpty) {
        final current = tasbihData.first;
        tasbihDhikr = current.targetDhikr;
        tasbihTarget = current.targetCount;
        tasbihZikrList = tasbihData.map((e) => e.targetDhikr).toList();
        // Per-zikr targets from the app (each zikr can have its own target).
        final appTargets = <String, int>{
          for (final t in tasbihData) t.targetDhikr: t.targetCount,
        };

        // The app owns the LIST of adhkar (add/delete/reorder happen in the
        // app); the widget keeps only its own selection + per-zikr counters.
        // Native stays authoritative for the *selection* (swiping zikrs on the
        // widget must survive a sync) — matched by dhikr TEXT so a removed or
        // reordered zikr never maps to the wrong entry — and for counts that
        // changed on the widget AFTER the app last changed them (so widget
        // taps made while the app was closed aren't erased). Counts the app
        // changed most recently win — the old max() merge could never reset a
        // stale native counter after the app's daily reset.
        final native = await ref.read(widgetSyncProvider).getTasbihData();
        final nativeList =
            (native['zikrList'] as List<dynamic>?)?.cast<String>() ?? const [];
        final nativePerZikr =
            (native['perZikrCounts'] as Map<dynamic, dynamic>?) ?? const {};
        final nativeDhikr = (native['dhikr'] as String?)?.trim() ?? '';
        final nativeTapAt = (native['lastTapAt'] as num?)?.toInt() ?? 0;
        final appCounts = <String, int>{
          for (final t in tasbihData) t.targetDhikr: t.currentCount,
        };
        final appChangedAt = await _tasbihAppChangedAt();
        // «Last interaction wins» — the side whose user action happened most
        // recently owns the counters.
        final appIsLatest = appChangedAt >= nativeTapAt;
        // The app list is the source of truth for the SET of adhkar; the
        // widget's copy is only a fallback while the app has no zikrs yet.
        final mergedList =
            tasbihZikrList.isNotEmpty ? tasbihZikrList : nativeList;
        final mergedCounts = <String, int>{
          for (final dhikr in mergedList)
            dhikr: appIsLatest
                ? (appCounts[dhikr] ?? 0)
                : ((nativePerZikr[dhikr] as num?)?.toInt() ??
                    (appCounts[dhikr] ?? 0)),
        };
        if (mergedList.isNotEmpty) {
          tasbihZikrList = mergedList;
          tasbihZikrTargets = [
            for (final dhikr in mergedList) appTargets[dhikr] ?? tasbihTarget,
          ];
          // Push the merged per-zikr counters back to the widget so switching
          // zikrs on the widget shows the app's latest counts for all zikrs.
          tasbihZikrCounts = [
            for (final dhikr in mergedList) mergedCounts[dhikr] ?? 0,
          ];
          // Match the widget's selection by dhikr text; fall back to the
          // app's currently active zikr, then the first entry.
          var idx = mergedList.indexOf(nativeDhikr);
          if (idx < 0) idx = mergedList.indexOf(tasbihDhikr);
          if (idx < 0) idx = 0;
          tasbihZikrIndex = idx;
          tasbihDhikr = mergedList[idx];
          tasbihCount = mergedCounts[tasbihDhikr] ?? 0;
          if (idx < tasbihZikrTargets.length) {
            tasbihTarget = tasbihZikrTargets[idx];
          }
        }
        tasbihActive = tasbihCount > 0;
      }
    } catch (e) {
      AppLogger.warning('WidgetSync', 'Tasbih snapshot failed: $e');
    }

    // The widget's native midnight reset must respect the app's
    // «ریست خودکار روزانه» setting — read from prefs (authoritative).
    var tasbihAutoReset = true;
    var azkarHaptic = true;
    var tasbihAutoAdvance = false;
    var widgetShowProgress = true;
    var widgetShowGregorian = true;
    var widgetFaDigits = false;
    var prayerLayout = WidgetSnapshot.prayerLayoutHorizontal;
    try {
      final prefs = await SharedPreferences.getInstance();
      tasbihAutoReset = prefs.getBool('azkar_autoReset') ?? true;
      azkarHaptic = prefs.getBool('azkar_haptic') ?? true;
      tasbihAutoAdvance = prefs.getBool('tasbih_auto_advance') ?? false;
      widgetShowProgress = prefs.getBool('widget_show_progress') ?? true;
      widgetFaDigits = prefs.getBool('widget_fa_digits') ?? false;
      widgetShowGregorian = prefs.getBool('widget_show_gregorian') ?? true;
      // «چیدمان ویجت اوقات نماز». A missing key is the horizontal card, and
      // anything this build does not know is coerced to it — the native side
      // coerces too, so the two can never disagree about what is drawable.
      prayerLayout = prefs.getString('widget_prayer_layout') ==
              WidgetSnapshot.prayerLayoutVertical
          ? WidgetSnapshot.prayerLayoutVertical
          : WidgetSnapshot.prayerLayoutHorizontal;
    } catch (_) {
      // No prefs (test env) — default to enabled.
    }

    // Active khatm: today's pages vs the daily target (ختم قرآن).
    var khatmActive = false;
    var khatmPagesToday = 0;
    var khatmDailyTarget = 0;
    var khatmCurrentJuz = 0;
    var khatmCurrentSurah = '';
    var khatmTotalPages = 604;
    var khatmReadPages = 0;
    try {
      final khatm = ref.read(khatmProvider).value;
      if (khatm != null && !khatm.isCompleted) {
        khatmActive = true;
        khatmPagesToday = khatm.pagesToday;
        khatmDailyTarget = khatm.dailyTarget;
        khatmTotalPages = khatm.totalPages;
        khatmReadPages = khatm.readPages;

        // Current reading position = the first page not yet read. Derive
        // juz (every 20 pages) and the surah name from the app's Quran data.
        final nextPage =
            khatm.pagesRead.indexWhere((p) => !p); // 0-based; -1 if none
        if (nextPage >= 0) {
          final page = nextPage + 1;
          khatmCurrentJuz = ((page - 1) ~/ 20) + 1;
          try {
            final entries = getPageData(page);
            if (entries.isNotEmpty) {
              final surah = entries.first['surah'] as int? ?? 1;
              khatmCurrentSurah = getSurahNameArabic(surah);
            }
          } catch (e) {
            // Page data unavailable — leave the surah label empty.
            AppLogger.warning('WidgetSync', 'khatm page data failed: $e');
          }
        }
      }
    } catch (e) {
      AppLogger.warning('WidgetSync', 'Khatm snapshot failed: $e');
    }

    final cityName = settings.city?.isNotEmpty == true
        ? settings.city!
        : (ref.read(prayerTimeServiceProvider).cityName.isNotEmpty
            ? ref.read(prayerTimeServiceProvider).cityName
            : 'موقعیت خودکار');

    // Native self-refresh inputs: the widget recomputes today's times itself
    // (midnight / stale sync) from these — same coordinates + parameters the
    // app's prayer engine used, so the two never drift apart.
    final coords = ref.read(prayerTimeServiceProvider).coordinates;
    final calcParams =
        widgetCalcParamsFor(settings.calculationMethod, settings);
    final hijriOffset = settings.hijriOffset;

    // Map display prayer name to iqamah offset
    final iqamahMap = <String, int>{
      'اذان صبح': settings.iqamahOffsetFajr,
      'اذان ظهر': settings.iqamahOffsetDhuhr,
      'اذان عصر': settings.iqamahOffsetAsr,
      'اذان مغرب': settings.iqamahOffsetMaghrib,
      'اذان عشاء': settings.iqamahOffsetIsha,
    };
    final iqamahOffset =
        nextPrayerName != null ? (iqamahMap[nextPrayerName] ?? 10) : 10;

    // The widget's paint contract: four raw ARGB channels (0 = «let the
    // native palette resolver decide») and today+tomorrow's clocks.
    final paletteArgb = _paletteArgb();
    final timesJson =
        allTimes.isEmpty ? null : _timesPayload(ref, settings, now, allTimes);

    return WidgetSnapshot(
      nextPrayerName: fridayPrayerLabel(nextPrayerName ?? '', now),
      nextPrayerMinutes: nextPrayerMinutes ?? 0,
      nextPrayerTime: nextPrayerTime ?? '',
      nextPrayerIqamahOffset: iqamahOffset,
      iqamahOffsets: [
        settings.iqamahOffsetFajr,
        settings.iqamahOffsetDhuhr,
        settings.iqamahOffsetAsr,
        settings.iqamahOffsetMaghrib,
        settings.iqamahOffsetIsha,
      ],
      shamsiDate:
          '${jalali.day} ${persianMonths[jalali.month - 1]} ${jalali.year}',
      gregorianDate: '${now.day} ${gregorianMonths[now.month - 1]} ${now.year}',
      hijriDate: '${hijri.day} ${hijriMonths[hijri.month - 1]} ${hijri.year}',
      cityName: cityName,
      prayers: Map.fromEntries(
        WidgetSnapshot.prayerOrder
            .map((name) => MapEntry(name, allTimes[name] ?? '')),
      ),
      sunrise: allTimes['طلوع'] ?? '',
      sunset: allTimes['مغرب'] ?? '',
      azanSound: settings.azanSound,
      tasbihDhikr: tasbihDhikr,
      tasbihCount: tasbihCount,
      tasbihTarget: tasbihTarget,
      tasbihActive: tasbihActive,
      tasbihZikrIndex: tasbihZikrIndex,
      tasbihZikrList: tasbihZikrList,
      tasbihZikrTargets: tasbihZikrTargets,
      tasbihZikrCounts: tasbihZikrCounts,
      tasbihAutoReset: tasbihAutoReset,
      azkarHaptic: azkarHaptic,
      tasbihAutoAdvance: tasbihAutoAdvance,
      widgetShowProgress: widgetShowProgress,
      widgetShowGregorian: widgetShowGregorian,
      widgetFaDigits: widgetFaDigits,
      prayerLayout: prayerLayout,
      currentPrayerName: fridayPrayerLabel(currentPrayerName, now),
      timelineProgress: timelineProgress,
      prayerStatuses: prayerStatuses,
      khatmActive: khatmActive,
      khatmPagesToday: khatmPagesToday,
      khatmDailyTarget: khatmDailyTarget,
      khatmCurrentJuz: khatmCurrentJuz,
      khatmCurrentSurah: khatmCurrentSurah,
      khatmTotalPages: khatmTotalPages,
      khatmReadPages: khatmReadPages,
      syncTimestamp: DateTime.now().millisecondsSinceEpoch,
      use12Hour: settings.use12Hour,
      calcLatitude: coords?.latitude,
      calcLongitude: coords?.longitude,
      calcMethod: settings.calculationMethod.name,
      calcFajrAngle: calcParams.fajrAngle,
      calcIshaAngle: calcParams.ishaAngle,
      calcMaghribAngle: calcParams.maghribAngle,
      calcIshaInterval: calcParams.ishaInterval,
      calcMadhab: settings.asrMethod == AsrMethod.hanafi ? 1 : 0,
      calcHighLatitude: settings.highLatitudeRule.index,
      calcMethodAdjustments: calcParams.methodAdjustments,
      calcUserAdjustments: [
        settings.fajrOffset + settings.globalPrayerOffset,
        settings.sunriseOffset + settings.globalPrayerOffset,
        settings.dhuhrOffset + settings.globalPrayerOffset,
        settings.asrOffset + settings.globalPrayerOffset,
        settings.maghribOffset + settings.globalPrayerOffset,
        settings.ishaOffset + settings.globalPrayerOffset,
      ],
      calcTimezone: settings.timezone,
      // The widget must render with the SAME offset the app used — its own
      // tz database can be stale (Iran DST removal lagged on old devices).
      // Falls back to the zone's own offset when it cannot be resolved.
      calcFixedOffsetMinutes: _fixedOffsetMinutes(settings),
      calcElevationAdjustments: _elevationAdjustments(ref, settings),
      calcHijriOffset: hijriOffset,
      calendarEvents: todayEvents,
      accentArgb: paletteArgb[0],
      textArgb: paletteArgb[1],
      bgArgb: paletteArgb[2],
      bgEndArgb: paletteArgb[3],
      prayerTimesJson: timesJson,
    );
  }

  /// Elevation (horizon-dip) deltas for the widget's native recompute, as
  /// `[sunriseMinutes, maghribMinutes]`.
  ///
  /// These are read back from the repository rather than re-solved here: the
  /// widget can only start from the repository's ALREADY corrected times, and
  /// re-solving on those converges to `[0, 0]` — which silently dropped the
  /// correction from the widget whenever it was enabled.
  List<int> _elevationAdjustments(WidgetRef ref, AppSettings settings) {
    if (!(settings.elevationCorrection)) return const [0, 0];
    try {
      return ref.read(prayerTimeServiceProvider).elevationAdjustments;
    } catch (e) {
      AppLogger.warning('WidgetSync', 'elevation read failed: $e');
      return const [0, 0];
    }
  }

  /// The per-date UTC offset of [AppSettings.timezone] in minutes, resolved
  /// with the same tz package the prayer engine uses (DST-correct for 2026+).
  int _fixedOffsetMinutes(AppSettings settings) {
    try {
      tzdata.initializeTimeZones();
      final loc = tz.getLocation(settings.timezone);
      return tz.TZDateTime.from(DateTime.now().toUtc(), loc)
          .timeZoneOffset
          .inMinutes;
    } catch (e) {
      AppLogger.warning('WidgetSync', 'fixed offset resolve failed: $e');
      return WidgetSnapshot.absentOffset;
    }
  }

  DateTime? _nextPrayerTime(List<DateTime> prayerTimes) {
    if (prayerTimes.isEmpty) return null;
    final now = DateTime.now();
    for (final time in prayerTimes) {
      if (time.isAfter(now)) return time;
    }
    final tomorrow = now.add(const Duration(days: 1));
    final fajr = prayerTimes.first;
    return DateTime(
        tomorrow.year, tomorrow.month, tomorrow.day, fajr.hour, fajr.minute);
  }
}
