import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/design_system/components/app_card.dart';
import 'package:tawheeed/core/design_system/components/stepper.dart';
import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/gender_toggle.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/munasakhat_sheet_content.dart';

/// The مناسخات form as the user drives it: stage 2 and on do not type a name,
/// they PICK one of the previous stage's heirs, and that pick decides both the
/// money that moves and the next deceased's gender.
void main() {
  const accent = Color(0xFF6A1B9A);

  Future<void> pumpSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        // the app is RTL; a chip Wrap and a stepper row lay out differently
        // per direction, so the form is tested the way it is actually read
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            child: MunasakhatSheetContent(
              accent: accent,
              onClose: () {},
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> count(WidgetTester tester, int stage, HeirType heir,
      {int times = 1, bool down = false}) async {
    final icon = down ? Icons.remove_rounded : Icons.add_rounded;
    final button = find.descendant(
      of: find.byKey(ValueKey('count-$stage-${heir.name}')),
      matching: find.byIcon(icon),
    );
    for (int i = 0; i < times; i++) {
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
    }
  }

  Future<void> addStage(WidgetTester tester) async {
    final button = find.text('افزودن مرحله');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> pickLink(WidgetTester tester, int stage, HeirType heir) async {
    final chip = find.byKey(ValueKey('link-$stage-${heir.name}'));
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  Future<void> compute(WidgetTester tester) async {
    final button = find.text('محاسبه');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> setEstate(WidgetTester tester, String value) async {
    final field = find.byType(TextField).first;
    await tester.ensureVisible(field);
    await tester.enterText(field, value);
    await tester.pump();
  }

  testWidgets('stage 2 opens with no free-text deceased — it must be picked',
      (tester) async {
    await pumpSheet(tester);
    expect(find.text('متوفی این مرحله کدام وارث بود؟'), findsNothing);
    expect(find.byType(GenderToggle), findsOneWidget);

    await addStage(tester);

    expect(find.byType(AppCard), findsNWidgets(2));
    expect(find.text('یکی از ورثهٔ مرحلهٔ 1 را انتخاب کنید'), findsOneWidget);
    expect(find.textContaining('هنوز وارثی ندارد'), findsOneWidget);
    // the gender of a chained deceased is never asked for — it follows the pick
    expect(find.byType(GenderToggle), findsOneWidget);
  });

  testWidgets('the picker offers exactly the heirs entered for stage 1',
      (tester) async {
    await pumpSheet(tester);
    await count(tester, 0, HeirType.son);
    await count(tester, 0, HeirType.daughter, times: 2);
    await addStage(tester);

    expect(find.byKey(const ValueKey('link-1-son')), findsOneWidget);
    expect(find.byKey(const ValueKey('link-1-daughter')), findsOneWidget);
    expect(find.text('دختر (2)'), findsOneWidget);
    // an heir nobody entered is not offered
    expect(find.byKey(const ValueKey('link-1-father')), findsNothing);

    await pickLink(tester, 1, HeirType.son);
    expect(find.text('پسر · مرد'), findsOneWidget);
  });

  testWidgets('picking a female heir makes the next deceased a woman',
      (tester) async {
    await pumpSheet(tester);
    await count(tester, 0, HeirType.daughter);
    await addStage(tester);
    await pickLink(tester, 1, HeirType.daughter);

    expect(find.text('دختر · زن'), findsOneWidget);
    final stage2 = find.byKey(const ValueKey('stage-card-1'));
    // a woman has a husband, not wives
    expect(find.descendant(of: stage2, matching: find.text('شوهر')),
        findsOneWidget);
    expect(
        find.descendant(of: stage2, matching: find.text('همسر')), findsNothing);
  });

  testWidgets('dropping the heir in stage 1 drops the link that used it',
      (tester) async {
    await pumpSheet(tester);
    await count(tester, 0, HeirType.son);
    await addStage(tester);
    await pickLink(tester, 1, HeirType.son);
    expect(find.text('پسر · مرد'), findsOneWidget);

    await count(tester, 0, HeirType.son, down: true);

    expect(find.text('پسر · مرد'), findsNothing);
    expect(find.byKey(const ValueKey('link-1-son')), findsNothing);
    expect(find.text('یکی از ورثهٔ مرحلهٔ 1 را انتخاب کنید'), findsOneWidget);
  });

  testWidgets('an unlinked stage is refused before any number appears',
      (tester) async {
    await pumpSheet(tester);
    await count(tester, 0, HeirType.son);
    await addStage(tester);

    await compute(tester);

    expect(find.textContaining('مشخص کنید متوفی کدام وارثِ'), findsOneWidget);
    expect(find.text('نتیجهٔ مناسخات'), findsNothing);
  });

  testWidgets('a blocked heir says so in Persian instead of passing zero on',
      (tester) async {
    await pumpSheet(tester);
    await count(tester, 0, HeirType.father);
    await count(tester, 0, HeirType.fullBrother);
    await addStage(tester);
    await pickLink(tester, 1, HeirType.fullBrother);
    await count(tester, 1, HeirType.mother);

    await compute(tester);

    expect(find.textContaining('سهم نمی‌بَد'), findsOneWidget);
    expect(find.text('نتیجهٔ مناسخات'), findsNothing);
  });

  testWidgets(
      'the chain moves the picked heir’s own share, and says where it came from',
      (tester) async {
    await pumpSheet(tester);
    await setEstate(tester, '300,000');
    await count(tester, 0, HeirType.son);
    await count(tester, 0, HeirType.daughter);
    await addStage(tester);
    await pickLink(tester, 1, HeirType.daughter);
    await count(tester, 1, HeirType.mother);

    await compute(tester);

    expect(find.text('نتیجهٔ مناسخات'), findsOneWidget);
    expect(find.textContaining('2 مرحله'), findsOneWidget);
    expect(find.textContaining('سهم منتقل‌شده از «دختر» در مرحلهٔ 1'),
        findsOneWidget);
    // 300,000 between son and daughter 2:1 → the daughter's third is the estate
    expect(find.text('100,000'), findsWidgets);
    // the engine was never reduced to an estimate
    expect(find.textContaining('تقریبی'), findsNothing);
  });

  testWidgets('a Persian-digit estate is read, not rejected', (tester) async {
    await pumpSheet(tester);
    await setEstate(tester, '۳۰۰٬۰۰۰');
    await count(tester, 0, HeirType.son);

    await compute(tester);

    expect(find.text('نتیجهٔ مناسخات'), findsOneWidget);
    expect(find.textContaining('300,000'), findsWidgets);
    expect(find.textContaining('خطا در محاسبه'), findsNothing);
  });

  testWidgets('the stage a chain ends on still shows every heir’s share',
      (tester) async {
    await pumpSheet(tester);
    await setEstate(tester, '120,000');
    await count(tester, 0, HeirType.wife);
    await count(tester, 0, HeirType.mother);
    await count(tester, 0, HeirType.father);

    await compute(tester);

    final stage1 = find.byKey(const ValueKey('stage-result-0'));
    expect(find.descendant(of: stage1, matching: find.text('همسر')),
        findsOneWidget);
    expect(find.descendant(of: stage1, matching: find.text('مادر')),
        findsOneWidget);
    expect(find.descendant(of: stage1, matching: find.text('پدر')),
        findsOneWidget);
    expect(find.textContaining('از ترکه'), findsWidgets);
  });

  testWidgets('removing a stage takes its link with it', (tester) async {
    await pumpSheet(tester);
    await count(tester, 0, HeirType.son);
    await addStage(tester);
    await pickLink(tester, 1, HeirType.son);
    await addStage(tester);
    expect(find.byType(AppCard), findsNWidgets(3));

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    // stage 1 is gone: the old stage 2 is the first deceased again
    expect(find.byType(AppCard), findsNWidgets(2));
    expect(find.text('متوفی اول'), findsOneWidget);
    expect(find.text('یکی از ورثهٔ مرحلهٔ 1 را انتخاب کنید'), findsOneWidget);
  });

  testWidgets('the sheet opens on the madhab the calculator tab uses',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MunasakhatSheetContent(
            accent: accent,
            initialMadhab: Madhab.hanafi,
            onClose: () {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('madhab-hanafi')), findsOneWidget);
    expect(find.text(madhabLabel(Madhab.hanafi)), findsOneWidget);
  });

  testWidgets('every stepper in the form is the kit one', (tester) async {
    await pumpSheet(tester);
    expect(find.byType(ValueStepper), findsWidgets);
    expect(find.byIcon(Icons.add_circle_outline), findsNothing);
  });

  testWidgets('a three-stage chain fits a 320dp phone at 1.3 text scale',
      (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 720 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              child: MunasakhatSheetContent(accent: accent, onClose: () {}),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await count(tester, 0, HeirType.son);
    await count(tester, 0, HeirType.daughter, times: 2);
    await addStage(tester);
    await pickLink(tester, 1, HeirType.daughter);
    await count(tester, 1, HeirType.husband);
    await addStage(tester);
    await pickLink(tester, 2, HeirType.husband);
    await count(tester, 2, HeirType.mother);
    await compute(tester);

    // an overflow or a RenderFlex exception lands here
    expect(tester.takeException(), isNull);
    // nothing is drawn outside the phone's width
    final steppers = tester.widgetList(find.byType(ValueStepper)).length;
    expect(steppers, greaterThan(0));
    for (var i = 0; i < steppers; i++) {
      final rect = tester.getRect(find.byType(ValueStepper).at(i));
      expect(rect.right, lessThanOrEqualTo(320 + 0.5));
      expect(rect.left, greaterThanOrEqualTo(-0.5));
    }
    expect(find.text('نتیجهٔ مناسخات'), findsOneWidget);
  });
}
