import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/features/worship/data/daos/daily_status_dao.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/date_key.dart';

class ReadingStreakState {
  final int currentStreak;
  final int longestStreak;
  final int todayPages;
  final int totalSessions;
  final Map<String, int> monthlyData;

  const ReadingStreakState({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.todayPages = 0,
    this.totalSessions = 0,
    this.monthlyData = const {},
  });
}

class ReadingStreakNotifier extends Notifier<ReadingStreakState> {
  DailyStatusDao? _dao;
  Timer? _midnightTimer;
  Map<String, int> _dataCache = {};

  /// Resolved when the initial DB read lands. The read assigns the whole
  /// cache, so a `logReading` made while it was in flight was silently
  /// overwritten by the older snapshot.
  Completer<void> _ready = Completer<void>();

  @override
  ReadingStreakState build() {
    _ready = Completer<void>();
    _init();
    ref.onDispose(() => _midnightTimer?.cancel());
    return const ReadingStreakState();
  }

  Future<void> _awaitReady() async {
    if (!_ready.isCompleted) await _ready.future;
  }

  Future<void> _init() async {
    _dao = ref.read(dailyStatusDaoProvider);
    _scheduleMidnightRefresh();
    try {
      await _loadFromDao();
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final midnight =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    _midnightTimer = Timer(midnight.difference(now), () {
      _loadFromDao();
      _scheduleMidnightRefresh();
    });
  }

  Future<void> _loadFromDao() async {
    final dao = _dao;
    if (dao == null) return;
    try {
      final data = await dao.getAllAsMap('reading');
      if (!ref.mounted) return;
      _dataCache = data;
      _updateState();
    } catch (e) {
      AppLogger.warning('ReadingStreak', 'load failed: $e');
    }
  }

  void _updateState() {
    final today = dateKeyOf(DateTime.now());
    final todayPages = _dataCache[today] ?? 0;
    state = ReadingStreakState(
      currentStreak: _computeStreak(_dataCache),
      longestStreak: _computeLongestStreak(_dataCache),
      todayPages: todayPages,
      totalSessions: _dataCache.length,
      monthlyData: Map.from(_dataCache),
    );
  }

  Future<void> logReading({int pages = 1}) async {
    await _awaitReady();
    if (!ref.mounted) return;
    final dao = _dao;
    if (dao == null) return;
    final date = dateKeyOf(DateTime.now());
    final total = (_dataCache[date] ?? 0) + pages;
    _dataCache[date] = total;
    await dao.set('reading', date, '', total);
    _updateState();
  }

  int _computeStreak(Map<String, int> data) {
    if (data.isEmpty) return 0;
    var streak = 0;
    final now = DateTime.now();
    for (var i = 0; i < 365; i++) {
      final d = DateTime(now.year, now.month, now.day - i);
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      if (data.containsKey(key) && (data[key] ?? 0) > 0) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  int _computeLongestStreak(Map<String, int> data) {
    if (data.isEmpty) return 0;
    final sorted = data.entries
        .where((e) => e.value > 0)
        .map((e) => e.key)
        .toList()
      ..sort();
    if (sorted.isEmpty) return 0;
    var maxStreak = 1;
    var current = 1;
    for (var i = 1; i < sorted.length; i++) {
      final prev = DateTime.parse(sorted[i - 1]);
      final curr = DateTime.parse(sorted[i]);
      if (curr.difference(prev).inDays == 1) {
        current++;
        if (current > maxStreak) maxStreak = current;
      } else {
        current = 1;
      }
    }
    return maxStreak;
  }
}

final readingStreakProvider =
    NotifierProvider<ReadingStreakNotifier, ReadingStreakState>(
        ReadingStreakNotifier.new);
