import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// A chapter (or intro section) of حصن المسلم.
class HesnChapter {
  final int id;
  final int number;
  final String title;
  final String kind;

  const HesnChapter({
    required this.id,
    required this.number,
    required this.title,
    required this.kind,
  });

  bool get isIntro => kind == 'intro';
}

/// A front-matter section of the book (مقدمه‌ها): title + full body text.
class HesnSection {
  final int id;
  final String title;
  final String body;

  const HesnSection({
    required this.id,
    required this.title,
    required this.body,
  });
}

/// One dhikr item with its full commentary (شرح).
class HesnItem {
  final int id;
  final int chapterId;
  final int seq;
  final int? no;
  final String lead;
  final String arabic;
  final String translation;
  final String words;
  final String guidance;
  final String benefits;
  final String refs;

  const HesnItem({
    required this.id,
    required this.chapterId,
    required this.seq,
    this.no,
    this.lead = '',
    this.arabic = '',
    this.translation = '',
    this.words = '',
    this.guidance = '',
    this.benefits = '',
    this.refs = '',
  });
}

/// Offline database service for حصن المسلم (شرح اذکار edition).
///
/// Copies the bundled [hesn.db] asset to the app documents directory on first
/// launch (or whenever the bundled content version changes), then serves
/// instant queries. Mirrors the pattern of `HadeethEncDbService`.
class HesnDbService {
  static HesnDbService? _instance;
  factory HesnDbService() => _instance ??= HesnDbService._();
  HesnDbService._();

  static const String _assetPath = 'assets/hesn.db';

  /// Bumped whenever assets/hesn.db is rebuilt with new content; must match
  /// the PRAGMA user_version written by tool/build_hesn_db.dart.
  static const int _contentVersion = 3;

  /// Readable version of [_contentVersion] (used by the content guard test).
  static int get contentVersion => _contentVersion;

  Database? _db;
  bool _ready = false;
  bool get isReady => _ready;

  Future<void> init() async {
    if (_ready) return;

    final directory = await getApplicationDocumentsDirectory();
    final path = p.join(directory.path, 'hesn.db');
    final file = File(path);

    var needsCopy = !await file.exists();
    if (!needsCopy) {
      try {
        final existing = sqlite3.open(path);
        final v =
            (existing.select('PRAGMA user_version').first.values.first as num?)
                    ?.toInt() ??
                0;
        existing.close();
        needsCopy = v != _contentVersion;
      } catch (_) {
        AppLogger.warning('hesn_db_service', 'operation failed');
        needsCopy = true;
      }
    }

    if (needsCopy) {
      try {
        final data = await rootBundle.load(_assetPath);
        await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      } catch (e) {
        AppLogger.warning('hesn_db_service', 'copy error: $e');
      }
    }

    try {
      _db = sqlite3.open(path);
      _ready = true;
    } catch (e) {
      AppLogger.warning('hesn_db_service', 'open error: $e');
      return;
    }

    try {
      final count =
          _db!.select('SELECT COUNT(*) as c FROM items').first['c'] as int;
      AppLogger.warning('hesn_db_service', 'ready, $count items');
    } catch (e) {
      AppLogger.warning('hesn_db_service', 'ready but query failed: $e');
    }
  }

  /// All chapters in book order (intro sections first, then chapters 1..132).
  Future<List<HesnChapter>> getChapters() async {
    await init();
    if (!_ready) return const [];
    return [
      for (final r in _db!.select(
        'SELECT id, number, title, kind FROM chapters ORDER BY id',
      ))
        HesnChapter(
          id: (r['id'] as num).toInt(),
          number: (r['number'] as num).toInt(),
          title: r['title'] as String,
          kind: r['kind'] as String,
        ),
    ];
  }

  /// Front-matter sections (مقدمه‌ها) in book order.
  Future<List<HesnSection>> getSections() async {
    await init();
    if (!_ready) return const [];
    return [
      for (final r in _db!.select(
        'SELECT id, title, body FROM sections ORDER BY id',
      ))
        HesnSection(
          id: (r['id'] as num).toInt(),
          title: r['title'] as String,
          body: (r['body'] ?? '') as String,
        ),
    ];
  }

  /// All dhikr items in book order.
  Future<List<HesnItem>> getAllItems() async {
    await init();
    if (!_ready) return const [];
    return _rowsToItems(
      _db!.select(
        'SELECT id, chapter_id, seq, no, lead, arabic, translation, words, '
        'guidance, benefits, refs FROM items ORDER BY id',
      ),
    );
  }

  /// Items of a single chapter in reading order.
  Future<List<HesnItem>> getItemsForChapter(int chapterId) async {
    await init();
    if (!_ready) return const [];
    return _rowsToItems(
      _db!.select(
        'SELECT id, chapter_id, seq, no, lead, arabic, translation, words, '
        'guidance, benefits, refs FROM items WHERE chapter_id = ? ORDER BY seq',
        [chapterId],
      ),
    );
  }

  List<HesnItem> _rowsToItems(List<Row> rows) {
    return [
      for (final r in rows)
        HesnItem(
          id: (r['id'] as num).toInt(),
          chapterId: (r['chapter_id'] as num).toInt(),
          seq: (r['seq'] as num).toInt(),
          no: r['no'] == null ? null : (r['no'] as num).toInt(),
          lead: (r['lead'] ?? '') as String,
          arabic: (r['arabic'] ?? '') as String,
          translation: (r['translation'] ?? '') as String,
          words: (r['words'] ?? '') as String,
          guidance: (r['guidance'] ?? '') as String,
          benefits: (r['benefits'] ?? '') as String,
          refs: (r['refs'] ?? '') as String,
        ),
    ];
  }

  void close() {
    _db?.close();
    _db = null;
    _ready = false;
  }
}
