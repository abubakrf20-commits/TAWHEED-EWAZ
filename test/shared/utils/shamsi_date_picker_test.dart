import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/shared/utils/shamsi_date_picker.dart';

void main() {
  Future<void> openPicker(
    WidgetTester tester,
    List<DateTime?> holder, {
    DateTime? initialDate,
    DateTime? earliestDate,
    DateTime? latestDate,
    String? title,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                holder.add(await ShamsiDatePicker.show(
                  context,
                  initialDate: initialDate,
                  earliestDate: earliestDate,
                  latestDate: latestDate,
                  title: title,
                ));
              },
              child: const Text('باز'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('باز'));
    await tester.pumpAndSettle();
  }

  /// The dialog's «تأیید» button — disabled (null `onPressed`) whenever the
  /// selection falls outside `[earliestDate, latestDate]`.
  TextButton confirm(WidgetTester tester) =>
      tester.widget<TextButton>(find.widgetWithText(TextButton, 'تأیید'));

  /// Whether the day cell for [dayNum] can be tapped at all.
  bool dayIsSelectable(WidgetTester tester, String dayNum) => tester
      .widget<GestureDetector>(find
          .ancestor(
              of: find.text(dayNum),
              matching: find.byType(GestureDetector))
          .last)
      .onTap !=
      null;

  testWidgets('پیکر انتخابگر سریع سال/ماه و دکمه امروز را دارد',
      (tester) async {
    await openPicker(tester, []);

    // دو کشویی برای ماه و سال وجود دارد
    expect(find.byType(DropdownButtonFormField<int>), findsNWidgets(2));
    // دکمه امروز وجود دارد
    expect(find.text('امروز'), findsOneWidget);

    final jToday = Jalali.fromDateTime(DateTime.now());
    // هدر سال فعلی را نشان می‌دهد
    expect(find.textContaining('${jToday.year}'), findsWidgets);
  });

  testWidgets('پرش سال از طریق کشویی، تقویم را جابه‌جا می‌کند', (tester) async {
    await openPicker(tester, []);

    final yearDropdown = tester
        .widgetList<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>))
        .toList();
    expect(yearDropdown.length, 2);

    // کشویی دوم (سال) را به سال 1370 می‌بریم
    final onChanged = yearDropdown[1].onChanged;
    expect(onChanged, isNotNull);
    onChanged!(1370);
    await tester.pumpAndSettle();

    // هدر سال 1370 را نشان می‌دهد
    expect(find.textContaining('1370'), findsWidgets);
  });

  testWidgets('دکمه امروز بعد از رفتن به ماه قبل، به امروز برمی‌گردد',
      (tester) async {
    await openPicker(tester, []);

    final jToday = Jalali.fromDateTime(DateTime.now());

    // یک ماه به قبل برو
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    final prev = Jalali(jToday.year, jToday.month).addMonths(-1);
    expect(find.textContaining('${prev.year}'), findsWidgets);

    // امروز → برگشت به ماه جاری
    await tester.tap(find.text('امروز'));
    await tester.pumpAndSettle();
    expect(find.textContaining('${jToday.year}'), findsWidgets);
  });

  testWidgets('بعد از پرش سال، تأیید تاریخ اول همان ماه را برمی‌گرداند',
      (tester) async {
    final holder = <DateTime?>[];
    await openPicker(tester, holder);

    final yearDropdown = tester
        .widgetList<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>))
        .toList();
    yearDropdown[1].onChanged!(1370);
    await tester.pumpAndSettle();

    await tester.tap(find.text('تأیید'));
    await tester.pumpAndSettle();

    final picked = holder.single!;
    final j = Jalali.fromDateTime(picked);
    expect(j.year, 1370);
    expect(j.month, Jalali.fromDateTime(DateTime.now()).month);
    expect(j.day, 1);
  });

  testWidgets('عنوان درخواست‌کننده بالای سطر ماه نوشته می‌شود', (tester) async {
    await openPicker(tester, [], title: 'تاریخ رسیدن به نصاب (شروع حول)');

    expect(find.text('تاریخ رسیدن به نصاب (شروع حول)'), findsOneWidget);
  });

  testWidgets('روزِ بیرون از سقف نمایش داده می‌شود ولی انتخاب نمی‌شود',
      (tester) async {
    final latest = Jalali(1405, 1, 15).toDateTime();
    final holder = <DateTime?>[];
    await openPicker(tester, holder,
        initialDate: latest, latestDate: latest);

    expect(dayIsSelectable(tester, '20'), isFalse);
    expect(dayIsSelectable(tester, '10'), isTrue);

    await tester.tap(find.text('10'));
    await tester.pumpAndSettle();
    expect(confirm(tester).onPressed, isNotNull);

    await tester.tap(find.text('تأیید'));
    await tester.pumpAndSettle();

    final j = Jalali.fromDateTime(holder.single!);
    expect([j.year, j.month, j.day], [1405, 1, 10]);
  });

  testWidgets('پرش سال بیرون از سقف، تأیید را خاموش می‌کند', (tester) async {
    final latest = Jalali(1405, 1, 15).toDateTime();
    await openPicker(tester, [], initialDate: latest, latestDate: latest);

    final dropdowns = tester
        .widgetList<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>))
        .toList();
    dropdowns[1].onChanged!(1406);
    await tester.pumpAndSettle();

    expect(confirm(tester).onPressed, isNull);
  });

  testWidgets('ماهی که پیش از کف مجاز است هیچ روز قابل‌انتخابی ندارد',
      (tester) async {
    await openPicker(tester, [],
        initialDate: Jalali(1405, 7, 12).toDateTime(),
        earliestDate: Jalali(1405, 7, 10).toDateTime(),
        latestDate: Jalali(1405, 10).toDateTime());

    final dropdowns = tester
        .widgetList<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>))
        .toList();

    // مرداد ۱۴۰۵ یک‌سره پیش از کف است
    dropdowns[0].onChanged!(5);
    await tester.pumpAndSettle();
    expect(dayIsSelectable(tester, '12'), isFalse);
    expect(confirm(tester).onPressed, isNull);

    // ابان ۱ درون بازه است
    dropdowns[0].onChanged!(8);
    await tester.pumpAndSettle();
    expect(confirm(tester).onPressed, isNotNull);
  });
}
