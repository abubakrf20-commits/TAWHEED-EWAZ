import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/features/worship/data/daos/daily_status_dao.dart';
import 'package:tawheeed/features/adhkar/data/daos/azkar_status_dao.dart';
import 'package:tawheeed/features/adhkar/data/azkar_data.dart';
import 'package:tawheeed/features/adhkar/tasbih/data/daos/tasbih_dao.dart';
import 'package:tawheeed/features/adhkar/tasbih/domain/entities/tasbih_model.dart';
import 'package:tawheeed/features/adhkar/domain/entities/zikr_item.dart';
import 'package:tawheeed/features/worship/domain/evaluation_calculator.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

const String frozenScoreCategory = 'eval_frozen_score';
const String frozenMetaCategory = 'eval_meta';
const int frozenSchemaVersion = 1;

/// Where a reset leaves its cutoff, as a row whose `date` is the day the reader
/// pressed reset.
///
/// WHY a stored date and not just a delete: deleting the evaluation's rows is not
/// enough to make the numbers start over. `build()` re-scores every past day that
/// has prayer, adhkar or tasbih records — which the reset deliberately does not
/// touch, because those are real records owned by other screens. Without a
/// cutoff, a reader who reset would open the month chart and find every bar still
/// there. The marker is the thing that makes "start over" mean it, and it costs
/// one row.
const String evalResetCategory = 'eval_reset';

class EvaluationLoadResult {
  final Map<String, int> scoreMap;
  final Map<String, Map<String, int>> worshipMap;
  final Map<String, int> tasbihDaily;
  final List<ZikrStatusRecordTableData> weekRecords;
  final List<ZikrStatusRecordTableData> monthRecords;
  final int totalDone;
  final int totalSkipped;
  final List<TasbihModel> allTasbih;
  final Map<String, int> frozenScores;
  final bool frozenSchemaOk;
  final Map<String, bool> pastAzkarPeriods;

  /// Latest reset cutoff (`YYYY-MM-DD`), or null when the reader never reset.
  /// Every date strictly before it is ignored by the evaluation.
  final String? resetAt;

  const EvaluationLoadResult({
    required this.scoreMap,
    required this.worshipMap,
    required this.tasbihDaily,
    required this.weekRecords,
    required this.monthRecords,
    required this.totalDone,
    required this.totalSkipped,
    required this.allTasbih,
    required this.frozenScores,
    required this.frozenSchemaOk,
    required this.pastAzkarPeriods,
    required this.resetAt,
  });
}

Future<EvaluationLoadResult> loadEvaluationData({
  required Ref ref,
  required String today,
  required String weekStart,
  required String monthStart,
}) async {
  final dailyDao = ref.read(dailyStatusDaoProvider);
  final azkarStatusDao = ref.read(azkarStatusDaoProvider);
  final tasbihDao = ref.read(tasbihDaoProvider);
  final (
    Map<String, int> scoreMap,
    Map<String, Map<String, int>> worshipMap,
    Map<String, int> tasbihDaily,
    List<ZikrStatusRecordTableData> weekRecords,
    List<ZikrStatusRecordTableData> monthRecords,
    int totalDone,
    int totalSkipped,
    List<TasbihModel> allTasbih,
  ) = await (
    dailyDao.getAllAsMap('worship_score'),
    dailyDao.getAllGroupedByDate('worship'),
    dailyDao.getAllAsMap('tasbih_daily'),
    azkarStatusDao.getStatusesForDateRange(weekStart, today),
    azkarStatusDao.getStatusesForDateRange(monthStart, today),
    azkarStatusDao.countByStatus(1),
    azkarStatusDao.countByStatus(2),
    // A broken tasbih table must not blank the whole evaluation screen, but it
    // must not read as 'user did no dhikr' either — the fallback is reported.
    tasbihDao.getAllDomain().catchError((Object e) {
      AppLogger.warning('evaluation_loader', 'tasbih load failed: $e');
      return <TasbihModel>[];
    }),
  ).wait;

  final frozenScores = await dailyDao.getAllAsMap(frozenScoreCategory);
  final frozenSchemaOk =
      await dailyDao.getValue(frozenMetaCategory, '', 'frozen_schema') ==
          frozenSchemaVersion;
  final resetAt = _latestResetCutoff(await dailyDao.getAllForCategory(evalResetCategory));

  await AzkarData.ensureLoaded();
  final pastAzkarPeriods =
      _computePastAzkarPeriods([...weekRecords, ...monthRecords]);

  return EvaluationLoadResult(
    scoreMap: scoreMap,
    worshipMap: worshipMap,
    tasbihDaily: tasbihDaily,
    weekRecords: weekRecords,
    monthRecords: monthRecords,
    totalDone: totalDone,
    totalSkipped: totalSkipped,
    allTasbih: allTasbih,
    frozenScores: frozenScores,
    frozenSchemaOk: frozenSchemaOk,
    pastAzkarPeriods: pastAzkarPeriods,
    resetAt: resetAt,
  );
}

/// The newest cutoff row, or null when there is none.
///
/// Rows are date-keyed and a reader can reset more than once, so the answer is
/// the maximum — a later reset must never be undone by an earlier marker still
/// sitting in the table.
String? _latestResetCutoff(List<DailyStatusTableData> rows) {
  String? latest;
  for (final row in rows) {
    if (row.date.isEmpty) continue;
    if (latest == null || row.date.compareTo(latest) > 0) latest = row.date;
  }
  return latest;
}

/// Derives past-date azkar period completion from persisted zikr status
/// records. A period counts as done for a date only when *every* zikr of
/// that period has a done row for that date (an untouched zikr has no row
/// and therefore does not count).
Map<String, bool> _computePastAzkarPeriods(
    List<ZikrStatusRecordTableData> records) {
  final morningIds =
      AzkarData.getByPeriod(PrayerPeriod.morningAzkar).map((z) => z.id).toSet();
  final eveningIds =
      AzkarData.getByPeriod(PrayerPeriod.eveningAzkar).map((z) => z.id).toSet();
  if (morningIds.isEmpty && eveningIds.isEmpty) return const {};
  final byDate = <String, Map<String, int>>{};
  for (final r in records) {
    (byDate[r.date] ??= {})[r.id] = r.statusIndex;
  }
  final today = EvaluationCalculator.dateKey(DateTime.now());
  final result = <String, bool>{};
  for (final e in byDate.entries) {
    if (e.key == today) continue;
    if (morningIds.isNotEmpty) {
      result['${e.key}:morningAzkar'] =
          morningIds.every((id) => e.value[id] == 1);
    }
    if (eveningIds.isNotEmpty) {
      result['${e.key}:eveningAzkar'] =
          eveningIds.every((id) => e.value[id] == 1);
    }
  }
  return result;
}
