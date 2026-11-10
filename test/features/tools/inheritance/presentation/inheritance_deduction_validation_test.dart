import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/tools/inheritance/data/inheritance_content.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/tabs/inheritance_calculator_tab.dart';

/// The deduction fields used to be read with a bare `NumberFormat.parse`, which
/// maps unreadable text to 0 and happily accepts negatives. These tests pin
/// the wired-in parser so a negative debt or an oversized will is reported
/// instead of silently producing nonsense shares.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await InheritanceContent.load();
  });

  Future<void> openTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: InheritanceCalculatorTab()),
    ));
    await tester.pumpAndSettle();
  }

  /// Finds the money field carrying [label] (the widget passes label text
  /// straight into the InputDecoration).
  Finder fieldFor(WidgetTester tester, String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );

  Future<void> fill(WidgetTester tester, String label, String value) async {
    await tester.enterText(fieldFor(tester, label), value);
    await tester.pump();
  }

  /// `_calculate` bails out before the deduction checks when no heir is picked,
  /// so every case selects the son first. Its tile is the only `ListTile` whose
  /// title is exactly "پسر"; the stepper is the `add_circle_outline` inside it.
  Future<void> addSon(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('پسر'),
          matching: find.byType(ListTile),
        ),
        matching: find.byIcon(Icons.add_circle_outline),
      ),
    );
    await tester.pump();
  }

  /// The tab renders "محاسبه میراث" twice — once as the section-header text and
  /// once as the submit button's label — so tapping by that text is ambiguous.
  /// Anchor on the button's icon, which appears exactly once in this tab.
  ///
  /// The rejection messages appear in a `SnackBar`; `pumpAndSettle` would run
  /// past its four-second auto-dismiss timer, so pump only the entrance.
  Future<void> tapCalculate(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.calculate_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('a negative debt is rejected with a message', (tester) async {
    await openTab(tester);
    await addSon(tester);
    await fill(tester, 'دیون (بدهی‌ها)', '-500000');
    await tapCalculate(tester);

    expect(find.textContaining('نمی‌تواند منفی باشد'), findsOneWidget);
  });

  testWidgets('debt and funeral together cannot exceed the estate',
      (tester) async {
    await openTab(tester);
    await addSon(tester);
    // Estate defaults to 1,000,000,000.
    await fill(tester, 'دیون (بدهی‌ها)', '900000000');
    await fill(tester, 'هزینه‌های تجهیز و تکفین', '900000000');
    await tapCalculate(tester);

    expect(
      find.textContaining('نمی‌تواند از مبلغ کل ترکه بیشتر باشد'),
      findsOneWidget,
    );
  });

  testWidgets('a will larger than the estate is rejected', (tester) async {
    await openTab(tester);
    await addSon(tester);
    await fill(tester, 'وصیت اول (حداکثر ثلث)', '2000000000');
    await tapCalculate(tester);

    expect(
      find.textContaining('مبلغ وصیت نمی‌تواند از مبلغ کل ترکه بیشتر باشد'),
      findsOneWidget,
    );
  });

  testWidgets('a valid estate still calculates', (tester) async {
    await openTab(tester);
    await addSon(tester);
    await fill(tester, 'دیون (بدهی‌ها)', '500000');
    await tapCalculate(tester);

    // The validation messages must not appear for a well-formed input.
    expect(find.textContaining('نمی‌تواند منفی باشد'), findsNothing);
    expect(
      find.textContaining('نمی‌تواند از مبلغ کل ترکه بیشتر باشد'),
      findsNothing,
    );
  });
}