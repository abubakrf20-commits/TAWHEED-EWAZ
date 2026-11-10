import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// Fixed-phase visual baselines for the redesign (spec §6.3, lightened to
/// what is deterministic without a device): the full component kit sheet under
/// each of the four pinned ThemeKinds. Goldens are
/// recorded on the host (`flutter test --update-goldens`); they guard layout
/// and palette drift, not on-device font shaping.
///
/// The «بیشتر» hub has its own, richer golden set in
/// `test/features/settings/presentation/screens/more_golden_test.dart`.
final _kinds = <ThemeKind>[
  ThemeKind.dawn,
  ThemeKind.day,
  ThemeKind.sunset,
  ThemeKind.night,
];

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.light,
      home: Directionality(textDirection: TextDirection.rtl, child: home),
    );

/// Everything static: no live clocks, fixed values, settled animations.
Widget _kitSheet() {
  const teal = Color(0xFF00897B);
  return Scaffold(
    bottomNavigationBar: AppBottomNav(
      index: 0,
      onSelected: (_) {},
      items: const [
        AppNavItem(icon: Icons.home_rounded, label: 'خانه', hue: teal),
        AppNavItem(
            icon: Icons.schedule_rounded, label: 'نماز', hue: Color(0xFF795548)),
        AppNavItem(
            icon: Icons.menu_book_rounded, label: 'بیشتر', hue: teal),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(10),
      children: [
        HeroCardShell(
          child: Row(
            children: [
              const Icon(Icons.mosque_rounded,
                  color: AppPalette.heroGold, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text('اذان مغرب',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 15,
                        color: Colors.white)),
              ),
              Text('17:38',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 15,
                      color: AppPalette.heroGold)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            GlassChip(icon: Icons.location_on_outlined, text: 'تهران'),
            SizedBox(width: 8),
            OutlineChip(text: 'سه‌شنبه ۱ مهر'),
            SizedBox(width: 8),
            SmallChip(text: '۶ نماز', dot: teal),
          ],
        ),
        const SizedBox(height: 6),
        const SectionHeader(title: 'نمازها', count: '6'),
        AppCard(
          child: Column(
            children: [
              const SettingRow(
                icon: Icons.wb_twilight_rounded,
                title: 'اذان صبح',
                subtitle: 'طلوع ۰۵:۴۰',
                trailing: Text('۰۳:۵۲'),
              ),
              const SettingRow(
                icon: Icons.favorite_rounded,
                title: 'ثبت نماز',
                color: teal,
                showChevron: false,
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('صبح'),
                  SizedBox(width: 8),
                  CheckCircle(checked: true, color: teal),
                  SizedBox(width: 8),
                  CheckCircle(checked: false, missed: true, color: teal),
                ]),
              ),
              SliderRow(
                  label: 'ضریب اکول', value: 40, onChanged: (_) {},
                  divisions: 10, color: teal),
              ValueStepper(value: 3, onChanged: (_) {}),
            ],
          ),
        ),
        const SectionHeader(title: 'گزارش روز'),
        AppCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              RingView(progress: .62,
                  color: teal,
                  semanticLabel: '۶۲٪ نماز',
                  child: Text('62%',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily, fontSize: 13))),
              RingView(progress: .25,
                  color: const Color(0xFFF9A825),
                  child: Text('25%',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily, fontSize: 13))),
              const IconTile(
                  icon: Icons.battery_charging_full_rounded,
                  color: teal,
                  semanticLabel: 'هدف روز'),
            ],
          ),
        ),
        SegmentedTabs(
            index: 1,
            onChanged: (_) {},
            tabs: const [
              SegmentedTab(label: 'روزانه'),
              SegmentedTab(label: 'هفتگی'),
              SegmentedTab(label: 'ماهانه'),
            ]),
        const SizedBox(height: 12),
      ],
    ),
  );
}

void main() {
  for (final kind in _kinds) {
    final name = kind.name;
    testWidgets('kit sheet golden — $name', (tester) async {
      AppTheme.applyTheme(kind: kind, phase: TimePhase.day);
      await tester.binding.setSurfaceSize(const Size(412, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(Scaffold(body: _kitSheet())));
      await tester.pump(const Duration(milliseconds: 500));
      await expectLater(find.byType(Scaffold).first,
          matchesGoldenFile('goldens/kit_$name.png'));
    });
  }
}
