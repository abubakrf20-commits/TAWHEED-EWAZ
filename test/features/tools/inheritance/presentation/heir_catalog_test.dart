import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/design_system/components/app_card.dart';
import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/heir_catalog.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/munasakhat_sheet_content.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/tabs/inheritance_calculator_tab.dart';
import 'package:tawheeed/features/tools/inheritance/data/inheritance_content.dart';

/// One catalog for both heir pickers, and one tap from the calculator tab to
/// the مناسخات sheet.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await InheritanceContent.load();
  });

  group('heir catalog', () {
    test('every heir appears exactly once, in display order', () {
      expect(kHeirOptions.length, HeirType.values.length);
      final seen = <HeirType>{};
      for (final o in kHeirOptions) {
        expect(seen.add(o.type), isTrue, reason: 'duplicate ${o.type.name}');
        expect(o.label, isNotEmpty);
      }
      expect(seen, HeirType.values.toSet());
    });

    test('heirOptionOf round-trips', () {
      for (final t in HeirType.values) {
        expect(heirOptionOf(t)?.type, t);
        expect(heirOptionOf(t)?.maxCount, heirMaxCount(t));
      }
    });

    test('only the spouse row changes with the deceased’s gender', () {
      final forMan = visibleHeirOptions(isMale: true);
      final forWoman = visibleHeirOptions(isMale: false);

      expect(forMan.any((o) => o.type == HeirType.husband), isFalse);
      expect(forMan.any((o) => o.type == HeirType.wife), isTrue);
      expect(forWoman.any((o) => o.type == HeirType.husband), isTrue);
      expect(forWoman.any((o) => o.type == HeirType.wife), isFalse);
      expect(forMan.length, HeirType.values.length - 1);
      expect(forWoman.length, HeirType.values.length - 1);

      final shared = forMan
          .map((o) => o.type)
          .toSet()
          .intersection(forWoman.map((o) => o.type).toSet());
      expect(
          shared,
          HeirType.values
              .toSet()
              .difference({HeirType.husband, HeirType.wife}));
    });

    test('a spouse is never counted twice', () {
      expect(heirMaxCount(HeirType.husband), 1);
      expect(heirOptionOf(HeirType.wife)?.maxCount, 4);
    });
  });

  group('the مناسخات entry on the calculator tab', () {
    Future<void> pumpTab(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: InheritanceCalculatorTab()),
      ));
      await tester.pump();
    }

    testWidgets('one tap on the kit row opens the sheet', (tester) async {
      await pumpTab(tester);

      expect(find.byType(MunasakhatSheetContent), findsNothing);
      expect(find.text('محاسبه مناسخات'), findsOneWidget);
      // the entry is a kit card, not a gradient box
      expect(
          find.ancestor(
              of: find.text('محاسبه مناسخات'), matching: find.byType(AppCard)),
          findsOneWidget);

      await tester.ensureVisible(find.text('محاسبه مناسخات'));
      await tester.tap(find.text('محاسبه مناسخات'));
      await tester.pumpAndSettle();

      expect(find.byType(MunasakhatSheetContent), findsOneWidget);
      expect(find.text('متوفی این مرحله کدام وارث بود؟'), findsNothing);
    });

    testWidgets('the sheet opens on the madhab the tab is set to',
        (tester) async {
      await pumpTab(tester);

      final hanafi = find.text(madhabLabel(Madhab.hanafi));
      await tester.ensureVisible(hanafi);
      await tester.tap(hanafi);
      await tester.pump();

      await tester.ensureVisible(find.text('محاسبه مناسخات'));
      await tester.tap(find.text('محاسبه مناسخات'));
      await tester.pumpAndSettle();

      final selectedAlpha =
          const Color(0xFF6A1B9A).withValues(alpha: .18); // the chip's fill
      final chip = tester.widget<Container>(find
          .descendant(
              of: find.byKey(const ValueKey('madhab-hanafi')),
              matching: find.byType(Container))
          .first);
      expect((chip.decoration as BoxDecoration).color, selectedAlpha);
    });
  });
}
