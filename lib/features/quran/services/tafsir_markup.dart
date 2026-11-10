/// Splits a tafsir's stored text into plain and marked-up runs.
///
/// Only one hosted tafsir carries markup (the Kurdish Rebar book): every row
/// wraps its Arabic verse in `<span class="arabic uthmani">` and every
/// honorific in `<span class="saw">`. Measured on the published database —
/// 6236 rows, 15448 verse spans and 2308 honorific spans, no nesting, no
/// stray `<`/`>` outside a span. The other 18 tafsirs and all translations
/// are plain text and take the no-op path.
///
/// The parse is lossless: the tags themselves disappear, every other
/// character survives in order. Only recognised span tags are matched, so a
/// literal `<` in content can never be eaten.
enum TafsirRunKind { plain, verse, honorific }

class TafsirRun {
  const TafsirRun(this.text, [this.kind = TafsirRunKind.plain]);

  final String text;
  final TafsirRunKind kind;

  @override
  String toString() => 'TafsirRun(${kind.name}: $text)';
}

class TafsirMarkup {
  TafsirMarkup._();

  static final RegExp _tag =
      RegExp(r'<span\b[^>]*>|</span\s*>', caseSensitive: false);

  /// True when [text] carries a span tag, i.e. rendering it as a rich span
  /// would change anything.
  static bool hasMarkup(String text) => _tag.hasMatch(text);

  static TafsirRunKind _kindOf(String openTag) =>
      openTag.toLowerCase().contains('saw')
          ? TafsirRunKind.honorific
          : TafsirRunKind.verse;

  static List<TafsirRun> parse(String text) {
    if (!text.contains('<')) return [TafsirRun(text)];

    final runs = <TafsirRun>[];
    var cursor = 0;
    var kind = TafsirRunKind.plain;

    void emit(int end) {
      if (end <= cursor) return;
      final piece = text.substring(cursor, end);
      if (runs.isNotEmpty && runs.last.kind == kind) {
        runs[runs.length - 1] = TafsirRun(runs.last.text + piece, kind);
      } else {
        runs.add(TafsirRun(piece, kind));
      }
    }

    for (final match in _tag.allMatches(text)) {
      emit(match.start);
      final tag = match.group(0)!;
      kind = tag.startsWith('</') ? TafsirRunKind.plain : _kindOf(tag);
      cursor = match.end;
    }
    emit(text.length);
    return runs;
  }

  /// The same text with span tags removed — for share bodies and copy, which
  /// are plain strings.
  static String strip(String text) {
    if (!text.contains('<')) return text;
    return parse(text).map((r) => r.text).join();
  }
}
