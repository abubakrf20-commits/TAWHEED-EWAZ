import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/features/adhkar/duas/presentation/providers/duas_provider.dart';
import 'package:tawheeed/features/books/services/book_content_service.dart';
import 'package:tawheeed/features/books/services/book_pagination.dart';
import 'package:tawheeed/features/dua_from_quran/data/dua_from_quran_data.dart';
import 'package:tawheeed/features/dua_from_quran/domain/entities/dua_from_quran_entity.dart';
import 'package:tawheeed/features/fatwa/services/fatwa_service.dart';
import 'package:tawheeed/features/hadeeth_enc/domain/entities/hadeeth_enc_hadith.dart';
import 'package:tawheeed/features/hadeeth_enc/services/hadeeth_enc_db_service.dart';
import 'package:tawheeed/features/hadith/services/hadith_books_service.dart';
import 'package:tawheeed/features/hadith/services/hadith_db_service.dart';
import 'package:tawheeed/features/notes/presentation/providers/notes_provider.dart';
import 'package:tawheeed/features/riyad/services/riyad_service.dart';
import 'package:tawheeed/features/ruqyah/data/ruqyah_content.dart';
import 'package:tawheeed/features/search/services/content_hit.dart';
import 'package:tawheeed/features/search/services/content_targets.dart';
import 'package:tawheeed/features/taraghib/services/taraghib_service.dart';
import 'package:tawheeed/features/maalim/services/maalim_service.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/arabic_search.dart';
import 'package:tawheeed/shared/utils/latinize_json_digits.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/utils/text_highlight.dart';

/// ═══════════════════════════════════════════════════════════════
/// The «بیشتر» content search — what the page's search field reaches when it
/// looks INSIDE a section instead of only at its title.
///
/// The shape follows the proven pattern of `GlobalSearchDelegate`: a source
/// answers «what text do you own?» as a list of [ContentPiece]s (a heading
/// plus the prose under it), each piece is folded ONCE into a search key with
/// the page's own normalization, and a keystroke is then a `contains` over the
/// memoized keys. Parsing and folding never repeat per keystroke — and for
/// the seven bundled JSON guides both happen on a background isolate, so the
/// first keystroke with a cold index does not stall the page.
///
/// Deliberately absent:
///  • the locked «تثبیت یقین» — search would leak its text past the password
///    screen that guards it;
///  • anything that needs the network (dorar hadith, the audio library,
///    announcements, قاف);
///  • a hadith database that has not been downloaded, or a کتابخانه book whose
///    content was not opened yet — its text is not on the device, so the
///    section reports nothing until it is;
///  • private personal data (اطلاعات من, دورهٔ ماهانه) — a result list is not
///    a place to surface it.
///
/// A hit is not a dead end: [ContentHit.highlightQuery] is the EXACT literal
/// the folded query matched (so a destination screen can paint it, whatever
/// letter forms the user typed), and [ContentHit.target] names the position
/// inside the owning section when the section has no per-item route.
/// ═══════════════════════════════════════════════════════════════

/// One searchable unit of a section's text.
class ContentPiece {
  const ContentPiece(this.title, this.body, {this.entity});

  /// The heading this text sits under; '' when it has none of its own.
  final String title;
  final String body;

  /// The object a target screen can open directly, when one can.
  final Object? entity;
}

/// Joins whatever a piece is made of into one string: strings are trimmed and
/// nested string lists (bullets, words, refs) are flattened.
String joinContentFields(Iterable<Object?> values) {
  final parts = <String>[];
  for (final v in values) {
    if (v is String) {
      final s = v.trim();
      if (s.isNotEmpty) parts.add(s);
    } else if (v is Iterable) {
      for (final e in v) {
        if (e is String) {
          final s = e.trim();
          if (s.isNotEmpty) parts.add(s);
        }
      }
    }
  }
  return parts.join(' ');
}

/// The number a query names, when the whole query is one: «412» → 412.
///
/// The page stores its query already folded — `toAsciiDigits` turns a Persian
/// keypad's ۴۱۲ into 412 — so both digit sets arrive equal here. Zero is not
/// a number any hadith edition carries, so it is not a number query.
int? moreContentNumberQuery(String query) {
  final n = int.tryParse(query);
  return n == null || n <= 0 ? null : n;
}

/// Whether [query] can find anything at all.
///
/// One character is too little to match text, but a NUMBER is a complete
/// question on its own — «5» must reach hadith 5. Every gate that guards a
/// section scan asks this, so the page's spinner, the engine and the page's
/// `searching` flag can never disagree about whether a query is live.
bool moreContentQueryIsSearchable(String query) =>
    query.length >= 2 || moreContentNumberQuery(query) != null;

/// A family of section content the More search can reach into.
abstract class MoreContentSource {
  MoreContentSource(this.itemId);

  /// The `MoreItem.id` of the tile that owns everything this source indexes.
  final String itemId;

  /// The section's text. The returned list must keep its identity while
  /// unchanged — that is what lets the keys below stay memoized.
  Future<List<ContentPiece>> pieces(WidgetRef? ref);

  /// True for a source whose scan is expensive enough to run after the first
  /// wave (see [MoreSearchPhase]) — the page shows the fast hits at once and
  /// folds this one in when it lands.
  bool get isDeferred => false;

  /// True when this source can answer «which entry carries hadith N?».
  ///
  /// A numeric query means the NUMBER, not a string match on some digits in
  /// the prose — that is why it is a separate question with a separate index.
  bool get hasNumberIndex => false;

  /// The entries carrying hadith [number]. An empty answer lets the caller
  /// fall back to [search], so a source whose numbers do not reach this value
  /// still answers with its text.
  Future<List<ContentHit>> searchByNumber(int number, {int limit = 3}) async =>
      const [];

  List<ContentPiece>? _src;
  List<String> _keys = const [];

  /// Installs a piece list whose keys were already folded off the UI isolate
  /// (see [buildGuideIndex]), so [search] does not fold them a second time.
  void _installFoldedKeys(List<ContentPiece> list, List<String> keys) {
    _src = list;
    _keys = keys;
  }

  Future<List<ContentHit>> search(
    String query,
    String rawQuery, {
    WidgetRef? ref,
    int limit = 3,
  }) async {
    final list = await pieces(ref);
    if (list.isEmpty) return const [];
    if (!identical(list, _src) || _keys.length != list.length) {
      _src = list;
      _keys = [
        for (final p in list) normalizeSearchKey('${p.title} ${p.body}')
      ];
    }
    final out = <ContentHit>[];
    for (var i = 0; i < list.length && out.length < limit; i++) {
      if (!_keys[i].contains(query)) continue;
      final p = list[i];
      // Project the FOLDED match back onto the original text: a destination
      // screen paints with its own (narrower) normalizer, so it needs the
      // literal this text really carries — not what the user typed.
      final combined = '${p.title} ${p.body}';
      final literal = matchedLiteral(combined, rawQuery);
      out.add(ContentHit(
        itemId: itemId,
        title: p.title,
        body: p.body,
        highlightQuery: literal,
        snippet:
            snippetAround(combined, literal.isEmpty ? rawQuery : literal),
        entity: p.entity,
      ));
    }
    return out;
  }
}

/// Keys that name nothing readable — icon names, row ids, ordering.
const Set<String> _skippedContentKeys = {
  'icon',
  'id',
  'key',
  'version',
  'step',
  'number',
  'color',
  'image',
  'url',
  'link',
};

/// Flattens a decoded content asset into pieces, one per JSON object.
///
/// An object carrying a heading (`title`, `name`, `question`, …) becomes a
/// piece holding only its OWN direct strings, and every nested object or
/// string list under it becomes a further piece with that heading inherited —
/// so a hit points at the smallest block that really contains the match, not
/// at a whole chapter.
void walkContentNode(dynamic node, String title, List<ContentPiece> out) {
  if (node is String) {
    final s = node.trim();
    if (s.isNotEmpty) out.add(ContentPiece(title, s));
    return;
  }
  if (node is List) {
    for (final e in node) {
      walkContentNode(e, title, out);
    }
    return;
  }
  if (node is Map) {
    var own = title;
    String? titleKey;
    for (final k in kContentTitleKeys) {
      final v = node[k];
      if (v is String && v.trim().isNotEmpty) {
        own = v.trim();
        titleKey = k;
        break;
      }
    }
    final body = <Object?>[
      for (final e in node.entries)
        if (e.key != titleKey &&
            !_skippedContentKeys.contains(e.key) &&
            e.value is String)
          e.value,
    ];
    final text = joinContentFields(body);
    if (text.isNotEmpty) out.add(ContentPiece(own, text));
    for (final e in node.entries) {
      final v = e.value;
      if (v is Map || v is List) walkContentNode(v, own, out);
    }
  }
}

/// Parses one bundled guide and folds every piece into its search key — the
/// whole cost of the first deep-search keystroke — off the UI isolate.
/// Returns `[titles, bodies, keys]` as plain, sendable data.
List<List<String>> buildGuideIndex(String raw) {
  final pieces = <ContentPiece>[];
  walkContentNode(latinizeJsonDigits(json.decode(raw)), '', pieces);
  return [
    [for (final p in pieces) p.title],
    [for (final p in pieces) p.body],
    [for (final p in pieces) normalizeSearchKey('${p.title} ${p.body}')],
  ];
}

/// A bundled `assets/content/*.json` guide: read once per process, then
/// searched from memory.
class JsonGuideSource extends MoreContentSource {
  JsonGuideSource(super.itemId, this.assetPath);

  final String assetPath;
  List<ContentPiece>? _parsed;

  @override
  Future<List<ContentPiece>> pieces(WidgetRef? ref) async {
    if (_parsed != null) return _parsed!;
    final List<ContentPiece> built;
    try {
      // Only the asset read stays here — parsing 1.18 MB of JSON and folding
      // 4,190 pieces takes hundreds of milliseconds on a phone and used to
      // run on the UI isolate at the first keystroke. The whole index now
      // comes back already folded.
      final raw = await rootBundle.loadString(assetPath);
      final index = await Isolate.run(() => buildGuideIndex(raw));
      built = [
        for (var i = 0; i < index[1].length; i++)
          ContentPiece(index[0][i], index[1][i]),
      ];
      _installFoldedKeys(built, index[2]);
    } catch (e) {
      AppLogger.warning('MoreContentSearch', '$assetPath failed: $e');
      return const [];
    }
    _parsed = built;
    return built;
  }

  /// Visible for tests: forgets the parsed pieces so a fixture re-reads.
  @visibleForTesting
  void resetForTest() => _parsed = null;
}

/// Content compiled into the app as `const` Dart lists (رقیه، دعاهای قرآنی).
class ConstSource extends MoreContentSource {
  ConstSource(super.itemId, this._build);

  final List<ContentPiece> Function() _build;
  List<ContentPiece>? _parsed;

  @override
  Future<List<ContentPiece>> pieces(WidgetRef? ref) async =>
      _parsed ??= _build();
}

/// A section whose text lives in a database the user downloads first. Until
/// that download exists there is nothing on the device to search, and the
/// source reports nothing rather than opening a database that isn't there.
abstract class DownloadedContentSource extends MoreContentSource {
  DownloadedContentSource(super.itemId);

  Future<bool> get hasContent;

  /// Matches with the database's own engine, which already normalizes the
  /// Arabic the way its content was indexed.
  Future<List<ContentHit>> find(String rawQuery, int limit);

  /// The entry carrying hadith [number], for a database that stores numbers.
  Future<List<ContentHit>> findNumber(int number, {int limit = 3}) async =>
      const [];

  @override
  Future<List<ContentHit>> searchByNumber(int number, {int limit = 3}) async {
    try {
      if (!await hasContent) return const [];
      return await findNumber(number, limit: limit);
    } catch (e) {
      AppLogger.debug('MoreContentSearch', '$itemId has no local content: $e');
      return const [];
    }
  }

  @override
  Future<List<ContentPiece>> pieces(WidgetRef? ref) async => const [];

  @override
  Future<List<ContentHit>> search(
    String query,
    String rawQuery, {
    WidgetRef? ref,
    int limit = 3,
  }) async {
    try {
      // Asking whether the text is on the device can itself fail (path
      // provider, a database that never opened) — and a section that cannot
      // answer is the same nothing as a section with no match.
      if (!await hasContent) return const [];
      return await find(rawQuery, limit);
    } catch (e) {
      AppLogger.debug('MoreContentSearch', '$itemId has no local content: $e');
      return const [];
    }
  }
}

/// The row's own prose — what a snippet is cut from and what the destination
/// screen shows.
const List<String> _rowBodyKeys = [
  'arabic',
  'text',
  'text_ar',
  'translation',
  'persian',
  'answer',
  'snippet',
];

String _rowBody(Map<String, dynamic> row) =>
    joinContentFields([for (final k in _rowBodyKeys) row[k]]);

/// rows → hits, for the databases that hand back plain column maps
/// (کتب حدیث, ریاض الصالحین, صحیح الترغیب, فتاوا).
///
/// [targetOf] names the position inside the owning section: these sections
/// have no per-item route, so the tile is the deepest link that exists — a
/// row id left in [ContentHit.entity] would read like one. [matchQuery] is
/// the key the database actually matched with, which is what the painted
/// literal has to be derived from.
List<ContentHit> hitsFromRows(
  String itemId,
  List<Map<String, dynamic>> rows,
  String rawQuery, {
  String Function(Map<String, dynamic> row)? titleOf,
  Object? Function(Map<String, dynamic> row)? targetOf,
  String? matchQuery,
}) =>
    [
      for (final r in rows)
        () {
          final body = _rowBody(r);
          final literal =
              TextHighlight.literalMatch(body, matchQuery ?? rawQuery);
          return ContentHit(
            itemId: itemId,
            title: titleOf?.call(r) ??
                _firstText(r, const ['question', 'title', 'name_arabic']),
            body: body,
            highlightQuery: literal,
            snippet: snippetAround(
              body,
              literal.isEmpty ? rawQuery : literal,
            ),
            target: targetOf?.call(r),
          );
        }(),
    ];

String _firstText(Map<String, dynamic> row, List<String> keys) {
  for (final k in keys) {
    final v = row[k];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return '';
}

/// Chapter `(chapter_index, name_arabic, book_id)` keyed by the chapter row id
/// — the column a hadith row actually keeps (`chapter_id`). The book is part
/// of the record because صحیح الترغیب restarts `chapter_index` in every book.
Map<int, (num, String, int?)> _chaptersById(
    List<Map<String, dynamic>> chapters) {
  final out = <int, (num, String, int?)>{};
  for (final c in chapters) {
    final id = (c['id'] as num?)?.toInt();
    final index = c['chapter_index'];
    if (id == null || index is! num) continue;
    final name = c['name_arabic'];
    out[id] = (index, name is String ? name : '', (c['book_id'] as num?)?.toInt());
  }
  return out;
}

/// The chapter NAME carrying [chapterIndex] — the number a [ContentTarget]
/// stores, where [_chaptersById] is keyed by the row id a hadith row carries.
///
/// [bookId] qualifies it: a multi-book edition repeats `chapter_index` from 1
/// in each book, so without the book the first book's chapter of that number
/// would be labelled on every other book's hit.
String _chapterTitleByIndex(
  List<Map<String, dynamic>> chapters,
  num chapterIndex, {
  int? bookId,
}) {
  for (final c in chapters) {
    if (c['chapter_index'] != chapterIndex) continue;
    if (bookId != null && (c['book_id'] as num?)?.toInt() != bookId) continue;
    final name = c['name_arabic'];
    return name is String ? name : '';
  }
  return '';
}

/// «حدیث 412» — the number a numeric query asked for, in the app's digits.
///
/// The digits are LTR-isolated: a bare Latin run inside a Persian title is
/// reordered by the bidi algorithm, and the one thing this title must say
/// unambiguously is which entry it is.
String hadithNumberTitle(int number, String chapterTitle) {
  final head = 'حدیث ${NumberFormat.ltrIsolated(NumberFormat.en(number))}';
  return chapterTitle.isEmpty ? head : '$head · $chapterTitle';
}

/// ریاض الصالحین and صحیح الترغیب — one standalone database each, the same
/// row shape, and no per-item route, so a hit carries the chapter (and the
/// stored entry number) its screen must jump to.
abstract class StandaloneHadithSource extends DownloadedContentSource {
  StandaloneHadithSource(super.itemId);

  Future<List<Map<String, dynamic>>> chapters();

  Future<List<Map<String, dynamic>>> rows(String rawQuery, int limit);

  /// `(bookId, chapterIndex, storedNumber)` of the entry carrying [number],
  /// resolved by the edition's own rule — «number» is not one thing across the
  /// two books (ریاض keeps printed numbers in a label table, الترغیب stores
  /// the visible one). [bookId] is null for an edition without a book layer.
  /// Null when the edition does not carry that number.
  Future<({int? bookId, num chapterIndex, int stored})?> locateNumber(
      int number);

  /// Every entry of one chapter, so a located number can be resolved to the
  /// row the destination screen will scroll to (and its text shown).
  ///
  /// [bookId] selects the book for an edition whose `chapter_index` restarts
  /// at 1 in every book; editions without a book layer ignore it.
  Future<List<Map<String, dynamic>>> entriesOfChapter(
    num chapterIndex, {
    int? bookId,
  });

  @override
  bool get hasNumberIndex => true;

  @override
  Future<List<ContentHit>> findNumber(int number, {int limit = 3}) async {
    final at = await locateNumber(number);
    if (at == null) return const [];
    final chapterIndex = at.chapterIndex;
    final stored = at.stored;
    final chapterTitle =
        _chapterTitleByIndex(await chapters(), chapterIndex, bookId: at.bookId);
    Map<String, dynamic>? row;
    for (final r in await entriesOfChapter(chapterIndex, bookId: at.bookId)) {
      if ((r['hadith_number'] as num?)?.toInt() == stored) {
        row = r;
        break;
      }
    }
    if (row == null) return const [];
    final body = _rowBody(row);
    return [
      ContentHit(
        itemId: itemId,
        title: hadithNumberTitle(number, chapterTitle),
        body: body,
        // No highlightQuery on purpose: the query's digits are not a literal
        // inside this text, so there is nothing a destination could paint — it
        // shows its own «حدیث N» badge from the target instead.
        snippet: snippetAround(body, ''),
        target: HadithChapterTarget(
          itemId: itemId,
          bookId: at.bookId,
          chapterIndex: chapterIndex,
          chapterTitle: chapterTitle,
          hadithNumber: stored,
        ),
      ),
    ];
  }

  @override
  Future<List<ContentHit>> find(String rawQuery, int limit) async {
    final byId = _chaptersById(await chapters());
    final rows = await this.rows(rawQuery, limit);
    String titleOf(Map<String, dynamic> r) {
      final c = byId[(r['chapter_id'] as num?)?.toInt()];
      return c == null ? '' : c.$2;
    }

    Object? targetOf(Map<String, dynamic> r) {
      final c = byId[(r['chapter_id'] as num?)?.toInt()];
      if (c == null) return null;
      return HadithChapterTarget(
        itemId: itemId,
        bookId: c.$3,
        chapterIndex: c.$1,
        chapterTitle: c.$2,
        hadithNumber: (r['hadith_number'] as num?)?.toInt(),
      );
    }

    return hitsFromRows(
      itemId,
      rows,
      rawQuery,
      matchQuery: TextHighlight.arabicSearchKey(rawQuery),
      titleOf: titleOf,
      targetOf: targetOf,
    );
  }
}

/// ریاض الصالحین — its own standalone database and full-text index.
class RiyadContentSource extends StandaloneHadithSource {
  RiyadContentSource() : super('riyad');

  final RiyadService _service = RiyadService();

  @override
  Future<bool> get hasContent => _service.isAvailable();

  @override
  Future<List<Map<String, dynamic>>> chapters() async {
    await _service.ensureReady();
    return _service.chapters();
  }

  @override
  Future<List<Map<String, dynamic>>> rows(String rawQuery, int limit) async {
    await _service.ensureReady();
    return _service.search(rawQuery, limit: limit);
  }

  @override
  Future<({int? bookId, num chapterIndex, int stored})?> locateNumber(
      int number) async {
    await _service.ensureReady();
    // The row's own number IS the badge the reader prints (1..1897); the
    // edition's per-باب printed numbers are not stored, so there is no label
    // table to consult any more.
    final at = await _service.locateHadithNumber(number);
    if (at == null) return null;
    return (bookId: null, chapterIndex: at.$1, stored: at.$2);
  }

  @override
  Future<List<Map<String, dynamic>>> entriesOfChapter(
    num chapterIndex, {
    int? bookId,
  }) async {
    await _service.ensureReady();
    return _service.entriesOfChapter(chapterIndex);
  }
}

/// صحیح الترغیب و الترهیب — its own 29-book database and full-text index.
class TaraghibContentSource extends StandaloneHadithSource {
  TaraghibContentSource() : super('taraghib');

  final TaraghibService _service = TaraghibService();

  @override
  Future<bool> get hasContent => _service.isAvailable();

  @override
  Future<List<Map<String, dynamic>>> chapters() async {
    await _service.ensureReady();
    return _service.allChapters();
  }

  @override
  Future<List<Map<String, dynamic>>> rows(String rawQuery, int limit) async {
    await _service.ensureReady();
    return _service.search(rawQuery, limit: limit);
  }

  @override
  Future<({int? bookId, num chapterIndex, int stored})?> locateNumber(
      int number) async {
    await _service.ensureReady();
    // The printed number runs 1..3775 across the whole edition and is stored
    // as-is, so the row's own column is the badge the reader sees.
    final at = await _service.locateHadithNumber(number);
    if (at == null) return null;
    return (
      bookId: at.bookId,
      chapterIndex: at.chapterIndex,
      stored: at.number,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> entriesOfChapter(
    num chapterIndex, {
    int? bookId,
  }) async {
    await _service.ensureReady();
    if (bookId == null) return const [];
    return _service.entriesOfChapter(bookId, chapterIndex);
  }
}

/// معالم السنه النبویه — the same engine, book 20.
class MaalimContentSource extends StandaloneHadithSource {
  MaalimContentSource() : super('maalim');

  final MaalimService _service = MaalimService();

  @override
  Future<bool> get hasContent => _service.isAvailable();

  @override
  Future<List<Map<String, dynamic>>> chapters() async {
    await _service.ensureReady();
    return _service.chapters();
  }

  @override
  Future<List<Map<String, dynamic>>> rows(String rawQuery, int limit) async {
    await _service.ensureReady();
    return _service.search(rawQuery, limit: limit);
  }

  @override
  Future<({int? bookId, num chapterIndex, int stored})?> locateNumber(
      int number) async {
    await _service.ensureReady();
    // معالم carries the visible book-wide number itself (1..474) — same as
    // الترغیب: the column is the badge the reader sees.
    final at = await _service.locateHadithNumber(number);
    if (at == null) return null;
    return (bookId: null, chapterIndex: at.$1, stored: at.$2);
  }

  @override
  Future<List<Map<String, dynamic>>> entriesOfChapter(
    num chapterIndex, {
    int? bookId,
  }) async {
    await _service.ensureReady();
    return _service.entriesOfChapter(chapterIndex);
  }
}

/// کتب حدیث — the nine books in one ~17 MB download.
class HadithBooksContentSource extends DownloadedContentSource {
  HadithBooksContentSource() : super('hadith-books');

  @override
  Future<bool> get hasContent => HadithDbService.isDownloaded();

  @override
  Future<List<ContentHit>> find(String rawQuery, int limit) async {
    final db = HadithDbService();
    await db.init();
    final rows = await db.searchArabic(rawQuery, limit: limit);
    // One extra query for the chapters these rows belong to: the row carries
    // `chapter_id`, the chapter carries the index and name a jump needs.
    final byId = _chaptersById(await db.getChaptersByIds([
      for (final r in rows)
        if (r['chapter_id'] is num) (r['chapter_id'] as num).toInt(),
    ]));

    (num, String, int?)? chapterOf(Map<String, dynamic> r) =>
        byId[(r['chapter_id'] as num?)?.toInt()];

    return hitsFromRows(
      itemId,
      rows,
      rawQuery,
      matchQuery: TextHighlight.arabicSearchKey(rawQuery),
      // Nine books answer here, so a row names its book beside the chapter —
      // the chapter name alone would not say which book it came from.
      titleOf: (r) {
        final chapter = chapterOf(r);
        if (chapter == null) return '';
        final book =
            HadithBooksService.metaForDbId((r['book_id'] as num).toInt());
        return book == null
            ? chapter.$2
            : '${book.titleArabic} · ${chapter.$2}';
      },
      targetOf: (r) {
        final chapter = chapterOf(r);
        final bookId = (r['book_id'] as num?)?.toInt();
        if (chapter == null || bookId == null) return null;
        return HadithBookEntryTarget(
          bookDbId: bookId,
          chapterIndex: chapter.$1,
          chapterTitle: chapter.$2,
          hadithNumber: (r['hadith_number'] as num?)?.toInt(),
        );
      },
    );
  }

  @override
  bool get hasNumberIndex => true;

  @override
  Future<List<ContentHit>> findNumber(int number, {int limit = 3}) async {
    final db = HadithDbService();
    await db.init();
    // Numbers restart in every book, so one query answers with the same number
    // from up to nine books — each hit names its own book, and the reader
    // picks which one they meant.
    final rows = await db.getHadithsByNumber(number, limit: limit);
    if (rows.isEmpty) return const [];
    final byId = _chaptersById(await db.getChaptersByIds([
      for (final r in rows)
        if (r['chapter_id'] is num) (r['chapter_id'] as num).toInt(),
    ]));

    final hits = <ContentHit>[];
    for (final r in rows) {
      final chapter = byId[(r['chapter_id'] as num?)?.toInt()];
      final bookId = (r['book_id'] as num?)?.toInt();
      final stored = (r['hadith_number'] as num?)?.toInt();
      // A row whose chapter or book cannot be resolved has no jump target, and
      // a hit that cannot land where it points is worse than one fewer hit.
      if (chapter == null || bookId == null || stored == null) continue;
      final book = HadithBooksService.metaForDbId(bookId);
      final where =
          book == null ? chapter.$2 : '${book.titleArabic} · ${chapter.$2}';
      final body = _rowBody(r);
      hits.add(ContentHit(
        itemId: itemId,
        title: hadithNumberTitle(number, where),
        body: body,
        // No highlightQuery — see the standalone source above.
        snippet: snippetAround(body, ''),
        target: HadithBookEntryTarget(
          bookDbId: bookId,
          chapterIndex: chapter.$1,
          chapterTitle: chapter.$2,
          hadithNumber: stored,
        ),
      ));
      if (hits.length >= limit) break;
    }
    return hits;
  }
}

/// فتاوای شرعی — the question is the title, the answer the snippet body.
class FatwaContentSource extends DownloadedContentSource {
  FatwaContentSource() : super('fatwa');

  @override
  Future<bool> get hasContent => FatwaService().isAvailable();

  @override
  Future<List<ContentHit>> find(String rawQuery, int limit) async {
    final service = FatwaService();
    await service.ensureReady();
    return hitsFromRows(
        itemId, service.search(rawQuery, limit: limit).rows, rawQuery);
  }
}

/// کتابخانه — every book whose content is already on disk.
///
/// A book's text lives on the device only after it was opened once
/// (`books_data/book_<id>.json.gz`), so this source never starts a download:
/// it scans what is there. Deferred because that scan decompresses and
/// paginates whole books, and it runs inside an isolate.
class BooksContentSource extends DownloadedContentSource {
  BooksContentSource() : super('ketabkhaneh');

  String? _cacheKey;
  List<ContentHit> _cacheHits = const [];

  @override
  bool get isDeferred => true;

  @override
  Future<bool> get hasContent async =>
      (await BookContentService.downloadedIds()).isNotEmpty;

  Future<Map<String, String>> _titles() async {
    final byId = <String, String>{};
    try {
      final raw =
          await rootBundle.loadString('assets/books_data/books_index.json');
      final list = json.decode(raw);
      if (list is List) {
        for (final e in list) {
          if (e is Map && e['id'] != null) {
            byId['${e['id']}'] = '${e['title'] ?? ''}';
          }
        }
      }
    } catch (e) {
      AppLogger.warning('MoreContentSearch', 'ketabkhaneh index: $e');
    }
    return byId;
  }

  @override
  Future<List<ContentHit>> find(String rawQuery, int limit) async {
    final ids = (await BookContentService.downloadedIds()).toList()..sort();
    if (ids.isEmpty) return const [];
    final cacheKey =
        '${TextHighlight.arabicSearchKey(rawQuery)}|${ids.join(',')}|$limit';
    if (_cacheKey == cacheKey) return _cacheHits;

    final titles = await _titles();
    final books = <Map<String, Object?>>[
      for (final id in ids)
        {
          'id': id,
          'title': titles[id] ?? '',
          'path': await BookContentService.localPathFor(id),
        },
    ];
    // The book carries its own title; the bundled index is the fallback for a
    // file whose entry disappeared.
    final raw = await Isolate.run(() => scanBookPages(books, rawQuery, limit));
    final hits = <ContentHit>[
      for (final m in raw)
        () {
          final title = (m['bookTitle'] as String?) ?? '';
          final bookId = (m['bookId'] as String?) ?? '';
          final pageIndex = (m['pageIndex'] as num?)?.toInt() ?? 0;
          return ContentHit(
            itemId: itemId,
            title: title.isNotEmpty ? title : bookId,
            body: (m['text'] as String?) ?? '',
            highlightQuery: (m['matched'] as String?) ?? '',
            snippet: (m['snippet'] as String?) ?? '',
            target: BookPageTarget(
              bookId: bookId,
              bookTitle: title,
              pageIndex: pageIndex,
              printNo: (m['printNo'] as num?)?.toInt(),
            ),
          );
        }(),
    ];
    _cacheKey = cacheKey;
    _cacheHits = hits;
    return hits;
  }
}

/// Pages of every downloaded book that carry [rawQuery] — off the UI isolate
/// (a library book can be several megabytes compressed).
///
/// [books] entries are `{id, title, path}` prepared on the main isolate, so
/// this function touches no plugin. Hits are interleaved one-per-book first,
/// so a word one book repeats cannot hide every other book behind the
/// per-source cap.
List<Map<String, Object?>> scanBookPages(
  List<Map<String, Object?>> books,
  String rawQuery,
  int limit,
) {
  final query = normalizeSearchKey(rawQuery);
  if (query.length < 2 || limit <= 0) return const [];
  final perBook = <List<Map<String, Object?>>>[];
  for (final b in books) {
    final hits = <Map<String, Object?>>[];
    try {
      final bytes = File((b['path'] as String?) ?? '').readAsBytesSync();
      final decoded = json.decode(utf8.decode(gzip.decode(bytes)));
      if (decoded is! Map) continue;
      final content = decoded['content'];
      if (content is! List) continue;
      final pages = BookPagination.paginate([
        for (final p in content)
          if (p is String) p
      ]);
      for (final page in pages) {
        if (!normalizeSearchKey(page.text).contains(query)) continue;
        final literal = matchedLiteral(page.text, rawQuery);
        hits.add({
          'bookId': b['id'],
          'bookTitle': b['title'],
          'pageIndex': page.index,
          'printNo': page.printNo,
          'text': page.text,
          'matched': literal,
          'snippet': snippetAround(
            page.text,
            literal.isEmpty ? rawQuery : literal,
            max: 160,
          ),
        });
        if (hits.length >= limit) break;
      }
    } catch (_) {
      // A missing or corrupt download is the same nothing as a book that is
      // not here; every other book still answers.
    }
    perBook.add(hits);
  }
  final out = <Map<String, Object?>>[];
  for (var round = 0; out.length < limit; round++) {
    var added = false;
    for (final hits in perBook) {
      if (round >= hits.length) continue;
      out.add(hits[round]);
      added = true;
      if (out.length >= limit) break;
    }
    if (!added) break;
  }
  return out;
}

/// موسوعه احادیث — typed rows, and the only hadith section with a per-item
/// route, so a hit keeps its id for `/hadeeth-enc/:id`.
class HadeethEncContentSource extends DownloadedContentSource {
  HadeethEncContentSource() : super('hadeeth-enc');

  @override
  Future<bool> get hasContent => HadeethEncDbService().isAvailable();

  @override
  Future<List<ContentHit>> find(String rawQuery, int limit) async {
    final items = await HadeethEncDbService().search(rawQuery, limit: limit);
    final hits = <ContentHit>[];
    for (final HadeethEncHadith h in items) {
      final body =
          joinContentFields([h.textAr, h.text, h.explanation, h.benefits]);
      final literal = TextHighlight.literalMatch(body, rawQuery);
      hits.add(ContentHit(
        itemId: itemId,
        title: h.title.isNotEmpty ? h.title : h.titleAr,
        body: body,
        highlightQuery: literal,
        snippet: snippetAround(body, literal.isEmpty ? rawQuery : literal),
        entity: h.id,
      ));
    }
    return hits;
  }
}

/// حصن المسلم — the same `duasProvider` list the global search reads, so what
/// the user sees in that section is what gets searched, and a hit carries its
/// dua straight into `DuaDetailScreen`.
class HesnContentSource extends MoreContentSource {
  HesnContentSource() : super('duas');

  @override
  Future<List<ContentPiece>> pieces(WidgetRef? ref) async {
    if (ref == null) return const [];
    final duas = ref.read(duasProvider).duas;
    return [
      for (final d in duas)
        ContentPiece(
          d.title,
          joinContentFields([
            d.arabicText,
            d.translation,
            d.lead,
            d.words,
            d.guidance,
            d.benefits,
            d.refs,
          ]),
          entity: d,
        ),
    ];
  }
}

/// The user's own یادداشت‌ها — a hit's [ContentPiece.entity] is the note row,
/// which the editor opens.
class NotesContentSource extends MoreContentSource {
  NotesContentSource() : super('worship-notes');

  @override
  Future<List<ContentPiece>> pieces(WidgetRef? ref) async {
    if (ref == null) return const [];
    final notes = await ref.read(notesProvider.future);
    return [
      for (final n in notes)
        ContentPiece(n.title, joinContentFields([n.content]), entity: n),
    ];
  }
}

List<ContentPiece> _ruqyahPieces() => [
      for (final item in <RuqyahItem>[
        ...RuqyahContent.intro,
        ...RuqyahContent.chapters.expand((c) => c.items),
        ...RuqyahContent.conclusion,
      ])
        ContentPiece(
          item.title ?? '',
          joinContentFields(
              [item.arabic, item.translation, item.body, item.bullets]),
        ),
    ];

List<ContentPiece> _quranSunnahDuaPieces() => [
      for (final d in <DuaFromQuran>[
        ...DuaFromQuranData.quranDuas,
        ...DuaFromQuranData.sunnahDuas,
      ])
        ContentPiece(d.source, joinContentFields([d.arabic, d.persian])),
    ];

/// Every content family, in the order the page shows them. A process-wide
/// list, so each guide parses and each key folds exactly once.
final List<MoreContentSource> kMoreContentSources = [
  JsonGuideSource('purification', 'assets/content/taharah.json'),
  JsonGuideSource('prayer', 'assets/content/salah.json'),
  JsonGuideSource('fasting', 'assets/content/sawm.json'),
  JsonGuideSource('zakat', 'assets/content/zakat.json'),
  JsonGuideSource('hajj-umrah', 'assets/content/hajj.json'),
  JsonGuideSource('inheritance', 'assets/content/inheritance.json'),
  JsonGuideSource('sciences', 'assets/content/sciences.json'),
  ConstSource('ruqyah', _ruqyahPieces),
  ConstSource('dua', _quranSunnahDuaPieces),
  HesnContentSource(),
  NotesContentSource(),
  RiyadContentSource(),
  TaraghibContentSource(),
  MaalimContentSource(),
  HadithBooksContentSource(),
  HadeethEncContentSource(),
  FatwaContentSource(),
  BooksContentSource(),
];

/// Which sources one search wave covers. The page runs [fast] on the
/// keystroke and [deferred] afterwards, so a whole-library scan can never
/// delay the text it already has in memory.
enum MoreSearchPhase { all, fast, deferred }

/// Searches inside every section's own text.
///
/// [query] must already be folded by `normalizeSearchKey` — the page
/// normalizes once and uses it for titles and content alike; [rawQuery] is
/// what the user typed, used to derive the literal a destination paints and
/// to place the snippet window. Each source is capped at [perSource] hits and
/// fails on its own, so one broken section cannot blank the whole result
/// list. [phase] splits the sources into the two waves above.
Future<List<ContentHit>> searchMoreContent({
  required String query,
  required String rawQuery,
  WidgetRef? ref,
  List<MoreContentSource>? sources,
  int perSource = 3,
  int limit = 24,
  MoreSearchPhase phase = MoreSearchPhase.all,
}) async {
  if (!moreContentQueryIsSearchable(query)) return const [];

  final number = moreContentNumberQuery(query);

  Future<List<ContentHit>> ask(MoreContentSource source) async {
    try {
      // A number is a direct question: the entry carrying it answers first,
      // and only a source that does not index numbers (or does not carry this
      // one) falls through to its text search.
      if (number != null && source.hasNumberIndex) {
        final hits = await source.searchByNumber(number, limit: perSource);
        if (hits.isNotEmpty) return hits;
      }
      // A single character is not a text question — but it is a number.
      if (query.length < 2) return const [];
      return await source.search(query, rawQuery, ref: ref, limit: perSource);
    } catch (e) {
      AppLogger.warning('MoreContentSearch', '${source.itemId}: $e');
      return const [];
    }
  }

  final results = await Future.wait([
    for (final source in (sources ?? kMoreContentSources))
      if (phase == MoreSearchPhase.all ||
          source.isDeferred == (phase == MoreSearchPhase.deferred))
        ask(source),
  ]);

  final out = <ContentHit>[];
  for (final hits in results) {
    for (final hit in hits) {
      if (out.length >= limit) return out;
      out.add(hit);
    }
  }
  return out;
}
