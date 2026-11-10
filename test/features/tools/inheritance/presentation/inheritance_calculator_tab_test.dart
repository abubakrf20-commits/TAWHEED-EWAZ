import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/tools/inheritance/data/inheritance_content.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/tabs/inheritance_calculator_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await InheritanceContent.load();
  });

  testWidgets('گزینه‌های جدید وارث در تب محاسبه نمایش داده می‌شوند',
      (tester) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: InheritanceCalculatorTab()),
    ));
    await tester.pump();

    const labels = [
      'پسرِ خواهر',
      'دخترِ برادرِ پدری و مادری',
      'دخترِ برادرِ پدری',
      'دایی (برادرِ مادر)',
      'خاله (خواهرِ مادر)',
      'عمه (خواهرِ پدر)',
      'دخترِ عمو',
    ];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });
}
