import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tawheeed/features/tools/zakat/presentation/screens/zakat_screen.dart';
import 'package:tawheeed/shared/models/app_currency.dart';
import 'package:tawheeed/shared/services/currency_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CurrencyStore.calculators.notifier.value = AppCurrency.toman;
  });

  tearDown(() {
    CurrencyStore.calculators.notifier.value = AppCurrency.toman;
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 12000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: ZakatScreen()));
    await tester.pump();
  }

  testWidgets('صفحه زکات هر 7 تب را نمایش می‌دهد', (tester) async {
    await pumpScreen(tester);
    for (final label in [
      'محاسبه',
      'آشنایی',
      'شرایط و اموال',
      'نصاب',
      'مصارف',
      'احکام معاصر',
      'پرسش‌ها',
    ]) {
      expect(find.text(label), findsWidgets, reason: 'تب «$label»');
    }
  });

  testWidgets('زکات شتر 145 رأس = 2 حقه (سه‌ساله)', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(find.widgetWithText(TextField, 'شتر'), '145');
    await tester.tap(find.text('حول (یک سال قمری) کامل شده است'));
    await tester.tap(find.text('دام سائمه (چرانیده در چراگاه) است'));
    await tester.pump();
    await tester.tap(find.text('محاسبه زکات'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 بنت لبون + 2 حِقّه'), findsWidgets);
    expect(find.textContaining('2 شتر ماده سه ساله'), findsNothing);
  });

  testWidgets('زکات کشاورزی به کیلوگرم نمایش داده می‌شود نه تومان',
      (tester) async {
    await pumpScreen(tester);
    await tester.enterText(
        find.widgetWithText(TextField, 'مقدار محصول برداشت‌شده'), '700');
    await tester.tap(find.text('محاسبه زکات'));
    await tester.pumpAndSettle();
    expect(find.textContaining('70 کیلوگرم'), findsWidgets);
  });

  testWidgets('زکات نقدی 2.5٪ از خالص دارایی بالای نصاب', (tester) async {
    await pumpScreen(tester);
    // نصاب نقدی (مذهب جمهور) = 85 گرم طلا × 25 میلیون تومان = 2٬125٬000٬000؛
    // با دارایی 3 میلیارد زکات = 75 میلیون تومان.
    await tester.enterText(
        find.widgetWithText(TextField, 'قیمت هر گرم طلای 24 عیار'), '25000000');
    await tester.enterText(
        find.widgetWithText(TextField, 'پول نقد'), '3000000000');
    await tester.tap(find.text('حول (یک سال قمری) کامل شده است'));
    await tester.pump();
    await tester.tap(find.text('محاسبه زکات'));
    await tester.pumpAndSettle();
    expect(find.textContaining('75,000,000'), findsWidgets);
  });

  testWidgets('بدون قیمت طلا/نقره هیچ زکاتی جعل نمی‌شود', (tester) async {
    await pumpScreen(tester);
    // هیچ قیمت پیش‌فرضی در برنامه نیست: دارایی بالا هم بدون قیمت روز
    // «واجب» اعلام نمی‌شود، فقط می‌گوید نصاب قابل محاسبه نیست.
    await tester.enterText(
        find.widgetWithText(TextField, 'پول نقد'), '3000000000');
    await tester.tap(find.text('حول (یک سال قمری) کامل شده است'));
    await tester.pump();
    await tester.tap(find.text('محاسبه زکات'));
    await tester.pumpAndSettle();
    expect(find.textContaining('نصاب قابل محاسبه نیست'), findsWidgets);
    expect(find.text('زکات واجب شده'), findsNothing);
  });

  testWidgets('انتخاب مبنای نقره آستانه را پایین و زکات را واجب می‌کند',
      (tester) async {
    await pumpScreen(tester);
    await tester.enterText(
        find.widgetWithText(TextField, 'قیمت هر گرم طلای 24 عیار'), '1000');
    await tester.enterText(
        find.widgetWithText(TextField, 'قیمت هر گرم نقره'), '100');
    await tester.enterText(find.widgetWithText(TextField, 'پول نقد'), '60000');
    await tester.tap(find.text('حول (یک سال قمری) کامل شده است'));
    await tester.pump();
    await tester.tap(find.text('محاسبه زکات'));
    await tester.pumpAndSettle();
    // خودکار (جمهور) → نصاب طلا 85,000؛ 60,000 زیر آن ⇒ واجب نیست.
    expect(find.text('زکات واجب نیست'), findsWidgets);

    await tester.tap(find.text('نقره'));
    await tester.pump();
    await tester.tap(find.text('محاسبه زکات'));
    await tester.pumpAndSettle();
    // نقره → نصاب 59,500؛ 60,000 بالای آن ⇒ زکات 1,500 تومان.
    expect(find.text('زکات واجب شده'), findsWidgets);
    expect(find.textContaining('1,500'), findsWidgets);
  });

  testWidgets('انتخاب واحد دلار: دریافت آنلاین می‌رود و قیمت‌های تومانی پاک می‌شوند',
      (tester) async {
    await pumpScreen(tester);
    expect(find.text('دریافت قیمت روز'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, 'قیمت هر گرم طلای 24 عیار'), '25000000');
    await tester.pump();

    // The unit is chosen only in Settings; the open page follows the shared
    // store and re-labels its own fields.
    await CurrencyStore.calculators.save(AppCurrency.dollar);
    await tester.pumpAndSettle();

    // TGJU فقط تومان می‌دهد؛ دکمه نباید بماند.
    expect(find.text('دریافت قیمت روز'), findsNothing);

    // قیمت تومانی نباید به‌عنوان دلار باقی بماند.
    final goldField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'قیمت هر گرم طلای 24 عیار'));
    expect(goldField.controller!.text, isEmpty);

    // جفت «دارایی دلاری / قیمت دلار» فقط برای واحدهای ایرانی معنا دارد.
    expect(find.widgetWithText(TextField, 'قیمت هر دلار'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_currency_code'), 'USD');
  });

  testWidgets('دلار بدون قیمت: نصاب قابل محاسبه نیست و زکاتی واجب نمی‌شود',
      (tester) async {
    await pumpScreen(tester);
    await CurrencyStore.calculators.save(AppCurrency.dollar);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'پول نقد'), '50000');
    await tester.tap(find.text('حول (یک سال قمری) کامل شده است'));
    await tester.pump();
    await tester.tap(find.text('محاسبه زکات'));
    await tester.pumpAndSettle();

    expect(find.text('زکات واجب نیست'), findsWidgets);
    expect(find.textContaining('نصاب قابل محاسبه نیست'), findsWidgets);
  });

  testWidgets('دلار با قیمت دستی: مبلغ به دلار نمایش داده می‌شود',
      (tester) async {
    await pumpScreen(tester);
    await CurrencyStore.calculators.save(AppCurrency.dollar);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'قیمت هر گرم طلای 24 عیار'), '60');
    await tester.enterText(find.widgetWithText(TextField, 'پول نقد'), '6000');
    await tester.tap(find.text('حول (یک سال قمری) کامل شده است'));
    await tester.pump();
    await tester.tap(find.text('محاسبه زکات'));
    await tester.pumpAndSettle();

    // نصاب 85 × 60 = 5,100 دلار؛ 2.5٪ از 6,000 = 150 دلار.
    expect(find.textContaining('150 دلار'), findsWidgets);
    expect(find.textContaining('2,500,000'), findsNothing,
        reason: 'قیمت پیش‌فرض تومانی نباید در واحد دلار ظاهر شود');
  });

  testWidgets('مذهب و مبنای نصاب پس از بازسازی صفحه می‌مانند', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('حنفی'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('نقره'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('zakat_madhab'), 'hanafi');
    expect(prefs.getString('zakat_nisab_basis'), 'silver');

    // صفحه از نو ساخته می‌شود — مثل بازگشت به صفحه یا اجرای دوبارهٔ اپ.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'قیمت هر گرم طلای 24 عیار'), '1000');
    await tester.enterText(
        find.widgetWithText(TextField, 'قیمت هر گرم نقره'), '100');
    await tester.enterText(find.widgetWithText(TextField, 'پول نقد'), '60000');
    await tester.tap(find.text('حول (یک سال قمری) کامل شده است'));
    await tester.pump();
    await tester.tap(find.text('محاسبه زکات'));
    await tester.pumpAndSettle();

    // مبنای ذخیره‌شده نقره است ⇒ نصاب 59,500؛ 60,000 بالای آن ⇒ واجب.
    expect(find.text('زکات واجب شده'), findsWidgets);
  });

  testWidgets('تغییر واحد از صفحهٔ تنظیمات، فیلدهای همین صفحه را هم عوض می‌کند',
      (tester) async {
    await pumpScreen(tester);
    await tester.pumpAndSettle();
    // The page itself offers no unit picker: one setting, in Settings.
    expect(find.text('واحد پول'), findsNothing);
    // تومان است، پس جفتِ «دارایی/قیمت دلار» دیده می‌شود.
    expect(find.widgetWithText(TextField, 'قیمت هر دلار'), findsOneWidget);

    // همان نوشتنی که ردیف «واحد حساب‌گرها» در تنظیمات انجام می‌دهد؛ صفحه در
    // تب دیگری زنده است و باید از همین کانال باخبر شود.
    CurrencyStore.calculators.notifier.value = AppCurrency.dollar;
    await tester.pumpAndSettle();

    // فیلدهای مبلغ هم واحد تازه را نشان می‌دهند: جفتِ دلاری فقط برای
    // واحدهای ایرانی معنا دارد و کنار می‌رود.
    expect(find.widgetWithText(TextField, 'پول نقد'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'قیمت هر دلار'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
