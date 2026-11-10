import 'package:drift/drift.dart';

class ReminderTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get note => text()();
  IntColumn get hour => integer()();
  IntColumn get minute => integer()();
  TextColumn get daysOfWeek => text()();
  BoolColumn get isEnabled => boolean()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get advanceMinutes => integer()();
  BoolColumn get useSound => boolean()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  TextColumn get soundName => text()();
  DateTimeColumn get specificDate => dateTime().nullable()();
  TextColumn get prayerRef => text().nullable()();
  IntColumn get prayerOffsetMinutes =>
      integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
