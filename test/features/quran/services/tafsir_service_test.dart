import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:tawheeed/features/quran/services/quran_content_service.dart';
import 'package:tawheeed/features/quran/services/tafsir_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('tawheeed_tafsir');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return null;
    });
    final contentDir = Directory(p.join(tempDir.path, 'quran_content'));
    await contentDir.create(recursive: true);
    final db = sqlite3.open(p.join(contentDir.path, 'mokhtasar_fa.db'));
    try {
      db.execute('CREATE TABLE contents (sura INT, ayah INT, text TEXT)');
      db.execute("INSERT INTO contents VALUES (1, 1, 'text-of-1-1')");
      db.execute("INSERT INTO contents VALUES (1, 2, 'text-of-1-2')");
      db.execute("INSERT INTO contents VALUES (1, 3, 'text-of-1-3')");
    } finally {
      db.close();
    }
    TafsirDbInfo.downloaded.add(const TafsirDbInfo(
      id: 900,
      name: 'المختصر',
      fileName: 'mokhtasar_fa.db',
    ));
  });

  tearDown(() async {
    TafsirService.close();
    TafsirDbInfo.downloaded.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('TafsirDbInfo', () {
    test('byId(169) prefers the mokhtasar db', () {
      final info = TafsirDbInfo.byId(169);
      expect(info, isNotNull);
      expect(info!.fileName, 'mokhtasar_fa.db');
    });

    test('byId matches the stored id and returns null for unknown', () {
      expect(TafsirDbInfo.byId(900), isNotNull);
      expect(TafsirDbInfo.byId(12345), isNull);
    });

    test('byId(169) never substitutes a foreign tafsir for المختصر', () {
      TafsirDbInfo.downloaded.clear();
      TafsirDbInfo.downloaded.add(const TafsirDbInfo(
        id: 901,
        name: 'تفسیر عربی',
        fileName: 'some_arabic_tafsir.db',
      ));
      // Must be null so databaseFor falls back to the bundled المختصر db —
      // showing another language as the default is a silent wrong-language bug.
      expect(TafsirDbInfo.byId(169), isNull);
    });

    test('idForContentFile is deterministic and non-negative', () {
      const file = QuranContentFile(
          id: 'x',
          type: 'tafsir',
          name: 't',
          fileName: 'mokhtasar_fa.db',
          sizeMB: 1);
      final a = TafsirDbInfo.idForContentFile(file);
      final b = TafsirDbInfo.idForContentFile(file);
      expect(a, b);
      expect(a, greaterThanOrEqualTo(0));
    });
  });

  group('TafsirService queries', () {
    test('getTafsir returns the text for an ayah', () async {
      expect(await TafsirService.getTafsir(1, 2), 'text-of-1-2');
    });

    test('getTafsir returns null for an ayah without an entry', () async {
      expect(await TafsirService.getTafsir(1, 99), isNull);
    });

    test('getTafsirForRange maps ayah -> text in order', () async {
      final map = await TafsirService.getTafsirForRange(1, 2, 3);
      expect(map, {2: 'text-of-1-2', 3: 'text-of-1-3'});
    });

    test('databaseFor throws for an unknown tafsir id', () async {
      expect(() => TafsirService.databaseFor(9999), throwsA(isA<Exception>()));
    });
  });

  group('TafsirService bundled fallback', () {
    test('seeds the bundled المختصر db when nothing is downloaded', () async {
      TafsirDbInfo.downloaded.clear();
      final db = await TafsirService.databaseFor(TafsirService.defaultTafsirId);
      final rows = db.select(
          'SELECT text FROM contents WHERE sura = 1 AND ayah = 1 LIMIT 1');
      expect(rows, isNotEmpty);
    });
  });
}
