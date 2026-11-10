import 'package:drift/drift.dart';

class DuaTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get arabicText => text()();
  TextColumn get transliteration => text().nullable()();
  TextColumn get translation => text()();
  TextColumn get reference => text().nullable()();
  TextColumn get category => text()();
  BoolColumn get isFavorite => boolean()();

  @override
  Set<Column> get primaryKey => {id};
}
