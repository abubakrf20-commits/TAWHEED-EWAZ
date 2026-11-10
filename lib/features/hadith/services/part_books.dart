/// The book level of a بخش whose chapters each carry their printed `part`.
///
/// Riyad and Maalim store ONE book row and keep the edition's own hierarchy in
/// `chapters.part` — «مقصد · کتاب · فصل» for Maalim, «کتاب · فصل» for Riyad.
/// The reader wants the same three steps الترغیب has (book › باب › حديث), so
/// this turns that label into the missing middle: one group per «کتاب», in the
/// order the edition prints them, each holding its own باب‌ها.
///
/// It is deliberately pure data — no Flutter, no database — so both sections
/// and their tests derive the books the same way.
library;

/// One «کتاب» of the edition: its label, the levels above it, and its باب‌ها.
class PartBook {
  const PartBook({
    required this.key,
    required this.title,
    required this.parent,
    required this.chapters,
  });

  /// The `part` prefix this group was cut at — stable across rebuilds, so it
  /// can be used as a widget key.
  final String key;

  /// The book's own label, e.g. «کتاب اول: اسلام و ايمان».
  final String title;

  /// The levels above the book (a Maalim مقصد, a Riyad volume), or null.
  final String? parent;

  /// This book's chapters, in printed order.
  final List<Map<String, dynamic>> chapters;

  int get babCount => chapters.length;
}

/// Groups [chapters] into books by their `part` label, in printed order.
///
/// A chapter with no `part` (an older revision) is a book of its own named
/// after its heading, so it is never silently dropped from the list.
List<PartBook> partBooksOf(List<Map<String, dynamic>> chapters) {
  final groups = <String, List<Map<String, dynamic>>>{};
  for (final ch in chapters) {
    final part = ((ch['part'] ?? '') as String).trim();
    final (key, _) = _splitPart(part, ch);
    groups.putIfAbsent(key, () => []).add(ch);
  }
  return [
    for (final entry in groups.entries) _bookFrom(entry.key, entry.value),
  ];
}

/// The book a group of chapters forms: its label and the level above it are both
/// read from the group's first chapter, so the two can never disagree.
PartBook _bookFrom(String key, List<Map<String, dynamic>> chapters) {
  final part = ((chapters.first['part'] ?? '') as String).trim();
  final (_, title) = _splitPart(part, chapters.first);
  return PartBook(
    key: key,
    title: title,
    parent: _parentOf(part, title),
    chapters: chapters,
  );
}

/// The book segment of [part] and the key it belongs to.
(String, String) _splitPart(String part, Map<String, dynamic> chapter) {
  if (part.isEmpty) {
    final title = ((chapter['name_arabic'] ?? '') as String).trim();
    return (title.isEmpty ? 'باب' : title, title.isEmpty ? 'باب' : title);
  }
  final levels = part.split(' · ');
  // The last level that names a «کتاب» is the book; «فصل» and anything after it
  // belongs to that book, so the group is the prefix up to and including it.
  var bookAt = -1;
  for (var i = 0; i < levels.length; i++) {
    if (levels[i].trim().startsWith('کتاب')) bookAt = i;
  }
  if (bookAt < 0) return (part, levels.last);
  return (
    levels.take(bookAt + 1).join(' · '),
    levels[bookAt].trim(),
  );
}

String? _parentOf(String part, String title) {
  final levels = part.split(' · ');
  final at = levels.indexOf(title);
  if (at <= 0) return null;
  final head = levels.take(at).join(' · ').trim();
  return head.isEmpty ? null : head;
}
