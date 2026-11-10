import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/books/presentation/book_page_notes.dart';
import 'package:tawheeed/features/books/services/book_pagination.dart';

/// One book-wide footnote map used to answer EVERY page is what made a note
/// look like it belonged to several pages: each page re-discovered its own
/// markers, so a source number that restarts per chapter could print a note
/// that was never on that page. These pin the resolver that replaced it.
void main() {
  const all = <String, String>{
    '3': 'الحاشية الأولى',
    '7': 'الحاشية الثانية',
    '12': 'الحاشية الثالثة',
    '9': '   ',
    '4': '',
  };

  BookPage page(String text) => BookPage(index: 1, text: text);

  group('BookPageNotes.of', () {
    test('answers only the markers this page carries, in reading order', () {
      final notes = BookPageNotes.of(page('قال الله (12) ثم قال (3).'), all);

      expect(notes.map((note) => note.sourceId), ['12', '3']);
      expect(
        notes.map((note) => note.text),
        ['الحاشية الثالثة', 'الحاشية الأولى'],
      );
    });

    test('numbers the page from one, never from the source number', () {
      final notes = BookPageNotes.of(page('قال الله (12) ثم قال (3).'), all);

      expect(notes.map((note) => note.displayNumber), [1, 2]);
    });

    test('prints a repeated marker once', () {
      final notes = BookPageNotes.of(page('قال (3) ثم (7) ثم (3).'), all);

      expect(notes, hasLength(2));
      expect(notes.map((note) => note.sourceId), ['3', '7']);
      expect(notes.map((note) => note.displayNumber), [1, 2]);
    });

    test('drops a marker no note answers, rather than set an empty row', () {
      final notes = BookPageNotes.of(page('قال (99) ثم (3).'), all);

      expect(notes.map((note) => note.sourceId), ['3']);
      expect(notes.single.displayNumber, 1);
    });

    test('drops a note whose text is blank', () {
      final notes = BookPageNotes.of(page('قال (9) ثم (3) ثم (4).'), all);

      expect(notes.map((note) => note.sourceId), ['3']);
    });

    test('an ordinary parenthetical number is not a footnote', () {
      final notes = BookPageNotes.of(
        page('رأيت (2018) في الكتاب، و(3) هنا.'),
        all,
      );

      expect(notes.map((note) => note.sourceId), ['3'],
          reason: 'a date in the text must not pull in a note by collision');
    });

    test('a page with no markers carries no notes', () {
      expect(BookPageNotes.of(page('قال الله تعالى.'), all), isEmpty);
    });

    test('the same marker on another page prints nothing there', () {
      // Two pages of one book, both carrying `(1)` — the source restarts its
      // numbering in every chapter. Only the page whose OWN extracted map
      // answers the marker prints a note; the other must stay bare, or page
      // one's footnote reappears at the foot of every later page.
      const first = BookPage(
        index: 0,
        text: 'بابٌ في الطهارة (1)',
        notes: {'1': 'الحاشية الأولى'},
      );
      const second = BookPage(index: 1, text: 'فصلٌ في الوضوء (1)');

      expect(BookPageNotes.of(first, first.notes), hasLength(1));
      expect(BookPageNotes.of(second, second.notes), isEmpty);
    });
  });

  group('BookFootnoteMode', () {
    test('round-trips every mode through its wire name', () {
      for (final mode in BookFootnoteMode.values) {
        expect(BookFootnoteMode.fromWire(mode.wire), mode);
      }
    });

    test('an unknown or missing wire name is the default page', () {
      expect(BookFootnoteMode.fromWire(null), BookFootnoteMode.markers);
      expect(BookFootnoteMode.fromWire(''), BookFootnoteMode.markers);
      expect(BookFootnoteMode.fromWire('margin'), BookFootnoteMode.markers);
    });

    test('the legacy boolean maps onto the two modes it could express', () {
      expect(
        BookFootnoteMode.fromLegacyBool(false),
        BookFootnoteMode.hidden,
        reason: 'switching markers off asked for a bare page, not pointers '
            'without their notes',
      );
      expect(BookFootnoteMode.fromLegacyBool(true), BookFootnoteMode.markers);
      expect(BookFootnoteMode.fromLegacyBool(null), BookFootnoteMode.markers);
    });

    test('only the marker mode points into the text', () {
      expect(BookFootnoteMode.markers.pointsInText, isTrue);
      expect(BookFootnoteMode.notes.pointsInText, isFalse);
      expect(BookFootnoteMode.hidden.pointsInText, isFalse);
    });

    test('every mode but hidden prints its notes', () {
      expect(BookFootnoteMode.markers.printsNotes, isTrue);
      expect(BookFootnoteMode.notes.printsNotes, isTrue);
      expect(BookFootnoteMode.hidden.printsNotes, isFalse);
    });

    test('every mode is labelled and described for the settings sheet', () {
      for (final mode in BookFootnoteMode.values) {
        expect(mode.label.trim(), isNotEmpty);
        expect(mode.description.trim(), isNotEmpty);
      }
    });
  });
}
