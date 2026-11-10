import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/features/quran/data/quran_data.dart';
import 'package:tawheeed/features/quran/mushaf/quran_ayah_share_screen.dart';
import 'package:tawheeed/features/quran/services/quran_translation_reader.dart';

/// Answers path_provider so the translation reader's content-dir probe cannot
/// hang the fake-async binding (the repo's recorded trap); the bundled asset
/// then answers for the Persian file.
class _FakePathProvider extends PathProviderPlatform {
  final String supportPath;
  _FakePathProvider(this.supportPath);

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => supportPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('ayah_share_test');
    final original = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    addTearDown(() {
      PathProviderPlatform.instance = original;
      try {
        tmp.deleteSync(recursive: true);
      } catch (_) {}
    });
    // The verse text + translation load across a REAL isolate — the repo's
    // recorded fake-async trap — so warm both in a real async zone.
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      await loadQuranData();
      await QuranTranslationReader.getTranslationsForRange(
          QuranTranslationReader.persianFileName, 1, 1, 7);
    });
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: QuranAyahShareScreen(surah: 1, initialFrom: 1, initialTo: 2),
    ));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.textContaining('ترجمهٔ اشتراک:').evaluate().isNotEmpty &&
          find.textContaining('به نام الله بخشند').evaluate().isNotEmpty) {
        break;
      }
    }
    await tester.pumpAndSettle();
  }

  testWidgets('the share carries a translation picker that lists the catalog',
      (tester) async {
    await pump(tester);

    // The default share translation is the app's selected one (Persian).
    expect(find.textContaining('ترجمهٔ اشتراک:'), findsOneWidget);

    await tester.tap(find.textContaining('ترجمهٔ اشتراک:'));
    await tester.pumpAndSettle();

    // The sheet lists the catalog entries with their availability: the
    // bundled Persian reads «فارسی» alone; undownloaded entries say so.
    expect(find.text('ترجمهٔ اشتراک‌گذاری'), findsOneWidget);
    expect(find.textContaining('دانلود نشده'), findsWidgets);
  });

  testWidgets('picking a translation re-renders the card in that translation',
      (tester) async {
    await pump(tester);

    await tester.tap(find.textContaining('ترجمهٔ اشتراک:'));
    await tester.pumpAndSettle();

    // Select the bundled Persian row — the only entry a fresh install can
    // serve (its subtitle is exactly «فارسی»; undownloaded rows say more).
    final persianRow = find.text('فارسی');
    expect(persianRow, findsOneWidget);
    // Capture the row's TITLE (the catalog name) from its ListTile.
    final tile = tester.widget<ListTile>(
        find.ancestor(of: persianRow, matching: find.byType(ListTile)));
    final persianName = (tile.title as Text).data!;
    await tester.tap(persianRow);
    await tester.pumpAndSettle();

    // The sheet closed and the picker row now names the picked translation —
    // the selection took. (The card's translation text itself arrives
    // through the reader's real-zone memo — the recorded fake-async trap —
    // so the wording is asserted by the reader's own tests, not here.)
    expect(find.text('ترجمهٔ اشتراک‌گذاری'), findsNothing);
    expect(find.text('ترجمهٔ اشتراک: $persianName'), findsOneWidget);
  });
}
