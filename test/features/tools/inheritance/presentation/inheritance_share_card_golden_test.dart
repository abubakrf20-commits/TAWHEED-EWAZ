import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/madhab_calculator.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/inheritance_share_card.dart';

void main() {
  // The card stamps the image with today's Jalali date, so an unpinned clock
  // makes this baseline fail the morning after it is recorded.
  late DateTime Function() originalClock;
  setUp(() {
    originalClock = InheritanceShareCard.clockForTest;
    InheritanceShareCard.clockForTest = () => DateTime(2026, 10, 1, 12);
  });
  tearDown(() {
    InheritanceShareCard.clockForTest = originalClock;
  });

  testWidgets('share card golden', (tester) async {
    final result =
        getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
      estate: 12000,
      wife: 1,
      daughter: 2,
    ));

    await tester.binding.setSurfaceSize(const Size(420, 900));
    // The app theme, not a bare `ThemeData`: the card's type now goes through
    // `AppTheme.scaledFontSize`, which reads `bodyMedium` — a bare Material
    // theme leaves it at 14/15 and silently renders the card a step small.
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme(fontFamily: 'Calibri'),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Colors.grey.shade300,
          body: Center(
            child: SizedBox(
              width: 420,
              child: InheritanceShareCard(result: result, estate: 12000),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    await expectLater(
      find.byType(InheritanceShareCard),
      matchesGoldenFile('goldens/share_card_scan.png'),
    );
  });
}
