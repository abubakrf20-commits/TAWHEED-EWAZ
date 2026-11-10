import 'package:tawheeed/features/worship/domain/evaluation_calculator.dart';

class EvaluationStatsCompute {
  const EvaluationStatsCompute._();

  static int currentStreak(Map<String, int> scoreCache, DateTime now) {
    int streak = 0;
    for (int i = 0; i < 365; i++) {
      final d = now.subtract(Duration(days: i));
      final score = scoreCache[EvaluationCalculator.dateKey(d)] ?? 0;
      if (score > 0) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }
    return streak;
  }

  static int bestStreak(Map<String, int> scoreCache, DateTime now) {
    int maxStreak = 0, current = 0;
    for (int i = 0; i < 365; i++) {
      final d = now.subtract(Duration(days: i));
      final score = scoreCache[EvaluationCalculator.dateKey(d)] ?? 0;
      if (score > 0) {
        current++;
      } else {
        if (current > maxStreak) {
          maxStreak = current;
        }
        current = 0;
      }
    }
    if (current > maxStreak) maxStreak = current;
    return maxStreak;
  }

  static int monthlyScoreTotal(Map<String, int> scoreCache, DateTime now) {
    int total = 0;
    for (final entry in scoreCache.entries) {
      final parts = entry.key.split('-');
      if (parts.length != 3) continue;
      try {
        final d = DateTime(
            int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        if (d.year == now.year && d.month == now.month) {
          total += entry.value;
        }
      } catch (_) {
        // Corrupt cache row (key not yyyy-MM-dd) — skip; not a runtime error.
      }
    }
    return total;
  }

  static int weeklyScoreTotal(Map<String, int> scoreCache, DateTime now) {
    int total = 0;
    for (final entry in scoreCache.entries) {
      final parts = entry.key.split('-');
      if (parts.length != 3) continue;
      try {
        final d = DateTime(
            int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        final diff = EvaluationCalculator.daysBetween(now, d);
        if (diff >= 0 && diff < 7) {
          total += entry.value;
        }
      } catch (_) {
        // Corrupt cache row (key not yyyy-MM-dd) — skip; not a runtime error.
      }
    }
    return total;
  }

  /// Total points earned over the trailing 7 days (today included).
  static int weeklyPoints(Map<String, int> scoreCache, DateTime now) {
    int total = 0;
    for (int i = 0; i < 7; i++) {
      total += scoreCache[
              EvaluationCalculator.dateKey(now.subtract(Duration(days: i)))] ??
          0;
    }
    return total;
  }

  /// Total points earned across a specific (Gregorian) month.
  static int monthlyPointsFor(
      Map<String, int> scoreCache, int year, int month) {
    int total = 0;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    for (int day = 1; day <= daysInMonth; day++) {
      total += scoreCache[
              EvaluationCalculator.dateKey(DateTime(year, month, day))] ??
          0;
    }
    return total;
  }

  static List<int> weeklyScoreSeries(
      Map<String, int> scoreCache, DateTime now) {
    final weekData = List.filled(7, 0);
    for (final entry in scoreCache.entries) {
      try {
        final parts = entry.key.split('-');
        if (parts.length != 3) continue;
        final d = DateTime(
            int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        final diff = EvaluationCalculator.daysBetween(now, d);
        if (diff >= 0 && diff < 7) {
          weekData[diff] = entry.value;
        }
      } catch (_) {
        // Corrupt cache row (key not yyyy-MM-dd) — skip; not a runtime error.
      }
    }
    return weekData;
  }

  static List<int> monthlyScoreSeries(
      Map<String, int> scoreCache, DateTime now) {
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final data = List.filled(daysInMonth, 0);
    for (final entry in scoreCache.entries) {
      final parts = entry.key.split('-');
      if (parts.length != 3) continue;
      try {
        final d = DateTime(
            int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        if (d.year == now.year && d.month == now.month) {
          data[d.day - 1] = entry.value;
        }
      } catch (_) {
        // Corrupt cache row (key not yyyy-MM-dd) — skip; not a runtime error.
      }
    }
    return data;
  }

  static double averageOf(List<int> scores) {
    final activeDays = scores.where((s) => s > 0).length;
    if (activeDays == 0) return 0;
    return scores.fold(0, (a, b) => a + b) / activeDays;
  }

  static int activeDaysOf(List<int> scores) =>
      scores.where((s) => s > 0).length;

  /// Rating thresholds are relative to the points actually REACHABLE
  /// (Audit 8.17): the score accumulator only spans the elapsed days of
  /// the month, so the old whole-calendar-month denominator kept the
  /// fraction below the lowest threshold until the last third of the
  /// month — every user read «نیاز به تلاش بیشتر» for weeks. The current
  /// month divides by the elapsed days (a perfect daily pace reads «عالی»
  /// at any point mid-month); any other anchor (browsed past/future
  /// months) is fully scored and keeps the old whole-month formula.
  static String performanceRating(
      int monthlyScore, int dailyMaxScore, DateTime now,
      {int? reachableDays}) {
    final today = DateTime.now();
    final isCurrentMonth = now.year == today.year && now.month == today.month;
    final elapsedDays = reachableDays ??
        (isCurrentMonth
            ? today.day
            : DateTime(now.year, now.month + 1)
                .difference(DateTime(now.year, now.month))
                .inDays);
    final max = dailyMaxScore * elapsedDays;
    if (max <= 0) return 'نیاز به تلاش بیشتر';
    return ratingForFraction(monthlyScore / max);
  }

  /// The single threshold table behind every rating badge. Kept separate so the
  /// score cards and the share report cannot disagree about one month.
  static String ratingForFraction(double fraction) {
    if (fraction >= 0.875) return 'عالی';
    if (fraction >= 0.625) return 'خوب';
    if (fraction >= 0.375) return 'قابل قبول';
    return 'نیاز به تلاش بیشتر';
  }

  static String weekdayName(int weekday) {
    return switch (weekday) {
      1 => 'دوشنبه',
      2 => 'سه‌شنبه',
      3 => 'چهارشنبه',
      4 => 'پنجشنبه',
      5 => 'جمعه',
      6 => 'شنبه',
      7 => 'یکشنبه',
      _ => '',
    };
  }

  static Map<String, dynamic> weeklyBestWorst(List<int> scores, DateTime now) {
    int best = 0, worst = 999999;
    int bestIdx = 0, worstIdx = 0;
    for (int i = 0; i < 7; i++) {
      if (scores[i] > best) {
        best = scores[i];
        bestIdx = i;
      }
      if (scores[i] > 0 && scores[i] < worst) {
        worst = scores[i];
        worstIdx = i;
      }
    }
    return {
      'bestDay': best > 0
          ? weekdayName(now.subtract(Duration(days: bestIdx)).weekday)
          : '-',
      'bestScore': best > 0 ? best : 0,
      'worstDay': worst < 999999
          ? weekdayName(now.subtract(Duration(days: worstIdx)).weekday)
          : '-',
      'worstScore': worst < 999999 ? worst : 0,
    };
  }

  static int tasbihCountForDay(Map<String, int> tasbihDailyCache, DateTime d) =>
      tasbihDailyCache[EvaluationCalculator.dateKey(d)] ?? 0;

  static int tasbihCountForLast7Days(
      Map<String, int> tasbihDailyCache, DateTime now) {
    int sum = 0;
    for (int i = 0; i < 7; i++) {
      sum +=
          tasbihCountForDay(tasbihDailyCache, now.subtract(Duration(days: i)));
    }
    return sum;
  }

  static int tasbihCountForMonth(
      Map<String, int> tasbihDailyCache, int year, int month) {
    final days = DateTime(year, month + 1, 0).day;
    int sum = 0;
    for (int day = 1; day <= days; day++) {
      sum += tasbihCountForDay(tasbihDailyCache, DateTime(year, month, day));
    }
    return sum;
  }

  static bool isWorshipDoneOnDate(Map<String, Map<String, int>> worshipCache,
      String worshipId, DateTime date) {
    final dk = EvaluationCalculator.dateKey(date);
    if (worshipCache[dk]?[worshipId] == 1) return true;
    return false;
  }

  /// Count worship item completions across a date range using the in-memory
  /// cache. «fasting» is excluded because it has its own dedicated circle in
  /// the evaluation tabs (counting it here would double-count it).
  static int countWorshipDoneInRange(Map<String, Map<String, int>> worshipCache,
      String startDateKey, String endDateKey) {
    int count = 0;
    for (final entry in worshipCache.entries) {
      if (entry.key.compareTo(startDateKey) >= 0 &&
          entry.key.compareTo(endDateKey) <= 0) {
        count += entry.value.entries
            .where((e) => e.value == 1 && e.key != 'fasting')
            .length;
      }
    }
    return count;
  }

  /// Count fasting days across a date range using the in-memory cache.
  static int countFastingInRange(Map<String, Map<String, int>> worshipCache,
      String startDateKey, String endDateKey) {
    int count = 0;
    final start = DateTime.parse(startDateKey);
    final end = DateTime.parse(endDateKey);
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      if (isWorshipDoneOnDate(worshipCache, 'fasting', d)) count++;
    }
    return count;
  }

  static int countFastingDaysInMonth(
      Map<String, Map<String, int>> worshipCache, int year, int month) {
    int count = 0;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    for (int day = 1; day <= daysInMonth; day++) {
      if (isWorshipDoneOnDate(
          worshipCache, 'fasting', DateTime(year, month, day))) {
        count++;
      }
    }
    return count;
  }

  static int countFastingDaysInWeek(
      Map<String, Map<String, int>> worshipCache, DateTime now) {
    int count = 0;
    for (int i = 0; i < 7; i++) {
      if (isWorshipDoneOnDate(
          worshipCache, 'fasting', now.subtract(Duration(days: i)))) {
        count++;
      }
    }
    return count;
  }

  /// Number of hayz (period) days inside [startDateKey, endDateKey].
  static int periodDaysInRange(
      Set<String> periodDateKeys, String startDateKey, String endDateKey) {
    int count = 0;
    for (final dk in periodDateKeys) {
      if (dk.compareTo(startDateKey) >= 0 && dk.compareTo(endDateKey) <= 0) {
        count++;
      }
    }
    return count;
  }
}
