// Widget tests: the mushaf sheet frame must stay dismissable by a downward
// drag.
//
// The modal sheet only closes on a downward drag when no deeper scrollable
// wins the gesture arena first. [MushafSheetScrollable] hands its list
// `NeverScrollableScrollPhysics` while the content fits, so the drag reaches
// the sheet; the moment the list genuinely overflows it scrolls again.
//
// This mirrors the real sheets exactly: a header that is *not* scrollable
// above a scrollable list body, so the drag in the first test lands on a row,
// not on the header.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/quran/mushaf/mushaf_color_sheets.dart';

Widget _sheetHost({required int itemCount}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => SizedBox(
                height: 400,
                child: Column(
                  children: [
                    // A non-scrollable header, like the real sheets have.
                    const SizedBox(height: 40),
                    Expanded(
                      child: MushafSheetScrollable(
                        builder: (context, physics) => ListView.builder(
                          physics: physics,
                          itemCount: itemCount,
                          itemBuilder: (context, i) =>
                              SizedBox(height: 60, child: Text('row $i')),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester, int itemCount) async {
  await tester.pumpWidget(_sheetHost(itemCount: itemCount));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a short list adds no drag recogniser, so a downward drag closes',
      (tester) async {
    await _openSheet(tester, 2);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('row 1'), findsOneWidget);

    // The drag starts on a list ROW (the scrollable), not on the header.
    await tester.drag(find.text('row 1'), const Offset(0, 500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(BottomSheet), findsNothing,
        reason: 'a downward drag over a fitting list must dismiss the sheet');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long list still scrolls instead of dismissing', (tester) async {
    await _openSheet(tester, 20);
    expect(find.text('row 19'), findsNothing);

    await tester.drag(find.text('row 1'), const Offset(0, -1200));
    await tester.pump();

    expect(find.text('row 19'), findsOneWidget,
        reason: 'an overflowing list must claim the drag and scroll');
    expect(find.byType(BottomSheet), findsOneWidget,
        reason: 'an upward drag must not dismiss the sheet');
    expect(tester.takeException(), isNull);
  });
}
