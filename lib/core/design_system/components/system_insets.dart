import 'package:flutter/material.dart';

/// Lifts a Scaffold [floatingActionButton] above the system navigation bar.
///
/// On 3-button phones the bar is an overlay (~48dp): a bare FAB sits 16dp
/// above the screen edge, i.e. behind the buttons and untappable.
///
/// Pass `MediaQuery.paddingOf(context).bottom` from the page's own build
/// context (above the Scaffold) as [inset]. This MUST stay a plain [Padding]
/// with a caller-side value — never a SafeArea/MediaQuery read inside: the
/// Scaffold strips every MediaQuery padding around the FAB slot
/// (`removeLeft/Top/Right/BottomPadding: true`), so an inner SafeArea always
/// sees zero and can never work there.
///
/// The value is the live inset, so gesture/hardware-key phones (inset zero)
/// stay pixel-identical — never a hardcoded bottom margin.
class InsetFab extends StatelessWidget {
  const InsetFab({super.key, required this.inset, required this.child});

  /// `MediaQuery.paddingOf(context).bottom` from the page's build context.
  final double inset;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: child,
    );
  }
}
