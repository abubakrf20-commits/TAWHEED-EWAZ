import 'package:drift/drift.dart';

class CalculatorRecordTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get expression => text()();
  TextColumn get result => text()();
  DateTimeColumn get timestamp => dateTime()();
  BoolColumn get isScientific => boolean().withDefault(const Constant(false))();
}
