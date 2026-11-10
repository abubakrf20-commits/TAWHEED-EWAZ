import 'package:flutter/foundation.dart';

/// ═══════════════════════════════════════════════════════════════
/// A position INSIDE a section that has no per-item route — carried by a
/// `ContentHit.target` so a result tap can land on the passage itself
/// instead of the section's front page.
///
/// Plain immutable data: the search layer produces them off the UI isolate
/// and the «بیشتر» page turns them into pushes. No screen imports back here.
/// ═══════════════════════════════════════════════════════════════

/// A hadith row inside a chapter of one of the standalone hadith sections
/// (ریاض الصالحین `riyad`, صحیح الترغیب `taraghib`). [itemId] selects which.
@immutable
class HadithChapterTarget {
  const HadithChapterTarget({
    required this.itemId,
    required this.chapterIndex,
    required this.chapterTitle,
    this.bookId,
    this.hadithNumber,
  });

  /// The owning «بیشتر» id — `riyad` or `taraghib`.
  final String itemId;

  /// The owning book's `books.id` — صحیح الترغیب restarts [chapterIndex] at 1
  /// in every one of its 29 books, so the index alone is ambiguous. Null for
  /// editions that carry no book layer (ریاض الصالحین).
  final int? bookId;

  /// The chapter's own `chapter_index`. It restarts in every book, so it is
  /// meaningful only together with [bookId].
  final num chapterIndex;

  final String chapterTitle;

  /// The row's stored `hadith_number`, used for the exact-row jump. Null when
  /// the row carried none — the chapter then jumps to the first text match.
  final int? hadithNumber;

  @override
  String toString() =>
      'HadithChapterTarget($itemId, book=$bookId, ch=$chapterIndex, '
      '#$hadithNumber)';
}

/// A hadith row inside one of the nine downloaded books (کتب حدیث). Resolved
/// through `HadithBooksService.metaForDbId` at open time, so the search layer
/// never carries UI metadata.
@immutable
class HadithBookEntryTarget {
  const HadithBookEntryTarget({
    required this.bookDbId,
    required this.chapterIndex,
    required this.chapterTitle,
    this.hadithNumber,
  });

  /// `hadiths.book_id` — the registry key is resolved from it when opening.
  final int bookDbId;

  /// The owning chapter's `chapter_index`.
  final num chapterIndex;

  final String chapterTitle;

  /// The row's stored `hadith_number`, used for the exact-row jump. Null when
  /// the row carried none — the chapter then jumps to the first text match.
  final int? hadithNumber;

  @override
  String toString() =>
      'HadithBookEntryTarget(book=$bookDbId, ch=$chapterIndex, #$hadithNumber)';
}

/// One printed page of a downloaded library book (`book_<id>.json.gz`).
/// The reader paginates with the same `BookPagination.paginate`, so
/// [pageIndex] addresses the identical page.
@immutable
class BookPageTarget {
  const BookPageTarget({
    required this.bookId,
    required this.bookTitle,
    required this.pageIndex,
    this.printNo,
  });

  final String bookId;
  final String bookTitle;
  final int pageIndex;

  /// The printed page number when the book carries `(N/M)` markers.
  final int? printNo;

  @override
  String toString() => 'BookPageTarget($bookId, p=$pageIndex)';
}
