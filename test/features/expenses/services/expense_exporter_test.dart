import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/expenses/domain/entities/expense_model.dart';
import 'package:tawheeed/features/expenses/services/expense_exporter.dart';

void main() {
  group('ExpenseExporter.buildCsv', () {
    test('emits a UTF-8 BOM and a header row', () {
      final csv = ExpenseExporter.buildCsv([]);
      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(csv.contains('تاریخ,نوع,عنوان,دسته,مبلغ,توضیحات'), isTrue);
    });

    test('rows sort newest first with Jalali dates and plain amounts', () {
      final csv = ExpenseExporter.buildCsv(
        [
          ExpenseModel(
              id: '1',
              title: 'قدیمی',
              amount: 100,
              category: 'عمومی',
              date: DateTime(2026)),
          ExpenseModel(
              id: '2',
              title: 'جدید',
              amount: 250,
              isIncome: true,
              date: DateTime(2026, 9, 4)),
        ],
      );
      final lines = csv.trimRight().split('\n');
      expect(lines.length, 3);
      // Newest (income) row first.
      expect(lines[1].contains('جدید'), isTrue);
      expect(lines[1].contains('درآمد'), isTrue);
      expect(lines[1].contains('250'), isTrue);
      expect(lines[2].contains('قدیمی'), isTrue);
      expect(lines[2].contains('هزینه'), isTrue);
      // Jalali date present (13/6/1405 for 2026-09-04).
      expect(lines[1].startsWith('1405/06/13'), isTrue);
    });

    test('quotes fields that contain commas', () {
      final csv = ExpenseExporter.buildCsv(
        [
          ExpenseModel(
              id: '1',
              title: 'خرید، نان و شیر',
              amount: 50,
              date: DateTime(2026, 9, 4)),
        ],
      );
      expect(csv.contains('"خرید، نان و شیر"'), isTrue);
    });

    test('escapes embedded double quotes', () {
      final csv = ExpenseExporter.buildCsv(
        [
          ExpenseModel(
              id: '1',
              title: 'گفت "سلام"',
              amount: 50,
              date: DateTime(2026, 9, 4)),
        ],
      );
      expect(csv.contains('"گفت ""سلام"""'), isTrue);
    });
  });
}
