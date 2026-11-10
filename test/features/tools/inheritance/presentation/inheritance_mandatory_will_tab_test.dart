import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/tools/inheritance/data/inheritance_content.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/tabs/inheritance_mandatory_will_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await InheritanceContent.load();
  });

  testWidgets('وصیت واجبه: کشور امارات در انتخابگر قانون موجود است',
      (tester) async {
    tester.view.physicalSize = const Size(900, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: InheritanceMandatoryWillTab()),
    ));
    await tester.pump();

    // Open the country dropdown.
    await tester.tap(find.text('کشور (قانون)'));
    await tester.pumpAndSettle();

    // The UAE law (added from the site's 8-country list) is selectable.
    expect(find.text('امارات'), findsOneWidget,
        reason: 'قانون امارات باید در فهرست وصیت واجبه باشد');
  });
}
