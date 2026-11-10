import 'dart:convert';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/latinize_json_digits.dart';

// ═══════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════

enum ScienceLevel { beginner, intermediate, advanced }

enum ScienceCategory {
  foundational('علوم بنیادین', Icons.auto_awesome_outlined),
  textual('علوم متنی', Icons.menu_book_outlined),
  deductive('علوم استنباطی', Icons.psychology_outlined),
  educational('علوم تربیتی', Icons.favorite_outlined),
  historical('علوم تاریخی', Icons.history_outlined),
  applied('علوم کاربردی', Icons.build_outlined);

  final String label;
  final IconData icon;
  const ScienceCategory(this.label, this.icon);

  static ScienceCategory fromString(String value) {
    return ScienceCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ScienceCategory.foundational,
    );
  }
}

class ScienceData {
  final String id;
  final String title;
  final String icon;
  final ScienceCategory category;
  final ScienceLevel level;
  final String definition;
  final String importance;
  final String scope;
  final List<String> subtopics;
  final List<TermData> keyTerms;
  final List<FaqData> faqs;
  final List<String> evidence;
  final List<String> relatedSciences;
  final List<String> commonMistakes;
  final String application;
  final List<ChapterData> chapters;

  /// Whether the science was explicitly marked as finished. Sciences whose
  /// content is still being written (placeholder entries) carry `complete:
  /// false` so the UI can show a «به‌زودی» badge instead of pretending the
  /// entry is finished.
  final bool complete;

  const ScienceData({
    required this.id,
    required this.title,
    required this.icon,
    required this.category,
    required this.level,
    required this.definition,
    required this.importance,
    required this.scope,
    required this.subtopics,
    required this.keyTerms,
    required this.faqs,
    required this.relatedSciences,
    this.evidence = const [],
    this.commonMistakes = const [],
    this.application = '',
    this.chapters = const [],
    this.complete = true,
  });

  /// A science counts as complete unless it is explicitly flagged as a draft
  /// (`complete: false` in JSON). The flag is the single source of truth:
  /// tool-style entries may have real content but no chapter structure, so
  /// chapter count is not a signal.
  bool get isComplete => complete;

  factory ScienceData.fromJson(Map<String, dynamic> json) {
    return ScienceData(
      id: json['id'] as String,
      title: json['title'] as String,
      icon: json['icon'] as String,
      category: ScienceCategory.fromString(json['category'] as String),
      level: ScienceLevel.values.firstWhere(
        (e) => e.name == (json['level'] as String?),
        orElse: () => ScienceLevel.beginner,
      ),
      definition: json['definition'] as String,
      importance: json['importance'] as String,
      scope: json['scope'] as String,
      subtopics: (json['subtopics'] as List?)?.cast<String>() ?? const [],
      keyTerms: (json['keyTerms'] as List?)
              ?.map((e) => TermData.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      faqs: (json['faqs'] as List?)
              ?.map((e) => FaqData.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      evidence: (json['evidence'] as List?)?.cast<String>() ?? const [],
      relatedSciences:
          (json['relatedSciences'] as List?)?.cast<String>() ?? const [],
      commonMistakes:
          (json['commonMistakes'] as List?)?.cast<String>() ?? const [],
      application: json['application'] as String? ?? '',
      chapters: (json['chapters'] as List?)
              ?.map((e) => ChapterData.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      complete: json['complete'] as bool? ?? true,
    );
  }

  bool matchesSearch(String q) {
    if (title.contains(q) ||
        definition.contains(q) ||
        category.label.contains(q) ||
        scope.contains(q) ||
        importance.contains(q) ||
        application.contains(q)) {
      return true;
    }
    for (final t in subtopics) {
      if (t.contains(q)) return true;
    }
    for (final t in keyTerms) {
      if (t.term.contains(q) || t.definition.contains(q)) return true;
    }
    for (final e in evidence) {
      if (e.contains(q)) return true;
    }
    for (final m in commonMistakes) {
      if (m.contains(q)) return true;
    }
    for (final f in faqs) {
      if (f.question.contains(q) || f.answer.contains(q)) return true;
    }
    for (final c in chapters) {
      if (c.title.contains(q)) return true;
      if (c.body != null && c.body!.contains(q)) return true;
      for (final sub in c.subsections) {
        if (sub.title != null && sub.title!.contains(q)) return true;
        if (sub.body != null && sub.body!.contains(q)) return true;
        for (final item in sub.items) {
          if (item.contains(q)) return true;
        }
        for (final v in sub.verses) {
          if (v.contains(q)) return true;
        }
      }
    }
    return false;
  }

  String? findSnippet(String q) {
    if (q.isEmpty) return null;
    for (final t in subtopics) {
      if (t.contains(q)) return t;
    }
    for (final t in keyTerms) {
      if (t.definition.contains(q)) return '${t.term}: ${t.definition}';
    }
    for (final e in evidence) {
      if (e.contains(q)) return e;
    }
    for (final f in faqs) {
      if (f.question.contains(q)) return 'سؤال: ${f.question}';
      if (f.answer.contains(q)) return f.answer;
    }
    for (final m in commonMistakes) {
      if (m.contains(q)) return 'اشتباه: $m';
    }
    for (final c in chapters) {
      if (c.title.contains(q)) return 'فصل: ${c.title}';
      if (c.body != null && c.body!.contains(q)) return c.body!;
      for (final sub in c.subsections) {
        if (sub.title != null && sub.title!.contains(q)) {
          final subText = sub.body ?? '';
          return sub.title! + (subText.isEmpty ? '' : ': $subText');
        }
        if (sub.body != null && sub.body!.contains(q)) return sub.body!;
        for (final item in sub.items) {
          if (item.contains(q)) return item;
        }
        for (final v in sub.verses) {
          if (v.contains(q)) return v;
        }
      }
    }
    if (scope.contains(q)) return scope;
    if (importance.contains(q)) return importance;
    return null;
  }
}

class ChapterData {
  final String title;
  final String? body;
  final List<ChapterSubsection> subsections;

  const ChapterData({
    required this.title,
    this.body,
    this.subsections = const [],
  });

  factory ChapterData.fromJson(Map<String, dynamic> json) {
    return ChapterData(
      title: json['title'] as String,
      body: json['body'] as String?,
      subsections: (json['subsections'] as List?)
              ?.map((e) =>
                  ChapterSubsection.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
    );
  }
}

class ChapterSubsection {
  final String? title;
  final String? body;
  final List<String> items;
  final List<String> verses;

  const ChapterSubsection({
    this.title,
    this.body,
    this.items = const [],
    this.verses = const [],
  });

  factory ChapterSubsection.fromJson(Map<String, dynamic> json) {
    return ChapterSubsection(
      title: json['title'] as String?,
      body: json['body'] as String?,
      items: (json['items'] as List?)?.cast<String>() ?? const [],
      verses: (json['verses'] as List?)?.cast<String>() ?? const [],
    );
  }
}

class TermData {
  final String term;
  final String definition;
  const TermData({required this.term, required this.definition});

  factory TermData.fromJson(Map<String, dynamic> json) {
    return TermData(
      term: json['term'] as String,
      definition: json['definition'] as String,
    );
  }
}

class FaqData {
  final String question;
  final String answer;
  const FaqData({required this.question, required this.answer});

  factory FaqData.fromJson(Map<String, dynamic> json) {
    return FaqData(
      question: json['question'] as String,
      answer: json['answer'] as String,
    );
  }
}

// ═══════════════════════════════════════════
// MAIN CONTENT HOLDER
// ═══════════════════════════════════════════

class SciencesContent {
  SciencesContent._();

  static const Color accent =
      Color(0xFF3F51B5); // نیلی — همرنگ بخش علوم اسلامی در «بیشتر»

  static List<ScienceData>? _cached;
  static bool _loadAttempted = false;

  static Future<void> load() async {
    if (_loadAttempted) return;
    _loadAttempted = true;
    try {
      final jsonString =
          await rootBundle.loadString('assets/content/sciences.json');
      // 1.3 MB of JSON: decode + model mapping off the UI isolate so the
      // first open of Islamic Sciences never drops frames.
      _cached = await compute(_decodeSciences, jsonString);
      AppLogger.info(
          'SciencesContent', 'Loaded ${_cached!.length} sciences from JSON');
    } catch (e) {
      AppLogger.warning('SciencesContent', 'Failed to load sciences.json: $e');
      _cached = [];
    }
  }

  static List<ScienceData> get all {
    if (_cached == null) {
      AppLogger.warning(
          'SciencesContent', 'Sciences not loaded yet — call load() first');
      return [];
    }
    return _cached!;
  }

  static bool get isLoaded => _cached != null;

  static const categoryOrder = [
    ScienceCategory.foundational,
    ScienceCategory.textual,
    ScienceCategory.deductive,
    ScienceCategory.educational,
    ScienceCategory.historical,
    ScienceCategory.applied,
  ];

  /// GROUP ACCENT TABLE — the flat redesign's per-category Identity hue +
  /// glyph. All values are existing [TopicHues]/Material tokens (no raw
  /// colors invented); the registry test asserts every category has exactly
  /// one entry and every item groups under a category WITH an accent.
  // NOTE: hex literals below are the canonical TopicHues values aliased here
  // because this data layer must not depend on the presentation palette
  // (tests decode the registry without the theme kit); identical values so
  // they stay in visual sync with the Single color source.
  static const Map<ScienceCategory, (Color, IconData)> categoryVisuals = {
    ScienceCategory.foundational: (
      Color(0xFF1B5E20),
      Icons.category_outlined
    ), // khatm green
    ScienceCategory.textual: (
      Color(0xFF8D6E63),
      Icons.menu_book_outlined
    ), // books brown
    ScienceCategory.deductive: (
      Color(0xFF5C6BC0),
      Icons.psychology_outlined
    ), // personalTools indigo
    ScienceCategory.educational: (
      Color(0xFFEC407A),
      Icons.favorite_outline
    ), // period pink
    ScienceCategory.historical: (
      Color(0xFFBF360C),
      Icons.history_edu_outlined
    ), // آجری (deep orange 900) — وام‌گرفته از درر؛ دیگر نیلی ماه نیست
    ScienceCategory.applied: (
      Color(0xFF0097A7),
      Icons.handyman_outlined
    ), // study cyan
  };

  /// Accent of [cat], falling back to the module accent.
  static Color accentOf(ScienceCategory cat) =>
      categoryVisuals[cat]?.$1 ?? accent;

  /// Glyph of [cat] (replaces the per-item emoji in the redesigned UI).
  static IconData glyphOf(ScienceCategory cat) =>
      categoryVisuals[cat]?.$2 ?? cat.icon;

  static List<ScienceData> byCategory(ScienceCategory cat) =>
      all.where((s) => s.category == cat).toList();

  static ScienceData? byId(String id) {
    try {
      return all.firstWhere((s) => s.id == id);
    } catch (e) {
      AppLogger.warning('sciences_content error', e.toString());
      return null;
    }
  }
}

/// Decodes the bundled sciences payload. Top-level so it can run on a
/// background isolate via [compute] (see [SciencesContent.load]).
List<ScienceData> _decodeSciences(String jsonString) {
  final decoded = latinizeJsonDigits(jsonDecode(jsonString)) as List;
  return decoded
      .map((e) => ScienceData.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}
