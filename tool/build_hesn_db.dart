// Builds assets/hesn.db (compact SQLite) from the parsed hesn.docx JSON.
//
// Usage:
//   dart run tool/build_hesn_db.dart <parsed.json> <output.db> [sqlite3.dll]
//
// The optional third argument points to a Windows sqlite3.dll for the CLI run
// (the app itself uses sqlite3_flutter_libs at runtime).
import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

void main(List<String> args) {
  // ignore: avoid_print
  final jsonPath = args[0];
  final outPath = args[1];

  final raw = File(jsonPath).readAsStringSync();
  final data = json.decode(raw) as Map<String, dynamic>;
  final intros = (data['intros'] as List).cast<Map<String, dynamic>>();
  final chapters = (data['chapters'] as List).cast<Map<String, dynamic>>();

  final dbFile = File(outPath);
  if (dbFile.existsSync()) dbFile.deleteSync();

  final db = sqlite3.open(outPath);
  db.execute('PRAGMA journal_mode = OFF');
  db.execute('''
    CREATE TABLE chapters (
      id INTEGER PRIMARY KEY,
      number INTEGER NOT NULL,
      title TEXT NOT NULL,
      kind TEXT NOT NULL DEFAULT 'chapter'
    )
  ''');
  db.execute('''
    CREATE TABLE items (
      id INTEGER PRIMARY KEY,
      chapter_id INTEGER NOT NULL,
      seq INTEGER NOT NULL,
      no INTEGER,
      lead TEXT NOT NULL DEFAULT '',
      arabic TEXT NOT NULL DEFAULT '',
      translation TEXT NOT NULL DEFAULT '',
      words TEXT NOT NULL DEFAULT '',
      guidance TEXT NOT NULL DEFAULT '',
      benefits TEXT NOT NULL DEFAULT '',
      refs TEXT NOT NULL DEFAULT ''
    )
  ''');
  db.execute('CREATE INDEX idx_items_chapter ON items(chapter_id)');
  db.execute('''
    CREATE TABLE sections (
      id INTEGER PRIMARY KEY,
      title TEXT NOT NULL,
      body TEXT NOT NULL
    )
  ''');

  final insertChapter = db.prepare(
    'INSERT INTO chapters (id, number, title, kind) VALUES (?, ?, ?, ?)',
  );
  final insertItem = db.prepare('''
    INSERT INTO items
      (chapter_id, seq, no, lead, arabic, translation, words, guidance, benefits, refs)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  ''');
  final insertSection = db.prepare(
    'INSERT INTO sections (id, title, body) VALUES (?, ?, ?)',
  );

  String joinLines(dynamic v) =>
      ((v as List?) ?? const []).map((e) => e.toString()).join('\n');

  var chapterId = 0;

  db.execute('BEGIN');
  for (final intro in intros) {
    chapterId++;
    insertChapter.execute([
      chapterId, 0, intro['title'] as String, 'intro',
    ]);
    insertSection.execute([
      chapterId,
      intro['title'] as String,
      joinLines(intro['body']),
    ]);
  }
  for (final ch in chapters) {
    chapterId++;
    insertChapter.execute([
      chapterId,
      (ch['number'] as num).toInt(),
      ch['title'] as String,
      'chapter',
    ]);
    final items = (ch['items'] as List).cast<Map<String, dynamic>>();
    for (final it in items) {
      insertItem.execute([
        chapterId,
        (it['seq'] as num).toInt(),
        it['no'] == null ? null : (it['no'] as num).toInt(),
        (it['lead'] ?? '') as String,
        (it['arabic'] ?? '') as String,
        (it['translation'] ?? '') as String,
        joinLines(it['words']),
        joinLines(it['guidance']),
        joinLines(it['benefits']),
        joinLines(it['refs']),
      ]);
    }
  }
  db.execute('COMMIT');

  insertChapter.close();
  insertItem.close();
  insertSection.close();

  // Must match HesnDbService._contentVersion so the app recopies the asset
  // when content changes.
  db.execute('PRAGMA user_version = 2');
  db.execute('VACUUM');
  final count = db.select('SELECT COUNT(*) c FROM chapters').first['c'];
  final icount = db.select('SELECT COUNT(*) c FROM items').first['c'];
  final scount = db.select('SELECT COUNT(*) c FROM sections').first['c'];
  db.close();

  final size = dbFile.lengthSync();
  // ignore: avoid_print
  print('built $outPath: chapters=$count items=$icount sections=$scount '
      'size=${(size / 1024).toStringAsFixed(0)}KB');
}
