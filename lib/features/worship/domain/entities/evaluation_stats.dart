class EvaluationStats {
  final int dailyScore;
  final int weeklyScore;
  final int monthlyScore;
  final int currentStreak;
  final int bestStreak;
  final int totalCompleted;
  final int totalSkipped;
  final int todayCompleted;
  final int weeklyCompleted;
  final int totalDoneThisMonth;
  final int worshipDoneToday;
  final int worshipTotal;
  final List<int> monthlyStats;
  final List<int> monthlyScores;
  final List<int> weeklyStats;
  final String performanceRating;
  final double dailyAverage;
  final Map<String, int> bestWorstDay;
  final List<int> weeklyScores;
  final double weeklyAverage;
  final int weeklyActiveDays;
  final int weeklyPrayerCount;
  final double monthlyAverage;
  final int monthlyActiveDays;
  final int monthlyPrayerCount;
  final Map<String, dynamic> weeklyBestWorst;

  const EvaluationStats({
    required this.dailyScore,
    required this.weeklyScore,
    required this.monthlyScore,
    required this.currentStreak,
    required this.bestStreak,
    required this.totalCompleted,
    required this.totalSkipped,
    required this.todayCompleted,
    required this.weeklyCompleted,
    required this.totalDoneThisMonth,
    required this.worshipDoneToday,
    required this.worshipTotal,
    required this.monthlyStats,
    required this.monthlyScores,
    required this.weeklyStats,
    required this.performanceRating,
    required this.dailyAverage,
    required this.bestWorstDay,
    required this.weeklyScores,
    required this.weeklyAverage,
    required this.weeklyActiveDays,
    required this.weeklyPrayerCount,
    required this.monthlyAverage,
    required this.monthlyActiveDays,
    required this.monthlyPrayerCount,
    required this.weeklyBestWorst,
  });
}
