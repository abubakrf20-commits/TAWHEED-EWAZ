import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sizes the surface to the page's own height, so the golden captures the whole
/// page and nothing but the page.
///
/// The intuitive measurement — `ScrollPosition.maxScrollExtent +
/// viewportDimension` — is only an *estimate* while rows below the fold are
/// unbuilt, and it is exact only while every row has the same height. Now that
/// rows wrap (a `maxLines` above 1, so a setting is never cut short), that
/// estimate over-shot the settings page by ~1100px at 412dp — a baseline padded
/// with a screen of empty space — and under-shot it by ~370px at 320dp, clipping
/// the page's bottom out of the picture. Both make the baseline lie about the
/// page.
///
/// So lay the page out first: a viewport far taller than any page puts every row
/// on screen, and walking the list's sliver children then gives the exact
/// content extent.
///
/// Call it after the page has been pumped at the final width (and text scale),
/// and before `expectLater(..., matchesGoldenFile(...))`.
Future<void> fitPageHeight(WidgetTester tester, double width) async {
  final scrollable = find.byType(Scrollable).first;

  // Give the viewport far more room than the page can need: with every child
  // laid out, the list reports its real extent instead of an extrapolation.
  await tester.binding.setSurfaceSize(Size(width, 24000));
  await tester.pumpAndSettle();

  final sliver = tester.renderObject<RenderSliverMultiBoxAdaptor>(
    find.descendant(of: scrollable, matching: find.byType(SliverList)).first,
  );
  var extent = 0.0;
  for (var child = sliver.firstChild;
      child != null;
      child = sliver.childAfter(child)) {
    final data = child.parentData! as SliverMultiBoxAdaptorParentData;
    final end = (data.layoutOffset ?? 0) + child.size.height;
    if (end > extent) extent = end;
  }

  // The kToolbarHeight reserve is what the existing baselines carried, so a page
  // whose top chrome is not an AppBar of exactly that height still cannot clip,
  // and the list's own trailing padding stays inside the picture.
  await tester.binding.setSurfaceSize(Size(width, extent + kToolbarHeight));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);

  // The picture must fit the page. A page that still scrolls here means the
  // measurement above was wrong and the baseline would cut its bottom off.
  final pos = tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position;
  expect(
    pos.maxScrollExtent,
    lessThanOrEqualTo(kToolbarHeight),
    reason: 'the golden viewport must show the whole page, '
        '${pos.maxScrollExtent.toStringAsFixed(0)}px are still below the fold',
  );
}
