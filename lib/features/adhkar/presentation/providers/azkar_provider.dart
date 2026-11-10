import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tawheeed/features/adhkar/data/repositories/azkar_repository_impl.dart';
import 'package:tawheeed/features/adhkar/data/azkar_data.dart';
import 'package:tawheeed/features/adhkar/domain/entities/zikr_item.dart';
import 'package:tawheeed/features/adhkar/domain/entities/general_zikr.dart';
import 'package:tawheeed/features/adhkar/domain/repositories/azkar_repository.dart'
    as repo;
import 'package:tawheeed/features/adhkar/utils/azkar_day_boundary.dart';
import 'package:tawheeed/features/adhkar/tasbih/data/daos/tasbih_dao.dart';
import 'package:tawheeed/features/adhkar/tasbih/domain/entities/tasbih_model.dart'
    as tm;

part 'azkar_provider.g.dart';

@riverpod
class Azkar extends _$Azkar {
  final _completions = <String, bool>{};
  final _counts = <String, int>{};
  final _statsCache = <String, Map<String, int>>{};
  int _version = 0;
  String _loadedDay = '';
  repo.AzkarRepository? _repo;

  /// Monotonically increasing counter bumped on every completion toggle.
  int get version => _version;

  @override
  Future<List<ZikrItem>> build() async {
    // A rebuild starts from a clean slate: stats memoized while the data was
    // still loading (the 0/0 card) must not survive into the loaded state.
    _completions.clear();
    _statsCache.clear();
    _repo = await ref.watch(azkarRepositoryProvider.future);
    await AzkarData.ensureLoaded();
    _loadedDay = _todayKey();
    await _restoreCounts();
    final items = AzkarData.allAzkar;
    for (final z in items) {
      final status = _repo!.getStatus(z.id);
      if (status == repo.ZikrStatus.done) _completions[z.id] = true;
    }
    return items;
  }

  /// In-progress repetition counts (e.g. 47/100) survive app restarts and
  /// provider rebuilds via this SharedPreferences mirror.
  static const _countsKey = 'azkar_partial_counts';
  static const _countsDayKey = 'azkar_partial_counts_day';
  SharedPreferences? _prefs;

  Future<void> _restoreCounts() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      if (_prefs!.getString(_countsDayKey) != _loadedDay) {
        _prefs!.remove(_countsKey);
        return;
      }
      final raw = _prefs!.getString(_countsKey);
      if (raw == null) return;
      final map = jsonDecode(raw);
      if (map is Map) {
        for (final e in map.entries) {
          final v = e.value;
          if (e.key is String && v is num) _counts[e.key as String] = v.toInt();
        }
      }
    } catch (_) {
      // Prefs unavailable or corrupt — counting starts from zero.
    }
  }

  void _persistCounts() {
    final prefs = _prefs;
    if (prefs == null) return;
    prefs.setString(_countsDayKey, _loadedDay);
    prefs.setString(_countsKey, jsonEncode(_counts));
  }

  /// Clock seam so tests can simulate a calendar-day rollover.
  @visibleForTesting
  static DateTime Function() nowOverride = DateTime.now;

  String _todayKey() => AzkarDayBoundary.dayKey(nowOverride());

  /// Reloads the in-memory completions when the calendar day changes, so
  /// yesterday's "done" items don't linger into today.
  /// این متد همگام است تا در pathهای sync (isCompleted/periodStats) بدون await قابل فراخوانی باشد؛
  /// بارگذاری واقعی از DB قبلاً در AzkarRepositoryImpl مدیریت شده و برای روز جدید خالی است.
  void _refreshIfDayChanged() {
    final day = _todayKey();
    if (day == _loadedDay) return;
    _loadedDay = day;
    _completions.clear();
    _counts.clear();
    _persistCounts();
    _statsCache.clear();
    // برای روز جدید، از کشِ از قبل بارگذاری‌شدهٔ repo بخوان (که برای روز جدید خالی است)
    // اگر repo هنوز در حال بارگذاری روز جدید باشد، این حلقه خالی می‌ماند و در فریم بعدی
    // با فراخوانی دوبارهٔ _refreshIfDayChanged یا با bump version درست می‌شود
    for (final z in AzkarData.allAzkar) {
      if (_repo?.getStatus(z.id) == repo.ZikrStatus.done) {
        _completions[z.id] = true;
      }
    }
    _version++;
    // اطمینان از اینکه UI بازسازی شود حتی اگر state همان بماند
    // scheduled with addPostFrameCallback so this can be safely called during
    // the widget build (e.g. from periodStats) without the
    // "Tried to modify a provider while the widget tree was building" error.
    final items = state.value ?? AzkarData.allAzkar;
    if (items.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        state = AsyncValue.data([...items]);
      });
    }
  }

  /// اجبار به بارگذاری مجدد از DB — برای pull-to-refresh و onResume
  Future<void> reload() async {
    final newDay = _todayKey();
    final dayChanged = newDay != _loadedDay;
    _loadedDay = newDay;
    _completions.clear();
    // یک reload در میانهٔ روز نباید شمارش‌های نیمه‌کارهٔ امروز را پاک کند؛
    // فقط وقتی روز منطقی عوض شده آن‌ها دور ریخته می‌شوند.
    if (dayChanged) {
      _counts.clear();
      _persistCounts();
    }
    _statsCache.clear();
    // اطمینان از اینکه repo کش روز فعلی را دارد
    if (_repo is AzkarRepositoryImpl) {
      await (_repo as AzkarRepositoryImpl).ensureTodayLoaded();
    }
    for (final z in AzkarData.allAzkar) {
      if (_repo?.getStatus(z.id) == repo.ZikrStatus.done) {
        _completions[z.id] = true;
      }
    }
    _version++;
    final items = state.value ?? AzkarData.allAzkar;
    state = AsyncValue.data([...items]);
  }

  /// Re-reads today's azkar state after the evaluation's range reset deleted
  /// the zikr rows behind this provider's back.
  ///
  /// [reload] trusts the repository's today-cache within one day, so it would
  /// resurrect the very completions the reset deleted. This path forces the
  /// cache to re-read from the DB, drops the in-progress counters (the day they
  /// belonged to is gone) and rebuilds the completion map from what survived.
  Future<void> refreshAfterExternalReset() async {
    _loadedDay = _todayKey();
    _completions.clear();
    _counts.clear();
    _persistCounts();
    _statsCache.clear();
    final r = _repo;
    if (r is AzkarRepositoryImpl) {
      await r.reloadTodayCache();
    }
    for (final z in AzkarData.allAzkar) {
      if (_repo?.getStatus(z.id) == repo.ZikrStatus.done) {
        _completions[z.id] = true;
      }
    }
    _version++;
    final items = state.value ?? AzkarData.allAzkar;
    state = AsyncValue.data([...items]);
  }

  bool isCompleted(String id) {
    _refreshIfDayChanged();
    return _completions[id] ?? false;
  }

  int getCount(String id, int target) {
    _refreshIfDayChanged();
    if (_completions[id] == true) return target;
    return _counts[id] ?? 0;
  }

  /// Writes an absolute count for a counted dhikr.
  ///
  /// The counters used to only walk up one step at a time, which is fine for a
  /// tap but cannot express undo or a session restored from storage. Reaching
  /// the target completes the item; zero clears both the count and the flag,
  /// so the collection views never disagree with what the pages show.
  Future<void> setCount(String id, int value, int target) async {
    _refreshIfDayChanged();
    final limit = target < 1 ? 1 : target;
    final clamped = value.clamp(0, limit);
    if (clamped >= limit) {
      await completeCount(id, limit);
      return;
    }
    if (clamped <= 0) {
      await resetProgress(id);
      return;
    }
    _completions.remove(id);
    _counts[id] = clamped;
    _persistCounts();
    _statsCache.clear();
    _version++;
    await _repo?.setStatus(id, repo.ZikrStatus.pending);
    final items = state.value ?? AzkarData.allAzkar;
    state = AsyncValue.data([...items]);
  }

  Future<void> incrementCount(String id, int target) async {
    _refreshIfDayChanged();
    final cur = _counts[id] ?? 0;
    if (cur >= target) return;
    final next = cur + 1;
    _counts[id] = next;
    if (next >= target) {
      _counts.remove(id);
      _persistCounts();
      _completions[id] = true;
      _statsCache.clear();
      _version++;
      await _repo?.setStatus(id, repo.ZikrStatus.done);
      final items = state.value ?? AzkarData.allAzkar;
      state = AsyncValue.data([...items]);
    } else {
      _persistCounts();
      _version++;
      final items = state.value ?? AzkarData.allAzkar;
      state = AsyncValue.data([...items]);
    }
  }

  /// Completes a counted dhikr in one persistence transition.
  ///
  /// The timeline uses this for its quick-complete action so a 100+ repetition
  /// dhikr does not cause one repository write per remaining repetition.
  Future<void> completeCount(String id, int target) async {
    _refreshIfDayChanged();
    if (target <= 0) {
      await markCompleted(id);
      return;
    }
    await _repo?.setStatus(id, repo.ZikrStatus.done);
    _counts.remove(id);
    _persistCounts();
    _completions[id] = true;
    _statsCache.clear();
    _version++;
    final items = state.value ?? AzkarData.allAzkar;
    state = AsyncValue.data([...items]);
  }

  Future<void> resetCount(String id) async {
    _counts.remove(id);
    _persistCounts();
    await resetProgress(id);
  }

  Future<void> markCompleted(String id) async {
    _refreshIfDayChanged();
    if (_counts.remove(id) != null) _persistCounts();
    _completions[id] = true;
    _statsCache.clear();
    _version++;
    await _repo?.setStatus(id, repo.ZikrStatus.done);
    final items = state.value ?? AzkarData.allAzkar;
    state = AsyncValue.data([...items]);
  }

  /// Marks many items done in a single write; the in-memory completion map is
  /// only updated after the persistence succeeds so a failure stays consistent.
  Future<void> markCompletedBatch(List<String> ids) async {
    if (ids.isEmpty) return;
    _refreshIfDayChanged();
    await _repo?.setStatusBatch(ids, repo.ZikrStatus.done);
    var countsChanged = false;
    for (final id in ids) {
      _completions[id] = true;
      if (_counts.remove(id) != null) countsChanged = true;
    }
    if (countsChanged) _persistCounts();
    _statsCache.clear();
    _version++;
    final items = state.value ?? AzkarData.allAzkar;
    state = AsyncValue.data([...items]);
  }

  Future<void> resetProgress(String id) async {
    _refreshIfDayChanged();
    _completions.remove(id);
    // «بازنشانی» means back to zero: without this the dhikr reopened at its
    // last partial count (getCount falls through to `_counts` once the
    // completion flag is gone), so the card showed 3/100 for a reset item.
    if (_counts.remove(id) != null) _persistCounts();
    _statsCache.clear();
    _version++;
    await _repo?.setStatus(id, repo.ZikrStatus.pending);
    final items = state.value ?? AzkarData.allAzkar;
    state = AsyncValue.data([...items]);
  }

  Map<String, int> periodStats(PrayerPeriod period) {
    _refreshIfDayChanged();
    final cacheKey = period.name;
    final cached = _statsCache[cacheKey];
    if (cached != null) return cached;
    // اگر state هنوز لود نشده، از AzkarData.allAzkar به‌عنوان fallback استفاده کن
    // تا total درست باشد و done از _completions خوانده شود
    final items = state.value ?? AzkarData.allAzkar;
    final periodItems =
        items.where((z) => z.period.name == period.name).toList();
    // اگر هنوز هیچ آیتمی نداریم (مثلاً AzkarData هنوز لود نشده)، از getByPeriod استفاده کن
    final effectiveItems =
        periodItems.isEmpty ? AzkarData.getByPeriod(period) : periodItems;
    final done = effectiveItems.where((z) => _completions[z.id] == true).length;
    final result = <String, int>{'done': done, 'total': effectiveItems.length};
    // Only a LOADED, non-empty reading is worth memoizing. The card asks for
    // stats during the first frame, before AzkarData has parsed; caching that
    // 0/0 made the ring stick at 0/0 for the whole session.
    if (state.hasValue && AzkarData.allAzkar.isNotEmpty) {
      _statsCache[cacheKey] = result;
    }
    return result;
  }
}

/// Lightweight version counter that bumps every time an azkar completion
/// toggles. Consumers can watch this instead of the full async [azkarProvider]
/// to avoid async lifecycle issues in tests and reduce rebuild scope.
@Riverpod(keepAlive: true)
int azkarVersion(Ref ref) {
  ref.watch(azkarProvider);
  return ref.read(azkarProvider.notifier).version;
}

@riverpod
class GeneralAzkar extends _$GeneralAzkar {
  TasbihDao? _dao;

  @override
  Future<List<GeneralZikr>> build() async {
    _dao = ref.read(tasbihDaoProvider);
    final all = await _dao!.getAllDomain();
    return all.map(_toGeneral).toList();
  }

  List<GeneralZikr> get allAzkar => state.value ?? [];

  Future<void> addZikr(String arabicText, {int targetCount = 100}) async {
    final now = DateTime.now();
    final model = tm.TasbihModel(
      id: now.millisecondsSinceEpoch.toString(),
      name: arabicText,
      targetDhikr: arabicText,
      targetCount: targetCount,
      createdAt: now,
    );
    await _dao!.saveDomain(model);
    final zikr = _toGeneral(model);
    state = AsyncValue.data([...allAzkar, zikr]);
  }

  Future<void> removeZikr(String id) async {
    await _dao!.deleteTasbih(id);
    state = AsyncValue.data(allAzkar.where((z) => z.id != id).toList());
  }

  Future<void> resetAll() async {
    for (final z in allAzkar) {
      await _dao!.resetCount(z.id);
    }
    state = AsyncValue.data(
        allAzkar.map((z) => z.copyWith(currentCount: 0)).toList());
  }

  Future<void> increment(String id) async {
    await _dao!.incrementLifetimeAndCount(id);
    state = AsyncValue.data(allAzkar.map((z) {
      if (z.id == id) {
        return z.copyWith(currentCount: z.currentCount + 1);
      }
      return z;
    }).toList());
  }

  Future<void> reset(String id) async {
    await _dao!.resetCount(id);
    state = AsyncValue.data(allAzkar
        .map((z) => z.id == id ? z.copyWith(currentCount: 0) : z)
        .toList());
  }

  Future<void> toggleEnabled(String id) async {
    final zikr = allAzkar.firstWhere((z) => z.id == id);
    final updated = zikr.copyWith(isEnabled: !zikr.isEnabled);
    final model = await _dao!.getTasbih(id);
    if (model != null) {
      await _dao!.upsertTasbih(model.copyWith(isEnabled: updated.isEnabled));
    }
    state =
        AsyncValue.data(allAzkar.map((z) => z.id == id ? updated : z).toList());
  }

  Future<void> updateTarget(String id, int target) async {
    await _dao!.updateTarget(id, target);
    state = AsyncValue.data(allAzkar
        .map((z) => z.id == id ? z.copyWith(targetCount: target) : z)
        .toList());
  }

  GeneralZikr _toGeneral(tm.TasbihModel m) => GeneralZikr(
        id: m.id,
        arabicText: m.name,
        targetCount: m.targetCount,
        isDefault: m.isDefault,
        isEnabled: m.isEnabled,
        currentCount: m.currentCount,
      );
}
