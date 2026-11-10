import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// One segment of a [SegmentedTabs] row.
class SegmentedTab {
  const SegmentedTab({required this.label, this.icon});

  final String label;
  final IconData? icon;
}

/// Segmented control: a muted track with the active segment on the phase
/// hero gradient. The selected pill animates at 200ms.
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.tabs,
    required this.index,
    required this.onChanged,
  });

  final List<SegmentedTab> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = TimeThemeKit.of(context).palette;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.outline, width: .5),
      ),
      child: Row(
        children: [
          for (final (i, tab) in tabs.indexed)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (i == index) return;
                    HapticFeedback.selectionClick();
                    onChanged(i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    height: 34,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      gradient: i == index
                          ? LinearGradient(
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                              colors: [p.heroTop, p.heroBottom],
                            )
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (tab.icon != null) ...[
                          Icon(
                            tab.icon,
                            size: 15,
                            color: i == index
                                ? AppPalette.heroGold
                                : p.textMuted,
                          ),
                          const SizedBox(width: 5),
                        ],
                        Flexible(
                          child: Text(
                            tab.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: AppTheme.scaledFontSize(context, 12),
                              fontWeight: i == index
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: i == index ? p.heroInk : p.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
