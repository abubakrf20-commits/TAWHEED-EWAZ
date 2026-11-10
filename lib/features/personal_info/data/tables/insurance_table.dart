import 'package:drift/drift.dart';

/// یک بیمه‌نامه (بیمه، تکمیلی، عمر...) با تاریخ اعتبار.
class InsuranceTable extends Table {
  TextColumn get id => text()();

  TextColumn get title => text()();

  TextColumn get provider => text().withDefault(const Constant(''))();

  /// شماره بیمه‌نامه — رمزشده.
  TextColumn get policyNo => text().withDefault(const Constant(''))();

  TextColumn get startDate => text().withDefault(const Constant(''))();

  /// تاریخ پایان اعتبار؛ خالی = بدون انقضا.
  TextColumn get expiryDate => text().withDefault(const Constant(''))();

  /// Absolute attachment paths, JSON array, '' = none.
  TextColumn get attachmentsJson => text().withDefault(const Constant(''))();

  TextColumn get notes => text().withDefault(const Constant(''))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
