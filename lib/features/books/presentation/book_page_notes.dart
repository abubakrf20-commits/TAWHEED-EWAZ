/// Which notes belong to one printed page, and what they are numbered.
///
/// The book files carry one note map for the WHOLE volume (`id → text`) and
/// mark each note in the running text as `(12)`. Those source numbers restart
/// inside every chapter, so the same id answers different notes in different
/// places — printing the raw id put one note at the foot of several pages.
///
/// The fix is to resolve the page's own markers once, in reading order, and
/// renumber them from 1 for that page: exactly what a printed book does, and
/// what the الترغیب reader (`InlineFootnotes`) already does. The source id
/// stays as provenance — it keys the note for a tap — but it is never printed.
///
/// Pure, like [BookPageText]: one resolver feeds both the printed rows and the
/// in-text markers, so the two can never disagree about which notes exist.
library;

import 'package:tawheeed/features/books/presentation/book_page_text.dart';
import 'package:tawheeed/features/books/services/book_pagination.dart';

/// What the page does with its notes.
///
/// Three states, not a bool: a reader may want the notes at the foot but an
/// uninterrupted page above them.
enum BookFootnoteMode {
  /// Markers in the text and the notes printed under it.
  markers,

  /// The notes printed under the page, with no pointers in the text.
  notes,

  /// Neither: the markers stay as ordinary text and no apparatus is printed.
  hidden;

  /// Persisted name. The enum is stored by name, so reordering it is safe.
  String get wire => name;

  /// Reads a stored value; an unknown or missing one is the full apparatus.
  static BookFootnoteMode fromWire(String? value) {
    for (final mode in values) {
      if (mode.wire == value) return mode;
    }
    return BookFootnoteMode.markers;
  }

  /// The preference this mode replaced was a bool: `true` meant markers on,
  /// `false` meant a bare page. A reader who turned it off asked for the page
  /// they had — no markers, no notes — so `false` maps to [hidden], not
  /// [notes], or the update would add an apparatus they had switched away.
  static BookFootnoteMode fromLegacyBool(bool? markersOn) =>
      markersOn == false ? BookFootnoteMode.hidden : BookFootnoteMode.markers;

  /// Whether a `(3)` in the text points at a note.
  bool get pointsInText => this == BookFootnoteMode.markers;

  /// Whether the notes are printed at the foot of the page.
  bool get printsNotes => this != BookFootnoteMode.hidden;

  String get label => switch (this) {
        BookFootnoteMode.markers => 'نشانگر و متن',
        BookFootnoteMode.notes => 'فقط متن',
        BookFootnoteMode.hidden => 'بدون پاورقی',
      };

  String get description => switch (this) {
        BookFootnoteMode.markers =>
          'شمارهٔ (۳) در متن و متن پاورقی در پای صفحه',
        BookFootnoteMode.notes => 'پاورقی‌ها چاپ می‌شوند، ولی اشاره‌ای در متن نیست',
        BookFootnoteMode.hidden => 'نه اشاره‌ای در متن، نه پاورقی',
      };
}

/// One note as the page prints it.
///
/// [displayNumber] is what the reader sees — 1, 2, 3 … inside THIS page.
/// [sourceId] is the book's own marker and only keys the note for a tap.
class BookPageNote {
  const BookPageNote({
    required this.displayNumber,
    required this.sourceId,
    required this.text,
  });

  final int displayNumber;
  final String sourceId;
  final String text;
}

/// The page's apparatus, resolved.
abstract final class BookPageNotes {
  const BookPageNotes._();

  /// Every note the page's text points at, in reading order, numbered from 1.
  ///
  /// A marker the book's map does not answer is dropped: it is a broken
  /// source, and printing a bare number over nothing reads as a lost page.
  /// The same id printed twice on one page is kept once — an apparatus that
  /// repeats a note is worse than one that skips a back-reference.
  static List<BookPageNote> of(BookPage page, Map<String, String> all) {
    final seen = <String>{};
    final notes = <BookPageNote>[];
    for (final id in BookPageText.noteIds(page.text)) {
      final text = (all[id] ?? '').trim();
      if (text.isEmpty) continue;
      if (!seen.add(id)) continue;
      notes.add(BookPageNote(
        displayNumber: notes.length + 1,
        sourceId: id,
        text: text,
      ));
    }
    return notes;
  }
}
