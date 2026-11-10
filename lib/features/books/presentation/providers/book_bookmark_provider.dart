import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tawheeed/features/books/data/daos/book_bookmark_dao.dart';

part 'book_bookmark_provider.g.dart';

/// IDs of every book that has at least one bookmark anywhere — was a
/// private FutureProvider living inside ketabkhaneh_screen.dart.
@Riverpod(keepAlive: true)
Future<Set<String>> allBookmarkedIds(Ref ref) {
  final dao = ref.read(bookBookmarkDaoProvider);
  return dao.getAllBookmarkedBookIds();
}

class BookBookmarkData {
  final int id;
  final String bookId;
  final int page;
  final String? note;
  final String highlightColor;
  final DateTime createdAt;
  final int sortOrder;

  const BookBookmarkData({
    required this.id,
    required this.bookId,
    required this.page,
    this.note,
    this.highlightColor = '',
    required this.createdAt,
    this.sortOrder = 0,
  });
}

@riverpod
class BookBookmark extends _$BookBookmark {
  @override
  Future<List<BookBookmarkData>> build(String bookId) async {
    final dao = ref.read(bookBookmarkDaoProvider);
    final bookmarks = await dao.getBookmarks(bookId);
    return bookmarks
        .map((b) => BookBookmarkData(
              id: b.id,
              bookId: b.bookId,
              page: b.page,
              note: b.note,
              highlightColor: b.highlightColor,
              createdAt: b.createdAt,
              sortOrder: b.sortOrder,
            ))
        .toList();
  }

  Future<void> toggleBookmark(int page, {String? note}) async {
    final dao = ref.read(bookBookmarkDaoProvider);
    final isBookmarked = await dao.isPageBookmarked(bookId, page);
    if (isBookmarked) {
      await dao.removeBookmarkByPage(bookId, page);
    } else {
      await dao.addBookmark(bookId, page, note: note);
    }
    ref.invalidateSelf();
  }

  Future<bool> isPageBookmarked(int page) async {
    final dao = ref.read(bookBookmarkDaoProvider);
    return dao.isPageBookmarked(bookId, page);
  }

  Future<void> addBookmark(int page,
      {String? note, String highlightColor = ''}) async {
    final dao = ref.read(bookBookmarkDaoProvider);
    await dao.addBookmark(bookId, page,
        note: note, highlightColor: highlightColor);
    ref.invalidateSelf();
  }

  Future<void> removeBookmark(int id) async {
    final dao = ref.read(bookBookmarkDaoProvider);
    await dao.removeBookmark(id);
    ref.invalidateSelf();
  }

  Future<void> updateNote(int id, String? note) async {
    final dao = ref.read(bookBookmarkDaoProvider);
    await dao.updateBookmarkNote(id, note);
    ref.invalidateSelf();
  }
}
