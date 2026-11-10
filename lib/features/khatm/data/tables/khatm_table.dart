import 'package:drift/drift.dart';

class KhatmTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  IntColumn get targetDays => integer()();
  TextColumn get pagesRead => text()();

  /// JSON map of 'YYYY-MM-DD' → pages read that day (for today's progress).
  ///
  /// Nullable on purpose: drift's `text()()` is NOT NULL and SQLite cannot
  /// add a NOT NULL column without a default to a table that already has
  /// rows — making this NOT NULL caused the schema-15→16 migration to throw
  /// "Cannot add a NOT NULL column with default value NULL" on every device
  /// with khatm data, which previously wiped the whole database.
  TextColumn get dailyRead => text().nullable()();
  BoolColumn get isCompleted => boolean()();
  TextColumn get participantNames => text()();
  TextColumn get participantAssignedJuzs => text()();

  @override
  Set<Column> get primaryKey => {id};
}
