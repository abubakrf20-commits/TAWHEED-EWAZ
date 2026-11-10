import 'package:flutter/material.dart';

/// App-wide page transitions for the RTL (Persian) UI.
///
/// Every pushed route in the app (GoRouter pages and the remaining imperative
/// `MaterialPageRoute`s) renders through `MaterialPage`, which delegates its
/// transition to the theme — so one theme-level builder gives the whole app a
/// consistent RTL feel with zero per-route edits.
///
/// A short mirrored slide + fade (the framework mirrors the slide axis for
/// the ambient RTL direction); pop reverses it.
class RtlSlideTransitionsBuilder extends PageTransitionsBuilder {
  const RtlSlideTransitionsBuilder();

  static const Curve _curve = Curves.easeOutCubic;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final slide = Tween<Offset>(
      begin: const Offset(-0.18, 0),
      end: Offset.zero,
    ).chain(CurveTween(curve: _curve)).animate(animation);
    final fade = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.6, curve: Curves.easeOut),
    ));
    return SlideTransition(
      position: slide,
      child: FadeTransition(opacity: fade, child: child),
    );
  }
}

/// Shared theme fragment — referenced by both light and dark ThemeData so
/// pushed routes animate identically in either mode.
const PageTransitionsTheme appPageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: RtlSlideTransitionsBuilder(),
    TargetPlatform.iOS: RtlSlideTransitionsBuilder(),
    TargetPlatform.linux: RtlSlideTransitionsBuilder(),
    TargetPlatform.macOS: RtlSlideTransitionsBuilder(),
    TargetPlatform.windows: RtlSlideTransitionsBuilder(),
    TargetPlatform.fuchsia: RtlSlideTransitionsBuilder(),
  },
);
