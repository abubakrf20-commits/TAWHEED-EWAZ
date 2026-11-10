import 'package:drift/drift.dart';

/// یک فرد (معمولاً خود کاربر یا یکی از اعضای خانواده) در بخش «اطلاعات من».
/// فیلدهای حساس هویتی (کد ملی، شماره پاسپورت...) به‌صورت AES-GCM رمز می‌شوند
/// و پیشوند `enc:` دارند — جستجو/لیست‌بندی روی آن‌ها انجام نمی‌شود.
class PersonalProfileTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// نسبت/نقش (مثلاً «خودم»، «همسر»، «پدر»). برای برچسب و لیست، حساس نیست.
  TextColumn get relation => text().withDefault(const Constant(''))();

  /// تاریخ تولد میلادی (ISO) یا شمسی — خالی معنا ندارد.
  TextColumn get birthDate => text().withDefault(const Constant(''))();

  /// کد ملی — مقدار رمزشده (پیشوند `enc:`).
  TextColumn get nationalId => text().withDefault(const Constant(''))();

  /// شماره شناسنامه — رمزشده.
  TextColumn get birthCertNo => text().withDefault(const Constant(''))();

  /// شماره پاسپورت — رمزشده.
  TextColumn get passportNo => text().withDefault(const Constant(''))();

  /// شماره همراه، تلفن ثابت، آدرس — عمومی (حساس‌ترین‌شان شماره است و در
  /// ستون‌های امنیتی ویژه نگهداری می‌شود؛ این‌ها برای نمایش معمولی‌اند).
  TextColumn get phone => text().withDefault(const Constant(''))();
  TextColumn get address => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Avatar color as hex (e.g. `#1976D2`).
  TextColumn get colorHex => text().withDefault(const Constant(''))();

  /// Absolute path to the profile photo ('' = none).
  TextColumn get avatarPath => text().withDefault(const Constant(''))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
