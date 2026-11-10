import 'package:drift/drift.dart';

/// A review session: سَبَق (recent memorization within the window) or
/// مُراجَعَه (distant memorization), each rated weak/medium/excellent.
class HifzReviewTable extends Table {
  TextColumn get id => text()();
  TextColumn get hafizId => text()();
  DateTimeColumn get date => dateTime()();

  /// 'sabaq' | 'murajaah'
  TextColumn get type => text()();
  IntColumn get surahFrom => integer()();
  IntColumn get ayahFrom => integer()();
  IntColumn get surahTo => integer()();
  IntColumn get ayahTo => integer()();
  IntColumn get pages => integer()();

  /// 'weak' | 'medium' | 'excellent'
  TextColumn get quality => text()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
