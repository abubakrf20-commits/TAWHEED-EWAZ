import 'package:drift/drift.dart';

class BookBookmarkTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text()();
  IntColumn get page => integer()();
  TextColumn get note => text().nullable()();
  TextColumn get highlightColor => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}
