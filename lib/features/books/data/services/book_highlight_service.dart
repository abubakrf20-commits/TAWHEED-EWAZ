import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class BookHighlight {
  final String bookId;
  final int page;
  final int startOffset;
  final int endOffset;
  final Color color;
  final DateTime createdAt;

  BookHighlight({
    required this.bookId,
    required this.page,
    required this.startOffset,
    required this.endOffset,
    required this.color,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int get length => endOffset - startOffset;

  Map<String, dynamic> toJson() => {
        'bookId': bookId,
        'page': page,
        'startOffset': startOffset,
        'endOffset': endOffset,
        'color': color.toARGB32(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory BookHighlight.fromJson(Map<String, dynamic> json) => BookHighlight(
        bookId: json['bookId'] ?? '',
        page: json['page'] ?? 0,
        startOffset: json['startOffset'] ?? 0,
        endOffset: json['endOffset'] ?? 0,
        color: Color(json['color'] ?? 0xFFFFFF00),
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      );
}

/// Highlight persistence for the book reader.
///
/// One JSON file per book under `<app-support>/book_highlights/` so a page
/// query only reads that book's data (the old design kept every highlight of
/// every book in a single SharedPreferences string that was rewritten on each
/// change). Writes are debounced per book to avoid thrashing disk on rapid
/// highlights.
class BookHighlightService {
  BookHighlightService._();

  static final BookHighlightService instance = BookHighlightService._();

  Directory? _dir;
  final Map<String, List<BookHighlight>> _cache = {};
  final Map<String, Timer> _writeTimers = {};
  final Set<String> _dirty = {};

  Future<Directory> _ensureDir() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'book_highlights'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _dir = dir;
    return dir;
  }

  Future<File> _fileFor(String bookId) async {
    final dir = await _ensureDir();
    final safe = bookId.replaceAll(RegExp(r'[^\w.\-]'), '_');
    return File(p.join(dir.path, '$safe.json'));
  }

  Future<List<BookHighlight>> getHighlights(String bookId) async {
    final cached = _cache[bookId];
    if (cached != null) return List.unmodifiable(cached);
    final file = await _fileFor(bookId);
    final list = <BookHighlight>[];
    if (await file.exists()) {
      try {
        final raw = jsonDecode(await file.readAsString());
        if (raw is List) {
          list.addAll(raw
              .whereType<Map<String, dynamic>>()
              .map(BookHighlight.fromJson));
        }
      } catch (_) {
        // Corrupt file — start fresh (the next write overwrites it).
      }
    }
    _cache[bookId] = list;
    return List.unmodifiable(list);
  }

  Future<List<BookHighlight>> getPageHighlights(String bookId, int page) async {
    final all = await getHighlights(bookId);
    return all.where((h) => h.page == page).toList();
  }

  Future<void> addHighlight(BookHighlight highlight) async {
    final all = await getHighlights(highlight.bookId);
    _cache[highlight.bookId] = [...all, highlight];
    _scheduleWrite(highlight.bookId);
  }

  Future<void> removeHighlight(
      String bookId, int page, int startOffset, int endOffset) async {
    final all = await getHighlights(bookId);
    _cache[bookId] = all
        .where((h) => !(h.page == page &&
            h.startOffset == startOffset &&
            h.endOffset == endOffset))
        .toList();
    _scheduleWrite(bookId);
  }

  Future<void> removeAllForBook(String bookId) async {
    _cache[bookId] = [];
    _scheduleWrite(bookId);
  }

  /// جابه‌جایی هایلایت‌ها پس از بازلایه‌بندی صفحات.
  ///
  /// [remap] ایندکس قدیم را به نو می‌برد و [pageTextLengths] طول متنِ هر
  /// صفحهٔ تازه است. برشِ پانوشت تنِ صفحه را کوتاه می‌کند، پس بازه‌ای که از
  /// انتها بیرون بزند به انتهای صفحه بریده می‌شود؛ بازه‌ای که کامل از بین
  /// رفته حذف می‌شود — رنگ‌آمیزی چیزی که وجود ندارد بدتر است.
  Future<void> remapPages(
    String bookId,
    Map<int, int> remap,
    List<int> pageTextLengths,
  ) async {
    final all = await getHighlights(bookId);
    if (all.isEmpty) return;
    final next = <BookHighlight>[];
    var changed = false;
    for (final h in all) {
      final page = remap[h.page] ?? h.page;
      final limit = page >= 0 && page < pageTextLengths.length
          ? pageTextLengths[page]
          : null;
      var start = h.startOffset;
      var end = h.endOffset;
      if (limit != null) {
        if (start > limit) start = limit;
        if (end > limit) end = limit;
      }
      if (page == h.page && start == h.startOffset && end == h.endOffset) {
        next.add(h);
        continue;
      }
      changed = true;
      if (end <= start) continue;
      next.add(BookHighlight(
        bookId: h.bookId,
        page: page,
        startOffset: start,
        endOffset: end,
        color: h.color,
        createdAt: h.createdAt,
      ));
    }
    if (!changed) return;
    _cache[bookId] = next;
    _dirty.add(bookId);
    await _flush(bookId);
  }

  void _scheduleWrite(String bookId) {
    _dirty.add(bookId);
    _writeTimers[bookId]?.cancel();
    _writeTimers[bookId] = Timer(const Duration(milliseconds: 300), () {
      unawaited(_flush(bookId));
    });
  }

  Future<void> _flush(String bookId) async {
    if (!_dirty.remove(bookId)) return;
    _writeTimers.remove(bookId)?.cancel();
    final items = _cache[bookId];
    if (items == null) return;
    try {
      final file = await _fileFor(bookId);
      await file.writeAsString(
        jsonEncode([for (final h in items) h.toJson()]),
        flush: true,
      );
    } catch (_) {
      // Best-effort persistence — a failed write only loses recent edits.
    }
  }

  /// Flushes any pending writes (call on app pause/exit).
  Future<void> flushAll() async {
    for (final bookId in _dirty.toList()) {
      await _flush(bookId);
    }
  }
}
