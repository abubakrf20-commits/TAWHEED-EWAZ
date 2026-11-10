import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/hadeeth_enc/domain/entities/hadeeth_enc_hadith.dart';
import 'package:tawheeed/features/hadeeth_enc/presentation/screens/hadeeth_enc_detail_screen.dart';

void main() {
  testWidgets(
      'detail screen shows translation and source from a full hadith object',
      (tester) async {
    const hadith = HadeethEncHadith(
      id: 1751,
      titleAr: 'عن أُم عَطِيَّةَ...',
      title: 'رسول الله در شستن دخترش...',
      textAr: 'دخل علينا رسول الله صلى الله عليه وسلم...',
      text: 'از ام عطیه روایت است که...',
      explanation: 'شرح کامل حدیث درباره غسل میت.',
      grade: '[صحیح است]',
      takhrij: '[متفق علیه]',
      link: 'https://hadeethenc.com/fa/browse/hadith/1751',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: HadeethEncDetailScreen(hadith: hadith),
      ),
    );
    await tester.pumpAndSettle();

    // The full content must be present — not empty. Inside the unified
    // card, منبع/صحت appear as chips with the raw text (no section labels).
    expect(find.text('ترجمه'), findsOneWidget);
    expect(find.text(hadith.text), findsOneWidget);
    expect(find.text(hadith.takhrij), findsWidgets);
    expect(find.text(hadith.grade), findsOneWidget);
    expect(find.text('شرح'), findsOneWidget);
    expect(find.text(hadith.explanation), findsOneWidget);
  });
}
