import 'package:drift/drift.dart';

class ExpenseTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  RealColumn get amount => real()();
  BoolColumn get isIncome => boolean().withDefault(const Constant(false))();
  TextColumn get category => text().withDefault(const Constant('عام'))();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  // Recurring entries («ورودی‌های تکراری»): the source row carries the pattern
  // and the next date that still needs a materialized copy. Generated copies
  // are plain rows (isRecurring = false).
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  TextColumn get recurringType => text().nullable()();
  DateTimeColumn get nextDueDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-category monthly budget («محدودیت بودجه برای هر دسته»).
class ExpenseBudgetTable extends Table {
  TextColumn get category => text()();
  RealColumn get monthlyLimit => real()();

  @override
  Set<Column> get primaryKey => {category};
}
