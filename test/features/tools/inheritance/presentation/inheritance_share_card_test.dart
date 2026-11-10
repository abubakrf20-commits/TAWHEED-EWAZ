import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/design_system/components/share_card_shell.dart';
import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/domain/madhab_calculator.dart';
import 'package:tawheeed/features/tools/inheritance/presentation/widgets/inheritance_share_card.dart';
import 'package:tawheeed/shared/services/share_service.dart';

void main() {
  testWidgets('share card shows header, summary and heir rows', (tester) async {
    final result =
        getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
      estate: 12000,
      wife: 1,
      daughter: 2,
    ));

    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SingleChildScrollView(
            child: InheritanceShareCard(result: result, estate: 12000),
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('نتایج تقسیم میراث'), findsOneWidget);
    expect(find.textContaining('جمهور'), findsOneWidget);
    expect(find.textContaining('همسر'), findsWidgets);
    expect(find.textContaining('دختر'), findsWidgets);
    // The mark beside a dash-free signature — the text share keeps the dash.
    expect(find.text(ShareService.signatureLine('میراث')), findsOneWidget);
    expect(find.text(ShareService.appLine('میراث')), findsNothing);
    final logo = tester.widget<Image>(find.byType(Image));
    expect(logo.image, ShareCardLogo.providerFor(ShareCardLogo.defaultSize));
    expect(logo.height, ShareCardLogo.defaultSize);
    expect(find.text('اصل مسأله: 24'), findsOneWidget); // همسر + دو دختر
    expect(find.textContaining('جمع سهمها'), findsOneWidget);
    expect(find.text('فرض'), findsWidgets); // نوع سهم روی هر ردیف
  });

  testWidgets('share card percents add to exactly 100 (Hare rounding)',
      (tester) async {
    // 1/8 + 2/3: per-row .round() prints 13٪ + 88٪ = 101٪. The rows follow
    // result.shares order (daughters before the spouse), so the assertion is
    // on the pair and its sum, not on which heir comes first.
    final result =
        getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
      estate: 12000,
      wife: 1,
      daughter: 2,
    ));

    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SingleChildScrollView(
            child: InheritanceShareCard(result: result, estate: 12000),
          ),
        ),
      ),
    ));
    await tester.pump();

    final percents = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((s) => s.endsWith('٪'))
        .map((s) => int.parse(s.substring(0, s.length - 1)))
        .toList();
    expect(percents.length, result.shares.length);
    expect(percents, containsAll([12, 88]));
    expect(percents.fold<int>(0, (a, b) => a + b), 100);
  });

  testWidgets('share card shows the asl strip with عول', (tester) async {
    final result =
        getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
      estate: 1300,
      husband: 1,
      mother: 1,
      fullSister: 2,
    ));

    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SingleChildScrollView(
            child: InheritanceShareCard(result: result, estate: 1300),
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('اصل مسأله: 6'), findsOneWidget);
    expect(find.textContaining('پس از عول: 8'), findsOneWidget);
  });

  testWidgets('share card shows the reason under each heir', (tester) async {
    final result =
        getCalculator(Madhab.jumhur).calculate(const InheritanceInput(
      estate: 12000,
      wife: 1,
      daughter: 2,
    ));

    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SingleChildScrollView(
            child: InheritanceShareCard(result: result, estate: 12000),
          ),
        ),
      ),
    ));
    await tester.pump();

    for (final s in result.shares) {
      if (s.reason.isNotEmpty) {
        expect(find.text(s.reason), findsOneWidget);
      }
    }
  });
}
