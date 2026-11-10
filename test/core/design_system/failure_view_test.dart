import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/design_system/components/components.dart';

/// The contract [FailureView] now owns on behalf of seventeen screens.
///
/// Each of those screens hand-built an error icon, a sentence and a retry, and
/// by the time this was written they disagreed on the layout, the icon size, the
/// title weight, the title colour, the detail colour, the button type and the
/// label — and only some of them could be found by key at all, which is why the
/// drift survived: an unkeyed panel can only be tested by matching Persian
/// prose, so it was not tested.
void main() {
  Widget wrap(Widget child) => MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: child),
        ),
      );

  testWidgets('id is the test handle: the panel is findable without prose',
      (tester) async {
    await tester.pumpWidget(wrap(
      FailureView(id: 'tasks_load', title: 'کارها باز نشدند', onRetry: () {}),
    ));

    expect(find.byKey(const ValueKey('failure_tasks_load')), findsOneWidget);
    expect(find.text('کارها باز نشدند'), findsOneWidget);
  });

  testWidgets('the retry label is fixed app-wide, never a parameter',
      (tester) async {
    await tester.pumpWidget(wrap(
      FailureView(id: 'a', title: 'باز نشد', onRetry: () {}),
    ));

    // Locked on purpose: the repo had three labels for this one action
    // («تلاش دوباره»، «تلاش مجدد»، «دوباره تلاش کنید»). Changing this constant is
    // an app-wide decision, not a per-screen one.
    expect(FailureView.retryLabel, 'تلاش دوباره');
    expect(find.text('تلاش دوباره'), findsOneWidget);
  });

  testWidgets('the retry button calls back exactly once per tap',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrap(
      FailureView(id: 'a', title: 'باز نشد', onRetry: () => taps++),
    ));

    await tester.tap(find.text('تلاش دوباره'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('a panel with nothing to retry still names the failure',
      (tester) async {
    await tester.pumpWidget(wrap(
      const FailureView(
        id: 'download',
        title: 'دانلود کامل نشد',
        detail: 'فایل نیمه‌کاره پاک نشده است.',
      ),
    ));

    expect(find.byKey(const ValueKey('failure_download')), findsOneWidget);
    expect(find.text('دانلود کامل نشد'), findsOneWidget);
    expect(find.text('فایل نیمه‌کاره پاک نشده است.'), findsOneWidget);
    // No retry offered — and no dead button pretending there is one.
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('card layout is tinted and start-aligned', (tester) async {
    await tester.pumpWidget(wrap(
      FailureView(id: 'a', title: 'باز نشد', onRetry: () {}),
    ));

    final box = tester.widget<Container>(
      find.byKey(const ValueKey('failure_a')),
    );
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.border, isNotNull);
    expect(decoration.borderRadius, BorderRadius.circular(16));
  });

  testWidgets('page layout is centred and scrollable', (tester) async {
    await tester.pumpWidget(wrap(
      FailureView(
        id: 'p',
        title: 'متأسفانه مشکلی پیش آمد. لطفاً دوباره تلاش کنید.',
        detail: 'این خطا رخ داده است؛ کار شما از دست نرفته.',
        onRetry: () {},
        layout: FailureLayout.page,
      ),
    ));

    expect(find.byKey(const ValueKey('failure_p')), findsOneWidget);
    // An error screen that itself overflows is the one screen the reader
    // cannot escape, so the page layout must be able to scroll.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('failure_p')),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('failure_p')),
        matching: find.byType(Center),
      ),
      findsWidgets,
    );
  });

  testWidgets('inline layout is one row with a text-button retry',
      (tester) async {
    await tester.pumpWidget(wrap(
      FailureView(
        id: 'more',
        title: 'بارگذاری بقیه ناموفق بود',
        onRetry: () {},
        layout: FailureLayout.inline,
      ),
    ));

    expect(find.byKey(const ValueKey('failure_more')), findsOneWidget);
    expect(find.byType(Row), findsWidgets);
    expect(find.widgetWithText(TextButton, 'تلاش دوباره'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('the panel is announced as a live region', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(wrap(
      FailureView(id: 'a', title: 'باز نشد', onRetry: () {}),
    ));

    // A failure that appears silently is only visible to a sighted reader.
    expect(
      tester.getSemantics(find.byKey(const ValueKey('failure_a'))),
      isSemantics(isLiveRegion: true),
    );

    // Must be disposed inside the test body, not in a tear-down: the binding
    // checks for leaked handles before tear-downs run.
    handle.dispose();
  });

  test('an anonymous panel is a construction error, not a style choice', () {
    expect(
      () => FailureView(id: '', title: 'باز نشد'),
      throwsAssertionError,
      reason: 'without an id the panel cannot be asserted on',
    );
    expect(
      () => FailureView(id: 'a', title: ''),
      throwsAssertionError,
      reason: '«خطا» is not a title; the reader needs to know what failed',
    );
  });

  testWidgets('ink can be overridden for surfaces that are not the ambient one',
      (tester) async {
    // The three mushaf surfaces paint paper with their own palette and no error
    // hue. Without this hook they could not use the shared panel, and the one
    // place the drift started would have kept its own copy.
    await tester.pumpWidget(wrap(
      FailureView(
        id: 'paper',
        title: 'خواندن نشان‌ها ممکن نشد',
        onRetry: () {},
        layout: FailureLayout.page,
        ink: const FailureInk(
          title: Color(0xFF102030),
          detail: Color(0xFF405060),
          danger: Color(0xFF708090),
        ),
      ),
    ));

    final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
    expect(icon.color, const Color(0xFF708090));
    final title = tester.widget<Text>(find.text('خواندن نشان‌ها ممکن نشد'));
    expect(title.style?.color, const Color(0xFF102030));
  });

  testWidgets('a retry in flight replaces the button instead of leaving it live',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrap(
      FailureView(
        id: 'a',
        title: 'باز نشد',
        onRetry: () => taps++,
        retrying: true,
        layout: FailureLayout.inline,
      ),
    ));

    // A live button here lets the reader queue requests against a read that has
    // not finished failing. Two of the three screens that had solved this on
    // their own left the button enabled.
    expect(find.text('تلاش دوباره'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(taps, 0);
  });

  testWidgets('the glyph can name the kind of failure, not just that it failed',
      (tester) async {
    // «جست‌وجو انجام نشد» because the server never answered is a different
    // event from «کتاب باز نشد» because a local read threw, and the glyph says
    // which without a word. The sizes it used to be confused with (20/44/48
    // across three screens) stay fixed per layout.
    await tester.pumpWidget(wrap(
      FailureView(
        id: 'search',
        title: 'جست‌وجو انجام نشد',
        onRetry: () {},
        layout: FailureLayout.page,
        icon: Icons.cloud_off,
      ),
    ));

    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNothing);
    expect(tester.widget<Icon>(find.byIcon(Icons.cloud_off)).size, 44);
  });
}
