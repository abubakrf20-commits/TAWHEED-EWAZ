import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/features/education/presentation/widgets/education_widgets.dart';
import 'package:tawheeed/features/education/presentation/widgets/evidence_section.dart';
import 'package:tawheeed/features/education/presentation/widgets/application_section.dart';
import 'package:tawheeed/features/education/presentation/widgets/common_mistakes_section.dart';
import 'package:tawheeed/features/education/presentation/widgets/related_sciences.dart';
import 'package:tawheeed/features/education/presentation/widgets/study_path_card.dart';
import 'package:tawheeed/features/education/presentation/widgets/term_card.dart';
import 'package:tawheeed/features/education/presentation/widgets/faq_section.dart';
import 'package:tawheeed/features/education/presentation/widgets/science_card.dart';
import 'package:tawheeed/features/education/presentation/widgets/branch_list.dart';
import 'package:tawheeed/features/education/presentation/widgets/education_hero_header.dart';
import 'package:tawheeed/features/education/data/sciences_content.dart';

Widget wrap(Widget w) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: w)));

void main() {
  testWidgets('StepCard renders step info', (tester) async {
    await tester.pumpWidget(wrap(
        const StepCard(stepNumber: 1, title: 'Step 1', body: 'Body text')));
    expect(find.text('Step 1'), findsOneWidget);
    expect(find.text('Body text'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('StepCard shows note and extra', (tester) async {
    await tester.pumpWidget(wrap(const StepCard(
        stepNumber: 2,
        title: 'T',
        body: 'B',
        note: 'Note text',
        extra: 'Extra text')));
    expect(find.text('Note text'), findsOneWidget);
    expect(find.text('Extra text'), findsOneWidget);
  });

  testWidgets('RulingCard renders title and body', (tester) async {
    await tester
        .pumpWidget(wrap(const RulingCard(title: 'Ruling', body: 'Body')));
    expect(find.text('Ruling'), findsOneWidget);
    expect(find.text('Body'), findsOneWidget);
  });

  testWidgets('InfoBox renders text', (tester) async {
    await tester.pumpWidget(wrap(const InfoBox(text: 'Info content')));
    expect(find.text('Info content'), findsOneWidget);
  });

  testWidgets('SectionHeader renders title', (tester) async {
    await tester.pumpWidget(wrap(const SectionHeader(title: 'Header')));
    expect(find.text('Header'), findsOneWidget);
  });

  testWidgets('CategoryListCard renders items', (tester) async {
    await tester.pumpWidget(wrap(const CategoryListCard(
        title: 'Cat', icon: Icons.star, items: ['A', 'B'])));
    expect(find.text('Cat'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('EvidenceSection renders evidence', (tester) async {
    await tester.pumpWidget(
        wrap(const EvidenceSection(evidence: ['Quran 1:1', 'Hadith text'])));
    expect(find.byType(EvidenceSection), findsOneWidget);
  });

  testWidgets('EvidenceSection handles empty list', (tester) async {
    await tester.pumpWidget(wrap(const EvidenceSection(evidence: [])));
    expect(find.byType(EvidenceSection), findsOneWidget);
  });

  testWidgets('ApplicationSection renders application', (tester) async {
    await tester
        .pumpWidget(wrap(const ApplicationSection(application: 'App text')));
    expect(find.text('App text'), findsOneWidget);
  });

  testWidgets('ApplicationSection handles empty', (tester) async {
    await tester.pumpWidget(wrap(const ApplicationSection(application: '')));
    expect(find.byType(ApplicationSection), findsOneWidget);
  });

  testWidgets('CommonMistakesSection renders mistakes', (tester) async {
    await tester.pumpWidget(
        wrap(const CommonMistakesSection(mistakes: ['Mistake text'])));
    expect(find.text('Mistake text'), findsOneWidget);
  });

  testWidgets('RelatedSciencesSection renders', (tester) async {
    await tester.pumpWidget(wrap(
        RelatedSciencesSection(relatedIds: ['tafsir'], onScienceTap: (_) {})));
    expect(find.byType(RelatedSciencesSection), findsOneWidget);
  });

  testWidgets('StudyPathSection renders path', (tester) async {
    await tester
        .pumpWidget(wrap(const StudyPathSection(studyPath: 'Step 1\nStep 2')));
    expect(find.text('Step 1'), findsOneWidget);
    expect(find.text('Step 2'), findsOneWidget);
  });

  testWidgets('TermSection renders terms', (tester) async {
    await tester.pumpWidget(wrap(const TermSection(terms: [
      TermData(term: 'Term', definition: 'Def'),
    ])));
    expect(find.text('Term'), findsOneWidget);
    expect(find.text('Def'), findsOneWidget);
  });

  testWidgets('FaqSection renders and expands', (tester) async {
    await tester.pumpWidget(wrap(const FaqSection(faqs: [
      FaqData(question: 'Q?', answer: 'A.'),
    ])));
    expect(find.text('Q?'), findsOneWidget);
    await tester.tap(find.text('Q?'));
    await tester.pump();
    expect(find.text('A.'), findsOneWidget);
  });

  testWidgets('ScienceCategoryCard renders', (tester) async {
    await tester.pumpWidget(wrap(Material(
        child: ScienceCategoryCard(
      category: ScienceCategory.foundational,
      sciences: const [
        ScienceData(
          id: 'testScience',
          title: 'علم آزمایشی',
          icon: '📘',
          category: ScienceCategory.foundational,
          level: ScienceLevel.beginner,
          definition: 'تعریف',
          importance: 'اهمیت',
          scope: 'گستره',
          subtopics: [],
          keyTerms: [],
          faqs: [],
          relatedSciences: [],
        ),
      ],
      onScienceTap: (_) {},
    ))));
    expect(find.byType(ScienceCategoryCard), findsOneWidget);
  });

  testWidgets(
      'ScienceCategoryCard shows «به‌زودی» badge only for incomplete sciences',
      (tester) async {
    await tester.pumpWidget(wrap(Material(
        child: ScienceCategoryCard(
      category: ScienceCategory.foundational,
      sciences: const [
        ScienceData(
          id: 'incompleteScience',
          title: 'علم ناقص',
          icon: '📘',
          category: ScienceCategory.foundational,
          level: ScienceLevel.beginner,
          definition: 'تعریف',
          importance: 'اهمیت',
          scope: 'گستره',
          subtopics: [],
          keyTerms: [],
          faqs: [],
          relatedSciences: [],
          complete: false,
        ),
        ScienceData(
          id: 'completeScience',
          title: 'علم کامل',
          icon: '📗',
          category: ScienceCategory.foundational,
          level: ScienceLevel.beginner,
          definition: 'تعریف',
          importance: 'اهمیت',
          scope: 'گستره',
          subtopics: [],
          keyTerms: [],
          faqs: [],
          relatedSciences: [],
          chapters: [
            ChapterData(title: 'فصل اول', body: 'متن'),
          ],
        ),
      ],
      onScienceTap: (_) {},
    ))));
    // Only the incomplete science gets the badge.
    expect(find.text('به‌زودی'), findsOneWidget);
    expect(find.text('علم ناقص'), findsOneWidget);
    expect(find.text('علم کامل'), findsOneWidget);
  });

  testWidgets('BranchList renders subtopics', (tester) async {
    await tester
        .pumpWidget(wrap(const BranchList(subtopics: ['Topic 1', 'Topic 2'])));
    expect(find.text('Topic 1'), findsOneWidget);
    expect(find.text('Topic 2'), findsOneWidget);
  });

  testWidgets('EducationHeroHeader renders info', (tester) async {
    await tester.pumpWidget(wrap(const EducationHeroHeader(
      title: 'Title',
      subtitle: 'Sub',
      icon: Icons.star,
      accentColor: Colors.blue,
    )));
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Sub'), findsOneWidget);
  });
}
