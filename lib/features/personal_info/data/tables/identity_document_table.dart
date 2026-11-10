import 'package:drift/drift.dart';

/// یک مدرک هویتی/سند متصل به یک پروفایل (کد ملی، شناسنامه، پاسپورت،
/// کارت ملی، گواهی‌نامه و غیره) با امکان افزودن عکس/فایل.
class IdentityDocumentTable extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text()();

  /// نوع سند ثابت: national_id / birth_cert / passport / card / other
  TextColumn get docType => text().withDefault(const Constant('other'))();

  TextColumn get title => text()();

  /// شماره/سریال سند — رمزشده (پیشوند `enc:`).
  TextColumn get documentNo => text().withDefault(const Constant(''))();

  TextColumn get issuedPlace => text().withDefault(const Constant(''))();
  TextColumn get issuedDate => text().withDefault(const Constant(''))();

  /// تاریخ انقضا (ISO yyyy-mm-dd)؛ خالی = بدون انقضا.
  TextColumn get expiryDate => text().withDefault(const Constant(''))();

  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Absolute path(s) to document photos, JSON array of paths, '' = none.
  TextColumn get imagesJson => text().withDefault(const Constant(''))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [];
}
