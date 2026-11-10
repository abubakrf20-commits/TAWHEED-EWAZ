import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:tawheeed/shared/services/content_download_service.dart';
import 'package:tawheeed/shared/services/downloaded_sqlite_db.dart';

/// Thrown when the fatwa database has not been downloaded yet (the UI shows
/// a download prompt instead of a crash).
typedef FatwaDatabaseMissingException = ContentDatabaseMissingException;

/// فتاوای شرعی (فارسی) — پرسش و پاسخ‌های فقهی اهل سنت و جماعت.
///
/// محتوا (9٬081 فتوای فارسی از IslamPP.Com) در پایگاه‌دادهٔ اختصاصی نگهداری
/// می‌شود: دانلود یک‌بارهٔ `fatwa/fatwas.db.gz` (~21 MB) از کاتالوگ محتوای
/// برنامه، مثل کتب حدیث و ریاض الصالحین. ستون‌های `q_norm` / `search_norm`
/// از پیش نرمال‌شده‌اند تا جستجو با/بدون اعراب و با ی/ک فارسی یا عربی
/// کار کند — [normalizeText] باید همان الگوریتم ابزار ساخت دیتابیس باشد.
class FatwaService extends DownloadedSqliteDbService {
  static FatwaService? _instance;
  factory FatwaService() => _instance ??= FatwaService._();
  FatwaService._({String? pathOverride})
      : _pathOverride = pathOverride,
        super(
          dbFileName: 'fatwas.db',
          remoteKey: 'fatwa/fatwas.db',
          // 2 = Maturidi/Ash'ari sect questions removed from the hosted
          // database. Bump again whenever fatwas.db is republished so
          // installed copies pick the correction up.
          contentRevision: 2,
        );

  /// Test-only instance bound to an explicit database file.
  @visibleForTesting
  static FatwaService forPath(String path) => FatwaService._(
        pathOverride: path,
      );

  final String? _pathOverride;

  /// Test instances are bound to fixture files that carry no revision, so they
  /// must never be treated as outdated copies.
  @override
  Future<bool> needsUpdate() async {
    if (_pathOverride != null) return false;
    return super.needsUpdate();
  }

  /// Normalization used for search matching — MUST stay in sync with
  /// `tools/build_fatwa_db.py::normalize` (tashkeel removal, alif unification,
  /// ة→ه, ى/ی→ي, ؤ→و, ئ→ي, ک→ك, lowercase).
  static String normalizeText(String s) {
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final code = s.codeUnitAt(i);
      // Skip Arabic tashkeel, superscript alif and tatweel.
      if ((code >= 0x064B && code <= 0x065F) || code == 0x0670) continue;
      if (code == 0x0640) continue;
      // Zero-width non-joiner / joiner. Persian words carry ZWNJ inside them
      // («می‌شود»), and a reader who types the same word without it — or with
      // it where the source has none — used to get zero results, because the
      // character sat in the middle of both sides and neither matched.
      if (code == 0x200C || code == 0x200D) continue;

      String out = s[i];
      switch (out) {
        case 'أ':
        case 'إ':
        case 'آ':
        case 'ٱ':
          out = 'ا';
        case 'ة':
          out = 'ه';
        case 'ى':
        case 'ی':
          out = 'ي';
        case 'ؤ':
          out = 'و';
        case 'ئ':
          out = 'ي';
        case 'ک':
          out = 'ك';
        default:
          out = out.toLowerCase();
      }
      buf.write(out);
    }
    return buf.toString();
  }

  @override
  Future<String> localPath() async {
    if (_pathOverride != null) return _pathOverride!;
    return super.localPath();
  }

  Future<bool> isAvailable() => isDownloadedFile();

  /// Splits a stored fatwa `answer` field into its display parts.
  ///
  /// IslamPP entries keep the short title in the `question` column, but the
  /// `answer` column often repeats the full question and then starts the real
  /// reply with a «جواب»/«الحمد لله» marker. [fullQuestion] is that repeated
  /// full question (null when the entry goes straight into the answer) and
  /// [answer] is the clean actual reply.
  static ({String? fullQuestion, String answer}) splitFatwa(String answer) {
    final jvabIdx = answer.indexOf('جواب');
    final hmdIdx = answer.indexOf('الحمد لله');
    final hmdIdx2 = answer.indexOf('الحمدلله');

    final indices = [
      if (jvabIdx >= 0) jvabIdx,
      if (hmdIdx >= 0) hmdIdx,
      if (hmdIdx2 >= 0) hmdIdx2,
    ];
    if (indices.isEmpty) {
      return (fullQuestion: null, answer: answer.trim());
    }

    final boundary = indices.reduce((a, b) => a < b ? a : b);
    final q = answer
        .substring(0, boundary)
        .trim()
        .replaceAll(RegExp(r'[،,:. ]+$'), '');
    final rest = answer.substring(boundary).trim();

    // Strip leading reply boilerplate: optional «جواب…» then «الحمد لله»،.
    // The class stops at the Arabic letters of "الحمدلله" so the first group
    // swallows only the "جواب)" prefix and the second eats the praise.
    final cleaned = rest.replaceFirst(
      RegExp(r'^(?:جواب[^\nالحمد]{0,20})?\s*(?:الحمد\s*لله[،,.\s]*)?'),
      '',
    );
    final trimmed = cleaned.trim();
    return (
      fullQuestion: q.isEmpty ? null : q,
      answer: trimmed.isEmpty ? rest : trimmed,
    );
  }

  /// Downloads fatwas.db.gz (decompressing on the fly) if missing.
  Future<void> download({DownloadProgress? onProgress}) =>
      downloadFile(onProgress: onProgress);

  Future<void> deleteDownloaded() => deleteDownloadedFile();

  // ─── Queries ──────────────────────────────────────────────────

  /// SQL fragment: پنهان کردن فتاوای مربوط به تشیع و رافضه از نتایج.
  ///
  /// Safety net only — those rows are deleted from the published database, so
  /// this matches nothing today. Note the «دوازده امام» term: it used to be
  /// written with CJK characters (十二 امام) and therefore never matched.
  static const String _excludeShia =
      "NOT (question LIKE '%شیعه%' OR question LIKE '%شیعی%' OR "
      "question LIKE '%تشیع%' OR question LIKE '%رافضه%' OR "
      "question LIKE '%رافضی%' OR question LIKE '%رافعی%' OR "
      "question LIKE '%امامیه%' OR question LIKE '%دوازده امام%' OR "
      "question LIKE '%ناصبی%')";

  int totalCount() => db
      .select('SELECT COUNT(*) AS c FROM fatwas WHERE $_excludeShia')
      .first['c'] as int;

  /// Categories ordered by size (largest first), with per-category counts.
  List<Map<String, dynamic>> categories() => [
        for (final r
            in db.select('SELECT category AS name, COUNT(*) AS c FROM fatwas '
                'WHERE $_excludeShia '
                'GROUP BY category ORDER BY c DESC'))
          {'name': r['name'] as String, 'count': r['c'] as int},
      ];

  /// Paged listing, newest-last by id; [category] filters when non-null.
  List<Map<String, dynamic>> listPage({
    String? category,
    int limit = 30,
    int offset = 0,
  }) {
    if (category == null || category.isEmpty) {
      return [
        for (final r in db.select(
            'SELECT id, question, category FROM fatwas '
            'WHERE $_excludeShia '
            'ORDER BY id LIMIT ? OFFSET ?',
            [limit, offset]))
          Map<String, dynamic>.from(r)
      ];
    }
    return [
      for (final r in db.select(
          'SELECT id, question, category FROM fatwas '
          'WHERE $_excludeShia AND category = ? '
          'ORDER BY id LIMIT ? OFFSET ?',
          [category, limit, offset]))
        Map<String, dynamic>.from(r)
    ];
  }

  /// The rows for [ids], in id order, as one indexed query.
  ///
  /// WHY: the favourites view used to call `listPage(limit: 100000)` and filter
  /// in Dart — 9,081 rows materialized on the UI thread every time a heart was
  /// tapped, so the screen froze on each favourite. SQLite already has the ids;
  /// let it return only those rows.
  List<Map<String, dynamic>> byIds(Iterable<int> ids) {
    final unique = ids.toSet().toList();
    if (unique.isEmpty) return const [];
    // Chunked so a very long favourites list cannot exceed SQLite's bound
    // variable limit (999 on older builds).
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < unique.length; i += 500) {
      final chunk = unique.sublist(i, (i + 500).clamp(0, unique.length));
      final marks = List.filled(chunk.length, '?').join(',');
      out.addAll([
        for (final r in db.select(
            'SELECT id, question, category FROM fatwas '
            'WHERE $_excludeShia AND id IN ($marks) ORDER BY id',
            chunk))
          Map<String, dynamic>.from(r),
      ]);
    }
    out.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    return out;
  }

  Map<String, dynamic>? byId(int id) {
    final rows = db.select('SELECT * FROM fatwas WHERE id = ?', [id]);
    return rows.isNotEmpty ? Map<String, dynamic>.from(rows.first) : null;
  }

  /// One search term's predicate.
  ///
  /// The baked columns still carry ZWNJ on databases built before the fold
  /// learned to strip it, so the comparison removes it on the column side
  /// too. On a re-baked database this REPLACE is a no-op.
  static const String _termPredicate =
      "(REPLACE(q_norm, char(8204), '') LIKE ? "
      "OR REPLACE(search_norm, char(8204), '') LIKE ?)";

  /// Full-text search over the baked normalized columns. Multi-term AND:
  /// every whitespace-separated term must appear in q or a.
  ({List<Map<String, dynamic>> rows, bool more}) search(
    String query, {
    int limit = 40,
  }) {
    final terms = normalizeText(query)
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty) return (rows: const [], more: false);

    final where = [for (final _ in terms) _termPredicate].join(' AND ');
    final args = [
      for (final t in terms) ...['%$t%', '%$t%'],
      limit + 1,
    ];
    final rows = db.select(
        'SELECT id, question, category, q_norm, search_norm FROM fatwas '
        'WHERE $_excludeShia AND $where ORDER BY id LIMIT ?',
        args);
    final more = rows.length > limit;
    return (
      rows: [
        for (final r in rows.take(limit))
          {
            'id': r['id'],
            'question': r['question'],
            'category': r['category'],
            // Snippet around the first matched term from the normalized
            // answer text (question is always visible on the card).
            'snippet': _snippet(
                (r['search_norm'] as String).replaceAll('\u200C', ''), terms),
          }
      ],
      more: more,
    );
  }

  static String? _snippet(String norm, List<String> terms) {
    for (final t in terms) {
      final idx = norm.indexOf(t);
      if (idx >= 0) {
        final start = idx > 60 ? idx - 60 : 0;
        var end = idx + t.length + 120;
        if (end > norm.length) end = norm.length;
        return '${start > 0 ? '…' : ''}'
            '${norm.substring(start, end).trim()}…';
      }
    }
    return null;
  }

  /// Random pick via offset (cheap; no full-table sort).
  /// Excludes Shia/Rafidha-related fatwas.
  Map<String, dynamic>? random() {
    final n = totalCount(); // already excludes via _excludeShia
    if (n == 0) return null;
    final off = DateTime.now().microsecondsSinceEpoch.remainder(n).abs();
    final rows = db.select(
        'SELECT id, question, category FROM fatwas '
        'WHERE $_excludeShia '
        'LIMIT 1 OFFSET ?',
        [off]);
    return rows.isNotEmpty ? Map<String, dynamic>.from(rows.first) : null;
  }
}
