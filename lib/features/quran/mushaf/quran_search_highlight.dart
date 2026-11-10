// Marks the searched words inside a search result's verse (report §6.5 / §7.1).
//
// The search normalizes both sides (diacritics stripped, Alef/Ya/Waw/Ta-Marbuta
// unified — see [normalizeArabicSearchText]), so a match found in the
// *normalized* verse has to be mapped back onto the *original* diacritized
// text before it can be drawn. That mapping is the whole job of this file.
//
// The folded text is built one character at a time, in lockstep with an index
// list back into the original string, which is what makes the mapping exact:
// every rewrite in the shared normalizer is either "drop this character"
// (a diacritic) or "replace this character" (one code unit in, one out), so
// nothing here is an approximation. Should that normalizer ever grow a
// many-characters-to-one rewrite, [_foldChar] must grow it too.
//
// Only the *display* is derived here — the search results themselves come from
// the FTS index unchanged.

import 'package:flutter/material.dart';

import 'package:tawheeed/features/quran/data/quran_helpers.dart';

/// The diacritics / Quranic marks the shared normalizer drops.
final RegExp _diacriticRe = RegExp(
    r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u06DF-\u06E8\u06EA-\u06ED\u08D4-\u08E2\u08E3-\u08FF]');

/// The letter variants the shared normalizer folds to their bare form.
final RegExp _alefRe = RegExp(r'[إأآٱ]');
final RegExp _yaRe = RegExp(r'[ىئ]');
final RegExp _wawRe = RegExp(r'[ؤ]');
final RegExp _taMarbutaRe = RegExp(r'ة');

final RegExp _whitespaceRe = RegExp(r'\s+');

/// Folds ONE character exactly the way [normalizeArabicSearchText] folds a
/// whole string. Returns `''` for a character that normalizes away (a
/// diacritic) and the folded character otherwise.
///
/// Mirrored from the shared normalizer on purpose: the per-character form is
/// what lets [searchMatchRanges] keep an exact index map. Keep the two in
/// step.
String _foldChar(String ch) {
  if (_diacriticRe.hasMatch(ch)) return '';
  if (_alefRe.hasMatch(ch)) return 'ا';
  if (_yaRe.hasMatch(ch)) return 'ي';
  if (_wawRe.hasMatch(ch)) return 'و';
  if (_taMarbutaRe.hasMatch(ch)) return 'ه';
  return ch;
}

/// Every range of [original] whose characters spell one of the query's words.
///
/// Each whitespace-separated word of the (normalized) query is located
/// independently — the same way the search service matches (`_searchWords`:
/// every word must be present, not necessarily adjacent), so a two-word query
/// still marks both words even when they sit apart in the verse.
///
/// The returned ranges are sorted and never overlap; each one reaches over the
/// trailing diacritics of its last letter, so the mark covers the whole
/// rendered word rather than cutting a kasra adrift. Empty when nothing
/// matches — the caller then simply draws the plain text.
List<TextRange> searchMatchRanges(String original, String query) {
  if (original.isEmpty) return const [];
  final words = normalizeArabicSearchText(query.trim())
      .split(_whitespaceRe)
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return const [];

  // Fold the verse, remembering where each folded character came from.
  final folded = StringBuffer();
  final originalIndex = <int>[]; // folded offset -> original offset
  for (var i = 0; i < original.length; i++) {
    final f = _foldChar(original[i]);
    if (f.isEmpty) continue;
    folded.write(f);
    originalIndex.add(i);
  }
  final normalized = folded.toString();
  if (normalized.isEmpty) return const [];

  final hits = <TextRange>[];
  for (final word in words) {
    var from = 0;
    while (true) {
      final at = normalized.indexOf(word, from);
      if (at < 0) break;
      final start = originalIndex[at];
      final last = originalIndex[at + word.length - 1];
      hits.add(TextRange(
        start: start,
        end: _absorbTrailingDiacritics(original, last + 1),
      ));
      from = at + word.length;
    }
  }
  if (hits.isEmpty) return const [];

  hits.sort((a, b) => a.start.compareTo(b.start));
  return List.unmodifiable(_merge(hits));
}

/// The styled subtitle of a result row: [text] with every hit of [query]
/// painted in [matchColor] over [matchBackground].
TextSpan buildSearchHighlightSpan({
  required String text,
  required String query,
  required Color matchColor,
  required Color matchBackground,
}) {
  final ranges = searchMatchRanges(text, query);
  if (ranges.isEmpty) return TextSpan(text: text);

  final children = <InlineSpan>[];
  var cursor = 0;
  for (final r in ranges) {
    if (r.start > cursor) {
      children.add(TextSpan(text: text.substring(cursor, r.start)));
    }
    children.add(TextSpan(
      text: text.substring(r.start, r.end),
      style: TextStyle(
        color: matchColor,
        fontWeight: FontWeight.w700,
        backgroundColor: matchBackground,
      ),
    ));
    cursor = r.end;
  }
  if (cursor < text.length) {
    children.add(TextSpan(text: text.substring(cursor)));
  }
  return TextSpan(children: children);
}

/// Advances past the dropped diacritics that trail the match's last letter.
int _absorbTrailingDiacritics(String original, int end) {
  var e = end;
  while (e < original.length && _foldChar(original[e]).isEmpty) {
    e++;
  }
  return e;
}

/// Folds touching or overlapping ranges into one (sorted input).
List<TextRange> _merge(List<TextRange> sorted) {
  final out = <TextRange>[];
  for (final r in sorted) {
    if (out.isEmpty || r.start > out.last.end) {
      out.add(r);
    } else if (r.end > out.last.end) {
      out[out.length - 1] = TextRange(start: out.last.start, end: r.end);
    }
  }
  return out;
}
