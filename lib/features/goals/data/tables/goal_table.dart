import 'package:drift/drift.dart';

/// یک هدف (مثلاً «حفظ 30 جزء») با بازهٔ زمانی و مقیاس سنجش.
///
/// ایندکس روی (is_archived, is_active) چون هر دو فیلترِ اصلی فهرست
/// هستند: فهرست «فعال و غیربایگانی» و شیت «بایگانی» — هر دو مستقیم
/// روی همین جفت فیلتر می‌شوند و بدون ایندکس اسکن کامل می‌شدند.
///
/// ایندکس دوم برای «اولویت» است: مرتب‌سازی پیش‌فرض فهرست روی همین
/// ستون است و هر باز-کردن فهرست دوباره همان ترتیب را می‌خواهد.
@TableIndex(
    name: 'idx_goal_table_archived_active', columns: {#isArchived, #isActive})
@TableIndex(
    name: 'idx_goal_table_priority',
    columns: {#isArchived, #isActive, #priority})
class GoalTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();

  TextColumn get description => text().withDefault(const Constant(''))();

  /// دسته‌بندی: hifz / quran / prayer / study / ibadat / health / other
  TextColumn get category => text().withDefault(const Constant('other'))();

  TextColumn get startDate => text().withDefault(const Constant(''))();

  /// سررسید/تاریخ پایان هدف؛ خالی = هدف باز (بدون مهلت).
  TextColumn get deadline => text().withDefault(const Constant(''))();

  /// مقیاس هدف:
  ///  count   → شمارشی (تعداد جزء/روز/صفحه) در [targetNumber].
  ///  minutes → زمانی (دقیقه مطالعه) در [targetNumber].
  ///  boolean → انجام/نشد (بدون عدد).
  TextColumn get targetType => text().withDefault(const Constant('count'))();

  IntColumn get targetNumber => integer().withDefault(const Constant(0))();

  /// هدفِ روزانه: چقدر باید در هر روز ثبت شود تا به مهلت برسد.
  ///
  /// ۰ یعنی کاربر ترجیح داده این را تعیین نکند — و آن‌وقت نرخ لازم از
  /// «باقی‌مانده تا مهلت ÷ روزهای باقی‌مانده» حساب می‌شود. این دو را یکی
  /// نکردیم چون «هدف روزانه» یک تصمیم آگاهانهٔ کاربر است و نرخ لازم یک
  /// محاسبه؛ نمایش دادنِ عدد دوم به‌جای عدد اول انتخابِ کاربر را عوض می‌کند.
  IntColumn get dailyTarget => integer().withDefault(const Constant(0))();

  /// اولویت: ۰ کم، ۱ متوسط (پیش‌فرض)، ۲ زیاد.
  IntColumn get priority => integer().withDefault(const Constant(1))();

  /// یادآوری روزانه. ساعتش در [remindAt] به‌صورت `HH:mm` می‌آید.
  ///
  /// روزانه است نه یک‌باره: «مطالعهٔ روزانه» با یادآوریِ سررسید معنا ندارد.
  BoolColumn get remindEnabled =>
      boolean().withDefault(const Constant(false))();

  TextColumn get remindAt => text().withDefault(const Constant(''))();

  /// پیوند اختیاری به منبع دیگر — `notes` / `hifz` / `khatm` — و شناسهٔ
  /// آن. خالی یعنی بی‌پیوند.
  ///
  /// فعلاً فقط خواندنی است: صفحهٔ هدف پیشرفتِ منبع را نشان می‌دهد ولی چیزی
  /// به آن برنمی‌گرداند. نوشتنِ برعکس (مثلاً «ثبت ۱ جزء» که خودکار در حفظ
  /// هم بنویسد) تصمیمی جداگانه است و باید از خودِ کاربر بیاید.
  TextColumn get linkedType => text().withDefault(const Constant(''))();
  TextColumn get linkedId => text().withDefault(const Constant(''))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
