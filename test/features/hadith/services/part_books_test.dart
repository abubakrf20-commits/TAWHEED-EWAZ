// Test: the کتاب level both ریاض and معالم gain from their own `part` labels.
//
// The grouping is pure data, so it is tested as data: no database, no widgets.
// What matters is that a chapter can never fall out of a book, that the printed
// order survives, and that a Maalim مقصد stays a label above the book instead of
// becoming a book of its own.
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/hadith/services/part_books.dart';

Map<String, dynamic> _chapter(num index, String? part, [String name = 'باب']) => {
      'chapter_index': index,
      'part': part,
      'name_arabic': name,
    };

void main() {
  test('a chapter group is cut at the کتاب level, not at فصل', () {
    final books = partBooksOf([
      _chapter(1, 'مقصد سوم: عبادات · کتاب اول: طهارت · فصل اول: پاکی'),
      _chapter(2, 'مقصد سوم: عبادات · کتاب اول: طهارت · فصل دوم: حیض'),
      _chapter(3, 'مقصد سوم: عبادات · کتاب دوم: أذان'),
    ]);

    expect(books, hasLength(2));
    expect(books.first.title, 'کتاب اول: طهارت');
    expect(books.first.parent, 'مقصد سوم: عبادات');
    expect(books.first.babCount, 2,
        reason: 'a فصل is a division inside its کتاب, not a book');
    expect(books.last.title, 'کتاب دوم: أذان');
    expect(books.last.parent, 'مقصد سوم: عبادات');
  });

  test('the printed order is the list order', () {
    final books = partBooksOf([
      _chapter(1, 'کتاب سوم: ایمان به تقدیر'),
      _chapter(2, 'کتاب اول: اسلام و ایمان'),
      _chapter(3, 'کتاب سوم: ایمان به تقدیر'),
    ]);
    expect(books.map((b) => b.title).toList(), [
      'کتاب سوم: ایمان به تقدیر',
      'کتاب اول: اسلام و ایمان',
    ], reason: 'the list follows the data, never a sort of our own');
    expect(books.first.babCount, 2);
  });

  test('a book with no مقصد above it has no parent', () {
    final books = partBooksOf([_chapter(1, 'کتاب 1: ادب')]);
    expect(books.single.parent, isNull);
    expect(books.single.title, 'کتاب 1: ادب');
  });

  test('a chapter with no part is its own book, never dropped', () {
    // ریاض prints a handful of ببs before its first «کتاب» heading; they are
    // real chapters and must stay reachable.
    final books = partBooksOf([
      _chapter(1, null, 'باب الإخلاص'),
      _chapter(2, '', 'باب التوبة'),
      _chapter(3, 'کتاب 1: ادب'),
    ]);
    expect(books.map((b) => b.title).toList(),
        ['باب الإخلاص', 'باب التوبة', 'کتاب 1: ادب']);
    expect(books.take(2).every((b) => b.parent == null), isTrue);
  });

  test('two different books with the same نام stay two books', () {
    final books = partBooksOf([
      _chapter(1, 'مقصد دوم: علم · کتاب نخست: علم'),
      _chapter(2, 'مقصد سوم: عبادات · کتاب نخست: علم'),
    ]);
    expect(books, hasLength(2),
        reason: 'the مقصد is part of the identity, not decoration');
  });

  test('nothing in means nothing out', () {
    expect(partBooksOf(const []), isEmpty);
  });
}
