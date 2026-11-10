import 'package:drift/drift.dart';

class TasbihTable extends Table {
  TextColumn get id => text()();
  TextColumn get dhikrText => text()();
  IntColumn get count => integer()();
  IntColumn get target => integer()();
  IntColumn get totalLifetimeCount =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}
