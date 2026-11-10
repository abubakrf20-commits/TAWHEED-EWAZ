import 'dart:async';

import 'package:tawheeed/shared/utils/date_key.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tawheeed/features/adhkar/tasbih/domain/entities/tasbih_model.dart'
    as domain;
import 'package:tawheeed/features/adhkar/tasbih/data/daos/tasbih_dao.dart';
import 'package:tawheeed/features/adhkar/tasbih/presentation/providers/tasbih_daily_reset.dart';
import 'package:tawheeed/features/worship/data/daos/daily_status_dao.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'tasbih_provider.g.dart';

@riverpod
class Tasbih extends _$Tasbih {
  /// Resolved when the first load finishes. Every mutation awaits it: a tap
  /// landed while `build()` was still in flight used to hit `state.value ==
  /// null` and vanish silently — the counter moved on screen for one frame and
  /// the count was never written to the DB or the daily totals.
  Completer<void> _ready = Completer<void>();

  @override
  Future<List<domain.TasbihModel>> build() async {
    _ready = Completer<void>();
    try {
      final dao = ref.read(tasbihDaoProvider);

      // Auto-reset daily counts if a new day has started
      await _checkDailyReset(dao);

      final items = await dao.getAllDomain();
      if (items.isEmpty) {
        await dao.seedDefaults();
        final seeded = await dao.getAllDomain();
        seeded.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return seeded;
      }
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  Future<void> _awaitReady() async {
    if (!_ready.isCompleted) await _ready.future;
  }

  /// Checks whether today's counts should be reset (a new day + auto-reset
  /// enabled + the configured reset time has passed). If so, resets all
  /// [currentCount]s to 0 (preserving [totalLifetimeCount]) so each day starts
  /// fresh. The previous day's totals are already recorded in SharedPreferences
  /// (via [_recordDailyTap]) for the evaluation section.
  ///
  /// The decision itself lives in [tasbihResetDecision], shared with the boot
  /// maintenance timer and the azkar/tasbih tab's midnight timer, so the three
  /// can never disagree about which day is stamped or where the boundary sits.
  Future<void> _checkDailyReset(TasbihDao dao) async {
    final decision = await tasbihResetDecision(DateTime.now());
    if (decision == null) return;

    try {
      final items = await dao.getAllDomain();
      for (final item in items) {
        if (item.currentCount > 0) {
          await dao.resetCount(item.id);
        }
      }

      // Mark the app as the latest editor using the reset DEADLINE (not the
      // execution time): a daily reset only invalidates counts recorded BEFORE
      // the reset boundary. Widget taps made after the deadline are today's
      // taps and must win the next merge instead of being discarded.
      _markAppChangedAt(decision.deadline.millisecondsSinceEpoch);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(tasbihLastActiveDateKey, decision.today);
    } catch (e) {
      // Skipping the reset is the safe answer, but it must not be silent: a
      // DAO failure here means yesterday's counts survived into today and the
      // daily stats disagree with the dial.
      AppLogger.warning('tasbih_provider', 'daily reset skipped: $e');
    }
  }

  /// Records one tap into today's daily tasbih counters (used by evaluation
  /// stats and the per-dhikr weekly/monthly report). Persisted in Drift via
  /// DailyStatusDao: the total is stored under `tasbih_daily` and the
  /// per-dhikr breakdown under `tasbih_daily_<id>`.
  ///
  /// Best-effort analytics: callers start it without awaiting it. The count on
  /// the dial is persisted in the tasbih row, and the tap path must never be
  /// gated on this second store — see the call sites.
  Future<void> _recordDailyTap(String id) async {
    await _addDailyTap(id, 1);
  }

  /// Adds [amount] taps to today's daily tasbih counters in a single atomic
  /// UPSERT, so rapid taps never race against a read-modify-write.
  Future<void> _addDailyTap(String id, int amount) async {
    if (amount <= 0) return;
    try {
      final dao = ref.read(dailyStatusDaoProvider);
      final dateKey = dateKeyOf(DateTime.now());
      await dao.increment('tasbih_daily', dateKey, '', amount);
      await dao.increment('tasbih_daily_$id', dateKey, '', amount);
    } catch (e) {
      AppLogger.warning('tasbih_provider', 'Daily tap record error: $e');
    }
  }

  void _patchState(List<domain.TasbihModel> items) {
    state = AsyncValue.data(items);
  }

  /// Rolls an optimistic counter patch back by applying the *inverse delta* to
  /// the LIVE state instead of restoring the pre-patch snapshot. A snapshot
  /// rollback also erases every write that landed while the failed one was in
  /// flight — including a batch drained from the home-screen widget, which
  /// would silently delete real taps.
  ///
  /// A negative [count] undoes a reset (the optimistic delta was negative).
  /// Floors at 0: a failed patch must never drive a counter negative.
  void _compensate(String id, {int count = 0, int lifetime = 0}) {
    final items = state.value;
    if (items == null) return;
    final idx = items.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final live = items[idx];
    final newCount = live.currentCount - count;
    final newLifetime = live.totalLifetimeCount - lifetime;
    _patchState(
      [...items]..[idx] = live.copyWith(
        currentCount: newCount < 0 ? 0 : newCount,
        totalLifetimeCount: newLifetime < 0 ? 0 : newLifetime,
      ),
    );
  }

  /// Records that the app changed a tasbih counter right now. The widget-sync
  /// merge compares this against the widget's own tap timestamp — the most
  /// recent interaction wins — so the app's counts (including resets) always
  /// reach the home-screen widget. Fire-and-forget, like the daily counters.
  void _markAppChanged() {
    _markAppChangedAt(DateTime.now().millisecondsSinceEpoch);
  }

  /// Records that the app changed a tasbih counter at [millis]. The widget-sync
  /// merge compares this against the widget's own tap timestamp — the most
  /// recent interaction wins — so the app's counts (including resets) always
  /// reach the home-screen widget. The daily reset stamps the reset *deadline*
  /// here, not the execution time, so only counts recorded before the boundary
  /// lose the merge. Fire-and-forget, like the daily counters.
  void _markAppChangedAt(int millis) {
    SharedPreferences.getInstance().then((prefs) async {
      try {
        await prefs.setInt('tasbih_widget_last_changed_at', millis);
      } catch (_) {
        // Persistence write failed (e.g. test environment)
      }
    }).catchError((Object _) {
      // No SharedPreferences implementation (e.g. unit/integration tests) —
      // the app-change timestamp stays 0 and the native widget wins the
      // merge, which is the safe default outside a real device.
    });
  }

  /// Optimistically increments the counters in state immediately, then persists
  /// in the background. A failed write compensates the delta instead of
  /// restoring a stale snapshot, so taps never block on disk I/O and a
  /// concurrent write is never erased.
  Future<void> increment(String id) async {
    await _awaitReady();
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) return;
    final idx = current.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final previous = current[idx];
    final updated = previous.copyWith(
      currentCount: previous.currentCount + 1,
      totalLifetimeCount: previous.totalLifetimeCount + 1,
    );
    _patchState([...current]..[idx] = updated);
    _markAppChanged();
    try {
      await ref.read(tasbihDaoProvider).incrementLifetimeAndCount(id);
      // Fire-and-forget. Awaiting the daily-totals write chained every tap —
      // and therefore the burst flush, the home-widget sync and a queued
      // reset that the flush sequences — to a SECOND store. A slow or
      // unavailable DailyStatusDao (a DB locked by a backup, a stalled
      // channel) then froze the dial's whole write path while the count
      // itself had already landed. The tap counts (this row + lifetime) are
      // the contract of this future; the analytics row is not.
      unawaited(_recordDailyTap(id));
    } catch (e) {
      _compensate(id, count: 1, lifetime: 1);
      AppLogger.warning('tasbih_provider', 'Tasbih increment error: $e');
    }
  }

  /// Adds [amount] taps at once (used for manual bulk entry, e.g. counting
  /// beads by hand). Updates both the current/lifetime counters and the
  /// daily tasbih counter so evaluation stats stay consistent.
  Future<void> addCount(String id, int amount) async {
    if (amount <= 0) return;
    await _awaitReady();
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) return;
    final idx = current.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final previous = current[idx];
    final updated = previous.copyWith(
      currentCount: previous.currentCount + amount,
      totalLifetimeCount: previous.totalLifetimeCount + amount,
    );
    _patchState([...current]..[idx] = updated);
    _markAppChanged();
    try {
      await ref.read(tasbihDaoProvider).addLifetimeAndCount(id, amount);
      // Same contract as `increment`: the bulk write is what this future
      // reports; the daily breakdown follows on its own.
      unawaited(_addDailyTap(id, amount));
    } catch (e) {
      _compensate(id, count: amount, lifetime: amount);
      AppLogger.warning('tasbih_provider', 'Tasbih addCount error: $e');
    }
  }

  Future<void> reset(String id) async {
    await _awaitReady();
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) return;
    final idx = current.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final previous = current[idx];
    final updated = previous.copyWith(currentCount: 0);
    _patchState([...current]..[idx] = updated);
    _markAppChanged();
    try {
      await ref.read(tasbihDaoProvider).resetCount(id);
    } catch (e) {
      // The optimistic delta was -previous.currentCount, so undo it by adding
      // that many back to whatever the live counter reads now.
      _compensate(id, count: -previous.currentCount);
      AppLogger.warning('tasbih_provider', 'Tasbih reset error: $e');
    }
  }

  /// Zeroes every session counter at once (user decision, 2026-11-05: the
  /// evaluation's day reset also silences the dials — «پاک‌سازی کامل روز»).
  ///
  /// Lifetime totals are untouched; this is the same [resetCount] the tasbih
  /// screen uses, applied to all items in one write. The reload on failure is
  /// the honest fallback: per-item compensation against a half-applied batch
  /// would guess at which counters survived.
  Future<void> resetAllSessions() async {
    await _awaitReady();
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) return;
    if (!current.any((t) => t.currentCount > 0)) return;
    _patchState([for (final t in current) t.copyWith(currentCount: 0)]);
    _markAppChanged();
    try {
      await ref.read(tasbihDaoProvider).resetAllCounts();
    } catch (e) {
      AppLogger.warning('tasbih_provider', 'Tasbih resetAll error: $e');
      ref.invalidateSelf();
    }
  }

  Future<void> startNew({required String text, required int target}) async {
    await _awaitReady();
    if (!ref.mounted) return;
    final now = DateTime.now();
    final model = domain.TasbihModel(
      id: now.millisecondsSinceEpoch.toString(),
      name: text,
      targetDhikr: text,
      targetCount: target,
      createdAt: now,
    );
    try {
      await ref.read(tasbihDaoProvider).saveDomain(model);
      if (!ref.mounted) return;
      _patchState([model, ...state.value ?? []]);
    } catch (e) {
      AppLogger.warning('tasbih_provider', 'Tasbih startNew error: $e');
    }
  }

  Future<void> delete(String id) async {
    await _awaitReady();
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) return;
    final idx = current.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final removed = current[idx];
    _patchState(current.where((t) => t.id != id).toList());
    try {
      await ref.read(tasbihDaoProvider).deleteTasbih(id);
    } catch (e) {
      // Put it back where it was: the list is sorted by createdAt descending,
      // so appending the item would move it to the end of the dhikr pager.
      final live = List<domain.TasbihModel>.of(state.value ?? const []);
      final at = idx <= live.length ? idx : live.length;
      live.insert(at, removed);
      _patchState(live);
      AppLogger.warning('tasbih_provider', 'Tasbih delete error: $e');
    }
  }

  Future<void> updateTarget(String id, int target) async {
    await _awaitReady();
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) return;
    final idx = current.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final previous = current[idx];
    final updated = previous.copyWith(targetCount: target);
    _patchState([...current]..[idx] = updated);
    try {
      await ref.read(tasbihDaoProvider).updateTarget(id, target);
    } catch (e) {
      final live = state.value;
      if (live == null) return;
      final liveIdx = live.indexWhere((t) => t.id == id);
      if (liveIdx < 0) return;
      _patchState(
        [...live]..[liveIdx] = live[liveIdx].copyWith(
          targetCount: previous.targetCount,
        ),
      );
      AppLogger.warning('tasbih_provider', 'Tasbih updateTarget error: $e');
    }
  }

  /// Renames a dhikr, keeping every count it has.
  ///
  /// [TasbihDao.rename] shipped with no caller, so the only way to fix a typo
  /// was delete + recreate — which silently threw away `totalLifetimeCount`.
  /// [domain.TasbihModel.name] and `targetDhikr` both come from the single
  /// `dhikrText` column, so they move together or the dial keeps printing the
  /// old text until the next reload.
  Future<void> rename(String id, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _awaitReady();
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) return;
    final idx = current.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final previous = current[idx];
    if (previous.targetDhikr == trimmed) return;
    _patchState(
      [...current]..[idx] = previous.copyWith(
        name: trimmed,
        targetDhikr: trimmed,
      ),
    );
    try {
      await ref.read(tasbihDaoProvider).rename(id, trimmed);
      // The widget-sync merge keys its per-dhikr map by dhikr TEXT, so the old
      // text is an unknown key there until the next full snapshot. Stamping the
      // app as the newest editor is what keeps that stale key from being
      // imported back as a second, duplicate dhikr.
      _markAppChanged();
    } catch (e) {
      final live = state.value;
      if (live == null) return;
      final liveIdx = live.indexWhere((t) => t.id == id);
      if (liveIdx < 0) return;
      _patchState(
        [...live]..[liveIdx] = live[liveIdx].copyWith(
          name: previous.name,
          targetDhikr: previous.targetDhikr,
        ),
      );
      AppLogger.warning('tasbih_provider', 'Tasbih rename error: $e');
    }
  }

  /// Resets today's session counts for all tasbihs (custom items and lifetime
  /// stats are preserved).
  Future<void> clearHistory() async {
    await _awaitReady();
    if (!ref.mounted) return;
    try {
      final dao = ref.read(tasbihDaoProvider);
      await dao.resetAllCounts();
      _markAppChanged();
      final items = await dao.getAllDomain();
      if (!ref.mounted) return;
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _patchState(items);
    } catch (e) {
      AppLogger.warning('tasbih_provider', 'Tasbih clearHistory error: $e');
    }
  }
}
