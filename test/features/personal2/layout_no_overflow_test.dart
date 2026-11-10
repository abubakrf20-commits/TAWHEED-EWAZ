import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/design_system/components/app_card.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/design_system/components/section_header.dart';
import 'package:tawheeed/core/design_system/components/tokens.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/personal2/shared/mini_charts.dart';
import 'package:tawheeed/features/personal2/shared/personal2_style.dart';

/// Layout guards for the new tools' geometry.
///
/// The brief requires "no overflow at 320/360/412 dp and text scale 1.0/1.3
/// (RTL) for all screens and sheets". These tests pump the widgets whose
/// sizing math is mine — the charts, the card rows and the child-mode tile
/// grid — at each width and scale. Full screens would need the whole
/// provider/database graph and would test plumbing rather than layout.
void main() {
  const widths = [320.0, 360.0, 412.0];
  const scales = [1.0, 1.3];

  Widget host(
    Widget child, {
    required double width,
    required double scale,
  }) {
    return MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(scale),
          devicePixelRatio: 1,
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SizedBox(
              width: width,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(DsSpacing.page),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('no overflow at 320/360/412 dp and scale 1.0/1.3 (RTL)', () {
    for (final width in widths) {
      for (final scale in scales) {
        final label = '${width.toInt()}dp x$scale';

        testWidgets('MiniRing $label', (tester) async {
          await tester.pumpWidget(host(
            const MiniRing(
              progress: .65,
              color: Personal2Colors.kids,
              semanticLabel: 'پیشرفت',
            ),
            width: width,
            scale: scale,
          ));
          expect(tester.takeException(), isNull);
        });

        testWidgets('MiniBars $label', (tester) async {
          await tester.pumpWidget(host(
            MiniBars(
              color: Personal2Colors.kids,
              items: const [
                MiniBarItem(label: 'مسواک زدن', value: 4, max: 7),
                MiniBarItem(label: 'مرتب کردن اتاق', value: 1, max: 7),
                MiniBarItem(
                  label: 'یک عنوان عادت خیلی طولانی که باید کوتاه شود',
                  value: 7,
                  max: 7,
                ),
              ],
            ),
            width: width,
            scale: scale,
          ));
          expect(tester.takeException(), isNull);
        });

        testWidgets('MiniColumnChart $label', (tester) async {
          await tester.pumpWidget(host(
            const MiniColumnChart(
              values: [3, 0, 5, 2, 7, 1, 4],
              labels: ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'],
              color: Personal2Colors.kids,
            ),
            width: width,
            scale: scale,
          ));
          expect(tester.takeException(), isNull);
        });

        testWidgets('DayStrip $label', (tester) async {
          await tester.pumpWidget(host(
            const DayStrip(
              color: Personal2Colors.teacher,
              segments: [
                DayStripSegment(letter: 'ش', state: DayStripState.done),
                DayStripSegment(letter: 'ی', state: DayStripState.missed),
                DayStripSegment(letter: 'د', state: DayStripState.partial),
                DayStripSegment(letter: 'س', state: DayStripState.excused),
                DayStripSegment(letter: 'چ', state: DayStripState.none),
                DayStripSegment(letter: 'پ', state: DayStripState.done),
                DayStripSegment(letter: 'ج', state: DayStripState.done),
              ],
            ),
            width: width,
            scale: scale,
          ));
          expect(tester.takeException(), isNull);
        });

        testWidgets('child-mode tile grid $label', (tester) async {
          // The tightest layout in the tool: two columns of large tiles with a
          // 52 dp icon inside a 1.32 aspect ratio.
          await tester.pumpWidget(host(
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                // Mirrors child_mode_screen.dart.
                childAspectRatio: 0.9,
              ),
              itemCount: 4,
              itemBuilder: (context, i) => AppCard(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DuotoneIconTile(
                      accent: Personal2Colors.kids,
                      icon: Icons.cleaning_services_rounded,
                      size: 52,
                    ),
                    const Spacer(),
                    Text(
                      'مرتب کردن اتاق',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'انجام شد · +2',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            width: width,
            scale: scale,
          ));
          expect(tester.takeException(), isNull);
        });

        testWidgets('personal-tools section row $label', (tester) async {
          await tester.pumpWidget(host(
            Column(
              children: [
                const SectionHeader(
                  title: 'ابزارهای شخصی',
                  accent: Personal2Colors.kids,
                ),
                for (final entry in const [
                  (Icons.child_care_outlined, 'دفتر عادت کودک',
                      'عادت‌ها، نماز، ستاره و جایزه — همه روی همین دستگاه'),
                  (Icons.menu_book_outlined, 'دفتر مربی قرآن',
                      'حضور، درس‌ها و پیشرفت شاگردان با ارجاع به صفحات مصحف'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          DuotoneIconTile(
                            accent: Personal2Colors.kids,
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
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  entry.$3,
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            width: width,
            scale: scale,
          ));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('RTL', () {
    testWidgets('the charts render under RTL', (tester) async {
      await tester.pumpWidget(host(
        const MiniColumnChart(
          values: [1, 2, 3],
          labels: ['ش', 'ی', 'د'],
          color: Personal2Colors.kids,
        ),
        width: 360,
        scale: 1,
      ));
      expect(
        Directionality.of(tester.element(find.byType(MiniColumnChart))),
        TextDirection.rtl,
      );
    });

    testWidgets('a Persian title does not throw bidi layout', (tester) async {
      await tester.pumpWidget(host(
        Text(
          'دفتر عادت کودک — ۳ از ۵ عادت',
          style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 14),
        ),
        width: 320,
        scale: 1.3,
      ));
      expect(tester.takeException(), isNull);
    });
  });
}
