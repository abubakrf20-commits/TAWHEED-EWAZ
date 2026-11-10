import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tawheeed/core/design_system/components/tokens.dart';
import 'package:tawheeed/core/theme/app_colors.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// Home bottom navigation: six equal-width pills with the icon ABOVE its
/// label INSIDE the pill (no separate label below).
///
/// Order and routes (RTL): خانه، قرآن، تسبیح، تقویم، ارزیابی، بیشتر.
/// Active = the tab's OWN section hue as a two-stop gradient ([pillTop] /
/// [pillBottom], deepened on the light bar and lifted on the dark one) + gold
/// icon + cream label; inactive = per-tab tinted pill with its own hue
/// (labels contrast-verified ≥ 4.5:1, see the nav tokens in [AppColors]).
///
/// Extracted into its own widget so every screen that shows the bottom bar
/// renders the same tabs. No implicit animation: the fill is decided on the
/// tap frame, so a tab switch never waits on a tween; dark mode keeps the
/// hue-alpha pill language.
class HomeBottomNav extends StatelessWidget {
  const HomeBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final void Function(int index) onTap;

  static const _items = <({IconData icon, String label, Color hue})>[
    (icon: Icons.home_rounded, label: 'خانه', hue: SectionHues.home),
    (icon: Icons.auto_stories_rounded, label: 'قرآن', hue: SectionHues.quran),
    (icon: Icons.wb_sunny_outlined, label: 'تسبیح', hue: SectionHues.tasbih),
    (
      icon: Icons.calendar_month_rounded,
      label: 'تقویم',
      hue: SectionHues.calendar
    ),
    (
      icon: Icons.assignment_rounded,
      label: 'ارزیابی',
      hue: SectionHues.evaluation
    ),
    (icon: Icons.grid_view_rounded, label: 'بیشتر', hue: SectionHues.more),
  ];

  /// Per-tab inactive (tint, icon, label) for light mode. Home reuses the
  /// existing linen/mocha tokens; report and more share the coral pair.
  static const _inactive = <({Color tint, Color icon, Color label})>[
    (tint: AppTheme.linen, icon: AppTheme.mocha, label: AppTheme.mocha),
    (
      tint: AppColors.navQuranTint,
      icon: SectionHues.quran,
      label: AppColors.navQuranLabel
    ),
    (
      tint: AppColors.navTasbihTint,
      icon: SectionHues.tasbih,
      label: AppColors.navTasbihLabel
    ),
    (
      tint: AppColors.navCalendarTint,
      icon: SectionHues.calendar,
      label: AppColors.navCalendarLabel
    ),
    (
      tint: AppColors.navReportTint,
      icon: AppColors.navCoral,
      label: AppColors.navDeepCoral
    ),
    (
      tint: AppColors.navMoreTint,
      icon: AppColors.navCoral,
      label: AppColors.navDeepCoral
    ),
  ];

  /// The selected pill wears **its own section's colour**, deepened until the
  /// cream label clears 4.5:1. Light mode deepens more (the pill sits on a
  /// white bar); dark mode lifts the top stop so the pill separates from the
  /// dark surface while keeping the hue. Public so the theme test can pin the
  /// exact stops instead of re-deriving the lerp.
  static Color pillTop(Color hue, bool isDark) => isDark
      ? (Color.lerp(hue, Colors.white, 0.12) ?? hue)
      : (Color.lerp(hue, Colors.black, 0.24) ?? hue);

  static Color pillBottom(Color hue, bool isDark) => isDark
      ? (Color.lerp(hue, Colors.black, 0.28) ?? hue)
      : (Color.lerp(hue, Colors.black, 0.42) ?? hue);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        border: Border(
          top: BorderSide(
            color:
                isDark ? Colors.white.withValues(alpha: 0.06) : AppTheme.shell,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: _NavPill(
                    item: _items[i],
                    inactive: _inactive[i],
                    selected: i == currentIndex,
                    isDark: isDark,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onTap(i);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NavPill extends StatelessWidget {
  const _NavPill({
    required this.item,
    required this.inactive,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final ({IconData icon, String label, Color hue}) item;
  final ({Color tint, Color icon, Color label}) inactive;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final top = HomeBottomNav.pillTop(item.hue, isDark);
    final bottom = HomeBottomNav.pillBottom(item.hue, isDark);
    // Gold is the brand ink on a dark pill; on the gold tab's own pill it is
    // unreadable, so the glyph falls back to cream there (contrast-checked, not
    // a hard-coded exception).
    final iconColor = selected
        ? (dsContrastRatio(AppPalette.heroGold, top) >= 3
            ? AppPalette.heroGold
            : AppPalette.cream)
        : isDark
            ? Color.lerp(item.hue, Colors.white, 0.45) ?? item.hue
            : inactive.icon;
    final labelColor = selected
        ? (dsContrastRatio(AppPalette.cream, top) >= 4.5
            ? AppPalette.cream
            : Colors.white)
        : isDark
            ? Color.lerp(item.hue, Colors.white, 0.60) ?? item.hue
            : inactive.label;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        // No implicit animation: the pill's fill is decided by the tab index,
        // which already changed on this frame. The old 180 ms ease tweened a
        // gradient + two text colours on every tab tap — a visible lag on the
        // phones this app targets, for a transition nobody asked to watch. A
        // plain Container also drops the implicit-animation ticker entirely.
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [top, bottom],
                  )
                : null,
            color: selected
                ? null
                : isDark
                    ? item.hue.withValues(alpha: 0.18)
                    : inactive.tint,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 20, color: iconColor),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: AppTheme.scaledFontSize(context, 10),
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                      color: labelColor,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
