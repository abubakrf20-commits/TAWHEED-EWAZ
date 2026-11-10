import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';

final bookBookmarkDaoProvider = Provider<BookBookmarkDao>((ref) {
  return BookBookmarkDao(ref.read(appDatabaseProvider));
});

class BookBookmarkDao {
  final AppDatabase db;
  BookBookmarkDao(this.db);

  Future<List<BookBookmarkTableData>> getBookmarks(String bookId) async {
    final query = db.select(db.bookBookmarkTable)
      ..where((t) => t.bookId.equals(bookId))
      ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]);
    return query.get();
  }

  Future<BookBookmarkTableData?> getBookmark(int id) async {
    final query = db.select(db.bookBookmarkTable)
      ..where((t) => t.id.equals(id));
    return query.getSingleOrNull();
  }

  Future<bool> isPageBookmarked(String bookId, int page) async {
    final query = db.select(db.bookBookmarkTable)
      ..where((t) => t.bookId.equals(bookId) & t.page.equals(page))
      ..limit(1);
    final result = await query.get();
    return result.isNotEmpty;
  }

  Future<int> addBookmark(String bookId, int page,
      {String? note, String highlightColor = ''}) async {
    return db.into(db.bookBookmarkTable).insert(
          BookBookmarkTableCompanion.insert(
            bookId: bookId,
            page: page,
            note: Value(note),
            highlightColor: Value(highlightColor),
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> removeBookmark(int id) async {
    await (db.delete(db.bookBookmarkTable)..where((t) => t.id.equals(id))).go();
  }

  Future<void> removeBookmarkByPage(String bookId, int page) async {
    await (db.delete(db.bookBookmarkTable)
          ..where((t) => t.bookId.equals(bookId) & t.page.equals(page)))
        .go();
  }

  Future<void> updateBookmarkNote(int id, String? note) async {
    await (db.update(db.bookBookmarkTable)..where((t) => t.id.equals(id)))
        .write(BookBookmarkTableCompanion(note: Value(note)));
  }

  Future<void> updateBookmarkSortOrder(int id, int sortOrder) async {
    await (db.update(db.bookBookmarkTable)..where((t) => t.id.equals(id)))
        .write(BookBookmarkTableCompanion(sortOrder: Value(sortOrder)));
  }

  /// جابه‌جایی نشانک به صفحهٔ تازه — مهاجرت یک‌بارهٔ ایندکس‌ها.
  Future<void> updateBookmarkPage(int id, int page) async {
    await (db.update(db.bookBookmarkTable)..where((t) => t.id.equals(id)))
        .write(BookBookmarkTableCompanion(page: Value(page)));
  }

  Future<int> getBookmarkCount(String bookId) async {
    final query = db.customSelect(
      'SELECT COUNT(*) AS cnt FROM book_bookmark_table WHERE book_id = ?',
      variables: [Variable.withString(bookId)],
    );
    final result = await query.get();
    return result.first.read<int>('cnt');
  }

  Future<Set<String>> getAllBookmarkedBookIds() async {
    final query = db.selectOnly(db.bookBookmarkTable)
      ..addColumns([db.bookBookmarkTable.bookId]);
    final results = await query.get();
    return results.map((r) => r.read(db.bookBookmarkTable.bookId)!).toSet();
  }

  Future<void> removeBookmarksForBook(String bookId) async {
    await (db.delete(db.bookBookmarkTable)
          ..where((t) => t.bookId.equals(bookId)))
        .go();
  }
}
