import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/books/data/services/book_highlight_service.dart';

void main() {
  group('BookHighlight model', () {
    test('length is end minus start offset', () {
      final h = BookHighlight(
        bookId: 'b1',
        page: 3,
        startOffset: 10,
        endOffset: 25,
        color: const Color(0xFF00FF00),
      );
      expect(h.length, 15);
    });

    test('toJson/fromJson round-trips every field', () {
      final h = BookHighlight(
        bookId: 'b1',
        page: 7,
        startOffset: 4,
        endOffset: 9,
        color: const Color(0xFF123456),
        createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
      );
      final restored = BookHighlight.fromJson(h.toJson());
      expect(restored.bookId, h.bookId);
      expect(restored.page, h.page);
      expect(restored.startOffset, h.startOffset);
      expect(restored.endOffset, h.endOffset);
      expect(restored.color, h.color);
      expect(restored.createdAt, h.createdAt);
    });

    test('fromJson applies defaults when keys are missing', () {
      final h = BookHighlight.fromJson({});
      expect(h.bookId, '');
      expect(h.page, 0);
      expect(h.startOffset, 0);
      expect(h.endOffset, 0);
      expect(h.color, const Color(0xFFFFFF00));
    });

    test('toJson stores color as ARGB int and createdAt as ISO string', () {
      final h = BookHighlight(
        bookId: 'b1',
        page: 1,
        startOffset: 0,
        endOffset: 1,
        color: const Color(0xFFAABBCC),
        createdAt: DateTime.utc(2026, 5, 6, 7, 8, 9),
      );
      final json = h.toJson();
      expect(json['color'], 0xFFAABBCC);
      expect(json['createdAt'], '2026-05-06T07:08:09.000Z');
    });
  });
}
