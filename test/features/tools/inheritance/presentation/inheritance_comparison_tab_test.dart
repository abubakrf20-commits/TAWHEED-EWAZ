import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/tools/inheritance/data/inheritance_content.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/tabs/inheritance_comparison_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await InheritanceContent.load();
  });

  Future<void> pumpTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: InheritanceComparisonTab()),
    ));
    await tester.pump();
  }

  testWidgets('گزینه‌های وارث جدید در تب مقایسه نمایش داده می‌شوند',
      (tester) async {
    await pumpTab(tester);
    for (final label in [
      'پسرِ خواهر',
      'دخترِ برادرِ پدری و مادری',
      'دخترِ برادرِ پدری',
      'دایی (برادرِ مادر)',
      'خاله (خواهرِ مادر)',
      'عمه (خواهرِ پدر)',
      'دخترِ عمو',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('ورودی مصاريف، دیون و وصیت در تب مقایسه باز می‌شود',
      (tester) async {
    await pumpTab(tester);
    await tester.tap(find.text('کسر هزینه‌های کفن، دیون و وصیت‌ها'));
    await tester.pump();
    expect(find.text('هزینه‌های تجهیز و تکفین'), findsOneWidget);
    expect(find.text('دیون (بدهی‌ها)'), findsOneWidget);
    expect(find.text('وصیت اول (حداکثر ثلث)'), findsOneWidget);
    expect(find.text('وصیت دوم'), findsOneWidget);
    expect(find.text('وصیت سوم'), findsOneWidget);
    expect(find.text('آیا وراث با پرداخت وصیت بیش از یک‌سوم موافقت کرده‌اند؟'),
        findsOneWidget);
  });
}
