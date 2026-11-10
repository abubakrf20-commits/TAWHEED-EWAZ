import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/tokens.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// The redesign's section header: a 4x18 accent bar, the title in 14px w500
/// ink, an optional count chip (page-bg fill, 11px), an optional muted
/// description under the title (10.5px, 12dp inset), and an optional
/// trailing widget (share icon, «همه» link, …).
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.count,
    this.description,
    this.trailing,
    this.margin,
    this.accent,
  });

  final String title;

  /// Count chip text, already formatted by the caller (digits setting).
  final String? count;

  /// Optional muted description under the title, inset past the accent bar.
  final String? description;
  final Widget? trailing;
  final EdgeInsetsGeometry? margin;

  /// Optional identity hue for the bar (a section's own colour). Defaults to
  /// the current theme's [AppPalette.accent], so a header can never paint the
  /// brand gold on a blue/teal/night page.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return Padding(
      padding: margin ?? const EdgeInsets.only(bottom: DsSpacing.rowGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: accent ?? t.accent,
                ),
              ),
              const SizedBox(width: 8),
              // Title + count live in ONE Expanded as a scale-down group: the
              // title keeps its intrinsic width and the trailing stays pinned
              // to the row end. When the two together outrun the free space
              // (the prayer header's period chip at 320dp × 1.3 text) the
              // group scales down uniformly instead of overflowing — the chip
              // can never starve the title back to invisibility. A bare
              // Flexible next to a Spacer would cap the title at its FLEX
              // SHARE — with a trailing widget that share was ~1% of the row
              // and the title collapsed to a couple of pixels (the
              // «اوقات شرعی» / «خلاصه امروز» / «رواتب» / «تایم‌لاین اعمال»
              // headers rendered empty).
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 14),
                          fontWeight: FontWeight.w500,
                          color: t.textPrimary,
                        ),
                      ),
                      if (count != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: t.pageBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            count!,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 11),
                              color: t.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 12),
              child: Text(
                description!,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 10.5),
                  color: t.textMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
