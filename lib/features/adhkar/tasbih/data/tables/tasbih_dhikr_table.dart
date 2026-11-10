import 'package:drift/drift.dart';

class TasbihDhikrTable extends Table {
  TextColumn get id => text()();
  TextColumn get tasbihId => text()();
  TextColumn get dhikrText => text()();

  @override
  Set<Column> get primaryKey => {id};
}
