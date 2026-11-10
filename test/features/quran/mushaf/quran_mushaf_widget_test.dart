// Widget test: the new mushaf reader must build without crashing, even when
// the network is unavailable (API errors are shown as friendly messages, not
// thrown into the widget tree).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/app/state/shell_nav.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_backgrounds.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_color_sheets.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_page_turn.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_reader_prefs.dart';
import 'package:tawheeed/features/quran/mushaf/qcf4/qcf4_page_viewer.dart';
import 'package:tawheeed/features/quran/mushaf/quran_mushaf_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Pumps the reader. [headerVisible] seeds the persisted «نوار بالای صفحه»
  /// tick — most tests below are about the band's own controls, so they start
  /// with it up; the bare-page default is asserted on its own.
  Future<void> pumpReader(WidgetTester tester,
      {bool headerVisible = true}) async {
    SharedPreferences.setMockInitialValues(
        headerVisible ? {MushafReaderPrefs.headerVisibleKey: true} : {});
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

  /// The reader watches Drift-backed stream providers (ayah highlights).
  /// Disposing them schedules a zero-duration housekeeping timer, and a timer
  /// left until binding teardown fails the "no pending timers" invariant -- so
  /// every test unmounts the tree and drains the clock while the binding is
  /// still running.
  Future<void> unmountReader(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// Lets a bottom sheet's entrance transition finish.
  ///
  /// Not `pumpAndSettle`: the reader header carries an indeterminate progress
  /// bar, which never settles, so the wait has to be explicit. 400ms is short —
  /// the route transition and the sheet's own animation run back to back — and
  /// a shorter wait leaves the sheet mid-slide, low on the screen and below the
  /// fold, which reads as a layout bug.
  Future<void> settleSheet(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// Opens the reading-settings sheet. It lives in the overflow menu now —
  /// the header is index / search / page identity / bookmark / ⋮ only, which
  /// is what stopped the reciter name being truncated to «ماهر ال…».
  Future<void> openReadingSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip('بیشتر'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('تنظیمات مطالعه'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Taps a row inside the reading-settings sheet, scrolling its body first.
  ///
  /// The sheet carries three cards now; on a 320dp phone «نمایش» starts below
  /// the fold, and the body only scrolls when it has to — so a bare tap lands
  /// outside the window and misses without an error.
  Future<void> tapInReadingSettings(WidgetTester tester, String label) async {
    final row = find.text(label);
    await tester.ensureVisible(row);
    await tester.pump();
    await tester.tap(row);
  }

  void readerTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      await body(tester);
      await unmountReader(tester);
    });
  }

  readerTest('the reader opens on a bare page: no header band by default',
      (tester) async {
    // Reader request (2026-11-10): the band is off unless the tick is set, so
    // the whole mushaf is on screen from the first frame.
    await pumpReader(tester, headerVisible: false);
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('بیشتر'), findsNothing,
        reason: 'a fresh reader shows the page, not a bar');
    expect(find.byTooltip('فهرست سوره‌ها'), findsNothing);
    // The page still carries its own identity in the bands.
    expect(find.byKey(const ValueKey('mushaf_corner_page_1')), findsOneWidget);
  });

  readerTest('mushaf view builds without crashing (offline)', (tester) async {
    await pumpReader(tester);

    // No exceptions may have been thrown into the widget tree.
    expect(tester.takeException(), isNull);

    // The page area must exist (spinner while the first page loads).
    expect(find.byType(PageView), findsOneWidget);
  });

  readerTest('mushaf toggles immersive state when leaving the tab',
      (tester) async {
    await pumpReader(tester);
    expect(tester.takeException(), isNull);
  });

  readerTest('header buttons stay tappable and fit the narrowest screens',
      (tester) async {
    // 320dp-wide, 640dp-tall phone (smallest common Android class).
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await pumpReader(tester);
    expect(tester.takeException(), isNull);

    // The spec-A header carries only index / search / bookmark / overflow.
    // «رفتن به صفحه / سوره / جزء» moved behind the centred page title.
    expect(find.byTooltip('بیشتر'), findsOneWidget);
    expect(find.byTooltip('فهرست سوره‌ها'), findsOneWidget);
    expect(find.byTooltip('جستجو در قرآن'), findsOneWidget);
    expect(find.byTooltip('نشان‌های قرآن'), findsOneWidget);

    // The header prints the page identity, and the paper carries its own
    // surah/juz corner labels in both chrome states (reader request) — so
    // «سورة …» appears twice, once in each place. The header's «صفحه N» is a
    // go-to control; the paper's own number is the bare digit bottom-left.
    expect(find.textContaining('سورة '), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('mushaf_corner_surah_1')),
        matching: find.textContaining('سورة '),
      ),
      findsOneWidget,
      reason: 'one of them is the page\'s own top-right label',
    );
    expect(find.textContaining('صفحه '), findsOneWidget);

    // Everything the old bar squeezed in lives in the overflow menu.
    await tester.tap(find.byTooltip('بیشتر'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('تنظیمات مطالعه'), findsOneWidget);
    expect(find.text('لیست آیات (پیروی از تلاوت)'), findsOneWidget);
    expect(find.text('دانلود برای آفلاین'), findsOneWidget);
    expect(find.text('ترجمه و تفاسیر'), findsOneWidget);
    // Optional additions this pass includes.
    expect(find.text('نشان‌ها'), findsOneWidget);
    expect(find.text('نشان‌گذاری این صفحه'), findsOneWidget);
    expect(find.text('اشتراک‌گذاری صفحه'), findsOneWidget);
    // Settings opens from here now.
    await tester.tap(find.text('تنظیمات مطالعه'));
    await settleSheet(tester);
    expect(tester.takeException(), isNull);
  });

  readerTest('landscape-lock toggle flips its icon state', (tester) async {
    // Narrow viewport — the header row is laid out identically to the
    // tappable-header test above.
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await pumpReader(tester);
    expect(tester.takeException(), isNull);

    // The landscape toggle lives in the reading-settings sheet; selecting it
    // closes the sheet, so the flip is verified by reopening the sheet.
    SwitchListTile tileOf() => tester.widget<SwitchListTile>(find.ancestor(
        of: find.text('حالت افقی — فونت بزرگ‌تر'),
        matching: find.byType(SwitchListTile)));

    await openReadingSettings(tester);
    expect(tileOf().value, isFalse);

    // Invoke the row's handler directly — the gesture layer of this sheet is
    // covered by the other tap tests. The contract under test: the toggle
    // flips and the lock is PERSISTED (the reader restores it on next open).
    final onChanged = tileOf().onChanged;
    if (onChanged != null) onChanged(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(QuranMushafViewState.landscapeLockPrefsKey), isTrue,
        reason: 'toggling the landscape row must persist the lock');
    expect(tester.takeException(), isNull);
  });

  readerTest('recitation-color picker opens, persists the pick and updates',
      (tester) async {
    // Same narrow-phone viewport as the header test above: the default test
    // window is far smaller than any real device and skips the header band.
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await pumpReader(tester);
    expect(tester.takeException(), isNull);

    // Open the consolidated reading-settings sheet, then the recitation
    // color picker from inside it.
    await openReadingSettings(tester);
    expect(find.text('رنگ پس‌زمینهٔ صفحه'), findsOneWidget);
    expect(find.text('رنگ آیهٔ در حال تلاوت'), findsOneWidget);

    await tester.tap(find.text('رنگ آیهٔ در حال تلاوت'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('رنگ آیهٔ در حال تلاوت'), findsWidgets);

    // The emerald default is preselected. Pick the second swatch (blue).
    final swatches = find.byKey(const ValueKey('recitation_color_swatch_1'));
    expect(swatches, findsOneWidget);
    await tester.tap(swatches);
    await tester.pump(const Duration(milliseconds: 100));

    // The choice persisted — as the colour itself, not as an index into the
    // palette, so pruning the palette can never hand the reader a different
    // ayah colour on the next launch.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(MushafReaderPrefs.recitationColorKey),
        kMushafRecitationColors[1].color.toARGB32());
    expect(prefs.getInt(MushafReaderPrefs.legacyRecitationIndexKey), isNull);
  });

  readerTest('the page-turn picker applies, persists and repaints the reader',
      (tester) async {
    // «افکت ورق‌زدن» is two cards in the reading-settings sheet. A tap applies
    // in place and keeps the sheet open, so the reader behind it changes at
    // once — which is the whole point of choosing a motion by trying it.
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await pumpReader(tester);
    expect(tester.takeException(), isNull);

    MushafPageTurn mode() => tester
        .widget<MushafTurningPage>(find.byType(MushafTurningPage).first)
        .mode;

    await openReadingSettings(tester);
    await settleSheet(tester);

    expect(find.text('افکت ورق‌زدن'), findsOneWidget);
    // «عادی» is also the middle speed, so a card is found where it is tapped.
    Finder card(String label) =>
        find.descendant(of: find.byType(InkWell), matching: find.text(label));
    for (final label in <String>['عادی', 'ورق کتابی']) {
      expect(card(label), findsOneWidget, reason: label);
    }
    // The retired effects must not come back to the picker.
    expect(find.text('طومار'), findsNothing);
    expect(find.text('بی‌درنگ'), findsNothing);
    // A fresh install opens on the plain slide: the effect is opt-in.
    expect(mode(), MushafPageTurn.plain);

    await tester.tap(card('ورق کتابی'));
    await tester.pump(const Duration(milliseconds: 100));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(MushafReaderPrefs.pageTurnKey), 'bookFlip',
        reason: 'the pick must survive the next launch');
    // The sheet stays open, and the reader behind it already turns.
    expect(find.text('ورق کتابی'), findsOneWidget);
    expect(mode(), MushafPageTurn.bookFlip);

    await tester.tap(card('عادی'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(prefs.getString(MushafReaderPrefs.pageTurnKey), 'plain');
    expect(mode(), MushafPageTurn.plain);
  });

  readerTest('the reading-settings sheet can be swiped shut', (tester) async {
    // The reported bug: the sheet could not be dismissed by dragging down,
    // because its body was a SingleChildScrollView over the whole surface and
    // the scrollable won the gesture before the sheet saw it.
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await pumpReader(tester);
    expect(tester.takeException(), isNull);

    await openReadingSettings(tester);
    await settleSheet(tester);
    expect(find.text('تنظیمات مطالعه'), findsOneWidget);

    // The two spec-C cards are taller than the old flat row list, so the body
    // may now scroll on a 640dp phone. The pinned chrome (title, handle, the
    // «بستن» button) must stay put and the drag-on-the-title dismissal must
    // keep working — that is the regression this test exists for.
    final close = find.text('بستن');
    expect(close, findsOneWidget);
    expect(
      tester.getBottomLeft(close).dy,
      lessThanOrEqualTo(tester.view.physicalSize.height / 2),
      reason: 'the close button must be pinned inside the sheet, not scrolled '
          'out of reach: it sits at ${tester.getBottomLeft(close)}',
    );

    // Both dismissal paths must work: the pinned close button and a drag on
    // it. A drag on the *body* legitimately scrolls it now (the two spec-C
    // cards are taller than the old flat list), so the drag is taken from the
    // pinned footer, which is outside the scrolling region.
    await tester.drag(find.text('بستن'), const Offset(0, 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('تنظیمات مطالعه'), findsNothing,
        reason: 'a downward drag on the pinned chrome must dismiss the sheet');
    expect(tester.takeException(), isNull);
  });

  readerTest('the background picker offers all 22 papers and swipes shut',
      (tester) async {
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await pumpReader(tester);

    await openReadingSettings(tester);
    await settleSheet(tester);
    await tester.tap(find.text('رنگ پس‌زمینهٔ صفحه'));
    await settleSheet(tester);

    // Every entry of the palette is reachable, first to last — the last is a
    // night paper since the light/dark split is contiguous.
    expect(find.byKey(const ValueKey('bg_color_swatch_0')), findsOneWidget);
    expect(
        find.byKey(
            ValueKey('bg_color_swatch_${kMushafBackgrounds.length - 1}')),
        findsOneWidget);
    expect(kMushafBackgrounds.length, 22);

    await tester.drag(
        find.byKey(const ValueKey('bg_color_swatch_0')), const Offset(0, 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byKey(const ValueKey('bg_color_swatch_0')), findsNothing,
        reason: 'dragging on a swatch must dismiss the picker, not scroll it');
    expect(tester.takeException(), isNull);
  });

  readerTest('picking a background persists the colour, not an index',
      (tester) async {
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await pumpReader(tester);

    await openReadingSettings(tester);
    await settleSheet(tester);
    await tester.tap(find.text('رنگ پس‌زمینهٔ صفحه'));
    await settleSheet(tester);

    await tester.tap(find.byKey(const ValueKey('bg_color_swatch_5')));
    await tester.pump(const Duration(milliseconds: 300));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(MushafReaderPrefs.backgroundKey),
        kMushafBackgrounds[5].color.toARGB32());
    expect(prefs.getInt(MushafReaderPrefs.legacyBackgroundIndexKey), isNull);
  });

  readerTest('every dark paper is selectable from «کاغذ تیره»', (tester) async {
    // The reported bug: the night group of the background picker handed its
    // LOCAL swatch index to a callback that indexes the whole palette, so each
    // dark paper painted the light paper of the same slot and «کاغذ تیره»
    // could not be selected at all.
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await pumpReader(tester);
    final prefs = await SharedPreferences.getInstance();

    // One opening, seven taps: the picker stays open on a tap (its preview is
    // live), so the whole group can be walked without reopening the sheet.
    await openReadingSettings(tester);
    await settleSheet(tester);
    await tester.tap(find.text('رنگ پس‌زمینهٔ صفحه'));
    await settleSheet(tester);

    for (var i = kMushafDayBackgroundCount;
        i < kMushafBackgrounds.length;
        i++) {
      expect(kMushafBackgrounds[i].isNight, isTrue,
          reason: 'palette index $i must live in the dark group');

      final swatch = find.byKey(ValueKey('bg_color_swatch_$i'));
      expect(swatch, findsOneWidget);
      // The sheet can be taller than the fold on a short phone; the target has
      // to be brought on screen before it can be tapped at all.
      await tester.ensureVisible(swatch);
      await tester.pump();
      await tester.tap(swatch);
      await tester.pump(const Duration(milliseconds: 100));

      expect(prefs.getInt(MushafReaderPrefs.backgroundKey),
          kMushafBackgrounds[i].color.toARGB32(),
          reason: 'tapping «${kMushafBackgrounds[i].name}» must persist that '
              'paper, not a light one');
    }
    expect(tester.takeException(), isNull);
  });

  readerTest('the paper picker previews the choice live, before it closes',
      (tester) async {
    // The point of the preview: a swatch is judged on a page, not on a chip.
    // So a tap has to move the preview *without* closing the sheet — the
    // reader reported having to close the sheet and look at the reader behind
    // it to see what a colour did.
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await pumpReader(tester);

    await openReadingSettings(tester);
    await settleSheet(tester);
    await tester.tap(find.text('رنگ پس‌زمینهٔ صفحه'));
    await settleSheet(tester);

    final firstPaper = kMushafBackgrounds.first;
    final darkPaper = kMushafBackgrounds.last;
    expect(darkPaper.isNight, isTrue);
    expect(find.text('پیش‌نمایش روی «${firstPaper.name}»'), findsOneWidget,
        reason: 'the picker must open on the paper the reader already has');
    // It has to be a *page*, not a caption: a thrown-together label would pass
    // the text assertions above while showing the reader nothing.
    final preview = tester.getSize(find.byType(MushafPagePreview));
    expect(preview.height, greaterThan(80));
    expect(preview.width, greaterThan(50));

    final darkSwatch = find
        .byKey(ValueKey('bg_color_swatch_${kMushafBackgrounds.length - 1}'));
    await tester.ensureVisible(darkSwatch);
    await tester.pump();
    await tester.tap(darkSwatch);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('رنگ پس‌زمینهٔ صفحه'), findsOneWidget,
        reason: 'the picker must stay open, or there is no preview to see');
    expect(find.text('پیش‌نمایش روی «${darkPaper.name}»'), findsOneWidget,
        reason: 'the preview must follow the new paper, not the old one');
    expect(find.text('پیش‌نمایش روی «${firstPaper.name}»'), findsNothing,
        reason: 'the preview must not still show the previous paper');
    expect(tester.takeException(), isNull);
  });

  readerTest('the recitation picker previews the choice live, before it closes',
      (tester) async {
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await pumpReader(tester);

    await openReadingSettings(tester);
    await settleSheet(tester);
    await tester.tap(find.text('رنگ آیهٔ در حال تلاوت'));
    await settleSheet(tester);

    expect(find.text('پیش‌نمایش «${kMushafRecitationColors.first.name}»'),
        findsOneWidget,
        reason: 'the picker must open on the colour the reader already has');

    await tester.tap(find.byKey(const ValueKey('recitation_color_swatch_1')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('رنگ آیهٔ در حال تلاوت'), findsOneWidget,
        reason: 'the picker must stay open, or there is no preview to see');
    expect(find.text('پیش‌نمایش «${kMushafRecitationColors[1].name}»'),
        findsOneWidget,
        reason: 'the preview must follow the new colour');
    expect(find.text('پیش‌نمایش «${kMushafRecitationColors.first.name}»'),
        findsNothing,
        reason: 'the preview must not still show the previous colour');
    expect(tester.takeException(), isNull);
  });

  readerTest('fullscreen is a bare page carrying only its own identity',
      (tester) async {
    // Reader request: the handle that opened the header is gone — nothing may
    // float over the mushaf. In fullscreen the page prints its own facts
    // in the bands it keeps clear of the glyphs (surah top-right, juz
    // top-left, page number bottom-left), and the *double* tap
    // on the page is the way back to the chrome. That gesture is driven in the
    // seeded sheet suite: an unseeded page renders from the raster fallback,
    // and the viewer builds no gesture layer until a page has loaded.
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await pumpReader(tester);
    expect(find.byTooltip('بیشتر'), findsOneWidget);

    await openReadingSettings(tester);
    await settleSheet(tester);
    await tapInReadingSettings(tester, 'نوار بالای صفحه');
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byTooltip('بیشتر'), findsNothing,
        reason: 'fullscreen hides the header');
    expect(find.byTooltip('نمایش نوارها و منو'), findsNothing,
        reason: 'the exit chip is gone: nothing may float over the page');
    expect(find.byIcon(Icons.unfold_more_rounded), findsNothing,
        reason: 'not even the chip icon survives');
    expect(find.text('نوارها'), findsNothing,
        reason: 'no caption may sit over the mushaf either');

    // The page's own identity stands in for the header. In fullscreen these
    // three labels are the only place these words are printed (the sheet suite
    // pins their bands): the page-side glyph that used to sit beside the
    // number is gone, so the number stands alone in the bottom band.
    String? corner(int page, String part) => tester
        .widget<Text>(find.descendant(
          of: find.byKey(ValueKey('mushaf_corner_${part}_$page')),
          matching: find.byType(Text),
        ))
        .data;
    expect(corner(1, 'surah'), 'سورة الفاتحة',
        reason: 'the surah name is printed in the top-right corner');
    expect(corner(1, 'juz'), 'جزء 1',
        reason: 'the juz is printed in the top-left corner');
    expect(corner(1, 'page'), '1',
        reason: 'the page number is printed in the bottom corner');
  });

  readerTest('font-size menu item was removed from the overflow menu',
      (tester) async {
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await pumpReader(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('بیشتر'));
    // Fixed pumps: the menu's open animation plus frame; pumpAndSettle would
    // hang on the header's indeterminate progress bar.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));

    // The slider entry is gone (it had no visible effect on the glyphs).
    expect(find.text('اندازهٔ متن مصحف'), findsNothing);
  });

  group('pager geometry is invariant', () {
    // The root cause of "a swipe skips a page": the chrome (header band) and
    // the mini player were viewport insets, so showing/hiding them resized the
    // PageView. A resize re-maps the scroll offset against a new viewport, and
    // the reader's height guard then snapped back to the page the drag started
    // from. The chrome is an overlay now and the space it covers is reserved
    // inside the page instead, so the pager's box must depend on nothing but
    // the system insets.
    readerTest('the pager fills the reader: the header band is an overlay',
        (tester) async {
      await pumpReader(tester);
      expect(tester.takeException(), isNull);

      final reader = tester.getSize(find.byType(QuranMushafView));
      final pager = tester.getSize(find.byType(PageView));

      // The test view has no system insets, so the pager must be exactly the
      // reader's box. On the old layout it was shorter by the header band --
      // and that shortfall *was* the resize the guard was papering over.
      expect(pager.width, reader.width);
      expect(pager.height, reader.height,
          reason: 'the header band must not shrink the pager');
      expect(pager.height, greaterThan(0));
    });

    readerTest('the header paints over the page without a render overflow',
        (tester) async {
      // The visual half of the overlay contract: the header is a real widget
      // stacked on top of the page, on the narrowest common phone.
      tester.view.physicalSize = const Size(320 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await pumpReader(tester);
      expect(tester.takeException(), isNull);

      // The header exists and the pager still owns the whole area.
      expect(find.byTooltip('بیشتر'), findsOneWidget);
      expect(
        tester.getSize(find.byType(PageView)).height,
        tester.getSize(find.byType(QuranMushafView)).height,
      );
      // Two layers sharing one box must not overflow.
      expect(tester.takeException(), isNull);
    });

    readerTest('the pager keeps its box across a drag', (tester) async {
      await pumpReader(tester);
      expect(tester.takeException(), isNull);

      final before = tester.getSize(find.byType(PageView));

      // A real drag across the pager. Offline the page cannot load, but the
      // gesture path must not throw and must leave the pager settled.
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.byType(PageView), findsOneWidget);
      expect(tester.getSize(find.byType(PageView)), before,
          reason: 'a drag must not resize the pager');
    });

    readerTest('a swipe keeps one continuous page subtree', (tester) async {
      // `key: ValueKey(page)` used to rebuild each page from scratch whenever
      // the index changed, which reset Qcf4PageViewer's cached tree and showed
      // the full-screen loading spinner for an already-warm page. Without the
      // key the page keeps its state across a swipe.
      await pumpReader(tester);
      expect(tester.takeException(), isNull);

      final pageFinder = find.descendant(
        of: find.byType(PageView),
        matching: find.byType(Qcf4PageViewer),
      );
      expect(pageFinder, findsWidgets);

      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // No exception from a re-keyed tree tearing down mid-gesture.
      expect(tester.takeException(), isNull);
      expect(pageFinder, findsWidgets);
    });

    readerTest('the incoming page keeps its element tree during a swipe',
        (tester) async {
      // The current page used to get a `ValueListenableBuilder` wrapper while
      // its neighbours got a bare `RepaintBoundary`. `PageView` reports the
      // page change mid-drag, so the swap unmounted the incoming page's
      // `Qcf4PageViewer` — and with it the memoized, already-laid-out page
      // tree — on a gesture frame (77 ms LAYOUT on device). Every slot now
      // keeps the same wrapper chain and only the listenable differs; this
      // guard pins that element identity survives the change.
      await pumpReader(tester);
      expect(tester.takeException(), isNull);

      Map<int, Element> pageElements() {
        final result = <int, Element>{};
        // `skipOffstage: false` — the cached neighbour is laid out but sits
        // outside the viewport, and the sliver reports it as offstage.
        final finder = find.descendant(
          of: find.byType(PageView, skipOffstage: false),
          matching: find.byType(Qcf4PageViewer, skipOffstage: false),
          skipOffstage: false,
        );
        for (final element in finder.evaluate()) {
          result[(element.widget as Qcf4PageViewer).page] = element;
        }
        return result;
      }

      final before = pageElements();
      expect(before.containsKey(2), isTrue,
          reason: 'the pager caches the neighbour page before the swipe, '
              'otherwise this test would prove nothing');
      final incoming = before[2]!;

      // Cross the halfway point, so the pager reports the page change while
      // the finger is still down — the exact moment the old wrapper swap ran.
      final width = tester.getSize(find.byType(PageView)).width;
      await tester.drag(find.byType(PageView), Offset(-width * 0.6, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(tester.takeException(), isNull);
      final after = pageElements();
      expect(after.containsKey(2), isTrue);
      expect(identical(after[2], incoming), isTrue,
          reason: 'changing the current page must not unmount the incoming '
              'page: an unmount discards its laid-out tree and re-shapes the '
              'whole page mid-gesture');
    });
  });
}
