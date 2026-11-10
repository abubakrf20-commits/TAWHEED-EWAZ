import 'package:drift/drift.dart';

class AudioDownloadTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get surah => integer()();
  IntColumn get verse => integer()();
  TextColumn get reciterKey => text()();
  TextColumn get reciterName => text()();
  TextColumn get filePath => text()();
  IntColumn get fileSize => integer()();
  DateTimeColumn get downloadedAt => dateTime()();
}
