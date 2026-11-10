import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/hadeeth_enc/domain/entities/hadeeth_enc_hadith.dart';
import 'package:tawheeed/features/hadeeth_enc/presentation/screens/hadeeth_enc_detail_screen.dart';

void main() {
  const hadith = HadeethEncHadith(
    id: 1751,
    titleAr: 'غسل میت',
    title: 'غسل میت',
    textAr: 'عن أُمّ عَطِيَّةَ قالت: ...',
    text: 'از ام عطیه روایت است که ...',
    explanation: 'شرح کامل حدیث درباره غسل میت.',
    benefits: 'منافع: وجوب غسل میت.',
    grade: '[صحیح است]',
    takhrij: '[متفق علیه]',
    link: 'https://hadeethenc.com/fa/browse/hadith/1751',
  );

  Widget buildApp({String? benefits}) {
    final h = benefits == null
        ? hadith
        : HadeethEncHadith(
            id: hadith.id,
            titleAr: hadith.titleAr,
            title: hadith.title,
            textAr: hadith.textAr,
            text: hadith.text,
            explanation: hadith.explanation,
            benefits: benefits,
            grade: hadith.grade,
            takhrij: hadith.takhrij,
            link: hadith.link,
          );
    return MaterialApp(
      home: HadeethEncDetailScreen(hadith: h),
    );
  }

  testWidgets(
      'renders Arabic, translation, source, grade, explanation in order',
      (tester) async {
    await tester.pumpWidget(buildApp());

    expect(find.text('حدیث 1751'), findsWidgets);
    expect(find.text(hadith.textAr), findsOneWidget);
    expect(find.text(hadith.text), findsOneWidget);
    expect(find.text('ترجمه'), findsOneWidget);
    // منبع و صحت inside the unified card are shown as chips with the raw
    // takhrij/grade text rather than separate labeled sections.
    expect(find.text(hadith.takhrij), findsWidgets);
    expect(find.text(hadith.grade), findsOneWidget);
    expect(find.text('شرح'), findsOneWidget);
    expect(find.text(hadith.explanation), findsOneWidget);
  });

  testWidgets('hides نکات حدیث section when benefits is empty', (tester) async {
    await tester.pumpWidget(buildApp(benefits: ''));
    expect(find.text('نکات حدیث'), findsNothing);
  });

  testWidgets('shows نکات حدیث section when benefits present', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.scrollUntilVisible(find.text('نکات حدیث'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('نکات حدیث'), findsOneWidget);
    expect(find.text(hadith.benefits), findsOneWidget);
  });

  testWidgets('renders each benefits line as a separate bullet',
      (tester) async {
    await tester.pumpWidget(buildApp(benefits: 'اولین نکته.\nدومین نکته.\n'));
    await tester.scrollUntilVisible(find.text('نکات حدیث'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('اولین نکته.'), findsOneWidget);
    expect(find.text('دومین نکته.'), findsOneWidget);
  });

  testWidgets('title and card use the real hadith number (sequence)',
      (tester) async {
    const numbered = HadeethEncHadith(
      id: 1751,
      titleAr: 'غسل میت',
      title: 'غسل میت',
      textAr: 'عن أُمّ عَطِيَّةَ قالت: ...',
      text: 'از ام عطیه روایت است که ...',
      sequence: 42,
    );
    await tester.pumpWidget(const MaterialApp(
      home: HadeethEncDetailScreen(hadith: numbered),
    ));
    await tester.pumpAndSettle();

    expect(find.text('حدیث 42'), findsWidgets);
    // The card header draws its icon through the shared ShareCardHeader —
    // no emoji in the painted title (proposal ۱۴).
    expect(find.text('حدیث شماره 42'), findsWidgets);
  });
}
