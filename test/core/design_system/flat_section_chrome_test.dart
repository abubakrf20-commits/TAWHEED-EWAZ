import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tawheeed/core/design_system/components/components.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// Guards the two shared chrome pieces of the section redesigns (the وضو و
/// طهارت reference): the flat tab chrome and the tab-opening intro card.
/// [TimeThemeKit.of] falls back to the gold palette on a plain MaterialApp,
/// so the colour assertions below resolve against [AppPalettes.goldLight].
void main() {
  testWidgets('FlatTabs wears the approved flat chrome in the AppBar slot',
      (tester) async {
    const tabs = FlatTabs(tabs: ['آشنایی', 'آموزش', 'احکام']);
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(bottom: tabs),
            body: const TabBarView(
              children: [Text('one'), Text('two'), Text('three')],
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    // The 48dp slot the redesigned sections share, reported by the widget
    // itself — no PreferredSize wrapper at the call site.
    expect(tabs.preferredSize, const Size.fromHeight(48));

    // One track: the muted surface with a single hairline outline, radius 14.
    final track = tester.widget<Container>(find.descendant(
      of: find.byType(FlatTabs),
      matching: find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).color ==
              AppPalettes.goldLight.surfaceAlt),
    ));
    final decoration = track.decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(14));
    final border = decoration.border! as Border;
    expect(border.top.color, AppPalettes.goldLight.outline);
    expect(border.top.width, .5);

    // The labels ride the solid dark pill — not an accent wash behind tabs.
    final bar = tester.widget<TabBar>(find.byType(TabBar));
    expect(bar.isScrollable, isTrue);
    expect(bar.tabAlignment, TabAlignment.center);
    expect(bar.dividerColor, Colors.transparent);
    expect(bar.labelColor, AppPalettes.goldLight.heroInk);
    expect(bar.unselectedLabelColor, AppPalettes.goldLight.textMuted);
    final indicator = bar.indicator! as BoxDecoration;
    expect(indicator.color, AppPalettes.goldLight.primaryStrong);
    expect(indicator.borderRadius, BorderRadius.circular(11));

    // Every label renders, and the row really drives the view.
    for (final label in ['آشنایی', 'آموزش', 'احکام']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('احکام'));
    await tester.pumpAndSettle();
    expect(find.text('three'), findsOneWidget);
  });

  testWidgets('TabIntroCard carries title+subtitle as one two-line text block',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: TabIntroCard(
            icon: Icons.mosque,
            accent: TopicHues.prayer,
            title: 'آشنایی با نماز',
            subtitle: 'شناخت جایگاه و اهمیت نماز — طبق مذهب شافعی',
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(find.byType(AppCard), findsOneWidget);
    expect(find.byType(DuotoneIconTile), findsOneWidget);
    final text = tester.widget<Text>(find
        .text('آشنایی با نماز\nشناخت جایگاه و اهمیت نماز — طبق مذهب شافعی'));
    expect(text.textDirection, TextDirection.rtl);
    expect(text.style?.color, AppPalettes.goldLight.textPrimary);
  });

  testWidgets('TabIntroCard without subtitle renders the bare title',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: TabIntroCard(
            icon: Icons.auto_awesome,
            accent: TopicHues.prayer,
            title: 'ارکان، واجبات، سنن، مکروهات و مبطلات نماز',
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(
        find.text('ارکان، واجبات، سنن، مکروهات و مبطلات نماز'), findsOneWidget);
  });
}
