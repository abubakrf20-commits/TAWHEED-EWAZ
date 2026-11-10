import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/shared/models/achievement.dart';

void main() {
  final unlockedAt = DateTime(2026, 7, 10);

  group('Achievement', () {
    test('constructor sets required fields', () {
      const achievement = Achievement(
        id: '1',
        title: 'First Prayer',
        description: 'Complete your first prayer',
        icon: '🕌',
        targetProgress: 1,
      );
      expect(achievement.id, '1');
      expect(achievement.title, 'First Prayer');
      expect(achievement.description, 'Complete your first prayer');
      expect(achievement.icon, '🕌');
      expect(achievement.targetProgress, 1);
    });

    test('constructor sets default values', () {
      const achievement = Achievement(
        id: '1',
        title: 'Test',
        description: 'Test desc',
        icon: '⭐',
        targetProgress: 10,
      );
      expect(achievement.points, 0);
      expect(achievement.isUnlocked, false);
      expect(achievement.unlockedAt, isNull);
      expect(achievement.progress, 0);
    });

    test('constructor sets custom values', () {
      final achievement = Achievement(
        id: '2',
        title: 'Streak 7',
        description: '7 day streak',
        icon: '🔥',
        points: 50,
        isUnlocked: true,
        unlockedAt: unlockedAt,
        progress: 10,
        targetProgress: 10,
      );
      expect(achievement.points, 50);
      expect(achievement.isUnlocked, true);
      expect(achievement.unlockedAt, unlockedAt);
      expect(achievement.progress, 10);
      expect(achievement.targetProgress, 10);
    });

    group('progressPercentage', () {
      test('returns ratio of progress to target', () {
        const achievement = Achievement(
          id: '1',
          title: 'T',
          description: 'D',
          icon: '⭐',
          progress: 5,
          targetProgress: 20,
        );
        expect(achievement.progressPercentage, 0.25);
      });

      test('clamps at 1.0', () {
        const achievement = Achievement(
          id: '1',
          title: 'T',
          description: 'D',
          icon: '⭐',
          progress: 15,
          targetProgress: 10,
        );
        expect(achievement.progressPercentage, 1.0);
      });
    });

    group('copyWith', () {
      test('creates new object with same field values when no args', () {
        const achievement = Achievement(
          id: '1',
          title: 'T',
          description: 'D',
          icon: '⭐',
          targetProgress: 10,
        );
        final copy = achievement.copyWith();
        expect(copy.id, achievement.id);
        expect(copy.title, achievement.title);
      });

      test('replaces isUnlocked', () {
        const achievement = Achievement(
          id: '1',
          title: 'T',
          description: 'D',
          icon: '⭐',
          targetProgress: 5,
        );
        final copy = achievement.copyWith(isUnlocked: true);
        expect(copy.isUnlocked, true);
      });
    });
  });
}
