import 'package:drift/drift.dart';
import 'package:tawheeed/features/goals/data/tables/goal_table.dart';

/// یک ثبت پیشرفت در یک هدف — هر ردیف یک «+مقدار» در روزِ [date].
///
/// کلید خارجی با [KeyAction.cascade] به [GoalTable]: حذف یک هدف حالا
/// در سطح دیتابیس ثبت‌هایش را هم می‌برد. پیش از این، پاک‌سازی دستی و
/// تراکنشی در لایهٔ repository بود و هر راه دیگری (از جمله پارامتر
/// عمومی `deleteProgress: false` یا قطعه‌شدن میان دو DELETE) ردیف‌های
/// یتیمی می‌ساخت که هیچ‌وقت پاک نمی‌شدند و همچنان در مجموع اهدافِ
/// ناموجود شمرده می‌شدند. `PRAGMA foreign_keys` از قبل در
/// `app_database.dart` روشن است، ولی تا پیش از این هیچ جدولی در
/// کل برنامه کلید خارجی اعلام نکرده بود.
///
/// ایندکس مرکب (goal_id, date) دو کوئری داغ را پوشش می‌دهد:
/// `SUM(amount) WHERE goal_id = ?` و جمع یک روزِ مشخص. پیش از آن
/// هر دو یک اسکن کامل جدول بودند، و چون هر کارت فهرست مجموع هدف خودش
/// را می‌پرسید، رندر N هدف N اسکن کامل جدول انجام می‌داد.
@TableIndex(
  name: 'idx_goal_progress_goal_date',
  columns: {#goalId, #date},
)
class GoalProgressTable extends Table {
  TextColumn get id => text()();
  TextColumn get goalId =>
      text().references(GoalTable, #id, onDelete: KeyAction.cascade)();

  /// روز ثبت (ISO yyyy-mm-dd). ذخیره‌سازی میلادی و صفرپرشده است، چون
  /// همین قالب کلیدِ مرتب‌سازیِ رشته‌ایِ `getProgress` است؛ نمایش شمسی
  /// در لایهٔ presentation انجام می‌شود.
  TextColumn get date => text()();

  /// مقدار اضافه‌شده در این ثبت (برای count/minutes).
  IntColumn get amount => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
