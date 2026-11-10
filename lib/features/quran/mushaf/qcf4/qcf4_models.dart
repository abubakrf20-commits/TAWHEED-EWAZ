import 'dart:convert';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Data models for the QCF4 (quran-qcf4) mushaf dataset
/// (MohamadHajjRabee/quran-qcf4, Madinah Mushaf 1441 AH).
///
/// The schema mirrors `pages/NNN.json`, `verses.json`, `font-map.json`,
/// `index.json` and `qbsml.json` from that repo. Each model parses
/// defensively (optional fields tolerated) so the reader never crashes on a
/// slightly-out-of-date cached page.

/// Renderable word/ornament on a line.
class Qcf4Word {
  /// Unicode code point (decimal) of the PUA glyph.
  final int? code;

  /// The actual PUA character to render (`\uF100`, …). Prefer `char` over
  /// re-deriving [code] — it is what the demo writes into each span.
  final String char;

  /// Font family this glyph comes from, e.g. `QCF4_Hafs_01` or `QCF4_QBSML`.
  final String font;

  /// Huma-readable Arabic (`بِسْمِ`, `الفاتحة`, or the verse-end label `V1`).
  final String? text;

  /// `word`, `end`, `surah_header`, `bismillah` or `quarter`.
  final String type;

  /// `sura:ayah` key for `word` and `end` words.
  final String? verseKey;

  /// Quran.com word position (1-based) within its verse, for `word` type.
  final int? position;

  /// Surah id for `surah_header` / `bismillah`.
  final int? sura;

  const Qcf4Word({
    this.code,
    required this.char,
    required this.font,
    this.text,
    required this.type,
    this.verseKey,
    this.position,
    this.sura,
  });

  /// Glyphs laid out on their own full-width centered line (surah banner and
  /// the Bismillah). Quarter-hizb markers (۞) and verse-end glyphs stay inline
  /// with the words of their physical Mushaf line.
  bool get isCentered => type == 'surah_header' || type == 'bismillah';

  /// Whether this is a Quranic word with a usable verse key (for highlight).
  bool get isQuranicWord => type == 'word' && verseKey != null;

  factory Qcf4Word.fromJson(Map<String, dynamic> json) {
    return Qcf4Word(
      code: _asInt(json['code']),
      char: _asString(json['char']) ?? '',
      font: _asString(json['font']) ?? 'QCF4_Hafs_01',
      text: _asString(json['text']),
      type: _asString(json['type']) ?? 'word',
      verseKey: _asString(json['verse_key']),
      position: _asInt(json['position']),
      sura: _asInt(json['sura']),
    );
  }
}

/// One physical line of the Mushaf page.
class Qcf4Line {
  final int line;
  final List<Qcf4Word> words;

  const Qcf4Line({required this.line, required this.words});

  factory Qcf4Line.fromJson(Map<String, dynamic> json) {
    final wordsJson = json['words'];
    final words = <Qcf4Word>[];
    if (wordsJson is List) {
      for (final w in wordsJson) {
        if (w is Map<String, dynamic>) words.add(Qcf4Word.fromJson(w));
      }
    }
    return Qcf4Line(
      line: _asInt(json['line']) ?? 0,
      words: words,
    );
  }
}

/// One surah that appears on a page.
class Qcf4Surah {
  final int id;
  final String name;
  final String nameArabic;
  final int? verseStart;
  final int? verseEnd;

  const Qcf4Surah({
    required this.id,
    required this.name,
    required this.nameArabic,
    this.verseStart,
    this.verseEnd,
  });

  factory Qcf4Surah.fromJson(Map<String, dynamic> json) {
    return Qcf4Surah(
      id: _asInt(json['id']) ?? 0,
      name: _asString(json['name']) ?? '',
      nameArabic: _asString(json['name_arabic']) ?? '',
      verseStart: _asInt(json['verse_start']),
      verseEnd: _asInt(json['verse_end']),
    );
  }
}

/// A single Mushaf page (the content of `pages/NNN.json`).
class Qcf4Page {
  final int page;
  final String font;
  final List<Qcf4Surah> surahs;
  final List<Qcf4Line> lines;

  const Qcf4Page({
    required this.page,
    required this.font,
    required this.surahs,
    required this.lines,
  });

  factory Qcf4Page.fromJson(Map<String, dynamic> json) {
    final surahsJson = json['surahs'];
    final surahs = <Qcf4Surah>[];
    if (surahsJson is List) {
      for (final s in surahsJson) {
        if (s is Map<String, dynamic>) surahs.add(Qcf4Surah.fromJson(s));
      }
    }
    final linesJson = json['lines'];
    final lines = <Qcf4Line>[];
    if (linesJson is List) {
      for (final l in linesJson) {
        if (l is Map<String, dynamic>) lines.add(Qcf4Line.fromJson(l));
      }
    }
    return Qcf4Page(
      page: _asInt(json['page']) ?? 0,
      font: _asString(json['font']) ?? 'QCF4_Hafs_01',
      surahs: surahs,
      lines: lines,
    );
  }

  Map<String, dynamic> toJson() => {
        'page': page,
        'font': font,
        'surahs': surahs
            .map((s) => {
                  'id': s.id,
                  'name': s.name,
                  'name_arabic': s.nameArabic,
                  'verse_start': s.verseStart,
                  'verse_end': s.verseEnd,
                })
            .toList(),
        'lines': lines
            .map((l) => {
                  'line': l.line,
                  'words': l.words
                      .map((w) => {
                            'code': w.code,
                            'char': w.char,
                            'font': w.font,
                            'text': w.text,
                            'type': w.type,
                            'verse_key': w.verseKey,
                            'position': w.position,
                            'sura': w.sura,
                          })
                      .toList(),
                })
            .toList(),
      };

  /// Encode back to compact JSON for disk caching.
  String encode() => jsonEncode(toJson());

  static Qcf4Page? decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return Qcf4Page.fromJson(decoded);
    } catch (_) {
      AppLogger.warning('qcf4_models', 'operation failed');
      return null;
    }
  }
}

/// A line-range entry in `verses.json` for one verse.
class Qcf4VerseLineRef {
  final int line;
  final int wordStart;
  final int wordEnd;

  const Qcf4VerseLineRef({
    required this.line,
    required this.wordStart,
    required this.wordEnd,
  });

  factory Qcf4VerseLineRef.fromJson(Map<String, dynamic> json) =>
      Qcf4VerseLineRef(
        line: _asInt(json['line']) ?? 0,
        wordStart: _asInt(json['word_start']) ?? 0,
        wordEnd: _asInt(json['word_end']) ?? 0,
      );
}

/// Location of one verse across one or more lines (`verses.json` entry).
class Qcf4VerseLocation {
  final int page;
  final List<Qcf4VerseLineRef> lines;

  const Qcf4VerseLocation({required this.page, required this.lines});

  factory Qcf4VerseLocation.fromJson(Map<String, dynamic> json) {
    final linesJson = json['lines'];
    final lines = <Qcf4VerseLineRef>[];
    if (linesJson is List) {
      for (final l in linesJson) {
        if (l is Map<String, dynamic>) lines.add(Qcf4VerseLineRef.fromJson(l));
      }
    }
    return Qcf4VerseLocation(page: _asInt(json['page']) ?? 0, lines: lines);
  }
}

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

String? _asString(dynamic v) => v is String ? v : null;
