import 'package:drift/drift.dart';

/// A person being tracked for Quran memorization (حافظ).
class HafizTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Avatar color as a hex string (e.g. `#1976D2`).
  TextColumn get colorHex => text()();

  /// Sabaq window in days: recent memorization reviewed as سَبَق (default 7).
  IntColumn get sabaqWindowDays => integer().withDefault(const Constant(7))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
