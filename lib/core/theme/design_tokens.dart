import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/app_colors.dart';

/// Lightweight design tokens that delegate to [AppTheme].
///
/// These exist to avoid breaking existing imports. Prefer using
/// `AppTheme` directly for new code.
class DesignTokens {
  DesignTokens._();

  /// Resolves to the active app font (follows the user's setting).
  static String get fontFamily => AppTheme.fontFamily;
  static String get arabicFontFamily => fontFamily;

  static TextStyle fontFamilyStyle() => TextStyle(fontFamily: fontFamily);

  // Spacing scale (delegates to AppTheme)
  static const double space2 = AppTheme.space2;
  static const double space4 = AppTheme.space4;
  static const double space6 = AppTheme.space6;
  static const double space8 = AppTheme.space8;
  static const double space10 = AppTheme.space10;
  static const double space12 = AppTheme.space12;
  static const double space16 = AppTheme.space16;
  static const double space20 = AppTheme.space20;
  static const double space24 = AppTheme.space24;
  static const double space32 = AppTheme.space32;
  static const double space48 = AppTheme.space48;
  static const double space64 = AppTheme.space64;

  // Border radius (delegates to AppTheme)
  static const double radiusXs = AppTheme.radiusSmall;
  static const double radiusSm = AppTheme.radiusMedium;
  static const double radiusMd = AppTheme.radiusLarge;
  static const double radiusLg = AppTheme.radiusXLarge;
  static const double radiusXl = AppTheme.radiusXxxLarge;

  // Durations (delegates to AppTheme)
  static const Duration fastAnim = AppTheme.fastAnim;
  static const Duration medAnim = AppTheme.medAnim;

  // Semantic colors (delegates to AppColors)
  static Color primary(BuildContext c) => AppColors.primary(c);
  static Color onPrimary(BuildContext c) => AppColors.onPrimary(c);
  static Color surface(BuildContext c) => AppColors.surface(c);
  static Color card(BuildContext c) => AppColors.card(c);
  static Color textPrimary(BuildContext c) => AppColors.textPrimary(c);
  static Color textSecondary(BuildContext c) => AppColors.textSecondary(c);
  static Color textMuted(BuildContext c) => AppColors.textMuted(c);
  static Color outline(BuildContext c) => AppColors.outline(c);
  static Color success(BuildContext c) => AppColors.success(c);
  static Color error(BuildContext c) => AppColors.error(c);

  // Arabic text style
  static TextStyle arabicText(
          {double size = 22, FontWeight weight = FontWeight.w600}) =>
      TextStyle(
        fontFamily: arabicFontFamily,
        fontSize: size,
        fontWeight: weight,
        height: 1.8,
      );

  // Body text style
  static TextStyle bodyText(
          {double size = 15, FontWeight weight = FontWeight.w400}) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
      );

  // Section title style
  static TextStyle sectionTitle(
          {double size = 16, FontWeight weight = FontWeight.w700}) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
      );

  // Card default padding
  static EdgeInsets get cardPadding =>
      const EdgeInsets.symmetric(horizontal: 16, vertical: 14);

  // Section horizontal padding
  static EdgeInsets get sectionPadding =>
      const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
}
