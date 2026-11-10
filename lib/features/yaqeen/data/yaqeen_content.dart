import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:tawheeed/shared/utils/arabic_search.dart';
import 'package:tawheeed/shared/utils/latinize_json_digits.dart';

/// ═══════════════════════════════════════════════════════════════
/// YaqeenContent — دادهٔ بخش «یقین» (تثبیت اعتقادی و پاسخ به شبهات)
///
/// محتوا از نقشهٔ `yaqeen.docx` با ابزار `tools/build_yaqeen_content.py`
/// به `assets/content/yaqeen.json` تبدیل شده و داخل باندل عرضه می‌شود
/// (بدون نیاز به دانلود). ساختار: 4 مسیر → فصل → درس → بخش‌های گفتار.
///
/// فلسفهٔ بخش: «بهترین دفاع، هجوم است» — 80٪ تثبیت یقین و باورها،
/// 20٪ پاسخ به شبهات، بر اساس عقیدهٔ اهل سنت و جماعت.
/// ═══════════════════════════════════════════════════════════════

class YaqeenDoubt {
  final int number;
  final String question;
  final List<String> explanation;
  final List<String> body;
  final List<String> conclusion;

  const YaqeenDoubt({
    required this.number,
    required this.question,
    required this.explanation,
    required this.body,
    required this.conclusion,
  });

  factory YaqeenDoubt.fromJson(Map<String, dynamic> m) => YaqeenDoubt(
        number: (m['number'] as num?)?.toInt() ?? 0,
        question: (m['question'] as String?)?.trim() ?? '',
        explanation: [
          for (final p
              in (m['explanation'] as List? ?? const []).cast<String>())
            if (p.trim().isNotEmpty) p.trim(),
        ],
        body: [
          for (final p in (m['body'] as List? ?? const []).cast<String>())
            if (p.trim().isNotEmpty) p.trim(),
        ],
        conclusion: [
          for (final p in (m['conclusion'] as List? ?? const []).cast<String>())
            if (p.trim().isNotEmpty) p.trim(),
        ],
      );
}

class YaqeenSection {
  final String? title;
  final List<String> paragraphs;
  final String kind;
  final YaqeenDoubt? doubt;

  const YaqeenSection({
    this.title,
    required this.paragraphs,
    this.kind = 'text',
    this.doubt,
  });

  bool get isDoubt => kind == 'doubt' || doubt != null;

  factory YaqeenSection.fromJson(dynamic json) {
    final m = json as Map<String, dynamic>;
    final rawDoubt = m['doubt'] as Map<String, dynamic>?;
    return YaqeenSection(
      title: (m['title'] as String?)?.trim().isEmpty == true
          ? null
          : m['title'] as String?,
      paragraphs: [
        for (final p in (m['paragraphs'] as List).cast<String>())
          if (p.trim().isNotEmpty) p.trim(),
      ],
      kind: (m['kind'] as String?)?.trim() ??
          (rawDoubt != null ? 'doubt' : 'text'),
      doubt: rawDoubt != null ? YaqeenDoubt.fromJson(rawDoubt) : null,
    );
  }
}

class YaqeenLesson {
  final String id;
  final String title;
  final String excerpt;
  final int minutes;
  final List<YaqeenSection> sections;

  const YaqeenLesson({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.minutes,
    required this.sections,
  });

  factory YaqeenLesson.fromJson(Map<String, dynamic> m) => YaqeenLesson(
        id: m['id'] as String,
        title: m['title'] as String,
        excerpt: m['excerpt'] as String? ?? '',
        minutes: (m['minutes'] as num?)?.toInt() ?? 1,
        sections: [
          for (final s in (m['sections'] as List)) YaqeenSection.fromJson(s),
        ],
      );

  /// Full plain text — used by search.
  String get fullText {
    final buf = StringBuffer(title);
    for (final s in sections) {
      if (s.title != null) {
        buf.write(' ');
        buf.write(s.title);
      }
      for (final p in s.paragraphs) {
        buf.write(' ');
        buf.write(p);
      }
    }
    return buf.toString();
  }
}

class YaqeenChapter {
  final String id;
  final String title;
  final List<YaqeenLesson> lessons;

  const YaqeenChapter({
    required this.id,
    required this.title,
    required this.lessons,
  });

  factory YaqeenChapter.fromJson(Map<String, dynamic> m) => YaqeenChapter(
        id: m['id'] as String,
        title: m['title'] as String,
        lessons: [
          for (final l in (m['lessons'] as List).cast<Map<String, dynamic>>())
            YaqeenLesson.fromJson(l),
        ],
      );
}

class YaqeenLevel {
  final String id;
  final String title;
  final String subtitle;
  final List<YaqeenChapter> chapters;

  const YaqeenLevel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.chapters,
  });

  factory YaqeenLevel.fromJson(Map<String, dynamic> m) => YaqeenLevel(
        id: m['id'] as String,
        title: m['title'] as String,
        subtitle: m['subtitle'] as String? ?? '',
        chapters: [
          for (final c in (m['chapters'] as List).cast<Map<String, dynamic>>())
            YaqeenChapter.fromJson(c),
        ],
      );

  List<YaqeenLesson> get lessons => [for (final c in chapters) ...c.lessons];

  int get totalMinutes => lessons.fold(0, (sum, l) => sum + l.minutes);
}

/// A flat lesson hit for search results — keeps the owning level for routing.
class YaqeenSearchHit {
  final YaqeenLesson lesson;
  final YaqeenLevel level;

  const YaqeenSearchHit(this.lesson, this.level);
}

class YaqeenRepository {
  static YaqeenRepository? _instance;
  factory YaqeenRepository() => _instance ??= YaqeenRepository._();
  YaqeenRepository._();

  static const String _assetPath = 'assets/content/yaqeen.json';

  List<YaqeenLevel>? _cache;

  Future<List<YaqeenLevel>> levels() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString(_assetPath);
    final data = latinizeJsonDigits(json.decode(raw)) as Map<String, dynamic>;
    final parsed = [
      for (final l in (data['levels'] as List).cast<Map<String, dynamic>>())
        YaqeenLevel.fromJson(l),
    ];
    _cache = parsed;
    return parsed;
  }

  /// All lessons flattened in curriculum order.
  Future<List<YaqeenSearchHit>> allLessons() async {
    final levels = await this.levels();
    return [
      for (final lv in levels)
        for (final l in lv.lessons) YaqeenSearchHit(l, lv),
    ];
  }

  /// Lightweight multi-term AND search over titles and full text.
  /// Normalizes Arabic tashkeel and Persian/Arabic ye-ke variants so
  /// queries work with or without diacritics.
  Future<List<YaqeenSearchHit>> search(String query) async {
    final terms = normalizeText(query)
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty) return const [];
    final all = await allLessons();
    final results = <YaqeenSearchHit>[];
    for (final hit in all) {
      final hay = normalizeText(hit.lesson.fullText);
      if (terms.every(hay.contains)) results.add(hit);
    }
    return results;
  }

  /// Canonical search normalizer (shared/utils/arabic_search.dart).
  /// Both query and haystack go through it, and the direction now matches
  /// every other runtime search pair (books, duas, global search).
  /// NOTE: precomputed-DB pairs (Quran FTS, fatwa search_norm) intentionally
  /// keep their own build-time functions — do NOT "sync" this with those.
  @visibleForTesting
  static String normalizeText(String s) => normalizeForSearch(s);
}
