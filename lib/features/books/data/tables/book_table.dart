import 'package:drift/drift.dart';

class BookTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get author => text()();
  TextColumn get category => text()();
  TextColumn get filePath => text()();
  IntColumn get fileSize => integer()();
  IntColumn get pageCount => integer()();
  DateTimeColumn get dateAdded => dateTime()();
  DateTimeColumn get lastRead => dateTime().nullable()();
  IntColumn get currentPage => integer()();
  BoolColumn get isFavorite => boolean()();
  RealColumn get readProgress => real()();
  TextColumn get language => text()();
  TextColumn get tags => text()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
