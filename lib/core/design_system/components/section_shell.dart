import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/page_header.dart';

/// The chrome every section page re-typed by hand: a transparent [Scaffold],
/// the slim [PageHeader], and the body shape around them.
///
/// It paints **no** ambient background and adds **no** [SafeArea]:
///
/// * the ambient is already single-sourced at the root — `MaterialApp.router`'s
///   builder wraps every route in one (`main.dart`), so a second layer would
///   double the glow;
/// * the tab shell already sits inside a `SafeArea` (`main_shell.dart`), so a
///   page inside the shell must not add another.
///
/// Two shapes cover every tab:
///
/// * [SectionShell.list] — a scrolling page whose header rides inside the list
///   as its first child, so it leaves with the content (the tab pages' pattern
///   since the 56dp AppBar was retired, 2026-10-14). An [onRefresh] wraps the
///   list in a [RefreshIndicator].
/// * [SectionShell.fixed] — a page whose header stays put and whose [child]
///   fills the rest (a column of tabs, a chart, a single widget).
class SectionShell extends StatelessWidget {
  /// A scrolling page: header first inside the list, then [children].
  const SectionShell.list({
    super.key,
    required this.title,
    this.actions = const [],
    this.headerPadding,
    this.padding = EdgeInsets.zero,
    this.onRefresh,
    this.children = const [],
  }) : child = null;

  /// A fixed page: header on top, [child] filling the remaining height.
  const SectionShell.fixed({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.headerPadding,
  })  : padding = EdgeInsets.zero,
        onRefresh = null,
        children = const [];

  final String title;
  final List<Widget> actions;

  /// Handed straight to [PageHeader]; `null` keeps its shared page inset.
  final EdgeInsetsGeometry? headerPadding;

  /// `SectionShell.list` only — the list's own inset. Pages whose header keeps
  /// its content-level padding (no horizontal inset of its own) put the page
  /// gutter here instead, so the whole list scrolls edge to edge under it.
  final EdgeInsetsGeometry padding;

  /// `SectionShell.list` only — pull-to-refresh around the list.
  final Future<void> Function()? onRefresh;

  /// `SectionShell.list` only — the page content under the header.
  final List<Widget> children;

  /// `SectionShell.fixed` only — the page content under the header.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final header =
        PageHeader(title: title, padding: headerPadding, actions: actions);

    final Widget body;
    if (child != null) {
      body = Column(children: [header, Expanded(child: child!)]);
    } else {
      final list = ListView(
        padding: padding,
        children: [header, ...children],
      );
      final refresh = onRefresh;
      body = refresh == null
          ? list
          : RefreshIndicator(onRefresh: refresh, child: list);
    }

    return Scaffold(backgroundColor: Colors.transparent, body: body);
  }
}
