import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/design_system/components/app_card.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/design_system/components/section_header.dart';
import 'package:tawheeed/core/design_system/components/tokens.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/personal2/shop/domain/shop_domain.dart';

/// Goldens for the shop tool's shared visual language — day + night presets,
/// with Vazirmatn loaded so the Persian shaping is real (same recipe as the
/// personal2 goldens).
///
/// The screens need the provider/database graph; these pin the pieces every
/// screen is built from: the teal hero, the stat cards, the POS cart row with
/// a fractional quantity, and the customer balance chips.
void main() {
  const kinds = <ThemeKind>[ThemeKind.day, ThemeKind.night];

  setUpAll(() async {
    final loader = FontLoader('Vazirmatn')
      ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'));
    await loader.load();
    AppTheme.fontFamily = 'Vazirmatn';
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

  /// The dashboard's hero + stat cards + alert row.
  Widget _dot(String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 10,
              color: Colors.white.withValues(alpha: .85),
            ),
          ),
        ],
      );

  Widget _stat(String label, String value, Color color, IconData icon) =>
      AppCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            DuotoneIconTile(accent: color, icon: icon, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily, fontSize: 11),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _alert(String text, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12),
              ),
            ),
          ],
        ),
      );

  /// The POS cart row with a fractional quantity (0.333 kg) and a customer
  /// balance chip — the tightest layout in the tool.
  Widget dashboardSheet() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0B3F45),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'فروش امروز',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: .8),
                  ),
                ),
                Text(
                  '۱٬۲۴۵٬۰۰۰',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '۸ فاکتور · ۱۴۰۴/۰۸/۱۲',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: .75),
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child: Row(
                      children: const [
                        Expanded(
                            flex: 50,
                            child: ColoredBox(
                                color: Color(0xFF2E8B3D))),
                        Expanded(
                            flex: 30,
                            child: ColoredBox(
                                color: Color(0xFF2F6FB5))),
                        Expanded(
                            flex: 20,
                            child: ColoredBox(
                                color: Color(0xFFC9462C))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _dot('نقد', const Color(0xFF2E8B3D)),
                    const SizedBox(width: 10),
                    _dot('کارت', const Color(0xFF2F6FB5)),
                    const SizedBox(width: 10),
                    _dot('نسیه', const Color(0xFFC9462C)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _stat('طلب مشتریان', '۳٬۲۰۰٬۰۰۰',
                    const Color(0xFF2E8B3D), Icons.receipt_long_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _stat('موجودی کم', '۴',
                    const Color(0xFFC9462C), Icons.warning_amber_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                _alert('۲ مشتری با بدهی بیش از ۳۰ روز',
                    const Color(0xFFC9462C)),
                _alert('کم‌موجودی: چای احمد', const Color(0xFFD9922B)),
              ],
            ),
          ),
        ],
      );

  Widget posCartSheet() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
              title: 'سبد فروش', accent: Color(0xFF0E7C86)),
          AppCard(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'چای احمد',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '۲۵۰٬۰۰۰ × 0.333 عدد',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '۸۳٬۳۳۳',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'قابل پرداخت',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily, fontSize: 11),
                      ),
                      Text(
                        '۸۳٬۳۰۰',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0E7C86),
                  ),
                  onPressed: () {},
                  child: Text(
                    'ثبت فروش',
                    style: TextStyle(fontFamily: AppTheme.fontFamily),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  /// The customers list row with debtor/creditor chips.
  Widget customersSheet() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
              title: 'مشتریان', accent: Color(0xFF0E7C86)),
          AppCard(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                      color: Color(0xFF0E7C86), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(
                    'ح',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'حاج رضا',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '۰۹۱۲',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0x142E8B3D),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'بدهکار ۵۰۰٬۰۰۰',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2E8B3D),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          AppCard(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                      color: Color(0xFF0E7C86), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(
                    'م',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'مشتری بستانکار',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0x142F6FB5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'بستانکار ۱۲۰٬۰۰۰',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2F6FB5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  group('shop goldens', () {
    for (final kind in kinds) {
      final suffix = kind.name;

      testWidgets('dashboard $suffix', (tester) async {
        AppTheme.applyTheme(kind: kind, phase: TimePhase.day);
        tester.view.physicalSize = const Size(400, 950);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(app(kind, dashboardSheet()));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/shop_dashboard_$suffix.png'),
        );
      });

      testWidgets('pos cart $suffix', (tester) async {
        AppTheme.applyTheme(kind: kind, phase: TimePhase.day);
        tester.view.physicalSize = const Size(400, 480);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(app(kind, posCartSheet()));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/shop_pos_cart_$suffix.png'),
        );
      });

      testWidgets('customers $suffix', (tester) async {
        AppTheme.applyTheme(kind: kind, phase: TimePhase.day);
        tester.view.physicalSize = const Size(400, 560);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(app(kind, customersSheet()));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/shop_customers_$suffix.png'),
        );
      });
    }
  });

  group('layout guards (320/360/412 × scale 1.0/1.3, RTL)', () {
    const widths = [320.0, 360.0, 412.0];
    const scales = [1.0, 1.3];

    Widget host(Widget child,
        {required double width, required double scale}) {
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

    for (final width in widths) {
      for (final scale in scales) {
        testWidgets('dashboard pieces ${width.toInt()}dp x$scale',
            (tester) async {
          await tester.pumpWidget(host(
            dashboardSheet(),
            width: width,
            scale: scale,
          ));
          expect(tester.takeException(), isNull);
        });

        testWidgets('pos cart row ${width.toInt()}dp x$scale',
            (tester) async {
          await tester.pumpWidget(host(
            posCartSheet(),
            width: width,
            scale: scale,
          ));
          expect(tester.takeException(), isNull);
        });

        testWidgets('customer rows ${width.toInt()}dp x$scale',
            (tester) async {
          await tester.pumpWidget(host(
            customersSheet(),
            width: width,
            scale: scale,
          ));
          expect(tester.takeException(), isNull);
        });
      }
    }

    test('the rounding used by the POS payable bar is the documented one', () {
      // 0.333 kg × 250,000 = 83,250 → step 100 → 83,300 (adj +50).
      final line = lineTotalOf(qtyMilli: 333, unitPrice: 250000);
      expect(line, 83250);
      expect(roundingAdjustment(line, 100), 50);
    });
  });
}
