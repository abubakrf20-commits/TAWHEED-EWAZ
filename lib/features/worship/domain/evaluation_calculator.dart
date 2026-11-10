import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/features/prayer/domain/entities/prayer_tracker_entities.dart';

class EvaluationCalculator {
  const EvaluationCalculator._();

  /// Maximum points a single طاعات checklist item can earn per day. Kept
  /// deliberately low so the worship checklist stays a habit tracker rather
  /// than a point grind. The global worshipMultiplier may lower this further
  /// but never raises it.
  static const int maxWorshipItemPoints = 5;

  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Whole-calendar-day difference (a.midnight vs b.midnight), avoiding the
  /// Duration.inDays truncation trap that breaks midnight-vs-noon dates.
  static int daysBetween(DateTime a, DateTime b) {
    final aMid = DateTime(a.year, a.month, a.day);
    final bMid = DateTime(b.year, b.month, b.day);
    return aMid.difference(bMid).inDays;
  }

  /// Scales a raw طاعات item value by [worshipMultiplier], capping the result
  /// at [maxWorshipItemPoints] per item (see that constant's doc comment).
  static int worshipItemPoints(int rawPoints, double worshipMultiplier) {
    final p = (rawPoints * worshipMultiplier).round();
    if (p > maxWorshipItemPoints) return maxWorshipItemPoints;
    if (p < 1) return 1;
    return p;
  }

  static int prayerPoints(
    String dateKey,
    Map<String, int> cache,
    int fardhPoint,
    int sunnahPoint,
    int duhaPoint,
  ) {
    int points = 0;
    for (final p in FardhPrayer.values) {
      final raw = cache['pt_${dateKey}_${p.name}'];
      if (raw != null) {
        final s = PrayerStatus.values[raw];
        if (s == PrayerStatus.done || s == PrayerStatus.qada) {
          points += fardhPoint;
        }
      }
    }
    for (final p in SunnahPrayer.values) {
      if ((cache['pt_${dateKey}_sunnah_${p.name}'] ?? 0) == 1) {
        points += sunnahPoint;
      }
    }
    if ((cache['pt_${dateKey}_duha'] ?? 0) == 1) {
      points += duhaPoint;
    }
    return points;
  }

  static int adhkarPoints(
    String dateKey,
    Map<String, bool> azkarPeriodDone,
    int adhkarPoint,
  ) {
    final morningDone = azkarPeriodDone['$dateKey:morningAzkar'] ?? false;
    final eveningDone = azkarPeriodDone['$dateKey:eveningAzkar'] ?? false;
    return (morningDone ? adhkarPoint : 0) + (eveningDone ? adhkarPoint : 0);
  }

  static int tasbihPoints(
    String dateKey,
    Map<String, int> tasbihDailyCache,
    int tasbihPoint,
  ) {
    final count = tasbihDailyCache[dateKey] ?? 0;
    return count > 0 ? tasbihPoint : 0;
  }

  static int prayerDailyMax(
    int fardhPoint,
    int sunnahPoint,
    int duhaPoint,
  ) =>
      FardhPrayer.values.length * fardhPoint +
      SunnahPrayer.values.length * sunnahPoint +
      duhaPoint;

  /// Jalali equivalent of [gregorian], via the shared `shamsi_date` package
  /// (single source of truth — no hand-rolled duplicate algorithm).
  static ({int year, int month, int day}) toJalali(DateTime gregorian) {
    final j = Jalali.fromDateTime(gregorian);
    return (year: j.year, month: j.month, day: j.day);
  }
}
