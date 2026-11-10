import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/features/adhkar/tasbih/presentation/providers/tasbih_provider.dart';
import 'package:tawheeed/features/worship/data/daos/daily_status_dao.dart';
import 'package:tawheeed/shared/utils/date_key.dart';

/// Figures for the tasbih stats cards (spec §TASBIH: «این هفته»، «هدف روزانه»).
///
/// Aggregates the `tasbih_daily` rows written by the Tasbih notifier; the week
/// starts on Saturday (Iran) and runs through today. [sumTargets] is the sum
/// of every dhikr's target — the day's configured plan — read from the live
/// tasbih list.
class TasbihStatsData {
  const TasbihStatsData({
    required this.weekTotal,
    required this.todayTotal,
    required this.sumTargets,
  });

  final int weekTotal;
  final int todayTotal;
  final int sumTargets;

  static const empty =
      TasbihStatsData(weekTotal: 0, todayTotal: 0, sumTargets: 0);
}

/// Rebuilds whenever the tasbih list state changes (each flushed batch of
/// taps, add/delete/target edit), so the numbers trail the counter by at most
/// one 180ms flush — no DB read sits on the tap path itself.
///
/// A failed read is published as an [AsyncError] rather than as zeros: a
/// counter that says «۰ این هفته» when the database could not be read is a
/// wrong reading, not a degraded one. Every consumer already tolerates a
/// missing value (`daily_summary_card` reads `.value`, the stat pills render
/// an em dash).
final tasbihStatsProvider = FutureProvider<TasbihStatsData>((ref) async {
  final items = ref.watch(tasbihProvider).value ?? const [];
  final sumTargets = items.fold<int>(0, (sum, t) => sum + t.targetCount);
  final dao = ref.read(dailyStatusDaoProvider);
  final now = DateTime.now();
  // Date-only arithmetic: subtracting a Duration across a DST boundary shifts
  // the whole week and can skip or duplicate the first day's rows.
  final weekStart =
      DateTime(now.year, now.month, now.day - (now.weekday - DateTime.saturday) % 7);
  final todayKey = dateKeyOf(now);
  final rows = await dao.getAllInDateRange(
    'tasbih_daily',
    dateKeyOf(weekStart),
    todayKey,
  );
  var week = 0;
  var today = 0;
  for (final row in rows) {
    week += row.value;
    if (row.date == todayKey) today += row.value;
  }
  return TasbihStatsData(
    weekTotal: week,
    todayTotal: today,
    sumTargets: sumTargets,
  );
});
