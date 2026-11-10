import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/worship/domain/entities/evaluation_stats.dart';

void main() {
  group('EvaluationStats', () {
    test('constructor sets all fields', () {
      const stats = EvaluationStats(
        dailyScore: 80,
        weeklyScore: 550,
        monthlyScore: 2200,
        currentStreak: 7,
        bestStreak: 30,
        totalCompleted: 150,
        totalSkipped: 10,
        todayCompleted: 5,
        weeklyCompleted: 35,
        totalDoneThisMonth: 140,
        worshipDoneToday: 3,
        worshipTotal: 10,
        monthlyStats: [20, 25, 30],
        monthlyScores: [200, 250, 300],
        weeklyStats: [10, 15, 12],
        performanceRating: 'عالی',
        dailyAverage: 5.0,
        bestWorstDay: {'best': 10, 'worst': 0},
        weeklyScores: [80, 90, 85],
        weeklyAverage: 5.0,
        weeklyActiveDays: 7,
        weeklyPrayerCount: 35,
        monthlyAverage: 4.7,
        monthlyActiveDays: 28,
        monthlyPrayerCount: 140,
        weeklyBestWorst: {'best': 10, 'worst': 5},
      );
      expect(stats.dailyScore, 80);
      expect(stats.weeklyScore, 550);
      expect(stats.monthlyScore, 2200);
      expect(stats.currentStreak, 7);
      expect(stats.bestStreak, 30);
      expect(stats.totalCompleted, 150);
      expect(stats.totalSkipped, 10);
      expect(stats.todayCompleted, 5);
      expect(stats.weeklyCompleted, 35);
      expect(stats.totalDoneThisMonth, 140);
      expect(stats.worshipDoneToday, 3);
      expect(stats.worshipTotal, 10);
      expect(stats.monthlyStats, [20, 25, 30]);
      expect(stats.monthlyScores, [200, 250, 300]);
      expect(stats.weeklyStats, [10, 15, 12]);
      expect(stats.performanceRating, 'عالی');
      expect(stats.dailyAverage, 5.0);
      expect(stats.bestWorstDay, {'best': 10, 'worst': 0});
      expect(stats.weeklyScores, [80, 90, 85]);
      expect(stats.weeklyAverage, 5.0);
      expect(stats.weeklyActiveDays, 7);
      expect(stats.weeklyPrayerCount, 35);
      expect(stats.monthlyAverage, 4.7);
      expect(stats.monthlyActiveDays, 28);
      expect(stats.monthlyPrayerCount, 140);
      expect(stats.weeklyBestWorst, {'best': 10, 'worst': 5});
    });
  });
}
