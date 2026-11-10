class DuaModel {
  final String id;
  final String title;
  final String arabicText;
  final String translation;
  final String? transliteration;
  final String source;
  final String? category;
  final bool isFavorite;
  final bool isCustom;
  final DateTime? createdAt;

  /// Intro line before the dhikr, e.g. «رسول اکرم ص فرمود: ...».
  final String lead;

  /// معنی کلمات — glossary lines («term: meaning»).
  final List<String> words;

  /// رهنمود حدیث — guidance paragraphs.
  final List<String> guidance;

  /// فوائد حدیث — benefit bullets.
  final List<String> benefits;

  /// منابع — takhrij/reference lines.
  final List<String> refs;

  /// Position inside its chapter (1-based) and the chapter number (0 for
  /// intro sections).
  final int seq;
  final int chapterNo;

  const DuaModel({
    required this.id,
    required this.title,
    required this.arabicText,
    required this.translation,
    this.transliteration,
    required this.source,
    this.category,
    this.isFavorite = false,
    this.isCustom = false,
    this.createdAt,
    this.lead = '',
    this.words = const [],
    this.guidance = const [],
    this.benefits = const [],
    this.refs = const [],
    this.seq = 0,
    this.chapterNo = 0,
  });

  bool get hasCommentary =>
      words.isNotEmpty || guidance.isNotEmpty || benefits.isNotEmpty;

  DuaModel copyWith({
    String? id,
    String? title,
    String? arabicText,
    String? translation,
    String? transliteration,
    String? source,
    String? category,
    bool? isFavorite,
    bool? isCustom,
    DateTime? createdAt,
    String? lead,
    List<String>? words,
    List<String>? guidance,
    List<String>? benefits,
    List<String>? refs,
    int? seq,
    int? chapterNo,
  }) {
    return DuaModel(
      id: id ?? this.id,
      title: title ?? this.title,
      arabicText: arabicText ?? this.arabicText,
      translation: translation ?? this.translation,
      transliteration: transliteration ?? this.transliteration,
      source: source ?? this.source,
      category: category ?? this.category,
      isFavorite: isFavorite ?? this.isFavorite,
      isCustom: isCustom ?? this.isCustom,
      createdAt: createdAt ?? this.createdAt,
      lead: lead ?? this.lead,
      words: words ?? this.words,
      guidance: guidance ?? this.guidance,
      benefits: benefits ?? this.benefits,
      refs: refs ?? this.refs,
      seq: seq ?? this.seq,
      chapterNo: chapterNo ?? this.chapterNo,
    );
  }
}
