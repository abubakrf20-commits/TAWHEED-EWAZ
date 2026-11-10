import 'package:flutter/foundation.dart';

/// ═══════════════════════════════════════════════════════════════
/// One result of a search that reached INSIDE a section's own text — an
/// ayah, a fiqh paragraph, a dua, a note — as opposed to a hit on a
/// section title. Produced by `more_content_search.dart`.
///
/// [itemId] is the «بیشتر» registry id of the section that owns the text, so
/// the page can group hits under the tile the user already knows; [entity]
/// carries the object a target screen can open directly, when such a screen
/// exists.
/// ═══════════════════════════════════════════════════════════════
@immutable
class ContentHit {
  const ContentHit({
    required this.itemId,
    required this.title,
    required this.snippet,
    this.body = '',
    this.highlightQuery = '',
    this.entity,
    this.target,
  });

  /// Owning section — a `MoreItem.id`.
  final String itemId;

  /// The heading the match sits under inside that section; '' when the
  /// content has no heading of its own, so the page shows the section title.
  final String title;

  /// An excerpt of the matched text, centered on the match where possible.
  final String snippet;

  /// The full text the snippet was cut from — what the reader screen shows
  /// when the owning section has no per-item screen of its own.
  final String body;

  /// The EXACT original substring the normalized query matched, verbatim from
  /// [body]/[title]. Painted by `TextHighlight` on the destination screen and
  /// used to cut [snippet]; empty when no literal could be projected back.
  final String highlightQuery;

  /// Deep-link payload (a `DuaModel`, a `NoteTableData`, …), or null when the
  /// target screen has no per-item entry point and the section opens instead.
  final Object? entity;

  /// A position inside a section that has no per-item route of its own — a
  /// chapter + hadith, a book page. See `content_targets.dart`.
  final Object? target;
}

/// The title-ish keys the bundled content assets use for a heading.
const List<String> kContentTitleKeys = [
  'title',
  'name',
  'question',
  'heading',
  'term',
];

/// A window of [body] around the first occurrence of [needle], falling back to
/// the head of the text when the needle is only visible after normalization
/// (harakat, letter folds). Never splits a surrogate pair.
String snippetAround(String body, String needle, {int max = 110}) {
  final text = body.trim();
  if (text.isEmpty) return '';
  if (text.length <= max && needle.isEmpty) return text;

  final lower = text.toLowerCase();
  final q = needle.trim().toLowerCase();
  var at = q.isEmpty ? 0 : lower.indexOf(q);
  if (at < 0) at = 0;

  var start = at > 40 ? at - 40 : 0;
  var end = start + max;
  if (end > text.length) {
    end = text.length;
    start = end - max;
    if (start < 0) start = 0;
  }
  // Step back off a high surrogate so the window cannot cut a pair in half.
  if (end < text.length) {
    final before = text.codeUnitAt(end - 1);
    if (before >= 0xD800 && before <= 0xDBFF) end--;
  }
  final lead = start > 0 ? '…' : '';
  final tail = end < text.length ? '…' : '';
  return '$lead${text.substring(start, end)}$tail';
}
