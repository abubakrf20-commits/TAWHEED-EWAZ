import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// The flat screen-level tab chrome of the section redesigns — the approved
/// وضو و طهارت reference: a muted track with one hairline border and a SOLID
/// dark selected pill (no gradient, no accent wash behind the tabs, no white
/// label).
///
/// Drop it straight into `AppBar.bottom`; it reports the redesigned sections'
/// shared 48dp slot itself, so no `PreferredSize` is needed at the call site.
/// The screen keeps its own `DefaultTabController` + `TabBarView`. The row
/// scrolls whenever the labels outrun a 320dp phone.
class FlatTabs extends StatelessWidget implements PreferredSizeWidget {
  const FlatTabs({super.key, required this.tabs});

  /// Tab labels, in reading order.
  final List<String> tabs;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.outline, width: .5),
      ),
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.center,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(11),
        indicator: BoxDecoration(
          color: t.primaryStrong,
          borderRadius: const BorderRadius.all(Radius.circular(11)),
        ),
        labelColor: t.heroInk,
        unselectedLabelColor: t.textMuted,
        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
        labelStyle: TextStyle(
            fontSize: AppTheme.scaledFontSize(context, 12),
            fontWeight: FontWeight.w600,
            fontFamily: AppTheme.fontFamily),
        unselectedLabelStyle: TextStyle(
            fontSize: AppTheme.scaledFontSize(context, 12),
            fontWeight: FontWeight.w400,
            fontFamily: AppTheme.fontFamily),
        tabs: [for (final label in tabs) Tab(text: label)],
      ),
    );
  }
}
