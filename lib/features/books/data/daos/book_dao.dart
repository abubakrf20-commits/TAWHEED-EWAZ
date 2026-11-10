import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';

final bookDaoProvider = Provider<BookDao>((ref) {
  return BookDao(ref.read(appDatabaseProvider));
});

class BookDao {
  final AppDatabase db;
  BookDao(this.db);

  Future<List<BookTableData>> getAllBooks() async {
    return db.select(db.bookTable).get();
  }

  Future<BookTableData?> getBook(String id) async {
    final query = db.select(db.bookTable)..where((t) => t.id.equals(id));
    return query.getSingleOrNull();
  }

  Future<void> upsertBook(BookTableData book) async {
    await db.into(db.bookTable).insertOnConflictUpdate(book);
  }

  Future<void> deleteBook(String id) async {
    await (db.delete(db.bookTable)..where((t) => t.id.equals(id))).go();
  }

  Future<void> clearAll() async {
    await db.delete(db.bookTable).go();
  }
}
