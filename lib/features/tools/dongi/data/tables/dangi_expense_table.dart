import 'package:drift/drift.dart';

/// An expense in a dangi (bill-split) group. One member pays; the amount is
/// split equally among all members of the group (or per-consumer when
/// [consumersJson] lists each member's own consumed amount).
class DangiExpenseTable extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text()();
  TextColumn get payerId => text()();
  TextColumn get title => text()();
  TextColumn get category => text().withDefault(const Constant('other'))();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  /// JSON of the per-member consumer amounts (memberId → consumed amount).
  /// An empty map / `{}` keeps the legacy equal split among all members.
  /// Stored as a real column (instead of a SharedPreferences side-store) so
  /// the data survives backup/restore and is always applied on load.
  TextColumn get consumersJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}
