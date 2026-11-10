import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/design_system/components/app_card.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/design_system/components/section_header.dart';
import 'package:tawheeed/core/design_system/components/tokens.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal2/shared/mini_charts.dart';
import 'package:tawheeed/features/personal2/shared/personal2_style.dart';

/// Golden baselines for the two new tools' visual language, under the app's
/// default theme (day) and one other preset (night), per the brief.
///
/// The screens themselves need the live provider graph, so these pin the
/// SHARED visual pieces every screen is built from: the charts, the flat hero,
/// the child-mode tile grid and the personal-tools section row. Layout and
/// palette drift shows up here in one place instead of in eight screen-level
/// goldens that would need a fake database each.
/// Real Persian shaping: the test binding's font draws every glyph much wider
/// than Vazirmatn, so the goldens would record tofu boxes for text that fits
/// on a real phone. Same pattern as `system_nav_inset_test.dart`.
Future<void> _loadVazirmatn() async {
  final loader = FontLoader('Vazirmatn')
    ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'));
  await loader.load();
  AppTheme.fontFamily = 'Vazirmatn';
}

void main() {
  const kinds = <ThemeKind>[ThemeKind.day, ThemeKind.night];

  setUpAll(() async {
    await _loadVazirmatn();
  });

  tearDownAll(() {
    AppTheme.fontFamily = AppTheme.defaultFontFamily;
  });

  Widget app(ThemeKind kind, Widget child) => MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(DsSpacing.page),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );

  /// The charts sheet: everything drawn by `mini_charts.dart`.
  Widget chartsSheet() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'گزارش هفتگی',
            accent: Personal2Colors.kids,
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: const [
                    MiniRing(
                      progress: .72,
                      color: Personal2Colors.kids,
                      semanticLabel: 'پیشرفت',
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'سارا · ۵ از ۷ عادت',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const MiniColumnChart(
                  values: [3, 5, 2, 7, 4, 1, 6],
                  labels: ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'],
                  color: Personal2Colors.kids,
                ),
                const SizedBox(height: 12),
                const MiniBars(
                  color: Personal2Colors.kids,
                  items: [
                    MiniBarItem(label: 'مسواک زدن', value: 7, max: 7),
                    MiniBarItem(label: 'درس خواندن', value: 5, max: 7),
                    MiniBarItem(label: 'مرتب کردن اتاق', value: 2, max: 7),
                  ],
                ),
                const SizedBox(height: 10),
                const DayStrip(
                  color: Personal2Colors.teacher,
                  segments: [
                    DayStripSegment(letter: 'ش', state: DayStripState.done),
                    DayStripSegment(letter: 'ی', state: DayStripState.done),
                    DayStripSegment(letter: 'د', state: DayStripState.partial),
                    DayStripSegment(letter: 'س', state: DayStripState.missed),
                    DayStripSegment(letter: 'چ', state: DayStripState.excused),
                    DayStripSegment(letter: 'پ', state: DayStripState.done),
                    DayStripSegment(letter: 'ج', state: DayStripState.done),
                  ],
                ),
              ],
            ),
          ),
        ],
      );

  /// The child-mode tile grid + star jar.
  Widget childModeSheet() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Personal2Colors.kids,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  'س',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'سلام سارا',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Personal2Colors.kidsStars.withValues(alpha: .22),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.star_rounded,
                        size: 16, color: Personal2Colors.kidsStars),
                    SizedBox(width: 4),
                    Text('12', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final entry in const [
                ('صبح', Icons.check_rounded, .18),
                ('ظهر', Icons.check_rounded, .18),
                ('عصر', Icons.circle_outlined, .10),
                ('مغرب', Icons.lock_outline, .06),
                ('عشاء', Icons.lock_outline, .06),
              ])
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Personal2Colors.kids.withValues(alpha: entry.$3),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Icon(entry.$2, size: 18, color: Personal2Colors.kids),
                        const SizedBox(height: 4),
                        Text(entry.$1, style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.9,
            children: [
              for (final entry in const [
                ('مسواک زدن', Icons.brush_rounded, 'انجام شد · +1'),
                ('درس خواندن', Icons.menu_book_rounded, '+2 ستاره'),
                ('مرتب کردن اتاق', Icons.cleaning_services_rounded, '+1 ستاره'),
                ('کمک در خانه', Icons.home_rounded, '+2 ستاره'),
              ])
                AppCard(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DuotoneIconTile(
                        accent: Personal2Colors.kids,
                        icon: entry.$2,
                        size: 52,
                      ),
                      const Spacer(),
                      Text(
                        entry.$1,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(entry.$3, style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'تا «بستنی» فقط ۶ ستاره مانده',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: SizedBox(
                    height: 10,
                    child: Stack(
                      children: [
                        Container(color: const Color(0x33000000)),
                        FractionallySizedBox(
                          widthFactor: .6,
                          child: Container(color: Personal2Colors.kidsStars),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  /// The two new entries as they appear in «اطلاعات من».
  Widget sectionRowSheet() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'ابزارهای شخصی',
            accent: Personal2Colors.kids,
          ),
          for (final entry in const [
            (
              Icons.child_care_outlined,
              'دفتر عادت کودک',
              'عادت‌ها، نماز، ستاره و جایزه — همه روی همین دستگاه',
              Personal2Colors.kids,
            ),
            (
              Icons.menu_book_outlined,
              'دفتر مربی قرآن',
              'حضور، درس‌ها و پیشرفت شاگردان با ارجاع به صفحات مصحف',
              Personal2Colors.teacher,
            ),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.all(14),
                borderColor: entry.$4.withValues(alpha: .3),
                child: Row(
                  children: [
                    DuotoneIconTile(
                      accent: entry.$4,
                      icon: entry.$1,
                      size: 40,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.$2,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(entry.$3, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
                  ],
                ),
              ),
            ),
        ],
      );

  group('goldens', () {
    for (final kind in kinds) {
      final suffix = kind.name;

      testWidgets('charts $suffix', (tester) async {
        AppTheme.applyTheme(kind: kind, phase: TimePhase.day);
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(app(kind, chartsSheet()));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/personal2_charts_$suffix.png'),
        );
      });

      testWidgets('child mode $suffix', (tester) async {
        AppTheme.applyTheme(kind: kind, phase: TimePhase.day);
        tester.view.physicalSize = const Size(400, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(app(kind, childModeSheet()));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/personal2_child_mode_$suffix.png'),
        );
      });

      testWidgets('personal tools section $suffix', (tester) async {
        AppTheme.applyTheme(kind: kind, phase: TimePhase.day);
        tester.view.physicalSize = const Size(400, 500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(app(kind, sectionRowSheet()));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/personal2_section_$suffix.png'),
        );
      });
    }
  });
}
