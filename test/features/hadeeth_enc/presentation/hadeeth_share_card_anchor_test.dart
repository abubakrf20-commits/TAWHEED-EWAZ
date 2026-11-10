import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/hadeeth_enc/domain/entities/hadeeth_enc_hadith.dart';
import 'package:tawheeed/features/hadeeth_enc/presentation/screens/hadeeth_enc_detail_screen.dart';
import 'package:tawheeed/features/hadeeth_enc/presentation/widgets/hadeeth_share_card.dart';

const _hadith = HadeethEncHadith(
  id: 1751,
  textAr: 'عن أبي هريرة رضي الله عنه قال',
  text: 'از ابوهریره روایت شده است',
  explanation: 'در این شرح واژهٔ جستجو پیدا می‌شود.',
  benefits: 'نکتهٔ نخست.\nنکتهٔ دوم.',
  grade: '[صحیح]',
  takhrij: '[متفق علیه]',
);

HadeethEncHadith _longHadith() => HadeethEncHadith(
      id: 1,
      textAr: List.filled(10, 'عن أبي هريرة رضي الله عنه قال رسول الله').join(' '),
      text: List.filled(10, 'از ابوهریره روایت شده است که رسول خدا فرمود').join(' '),
      explanation:
          List.filled(10, 'واژهٔ جستجو در این شرح آمده است و ادامه دارد').join(' '),
      benefits: List.filled(6, 'نکته‌ای برای خواننده.').join('\n'),
    );

Widget _card({String query = '', GlobalKey? anchor}) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: HadeethShareCard(
            hadith: _hadith,
            highlightQuery: query,
            matchAnchor: anchor,
            showBranding: false,
          ),
        ),
      ),
    );

String _anchoredText(WidgetTester tester, GlobalKey anchor) {
  final text = tester.widget<Text>(find
      .descendant(of: find.byKey(anchor), matching: find.byType(Text))
      .first);
  return text.textSpan?.toPlainText() ?? text.data ?? '';
}

void main() {
  group('HadeethShareCard matchAnchor', () {
    testWidgets('anchors the first block that carries the query and paints it',
        (tester) async {
      final anchor = GlobalKey();
      await tester.pumpWidget(_card(query: 'جستجو', anchor: anchor));

      expect(find.byKey(anchor), findsOneWidget);
      expect(_anchoredText(tester, anchor), _hadith.explanation);
      // The matched word is shaded: the rich text is split into more than one
      // span (leading text, highlight, trailing text).
      final text = tester.widget<Text>(find
          .descendant(of: find.byKey(anchor), matching: find.byType(Text))
          .first);
      expect((text.textSpan as TextSpan).children!.length, greaterThan(1));
    });

    testWidgets('anchors the Arabic block when the query is Arabic',
        (tester) async {
      final anchor = GlobalKey();
      await tester.pumpWidget(_card(query: 'هريرة', anchor: anchor));

      expect(find.byKey(anchor), findsOneWidget);
      expect(_anchoredText(tester, anchor), _hadith.textAr);
    });

    testWidgets('anchors only once when several blocks carry the query',
        (tester) async {
      final anchor = GlobalKey();
      await tester.pumpWidget(_card(query: 'نکته', anchor: anchor));

      expect(find.byKey(anchor), findsOneWidget);
    });

    testWidgets('no anchor is attached when the query matches nothing',
        (tester) async {
      final anchor = GlobalKey();
      await tester.pumpWidget(_card(query: 'واژهٔنایاب', anchor: anchor));

      expect(find.byKey(anchor), findsNothing);
    });

    testWidgets('no anchor is attached without a query', (tester) async {
      final anchor = GlobalKey();
      await tester.pumpWidget(_card(anchor: anchor));

      expect(find.byKey(anchor), findsNothing);
    });
  });

  group('HadeethEncDetailScreen scroll-to-match', () {
    double offsetOf(WidgetTester tester) => tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;

    testWidgets('opens scrolled to the block carrying the searched word',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: HadeethEncDetailScreen(
          hadith: _longHadith(),
          highlightQuery: 'جستجو',
        ),
      ));
      await tester.pumpAndSettle();

      expect(offsetOf(tester), greaterThan(0));
    });

    testWidgets('starts at the top when no word was searched', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: HadeethEncDetailScreen(hadith: _longHadith()),
      ));
      await tester.pumpAndSettle();

      expect(offsetOf(tester), 0);
    });
  });
}
