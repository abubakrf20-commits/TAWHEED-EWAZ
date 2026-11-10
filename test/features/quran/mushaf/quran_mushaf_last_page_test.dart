// Widget test: the reader must not lose the page the reader is on when the
// screen — or the whole app — goes away inside the 750 ms save debounce.
//
// The user's report: opening the mushaf's last page and coming back later
// lands on the page that was read before it. The debounce that persists
// `quran_last_page` is cancelled on dispose, never flushed, and no lifecycle
// observer flushes it when the app is backgrounded — so a page reached and
// left inside 750 ms (or a process frozen in the background) is never saved
// and the next mount restores the older bookmark.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/app/state/shell_nav.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_reader_prefs.dart';
import 'package:tawheeed/features/quran/mushaf/quran_mushaf_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const lastPageKey = 'quran_last_page';
  const seedPage = 42;
  const lastPage = 604;

  Future<void> pumpReader(
    WidgetTester tester, {
    int storedPage = seedPage,
  }) async {
    // The reader auto-hides its chrome in landscape (`_chromeVisible`), and the
    // default test window is 800x600 — landscape. A phone reads this page in
    // portrait, and the go-to control lives in that chrome, so pin the shape.
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      lastPageKey: storedPage,
      // These tests reach for the go-to control, which lives in the band.
      MushafReaderPrefs.headerVisibleKey: true,
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quranImmersiveProvider.overrideWith(QuranImmersive.new),
        ],
        child: const Directionality(
          textDirection: TextDirection.rtl,
          child: MaterialApp(
            home: Scaffold(
              body: QuranMushafView(),
            ),
          ),
        ),
      ),
    );
    // Let async init (prefs + failed network calls) settle.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Disposing the reader's Drift-backed providers schedules a zero-duration
  /// housekeeping timer, so every test unmounts while the binding still runs.
  Future<void> unmountReader(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// The pager's resting slot (0-based). `PageView.controller` is nullable in
  /// the SDK, hence the `?.` — the reader always passes one.
  int? restedIndex(WidgetTester tester) =>
      tester.widget<PageView>(find.byType(PageView)).controller?.page?.round();

  Future<int?> storedPage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(lastPageKey);
  }

  /// Opens the go-to dialog from the header — its centre block prints
  /// «جزء N · صفحه M» and is the go-to tap target — then jumps to [page].
  ///
  /// The jump animates for 350 ms, and `_onPageChanged` only runs when the
  /// pager settles, so the 750 ms save debounce starts at the end of that
  /// animation — this helper deliberately stops one pump after it.
  Future<void> goToPage(WidgetTester tester, int page) async {
    await tester.tap(find.textContaining('صفحه '));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(
      find.widgetWithText(TextField, 'شماره صفحه (1 تا 604)'),
      '$page',
    );
    await tester.tap(find.text('برو'));
    // The dialog pops, then the pager animates for 350 ms.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  void readerTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      await body(tester);
      await unmountReader(tester);
    });
  }

  readerTest('a page left inside the save debounce is still persisted',
      (tester) async {
    await pumpReader(tester);
    expect(
      restedIndex(tester),
      seedPage - 1,
      reason: 'the saved bookmark (page $seedPage) is restored on mount',
    );

    await goToPage(tester, lastPage);
    expect(restedIndex(tester), lastPage - 1);

    // Leave the reader INSIDE the 750 ms debounce window — this is exactly
    // what the user does after opening the last page for a quick look.
    await unmountReader(tester);

    expect(await storedPage(), lastPage);
  });

  readerTest('a page reached before the app is backgrounded is persisted',
      (tester) async {
    await pumpReader(tester);

    await goToPage(tester, lastPage);
    expect(restedIndex(tester), lastPage - 1);

    // Android freezes (or kills) the process from paused; without a lifecycle
    // flush the pending page never reaches prefs.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(await storedPage(), lastPage);
  });

  readerTest('the persisted page is where the next mount opens',
      (tester) async {
    await pumpReader(tester);

    await goToPage(tester, lastPage);
    // Let the debounce fire this time: the control case for the two tests
    // above — the write path itself works, so their failures are the window.
    await tester.pump(const Duration(milliseconds: 800));
    expect(await storedPage(), lastPage);

    await unmountReader(tester);
    await pumpReader(tester, storedPage: lastPage);
    expect(restedIndex(tester), lastPage - 1);
    expect(find.textContaining('صفحه $lastPage'), findsOneWidget);
  });
}
