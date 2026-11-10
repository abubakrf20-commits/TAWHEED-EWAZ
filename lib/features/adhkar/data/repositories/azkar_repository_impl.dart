import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/features/adhkar/data/daos/azkar_status_dao.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/adhkar/utils/azkar_day_boundary.dart';

import '../../domain/entities/zikr_item.dart' as domain;
import '../../domain/repositories/azkar_repository.dart' as repo;
import 'package:tawheeed/features/adhkar/data/azkar_data.dart';

final azkarRepositoryProvider =
    FutureProvider<repo.AzkarRepository>((ref) async {
  final dao = ref.read(azkarStatusDaoProvider);
  final impl = AzkarRepositoryImpl(dao);
  await impl.init();
  return impl;
});

class AzkarRepositoryImpl implements repo.AzkarRepository {
  final AzkarStatusDao _dao;
  String _today = '';
  final Map<String, repo.ZikrStatus> _statusCache = {};
  Future<void>? _pendingLoad;

  AzkarRepositoryImpl(this._dao) {
    _refreshToday();
  }

  void _refreshToday() {
    _today = AzkarDayBoundary.dayKey(DateTime.now());
  }

  String _todayKeyNow() => AzkarDayBoundary.dayKey(DateTime.now());

  void _ensureCurrentDay() {
    final today = _todayKeyNow();
    if (_today == today) return;
    // روز عوض شده — کش را خالی و بارگذاری جدید را آغاز کن
    // اگر قبلاً در حال بارگذاری هستیم، دوباره شروع نکن
    if (_pendingLoad != null) return;
    _today = today;
    _statusCache.clear();
    _pendingLoad = _loadTodayCache().whenComplete(() => _pendingLoad = null);
  }

  @override
  Future<void> init() async {
    // Load the user's reset boundary before stamping any day key, so the
    // provider's first `_todayKey()` call already uses the right day.
    await AzkarDayBoundary.load();
    _refreshToday();
    await _loadTodayCache();
  }

  Future<void> _loadTodayCache() async {
    _statusCache.clear();
    try {
      final records = await _dao.getStatusesForDate(_today);
      for (final r in records) {
        _statusCache[r.id] = repo.ZikrStatus.values[r.statusIndex];
      }
    } catch (_) {
      // DB read failed — keep cache empty, will retry on next access
    }
  }

  /// اطمینان از اینکه کش امروز کاملاً بارگذاری شده (برای استفاده در provider)
  Future<void> ensureTodayLoaded() async {
    final today = _todayKeyNow();
    if (_today != today) {
      _today = today;
      await _loadTodayCache();
      return;
    }
    if (_pendingLoad != null) await _pendingLoad;
  }

  /// Re-reads today's statuses from the DB even when the day has not changed.
  ///
  /// [ensureTodayLoaded] deliberately trusts the cache within one day, which is
  /// right for its callers — but the evaluation's range reset deletes rows
  /// behind this cache's back, and a stale cache would resurrect the deleted
  /// completions on the next rebuild. The reset calls this to re-sync.
  Future<void> reloadTodayCache() async {
    _refreshToday();
    await _loadTodayCache();
  }

  @override
  Future<List<domain.ZikrItem>> loadAllAzkar() async {
    await AzkarData.ensureLoaded();
    return AzkarData.allAzkar;
  }

  @override
  List<domain.ZikrItem> getByPeriod(domain.PrayerPeriod period) {
    return AzkarData.getByPeriod(period);
  }

  @override
  repo.ZikrStatus getStatus(String id) {
    _ensureCurrentDay();
    return _statusCache[id] ?? repo.ZikrStatus.pending;
  }

  @override
  Future<void> setStatus(String id, repo.ZikrStatus status) async {
    // قبل از نوشتن، مطمئن شو روز درست است
    final today = _todayKeyNow();
    if (_today != today) {
      _today = today;
      await _loadTodayCache();
    }
    _statusCache[id] = status;
    await _dao.setStatus(ZikrStatusRecordTableData(
      id: id,
      statusIndex: status.index,
      date: _today,
    ));
  }

  @override
  Future<void> setStatusBatch(List<String> ids, repo.ZikrStatus status) async {
    if (ids.isEmpty) return;
    final today = _todayKeyNow();
    if (_today != today) {
      _today = today;
      await _loadTodayCache();
    }
    final records = <ZikrStatusRecordTableData>[];
    for (final id in ids) {
      _statusCache[id] = status;
      records.add(ZikrStatusRecordTableData(
        id: id,
        statusIndex: status.index,
        date: _today,
      ));
    }
    await _dao.setStatusesBatch(records);
  }

  @override
  Map<String, int> periodStats(domain.PrayerPeriod period) {
    _ensureCurrentDay();
    final items = AzkarData.getByPeriod(period);
    int done = 0, skipped = 0;
    for (final z in items) {
      final s = _statusCache[z.id] ?? repo.ZikrStatus.pending;
      if (s == repo.ZikrStatus.done) done++;
      if (s == repo.ZikrStatus.skipped) skipped++;
    }
    return {'total': items.length, 'done': done, 'skipped': skipped};
  }

  @override
  Map<String, int> get todayStats {
    _ensureCurrentDay();
    int total = 0, done = 0, skipped = 0;
    for (final period in domain.PrayerPeriod.values) {
      final s = periodStats(period);
      total += s['total'] ?? 0;
      done += s['done'] ?? 0;
      skipped += s['skipped'] ?? 0;
    }
    return {'total': total, 'done': done, 'skipped': skipped};
  }

  @override
  Future<void> resetDay() async {
    _refreshToday();
    await _loadTodayCache();
  }
}
