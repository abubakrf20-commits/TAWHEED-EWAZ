import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/dongi/domain/dangi_categories.dart';
import 'package:tawheeed/features/tools/dongi/domain/dangi_report.dart';
import 'package:tawheeed/features/tools/dongi/domain/entities/dangi_models.dart';

DangiExpenseModel _expense({
  required String id,
  required String category,
  required double amount,
  required DateTime date,
}) =>
    DangiExpenseModel(
      id: id,
      groupId: 'g1',
      payerId: 'm1',
      title: 'هزینهٔ $id',
      category: category,
      amount: amount,
      date: date,
      createdAt: date,
    );

void main() {
  group('buildDangiExpenseReport', () {
    test('empty expenses produce an empty report', () {
      final r = buildDangiExpenseReport(const []);
      expect(r.count, 0);
      expect(r.total, 0);
      expect(r.byDate, isEmpty);
      expect(r.byCategory, isEmpty);
    });

    test('groups expenses by day, newest first, with subtotals', () {
      final r = buildDangiExpenseReport([
        _expense(
            id: 'a',
            category: 'food',
            amount: 100,
            date: DateTime(2025, 1, 5, 10)),
        _expense(
            id: 'b',
            category: 'food',
            amount: 50,
            date: DateTime(2025, 1, 5, 18)),
        _expense(
            id: 'c',
            category: 'transport',
            amount: 200,
            date: DateTime(2025, 1, 3, 9)),
      ]);

      expect(r.count, 3);
      expect(r.total, 350);
      expect(r.byDate, hasLength(2));
      // Newest day first.
      expect(r.byDate[0].date, DateTime(2025, 1, 5));
      expect(r.byDate[0].subtotal, 150);
      expect(r.byDate[0].expenses, hasLength(2));
      // Within a day, newest expense first.
      expect(r.byDate[0].expenses.first.id, 'b');
      expect(r.byDate[1].date, DateTime(2025, 1, 3));
      expect(r.byDate[1].subtotal, 200);
    });

    test('groups by category, biggest total first, unknown falls back', () {
      final r = buildDangiExpenseReport([
        _expense(
            id: 'a', category: 'food', amount: 100, date: DateTime(2025, 1, 5)),
        _expense(
            id: 'b', category: 'food', amount: 200, date: DateTime(2025, 1, 6)),
        _expense(
            id: 'c',
            category: 'transport',
            amount: 50,
            date: DateTime(2025, 1, 7)),
        _expense(
            id: 'd',
            category: 'legacy-unknown',
            amount: 30,
            date: DateTime(2025, 1, 8)),
      ]);

      expect(r.byCategory, hasLength(3));
      // Sorted by total desc.
      expect(r.byCategory[0].category, DangiExpenseCategory.food);
      expect(r.byCategory[0].total, 300);
      expect(r.byCategory[0].expenses, hasLength(2));
      expect(r.byCategory[1].category, DangiExpenseCategory.transport);
      expect(r.byCategory[1].total, 50);
      // Unknown id maps to 'other'.
      expect(r.byCategory[2].category, DangiExpenseCategory.other);
      expect(r.byCategory[2].total, 30);
      expect(r.maxCategoryTotal, 300);
    });

    test('category total share scales with maxCategoryTotal', () {
      final r = buildDangiExpenseReport([
        _expense(
            id: 'a',
            category: 'lodging',
            amount: 400,
            date: DateTime(2025, 1, 5)),
        _expense(
            id: 'b', category: 'fun', amount: 100, date: DateTime(2025, 1, 6)),
      ]);
      expect(r.byCategory[0].category, DangiExpenseCategory.lodging);
      expect(r.maxCategoryTotal, 400);
      expect(r.byCategory[1].total / r.maxCategoryTotal, 0.25);
    });
  });

  group('DangiExpenseCategory', () {
    test('fromId resolves known ids and falls back to other', () {
      expect(DangiExpenseCategory.fromId('food'), DangiExpenseCategory.food);
      expect(DangiExpenseCategory.fromId('shopping'),
          DangiExpenseCategory.shopping);
      expect(DangiExpenseCategory.fromId('nope'), DangiExpenseCategory.other);
    });

    test('every category has a Persian label', () {
      for (final c in DangiExpenseCategory.values) {
        expect(c.label, isNotEmpty);
        expect(c.id, isNotEmpty);
      }
    });
  });

  group('date labels', () {
    test('dangiDateLabel formats Jalali date with English digits', () {
      // 2025-01-05 is 16 دی 1403.
      final label = dangiDateLabel(DateTime(2025, 1, 5));
      expect(label, contains('دی'));
      expect(label, contains('1403'));
      expect(label, contains('16'));
    });

    test('weekday label includes the day name', () {
      // 2025-01-05 is a Sunday (yek-shanbeh).
      final label = dangiDateLabelWithWeekday(DateTime(2025, 1, 5));
      expect(label, contains('یکشنبه'));
      expect(label, contains('،'));
    });
  });

  group('faMoney', () {
    test('formats integers with English digits and thousand separators', () {
      expect(faMoney(450000), '450,000');
      expect(faMoney(0), '0');
      expect(faMoney(1234), '1,234');
      expect(faMoney(1000000), '1,000,000');
    });

    test('keeps two decimals when present', () {
      expect(faMoney(1234.5), '1,234.50');
      expect(faMoney(333.333), '333.33');
    });
  });
}
