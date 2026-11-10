import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/personal/family_faith/savings/savings_models.dart';

SavingsGoal _goal({
  double target = 10000000,
  DateTime? targetDate,
}) =>
    SavingsGoal(
      id: 'g1',
      title: 'سفر',
      targetAmount: target,
      targetDate: targetDate,
      createdAt: DateTime(2026, 1, 1),
    );

Deposit _deposit(String id, DateTime date, double amount) =>
    Deposit(id: id, goalId: 'g1', date: date, amount: amount);

void main() {
  final now = DateTime(2026, 9, 12);

  group('progress', () {
    test('saved is the sum, including a negative deposit', () {
      final progress = savingsProgress(
        goal: _goal(),
        deposits: [
          _deposit('a', DateTime(2026, 9, 1), 2000000),
          _deposit('b', DateTime(2026, 9, 5), 500000),
          _deposit('c', DateTime(2026, 9, 8), -300000),
        ],
        now: now,
      );
      expect(progress.saved, 2200000);
      expect(progress.remaining, 7800000);
      expect(progress.fraction, closeTo(.22, .0001));
      expect(progress.depositCount, 3);
    });

    test('an empty goal is zero and not an error', () {
      final progress =
          savingsProgress(goal: _goal(), deposits: const [], now: now);
      expect(progress.saved, 0);
      expect(progress.fraction, 0);
      expect(progress.remaining, 10000000);
      expect(progress.hasEta, isFalse);
    });

    test('a zero target never divides by zero', () {
      final progress = savingsProgress(
        goal: _goal(target: 0),
        deposits: [_deposit('a', DateTime(2026, 9, 1), 1000)],
        now: now,
      );
      expect(progress.fraction, 1);
      expect(progress.remaining, 0);
    });

    test('over-saving caps the fraction at one', () {
      final progress = savingsProgress(
        goal: _goal(target: 1000),
        deposits: [_deposit('a', DateTime(2026, 9, 1), 5000)],
        now: now,
      );
      expect(progress.fraction, 1);
      expect(progress.saved, 5000);
      expect(progress.remaining, 0);
    });
  });

  group('ETA', () {
    test('a single deposit is not enough evidence', () {
      final progress = savingsProgress(
        goal: _goal(),
        deposits: [_deposit('a', DateTime(2026, 9, 1), 1000000)],
        now: now,
      );
      expect(progress.etaDays, isNull);
      expect(progress.daysSinceFirstDeposit, 11);
    });

    test('two deposits over less than fourteen days still wait', () {
      final progress = savingsProgress(
        goal: _goal(),
        deposits: [
          _deposit('a', DateTime(2026, 9, 2), 1000000),
          _deposit('b', DateTime(2026, 9, 10), 1000000),
        ],
        now: now,
      );
      expect(progress.etaDays, isNull);
    });

    test('two deposits over fifteen days produce an ETA', () {
      final progress = savingsProgress(
        goal: _goal(),
        deposits: [
          _deposit('a', DateTime(2026, 8, 28), 1000000),
          _deposit('b', DateTime(2026, 9, 10), 1000000),
        ],
        now: now,
      );
      // 2,000,000 over 15 days ≈ 133,333/day; 8,000,000 remaining ≈ 60 days.
      expect(progress.etaDays, 60);
    });

    test('a completed goal needs no ETA', () {
      final progress = savingsProgress(
        goal: _goal(target: 1000),
        deposits: [
          _deposit('a', DateTime(2026, 8, 1), 600),
          _deposit('b', DateTime(2026, 9, 1), 600),
        ],
        now: now,
      );
      expect(progress.isComplete, isTrue);
      expect(progress.etaDays, 0);
    });

    test('the monthly average counts positive deposits only', () {
      final progress = savingsProgress(
        goal: _goal(),
        deposits: [
          _deposit('a', DateTime(2026, 8, 1), 3000000),
          _deposit('b', DateTime(2026, 9, 1), 3000000),
          _deposit('c', DateTime(2026, 9, 2), -1000000),
        ],
        now: now,
      );
      expect(progress.monthlyAverage, closeTo(2000000, 1));
    });

    test('a target date turns into a monthly requirement', () {
      final progress = savingsProgress(
        goal: _goal(target: 12000000, targetDate: DateTime(2026, 12, 12)),
        deposits: [_deposit('a', DateTime(2026, 9, 1), 2000000)],
        now: now,
      );
      expect(progress.monthsToDeadline, 3);
      expect(progress.perMonthNeeded, closeTo(3333333.33, 1));
    });

    test('a deadline in the past asks for everything at once', () {
      final progress = savingsProgress(
        goal: _goal(target: 5000000, targetDate: DateTime(2026, 8, 1)),
        deposits: const [],
        now: now,
      );
      expect(progress.monthsToDeadline, 0);
      expect(progress.perMonthNeeded, 5000000);
    });
  });

  group('milestones and withdrawals', () {
    test('each crossing is reported once, highest wins', () {
      expect(crossedMilestone(.1, .3), 25);
      expect(crossedMilestone(.6, .9), 75);
      expect(crossedMilestone(.1, 1.0), 100);
      expect(crossedMilestone(.3, .4), isNull);
      expect(crossedMilestone(.5, .5), isNull);
    });

    test('reached milestones follow the fraction', () {
      final progress = savingsProgress(
        goal: _goal(target: 4000),
        deposits: [_deposit('a', DateTime(2026, 9, 1), 2100)],
        now: now,
      );
      expect(progress.milestonesReached, [25, 50]);
    });

    test('a withdrawal can never exceed the balance', () {
      final deposits = [
        _deposit('a', DateTime(2026, 9, 1), 700000),
        _deposit('b', DateTime(2026, 9, 2), -200000),
      ];
      expect(maxWithdrawable(deposits), 500000);
      expect(maxWithdrawable(const []), 0);
    });
  });
}
