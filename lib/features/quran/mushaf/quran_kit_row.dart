import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/tokens.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/features/quran/mushaf/mushaf_palette.dart';

/// The reader's list row, drawn in the app's shared design language.
///
/// Every list inside the mushaf (reciters, translations & tafsirs, the
/// downloads page, the surah index, search results, the speed pickers) uses
/// this row so they read as the same system as the home page and «بیشتر»:
/// the flat duotone [DuotoneIconTile] those screens put on every prayer,
/// rawatib and reminder row, a title/subtitle pair on the shared type scale,
/// and an optional trailing widget.
///
/// It takes a [MushafPalette] rather than reading the time theme because the
/// mushaf is deliberately theme-independent — a paper/night reader — so a
/// sheet has to follow the paper it opens on, not the app theme behind it.
class QuranKitRow extends StatelessWidget {
  const QuranKitRow({
    super.key,
    required this.palette,
    required this.title,
    this.icon,
    this.leading,
    this.badge,
    this.subtitle,
    this.subtitleRich,
    this.subtitleColor,
    this.trailing,
    this.selected = false,
    this.tileSize = 36,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
  }) : assert(
          (icon != null) != (leading != null),
          'QuranKitRow needs exactly one identity: pass icon, or leading '
          '(which replaces it), never both and never neither.',
        );

  final MushafPalette palette;

  /// Identity glyph for the standard duotone tile. Ignored when [leading] is
  /// supplied.
  final IconData? icon;

  /// Replaces the duotone tile entirely — e.g. a number tile where the row's
  /// identity is a surah or verse number rather than an icon.
  final Widget? leading;

  /// Optional chip rendered after the title in the same line (a language tag).
  final Widget? badge;

  final String title;
  final String? subtitle;

  /// A styled subtitle — a search result whose match is marked. Wins over
  /// [subtitle] when both are given.
  final TextSpan? subtitleRich;

  /// Overrides the muted subtitle ink — for rows whose subtitle is the real
  /// content (a search result's verse text) rather than metadata.
  final Color? subtitleColor;

  final Widget? trailing;

  /// Selected rows take a heavier title and a faint accent wash.
  final bool selected;

  final double tileSize;
  final VoidCallback? onTap;

  /// Long-press shortcut (the player's speed row flips 1× ↔ 2× without
  /// opening its picker).
  final VoidCallback? onLongPress;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tint = palette.accent.withValues(alpha: 0.08);
    // One node per row, so a screen reader announces «قاری — حفص عن عاصم» as
    // a single item instead of two loose texts (report §7.8).
    final subtitleText = subtitleRich?.toPlainText() ?? subtitle;
    final semanticsLabel = (subtitleText == null || subtitleText.isEmpty)
        ? title
        : '$title — $subtitleText';
    return Semantics(
      container: true,
      button: onTap != null || onLongPress != null,
      selected: selected,
      label: semanticsLabel,
      onTap: onTap,
      onLongPress: onLongPress,
      child: ExcludeSemantics(
        child: _buildRow(context, tint),
      ),
    );
  }

  Widget _buildRow(BuildContext context, Color tint) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(14),
      child: DecoratedBox(
        decoration: selected
            ? BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(14),
              )
            : const BoxDecoration(),
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              leading ??
                  DuotoneIconTile(
                    accent: palette.accent,
                    icon: icon!,
                    size: tileSize,
                  ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 14),
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w600,
                              color: palette.surfaceText,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 6),
                          badge!,
                        ],
                      ],
                    ),
                    if (subtitle != null || subtitleRich != null) ...[
                      const SizedBox(height: 2),
                      Text.rich(
                        subtitleRich ?? TextSpan(text: subtitle),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: AppTheme.scaledFontSize(context, 12),
                          color: subtitleColor ?? palette.surfaceMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The same duotone squircle as [DuotoneIconTile], but carrying a short label
/// (a surah or verse number) instead of a glyph — for lists whose identity is
/// the number itself.
class QuranKitNumberTile extends StatelessWidget {
  const QuranKitNumberTile({
    super.key,
    required this.accent,
    required this.label,
    this.size = 36,
  });

  final Color accent;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = 0.32 * size;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: AppTheme.scaledFontSize(context, 12),
          fontWeight: FontWeight.w700,
          color: mix(accent, Colors.black, 0.10),
        ),
      ),
    );
  }
}
