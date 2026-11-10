import 'package:drift/drift.dart';

@TableIndex(name: 'idx_notes_updated_at', columns: {#updatedAt})
@TableIndex(name: 'idx_notes_pinned', columns: {#isPinned})
class NoteTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get tags => text()();
  // Note folder («پوشه‌های یادداشت»): a lightweight grouping string, '' = no
  // folder, kept in the same spirit as tags (plain text, comma-free).
  TextColumn get folder => text().withDefault(const Constant(''))();
  BoolColumn get isDone => boolean()();
  IntColumn get colorIndex => integer()();
  BoolColumn get isPinned => boolean()();

  /// Voice-note attachment: absolute file path ('' = none) and its duration
  /// in milliseconds (0 = no audio). Kept separate from [content] so a note
  /// can be audio-only, text-only, or both. The file lives under the app's
  /// private docs dir (see voice-notes storage) and is cleaned up on delete.
  TextColumn get audioPath => text().withDefault(const Constant(''))();
  IntColumn get audioDurationMs => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
