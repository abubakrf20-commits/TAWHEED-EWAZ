import 'package:drift/drift.dart';

/// حدیث موردعلاقهٔ کاربر، ذخیره‌شده در المفضلة (آفلاین).
///
/// [id] شناسهٔ پایدار حدیث از درر است (hadithId واقعی یا بصمت متن+منبع)؛
/// کلید اصلی همان است تا «حفظ دوباره» یک حدیث، رکورد را تکراری نسازد.
class FavoriteDorarHadithTable extends Table {
  TextColumn get id => text()();
  TextColumn get hadithText => text()();
  TextColumn get narrator => text().nullable()();
  TextColumn get mohdith => text().nullable()();
  TextColumn get book => text().nullable()();
  TextColumn get hadithNumber => text().nullable()();
  TextColumn get degree => text().nullable()();
  DateTimeColumn get savedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
