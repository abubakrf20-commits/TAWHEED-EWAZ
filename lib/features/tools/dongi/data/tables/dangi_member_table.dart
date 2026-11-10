import 'package:drift/drift.dart';

/// A member of a dangi (bill-split) group.
class DangiMemberTable extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
