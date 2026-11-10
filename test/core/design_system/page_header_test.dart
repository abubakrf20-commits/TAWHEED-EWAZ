import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';

/// `PageHeader` replaced the 56dp [AppBar] every top-level tab used to wear
/// (user request, 2026-10-14). These are the geometry and typography
/// invariants behind that decision — the header is 40dp tall, the title rides
/// the shared type scale **centred on the page** (user request, 2026-10-23),
/// and the actions sit at the END edge as compact 40dp tap targets.
Widget _app(Widget child, {bool rtl = true, double width = 412}) => MaterialApp(
      theme: AppTheme.lightTheme(),
      home: Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: Scaffold(
            body: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );

void main() {
  testWidgets('is exactly PageHeader.height tall', (tester) async {
    await tester.pumpWidget(_app(const PageHeader(title: 'خانه')));
    expect(PageHeader.height, 40);
    expect(tester.getSize(find.byType(PageHeader)).height, PageHeader.height);
  });

  testWidgets('RTL: title is centred, action at the end edge', (tester) async {
    await tester.pumpWidget(_app(PageHeader(
      title: 'خانه',
      actions: [
        PageAction(icon: Icons.search, tooltip: 'جستجو', onPressed: () {}),
      ],
    )));
    final header = tester.getRect(find.byType(PageHeader));
    final title = tester.getRect(find.text('خانه'));
    final action = tester.getRect(find.byType(PageAction));

    // The title sits on the page centre line, not next to its action…
    expect(title.center.dx, closeTo(header.center.dx, 0.5));
    // RTL: end is left.
    expect(action.left, closeTo(header.left + DsSpacing.page, 0.5));
    // …and stays clear of it (its own half of the mirrored gutters).
    expect(title.left, greaterThan(action.right));
  });

  testWidgets('LTR centres the title too, action at its end edge',
      (tester) async {
    await tester.pumpWidget(_app(
      PageHeader(
        title: 'خانه',
        actions: [
          PageAction(icon: Icons.search, tooltip: 'جستجو', onPressed: () {}),
        ],
      ),
      rtl: false,
    ));
    final header = tester.getRect(find.byType(PageHeader));
    final title = tester.getRect(find.text('خانه'));
    final action = tester.getRect(find.byType(PageAction));

    expect(title.center.dx, closeTo(header.center.dx, 0.5));
    expect(action.right, closeTo(header.right - DsSpacing.page, 0.5));
  });

  testWidgets('without actions the title is centred on the full row',
      (tester) async {
    await tester.pumpWidget(_app(const PageHeader(title: 'بیشتر')));
    final header = tester.getRect(find.byType(PageHeader));
    final title = tester.getRect(find.text('بیشتر'));
    expect(title.center.dx, closeTo(header.center.dx, 0.5));
  });

  testWidgets('two actions keep the title on the page centre line',
      (tester) async {
    await tester.pumpWidget(_app(PageHeader(
      title: 'خانه',
      actions: [
        PageAction(icon: Icons.search, tooltip: 'جستجو', onPressed: () {}),
        PageAction(icon: Icons.settings, tooltip: 'تنظیمات', onPressed: () {}),
      ],
    )));
    final header = tester.getRect(find.byType(PageHeader));
    final title = tester.getRect(find.text('خانه'));
    expect(title.center.dx, closeTo(header.center.dx, 0.5));
  });

  testWidgets('the title rides the shared type scale, w600', (tester) async {
    await tester.pumpWidget(_app(const PageHeader(title: 'خانه')));
    final ctx = tester.element(find.byType(PageHeader));
    final text = tester.widget<Text>(find.text('خانه'));
    final size = text.style!.fontSize!;
    // Never a hand-typed literal: it is a real step of the shared scale and is
    // exactly what scaledFontSize(14) resolves to.
    expect(AppTheme.typeScale, contains(size));
    expect(size, AppTheme.scaledFontSize(ctx, 14));
    expect(text.style!.fontWeight, FontWeight.w600);
    // The tab title must be quieter than the 16sp+ AppBar title it replaced.
    expect(size, lessThanOrEqualTo(14));
  });

  testWidgets('the action keeps a 40dp square tap target', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(PageHeader(
      title: 'خانه',
      actions: [
        PageAction(
            icon: Icons.search, tooltip: 'جستجو', onPressed: () => taps++),
      ],
    )));
    final size = tester.getSize(find.byType(PageAction));
    expect(size, const Size(PageHeader.height, PageHeader.height));
    expect(size.height, lessThanOrEqualTo(PageHeader.height));
    await tester.tap(find.byType(PageAction));
    expect(taps, 1);
  });

  testWidgets('a long title scales down instead of overflowing at 320/1.3',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            body: SizedBox(
              width: 320,
              child: PageHeader(
                title: 'ارزیابی و گزارش',
                actions: [
                  PageAction(
                      icon: Icons.settings, tooltip: 'تنظیمات', onPressed: () {}),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    final header = tester.getRect(find.byType(PageHeader));
    final title = tester.getRect(find.text('ارزیابی و گزارش'));
    final action = tester.getRect(find.byType(PageAction));
    expect(header.height, PageHeader.height);
    // Still one line, still centred between the mirrored action gutters.
    expect(title.center.dx, closeTo(header.center.dx, 0.5));
    expect(title.left, greaterThanOrEqualTo(action.right - 0.5));
    expect(title.right, lessThanOrEqualTo(header.right + 0.5));
  });
}
