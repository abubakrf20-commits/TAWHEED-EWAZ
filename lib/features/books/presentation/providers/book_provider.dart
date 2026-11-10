import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:drift/drift.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/books/data/models/book_model.dart';
import 'package:tawheeed/features/books/data/daos/book_bookmark_dao.dart';
import 'package:tawheeed/features/books/data/daos/book_dao.dart';
import 'package:tawheeed/features/books/data/services/book_highlight_service.dart';
import 'package:tawheeed/features/books/services/book_content_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

part 'book_provider.g.dart';

/// کتاب‌هایی که از کاتالوگ و سرور حذف شده‌اند — روی دستگاه کاربران قدیمی هم
/// با هر بار اجرا از دیتابیس پاک می‌شوند تا دیگر در کتابخانه دیده نشوند.
const _removedBookIds = {'56498', '52449'};

@riverpod
class Book extends _$Book {
  @override
  Future<List<BookModel>> build() async {
    final dao = ref.read(bookDaoProvider);
    await _removeRetiredBooks(dao);
    final books = await dao.getAllBooks();
    if (books.isEmpty) {
      await _seedFromAssets(dao);
    } else if (_needsRepair(books)) {
      await _repairBooks(dao, books);
    }
    final all = await dao.getAllBooks();
    all.sort((a, b) => a.title.compareTo(b.title));
    return all.map(_toModel).toList();
  }

  bool _needsRepair(List<BookTableData> books) {
    return books.any((b) => b.author.isEmpty || b.category.isEmpty);
  }

  /// کتاب‌های حذف‌شده از کاتالوگ را (به‌همراه محتوای دانلودشده) از دستگاه پاک
  /// می‌کند — idempotent و در هر اجرا فقط وقتی ردیفی وجود داشته باشد هزینه دارد.
  Future<void> _removeRetiredBooks(BookDao dao) async {
    for (final id in _removedBookIds) {
      final book = await dao.getBook(id);
      if (book == null) continue;
      await dao.deleteBook(id);
      await ref.read(bookBookmarkDaoProvider).removeBookmarksForBook(id);
      await BookHighlightService.instance.removeAllForBook(id);
      try {
        await BookContentService.deleteDownloaded(id);
      } catch (_) {
        AppLogger.warning('book_provider', 'operation failed');
      }
    }
  }

  Future<void> _repairBooks(BookDao dao, List<BookTableData> books) async {
    final assets =
        await rootBundle.loadString('assets/books_data/books_index.json');
    final indexList = json.decode(assets) as List<dynamic>;
    for (final book in books) {
      final needsTitleFix = book.title.isEmpty;
      final needsAuthorFix = book.author.isEmpty;
      final needsCategoryFix = book.category.isEmpty;
      if (needsTitleFix || needsAuthorFix || needsCategoryFix) {
        final match = indexList.firstWhere(
          (item) => item['id'] == book.id,
          orElse: () => null,
        );
        if (match != null) {
          final updated = book.copyWith(
            title: needsTitleFix ? (match['title'] ?? '') : book.title,
            author: needsAuthorFix ? (match['author'] ?? '') : book.author,
            category: needsCategoryFix
                ? (match['category']?.toString().isNotEmpty == true
                    ? match['category']
                    : _detectCategory(match['title'] ?? ''))
                : book.category,
          );
          await dao.upsertBook(updated);
        }
      }
    }
  }

  Future<void> _seedFromAssets(BookDao dao) async {
    try {
      final indexJson =
          await rootBundle.loadString('assets/books_data/books_index.json');
      final List<dynamic> indexList = json.decode(indexJson);
      for (final item in indexList) {
        final row = BookTableData(
          id: item['id'] ?? '',
          title: item['title'] ?? '',
          author: item['author'] ?? '',
          category: item['category']?.toString().isNotEmpty == true
              ? item['category']
              : _detectCategory(item['title'] ?? ''),
          filePath: '',
          fileSize: 0,
          pageCount: item['pages'] ?? 0,
          dateAdded: DateTime.now(),
          currentPage: 0,
          isFavorite: false,
          readProgress: 0.0,
          language: 'fa',
          tags: item['description'] != null &&
                  item['description'].toString().isNotEmpty
              ? item['description']
              : '',
        );
        await dao.upsertBook(row);
      }
    } catch (e) {
      AppLogger.warning('book_provider', 'Error loading books from assets: $e');
    }
  }

  BookModel _toModel(BookTableData row) {
    return BookModel(
      id: row.id,
      title: row.title,
      author: row.author,
      category: row.category,
      filePath: row.filePath,
      fileSize: row.fileSize,
      pageCount: row.pageCount,
      dateAdded: row.dateAdded,
      lastRead: row.lastRead,
      currentPage: row.currentPage,
      isFavorite: row.isFavorite,
      readProgress: row.readProgress,
      language: row.language,
      tags: row.tags.isEmpty ? [] : row.tags.split(','),
      startedAt: row.startedAt,
      completedAt: row.completedAt,
    );
  }

  List<BookModel> byCategory(String category) =>
      state.value?.where((b) => b.category == category).toList() ?? [];

  List<BookModel> get favorites =>
      state.value?.where((b) => b.isFavorite).toList() ?? [];

  List<String> get categories {
    final books = state.value ?? [];
    final cats = books
        .map((b) => b.category)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    cats.sort();
    return cats;
  }

  List<BookModel> search(String query) {
    final books = state.value ?? [];
    if (query.isEmpty) return books;
    final q = query.toLowerCase();
    return books
        .where((b) =>
            b.title.toLowerCase().contains(q) ||
            b.author.toLowerCase().contains(q) ||
            b.category.toLowerCase().contains(q))
        .toList();
  }

  Future<void> toggleFavorite(String id) async {
    final dao = ref.read(bookDaoProvider);
    final book = await dao.getBook(id);
    if (book != null) {
      final updated = book.copyWith(isFavorite: !book.isFavorite);
      await dao.upsertBook(updated);
      final all = await dao.getAllBooks();
      all.sort((a, b) => a.title.compareTo(b.title));
      state = AsyncData(all.map(_toModel).toList());
    }
  }

  Future<void> updateProgress(String id, int page, {int? totalPages}) async {
    final dao = ref.read(bookDaoProvider);
    final book = await dao.getBook(id);
    if (book != null) {
      final denominator = totalPages ?? book.pageCount;
      if (denominator <= 0) return;
      final now = DateTime.now();
      final clampedPage = page.clamp(0, denominator).toInt();
      final progress = (clampedPage / denominator).clamp(0.0, 1.0).toDouble();
      final isComplete = progress >= 1.0;
      final updated = book.copyWith(
        currentPage: clampedPage,
        readProgress: progress,
        // The shelf must show the same page count the reader counts. The
        // catalog only knows how many PARAGRAPHS a book file has, which is
        // not what the reader paginates by (printed page markers), so the
        // first read writes the real number here and every screen agrees from
        // then on.
        pageCount: totalPages ?? book.pageCount,
        lastRead: Value(now),
        startedAt: Value(book.startedAt ?? (clampedPage > 0 ? now : null)),
        completedAt: Value(isComplete ? (book.completedAt ?? now) : null),
      );
      await dao.upsertBook(updated);
      final all = await dao.getAllBooks();
      all.sort((a, b) => a.title.compareTo(b.title));
      state = AsyncData(all.map(_toModel).toList());
    }
  }

  List<BookModel> get completedBooks {
    final books = state.value ?? [];
    return books.where((b) => b.isCompleted).toList();
  }

  Future<void> deleteBook(String id) async {
    final dao = ref.read(bookDaoProvider);
    await dao.deleteBook(id);
    await ref.read(bookBookmarkDaoProvider).removeBookmarksForBook(id);
    await BookHighlightService.instance.removeAllForBook(id);
    final all = await dao.getAllBooks();
    all.sort((a, b) => a.title.compareTo(b.title));
    state = AsyncData(all.map(_toModel).toList());
  }

  BookModel? getById(String id) {
    final books = state.value ?? [];
    return books.where((b) => b.id == id).firstOrNull;
  }

  Future<void> updateTags(String id, List<String> tags) async {
    final dao = ref.read(bookDaoProvider);
    final book = await dao.getBook(id);
    if (book != null) {
      final updated = book.copyWith(tags: tags.join(','));
      await dao.upsertBook(updated);
      final all = await dao.getAllBooks();
      all.sort((a, b) => a.title.compareTo(b.title));
      state = AsyncData(all.map(_toModel).toList());
    }
  }

  Set<String> get allUserTags {
    final books = state.value ?? [];
    final tags = <String>{};
    for (final b in books) {
      tags.addAll(b.tags);
    }
    return tags;
  }

  String _detectCategory(String title) {
    final t = title.toLowerCase();
    if (t.contains('نماز') ||
        t.contains('وضو') ||
        t.contains('طهارت') ||
        t.contains('فقه')) {
      return 'فقه';
    }
    if (t.contains('عقیده') || t.contains('توحید') || t.contains('ایمان')) {
      return 'عقیده';
    }
    if (t.contains('قرآن') || t.contains('تفسیر') || t.contains('تجوید')) {
      return 'تفسیر';
    }
    if (t.contains('حدیث') || t.contains('بخاری') || t.contains('سنت')) {
      return 'حدیث';
    }
    if (t.contains('سیرت') ||
        t.contains('زندگی') ||
        t.contains('صحابه') ||
        t.contains('نبوت')) {
      return 'سیره';
    }
    if (t.contains('اخلاق') || t.contains('آداب')) return 'اخلاق';
    if (t.contains('ذکر') || t.contains('ادعیه') || t.contains('دعا')) {
      return 'ادعیه';
    }
    if (t.contains('زکات') || t.contains('حج') || t.contains('روزه')) {
      return 'عبادات';
    }
    if (t.contains('شعر') ||
        t.contains('ادب') ||
        t.contains('سعدي') ||
        t.contains('مثنوی')) {
      return 'ادبیات';
    }
    return 'متفرقه';
  }
}
