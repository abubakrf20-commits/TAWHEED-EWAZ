import 'package:drift/drift.dart';

/// رمزها، کارت‌ها، حساب‌های بانکی و شبکه‌های اجتماعی.
/// فیلدهای حساس (username/password/extra) AES-GCM رمز می‌شوند؛
/// فقط title و category و notes متن‌ساده‌اند.
class CredentialTable extends Table {
  TextColumn get id => text()();

  /// دسته‌بندی: password / card / bank / social / email / other
  TextColumn get category => text().withDefault(const Constant('password'))();

  TextColumn get title => text()();

  /// نام کاربری/شماره/ایمیل — رمزشده.
  TextColumn get username => text().withDefault(const Constant(''))();

  /// رمز/پین/PIN کارت — رمزشده.
  TextColumn get password => text().withDefault(const Constant(''))();

  /// دیتای تکمیلی JSON (شماره کارت، CVV2، انقضا، شماره شبا، شماره حساب...)
  /// — رمزشده.
  TextColumn get extraJson => text().withDefault(const Constant(''))();

  TextColumn get notes => text().withDefault(const Constant(''))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
