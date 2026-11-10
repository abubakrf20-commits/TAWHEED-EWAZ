// Hoisted pattern objects — both functions run per content piece over every
// bundled guide, so a pattern rebuilt per call is pure overhead.
final RegExp _reDiacritics = RegExp(
  r'[\u0610-\u061A\u0640\u064B-\u065F\u0670'
  r'\u06D6-\u06ED\u08D3-\u08FF\uFD3E\uFD3F\uFDFA\uFDFD]',
);
final RegExp _reWhitespaceRun = RegExp(r'\s+');

/// Normalizes Arabic/Persian text for forgiving search matching.
///
/// Handles the classic failures when searching Islamic texts with a Persian
/// keyboard: Arabic yeh/kaf vs Persian ones (ي→ی، ك→ک), hamza carriers,
/// alef forms, taa marbuta, alef maksura — plus stripping every haraka,
/// Quranic pause/annotation mark, tatweel and ornate punctuation so that
/// «اعوذ بك» finds «أَعُوذُ بِكَ» inside a fully vocalized mushaf-style text.
String normalizeForSearch(String input) {
  var s = input.toLowerCase();

  // Harakat, Quranic annotation/pause marks, honorifics, tatweel, symbols.
  s = s.replaceAll(_reDiacritics, '');

  // Letter unification.
  s = s
      .replaceAll('\u0622', '\u0627') // آ → ا
      .replaceAll('\u0623', '\u0627') // أ → ا
      .replaceAll('\u0625', '\u0627') // إ → ا
      .replaceAll('\u0671', '\u0627') // ٱ → ا
      .replaceAll('\u0629', '\u0647') // ة → ه
      .replaceAll('\u0649', '\u06CC') // ى → ی
      .replaceAll('\u064A', '\u06CC') // ي → ی
      .replaceAll('\u0643', '\u06A9') // ك → ک
      .replaceAll('\u0626', '\u06CC') // ئ → ی
      .replaceAll('\u0624', '\u0648') // ؤ → و
      .replaceAll('\u0621', ''); // ء → ''

  // Collapse whitespace runs into single spaces.
  return s.replaceAll(_reWhitespaceRun, ' ').trim();
}

/// Converts Persian (۰-۹) and Arabic-Indic (٠-٩) digits to ASCII.
String toAsciiDigits(String input) {
  var hasEasternDigits = false;
  for (var i = 0; i < input.length; i++) {
    final u = input.codeUnitAt(i);
    if ((u >= 0x06F0 && u <= 0x06F9) || (u >= 0x0660 && u <= 0x0669)) {
      hasEasternDigits = true;
      break;
    }
  }
  if (!hasEasternDigits) return input;
  const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  var out = input;
  for (var i = 0; i < 10; i++) {
    out = out.replaceAll(fa[i], '$i').replaceAll(ar[i], '$i');
  }
  return out;
}

/// The tightest search key there is: [normalizeForSearch] plus ZWNJ and every
/// space removed, so a typed «قبله نما» finds «قبله‌نما», «کتاب خانه» finds
/// «کتابخانه», and «بسم الله» finds «بِسْمِ اللهِ» however the source spells
/// its spacing. Used for short, indexable strings — a section title or a
/// whole content block folded at once — where `contains` replaces word
/// boundaries.
String normalizeSearchKey(String input) {
  final folded = toAsciiDigits(normalizeForSearch(
    input.replaceAll('\u200c', ''),
  ));
  // normalizeForSearch already collapsed every whitespace run to one ASCII
  // space, so this is the same as stripping `\s+` — without a regex pass.
  return folded.replaceAll(' ', '');
}

/// [normalizeSearchKey] with a map back to the ORIGINAL string: `map[i]` is
/// the index in [input] of the character that produced key index `i`.
///
/// Kept character-by-character so the two functions are equivalent by
/// construction (a fold, a dropped mark or a digit swap never shifts the
/// map), which is what lets a normalized hit be projected back onto the
/// verbatim text the screen will paint. The end of a match is resolved off
/// the next mapped index, or the text's own length at its tail.
({String key, List<int> map}) searchKeyWithMap(String input) {
  final buf = StringBuffer();
  final map = <int>[];
  for (var i = 0; i < input.length; i++) {
    final code = input.codeUnitAt(i);
    // ZWNJ, harakat, Quranic marks, tatweel and ornate punctuation.
    if (code == 0x200C ||
        (code >= 0x0610 && code <= 0x061A) ||
        code == 0x0640 ||
        (code >= 0x064B && code <= 0x065F) ||
        code == 0x0670 ||
        (code >= 0x06D6 && code <= 0x06ED) ||
        (code >= 0x08D3 && code <= 0x08FF) ||
        code == 0xFD3E ||
        code == 0xFD3F ||
        code == 0xFDFA ||
        code == 0xFDFD ||
        _isSearchSpace(code)) {
      continue;
    }
    final out = switch (code) {
      0x0622 || 0x0623 || 0x0625 || 0x0671 => '\u0627',
      0x0629 => '\u0647',
      0x0649 || 0x064A || 0x0626 => '\u06CC',
      0x0643 => '\u06A9',
      0x0624 => '\u0648',
      0x0621 => '',
      >= 0x06F0 && <= 0x06F9 => String.fromCharCode(0x30 + code - 0x06F0),
      >= 0x0660 && <= 0x0669 => String.fromCharCode(0x30 + code - 0x0660),
      _ => input[i].toLowerCase(),
    };
    for (var k = 0; k < out.length; k++) {
      map.add(i);
    }
    buf.write(out);
  }
  return (key: buf.toString(), map: map);
}

/// The exact substring of [text] that [query] matched after folding — the
/// literal a destination screen can search for and paint, because its own
/// per-character normalizer sees this same span. `''` when nothing matches.
String matchedLiteral(String text, String query) {
  final folded = searchKeyWithMap(text);
  final needle = searchKeyWithMap(query).key;
  if (needle.isEmpty || folded.key.isEmpty) return '';
  final at = folded.key.indexOf(needle);
  if (at < 0) return '';
  final start = folded.map[at];
  final after = at + needle.length;
  final end = after < folded.map.length ? folded.map[after] : text.length;
  if (end <= start) return '';
  return text.substring(start, end).trim();
}

/// The characters ECMAScript `\s` covers — the set [normalizeForSearch]
/// collapses. Spelled out because key folding drops whitespace entirely.
bool _isSearchSpace(int c) =>
    c == 0x20 ||
    c == 0x09 ||
    c == 0x0A ||
    c == 0x0B ||
    c == 0x0C ||
    c == 0x0D ||
    c == 0xA0 ||
    c == 0x1680 ||
    (c >= 0x2000 && c <= 0x200A) ||
    c == 0x2028 ||
    c == 0x2029 ||
    c == 0x202F ||
    c == 0x205F ||
    c == 0x3000 ||
    c == 0xFEFF;
