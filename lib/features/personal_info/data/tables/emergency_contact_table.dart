import 'package:drift/drift.dart';

/// تماس اضطراری — موردی که در لحظهٔ نیاز در دسترس باشد.
class EmergencyContactTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get relation => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
