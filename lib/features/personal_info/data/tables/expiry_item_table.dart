import 'package:drift/drift.dart';

/// تاریخ انقضا / ددلاین (قسط، گواهی‌نامه، ویزا، مرور بیمه، چک و...) با
/// شمارش معکوس و امکان یادآوری محلی چند روز قبل.
class ExpiryItemTable extends Table {
  TextColumn get id => text()();

  /// expiry_warning / installment / visa / certificate / other
  TextColumn get category => text().withDefault(const Constant('other'))();

  TextColumn get title => text()();

  /// تاریخ مبدأ (اختیاری، مثلاً تاریخ شروع قسط).
  TextColumn get startDate => text().withDefault(const Constant(''))();

  /// تاریخ سررسید (قطعاً موجود).
  TextColumn get dueDate => text()();

  TextColumn get notes => text().withDefault(const Constant(''))();

  /// آیا یادآوری محلی فعال است؟
  BoolColumn get remindEnabled =>
      boolean().withDefault(const Constant(false))();

  /// چند روز قبل از سررسید اطلاع‌رسانی شود (نمایش عدد؛ یادآوری یک‌باره در
  /// آن روز). 0 = فقط در روز سررسید.
  IntColumn get remindDaysBefore => integer().withDefault(const Constant(0))();

  /// ISO تاریخ آخرین یادآوری‌شده — برای جلوگیری از تکرار یادآوری.
  TextColumn get lastRemindedDate => text().withDefault(const Constant(''))();

  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
