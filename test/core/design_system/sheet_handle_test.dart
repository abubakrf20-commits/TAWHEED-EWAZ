import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/design_system/components/sheet_handle.dart';

/// One grab handle for every sheet: 38×4, fully rounded, accent at 28 %.
/// Before this component each sheet drew its own (36/38/40, radius 2 or 99,
/// three colour sources), so two sheets opened back to back disagreed.
void main() {
  testWidgets('the handle is one geometry and one ink', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: SheetHandle()))),
    );

    expect(tester.getSize(find.byType(SheetHandle)), const Size(38, 4));

    final box = tester.widget<Container>(
      find.descendant(
        of: find.byType(SheetHandle),
        matching: find.byType(Container),
      ),
    );
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(2));
    expect(decoration.color!.a, closeTo(0.28, 0.01),
        reason: 'the bar is a hint, never a divider');
  });

  testWidgets('a caller may only widen the bar, not restyle it',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: SheetHandle(width: 44))),
      ),
    );
    expect(tester.getSize(find.byType(SheetHandle)), const Size(44, 4));
  });
}
