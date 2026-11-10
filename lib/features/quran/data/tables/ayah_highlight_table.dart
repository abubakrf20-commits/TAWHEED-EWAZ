import 'package:drift/drift.dart';

/// Permanent colored highlight on a whole ayah of the Mushaf (Audit 8.12:
/// previously bookmarks existed but nothing persisted a *color* the reader
/// could see on the page). One row per highlighted ayah; re-highlighting
/// replaces the color (unique index on surah+ayah).
class AyahHighlightTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get surah => integer()();
  IntColumn get ayah => integer()();

  /// Highlight fill color as `#RRGGBB` (hex string — stays readable in
  /// backups and diffs; alpha is fixed at draw time).
  TextColumn get colorHex => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {surah, ayah}
      ];
}
