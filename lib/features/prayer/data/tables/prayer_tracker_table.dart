import 'package:drift/drift.dart';

class PrayerTrackerTable extends Table {
  TextColumn get date => text()();
  TextColumn get prayerKey => text()();
  IntColumn get value => integer().nullable()();

  @override
  Set<Column> get primaryKey => {date, prayerKey};
}
