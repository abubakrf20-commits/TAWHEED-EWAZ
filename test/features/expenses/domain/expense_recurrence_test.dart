import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/expenses/domain/expense_recurrence.dart';

void main() {
  group('ExpenseRecurrence.next', () {
    test('daily adds one day', () {
      expect(
        ExpenseRecurrence.next(DateTime(2026, 9, 4), 'daily'),
        DateTime(2026, 9, 5),
      );
    });

    test('weekly adds seven days', () {
      expect(
        ExpenseRecurrence.next(DateTime(2026, 9, 4), 'weekly'),
        DateTime(2026, 9, 11),
      );
    });

    test('monthly keeps the day of month', () {
      expect(
        ExpenseRecurrence.next(DateTime(2026, 9, 4), 'monthly'),
        DateTime(2026, 10, 4),
      );
    });

    test('monthly clamps to the target month length (Jan 31)', () {
      expect(
        ExpenseRecurrence.next(DateTime(2026, 1, 31), 'monthly'),
        DateTime(2026, 2, 28),
      );
      // And continues from the clamped anchor: Feb 28 → Mar 28.
      expect(
        ExpenseRecurrence.next(DateTime(2026, 2, 28), 'monthly'),
        DateTime(2026, 3, 28),
      );
    });

    test('monthly handles leap February', () {
      expect(
        ExpenseRecurrence.next(DateTime(2024, 1, 31), 'monthly'),
        DateTime(2024, 2, 29),
      );
    });

    test('label maps patterns to Persian', () {
      expect(ExpenseRecurrence.label('daily'), 'روزانه');
      expect(ExpenseRecurrence.label('weekly'), 'هفتگی');
      expect(ExpenseRecurrence.label('monthly'), 'ماهانه');
      expect(ExpenseRecurrence.label(null), isNull);
      expect(ExpenseRecurrence.label('yearly'), isNull);
    });

    test('isSupported accepts the three patterns only', () {
      expect(ExpenseRecurrence.isSupported('daily'), isTrue);
      expect(ExpenseRecurrence.isSupported('weekly'), isTrue);
      expect(ExpenseRecurrence.isSupported('monthly'), isTrue);
      expect(ExpenseRecurrence.isSupported('yearly'), isFalse);
      expect(ExpenseRecurrence.isSupported(null), isFalse);
    });
  });
}
