/// مهاجرت یک‌بارهٔ ایندکس صفحه‌ها پس از بازلایه‌بندی کتاب‌ها.
///
/// پیش‌تر هر `(N/M)` — حتی شماره‌ای که در پانوشت آمده بود — صفحه‌ای جدا
/// می‌ساخت. پالایشِ آن نشانگرهای ساختگی صفحه‌ها را جابه‌جا می‌کند، و
/// ایندکس صفحه چیزی است که در دستگاه ذخیره شده: پیشرفت مطالعه، نشانک‌ها و
/// هایلایت‌ها. شمارهٔ صفحهٔ چاپی تنها لنگر پایدار میان دو چیدمان است.
library;

import 'package:tawheeed/features/books/services/book_pagination.dart';

abstract final class BookPageMigration {
  const BookPageMigration._();

  /// پرچم «این کتاب یک‌بار مهاجرت شده است».
  static String flagKey(String bookId) => 'books_reanchor_v2_$bookId';

  /// نگاشت ایندکس قدیم → ایندکس نو.
  ///
  /// صفحهٔ پیش‌گفتار (بدون شمارهٔ چاپی) به صفحهٔ نخست می‌رود، و صفحه‌ای که
  /// شماره‌اش در چیدمان تازه پیدا نشود از نگاشت بیرون می‌ماند تا فراخوان
  /// خودش تصمیم بگیرد — حدس زدن صفحهٔ دیگر بدتر از نگاه‌داشتن ایندکس است.
  static Map<int, int> remap({
    required List<int?> legacyPrintNos,
    required List<BookPage> pages,
  }) {
    final byPrint = <int, int>{};
    for (var i = 0; i < pages.length; i++) {
      final printNo = pages[i].printNo;
      if (printNo != null) byPrint.putIfAbsent(printNo, () => i);
    }
    final out = <int, int>{};
    for (var old = 0; old < legacyPrintNos.length; old++) {
      final printNo = legacyPrintNos[old];
      if (printNo == null) {
        out[old] = 0;
        continue;
      }
      final fresh = byPrint[printNo];
      if (fresh != null) out[old] = fresh;
    }
    return out;
  }
}
