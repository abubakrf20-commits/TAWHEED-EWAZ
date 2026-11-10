import 'package:drift/drift.dart';

class PeriodRecordTable extends Table {
  IntColumn get id => integer()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  IntColumn get periodLength => integer()();
  DateTimeColumn get createdAt => dateTime()();

  /// نوع رکورد: hayz (حیض) | nifas (نفاس) | istihadha (استحاضه).
  /// NULL یعنی رکورد قدیمی و به‌عنوان حیض در نظر گرفته می‌شود.
  TextColumn get recordType => text().nullable()();

  /// شدت خونریزی برای نمودار/گزارش: light | medium | heavy
  TextColumn get flow => text().nullable()();

  /// نوع استحاضه: qalila | mutawassita | kathira
  TextColumn get istihadhaType => text().nullable()();

  TextColumn get symptoms => text().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
