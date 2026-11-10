import 'package:drift/drift.dart';

/// یک جلسهٔ تمرکز تکمیل‌شده (پومودور کلاسیک یا شمارش معکوس).
class PomodoroSessionTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startedAt => dateTime()();
  IntColumn get durationMinutes => integer()();
  TextColumn get mode => text()(); // classic | countdown
  TextColumn get focusType => text()(); // قرآن | حدیث | مطالعه | کار | عمومی
}
