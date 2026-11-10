import 'package:drift/drift.dart';

/// خودرو، ملک/خانه و سایر دارایی‌های ثبت‌شده.
/// شناسه/پلاک/سند ملک حساس است — رمزشده نگهداری می‌شود.
class AssetTable extends Table {
  TextColumn get id => text()();

  /// car / house / property / other
  TextColumn get category => text().withDefault(const Constant('other'))();

  TextColumn get title => text()();

  TextColumn get details => text().withDefault(const Constant(''))();

  /// کد/سریال/شماره پلاک — رمزشده.
  TextColumn get registrationNo => text().withDefault(const Constant(''))();

  /// Absolute attachment paths, JSON array of paths, '' = none.
  TextColumn get attachmentsJson => text().withDefault(const Constant(''))();

  TextColumn get notes => text().withDefault(const Constant(''))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
