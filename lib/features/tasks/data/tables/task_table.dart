import 'package:drift/drift.dart';

@TableIndex(name: 'idx_tasks_due_date', columns: {#dueDate})
class TasksTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  TextColumn get recurringType => text().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  // One-shot «یادآوری روز سررسید»: enabled flag + local time as "HH:mm".
  BoolColumn get remindEnabled =>
      boolean().withDefault(const Constant(false))();
  TextColumn get remindAt => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  // Stored as a comma-joined string to mirror the legacy raw schema.
  TextColumn get tags => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}
