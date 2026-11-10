import 'package:drift/drift.dart';

/// A group of people sharing expenses (دنگی).
class DangiGroupTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Accent color as hex (e.g. `#00ACC1`).
  TextColumn get colorHex => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
