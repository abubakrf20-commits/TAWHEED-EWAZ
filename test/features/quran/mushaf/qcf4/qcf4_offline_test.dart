import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_config.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_data_store.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_download_manager.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_font_loader.dart';

/// Offline unit tests for the QCF4 stack: no network, no real fonts.
///
/// The store/loader/manager are singletons, so the whole file shares one
/// temp documents dir (created in setUpAll) and each test uses distinct
/// pages. `Qcf4DataStore.clearMemory` runs between tests for isolation.
/// Engine font registration is driven through
/// `Qcf4FontLoader.testRegisterHook` because the test engine accepts any
/// bytes as a valid font.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  Directory pagesDir() => Directory(
      p.join(tempDir.path, 'quran_content', Qcf4Config.cacheDirName, 'pages'));
  Directory fontsDir() => Directory(
      p.join(tempDir.path, 'quran_content', Qcf4Config.cacheDirName, 'fonts'));

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('tawheeed_qcf4');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return null;
    });
    SharedPreferences.setMockInitialValues({});
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  tearDown(() {
    Qcf4DataStore.instance.clearMemory();
    Qcf4FontLoader.instance.testRegisterHook = null;
  });

  group('Qcf4DownloadState', () {
    test('defaults mean not-downloaded and idle', () {
      const s = Qcf4DownloadState();
      expect(s.running, isFalse);
      expect(s.done, 0);
      expect(s.fullyDownloaded, isFalse);
      expect(s.failedItems, isEmpty);
      expect(s.error, isNull);
    });

    test('copyWith preserves fields it does not touch', () {
      const s = Qcf4DownloadState(done: 5, total: 10);
      final c = s.copyWith(running: true);
      expect(c.done, 5);
      expect(c.total, 10);
      expect(c.running, isTrue);
      expect(c.failedItems, isEmpty);
    });
  });

  group('Qcf4DataStore offline behavior', () {
    test('missing page with allowNetwork=false reports a miss', () async {
      final res =
          await Qcf4DataStore.instance.loadPage(600, allowNetwork: false);
      expect(res, isA<Qcf4PageMissing>());
      expect((res as Qcf4PageMissing).fetchFromNetwork, isTrue);
    });

    test('corrupt cached page is deleted and reported as a miss', () async {
      final dir = pagesDir();
      await dir.create(recursive: true);
      final file = File(p.join(dir.path, '601.json'));
      await file.writeAsString('this is not json{{{');

      final res =
          await Qcf4DataStore.instance.loadPage(601, allowNetwork: false);
      expect(res, isA<Qcf4PageMissing>());
      expect(await file.exists(), isFalse);
    });

    test('cachedPageCount counts json files', () async {
      final before = await Qcf4DataStore.instance.cachedPageCount();
      final dir = pagesDir();
      await dir.create(recursive: true);
      await File(p.join(dir.path, '602.json')).writeAsString('{}');
      await File(p.join(dir.path, '603.json')).writeAsString('{}');
      expect(await Qcf4DataStore.instance.cachedPageCount(), before + 2);
    });

    test('peek returns the RAM-cached page and null otherwise', () async {
      final dir = pagesDir();
      await dir.create(recursive: true);
      await File(p.join(dir.path, '001.json'))
          .writeAsString('{"page":1,"font":"QCF4_Hafs_01","lines":[]}');

      expect(Qcf4DataStore.instance.peek(1), isNull);

      await Qcf4DataStore.instance.loadPage(1, allowNetwork: false);
      final page = Qcf4DataStore.instance.peek(1);
      expect(page, isNotNull);
      expect(page!.page, 1);
      expect(page.font, 'QCF4_Hafs_01');

      // A disk-only page is NOT visible to peek (it must be decoded first).
      Qcf4DataStore.instance.clearMemory();
      expect(Qcf4DataStore.instance.peek(1), isNull);
    });
  });

  group('Qcf4FontLoader failure handling', () {
    test('corrupt TTF is deleted; a later retry registers cleanly', () async {
      final loader = Qcf4FontLoader.instance;
      const family = 'QCF4_Test_Family';
      final dir = fontsDir();
      await dir.create(recursive: true);
      final file = File(p.join(dir.path, Qcf4Config.fontTtfFileName(family)));
      await file.writeAsBytes([0, 1, 2, 3]);

      // Registration fails (e.g. truncated download): the bad file must go
      // so a later retry fetches fresh bytes instead of failing on it again.
      loader.testRegisterHook = (_, __) async => false;
      expect(await loader.ensure(family), isFalse);
      expect(await file.exists(), isFalse);
      expect(loader.isLoaded(family), isFalse);

      // Retry after clearFailed with a working engine and a fresh payload.
      loader.testRegisterHook = (_, __) async => true;
      loader.clearFailed();
      await file.writeAsBytes([9, 9, 9, 9]);
      expect(await loader.ensure(family), isTrue);
      expect(loader.isLoaded(family), isTrue);
      expect(await file.exists(), isTrue);
    });

    test('unregistered family is not loaded', () {
      expect(Qcf4FontLoader.instance.isLoaded('QCF4_Hafs_99'), isFalse);
    });
  });

  group('Qcf4DownloadManager state', () {
    test('partial cache is not fully downloaded', () async {
      expect(await Qcf4DownloadManager.instance.isFullyDownloaded(), isFalse);
    });

    test('clearAllDownloaded wipes disk and resets state', () async {
      await Qcf4DownloadManager.instance.clearAllDownloaded();
      expect(await Qcf4DataStore.instance.cachedPageCount(), 0);
      expect(await Qcf4FontLoader.instance.cachedFontCount(), 0);
      final s = Qcf4DownloadManager.instance.state.value;
      expect(s.running, isFalse);
      expect(s.done, 0);
      expect(s.fullyDownloaded, isFalse);
      expect(s.failedItems, isEmpty);
    });
  });
}
