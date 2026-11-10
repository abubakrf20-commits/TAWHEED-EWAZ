import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/features/home/presentation/widgets/quick_actions.dart';
import 'package:tawheeed/features/settings/presentation/more/more_duotone.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpActions(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(child: QuickActions()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('restored quick access shows the saved tiles plus add',
      (tester) async {
    await pumpActions(tester);
    expect(find.text('دسترسی سریع'), findsOneWidget);
    // Defaults from the provider cache.
    expect(find.text('قبله‌نما'), findsOneWidget);
    expect(find.text('ختم قرآن'), findsOneWidget);
    expect(find.text('افزودن'), findsOneWidget);
    // The More page's Style-2 squircle, one per tile.
    expect(find.byKey(const ValueKey('quick-tile')), findsNWidgets(3));
  });

  testWidgets('a shortcut fills its four-column cell instead of floating in it',
      (tester) async {
    await pumpActions(tester);
    // 800dp card width → cell (800 − 24) / 4 = 194 → 0.92 · 194 hits the 88
    // ceiling. The user's complaint was the air AROUND the tile, so the old
    // More-page ratio (72 here) is no longer the reference.
    final box = tester
        .firstRenderObject<RenderBox>(find.byKey(const ValueKey('quick-tile')));
    expect(box.size.width, quickTileSize(194));
    expect(box.size.width, 88);
    expect(quickTileSize(83), greaterThan(moreTileSize(83)));
    expect(quickTileSize(194), lessThanOrEqualTo(194));
  });

  testWidgets('neighbouring shortcuts are one gutter apart, not a third of a cell',
      (tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpActions(tester);

    final tiles = find.byKey(const ValueKey('quick-tile'));
    final first = tester.getRect(tiles.at(0));
    final second = tester.getRect(tiles.at(1));
    final gap = (first.left - second.right).abs();
    // 8 dp gutter + the 8 % inset left inside the cell. The old More ratio
    // put 23 dp here at this width (the complaint), so pin under 18.
    expect(gap, lessThanOrEqualTo(18), reason: 'gap was $gap');
    expect(gap, lessThan(8 + 0.2 * (first.width / 0.92 - 10)),
        reason: 'a shortcut must never keep the airy More-page gap');
  });

  testWidgets('B04: no visible x badge, but a labelled one-tap delete exists',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpActions(tester);

    // User request 2026-11-06: the shortcut artwork carries no delete mark.
    expect(find.byIcon(Icons.close), findsNothing);

    // Audit B04: removal is reachable with ONE tap, through the picker.
    await tester.tap(find.text('افزودن'));
    await tester.pumpAndSettle();
    // The card header and the sheet title both read «دسترسی سریع».
    expect(find.text('دسترسی سریع'), findsNWidgets(2));
    // The management section is first in the sheet, so the labelled
    // one-tap delete control is in the initial viewport (no scrolling).
    expect(find.text('دسترسیهای فعلی (حذف با آیکون سطل)'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('حذف دسترسی')), findsWidgets);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(find.text('حذف دسترسی'), findsWidgets,
        reason: 'the one-tap control opens the confirmation dialog');
    semantics.dispose();
  });
}
