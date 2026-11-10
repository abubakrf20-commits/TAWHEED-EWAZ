import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/design_system/components/tab_intro_card.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/features/education/data/sciences_content.dart';
import 'package:tawheeed/features/education/presentation/screens/science_detail_screen.dart';
import 'package:tawheeed/features/education/presentation/screens/sciences_home_screen.dart';
import 'package:tawheeed/features/education/presentation/widgets/branch_list.dart';
import 'package:tawheeed/features/education/presentation/widgets/chapters_section.dart';
import 'package:tawheeed/features/education/presentation/widgets/evidence_section.dart';
import 'package:tawheeed/features/education/presentation/widgets/related_sciences.dart';
import 'package:tawheeed/features/education/presentation/widgets/term_card.dart';

/// The flat-design contract of علوم اسلامی: every science wears its own
/// category hue inside (no module indigo), the intro is the shared
/// [TabIntroCard] recipe, and the search rows lead with the category duotone
/// glyph instead of the per-item emoji.
Widget app(Widget home) => MaterialApp(
      home: Directionality(textDirection: TextDirection.rtl, child: home),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await SciencesContent.load();
  });

  testWidgets('a science wears its own category accent inside', (tester) async {
    final history = SciencesContent.byId('islamicHistory')!;
    expect(history.category, ScienceCategory.historical);
    final accent = SciencesContent.accentOf(history.category);

    await tester.pumpWidget(app(ScienceDetailScreen(scienceId: history.id)));
    await tester.pumpAndSettle();

    // The intro card is the shared flat recipe and carries the category hue.
    final intro = tester.widget<TabIntroCard>(find.byType(TabIntroCard));
    expect(intro.accent, accent);
    expect(intro.icon, SciencesContent.glyphOf(history.category));
    expect(intro.title, history.title);

    // The chapter section header no longer wears the module indigo.
    expect(tester.widget<ChaptersSection>(find.byType(ChaptersSection)).accent,
        accent);

    await tester.scrollUntilVisible(find.byType(RelatedSciencesSection), 600);
    expect(
        tester
            .widget<RelatedSciencesSection>(find.byType(RelatedSciencesSection))
            .accent,
        accent);
  });

  testWidgets(
      'the coming-soon banner and the sections wear the category accent',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final draft = SciencesContent.byId('shafiiMadhhab')!;
    expect(draft.isComplete, isFalse);
    final accent = SciencesContent.accentOf(draft.category);

    await tester.pumpWidget(app(ScienceDetailScreen(scienceId: draft.id)));
    await tester.pumpAndSettle();

    final hourglass = tester.widget<Icon>(find.byIcon(Icons.hourglass_top));
    expect(hourglass.color, accent,
        reason: 'the coming-soon banner wears the category accent');

    expect(tester.widget<EvidenceSection>(find.byType(EvidenceSection)).accent,
        accent);
    expect(tester.widget<BranchList>(find.byType(BranchList)).accent, accent);
    expect(tester.widget<TermSection>(find.byType(TermSection)).accent, accent);
    expect(
        tester
            .widget<RelatedSciencesSection>(find.byType(RelatedSciencesSection))
            .accent,
        accent);
  });

  testWidgets('the hub AppBar and the search rows follow the flat recipe',
      (tester) async {
    await tester.pumpWidget(app(const SciencesHomeScreen()));
    await tester.pumpAndSettle();

    // AppBar title: the shared 16 / w500 recipe (was raw w700).
    final title = tester.widget<Text>(find.text('علوم اسلامی'));
    expect(title.style?.fontWeight, FontWeight.w500);
    expect(title.style?.fontSize,
        AppTheme.scaledFontSize(tester.element(find.text('علوم اسلامی')), 16));

    await tester.tap(find.byIcon(Icons.search).first);
    await tester.pumpAndSettle();

    // Search rows now lead with the category duotone tile, not the emoji.
    final first = SciencesContent.all.first;
    final tiles = tester
        .widgetList<DuotoneIconTile>(find.byType(DuotoneIconTile))
        .toList();
    expect(tiles, isNotEmpty);
    expect(tiles.first.accent, SciencesContent.accentOf(first.category));
    expect(find.text(first.icon), findsNothing);
  });

  test('no per-science emoji is drawn anywhere in the section', () {
    for (final path in const [
      'lib/features/education/presentation/screens/sciences_home_screen.dart',
      'lib/features/education/presentation/screens/science_detail_screen.dart',
      'lib/features/education/presentation/widgets/science_card.dart',
      'lib/features/education/presentation/widgets/related_sciences.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src, isNot(contains('Text(s.icon')),
          reason: '$path still draws the per-item emoji');
    }
  });
}
