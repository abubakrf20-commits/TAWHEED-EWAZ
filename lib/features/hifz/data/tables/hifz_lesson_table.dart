import 'package:drift/drift.dart';

/// Daily NEW memorization the student delivers (حفظ جدید).
/// Progress = sum of `pages` over all lessons / 604.
class HifzLessonTable extends Table {
  TextColumn get id => text()();
  TextColumn get hafizId => text()();
  DateTimeColumn get date => dateTime()();
  IntColumn get surahFrom => integer()();
  IntColumn get ayahFrom => integer()();
  IntColumn get surahTo => integer()();
  IntColumn get ayahTo => integer()();
  IntColumn get pages => integer()();
  TextColumn get quality => text().withDefault(const Constant('excellent'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
