import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/design_system/components/components.dart';

/// Plain MaterialApp is enough: [TimeThemeKit.of] falls back to the gold
/// light palette when the extension is absent.
Widget app(Widget child, {bool rtl = true, bool dark = false}) => MaterialApp(
      theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
      home: Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  group('AppCard', () {
    testWidgets('renders child and fires onTap', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(app(AppCard(
        onTap: () => tapped++,
        child: const Text('محتوا'),
      )));
      expect(find.text('محتوا'), findsOneWidget);
      await tester.tap(find.byType(AppCard));
      expect(tapped, 1);
    });

    testWidgets('fires onLongPress without onTap', (tester) async {
      var held = 0;
      await tester.pumpWidget(app(AppCard(
        onLongPress: () => held++,
        child: const Text('محتوا'),
      )));
      await tester.longPress(find.byType(AppCard));
      expect(held, 1);
    });
  });

  group('SectionHeader', () {
    testWidgets('renders title, count chip and trailing', (tester) async {
      await tester.pumpWidget(app(const SectionHeader(
        title: 'عنوان بخش',
        count: '۱۲',
        trailing: Icon(Icons.share_outlined),
      )));
      expect(find.text('عنوان بخش'), findsOneWidget);
      expect(find.text('۱۲'), findsOneWidget);
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    });
  });

  group('chips', () {
    testWidgets('GlassChip fires onTap', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(app(GlassChip(
        icon: Icons.refresh_rounded,
        text: 'موقعیت من',
        onTap: () => tapped++,
      )));
      await tester.tap(find.text('موقعیت من'));
      expect(tapped, 1);
    });

    testWidgets('OutlineChip and SmallChip render text', (tester) async {
      await tester.pumpWidget(app(const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlineChip(text: 'قمری'),
          SmallChip(text: 'شمسی', dot: Colors.amber),
          BadgeChip(text: 'بعدی'),
        ],
      )));
      expect(find.text('قمری'), findsOneWidget);
      expect(find.text('شمسی'), findsOneWidget);
      expect(find.text('بعدی'), findsOneWidget);
    });
  });

  group('IconTile', () {
    testWidgets('render smoke: duotone tiles', (tester) async {
      await tester.pumpWidget(app(const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTile(icon: Icons.home_rounded, color: Colors.teal),
          IconTile(icon: Icons.home_rounded, color: Colors.teal, size: 34),
        ],
      )));
      expect(find.byIcon(Icons.home_rounded), findsNWidgets(2));
    });
  });

  group('CheckCircle', () {
    testWidgets('states: empty, checked, missed', (tester) async {
      await tester.pumpWidget(app(const CheckCircle(
        checked: false,
        color: Colors.teal,
      )));
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      await tester.pumpWidget(app(const CheckCircle(
        checked: true,
        color: Colors.teal,
      )));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      await tester.pumpWidget(app(const CheckCircle(
        checked: false,
        color: Colors.teal,
        missed: true,
      )));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
    });
  });

  group('HeroCardShell', () {
    testWidgets('renders child in full and lite modes', (tester) async {
      await tester.pumpWidget(app(const HeroCardShell(
        child: Text('هیرو'),
      )));
      expect(find.text('هیرو'), findsOneWidget);
      await tester.pumpWidget(app(const HeroCardShell(
        lite: true,
        child: Text('هیرو ساده'),
      )));
      expect(find.text('هیرو ساده'), findsOneWidget);
    });
  });

  group('RingView', () {
    testWidgets('renders child at the center', (tester) async {
      await tester.pumpWidget(app(const RingView(
        progress: .5,
        semanticLabel: 'پیشرفت',
        child: Text('۵۰'),
      )));
      expect(find.text('۵۰'), findsOneWidget);
    });

    testWidgets('clamps out-of-range progress without error', (tester) async {
      await tester.pumpWidget(app(const RingView(progress: 1.7)));
      await tester.pumpWidget(app(const RingView(progress: -0.4)));
      expect(tester.takeException(), isNull);
    });
  });

  group('SettingRow', () {
    testWidgets('renders icon, texts, default chevron and fires onTap',
        (tester) async {
      var tapped = 0;
      await tester.pumpWidget(app(SettingRow(
        icon: Icons.wb_sunny_outlined,
        title: 'اذان',
        subtitle: 'صدا و اعلان',
        onTap: () => tapped++,
      )));
      expect(find.text('اذان'), findsOneWidget);
      expect(find.text('صدا و اعلان'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      await tester.tap(find.text('اذان'));
      expect(tapped, 1);
    });

    testWidgets('custom trailing replaces the chevron', (tester) async {
      await tester.pumpWidget(app(const SettingRow(
        icon: Icons.wb_sunny_outlined,
        title: 'حالت شب',
        trailing: Switch(value: true, onChanged: null),
      )));
      expect(find.byType(Switch), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    });

    testWidgets('showChevron: false drops the chevron for action rows',
        (tester) async {
      await tester.pumpWidget(app(const SettingRow(
        icon: Icons.play_circle_outline,
        title: 'پخش صدای اذان (تست)',
        showChevron: false,
      )));
      expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    });
  });

  group('SliderRow', () {
    testWidgets('shows label + value pill and reports drags', (tester) async {
      var value = 30.0;
      // LTR keeps the drag maths obvious; RTL flips the axis by design.
      await tester.pumpWidget(app(
          rtl: false,
          StatefulBuilder(
            builder: (context, setState) => SizedBox(
              width: 300,
              child: SliderRow(
                label: 'اندازه فونت',
                value: value,
                valueLabel: '${value.round()}٪',
                onChanged: (v) => setState(() => value = v),
              ),
            ),
          )));
      expect(find.text('اندازه فونت'), findsOneWidget);
      expect(find.text('30٪'), findsOneWidget);
      await tester.drag(find.byType(Slider), const Offset(60, 0));
      await tester.pump();
      expect(value, greaterThan(30));
    });

    testWidgets('null onChanged disables the slider', (tester) async {
      await tester.pumpWidget(app(const SizedBox(
        width: 300,
        child: SliderRow(label: 'غیرفعال', value: 20, onChanged: null),
      )));
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
    });
  });

  group('ValueStepper', () {
    testWidgets('increments, decrements and clamps at bounds', (tester) async {
      var value = 5;
      var calls = 0;
      await tester.pumpWidget(app(StatefulBuilder(
        builder: (context, setState) => ValueStepper(
          value: value,
          min: 4,
          max: 6,
          onChanged: (v) {
            calls++;
            setState(() => value = v);
          },
        ),
      )));
      expect(find.text('5'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(value, 6);
      expect(calls, 1);

      // At max: the plus button is disabled.
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(value, 6);
      expect(calls, 1);

      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pumpAndSettle();
      expect(value, 4); // clamped at min
      expect(calls, 3);
    });

    testWidgets('step and valueLabel are honoured', (tester) async {
      var value = 10;
      await tester.pumpWidget(app(StatefulBuilder(
        builder: (context, setState) => ValueStepper(
          value: value,
          step: 5,
          max: 20,
          valueLabel: '$value دقیقه',
          onChanged: (v) => setState(() => value = v),
        ),
      )));
      expect(find.text('10 دقیقه'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(value, 15);
    });
  });

  group('SegmentedTabs', () {
    const tabs = [
      SegmentedTab(label: 'الف', icon: Icons.star),
      SegmentedTab(label: 'ب'),
      SegmentedTab(label: 'ج'),
    ];

    testWidgets('fires onChanged once per real change', (tester) async {
      var index = 0;
      var calls = 0;
      await tester.pumpWidget(app(StatefulBuilder(
        builder: (context, setState) => SizedBox(
          width: 300,
          child: SegmentedTabs(
            tabs: tabs,
            index: index,
            onChanged: (i) {
              calls++;
              setState(() => index = i);
            },
          ),
        ),
      )));
      await tester.tap(find.text('ب'));
      await tester.pumpAndSettle();
      expect(index, 1);
      expect(calls, 1);

      // Re-tapping the active segment is a no-op.
      await tester.tap(find.text('ب'));
      await tester.pumpAndSettle();
      expect(calls, 1);
    });
  });

  group('AppBottomNav', () {
    const items = [
      AppNavItem(icon: Icons.home_rounded, label: 'خانه', hue: Colors.blue),
      AppNavItem(
          icon: Icons.auto_stories_rounded, label: 'قرآن', hue: Colors.green),
      AppNavItem(
          icon: Icons.wb_sunny_outlined, label: 'تسبیح', hue: Colors.orange),
      AppNavItem(
          icon: Icons.calendar_month_rounded,
          label: 'تقویم',
          hue: Colors.purple),
      AppNavItem(
          icon: Icons.assignment_rounded, label: 'ارزیابی', hue: Colors.red),
      AppNavItem(
          icon: Icons.grid_view_rounded, label: 'بیشتر', hue: Colors.brown),
    ];

    testWidgets('renders all labels and reports selections', (tester) async {
      var index = 0;
      await tester.pumpWidget(app(StatefulBuilder(
        builder: (context, setState) => AppBottomNav(
          items: items,
          index: index,
          onSelected: (i) => setState(() => index = i),
        ),
      )));
      for (final item in items) {
        expect(find.text(item.label), findsOneWidget);
      }
      await tester.tap(find.text('تقویم'));
      await tester.pumpAndSettle();
      expect(index, 3);
    });
  });

  group('narrow width + large text', () {
    testWidgets('kit lays out at 320dp / textScale 1.3 without overflow',
        (tester) async {
      final kit = MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: SizedBox(
                    width: 320,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeader(title: 'نمازهای امروز', count: '۵'),
                        AppCard(
                          child: Column(
                            children: [
                              SettingRow(
                                icon: Icons.wb_sunny_outlined,
                                title: 'اذان صبح',
                                subtitle: 'اعلان فعال است',
                                onTap: () {},
                              ),
                              SliderRow(
                                label: 'صدای اذان',
                                value: 70,
                                onChanged: (_) {},
                              ),
                              const SegmentedTabs(
                                tabs: [
                                  SegmentedTab(label: 'امروز'),
                                  SegmentedTab(
                                      label: 'هفتگی', icon: Icons.star),
                                  SegmentedTab(label: 'ماهانه'),
                                ],
                                index: 1,
                                onChanged: _noop,
                              ),
                              const ValueStepper(value: 33, onChanged: _noop),
                            ],
                          ),
                        ),
                        const HeroCardShell(
                          child: Text('امروز'),
                        ),
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GlassChip(icon: Icons.place, text: 'موقعیت من'),
                            SizedBox(width: 6),
                            OutlineChip(text: 'قمری'),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SmallChip(text: 'شمسی', dot: Colors.amber),
                            SizedBox(width: 6),
                            CheckCircle(checked: true, color: Colors.teal),
                            SizedBox(width: 6),
                            RingView(progress: .4, size: 48, child: Text('۴۰')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(kit);
      expect(tester.takeException(), isNull);
    });
  });

  group('dsContentColor', () {
    testWidgets('returns an opaque readable color in both modes',
        (tester) async {
      const hue = Color(0xFF1F7A63);
      for (final dark in [false, true]) {
        late Color result;
        await tester.pumpWidget(app(
          Builder(builder: (context) {
            result = dsContentColor(context, hue);
            return const SizedBox.shrink();
          }),
          dark: dark,
        ));
        expect(result.a, 1);
        expect(result, isNot(hue));
      }
    });
  });
}

void _noop(int _) {}
