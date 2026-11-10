import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/design_system/components/settings_components.dart';
import 'package:tawheeed/core/design_system/components/settings_tokens.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

Future<void> pumpSheet(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('SettingsSwitch', () {
    testWidgets('paints the spec track colors and toggles', (tester) async {
      var value = false;
      await pumpSheet(
        tester,
        StatefulBuilder(
          builder: (context, setState) => SettingsSwitch(
            value: value,
            semanticLabel: 'demo',
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      );
      Container track() => tester.widget<Container>(
            find.descendant(
              of: find.byType(SettingsSwitch),
              matching: find.byType(Container),
            ).first,
          );
      // No TimeThemeKit above → the kit falls back to the gold palette, so the
      // OFF track is that palette's outline (the kit no longer keeps a second
      // fixed sand constant).
      expect((track().decoration! as BoxDecoration).color,
          AppPalettes.goldLight.outline);
      await tester.tap(find.byType(SettingsSwitch));
      await tester.pumpAndSettle();
      expect(value, isTrue);
      expect((track().decoration! as BoxDecoration).color,
          SettingsTokens.switchOn);
      // Exact 42x24 visual inside the 48dp hit area.
      final box = track().constraints!;
      expect(box.maxWidth, 42);
      expect(box.maxHeight, 24);
    });

    testWidgets('null onChanged disables the switch', (tester) async {
      await pumpSheet(
        tester,
        const SettingsSwitch(value: true, onChanged: null),
      );
      await tester.tap(find.byType(SettingsSwitch));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('SettingsStepper', () {
    testWidgets('steps, clamps at bounds and dims the dead side',
        (tester) async {
      var value = 1;
      await pumpSheet(
        tester,
        StatefulBuilder(
          builder: (context, setState) => SettingsStepper(
            value: value,
            max: 2,
            onChanged: (v) => setState(() => value = v),
            semanticLabel: 'steps',
          ),
        ),
      );
      expect(find.text('1'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(value, 2);
      // At max, + is a no-op.
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(value, 2);
      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pumpAndSettle();
      expect(value, 1);
    });

    testWidgets('signed values use the true minus', (tester) async {
      await pumpSheet(
        tester,
        SettingsStepper(
            value: -5, signed: true, onChanged: (_) {}, unit: 'دقیقه'),
      );
      expect(find.textContaining('−5'), findsOneWidget);
      expect(find.text('دقیقه'), findsOneWidget);
    });

    testWidgets('long-press repeats', (tester) async {
      var value = 0;
      await pumpSheet(
        tester,
        StatefulBuilder(
          builder: (context, setState) => SettingsStepper(
            value: value,
            max: 100,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      );
      final gesture = await tester.startGesture(
          tester.getCenter(find.byIcon(Icons.add_rounded)));
      // Step the clock in frames, like real usage: each tick's rebuild
      // refreshes widget.value, so the repeat keeps climbing (a single
      // 1500ms pump would freeze widget.value mid-flight and prove nothing).
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(value, greaterThan(2));
    });

    testWidgets('exposes value and increase/decrease actions',
        (tester) async {
      await pumpSheet(
        tester,
        SettingsStepper(
            value: 3, onChanged: (_) {}, semanticLabel: 'stepper-demo'),
      );
      final node = tester.getSemantics(find.byType(SettingsStepper));
      expect(node.label, contains('stepper-demo'));
      expect(node.getSemanticsData().value, contains('3'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.increase),
          isTrue);
      expect(node.getSemanticsData().hasAction(SemanticsAction.decrease),
          isTrue);
    });
  });

  group('SettingsValueChip', () {
    testWidgets('paints the spec chip', (tester) async {
      await pumpSheet(tester, const SettingsValueChip(text: '18°'));
      final box = tester.widget<Container>(find.byType(Container).first);
      final decoration = box.decoration! as BoxDecoration;
      // The chip now rides the CURRENT theme (gold fallback here): fill is the
      // palette's tertiarySoft, not a fixed sand constant.
      expect(decoration.color, AppPalettes.goldLight.tertiarySoft);
      expect(find.text('18°'), findsOneWidget);
    });
  });

  group('SettingsSliderRow', () {
    testWidgets('renders tile, title, chip and slider', (tester) async {
      await pumpSheet(
        tester,
        SettingsSliderRow(
          icon: Icons.volume_up_rounded,
          accent: Colors.orange,
          title: 'demo slider',
          valueText: '55٪',
          value: 0.55,
          onChanged: (_) {},
          onSettled: (_) {},
        ),
      );
      expect(find.text('demo slider'), findsOneWidget);
      expect(find.text('55٪'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });
  });

  group('SettingsSegmented', () {
    testWidgets('selects another option', (tester) async {
      var value = 'a';
      await pumpSheet(
        tester,
        StatefulBuilder(
          builder: (context, setState) => SettingsSegmented<String>(
            options: const [
              SettingsSegment(label: 'one', value: 'a'),
              SettingsSegment(label: 'two', value: 'b'),
              SettingsSegment(label: 'three', value: 'c'),
            ],
            value: value,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      );
      await tester.tap(find.text('two'));
      await tester.pumpAndSettle();
      expect(value, 'b');
    });
  });

  group('WarningCard', () {
    testWidgets('renders text and fires the action', (tester) async {
      var fired = false;
      await pumpSheet(
        tester,
        WarningCard(
          text: 'demo warning',
          actionLabel: 'open settings',
          onAction: () => fired = true,
        ),
      );
      expect(find.text('demo warning'), findsOneWidget);
      await tester.tap(find.text('open settings'));
      await tester.pumpAndSettle();
      expect(fired, isTrue);
    });
  });

  group('SettingsSearchField', () {
    testWidgets('reports input and clears', (tester) async {
      var last = '';
      await pumpSheet(
        tester,
        SettingsSearchField(onChanged: (v) => last = v),
      );
      await tester.enterText(find.byType(TextField), 'اذان');
      await tester.pumpAndSettle();
      expect(last, 'اذان');
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(last, '');
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('DebouncedWriter', () {
    test('coalesces rapid writes, last value wins', () async {
      final writer = DebouncedWriter(delay: const Duration(milliseconds: 50));
      final seen = <int>[];
      writer.schedule(() async => seen.add(1));
      writer.schedule(() async => seen.add(2));
      writer.schedule(() async => seen.add(3));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(seen, [3]);
      writer.dispose();
    });

    test('flush runs the pending write immediately', () async {
      final writer = DebouncedWriter(delay: const Duration(seconds: 5));
      var ran = false;
      writer.schedule(() async => ran = true);
      await writer.flush();
      expect(ran, isTrue);
      writer.dispose();
    });
  });
}
