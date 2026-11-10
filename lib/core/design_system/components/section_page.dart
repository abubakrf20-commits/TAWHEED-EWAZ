import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/flat_tabs.dart';
import 'package:tawheeed/core/design_system/components/remembered_tabs.dart';
import 'package:tawheeed/core/design_system/components/section_app_bar.dart';
import 'package:tawheeed/core/design_system/components/section_search.dart';

/// The chrome of a tabbed section page, in one place.
///
/// WHY this exists: nine pages — نماز، روزه، زکات، میراث، وضو، حج، رقیه، دعا،
/// ماه — each re-typed the same four decisions by hand:
///
/// 1. `Scaffold(backgroundColor: Colors.transparent)`, because the route is
///    already wrapped in an `AmbientBackground` and the theme's scaffold colour
///    is opaque;
/// 2. `AppBar` with `elevation: 0` **and** `scrolledUnderElevation: 0`, because
///    Material 3 tints a scrolled-under bar with the surface colour and that
///    reads as a flat band cutting the gradient in two;
/// 3. the title style — 16dp, w500, `t.primary`, centred;
/// 4. `FlatTabs` in its 48dp slot.
///
/// Two of the nine had already drifted on (2) — روزه and وضو shipped without the
/// elevation pins, so their app bar grew a band the moment a list scrolled under
/// it, and no test noticed because each page tested its own copy of the chrome.
/// Nothing about that is a content decision: it is the same answer nine times.
/// Owning it here makes the drift impossible rather than merely unlikely.
///
/// The page keeps its own content: [children] is the `TabBarView` body, one per
/// entry in [tabs]. [header] covers the one page (ماه و منازل) that needs a band
/// between the tab strip and the views — a date selector shared by all four.
class SectionPage extends StatelessWidget {
  const SectionPage({
    super.key,
    required this.id,
    required this.title,
    required this.tabs,
    required this.children,
    this.header,
    this.actions = const [],
    this.searchEntries,
  })  : assert(
          tabs.length == children.length,
          'SectionPage: tabs and children must be the same length',
        ),
        assert(
          tabs.length > 0,
          'SectionPage: a tabbed page needs at least one tab',
        );

  /// Storage namespace for the remembered tab, e.g. `'zakat'`.
  ///
  /// Passed straight to [RememberedTabs], so the section reopens on the tab the
  /// reader left.
  final String id;

  /// App-bar title. Also the name the in-section search reports.
  final String title;

  /// Tab labels, in reading order.
  final List<String> tabs;

  /// One `TabBarView` page per tab.
  final List<Widget> children;

  /// An optional band pinned above the tab views and below the tab strip.
  final Widget? header;

  /// Extra app-bar actions, placed after the search action.
  final List<Widget> actions;

  /// The page's own searchable index.
  ///
  /// When supplied, a search action appears in the app bar and a hit switches
  /// to the tab it names. When null the action is absent rather than dead — a
  /// search button that opens onto nothing is worse than no button.
  final List<SectionSearchEntry>? searchEntries;

  @override
  Widget build(BuildContext context) {
    final entries = searchEntries;

    return RememberedTabs(
      id: id,
      length: tabs.length,
      child: Scaffold(
        // The route is wrapped in AmbientBackground; an opaque scaffold would
        // cover it and leave the page on a flat slab of colour.
        backgroundColor: Colors.transparent,
        // The tab page's bar and the pushed page's bar are the same six
        // decisions; this page used to type them a fourth time. [SectionAppBar]
        // is that answer, and the only thing this page adds is the tab strip.
        appBar: SectionAppBar(
          title: title,
          actions: [
            if (entries != null)
              SectionSearchAction(sectionTitle: title, entries: entries),
            ...actions,
          ],
          bottom: FlatTabs(tabs: tabs),
        ),
        body: header == null
            ? TabBarView(children: children)
            : Column(
                children: [
                  header!,
                  Expanded(child: TabBarView(children: children)),
                ],
              ),
      ),
    );
  }
}
