import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/app_card.dart';
import 'package:tawheeed/core/design_system/components/duotone_icon_tile.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// The flat card that opens a redesigned section's tab — and stands in for
/// the old gradient hero on the introduction tab: a duotone tile beside the
/// tab's own words (title, plus an optional second line), on the plain card
/// surface. No accent wash, no gradient, no shadow.
///
/// The card carries whatever copy the screen already had; only the container
/// changes. Passing a pre-joined `'title\nsubtitle'` string renders
/// identically — this is the same recipe the وضو و طهارت reference uses.
class TabIntroCard extends StatelessWidget {
  const TabIntroCard({
    super.key,
    required this.icon,
    required this.accent,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = TimeThemeKit.of(context).palette;
    return AppCard(
      child: Row(
        children: [
          DuotoneIconTile(accent: accent, icon: icon, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              subtitle == null ? title : '$title\n$subtitle',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.scaledFontSize(context, 13),
                fontWeight: FontWeight.w600,
                color: t.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
