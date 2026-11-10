import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';

class AppColors {
  AppColors._();

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // =========================
  // Core palette (theme-aware)
  // =========================
  static Color primary(BuildContext context) =>
      isDark(context) ? AppTheme.darkPrimary : AppTheme.lightPrimary;

  static Color primaryStrong(BuildContext context) => isDark(context)
      ? AppTheme.darkPrimaryStrong
      : AppTheme.lightPrimaryStrong;

  static Color primarySoft(BuildContext context) =>
      isDark(context) ? AppTheme.darkPrimarySoft : AppTheme.lightPrimarySoft;

  static Color secondary(BuildContext context) =>
      isDark(context) ? AppTheme.darkSecondary : AppTheme.lightSecondary;

  static Color secondarySoft(BuildContext context) => isDark(context)
      ? AppTheme.darkSecondarySoft
      : AppTheme.lightSecondarySoft;

  static Color tertiary(BuildContext context) =>
      isDark(context) ? AppTheme.darkTertiary : AppTheme.lightTertiary;

  static Color tertiarySoft(BuildContext context) =>
      isDark(context) ? AppTheme.darkTertiarySoft : AppTheme.lightTertiarySoft;

  static Color background(BuildContext context) =>
      isDark(context) ? AppTheme.darkScaffoldTint : AppTheme.lightScaffoldTint;

  static Color surface(BuildContext context) =>
      isDark(context) ? AppTheme.darkSurfaceTint : AppTheme.lightSurfaceTint;

  static Color surfaceAlt(BuildContext context) => isDark(context)
      ? AppTheme.darkSurfaceAltTint
      : AppTheme.lightSurfaceAltTint;

  static Color surfaceMuted(BuildContext context) => isDark(context)
      ? AppTheme.darkSurfaceMutedTint
      : AppTheme.lightSurfaceMutedTint;

  static Color card(BuildContext context) =>
      isDark(context) ? AppTheme.darkCardTint : AppTheme.lightCardTint;

  static Color cardTinted(BuildContext context) =>
      isDark(context) ? AppTheme.darkCardTinted : AppTheme.lightCardTinted;

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;

  static Color textSecondary(BuildContext context) => isDark(context)
      ? AppTheme.darkTextSecondary
      : AppTheme.lightTextSecondary;

  static Color textMuted(BuildContext context) =>
      isDark(context) ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

  static Color outline(BuildContext context) =>
      isDark(context) ? AppTheme.darkOutline : AppTheme.lightOutline;

  static Color divider(BuildContext context) =>
      isDark(context) ? AppTheme.darkDivider : AppTheme.lightDivider;

  static Color success(BuildContext context) =>
      isDark(context) ? AppTheme.darkSuccess : AppTheme.lightSuccess;

  static Color warning(BuildContext context) =>
      isDark(context) ? AppTheme.darkWarning : AppTheme.lightWarning;

  static Color error(BuildContext context) =>
      isDark(context) ? AppTheme.darkError : AppTheme.lightError;

  static Color info(BuildContext context) =>
      isDark(context) ? AppTheme.darkInfo : AppTheme.lightInfo;

  /// Success green — single canonical source (AppTheme.lightSuccess).
  static const Color successGreen = AppTheme.lightSuccess;

  /// بنفسجي مخصص (قیام اللیل) — كانوني في AppColors
  static const Color accentPurple = Color(0xFF7C4DFF);

  /// أخضر الصلاة (شاشة النماز) — كانوني في AppColors
  static const Color prayerGreen = Color(0xFF4A7C5A);

  /// Fixed hadith color — pinned so it never shifts with the theme accent
  /// preset (design rule: each section keeps its own color).
  static const Color hadithFixed = Color(0xFF00695C);

  // =========================
  // Semantic helpers
  // =========================
  /// Text/icon color on primary background (white on dark primary, dark on light primary)
  static Color onPrimary(BuildContext context) =>
      isDark(context) ? const Color(0xFF1A1410) : Colors.white;

  /// Shadow color for cards/elevations
  static Color shadow(BuildContext context) =>
      isDark(context) ? Colors.black : const Color(0xFF3E2723);

  /// Period/menstruation accent color
  static Color periodAccent(BuildContext context) =>
      isDark(context) ? const Color(0xFFD47A9A) : const Color(0xFFE91E63);

  // =========================
  // Navigation
  // =========================
  static Color navBackground(BuildContext context) => surface(context);

  static Color navItemActiveBackground(BuildContext context) => isDark(context)
      ? AppTheme.darkPrimary.withValues(alpha: 0.20)
      : AppTheme.lightPrimary.withValues(alpha: 0.12);

  static Color navItemActiveForeground(BuildContext context) =>
      isDark(context) ? AppTheme.darkPrimary : AppTheme.lightPrimary;

  static Color navItemInactiveForeground(BuildContext context) =>
      isDark(context)
          ? AppTheme.darkTextMuted
          : textSecondary(context).withValues(alpha: 0.45);

  // =========================
  // Hero cards
  // =========================
  static Color heroOn(BuildContext context) =>
      isDark(context) ? AppTheme.darkTextPrimary : Colors.white;

  static Color heroOnMuted(BuildContext context) => isDark(context)
      ? AppTheme.darkTextPrimary.withValues(alpha: 0.85)
      : Colors.white.withValues(alpha: 0.85);

  // =========================
  // Tasbih
  // =========================
  static Color tasbihBackground(BuildContext context) =>
      isDark(context) ? AppTheme.darkSurfaceTint : AppTheme.lightScaffoldTint;

  static Color tasbihCounterColor(BuildContext context) =>
      isDark(context) ? AppTheme.darkPrimary : AppTheme.lightPrimary;

  static Color tasbihProgressColor(BuildContext context) =>
      isDark(context) ? AppTheme.darkPrimary : AppTheme.lightTertiary;

  static Color tasbihButtonColor(BuildContext context) =>
      isDark(context) ? AppTheme.darkPrimary : AppTheme.lightPrimary;

  // =========================
  // Calendar
  // =========================
  static Color calendarToday(BuildContext context) =>
      isDark(context) ? AppTheme.darkPrimary : AppTheme.lightTertiary;

  static Color calendarTodayText(BuildContext context) =>
      isDark(context) ? AppTheme.darkBackground : AppTheme.lightPrimaryStrong;

  static Color calendarSelected(BuildContext context) =>
      isDark(context) ? AppTheme.darkPrimarySoft : AppTheme.lightPrimarySoft;

  static Color calendarSelectedText(BuildContext context) =>
      isDark(context) ? AppTheme.darkTextPrimary : AppTheme.lightPrimaryStrong;

  // =========================
  // Event colors for Islamic calendar
  // =========================
  static Color eventColorEid({required bool isDark}) =>
      isDark ? const Color(0xFFE5C87B) : const Color(0xFFC9A94E);

  static Color eventColorRamadan({required bool isDark}) =>
      isDark ? const Color(0xFF7CB57A) : const Color(0xFF5B8C5A);

  static Color eventColorAshura({required bool isDark}) =>
      isDark ? const Color(0xFFD47A7A) : const Color(0xFFB85C5C);

  static Color eventColorArafah({required bool isDark}) =>
      isDark ? const Color(0xFFD4B05A) : const Color(0xFFC9A94E);

  static Color eventColorMawlid({required bool isDark}) =>
      isDark ? const Color(0xFF93B5D4) : const Color(0xFF6B7D8C);

  static Color eventColorDefault({required bool isDark}) =>
      isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

  // =========================
  // Clock card
  // =========================
  /// Gradient for the hero clock card — adapts to accent preset + time of day
  static List<Color> clockGradient(BuildContext context, {required int hour}) {
    final dark = isDark(context);
    if (dark) {
      // Dark mode: use deeper tones
      return [const Color(0xFF1B1510), const Color(0xFF2D241E)];
    }
    // Light mode: use primary-based gradient
    return [AppTheme.lightPrimary, AppTheme.lightPrimaryStrong];
  }

  /// Accent color used inside the clock card (dot separator, badges, etc.)
  static Color clockAccent(BuildContext context) =>
      isDark(context) ? AppTheme.darkPrimary : AppTheme.lightTertiary;

  /// Color for the next-prayer countdown badge
  static Color prayerCountdownBg(BuildContext context) => isDark(context)
      ? AppTheme.darkPrimary.withValues(alpha: 0.22)
      : Colors.white.withValues(alpha: 0.18);

  // =========================
  // Date pill colors (for triple calendar)
  // =========================
  static const Color datePillShamsi = Color(0xFFC9A94E);
  static const Color datePillHijri = Color(0xFF4A7C4A);
  static const Color datePillGregorian = Color(0xFF5B7FA5);

  // =========================
  // Current-prayer row tints (home polish; mockup FFF6DA -> FFFBF0).
  // No existing token matches, so they live here instead of in widgets.
  // =========================
  static const Color currentPrayerTintStart = Color(0xFFFFF6DA);
  static const Color currentPrayerTintEnd = Color(0xFFFFFBF0);

  // =========================
  // Bottom-nav inactive tints + labels (home polish).
  // The pale tints have no existing equivalent; icons reuse SectionHues
  // where exact. Every label pair is contrast-verified >= 4.5:1
  // (report icon reuses the darker coral so it clears 3:1 as well).
  // =========================
  // Quran stays green (the single green tab).
  static const Color navQuranTint = Color(0xFFE1F0E9);
  static const Color navQuranLabel = Color(0xFF146B4D);
  // Tasbih → bold gold family.
  static const Color navTasbihTint = Color(0xFFF7ECD2); // pale gold
  static const Color navTasbihLabel = Color(0xFF8A6208); // dark gold
  // Calendar → coffee-brown family.
  static const Color navCalendarTint = Color(0xFFEFE6DE); // pale brown
  static const Color navCalendarLabel = Color(0xFF5E3A22); // dark brown
  static const Color navReportTint = Color(0xFFFADCD0);
  static const Color navCoral = Color(0xFFB8421C);
  static const Color navDeepCoral = Color(0xFF8F3216);
  static const Color navMoreTint = Color(0xFFF4E1DA);

  /// Pill text color — always white for contrast on dark clock card
  static Color datePillText(BuildContext context) =>
      isDark(context) ? AppTheme.darkTextPrimary : Colors.white;

  // =========================
  // Module accent colors (now dynamic — updated by applyAccentPreset)
  // =========================
  static Color get homeAccent => AppTheme.homeAccent;
  static Color get quranAccent => AppTheme.quranAccent;
  static Color get azkarAccent => AppTheme.azkarAccent;
  static Color get calendarAccent => AppTheme.calendarAccent;
  static Color get settingsAccent => AppTheme.settingsAccent;
  static Color get evaluationAccent => AppTheme.evaluationAccent;
  static Color get zakatAccent => AppTheme.zakatAccent;
  static Color get hadithAccent => AppTheme.hadithAccent;
  static Color get hajjAccent => AppTheme.hajjAccent;
  static Color get notesAccent => AppTheme.notesAccent;
  static Color get womenAccent => AppTheme.womenAccent;
  static Color get fastingAccent => AppTheme.fastingAccent;
  static Color get prayerAccent => AppTheme.prayerAccent;
  static Color get purificationAccent => AppTheme.purificationAccent;
  static Color get scienceAccent => AppTheme.scienceAccent;
  static Color get duaAccent => AppTheme.duaAccent;
  static Color get tasksAccent => AppTheme.tasksAccent;

  /// Returns [accent] darkened toward black so it passes AA contrast
  /// (~5.9:1 on white for the default gold) when used as small text on
  /// light surfaces. Module-aware: the amount is applied to whatever
  /// accent the user's palette provides.
  static Color darkenAccentForText(Color accent, [double amount = 0.3]) =>
      Color.lerp(accent, Colors.black, amount) ?? accent;

  /// Module-aware accent variant for small text: in light mode it uses
  /// [darkenAccentForText] for AA contrast; in dark mode raw accents already
  /// pass (~4.9:1 on surfaces), so they are returned unchanged.
  ///
  /// [amount] lets callers request a stronger darkening for very light accents
  /// (e.g. amber 0xFFF5A623 needs ~0.45 to reach 4.5:1 on white, while the
  /// default gold needs only 0.3).
  static Color strongAccent(BuildContext context, Color accent,
          [double amount = 0.3]) =>
      isDark(context) ? accent : darkenAccentForText(accent, amount);
}
