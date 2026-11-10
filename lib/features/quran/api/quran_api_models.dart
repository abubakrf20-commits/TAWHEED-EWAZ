/// Typed models for the Quran Foundation Content API (v4).
///
/// Field names below mirror the REAL API responses verified from
/// https://api-docs.quran.foundation — see each class doc for the endpoint.
library;

/// A single word of a verse. The API may return `code_v2` as an HTML entity
/// (e.g. `&#xfb51;`) in some payloads and as a raw private-use character in
/// others, so [glyphV2] decodes both forms.
class VerseWord {
  final int id;
  final int position;
  final String? audioUrl;
  final String
      charTypeName; // 'word' | 'end' | 'pause' | 'sajdah' | 'rub-el-hizb'
  final String? textUthmani;
  final String? textQpcHafs;
  final String? codeV1;
  final String? codeV2;
  final int? pageNumber;
  final int? lineNumber;
  final String? translation;

  const VerseWord({
    required this.id,
    required this.position,
    this.audioUrl,
    required this.charTypeName,
    this.textUthmani,
    this.textQpcHafs,
    this.codeV1,
    this.codeV2,
    this.pageNumber,
    this.lineNumber,
    this.translation,
  });

  factory VerseWord.fromJson(Map<String, dynamic> json) {
    final trans = json['translation'];
    return VerseWord(
      id: json['id'] as int? ?? 0,
      position: json['position'] as int? ?? 0,
      audioUrl: json['audio_url'] as String?,
      charTypeName: (json['char_type_name'] as String?) ?? 'word',
      textUthmani: json['text_uthmani'] as String?,
      textQpcHafs: json['text_qpc_hafs'] as String?,
      codeV1: json['code_v1'] as String?,
      codeV2: json['code_v2'] as String?,
      pageNumber: json['page_number'] as int?,
      lineNumber: json['line_number'] as int?,
      translation:
          trans is Map<String, dynamic> ? trans['text'] as String? : null,
    );
  }

  /// True for a normal Quranic word (glyph-rendered). End/pause/sajdah
  /// markers are rendered with the Unicode fallback font instead.
  bool get isWord => charTypeName == 'word';

  /// Decoded QCF V2 glyph code (handles HTML entities like `&#xfb51;`).
  String get glyphV2 {
    final raw = codeV2;
    if (raw == null || raw.isEmpty) return '';
    return _decodeHtmlEntities(raw);
  }

  /// Text to render with the Unicode fallback font while the page font is
  /// still loading, or for non-word markers.
  String get unicodeText {
    return textQpcHafs ?? textUthmani ?? '';
  }

  static String _decodeHtmlEntities(String input) {
    if (!input.contains('&#')) return input;
    final buffer = StringBuffer();
    var i = 0;
    while (i < input.length) {
      final amp = input.indexOf('&#', i);
      if (amp < 0) {
        buffer.write(input.substring(i));
        break;
      }
      buffer.write(input.substring(i, amp));
      final semi = input.indexOf(';', amp + 2);
      if (semi < 0) {
        buffer.write(input.substring(amp));
        break;
      }
      final entity = input.substring(amp + 2, semi);
      final hex = entity.startsWith('x') || entity.startsWith('X');
      final digits = hex ? entity.substring(1) : entity;
      final code = int.tryParse(digits, radix: hex ? 16 : 10);
      if (code != null && code > 0) {
        buffer.writeCharCode(code);
      }
      i = semi + 1;
    }
    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'position': position,
        'audio_url': audioUrl,
        'char_type_name': charTypeName,
        'text_uthmani': textUthmani,
        'text_qpc_hafs': textQpcHafs,
        'code_v1': codeV1,
        'code_v2': codeV2,
        'page_number': pageNumber,
        'line_number': lineNumber,
        if (translation != null) 'translation': {'text': translation},
      };
}

/// A verse of the mushaf. `words` are returned in correct Mushaf order.
class QuranVerse {
  final int id;
  final int chapterId;
  final int verseNumber;
  final String verseKey; // e.g. '2:255'
  final int? verseIndex;
  final int? juzNumber;
  final int? hizbNumber;
  final int? rubElHizbNumber;
  final int pageNumber;
  final String? textUthmani;
  final List<VerseWord> words;

  const QuranVerse({
    required this.id,
    required this.chapterId,
    required this.verseNumber,
    required this.verseKey,
    this.verseIndex,
    this.juzNumber,
    this.hizbNumber,
    this.rubElHizbNumber,
    required this.pageNumber,
    this.textUthmani,
    this.words = const [],
  });

  factory QuranVerse.fromJson(Map<String, dynamic> json) {
    final rawWords = json['words'];
    // Prelive responses omit `chapter_id` — derive it from `verse_key`
    // ("chapter:verse") so surah headers, audio and navigation stay correct.
    var chapterId = json['chapter_id'] as int? ?? 0;
    if (chapterId <= 0) {
      final vk = json['verse_key'] as String? ?? '';
      final colon = vk.indexOf(':');
      if (colon > 0) chapterId = int.tryParse(vk.substring(0, colon)) ?? 0;
    }
    return QuranVerse(
      id: json['id'] as int? ?? 0,
      chapterId: chapterId,
      verseNumber: json['verse_number'] as int? ?? 0,
      verseKey: json['verse_key'] as String? ?? '',
      verseIndex: json['verse_index'] as int?,
      juzNumber: json['juz_number'] as int?,
      hizbNumber: json['hizb_number'] as int?,
      rubElHizbNumber: json['rub_el_hizb_number'] as int?,
      pageNumber: json['page_number'] as int? ?? 0,
      textUthmani: json['text_uthmani'] as String?,
      words: rawWords is List
          ? rawWords
              .whereType<Map<String, dynamic>>()
              .map(VerseWord.fromJson)
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'chapter_id': chapterId,
        'verse_number': verseNumber,
        'verse_key': verseKey,
        'verse_index': verseIndex,
        'juz_number': juzNumber,
        'hizb_number': hizbNumber,
        'rub_el_hizb_number': rubElHizbNumber,
        'page_number': pageNumber,
        'text_uthmani': textUthmani,
        'words': [for (final w in words) w.toJson()],
      };
}

/// A reciter entry from `GET /resources/chapter_reciters`.
class ChapterReciter {
  final int id;
  final String name;
  final String? translatedName;
  final String? style;
  final String? qirat;

  const ChapterReciter({
    required this.id,
    required this.name,
    this.translatedName,
    this.style,
    this.qirat,
  });

  factory ChapterReciter.fromJson(Map<String, dynamic> json) {
    String? nestedName(dynamic v) {
      if (v is Map<String, dynamic>) return v['name'] as String?;
      if (v is String) return v;
      return null;
    }

    return ChapterReciter(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? json['reciter_name'] as String? ?? '',
      translatedName: nestedName(json['translated_name']),
      style: nestedName(json['style']),
      qirat: nestedName(json['qirat']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'reciter_name': name,
        'translated_name':
            translatedName == null ? null : {'name': translatedName},
        'style': style == null ? null : {'name': style},
        'qirat': qirat == null ? null : {'name': qirat},
      };

  /// Best display name: translated (persian when requested) else English.
  String get displayName => translatedName ?? name;

  String get subtitle {
    final parts = [
      if (style != null && style!.isNotEmpty) style!,
      if (qirat != null && qirat!.isNotEmpty) qirat!,
    ];
    return parts.join(' · ');
  }
}

/// One page entry of `GET /pages/lookup`.
class PageInfo {
  final String from;
  final String to;
  final String firstVerseKey;
  final String lastVerseKey;

  const PageInfo({
    required this.from,
    required this.to,
    required this.firstVerseKey,
    required this.lastVerseKey,
  });

  factory PageInfo.fromJson(Map<String, dynamic> json) => PageInfo(
        from: json['from'] as String? ?? '',
        to: json['to'] as String? ?? '',
        firstVerseKey: json['first_verse_key'] as String? ?? '',
        lastVerseKey: json['last_verse_key'] as String? ?? '',
      );
}

/// Response of `GET /pages/lookup`.
class PagesLookup {
  final String rangeFrom;
  final String rangeTo;
  final Map<int, PageInfo> pages;
  final int totalPage;

  const PagesLookup({
    required this.rangeFrom,
    required this.rangeTo,
    this.pages = const {},
    this.totalPage = 0,
  });

  factory PagesLookup.fromJson(Map<String, dynamic> json) {
    final rawPages = json['pages'];
    final range = json['lookup_range'];
    return PagesLookup(
      rangeFrom:
          range is Map<String, dynamic> ? (range['from'] as String? ?? '') : '',
      rangeTo:
          range is Map<String, dynamic> ? (range['to'] as String? ?? '') : '',
      pages: rawPages is Map<String, dynamic>
          ? {
              for (final e in rawPages.entries)
                if (int.tryParse(e.key) != null &&
                    e.value is Map<String, dynamic>)
                  int.parse(e.key):
                      PageInfo.fromJson(e.value as Map<String, dynamic>),
            }
          : const {},
      totalPage: json['total_page'] as int? ?? 0,
    );
  }
}
