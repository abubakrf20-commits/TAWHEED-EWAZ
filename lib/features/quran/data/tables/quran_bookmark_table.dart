import 'package:drift/drift.dart';

class QuranBookmarkTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get surah => integer()();
  IntColumn get ayah => integer()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
