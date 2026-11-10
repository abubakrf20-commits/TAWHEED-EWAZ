import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/features/fasting/presentation/tabs/fitr_zakat_tab.dart';
import 'package:tawheeed/shared/models/app_currency.dart';
import 'package:tawheeed/shared/services/currency_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Finder membersField() => find.widgetWithText(TextField, 'مثلاً 4');

  Future<void> pumpTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FitrZakatTab()),
    ));
    await tester.pump();
  }

  testWidgets('زکات فطر جنسی = تعداد افراد × صاع', (tester) async {
    await pumpTab(tester);
    await tester.enterText(membersField(), '4');
    await tester.tap(find.text('3'));
    await tester.pump();
    await tester.tap(find.text('محاسبه زکات فطر'));
    await tester.pump();
    expect(find.textContaining('12 کیلوگرم'), findsWidgets);
  });

  testWidgets('زکات فطر نقدی = تعداد افراد × صاع × قیمت هر کیلوگرم',
      (tester) async {
    await pumpTab(tester);
    await tester.enterText(membersField(), '4');
    await tester.tap(find.text('3'));
    await tester.pump();
    await tester.tap(find.text('نقدی (تومان)'));
    await tester.pump();
    // قیمت پیش‌فرض برنج: 90,000 تومان → 4 × 3 × 90,000 = 1,080,000
    await tester.tap(find.text('برنج'));
    await tester.pump();
    await tester.tap(find.text('محاسبه زکات فطر'));
    await tester.pump();
    expect(find.textContaining('1,080,000'), findsWidgets);
  });

  testWidgets('تغییر واحد پول: قیمت تومانی دور ریخته و مبلغ به دلار حساب می‌شود',
      (tester) async {
    await pumpTab(tester);
    await tester.tap(find.text('برنج'));
    await tester.pump();

    // The unit is chosen only in Settings; the tab follows the shared store.
    await CurrencyStore.calculators.save(AppCurrency.dollar);
    await tester.pumpAndSettle();

    // قیمت واحد قبلی نباید به‌عنوان دلار بماند.
    final priceField =
        tester.widget<TextField>(find.widgetWithText(TextField, 'قیمت روز'));
    expect(priceField.controller!.text, isEmpty);

    await tester.enterText(membersField(), '4');
    await tester.tap(find.text('3'));
    await tester.pump();
    await tester.enterText(
        find.widgetWithText(TextField, 'قیمت روز'), '12');
    await tester.tap(find.text('نقدی (دلار)'));
    await tester.pump();
    await tester.tap(find.text('محاسبه زکات فطر'));
    await tester.pump();

    // 4 × 3 × 12 = 144 دلار
    expect(find.textContaining('144 دلار'), findsWidgets);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('fitr_zakat_price_برنج_USD'), 12,
        reason: 'قیمت دلاری باید در کلید واحد خودش ذخیره شود');
    expect(prefs.getDouble('fitr_zakat_price_برنج'), isNull,
        reason: 'کلید تومان نباید با عدد دلاری آلوده شود');
  });

  testWidgets('صاعِ یک قوت غالب به قوت غالب بعدی قرض داده نمی‌شود',
      (tester) async {
    // گندم با صاعِ ۲.۵ ذخیره شده است؛ برنج هرگز تنظیم نشده.
    SharedPreferences.setMockInitialValues({'fitr_zakat_sa_گندم': 2.5});
    await pumpTab(tester);

    await tester.tap(find.text('محاسبه زکات فطر'));
    await tester.pump();
    expect(find.textContaining('2.50 کیلوگرم'), findsWidgets);

    // پیش‌تر، صاعِ گندم به برنج سرایت می‌کرد و صفحه وزنی را نشان می‌داد که
    // به قوت غالب قبلی تعلق داشت — پاسخی غلط که عمدی به نظر می‌رسید.
    await tester.tap(find.text('برنج'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('محاسبه زکات فطر'));
    await tester.pump();

    expect(find.textContaining('3.00 کیلوگرم'), findsWidgets);
    expect(find.textContaining('2.50 کیلوگرم'), findsNothing);
  });
}
