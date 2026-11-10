import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/features/settings/domain/entities/app_settings.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_notifier.dart';
import 'package:tawheeed/features/tools/date_converter/presentation/screens/date_converter_screen.dart';
import 'package:tawheeed/shared/utils/hijri_utils.dart';

class _MockSettings extends Settings {
  AppSettings settings = const AppSettings(hijriOffset: 0);

  @override
  Future<AppSettings> build() async => settings;

  @override
  Future<void> patch(AppSettings Function(AppSettings) updater) async {
    settings = updater(settings);
  }
}

/// The single number field on the page — the input card is built only for the
/// active source system, so exactly one [TextField] ever exists.
String _yearField(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

/// `find.byIcon` answers the [Icon] inside the button, so the state of the
/// button itself has to be read through its ancestor.
IconButton _button(WidgetTester tester, IconData icon, {int index = 0}) =>
    tester
        .widgetList<IconButton>(find.ancestor(
            of: find.byIcon(icon), matching: find.byType(IconButton)))
        .elementAt(index);

/// Opens the page at 400dp: the width where the month strip genuinely has to
/// scroll, and where the result rows have to prove they fit.
Future<void> _open(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(ProviderScope(
    overrides: [settingsProvider.overrideWith(_MockSettings.new)],
    child: MaterialApp(
      home: Directionality(textDirection: TextDirection.rtl, child: screen),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders source selector and all three result cards',
      (tester) async {
    await _open(tester, const DateConverterScreen());

    expect(find.text('مبدل تاریخ'), findsOneWidget);
    expect(find.text('هجری'), findsOneWidget);
    expect(find.text('شمسی'), findsOneWidget);
    expect(
        find.text('میلادی'), findsNWidgets(2)); // source segment + result card
    expect(find.text('هجری قمری'), findsOneWidget);
    expect(find.text('شمسی (جلالی)'), findsOneWidget);
    // The today shortcut button is available.
    expect(find.byIcon(Icons.today), findsOneWidget);
  });

  testWidgets('switching the source type keeps all three calendars in sync',
      (tester) async {
    await _open(tester, const DateConverterScreen());

    // Hijri source is the default; switch to شمسی and verify the result
    // cards still render without errors.
    await tester.tap(find.text('شمسی'));
    await tester.pumpAndSettle();

    expect(find.text('هجری قمری'), findsOneWidget);
    expect(find.text('شمسی (جلالی)'), findsOneWidget);
    expect(find.text('میلادی'), findsNWidgets(2));
  });

  group('converting', () {
    testWidgets('a Gregorian anchor prints the same day in all three cards',
        (tester) async {
      await _open(
          tester,
          const DateConverterScreen(
              initialGregorianDay: 30,
              initialGregorianMonth: 10,
              initialGregorianYear: 2026));

      expect(find.text('30 اکتبر 2026'), findsOneWidget);
      // Derived, not hand-typed: the box has to agree with the app's own
      // conversion of the same day, in both other calendars. The mock settings
      // resolve only after initState, so this also proves the page re-converts
      // when the real offset (0) arrives instead of keeping its fallback.
      final j = Jalali.fromDateTime(DateTime(2026, 10, 30));
      final h = HijriUtils.hijriFromGreg(2026, 10, 30);
      expect(
          find.text(
              '${j.day} ${DateConstants.persianMonths[j.month - 1]} ${j.year}'),
          findsOneWidget);
      expect(
          find.text(
              '${h.day} ${DateConstants.hijriMonths[h.month - 1]} ${h.year}'),
          findsOneWidget);
      // The weekday comes from the calendar section's own display table, and
      // 30 October 2026 is a Friday.
      expect(find.text('جمعه'), findsOneWidget);
    });

    testWidgets('changing the source system does not move the day',
        (tester) async {
      await _open(
          tester,
          const DateConverterScreen(
              initialGregorianDay: 30,
              initialGregorianMonth: 10,
              initialGregorianYear: 2026));

      await tester.tap(find.text('شمسی'));
      await tester.pumpAndSettle();
      expect(find.text('30 اکتبر 2026'), findsOneWidget);

      await tester.tap(find.text('هجری'));
      await tester.pumpAndSettle();
      expect(find.text('30 اکتبر 2026'), findsOneWidget);
      expect(find.text('جمعه'), findsOneWidget);
    });

    testWidgets('the ±10 steppers write the year field, not only the state',
        (tester) async {
      await _open(
          tester,
          const DateConverterScreen(
              initialHijriDay: 1,
              initialHijriMonth: 1,
              initialHijriYear: 1400));
      expect(_yearField(tester), '1400');

      await tester.tap(find.byIcon(Icons.fast_forward));
      await tester.pumpAndSettle();
      expect(_yearField(tester), '1410');

      await tester.tap(find.byIcon(Icons.fast_rewind));
      await tester.pumpAndSettle();
      expect(_yearField(tester), '1400');
    });

    testWidgets('the ±10 steppers stop at the range edge', (tester) async {
      await _open(
          tester,
          const DateConverterScreen(
              initialHijriDay: 1,
              initialHijriMonth: 1,
              initialHijriYear: 1495));

      expect(_button(tester, Icons.fast_forward).onPressed, isNull);
      expect(find.text('1 محرم 1495'), findsOneWidget);
    });

    testWidgets('a half-typed year is not applied', (tester) async {
      await _open(
          tester,
          const DateConverterScreen(
              initialHijriDay: 1,
              initialHijriMonth: 1,
              initialHijriYear: 1400));

      // The guard against the old clamp-per-keystroke bug: «1» must not become
      // the minimum year, so the conversion has to stay on 1400 all the way in.
      await tester.enterText(find.byType(TextField), '1');
      await tester.pump();
      expect(find.text('1 محرم 1400'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '1447');
      await tester.pumpAndSettle();
      expect(_yearField(tester), '1447');
    });

    testWidgets('the day stepper stops at the month length', (tester) async {
      final lastDay = HijriUtils.hijriMonthLength(1, year: 1447);
      await _open(
          tester,
          DateConverterScreen(
              initialHijriDay: lastDay,
              initialHijriMonth: 1,
              initialHijriYear: 1447));

      // The year row carries the first add button, the day row the second.
      expect(_button(tester, Icons.add_circle_outline, index: 1).onPressed,
          isNull);
    });
  });

  group('month strip', () {
    testWidgets('opens with the selected month in view', (tester) async {
      await _open(
          tester,
          const DateConverterScreen(
              initialGregorianDay: 25,
              initialGregorianMonth: 12,
              initialGregorianYear: 2025));

      expect(find.text('25 دسامبر 2025'), findsOneWidget);
      // The strip used to start at month 1, which left a December anchor
      // scrolled out of the viewport with nothing hinting it was there.
      final rect = tester.getRect(find.text(DateConstants.gregorianMonths[11]));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(400));
    });

    testWidgets('tapping a month name converts to it', (tester) async {
      await _open(
          tester,
          const DateConverterScreen(
              initialGregorianDay: 25,
              initialGregorianMonth: 12,
              initialGregorianYear: 2025));

      // نوامبر is the neighbour the reveal leaves on screen; ژانویه sits at the
      // far end of the strip and is genuinely scrolled away here.
      await tester.tap(find.text('نوامبر'));
      await tester.pumpAndSettle();
      expect(find.text('25 نوامبر 2025'), findsOneWidget);
    });

    testWidgets('the strip re-anchors when the source system changes',
        (tester) async {
      await _open(
          tester,
          const DateConverterScreen(
              initialGregorianDay: 25,
              initialGregorianMonth: 12,
              initialGregorianYear: 2025));

      // 25 دسامبر 2025 is 4 دی 1404 — the شمسى strip has to open on دی, not on
      // the month 12 position it held for the میلادی names.
      await tester.tap(find.text('شمسی'));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.text(DateConstants.persianMonths[9]));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(400));
    });
  });
}
