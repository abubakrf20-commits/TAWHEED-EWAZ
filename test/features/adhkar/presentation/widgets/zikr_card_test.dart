import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/adhkar/presentation/widgets/zikr_card.dart';
import 'package:tawheeed/features/adhkar/domain/entities/zikr_item.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_selectors.dart';

void main() {
  const sampleZikr = ZikrItem(
    id: '1',
    title: 'Test Zikr',
    arabicText: 'سبحان الله',
    translation: 'Glory to Allah',
    source: 'Quran',
    period: PrayerPeriod.morningAzkar,
    repeatCount: 3,
  );

  const zikrWithDaleel = ZikrItem(
    id: '2',
    title: 'Daleel Zikr',
    arabicText: 'أشهد أن لا إله إلا الله',
    translation: 'I bear witness',
    daleel: 'دلیل از بخاری',
    source: 'Bukhari',
    period: PrayerPeriod.morningAzkar,
  );

  Future<void> pumpCard(
    WidgetTester tester,
    ZikrItem zikr, {
    bool showArabicText = true,
    bool showDaleel = true,
    bool largeArabicFont = false,
    VoidCallback? onToggle,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          showArabicTextProvider.overrideWithValue(showArabicText),
          showDaleelProvider.overrideWithValue(showDaleel),
          largeArabicFontProvider.overrideWithValue(largeArabicFont),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
                child: ZikrCard(
              zikr: zikr,
              index: 0,
              onToggle: onToggle,
            )),
          ),
        ),
      ),
    );
  }

  testWidgets('ZikrCard renders title and arabic text', (tester) async {
    await pumpCard(tester, sampleZikr);
    expect(find.text('Test Zikr'), findsOneWidget);
    expect(find.text('سبحان الله'), findsOneWidget);
  });

  testWidgets('ZikrCard shows completed state', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ZikrCard(zikr: sampleZikr, index: 0, isCompleted: true),
          ),
        ),
      ),
    );
    expect(find.byType(ZikrCard), findsOneWidget);
  });

  testWidgets('ZikrCard calls onToggle when check circle tapped',
      (tester) async {
    var toggled = false;
    await pumpCard(tester, sampleZikr, onToggle: () => toggled = true);
    await tester.tap(find.byIcon(Icons.check_circle_outline).first);
    expect(toggled, isTrue);
  });

  testWidgets('«نمایش متن عربی» off hides the arabic block', (tester) async {
    await pumpCard(tester, sampleZikr, showArabicText: false);
    expect(find.text('سبحان الله'), findsNothing);
    expect(find.text('Glory to Allah'), findsOneWidget);
  });

  testWidgets('«نمایش دلیل» off hides the daleel box', (tester) async {
    await pumpCard(tester, zikrWithDaleel, showDaleel: false);
    expect(find.text('دلیل از بخاری'), findsNothing);

    await pumpCard(tester, zikrWithDaleel);
    expect(find.text('دلیل از بخاری'), findsOneWidget);
  });

  testWidgets('«فونت بزرگ‌تر عربی» enlarges the arabic text', (tester) async {
    double arabicSize(WidgetTester tester) =>
        tester.widget<Text>(find.text('سبحان الله')).style!.fontSize!;

    await pumpCard(tester, sampleZikr);
    final normal = arabicSize(tester);

    await pumpCard(tester, sampleZikr, largeArabicFont: true);
    expect(arabicSize(tester), greaterThan(normal));
  });
}
