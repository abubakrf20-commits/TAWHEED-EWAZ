import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// The app bar of a *pushed* page — the sibling of [SectionPage]'s bar.
///
/// WHY this exists: [SectionPage] owns the chrome of the nine tabbed sections,
/// and [SectionShell] owns the header of a tab that has no app bar at all. The
/// third shape — a page pushed onto the stack, with a back arrow and a title —
/// had no owner, so eighty-four files re-typed the same six decisions:
///
/// 1. `backgroundColor: Colors.transparent`, because the route is already
///    wrapped in an `AmbientBackground` and the theme's scaffold colour is
///    opaque;
/// 2. `elevation: 0` **and** `scrolledUnderElevation: 0`, because Material 3
///    tints a scrolled-under bar with the surface colour, and over the ambient
///    gradient that is a visible band cutting the glow in two;
/// 3. `centerTitle: true`;
/// 4. `foregroundColor` and `iconTheme` from the time-theme palette, so the
///    back arrow is the same ink as the title;
/// 5. the title style — 16dp, w500, `palette.primary`, the app font;
/// 6. `actions` in the app's own order.
///
/// Only (6) is a content decision. The rest is one answer retyped, and by the
/// time this was written it had drifted: titles at w500 and w700, bars whose
/// elevation pins were missing so they grew a band the moment a list scrolled
/// under them, and bars with no `centerTitle` at all. `study_screen` had three
/// copies inside a single file.
///
/// Two knobs are kept because they are content, not styling:
///
/// * [titleWidget] — the library's search mode puts a `TextField` where the
///   title was, and that is a different thing to draw, not a different style;
/// * [bottom] — a bar that carries a strip (tabs, a segmented control) needs
///   its height accounted for, and `preferredSize` cannot guess it.
class SectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SectionAppBar({
    super.key,
    required this.title,
    this.titleWidget,
    this.actions = const [],
    this.bottom,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.toolbarHeight,
    this.accent,
  });

  /// The identity hue of the section the page belongs to.
  ///
  /// `null` keeps the app's theme accent, which is right for a generic page.
  /// A tool page whose cards, chips and buttons are painted in its own hue
  /// passes it here, so the back arrow and the title are the SAME ink as the
  /// elements below them instead of the theme's accent over a foreign hue.
  final Color? accent;

  /// The bar's title, and the name a screen reader announces.
  ///
  /// Still required when [titleWidget] is passed: the widget is what is drawn,
  /// the string is what the page *is*.
  final String title;

  /// Drawn instead of the title text — a search field, a date, a chip row.
  final Widget? titleWidget;

  final List<Widget> actions;

  /// A strip under the bar. Its height is added to [preferredSize].
  final PreferredSizeWidget? bottom;

  /// Overrides the implied back button. `null` keeps Material's default, which
  /// is the arrow on a pushed route and nothing on a root one.
  final Widget? leading;

  final bool automaticallyImplyLeading;

  final double? toolbarHeight;

  @override
  Size get preferredSize => Size.fromHeight(
        (toolbarHeight ?? kToolbarHeight) + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    final ink = accent ?? t.primary;
    return AppBar(
      backgroundColor: Colors.transparent,
      // Material 3 tints the bar with the surface colour; over the ambient
      // gradient that tint is a band, so it is pinned here as well as the
      // elevations. `SectionPage` had this pin and this component did not —
      // which is how a "single" component quietly kept two behaviours.
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      foregroundColor: ink,
      iconTheme: IconThemeData(color: ink),
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      toolbarHeight: toolbarHeight,
      title: titleWidget ??
          Text(
            title,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: AppTheme.scaledFontSize(context, 16),
              fontWeight: FontWeight.w500,
              color: ink,
            ),
          ),
      actions: actions,
      bottom: bottom,
    );
  }
}
