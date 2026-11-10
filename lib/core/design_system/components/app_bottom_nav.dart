import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// One tab of the [AppBottomNav].
class AppNavItem {
  const AppNavItem({required this.icon, required this.label, required this.hue});

  final IconData icon;
  final String label;

  /// Fixed identity hue — inactive pill tint and icon color.
  final Color hue;
}

/// Bottom navigation with the design's colored-pill language: every tab owns
/// a fixed identity hue (inactive = soft tinted pill with its hue's icon,
/// active = the phase's hero gradient with the shared gold icon). Promoted
/// from the shell's tuned nav (100ms selection animation).
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.items,
    required this.index,
    required this.onSelected,
  });

  final List<AppNavItem> items;
  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = TimeThemeKit.of(context).palette;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
          child: Row(
            children: [
              for (final (i, item) in items.indexed)
                Expanded(child: _NavItemTile(
                  item: item,
                  selected: i == index,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelected(i);
                  },
                )),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemTile extends StatelessWidget {
  const _NavItemTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = TimeThemeKit.of(context).palette;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
                width: selected ? 52 : 46,
                height: 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: selected
                      ? null
                      : item.hue.withValues(alpha: isDark ? 0.18 : 0.10),
                  gradient: selected
                      ? LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [p.heroTop, p.heroBottom],
                        )
                      : null,
                ),
                child: Icon(
                  item.icon,
                  size: 20,
                  color: selected
                      ? AppPalette.heroGold
                      : (isDark
                          ? Color.lerp(item.hue, Colors.white, 0.45) ?? item.hue
                          : item.hue),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: AppTheme.scaledFontSize(context, 10.5),
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  color: selected ? p.textPrimary : p.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
