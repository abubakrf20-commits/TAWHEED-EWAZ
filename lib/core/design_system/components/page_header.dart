import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/tokens.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// The tab pages' slim page header — the replacement for the 56dp [AppBar]
/// every top-level tab used to wear (user request, 2026-10-14: «بالای تب‌ها
/// زیادی جا گرفتند»).
///
/// One 40dp row: the page title at 14sp/w600 **centred** on the page and the
/// page's actions on the END side as compact 20dp glyphs. The title is centred
/// like the [AppBar] titles it replaced (user request, 2026-10-23: «عنوان تب
/// که بالا هست وسط نوشه بشود نه سمت راست»), but without the 56dp bar or the
/// 20sp/w700 face — this is a quiet page label, not a bar.
///
/// Pages whose body scrolls should put it *inside* their scrollable (as the
/// first child) so it leaves with the content; pages whose body is a tab view
/// keep it fixed at the top. It renders nothing but the row — the caller owns
/// the side padding, so it lines up with that page's own content inset.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.actions = const [],
    this.padding,
  });

  final String title;
  final List<Widget> actions;

  /// Padding around the row. Defaults to the shared page inset on both sides
  /// and no vertical padding — the 40dp row already centres the 14sp title
  /// with ~10dp of air above and below it.
  final EdgeInsetsGeometry? padding;

  /// The row's height: one 40dp line. A [PageAction]'s tap target is 40dp, so
  /// it fills the row exactly.
  static const double height = 40;

  /// The gap between two action slots.
  static const double _actionGap = 2;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: padding ??
          const EdgeInsetsDirectional.fromSTEB(
              DsSpacing.page, 0, DsSpacing.page, 0),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            // Mirror the action block on the leading side. Equal gutters make
            // the Expanded title's centre the ROW's centre, so the title sits
            // on the page centre line — not merely centred in whatever space
            // the actions left over.
            if (actions.isNotEmpty)
              SizedBox(width: actions.length * (height + _actionGap)),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.scaledFontSize(context, 14),
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                  ),
                ),
              ),
            ),
            for (final action in actions) ...[
              const SizedBox(width: _actionGap),
              // One fixed slot per action, so the leading gutter above is an
              // exact mirror even if an action is not a [PageAction].
              SizedBox(width: height, height: height, child: action),
            ],
          ],
        ),
      ),
    );
  }
}

/// The compact action button [PageHeader] expects: a 20dp glyph in a 40dp tap
/// target (the AppBar's icon was 24dp in 48), so the row stays 40dp tall.
///
/// The glyph defaults to the page accent — the colour the calendar and adhkar
/// bars already tinted their actions with.
class PageAction extends StatelessWidget {
  const PageAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      iconSize: 20,
      color: color ?? t.primary,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(
        width: PageHeader.height,
        height: PageHeader.height,
      ),
    );
  }
}
