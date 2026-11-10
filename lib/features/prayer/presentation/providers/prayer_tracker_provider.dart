import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/prayer/data/daos/prayer_tracker_dao.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/date_range.dart';
import 'package:tawheeed/features/prayer/domain/entities/prayer_tracker_entities.dart';
import 'package:tawheeed/shared/utils/date_key.dart';

export 'package:tawheeed/features/prayer/domain/entities/prayer_tracker_entities.dart';

part 'prayer_tracker_provider.g.dart';

class PrayerTrackerState {
  final int version;
  final Map<FardhPrayer, PrayerStatus> fardStatuses;
  final Map<SunnahPrayer, bool> sunnahStatuses;
  final bool duhaStatus;

  const PrayerTrackerState({
    this.version = 0,
    this.fardStatuses = const {},
    this.sunnahStatuses = const {},
    this.duhaStatus = false,
  });
}

@riverpod
class PrayerTracker extends _$PrayerTracker {
  PrayerTrackerDao? _dao;
  String _today = '';
  Timer? _midnightTimer;
  int _version = 0;

  // In-memory caches — updated synchronously on toggles, read by _currentState().
  final Map<FardhPrayer, PrayerStatus> _fardCache = {};
  final Map<SunnahPrayer, bool> _sunnahCache = {};
  bool _duhaCache = false;

  // Full in-memory cache of all prayer records keyed by "pt_{date}_{prayerKey}".
  // Loaded once on build from Drift, updated synchronously on every write.
  Map<String, int> _prayerCache = {};

  // The taps below are synchronous by design (widget callbacks), and the UI
  // stays tappable while `build()` is still awaiting the DB. A tap made in
  // that window used to be overwritten by the older snapshot the load then
  // assigned. These are replayed over the snapshot instead.
  bool _loaded = false;
  final Map<String, int> _writesDuringLoad = {};

  @override
  Future<PrayerTrackerState> build() async {
    _dao = ref.read(prayerTrackerDaoProvider);
    _loaded = false;
    _writesDuringLoad.clear();
    _refreshToday();
    await _loadAllData();
    _scheduleMidnightRefresh();
    ref.onDispose(() => _midnightTimer?.cancel());
    return _currentState();
  }

  /// Load all prayer records from Drift into the in-memory cache and populate
  /// today's fast-access caches.
  Future<void> _loadAllData() async {
    final snapshot = await _dao!.getAllAsMap();
    if (!ref.mounted) return;
    _prayerCache = {...snapshot, ..._writesDuringLoad};
    _writesDuringLoad.clear();
    _loaded = true;
    _buildCachesFromCache();
  }

  /// Populate today's fast-access caches from the global [_prayerCache].
  void _buildCachesFromCache() {
    for (final prayer in FardhPrayer.values) {
      final raw = _prayerCache['pt_${_today}_${prayer.name}'];
      _fardCache[prayer] =
          raw != null ? PrayerStatus.values[raw] : PrayerStatus.pending;
    }
    for (final prayer in SunnahPrayer.values) {
      _sunnahCache[prayer] =
          (_prayerCache['pt_${_today}_sunnah_${prayer.name}'] ?? 0) == 1;
    }
    _duhaCache = (_prayerCache['pt_${_today}_duha'] ?? 0) == 1;
  }

  PrayerTrackerState _currentState() => PrayerTrackerState(
        version: _version,
        fardStatuses: Map.unmodifiable(_fardCache),
        sunnahStatuses: Map.unmodifiable(_sunnahCache),
        duhaStatus: _duhaCache,
      );

  void _notify() {
    _version++;
    state = AsyncValue.data(_currentState());
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    // Fire at the *actual* next midnight (not "24h from now"), so the day
    // caches roll over as soon as the date changes even when the app stays in
    // the foreground across midnight.
    final now = DateTime.now();
    final midnight = now.addCalendarDaysFromMidnight(1);
    final duration = midnight.difference(now);
    _midnightTimer = Timer(duration, () {
      if (_refreshToday()) _notify();
      _scheduleMidnightRefresh();
    });
  }

  /// Update [_today] to the current date. When the date actually rolls over,
  /// the daily fast-access caches are rebuilt immediately from [_prayerCache]
  /// so stale "yesterday" statuses can never be read for the new day. Returns
  /// true when the day changed (callers may notify listeners).
  bool _refreshToday() {
    final now = DateTime.now();
    final newToday = dateKeyOf(now);
    if (newToday == _today) return false;
    _today = newToday;
    _buildCachesFromCache();
    return true;
  }

  // ── Public getters (read from in-memory cache — fast) ──

  PrayerStatus getStatus(FardhPrayer prayer) {
    if (_refreshToday()) _notify();
    return _fardCache[prayer] ?? PrayerStatus.pending;
  }

  /// The five fard statuses of an arbitrary [date], read from the in-memory
  /// copy of every row.
  ///
  /// The calendar marks past days with this, so it must not be a DB query per
  /// selection — the whole table is already loaded by `build()`. A date with no
  /// rows reads as [PrayerStatus.pending] for all five, which is the truth:
  /// nothing was recorded.
  ///
  /// The cache is only populated after the first load, so callers gate on the
  /// provider actually having a value (`AsyncValue.hasValue`); otherwise
  /// «not loaded yet» would print as «not prayed», which is a claim about the
  /// user's worship made from a missing read.
  Map<FardhPrayer, PrayerStatus> statusesForDate(DateTime date) {
    final day = dateKeyOf(date);
    final out = <FardhPrayer, PrayerStatus>{};
    for (final prayer in FardhPrayer.values) {
      final raw = _prayerCache['pt_${day}_${prayer.name}'];
      out[prayer] = raw != null && raw >= 0 && raw < PrayerStatus.values.length
          ? PrayerStatus.values[raw]
          : PrayerStatus.pending;
    }
    return out;
  }

  void setStatus(FardhPrayer prayer, PrayerStatus status) {
    _fardCache[prayer] = status;
    final key = 'pt_${_today}_${prayer.name}';
    _prayerCache[key] = status.index;
    if (!_loaded) _writesDuringLoad[key] = status.index;
    _dao?.upsert(PrayerTrackerTableData(
      date: _today,
      prayerKey: prayer.name,
      value: status.index,
    ));
    _notify();
  }

  String _sunnahKey(SunnahPrayer prayer) =>
      'pt_${_today}_sunnah_${prayer.name}';
  void toggleSunnah(SunnahPrayer prayer) {
    try {
      final current = _sunnahCache[prayer] ?? false;
      final newValue = !current;
      _sunnahCache[prayer] = newValue;
      final key = _sunnahKey(prayer);
      _prayerCache[key] = newValue ? 1 : 0;
      if (!_loaded) _writesDuringLoad[key] = newValue ? 1 : 0;
      _dao?.upsert(PrayerTrackerTableData(
        date: _today,
        prayerKey: 'sunnah_${prayer.name}',
        value: newValue ? 1 : 0,
      ));
      _notify();
    } catch (e) {
      AppLogger.error('PrayerTrackerNotifier.toggleSunnah', e);
    }
  }

  void toggleStatus(FardhPrayer prayer) {
    final current = getStatus(prayer);
    // NOTE: PrayerStatus.missed is reserved (never assigned by any writer —
    // the enum slot exists for DB-index compatibility). The cycle therefore
    // only rotates through the three settable states. A row whose window has
    // closed is shown as past-due by the reader-side derivation in
    // features/prayer/domain/prayer_windows.dart, which stays unwritten so a
    // late tick can still correct it.
    final next = switch (current) {
      PrayerStatus.pending => PrayerStatus.done,
      PrayerStatus.done => PrayerStatus.qada,
      PrayerStatus.qada => PrayerStatus.pending,
      PrayerStatus.missed => PrayerStatus.pending,
    };
    setStatus(prayer, next);
  }

  void toggleDuha() {
    final current = _duhaCache;
    final newValue = !current;
    _duhaCache = newValue;
    _prayerCache['pt_${_today}_duha'] = newValue ? 1 : 0;
    if (!_loaded) _writesDuringLoad['pt_${_today}_duha'] = newValue ? 1 : 0;
    _dao?.upsert(PrayerTrackerTableData(
      date: _today,
      prayerKey: 'duha',
      value: newValue ? 1 : 0,
    ));
    _notify();
  }

  Map<String, int> get cachedPrayerData => _prayerCache;

  ({int fardh, int sunnah, int duha}) countPrayersInRange(
      String startDateKey, String endDateKey) {
    int fardh = 0, sunnah = 0, duha = 0;
    for (final entry in _prayerCache.entries) {
      final key = entry.key;
      if (key.length < 13) continue;
      final datePart = key.substring(3, 13);
      if (datePart.compareTo(startDateKey) >= 0 &&
          datePart.compareTo(endDateKey) <= 0) {
        if (key.contains('sunnah')) {
          if (entry.value == 1) sunnah++;
        } else if (key.contains('duha')) {
          if (entry.value == 1) duha++;
        } else if (!key.contains('period') && !key.contains('cycle')) {
          final status = PrayerStatus.values[entry.value];
          if (status == PrayerStatus.done || status == PrayerStatus.qada) {
            fardh++;
          }
        }
      }
    }
    return (fardh: fardh, sunnah: sunnah, duha: duha);
  }

  /// Consecutive days with all 5 fardh prayed on time. Qada days do NOT
  /// extend the streak (a made-up prayer is counted in scores/history, but a
  /// "streak" means on-time days). Currently exercised by tests; the
  /// evaluation tab tracks its own score-based streaks.
  ({int current, int longest}) computeStreaks() {
    int streak = 0, longest = 0, currentRun = 0;
    final now = DateTime.now();
    for (int daysAgo = 0; daysAgo < 365; daysAgo++) {
      final date = DateTime(now.year, now.month, now.day - daysAgo);
      final dk = dateKeyOf(date);
      int done = 0;
      for (final prayer in FardhPrayer.values) {
        final raw = _prayerCache['pt_${dk}_${prayer.name}'];
        if (raw != null) {
          final s = PrayerStatus.values[raw];
          if (s == PrayerStatus.done) done++;
        }
      }
      if (done == 5) {
        streak++;
        currentRun++;
        if (currentRun > longest) longest = currentRun;
      } else {
        currentRun = 0;
        if (daysAgo > 0) break;
      }
    }
    return (current: streak, longest: longest);
  }
}
