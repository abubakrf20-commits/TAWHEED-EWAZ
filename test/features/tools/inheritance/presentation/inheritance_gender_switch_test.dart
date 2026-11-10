import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/tools/inheritance/data/inheritance_content.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/tabs/inheritance_calculator_tab.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/tabs/inheritance_comparison_tab.dart';

/// Taps the + button inside the heir tile that has [label] as its title.
Future<void> addHeir(WidgetTester tester, String label) async {
  final tile = find.widgetWithText(ListTile, label);
  await tester.tap(
    find.descendant(
      of: tile,
      matching: find.byIcon(Icons.add_circle_outline),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await InheritanceContent.load();
  });

  testWidgets(
      'تعویض جنسیت بعد از حل: شوهر پاک و نتیجه بازمحاسبه میشود (تب محاسبه)',
      (tester) async {
    tester.view.physicalSize = const Size(900, 30000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: InheritanceCalculatorTab()),
    ));
    await tester.pump();

    // متوفی زن → شوهر مجاز است.
    await tester.tap(find.text('متوفی زن'));
    await tester.pump();

    await addHeir(tester, 'شوهر');
    await addHeir(tester, 'دختر');

    await tester.tap(find.widgetWithText(FilledButton, 'محاسبه میراث'));
    await tester.pumpAndSettle();

    expect(find.text('ترکه قابل تقسیم'), findsOneWidget);

    // متوفی مرد → «شوهر» باید صفر شود، بدون خطا بازمحاسبه شود و «همسر» برگردد.
    await tester.tap(find.text('متوفی مرد'));
    await tester.pumpAndSettle();

    expect(
      find.text('متوفی مرد است — گزینه "شوهر" برای متوفی مرد مجاز نیست.'),
      findsNothing,
      reason: 'تعویض جنسیت نباید خطای اسنک‌بارِ شوهر بدهد.',
    );
    // تایل شوهر برای متوفی مرد مخفی است و سهم قدیمی شوهر نیز نباید بماند.
    expect(find.text('شوهر'), findsNothing);
    // نتیجه بدون خطا بازمحاسبه شده و روی صفحه است.
    expect(find.text('ترکه قابل تقسیم'), findsOneWidget);
    // تایل همسر (معتبر برای متوفی مرد) دوباره قابل انتخاب است.
    expect(find.widgetWithText(ListTile, 'همسر'), findsOneWidget);
  });

  testWidgets('تعویض جنسیت بعد از حل در تب مقایسه هم بازمحاسبه میکند',
      (tester) async {
    tester.view.physicalSize = const Size(900, 30000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: InheritanceComparisonTab()),
    ));
    await tester.pump();

    // متوفی مرد (پیش‌فرض) → همسر مجاز است.
    await addHeir(tester, 'همسر');
    await addHeir(tester, 'دختر');

    await tester.tap(find.widgetWithText(FilledButton, 'مقایسه مذاهب'));
    await tester.pumpAndSettle();

    expect(find.text('جمهور'), findsWidgets);

    // متوفی زن → همسر باید صفر شود، شوهر ظاهر گردد و نتیجه بازمحاسبه شود.
    await tester.tap(find.text('متوفی زن'));
    await tester.pumpAndSettle();

    expect(find.text('جمهور'), findsWidgets,
        reason: 'نتیجه باید بدون خطا بازمحاسبه شده باشد.');
    expect(find.widgetWithText(ListTile, 'شوهر'), findsOneWidget);
    expect(find.text('همسر'), findsNothing);

    // برگشت به متوفی مرد → شوهر مخفی و همسر دوباره ظاهر شود.
    await tester.tap(find.text('متوفی مرد'));
    await tester.pumpAndSettle();

    expect(find.text('شوهر'), findsNothing);
    expect(find.widgetWithText(ListTile, 'همسر'), findsOneWidget);
    expect(find.text('جمهور'), findsWidgets);
  });
}
