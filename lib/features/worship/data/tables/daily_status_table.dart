import 'package:drift/drift.dart';

class DailyStatusTable extends Table {
  TextColumn get category => text()();
  TextColumn get date => text()();
  TextColumn get key => text()();
  IntColumn get value => integer()();

  @override
  Set<Column> get primaryKey => {category, date, key};
}
