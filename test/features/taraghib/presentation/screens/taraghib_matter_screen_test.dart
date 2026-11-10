import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/features/taraghib/presentation/screens/taraghib_matter_screen.dart';
import 'package:tawheeed/features/taraghib/services/taraghib_service.dart';

/// Drives the مقدمه/خاتمه reader without a real database.
class _FakeMatterService extends TaraghibService {
  _FakeMatterService({
    this.paragraphs = const <Map<String, dynamic>>[],
    this.footnotes = const <Map<String, dynamic>>[],
    this.failTimes = 0,
  });

  final List<Map<String, dynamic>> paragraphs;
  final List<Map<String, dynamic>> footnotes;
  final int failTimes;
  int openCalls = 0;

  @override
  Future<void> ensureReady() async {
    openCalls++;
    if (openCalls <= failTimes) {
      throw Exception('book locked');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> matterParagraphs(int sectionId) async =>
      paragraphs;

  @override
  Future<List<Map<String, dynamic>>> footnotesOfSection(int sectionId) async =>
      footnotes;
}

const Map<String, dynamic> _introSection = {
  'id': 22,
  'kind': 'intro',
  'title': 'مقدمه',
  'source_title': 'المقدمة',
};

/// Footnote bodies are `SelectableText`, so a plain `find.text` is not the
/// finder to reach for; this one names the widget it expects.
Finder _note(String text) => find.byWidgetPredicate(
      (w) => w is SelectableText && (w.data ?? '').trim() == text,
      description: 'SelectableText("$text")',
    );

Future<void> pumpMatter(
  WidgetTester tester,
  Map<String, dynamic> section,
  TaraghibService service,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
      home: TaraghibMatterScreen(section: section, service: service)));
}

void main() {
  testWidgets('an intro prints its numbered sub-headings as headings',
      (tester) async {
    final fake = _FakeMatterService(paragraphs: const [
      {'arabic': 'بند نخست المقدمة', 'style': null, 'source_para': 0},
      {'arabic': 'الفصل الأول', 'style': 'a8', 'source_para': 1},
      {'arabic': 'بند دوم', 'style': null, 'source_para': 2},
    ]);
    await pumpMatter(tester, _introSection, fake);
    await tester.pumpAndSettle();

    expect(find.text('3 بند'), findsOneWidget);
    expect(find.text('الفصل الأول'), findsOneWidget);
    expect(tester.widget<Text>(find.text('الفصل الأول')).style?.fontWeight,
        FontWeight.w800);
    expect(tester.widget<Text>(find.text('بند دوم')).style?.fontWeight,
        isNot(FontWeight.w800));
    // No section has notes here, so nothing is painted between paragraphs.
    expect(find.byType(SelectableText), findsNothing);
  });

  testWidgets('a footnote sits under the very paragraph that owns it',
      (tester) async {
    final fake = _FakeMatterService(
      paragraphs: const [
        {'arabic': 'بند نخست', 'style': null, 'source_para': 0},
        {'arabic': 'بند دوم', 'style': null, 'source_para': 1},
      ],
      footnotes: const [
        {'text': 'حاشیهٔ نخست بند یکم', 'source_para': 0, 'sort_order': 1},
        {'text': 'حاشیهٔ دوم بند یکم', 'source_para': 0, 'sort_order': 2},
        {'text': 'حاشیهٔ بند دوم', 'source_para': 1, 'sort_order': 3},
        // A note whose paragraph is not in this section must be attached to
        // nothing at all — never floated to the top or the end.
        {'text': 'حاشیهٔ یتیم', 'source_para': 99, 'sort_order': 4},
      ],
    );
    await pumpMatter(tester, _introSection, fake);
    await tester.pumpAndSettle();

    final first = tester.getTopLeft(find.text('بند نخست')).dy;
    final firstNote = tester.getTopLeft(_note('حاشیهٔ نخست بند یکم')).dy;
    final secondNote = tester.getTopLeft(_note('حاشیهٔ دوم بند یکم')).dy;
    final second = tester.getTopLeft(find.text('بند دوم')).dy;
    final secondOwn = tester.getTopLeft(_note('حاشیهٔ بند دوم')).dy;

    expect(first, lessThan(firstNote));
    expect(firstNote, lessThan(secondNote));
    expect(secondNote, lessThan(second));
    expect(second, lessThan(secondOwn));
    expect(_note('حاشیهٔ یتیم'), findsNothing);

    // The print edition restarts the counter on every page, so each owner
    // block numbers its own notes from 1 — never one running number.
    expect(find.text('1'), findsNWidgets(2));
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsNothing);
  });

  testWidgets('copy hands the whole section over, notes under their paragraph',
      (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    final fake = _FakeMatterService(
      paragraphs: const [
        {'arabic': 'المقدمة\tالحمد لله', 'style': null, 'source_para': 0},
        {'arabic': 'بند ثانٍ', 'style': null, 'source_para': 1},
      ],
      footnotes: const [
        {'text': 'حاشية أولى', 'source_para': 0, 'sort_order': 1},
        // A blank body is not a note; it must not add a numbered line.
        {'text': '   ', 'source_para': 1, 'sort_order': 2},
      ],
    );
    await pumpMatter(tester, _introSection, fake);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('کپی متن'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));

    expect(find.text('متن این بخش کپی شد.'), findsOneWidget);
    final set = calls
        .firstWhere((c) => c.method == 'Clipboard.setData')
        .arguments as Map<Object?, Object?>;
    // A tab is a print-edition separator, so it becomes an em dash; the note
    // follows the paragraph it belongs to.
    expect(set['text'], 'المقدمة — الحمد لله\n1. حاشية أولى\n\nبند ثانٍ');
  });

  testWidgets('a failed load names itself, and a retry re-reads the section',
      (tester) async {
    final fake = _FakeMatterService(paragraphs: const [
      {'arabic': 'بند', 'style': null, 'source_para': 0},
    ], failTimes: 1);
    await pumpMatter(tester, _introSection, fake);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('failure_taraghib_matter_load')),
        findsOneWidget);
    expect(find.text('متن این بخش باز نشد'), findsOneWidget);
    // Nothing to copy while the section has not been read.
    expect(find.byTooltip('کپی متن'), findsNothing);
    expect(fake.openCalls, 1);

    await tester.tap(find.text('تلاش دوباره'));
    await tester.pumpAndSettle();

    expect(fake.openCalls, 2);
    expect(find.text('متن این بخش باز نشد.'), findsNothing);
    expect(find.text('بند'), findsOneWidget);
  });

  testWidgets('a section with no paragraphs says so', (tester) async {
    final fake = _FakeMatterService();
    await pumpMatter(tester, _introSection, fake);
    await tester.pumpAndSettle();

    expect(find.text('متنی برای این بخش ثبت نشده است.'), findsOneWidget);
    // With no paragraphs there is nothing to count and nothing to copy.
    expect(find.textContaining('بند'), findsNothing);
    expect(find.byTooltip('کپی متن'), findsNothing);
  });
}
