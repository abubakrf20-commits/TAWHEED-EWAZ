import 'package:drift/drift.dart';

@TableIndex(name: 'idx_zikr_status_date', columns: {#date})
class ZikrStatusRecordTable extends Table {
  TextColumn get id => text()();
  IntColumn get statusIndex => integer()();
  TextColumn get date => text()();

  @override
  Set<Column> get primaryKey => {id, date};
}
