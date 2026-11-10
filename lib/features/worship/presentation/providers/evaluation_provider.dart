import 'dart:async';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/features/worship/data/daos/daily_status_dao.dart';
import 'package:tawheeed/features/adhkar/data/daos/azkar_status_dao.dart';
import 'package:tawheeed/features/adhkar/tasbih/presentation/providers/tasbih_provider.dart';
import 'package:tawheeed/features/adhkar/domain/entities/zikr_item.dart';
import 'package:tawheeed/features/adhkar/presentation/providers/azkar_provider.dart';
import 'package:tawheeed/features/worship/data/evaluation_data_loader.dart';
import 'package:tawheeed/features/worship/data/evaluation_reset_backup.dart';
import 'package:tawheeed/features/worship/domain/evaluation_stats_compute.dart';
import 'package:tawheeed/features/worship/presentation/providers/evaluation_report.dart'
    as report;
import 'package:tawheeed/features/prayer/data/daos/prayer_tracker_dao.dart';
import 'package:tawheeed/features/prayer/presentation/providers/prayer_tracker_provider.dart';
import 'package:tawheeed/features/prayer/presentation/providers/period_provider.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_provider.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/date_key.dart';
import 'package:tawheeed/features/home/services/widget_sync_provider.dart';

part 'evaluation_provider.g.dart';

class WorshipItem {
  final String id;
  final String label;
  final IconData icon;
  final int points;
  final bool done;

  const WorshipItem(
      {required this.id,
      required this.label,
      required this.icon,
      this.done = false,
      this.points = 10});

  WorshipItem copyWith({bool? done}) {
    return WorshipItem(
        id: id,
        label: label,
        icon: icon,
        points: points,
        done: done ?? this.done);
  }
}

class EvaluationState {
  final List<WorshipItem> worshipItems;
  final int dailyScore;
  final int monthlyScore;
  final int weeklyScore;
  final int currentStreak;
  final int bestStreak;
  final int totalCompleted;
  final int totalSkipped;
  final int todayCompleted;
  final int weeklyCompleted;
  final int monthlyAzkarCompleted;
  final int totalLifetimeTasbih;
  final int totalDailyTasbih;

  /// Per-zikr tap counts for today (date-keyed `tasbih_daily_<id>` rows).
  final Map<String, int> tasbihTodayPerZikr;

  EvaluationState({
    this.worshipItems = const [],
    this.dailyScore = 0,
    this.monthlyScore = 0,
    this.weeklyScore = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.totalCompleted = 0,
    this.totalSkipped = 0,
    this.todayCompleted = 0,
    this.weeklyCompleted = 0,
    this.monthlyAzkarCompleted = 0,
    this.totalLifetimeTasbih = 0,
    this.totalDailyTasbih = 0,
    this.tasbihTodayPerZikr = const {},
  });

  EvaluationState copyWith({
    List<WorshipItem>? worshipItems,
    int? dailyScore,
    int? monthlyScore,
    int? weeklyScore,
    int? currentStreak,
    int? bestStreak,
    int? totalCompleted,
    int? totalSkipped,
    int? todayCompleted,
    int? weeklyCompleted,
    int? monthlyAzkarCompleted,
    int? totalLifetimeTasbih,
    int? totalDailyTasbih,
    Map<String, int>? tasbihTodayPerZikr,
  }) {
    return EvaluationState(
      worshipItems: worshipItems ?? this.worshipItems,
      dailyScore: dailyScore ?? this.dailyScore,
      monthlyScore: monthlyScore ?? this.monthlyScore,
      weeklyScore: weeklyScore ?? this.weeklyScore,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      totalCompleted: totalCompleted ?? this.totalCompleted,
      totalSkipped: totalSkipped ?? this.totalSkipped,
      todayCompleted: todayCompleted ?? this.todayCompleted,
      weeklyCompleted: weeklyCompleted ?? this.weeklyCompleted,
      monthlyAzkarCompleted:
          monthlyAzkarCompleted ?? this.monthlyAzkarCompleted,
      totalLifetimeTasbih: totalLifetimeTasbih ?? this.totalLifetimeTasbih,
      totalDailyTasbih: totalDailyTasbih ?? this.totalDailyTasbih,
      tasbihTodayPerZikr: tasbihTodayPerZikr ?? this.tasbihTodayPerZikr,
    );
  }
}

@riverpod
class Evaluation extends _$Evaluation {
  DailyStatusDao? _dailyDao;

  /// Maximum points a single طاعات checklist item can earn per day. Kept
  /// deliberately low so the worship checklist stays a habit tracker rather
  /// than a point grind. The global worshipMultiplier may lower this further
  /// but never raises it.
  static const int maxWorshipItemPoints = 5;

  static const _defaultWorship = [
    ('quran', 'قرائت قرآن', Icons.menu_book, 5),
    ('sadaqa', 'صدقه', Icons.favorite, 5),
    ('tahajjud', 'نماز شب', Icons.nightlight, 5),
    ('fasting', 'روزه (سنت)', Icons.restaurant, 5),
    ('good_deeds', 'بر والدین و صله رحم و ...', Icons.people, 5),
    // The step-by-step checklists in نماز and وضو و طهارت register these ids
    // through `toggleWorship`; an id missing here made that sync a silent
    // no-op (the card skips unknown ids). They are ordinary checklist items
    // and can be ticked by hand like the rest.
    ('prayer', 'نماز', Icons.mosque, 5),
    ('wudu', 'وضو', Icons.clean_hands, 5),
    ('ghusl', 'غسل', Icons.shower, 5),
    ('tayammum', 'تیمم', Icons.back_hand, 5),
  ];
  static const Map<String, IconData> iconMap = {
    'star': Icons.star,
    'favorite': Icons.favorite,
    'menu_book': Icons.menu_book,
    'nightlight': Icons.nightlight,
    'restaurant': Icons.restaurant,
    'wb_sunny': Icons.wb_sunny,
    'people': Icons.people,
    'mosque': Icons.mosque,
    'done_outline': Icons.done_outline,
    'volunteer_activism': Icons.volunteer_activism,
    'self_improvement': Icons.self_improvement,
    'broken_image': Icons.broken_image,
    'spa': Icons.spa,
    'clean_hands': Icons.clean_hands,
    'shower': Icons.shower,
    'back_hand': Icons.back_hand,
  };

  Map<String, int> _scoreCache = {};

  Map<String, Map<String, int>> _worshipCache = {};

  Map<String, int> _tasbihDailyCache = {};

  // ── Frozen history scores ─────────────────────────────────────────────
  // Past dates must never be recomputed with *current* point settings:
  // changing points in Settings would otherwise rewrite history. The frozen
  // combined total per date lives in daily_status under [_frozenCategory]
  // (no schema migration needed — same key-value table). [_frozenSchemaOk]
  // guards against future formula changes: if the code schema differs from
  // the stamped one, frozen rows are ignored and re-frozen with the new
  // formula. Editing a past day explicitly re-scores it with current points
  // and freezes the new value.
  //
  // Aliased to the loader's public names rather than repeated: the two files
  // wrote the same two strings independently, and a typo in one of them would
  // have made the loader read a category nobody writes.
  static const String _frozenCategory = frozenScoreCategory;
  static const String _frozenMetaCategory = frozenMetaCategory;
  static const int _frozenSchemaVersion = frozenSchemaVersion;
  Map<String, int> _frozenScores = {};
  bool _frozenSchemaOk = false;

  /// The `daily_status` categories a range reset clears, scoped to the reset's
  /// dates: `worship` holds the checklist ticks (which the calendar's fasting
  /// toggle and the prayer/wudu step checklists also write, through this
  /// provider), `worship_score` and the frozen scores are derived from them,
  /// and `tasbih_daily` is the daily tap total the tasbih taps record for the
  /// evaluation to read. The per-zikr `tasbih_daily_<id>` rows are covered by
  /// the prefix delete next to this.
  ///
  /// Deliberately NOT here: [frozenMetaCategory] (the schema stamp is global,
  /// not per-date) and [evalResetCategory] (the cutoff markers of earlier
  /// resets — dropping them would let dates before an old reset score again).
  static const List<String> rangeResetCategories = [
    'worship',
    'worship_score',
    frozenScoreCategory,
    'tasbih_daily',
  ];

  /// Latest reset cutoff, or null when the reader never reset.
  String? _resetAt;

  // Hayz (period) date keys: on these days prayers & fasting auto-count.
  Set<String> _periodDateKeys = {};

  // Points awarded for completed prayers (فرض / رواتب و وتر / ضحی), added on
  // top of the worship-checklist score so the امتیاز reflects prayers too.
  // Values are user-configurable via Settings (امتیازدهی عبادات).
  int _fardhPoint = 10;
  int _sunnahPoint = 5;
  int _duhaPoint = 5;
  int _adhkarPoint = 10;
  int _tasbihPoint = 10;
  double _worshipMultiplier = 1.0;
  Set<String> _excludedWorship = {};

  int _prayerPointsForDate(String dateKey, [Map<String, int>? prayerCache]) {
    // Registration is manual even during hayz — no automatic prayer points.
    // A period day only earns points if the user explicitly records worship
    // or prayer completion for that date.
    // [prayerCache], when provided, avoids touching `ref` after async gaps
    // inside build() (a superseded build must never use a disposed ref).
    final cache = prayerCache ??
        ref.read(prayerTrackerProvider.notifier).cachedPrayerData;
    int points = 0;
    for (final p in FardhPrayer.values) {
      final raw = cache['pt_${dateKey}_${p.name}'];
      if (raw != null) {
        final s = PrayerStatus.values[raw];
        if (s == PrayerStatus.done || s == PrayerStatus.qada) {
          points += _fardhPoint;
        }
      }
    }
    for (final p in SunnahPrayer.values) {
      if ((cache['pt_${dateKey}_sunnah_${p.name}'] ?? 0) == 1) {
        points += _sunnahPoint;
      }
    }
    if ((cache['pt_${dateKey}_duha'] ?? 0) == 1) {
      points += _duhaPoint;
    }
    return points;
  }

  int _combinedScore(String dateKey, int worshipScore,
          [Map<String, int>? prayerCache]) =>
      worshipScore +
      _prayerPointsForDate(dateKey, prayerCache) +
      _adhkarPointsForDate(dateKey) +
      _tasbihPointsForDate(dateKey);

  /// Frozen total for [dateKey] when it is a past date with a valid frozen
  /// row, otherwise the live combined score (today is always live).
  int _frozenOrLiveScore(String dateKey, int worshipScore, String today,
      [Map<String, int>? prayerCache]) {
    final frozen = _frozenScores[dateKey];
    if (dateKey != today && _frozenSchemaOk && frozen != null) {
      return frozen;
    }
    return _combinedScore(dateKey, worshipScore, prayerCache);
  }

  /// Persists the frozen total for every legacy past date that has none yet,
  /// so pre-existing history is sealed exactly once and never rewritten by
  /// later point-setting changes.
  Future<void> _backfillFrozenScores(String today) async {
    final pending = <Future<void>>[];
    for (final e in _scoreCache.entries) {
      if (e.key == today) continue;
      if (_frozenSchemaOk && _frozenScores.containsKey(e.key)) continue;
      _frozenScores[e.key] = e.value;
      pending.add(_dailyDao!.set(_frozenCategory, e.key, 'total', e.value));
    }
    if (pending.isNotEmpty) {
      pending.add(_dailyDao!
          .set(_frozenMetaCategory, '', 'frozen_schema', _frozenSchemaVersion));
      await Future.wait(pending);
    }
    _frozenSchemaOk = true;
  }

  int _adhkarPointsForDate(String dateKey) {
    // Check if morning or evening adhkar is fully completed for this date.
    // We check the azkar completion cache (loaded earlier in build).
    final morningDone = _isAzkarPeriodDone(dateKey, 'morningAzkar');
    final eveningDone = _isAzkarPeriodDone(dateKey, 'eveningAzkar');
    return (morningDone ? _adhkarPoint : 0) + (eveningDone ? _adhkarPoint : 0);
  }

  int _tasbihPointsForDate(String dateKey) {
    // Award points if any tasbih was done today (daily count > 0).
    final count = _tasbihDailyCache[dateKey] ?? 0;
    return count > 0 ? _tasbihPoint : 0;
  }

  bool _isAzkarPeriodDone(String dateKey, String periodName) {
    // This will be populated during build() after azkar data is loaded.
    return _azkarPeriodDoneCache['$dateKey:$periodName'] ?? false;
  }

  final Map<String, bool> _azkarPeriodDoneCache = {};

  /// Re-reads today's azkar morning/evening completion from the azkar
  /// provider into the cache. The single owner of this copy (Audit 2.6-3) —
  /// every mutation path calls this instead of duplicating the block.
  void refreshTodayAzkarPeriods(Ref ref) {
    // Only today's two keys are written. Rebuilding the whole map here used to
    // discard the past-date periods loaded from history, so any later edit of
    // a past day re-froze that date with zero adhkar points.
    final azkarNotifier = ref.read(azkarProvider.notifier);
    final morningStats = azkarNotifier.periodStats(PrayerPeriod.morningAzkar);
    final eveningStats = azkarNotifier.periodStats(PrayerPeriod.eveningAzkar);
    final todayMorningDone = (morningStats['total'] ?? 0) > 0 &&
        morningStats['done'] == morningStats['total'];
    final todayEveningDone = (eveningStats['total'] ?? 0) > 0 &&
        eveningStats['done'] == eveningStats['total'];
    final todayKey = DateTime.now().toString().substring(0, 10);
    _azkarPeriodDoneCache['$todayKey:morningAzkar'] = todayMorningDone;
    _azkarPeriodDoneCache['$todayKey:eveningAzkar'] = todayEveningDone;
  }

  /// Maximum daily points from prayers: 5 fardh × 10 + 6 sunnah × 5 + duha 5.
  int get prayerDailyMax =>
      FardhPrayer.values.length * _fardhPoint +
      SunnahPrayer.values.length * _sunnahPoint +
      _duhaPoint;

  int get adhkarDailyMax => _adhkarPoint * 2; // morning + evening
  int get tasbihDailyMax => _tasbihPoint;

  List<Map<String, dynamic>> _customWorshipItemsCache = [];

  /// E01 (unit 5 audit): the evaluation tab lives inside an IndexedStack, so
  /// this provider is never disposed and «امروز» would keep pointing at
  /// yesterday after midnight. One timer per build invalidates the provider
  /// exactly when the calendar day rolls over.
  Timer? _midnightTimer;

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final midnight =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    _midnightTimer = Timer(midnight.difference(now), () {
      if (ref.mounted) ref.invalidateSelf();
    });
  }

  @override
  Future<EvaluationState> build() async {
    ref.onDispose(() => _midnightTimer?.cancel());
    _scheduleMidnightRefresh();
    ref.watch(azkarVersionProvider);
    ref.watch(tasbihProvider);
    // Wait for the prayer tracker to finish loading BEFORE computing prayer
    // points. Watching it directly would invalidate this provider mid-build
    // when the tracker transitions loading -> data (Riverpod 3 throws
    // «disposed during loading state» in that case). The explicit await makes
    // the first build wait for data, so the watch below never fires mid-build.
    await ref.watch(prayerTrackerProvider.future);
    ref.watch(prayerTrackerProvider);
    // User-configurable worship points (Settings → امتیازدهی عبادات).
    final settings = await ref.watch(settingsProvider.future);
    ref.watch(settingsProvider);
    _fardhPoint = settings.fardhPoint;
    _sunnahPoint = settings.sunnahPoint;
    _duhaPoint = settings.duhaPoint;
    _adhkarPoint = settings.adhkarPoint;
    _tasbihPoint = settings.tasbihPoint;
    _worshipMultiplier = settings.worshipMultiplier;
    _excludedWorship = settings.excludedWorship.toSet();
    _hiddenDefaults = settings.hiddenWorshipItems.toSet();
    // Load period (hayz) records for isPeriodDay checks and statistics.
    // Registration stays manual — a period day only counts if the user
    // explicitly toggles worship/prayer for that date (no auto scoring).
    final periodState = await ref.watch(periodProvider.future);
    ref.watch(periodProvider);
    _periodDateKeys = _collectPeriodDateKeys(
        periodState.records, periodState.defaultPeriodLength);
    // Snapshot the prayer cache BEFORE the loader's awaits below: build()
    // must never touch `ref` after an async gap — a rebuild supersedes this
    // build and disposes its ref. Everything downstream receives this
    // snapshot as a parameter instead.
    final ptCache = ref.read(prayerTrackerProvider.notifier).cachedPrayerData;
    _dailyDao = ref.read(dailyStatusDaoProvider);
    // SINGLE SOURCE (Audit 2.6-3): today's azkar period completion is read
    // through one shared helper instead of six copy-pasted blocks that each
    // cleared + refilled the cache from azkarProvider.periodStats().
    refreshTodayAzkarPeriods(ref);

    final today = dateKeyOf(DateTime.now());
    final now = DateTime.now();
    final weekStart = dateKeyOf(now.subtract(const Duration(days: 6)));
    final monthStart = dateKeyOf(DateTime(now.year, now.month));

    _customWorshipItemsCache =
        List<Map<String, dynamic>>.from(settings.customWorshipItems);

    // Extracted data loading (Audit 8.17): the parallel 9-query batch, the
    // frozen-score reads and the past-date azkar derivation live in
    // evaluation_data_loader.dart — this provider only wires the results in.
    final data = await loadEvaluationData(
      ref: ref,
      today: today,
      weekStart: weekStart,
      monthStart: monthStart,
    );
    _frozenScores = data.frozenScores;
    _frozenSchemaOk = data.frozenSchemaOk;
    _resetAt = data.resetAt;
    _azkarPeriodDoneCache.addAll(data.pastAzkarPeriods);
    _worshipCache = data.worshipMap;
    _tasbihDailyCache = data.tasbihDaily;

    // Each persisted worship score gets today's/past prayer points added on
    // top so weekly/monthly totals reflect prayers too. Past dates use the
    // frozen total when available — never recomputed with current points.
    _scoreCache = {
      for (final e in data.scoreMap.entries)
        e.key: _frozenOrLiveScore(e.key, e.value, today, ptCache),
    };
    // Days where the user only prayed (no worship-checklist toggle) never get a
    // `worship_score` row, so their prayer points would be lost from the
    // weekly/monthly/heatmap totals. Seed the cache for every prayer day too.
    for (final key in ptCache.keys) {
      if (!key.startsWith('pt_') || key.length < 13) continue;
      final dk = key.substring(3, 13);
      if (!_scoreCache.containsKey(dk)) {
        final pts = _frozenOrLiveScore(dk, 0, today, ptCache);
        if (pts > 0) _scoreCache[dk] = pts;
      }
    }
    // A reset's cutoff drops everything before the day it was pressed —
    // including the prayer-only days just seeded above. Applied after the
    // seeding pass and *before* the backfill, so the backfill cannot re-freeze a
    // date the reader asked to forget.
    final resetAt = _resetAt;
    if (resetAt != null) {
      _scoreCache.removeWhere((key, _) => key.compareTo(resetAt) < 0);
    }
    // One-time backfill: freeze every legacy past date so history can never
    // be rewritten by future point-setting changes.
    await _backfillFrozenScores(today);
    final worshipItems = _loadWorship(today);
    // Excluded items must not score, exactly like every toggle path (503-540):
    // omitting the filter here let an excluded-but-done طاعت inflate today's
    // امتیاز until the user happened to toggle again.
    final worshipScore = worshipItems
        .where((w) => w.done && !_excludedWorship.contains(w.id))
        .fold(0, (s, w) => s + w.points);
    final dailyScore = _combinedScore(today, worshipScore, ptCache);
    _scoreCache[today] = dailyScore;

    final todayCompleted = data.weekRecords
        .where((r) => r.date == today && r.statusIndex == 1)
        .length;
    final weeklyCompleted =
        data.weekRecords.where((r) => r.statusIndex == 1).length;
    final monthlyAzkarCompleted =
        data.monthRecords.where((r) => r.statusIndex == 1).length;

    int totalLifetimeTasbih = 0;
    for (final t in data.allTasbih) {
      totalLifetimeTasbih += t.totalLifetimeCount;
    }
    // (allTasbih snapshot comes from the extracted loader above)

    // Per-zikr counts for TODAY (from `tasbih_daily_<id>` rows) so the daily
    // evaluation's «جزئیات تسبیح» always reflects today's taps — the session
    // counter resets at the configured time, the daily row is date-keyed.
    // Single batched query instead of one getValue per zikr (N+1).
    final tasbihTodayPerZikr = await _dailyDao!.getTasbihDailyForDate(today);
    for (final t in data.allTasbih) {
      tasbihTodayPerZikr.putIfAbsent(t.id, () => 0);
    }

    return EvaluationState(
      worshipItems: worshipItems,
      dailyScore: dailyScore,
      monthlyScore: _monthlyScoreCached(),
      weeklyScore: _weeklyScoreCached(),
      currentStreak: _currentStreakCached(),
      bestStreak: _bestStreakCached(),
      totalCompleted: data.totalDone,
      totalSkipped: data.totalSkipped,
      todayCompleted: todayCompleted,
      weeklyCompleted: weeklyCompleted,
      monthlyAzkarCompleted: monthlyAzkarCompleted,
      totalLifetimeTasbih: totalLifetimeTasbih,
      totalDailyTasbih: _tasbihDailyCache[today] ?? 0,
      tasbihTodayPerZikr: tasbihTodayPerZikr,
    );
  }

  // ── Tasbih daily counters (Drift via DailyStatusDao) ──

  int tasbihCountForToday() =>
      _tasbihDailyCache[dateKeyOf(DateTime.now())] ?? 0;

  int tasbihCountForDay(DateTime d) =>
      EvaluationStatsCompute.tasbihCountForDay(_tasbihDailyCache, d);

  int tasbihCountForLast7Days() =>
      EvaluationStatsCompute.tasbihCountForLast7Days(
          _tasbihDailyCache, DateTime.now());

  int tasbihCountForMonth(int year, int month) =>
      EvaluationStatsCompute.tasbihCountForMonth(
          _tasbihDailyCache, year, month);

  List<WorshipItem> _loadWorship(String today) {
    _loadHiddenDefaults();
    final saved = _worshipCache[today] ?? {};
    final customList = _customWorshipItemsCache;
    final items =
        _defaultWorship.where((w) => !_hiddenDefaults.contains(w.$1)).map((w) {
      final (id, label, icon, points) = w;
      return WorshipItem(
          id: id,
          label: label,
          icon: icon,
          points: _worshipItemPoints(points),
          done: saved[id] == 1);
    }).toList();
    for (final c in customList) {
      items.add(WorshipItem(
        id: c['id'] as String,
        label: c['label'] as String,
        icon: iconMap[c['iconName'] as String?] ?? Icons.star,
        points: _worshipItemPoints(
            int.tryParse(c['points']?.toString() ?? '') ??
                maxWorshipItemPoints),
        done: saved[c['id']] == 1,
      ));
    }
    return items;
  }

  /// Scales a raw طاعات item value by [worshipMultiplier], capping the result
  /// at [maxWorshipItemPoints] per item (see that constant's doc comment).
  int _worshipItemPoints(int rawPoints) {
    final p = (rawPoints * _worshipMultiplier).round();
    if (p > maxWorshipItemPoints) return maxWorshipItemPoints;
    if (p < 1) return 1;
    return p;
  }

  void toggleWorship(String id) {
    final cur = state.requireValue;
    final items = cur.worshipItems.map((w) {
      if (w.id == id) return w.copyWith(done: !w.done);
      return w;
    }).toList();
    final worshipScore = items
        .where((w) => w.done && !_excludedWorship.contains(w.id))
        .fold(0, (s, w) => s + w.points);
    // SINGLE SOURCE (Audit 2.6-3): today's azkar period completion is read
    // through one shared helper instead of six copy-pasted blocks that each
    // cleared + refilled the cache from azkarProvider.periodStats().
    refreshTodayAzkarPeriods(ref);

    final today = dateKeyOf(DateTime.now());
    final merged = {..._worshipCache[today] ?? {}};
    for (final item in items) {
      merged[item.id] = item.done ? 1 : 0;
    }
    _worshipCache[today] = merged;
    final dailyScore = _combinedScore(today, worshipScore);
    _scoreCache[today] = dailyScore;
    state = AsyncData(_withFreshAggregates(
        cur.copyWith(worshipItems: items, dailyScore: dailyScore)));
    _dailyDao?.set(
        'worship', today, id, items.firstWhere((w) => w.id == id).done ? 1 : 0);
    _dailyDao?.set('worship_score', today, '', worshipScore);
  }

  void toggleExcludeWorship(String id) {
    final cur = state.requireValue;
    if (_excludedWorship.contains(id)) {
      _excludedWorship.remove(id);
    } else {
      _excludedWorship.add(id);
    }
    ref
        .read(settingsProvider.notifier)
        .patch((s) => s.copyWith(excludedWorship: _excludedWorship.toList()));
    // Recalculate today's score.
    final items = cur.worshipItems;
    final worshipScore = items
        .where((w) => w.done && !_excludedWorship.contains(w.id))
        .fold(0, (s, w) => s + w.points);
    final today = dateKeyOf(DateTime.now());
    final dailyScore = _combinedScore(today, worshipScore);
    _scoreCache[today] = dailyScore;
    state =
        AsyncData(_withFreshAggregates(cur.copyWith(dailyScore: dailyScore)));
  }

  bool isWorshipExcluded(String id) => _excludedWorship.contains(id);

  int? getScoreForDate(DateTime date) {
    final key = dateKeyOf(date);
    return _scoreCache[key];
  }

  /// Re-derives the aggregate counters (streaks, weekly/monthly scores) from
  /// the in-memory [_scoreCache] for an optimistically-emitted state.
  /// Without this, toggles update `dailyScore` but leave `currentStreak` etc.
  /// stale until some unrelated rebuild happens.
  EvaluationState _withFreshAggregates(EvaluationState cur) {
    return cur.copyWith(
      currentStreak: _currentStreakCached(),
      bestStreak: _bestStreakCached(),
      weeklyScore: _weeklyScoreCached(),
      monthlyScore: _monthlyScoreCached(),
    );
  }

  int _monthlyScoreCached() =>
      EvaluationStatsCompute.monthlyScoreTotal(_scoreCache, DateTime.now());

  int _weeklyScoreCached() =>
      EvaluationStatsCompute.weeklyScoreTotal(_scoreCache, DateTime.now());

  /// Sum of today's achievable points from the visible worship items.
  /// The worship-checklist share of [dailyMaxScore]: every item the user has
  /// not hidden, at their own points and multiplier.
  ///
  /// Exposed because the evaluation tab now *says* what the daily ceiling is
  /// made of. «۱۲ از ۴۵» with no account of the 45 is a number the reader
  /// cannot audit — and it silently changes when they hide an item or edit its
  /// points, so it read as a bug the first time it moved.
  int get worshipDailyMax {
    final items = state.value?.worshipItems;
    if (items != null && items.isNotEmpty) {
      return items
          .where((w) => !_excludedWorship.contains(w.id))
          .fold(0, (s, w) => s + w.points);
    }
    return (_defaultWorship
                .where((w) => !_excludedWorship.contains(w.$1))
                .fold(0, (s, w) => s + w.$4) *
            _worshipMultiplier)
        .round();
  }

  int get dailyMaxScore =>
      worshipDailyMax + prayerDailyMax + adhkarDailyMax + tasbihDailyMax;

  /// Total points earned over the trailing 7 days (today included).
  int weeklyPoints() =>
      EvaluationStatsCompute.weeklyPoints(_scoreCache, DateTime.now());

  /// Total points earned across a specific (Gregorian) month.
  int monthlyPointsFor(int year, int month) =>
      EvaluationStatsCompute.monthlyPointsFor(_scoreCache, year, month);

  int _currentStreakCached() =>
      EvaluationStatsCompute.currentStreak(_scoreCache, DateTime.now());

  int _bestStreakCached() =>
      EvaluationStatsCompute.bestStreak(_scoreCache, DateTime.now());

  List<int> get monthlyScores =>
      EvaluationStatsCompute.monthlyScoreSeries(_scoreCache, DateTime.now());

  List<Map<String, dynamic>> get customWorshipItems => _customWorshipItemsCache;

  int countFastingDaysInMonth(int year, int month) =>
      EvaluationStatsCompute.countFastingDaysInMonth(
          _worshipCache, year, month);

  bool _isWorshipDoneOnDate(String worshipId, DateTime date) {
    final dk = dateKeyOf(date);
    if (_worshipCache[dk]?[worshipId] == 1) return true;
    return false;
  }

  bool isWorshipDoneOnDate(String worshipId, DateTime date) =>
      _isWorshipDoneOnDate(worshipId, date);

  /// Count worship item completions across a date range using the in-memory cache.
  /// «fasting» is excluded because it has its own dedicated circle in the
  /// evaluation tabs (counting it here would double-count it).
  int countWorshipDoneInRange(String startDateKey, String endDateKey) =>
      EvaluationStatsCompute.countWorshipDoneInRange(
          _worshipCache, startDateKey, endDateKey);

  /// Count fasting days across a date range using the in-memory cache.
  int countFastingInRange(String startDateKey, String endDateKey) =>
      EvaluationStatsCompute.countFastingInRange(
          _worshipCache, startDateKey, endDateKey);

  /// Number of hayz (period) days inside [startDateKey, endDateKey].
  int periodDaysInRange(String startDateKey, String endDateKey) =>
      EvaluationStatsCompute.periodDaysInRange(
          _periodDateKeys, startDateKey, endDateKey);

  /// Whether [dateKey] (YYYY-MM-DD) falls inside a hayz (period) record.
  bool isPeriodDay(String dateKey) => _periodDateKeys.contains(dateKey);

  Set<String> _collectPeriodDateKeys(
      List<PeriodRecordTableData> records, int defaultLength) {
    final keys = <String>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final r in records) {
      // استحاضه چرخهٔ حیض نیست؛ نماز و روزه در آن واجب است، پس از امتیازدهی
      // حذف نمی‌شود. فقط حیض و نفاس روزهای معاف محسوب می‌شوند.
      if (r.recordType == 'istihadha') continue;
      final start =
          DateTime(r.startDate.year, r.startDate.month, r.startDate.day);
      final DateTime end;
      if (r.endDate != null) {
        end = DateTime(r.endDate!.year, r.endDate!.month, r.endDate!.day);
      } else {
        // Active record: mirror PeriodRecordX.coversDate — its own stored
        // length, floored at today, capped at the fiqh maximum of its type —
        // so the evaluation circles and the period banner can never disagree.
        final len = r.periodLength > 0 ? r.periodLength : defaultLength;
        final predictedEnd = start.add(Duration(days: len - 1));
        final maxEnd = start.add(Duration(
            days: maxBleedingDaysFor(r.recordType == 'nifas'
                    ? PeriodRecordType.nifas
                    : PeriodRecordType.hayz) -
                1));
        var e = predictedEnd.isAfter(today) ? predictedEnd : today;
        if (e.isAfter(maxEnd)) e = maxEnd;
        end = e;
      }
      for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
        keys.add(dateKeyOf(d));
      }
    }
    return keys;
  }

  String get performanceRating => EvaluationStatsCompute.performanceRating(
        state.value?.monthlyScore ?? 0,
        dailyMaxScore,
        DateTime.now(),
      );

  /// Rating for the month shown by the stats widget (Audit 8.17): when the
  /// user browses a past month, the rating must reflect THAT month's elapsed
  /// days, not the current month's — previously it always reported the live
  /// month's rating against the browsed month's score.
  String performanceRatingFor(DateTime monthAnchor) =>
      EvaluationStatsCompute.performanceRating(
        EvaluationStatsCompute.monthlyPointsFor(
            _scoreCache, monthAnchor.year, monthAnchor.month),
        dailyMaxScore,
        monthAnchor,
      );

  double get dailyAverage => monthlyAverage;

  /// Rating for an explicit span of calendar days — the stats tab shows a
  /// Jalali month, whose Gregorian span `performanceRatingFor` (bucketed by
  /// Gregorian month) cannot express. Days after today are excluded from the
  /// reachable maximum, same as the current-month rule there.
  String performanceRatingForDays(List<DateTime> days) {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final score =
        days.fold<int>(0, (s, d) => s + (_scoreCache[dateKeyOf(d)] ?? 0));
    final elapsed = days.where((d) => !d.isAfter(todayMidnight)).length;
    return EvaluationStatsCompute.performanceRating(
      score,
      dailyMaxScore,
      days.isEmpty ? today : days.first,
      reachableDays: elapsed == 0 ? days.length : elapsed,
    );
  }

  void _refreshTodayAfterItemChange() {
    final today = dateKeyOf(DateTime.now());
    final items = _loadWorship(today);
    final worshipScore = items
        .where((w) => w.done && !_excludedWorship.contains(w.id))
        .fold(0, (s, w) => s + w.points);
    final score = _combinedScore(today, worshipScore);
    _scoreCache[today] = score;
    state = AsyncData(_withFreshAggregates(
        state.requireValue.copyWith(worshipItems: items, dailyScore: score)));
  }

  void addCustomWorshipItem(String label, IconData icon, int points) {
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final customList = [..._customWorshipItemsCache];
    final iconName = iconMap.entries
        .firstWhere(
          (e) => e.value == icon,
          orElse: () => const MapEntry<String, IconData>('star', Icons.star),
        )
        .key;
    customList.add(
        {'id': id, 'label': label, 'iconName': iconName, 'points': points});
    _customWorshipItemsCache = customList;
    ref
        .read(settingsProvider.notifier)
        .patch((s) => s.copyWith(customWorshipItems: List.of(customList)));
    // SINGLE SOURCE (Audit 2.6-3): today's azkar period completion is read
    // through one shared helper instead of six copy-pasted blocks that each
    // cleared + refilled the cache from azkarProvider.periodStats().
    refreshTodayAzkarPeriods(ref);

    _refreshTodayAfterItemChange();
  }

  void removeCustomWorshipItem(String id) {
    final customList = [..._customWorshipItemsCache];
    customList.removeWhere((c) => c['id'] == id);
    _customWorshipItemsCache = customList;
    ref
        .read(settingsProvider.notifier)
        .patch((s) => s.copyWith(customWorshipItems: List.of(customList)));
    // SINGLE SOURCE (Audit 2.6-3): today's azkar period completion is read
    // through one shared helper instead of six copy-pasted blocks that each
    // cleared + refilled the cache from azkarProvider.periodStats().
    refreshTodayAzkarPeriods(ref);

    // Removing a *checked* custom item used to leave its points in `dailyScore`
    // and in the heatmap cache until the next unrelated toggle.
    _refreshTodayAfterItemChange();
  }

  // ── Hidden defaults ──

  Set<String> _hiddenDefaults = {};

  Set<String> get hiddenDefaultIds => _hiddenDefaults;

  void _loadHiddenDefaults() {
    // Hidden-default ids come from the settings row (loaded during build).
  }

  void toggleHideDefaultItem(String id) {
    if (_hiddenDefaults.contains(id)) {
      _hiddenDefaults.remove(id);
    } else {
      _hiddenDefaults.add(id);
    }
    ref
        .read(settingsProvider.notifier)
        .patch((s) => s.copyWith(hiddenWorshipItems: _hiddenDefaults.toList()));
    // SINGLE SOURCE (Audit 2.6-3): today's azkar period completion is read
    // through one shared helper instead of six copy-pasted blocks that each
    // cleared + refilled the cache from azkarProvider.periodStats().
    refreshTodayAzkarPeriods(ref);

    _refreshTodayAfterItemChange();
  }

  bool isDefaultItemHidden(String id) => _hiddenDefaults.contains(id);

  void toggleWorshipForDate(String worshipId, DateTime date) {
    final dk = dateKeyOf(date);
    final current = _worshipCache[dk]?[worshipId] ?? 0;
    final newVal = current == 1 ? 0 : 1;
    _worshipCache.putIfAbsent(dk, () => {})[worshipId] = newVal;
    _dailyDao?.set('worship', dk, worshipId, newVal);
    _recomputeDateScore(dk);
    // SINGLE SOURCE (Audit 2.6-3): today's azkar period completion is read
    // through one shared helper instead of six copy-pasted blocks that each
    // cleared + refilled the cache from azkarProvider.periodStats().
    refreshTodayAzkarPeriods(ref);

    final today = dateKeyOf(DateTime.now());
    if (state is AsyncData && dk == today) {
      final items = _loadWorship(today);
      final worshipScore = items
          .where((w) => w.done && !_excludedWorship.contains(w.id))
          .fold(0, (s, w) => s + w.points);
      final dailyScore = _combinedScore(today, worshipScore);
      _scoreCache[today] = dailyScore;
      state = AsyncData(_withFreshAggregates(state.requireValue
          .copyWith(worshipItems: items, dailyScore: dailyScore)));
    } else if (state is AsyncData) {
      // Past-date toggle (calendar): refresh aggregates too, so
      // CalendarDayCell, FastingToggle and weekly/monthly scores reflect the
      // change immediately instead of waiting for an unrelated rebuild.
      state = AsyncData(_withFreshAggregates(state.requireValue.copyWith()));
    }
  }

  /// Recomputes a single date's worship score from its saved item states and
  /// persists it, so weekly/monthly scores stay in sync even for past dates
  /// (e.g. fasting toggled from the calendar). An explicitly edited past
  /// date is re-scored with current points and frozen again; untouched past
  /// dates always keep their frozen total.
  void _recomputeDateScore(String dateKey) {
    final saved = _worshipCache[dateKey] ?? {};
    final items = state.value?.worshipItems ?? const <WorshipItem>[];
    var worshipScore = 0;
    for (final w in items) {
      if (saved[w.id] == 1 && !_excludedWorship.contains(w.id)) {
        worshipScore += w.points;
      }
    }
    final score = _combinedScore(dateKey, worshipScore);
    _scoreCache[dateKey] = score;
    _dailyDao?.set('worship_score', dateKey, '', worshipScore);
    if (dateKey != dateKeyOf(DateTime.now())) {
      _frozenScores[dateKey] = score;
      _dailyDao?.set(_frozenCategory, dateKey, 'total', score);
      _dailyDao?.set(
          _frozenMetaCategory, '', 'frozen_schema', _frozenSchemaVersion);
      _frozenSchemaOk = true;
    }
  }

  int countFastingDaysInWeek() => EvaluationStatsCompute.countFastingDaysInWeek(
      _worshipCache, DateTime.now());

  List<int> get weeklyScores =>
      EvaluationStatsCompute.weeklyScoreSeries(_scoreCache, DateTime.now());

  double get weeklyAverage {
    final scores = weeklyScores;
    final activeDays = scores.where((s) => s > 0).length;
    if (activeDays == 0) return 0;
    return scores.fold(0, (a, b) => a + b) / activeDays;
  }

  int get weeklyActiveDays => weeklyScores.where((s) => s > 0).length;

  Map<String, dynamic> get weeklyBestWorst =>
      EvaluationStatsCompute.weeklyBestWorst(weeklyScores, DateTime.now());

  double get monthlyAverage {
    final scores = monthlyScores;
    final activeDays = scores.where((s) => s > 0).length;
    if (activeDays == 0) return 0;
    return scores.fold(0, (a, b) => a + b) / activeDays;
  }

  int get monthlyActiveDays => monthlyScores.where((s) => s > 0).length;

  /// Jalali equivalent of [gregorian], via the shared `shamsi_date` package
  /// (single source of truth — no hand-rolled duplicate algorithm).
  ({int year, int month, int day}) toJalali(DateTime gregorian) {
    final j = Jalali.fromDateTime(gregorian);
    return (year: j.year, month: j.month, day: j.day);
  }

  // ── Reset ──────────────────────────────────────────────────────────────

  /// What a reset of [start..end] would erase, in numbers.
  ///
  /// Read by the confirmation dialog. «تاریخچه پاک می‌شود» is a sentence a reader
  /// accepts without reading it; «۳۸ روز و ۹۴۰ امتیاز» is one they can weigh
  /// against what they are about to lose. Counted off the in-memory cache, so
  /// opening the dialog costs no query. The streak is measured inside the range
  /// only — a best streak from another month must not be quoted as at risk by a
  /// month reset that will never touch it.
  ({int days, int points, int bestStreak}) resetImpactForRange(
      DateTime start, DateTime end) {
    var days = 0;
    var points = 0;
    var best = 0;
    var current = 0;
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      final score = _scoreCache[dateKeyOf(d)] ?? 0;
      if (score <= 0) {
        current = 0;
        continue;
      }
      days++;
      points += score;
      current++;
      if (current > best) best = current;
    }
    return (days: days, points: points, bestStreak: best);
  }

  /// Deletes the recorded worship data of [start..end] (inclusive) and lets the
  /// scores rebuild to zero on their own.
  ///
  /// This is the user-approved FULL wipe (2026-11-05): inside the range it
  /// clears the worship checklist ticks, the derived scores, the frozen
  /// totals, the daily tasbih counters — and the prayer and azkar records,
  /// because the daily score is built from them and a reset that leaves them
  /// standing re-derives its own score on the next rebuild, which read as
  /// «the reset does nothing». When the range covers today the tasbih session
  /// dials are zeroed too. Period records and the lifetime tasbih totals are
  /// not touched.
  ///
  /// BEFORE anything is deleted the range's rows are snapshotted to disk
  /// (user request, 2026-11-05) — the returned path feeds the snackbar's
  /// «بازگردانی» action, and [restoreFromBackup] puts the rows back. If the
  /// backup cannot be written the reset aborts: an undo that only sometimes
  /// exists must never be promised.
  ///
  /// Returns the backup path on success, null when any write failed. Nothing
  /// is cleared in memory on failure: a screen that looks reset while the rows
  /// are still on disk is the worst of both outcomes, because the reader stops
  /// looking for the data.
  Future<String?> resetRange(DateTime start, DateTime end) async {
    final startKey = dateKeyOf(start);
    final endKey = dateKeyOf(end);
    String backupPath;
    try {
      final dao = ref.read(dailyStatusDaoProvider);
      final backup = EvaluationResetBackup(
        rangeStart: startKey,
        rangeEnd: endKey,
        createdAt: DateTime.now(),
        dailyRows: await dao.getRowsForRangeBackup(
            rangeResetCategories, 'tasbih_daily_', startKey, endKey),
        prayerRows: await ref
            .read(prayerTrackerDaoProvider)
            .getAllInDateRange(startKey, endKey),
        zikrRows: await ref
            .read(azkarStatusDaoProvider)
            .getStatusesForDateRange(startKey, endKey),
      );
      backupPath = await saveEvaluationBackup(backup);
      await dao.deleteCategoriesInDateRange(
          rangeResetCategories, startKey, endKey);
      await dao.deleteCategoryPrefixInDateRange(
          'tasbih_daily_', startKey, endKey);
      await ref
          .read(prayerTrackerDaoProvider)
          .deleteDateRange(startKey, endKey);
      await ref.read(azkarStatusDaoProvider).deleteDateRange(startKey, endKey);
    } catch (e) {
      AppLogger.warning('Evaluation', 'range reset failed: $e');
      return null;
    }
    // The dials belong to the wiped day too (user decision, 2026-11-05).
    final todayKey = dateKeyOf(DateTime.now());
    if (todayKey.compareTo(startKey) >= 0 && todayKey.compareTo(endKey) <= 0) {
      await ref.read(tasbihProvider.notifier).resetAllSessions();
      // The home-screen widgets mirror today's tasbih daily total, per-zikr
      // counts and prayer «خواندم» marks natively. Clear that mirror too, or
      // the next widget→app sync (10 s retry timer / app resume) re-imports it
      // and resurrects the reset a few seconds later.
      //
      // Fire-and-forget with its own catch: the mirror clear is best-effort
      // hygiene for the NEXT sync tick, not a precondition of the reset —
      // awaiting it here gated the whole reset on a platform-channel round
      // trip (and hung the reset in tests where the channel has no handler).
      unawaited(ref.read(widgetSyncProvider).clearEvaluationState().catchError(
            (Object e) => AppLogger.warning(
                'Evaluation', 'widget clear failed: $e'),
          ));
    }
    // The screens that own the deleted records must agree with the DB, or the
    // next tab shows ticks the reset just removed. Azkar cannot be plainly
    // invalidated: its repository caches today's statuses, and a rebuild off a
    // stale cache would resurrect the deleted completions — the explicit
    // refresh re-reads the cache instead.
    ref.invalidate(prayerTrackerProvider);
    ref.invalidate(tasbihProvider);
    await ref.read(azkarProvider.notifier).refreshAfterExternalReset();
    // Rebuild from what is left rather than patching the caches by hand: the
    // build already knows how to derive scores from the remaining sources, and
    // a second derivation here could drift from it.
    ref.invalidateSelf();
    return backupPath;
  }

  /// Puts a range-reset's snapshot back and rebuilds every affected screen.
  ///
  /// A failed restore reports false and touches nothing — «the undo did not
  /// work» is a readable answer, «half my week is back» is not.
  Future<bool> restoreFromBackup(String path) async {
    try {
      final backup = await readEvaluationBackup(path);
      final dao = ref.read(dailyStatusDaoProvider);
      await dao.restoreRows(backup.dailyRows);
      await ref.read(prayerTrackerDaoProvider).restoreRows(backup.prayerRows);
      await ref.read(azkarStatusDaoProvider).restoreRows(backup.zikrRows);
    } catch (e) {
      AppLogger.warning('Evaluation', 'backup restore failed: $e');
      return false;
    }
    ref.invalidate(prayerTrackerProvider);
    ref.invalidate(tasbihProvider);
    await ref.read(azkarProvider.notifier).refreshAfterExternalReset();
    ref.invalidateSelf();
    return true;
  }

  /// Delegates to the pure [report.buildMonthlyReport] — the single source
  /// for the text report (Audit 8.17 follow-up: this used to duplicate the
  /// builder, and the two could drift apart).
  String generateMonthlyReport() {
    final s = state.value;
    return report.buildMonthlyReport(
      s?.monthlyScore,
      performanceRating: performanceRating,
      dailyAverage: dailyAverage,
      currentStreak: s?.currentStreak ?? 0,
      bestStreak: s?.bestStreak ?? 0,
      worshipDone: s?.worshipItems.where((w) => w.done).length ?? 0,
      worshipTotal: s?.worshipItems.length ?? 0,
      monthlyScores: monthlyScores,
      totalCompleted: s?.totalCompleted ?? 0,
      totalSkipped: s?.totalSkipped ?? 0,
    );
  }
}
