import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/shared/widgets/latin_time_picker.dart';
import 'package:tawheeed/shared/widgets/number_input_formatters.dart';

/// The app pins `Locale('fa')` (main.dart), so Material's `showTimePicker`
/// formats its dial AND its text input with Persian digits and then parses the
/// typed value with a plain `int.tryParse` — «۲۱:۳۰» was refused as invalid.
/// This dialog is the replacement: the fields fold ۰-۹/٠-٩ to ASCII as the user
/// types, so whatever keyboard the phone offers, the stored value is Latin.
void main() {
  Future<void> openPicker(
    WidgetTester tester,
    List<TimeOfDay?> holder, {
    TimeOfDay initial = const TimeOfDay(hour: 21, minute: 30),
    String title = 'ساعت',
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                holder.add(await showLatinTimePicker(
                  context,
                  initialTime: initial,
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

  List<TextField> fields(WidgetTester tester) => tester
      .widgetList<TextField>(find.byType(TextField))
      .toList(growable: false);

  group('LatinTimePickerDialog', () {
    testWidgets('prefills the initial time in Latin digits', (tester) async {
      await openPicker(tester, [],
          initial: const TimeOfDay(hour: 21, minute: 5));

      final f = fields(tester);
      expect(f, hasLength(2));
      expect(f[0].controller!.text, '21');
      expect(f[1].controller!.text, '5');
    });

    testWidgets('a typed Persian- or Arabic-digit time is folded to Latin',
        (tester) async {
      await openPicker(tester, []);

      await tester.enterText(find.byType(TextField).first, '۰۸');
      await tester.enterText(find.byType(TextField).last, '٤٥');

      final f = fields(tester);
      expect(f[0].controller!.text, '08');
      expect(f[1].controller!.text, '45');
    });

    testWidgets('non-digits never reach a field and two is the cap',
        (tester) async {
      await openPicker(tester, []);

      // 'abc' is dropped, the typed ۷ arrives as ASCII 7.
      await tester.enterText(find.byType(TextField).first, 'abc۷');
      expect(fields(tester)[0].controller!.text, '7');

      // A third digit has no room: the field holds a two-digit number.
      await tester.enterText(find.byType(TextField).last, '123');
      expect(fields(tester)[1].controller!.text.length, lessThanOrEqualTo(2));
    });

    testWidgets('a valid time is returned as a Latin-valued TimeOfDay',
        (tester) async {
      final holder = <TimeOfDay?>[];
      await openPicker(tester, holder);

      await tester.enterText(find.byType(TextField).first, '۷');
      await tester.enterText(find.byType(TextField).last, '۰۵');
      await tester.tap(find.text('تأیید'));
      await tester.pumpAndSettle();

      expect(holder, hasLength(1));
      expect(holder.single, const TimeOfDay(hour: 7, minute: 5));
      expect(find.byType(LatinTimePickerDialog), findsNothing);
    });

    testWidgets('out-of-range values name the range and keep the dialog open',
        (tester) async {
      final holder = <TimeOfDay?>[];
      await openPicker(tester, holder,
          initial: const TimeOfDay(hour: 0, minute: 0));

      await tester.enterText(find.byType(TextField).first, '25');
      await tester.enterText(find.byType(TextField).last, '61');
      await tester.tap(find.text('تأیید'));
      await tester.pumpAndSettle();

      expect(find.text('0 تا 23'), findsOneWidget);
      expect(find.text('0 تا 59'), findsOneWidget);
      expect(find.byType(LatinTimePickerDialog), findsOneWidget);
      expect(holder, isEmpty);
    });

    testWidgets('the boundary times 00:00 and 23:59 are accepted',
        (tester) async {
      final holder = <TimeOfDay?>[];
      await openPicker(tester, holder,
          initial: const TimeOfDay(hour: 12, minute: 0));

      await tester.enterText(find.byType(TextField).first, '23');
      await tester.enterText(find.byType(TextField).last, '59');
      await tester.tap(find.text('تأیید'));
      await tester.pumpAndSettle();
      expect(holder.single, const TimeOfDay(hour: 23, minute: 59));

      holder.clear();
      await openPicker(tester, holder,
          initial: const TimeOfDay(hour: 9, minute: 9));
      await tester.enterText(find.byType(TextField).first, '0');
      await tester.enterText(find.byType(TextField).last, '00');
      await tester.tap(find.text('تأیید'));
      await tester.pumpAndSettle();
      expect(holder.single, const TimeOfDay(hour: 0, minute: 0));
    });

    testWidgets('the caller\'s title is what the dialog asks', (tester) async {
      await openPicker(tester, [], title: 'تاریخ رسیدن به نصاب');
      expect(find.text('تاریخ رسیدن به نصاب'), findsOneWidget);
    });

    testWidgets('cancel returns null', (tester) async {
      final holder = <TimeOfDay?>[];
      await openPicker(tester, holder);

      await tester.tap(find.text('لغو'));
      await tester.pumpAndSettle();

      expect(holder, hasLength(1));
      expect(holder.single, isNull);
    });

    testWidgets('the fields take the app font, not a Material default',
        (tester) async {
      await openPicker(tester, []);
      for (final f in fields(tester)) {
        expect(f.style!.fontFamily, AppTheme.fontFamily);
      }
    });
  });

  group('LatinDigitFoldFormatter', () {
    const fold = LatinDigitFoldFormatter();
    TextEditingValue typed(String text) => TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));

    test('folds Persian digits and leaves the rest of the text alone', () {
      final r = fold.formatEditUpdate(TextEditingValue.empty, typed('۲۱:۳۰'));
      expect(r.text, '21:30');
    });

    test('folds Arabic-Indic digits', () {
      expect(fold.formatEditUpdate(TextEditingValue.empty, typed('٢١:٣٠')).text,
          '21:30');
    });

    test('returns Latin text untouched, not a rebuilt value', () {
      final v = typed('21:30');
      expect(fold.formatEditUpdate(TextEditingValue.empty, v), same(v));
    });

    test('keeps the caret where the user left it', () {
      final r = fold.formatEditUpdate(
          TextEditingValue.empty,
          const TextEditingValue(
              text: '۱۲', selection: TextSelection.collapsed(offset: 2)));
      expect(r.text, '12');
      expect(r.selection.baseOffset, 2);
    });

    test('clamps a selection beyond the folded length', () {
      final r = fold.formatEditUpdate(
          TextEditingValue.empty,
          const TextEditingValue(
              text: '۱۲',
              selection: TextSelection(baseOffset: 9, extentOffset: 12)));
      expect(r.selection.baseOffset, 2);
      expect(r.selection.extentOffset, 2);
    });

    test('is a TextInputFormatter usable in a formatters list', () {
      expect(fold, isA<TextInputFormatter>());
      expect(const [LatinDigitFoldFormatter()], hasLength(1));
    });
  });
}
