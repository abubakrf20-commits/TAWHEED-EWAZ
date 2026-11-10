import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// Settings row: an identity [IconTile], a title/subtitle pair and an
/// optional trailing widget (defaults to a soft chevron). Padded to a 48dp
/// touch target so weak-phone taps land reliably.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.color,
    this.titleColor,
    this.trailing,
    this.showChevron = true,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Identity hue for the icon tile; defaults to the live phase primary.
  final Color? color;

  /// Title ink; defaults to the palette's text primary. Set it (together with
  /// [color]) to mark a destructive row, e.g. delete-account.
  final Color? titleColor;

  /// Replaces the default chevron — e.g. a switch or a value text.
  final Widget? trailing;

  /// When false the default chevron is omitted (action rows that neither
  /// navigate nor open a page should not promise one).
  final bool showChevron;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = TimeThemeKit.of(context).palette;
    final hue = color ?? p.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            IconTile(icon: icon, color: hue, iconSize: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.scaledFontSize(context, 14),
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? p.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: AppTheme.scaledFontSize(context, 12),
                        color: p.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                (showChevron
                    ? Icon(
                        Icons.chevron_left_rounded,
                        size: 20,
                        color: p.textMuted,
                      )
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}
