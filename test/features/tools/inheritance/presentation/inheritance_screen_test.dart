import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/features/tools/inheritance/data/inheritance_content.dart';
import 'package:tawheeed/shared/models/app_currency.dart';
import 'package:tawheeed/shared/services/currency_store.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/screens/inheritance_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await InheritanceContent.load();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: InheritanceScreen()));
    await tester.pump();
  }

  testWidgets('صفحهٔ میراث هر ۱۰ تب را نمایش می‌دهد', (tester) async {
    await pumpScreen(tester);
    for (final label in [
      'محاسبه',
      'ماشین حساب کسرها',
      'ماشین حساب سهام',
      'مقایسه',
      'مبانی',
      'ورثه',
      'قواعد',
      'حالات خاص',
      'وصیت واجبه',
      'آزمون',
    ]) {
      expect(find.text(label), findsWidgets, reason: 'تب «$label»');
    }
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.byType(TabBarView), findsOneWidget);
  });

  testWidgets('ترتیب تب‌ها: ماشین‌های حساب بلافاصله بعد از محاسبه',
      (tester) async {
    await pumpScreen(tester);
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    final labels =
        tabBar.tabs.map((t) => (t is Tab ? t.text : null) ?? '').toList();
    expect(labels.take(4),
        ['محاسبه', 'ماشین حساب کسرها', 'ماشین حساب سهام', 'حالات خاص']);
  });

  testWidgets('تب محاسبه محتوایش را بدون spinner نشان می‌دهد', (tester) async {
    await pumpScreen(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('انتخاب ورثه'), findsWidgets);
    expect(find.text('محاسبه میراث'), findsWidgets);
  });

  testWidgets('سایر تب‌ها بدون خطا و بدون spinner باز می‌شوند', (tester) async {
    await pumpScreen(tester);
    for (final label in [
      'ماشین حساب کسرها',
      'ماشین حساب سهام',
      'مقایسه',
      'مبانی',
      'ورثه',
      'قواعد',
      'حالات خاص',
      'وصیت واجبه',
      'آزمون'
    ]) {
      final tab = find.text(label).last;
      await tester.ensureVisible(tab);
      await tester.pumpAndSettle();
      await tester.tap(tab, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: 'تب «$label» روی spinner گیر نکرده');
    }
  });

  testWidgets('انتخاب واحد دلار برچسب‌ها را عوض و عدد پیش‌فرض را پاک می‌کند',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await CurrencyStore.calculators.save(AppCurrency.toman);
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'مبلغ کل ترکه (تومان)'),
        findsOneWidget);

    // The unit is chosen only in Settings; this page follows the shared store
    // and offers no picker of its own.
    expect(find.text('واحد پول'), findsNothing);
    await CurrencyStore.calculators.save(AppCurrency.dollar);
    await tester.pumpAndSettle();

    final field =
        find.widgetWithText(TextField, 'مبلغ کل ترکه (دلار)');
    expect(field, findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text, isEmpty,
        reason: 'عدد پیش‌فرض تومانی نباید به‌عنوان یک میلیارد دلار بماند');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_currency_code'), 'USD',
        reason: 'واحد میراث همان واحد مشترک ابزارهای مالی است');
  });
}
