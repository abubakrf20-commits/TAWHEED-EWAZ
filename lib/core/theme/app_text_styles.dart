import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/app_colors.dart';
import 'package:tawheeed/core/theme/theme.dart';

class AppTextStyles {
  AppTextStyles._();

  /// Resolves to the active app font (follows the user's setting).
  static String get fontFamily => AppTheme.fontFamily;

  // Helper to apply font scaling
  static double _sf(BuildContext context, double base) =>
      AppTheme.scaledFontSize(context, base);

  // =========================
  // Screen-level
  // =========================
  static TextStyle screenTitle(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: _sf(context, 24),
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary(context),
      );

  static TextStyle sectionTitle(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: _sf(context, 18),
        height: 1.30,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary(context),
      );

  static TextStyle subtitle(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: _sf(context, 14),
        height: 1.50,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary(context),
      );

  static TextStyle body(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: _sf(context, 15),
        height: 1.50,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary(context),
      );

  static TextStyle caption(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: _sf(context, 12),
        height: 1.30,
        fontWeight: FontWeight.w500,
        color: AppColors.textMuted(context),
      );

  // =========================
  // Prayer
  // =========================
  static TextStyle prayerName(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: _sf(context, 17),
        height: 1.30,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary(context),
      );

  static TextStyle prayerTime(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: _sf(context, 22),
        height: 1.15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary(context),
      );

  static TextStyle prayerTimeSmall(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: _sf(context, 16),
        height: 1.20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary(context),
      );

  static TextStyle nextPrayerLabel(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: _sf(context, 14),
        height: 1.30,
        fontWeight: FontWeight.w600,
        color: AppColors.heroOn(context).withValues(alpha: 0.85),
      );

  static TextStyle nextPrayerTime(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: _sf(context, 34),
        height: 1.05,
        fontWeight: FontWeight.w700,
        color: AppColors.heroOn(context),
      );

  static TextStyle countdown(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: _sf(context, 24),
        height: 1.10,
        fontWeight: FontWeight.w700,
        color: AppColors.heroOn(context),
      );

  static TextStyle countdownLabel(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: _sf(context, 13),
        height: 1.25,
        fontWeight: FontWeight.w500,
        color: AppColors.heroOn(context).withValues(alpha: 0.80),
      );

  // =========================
  // Tasbih / Dhikr
  // =========================
  static TextStyle tasbihNumber(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: _sf(context, 52),
        height: 1.00,
        fontWeight: FontWeight.w700,
        color: AppColors.tasbihCounterColor(context),
      );

  static TextStyle tasbihLabel(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: _sf(context, 14),
        height: 1.30,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary(context),
      );

  static TextStyle zikrTitle(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: _sf(context, 20),
        height: 1.30,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary(context),
      );

  static TextStyle zikrText(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: _sf(context, 18),
        height: 1.60,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary(context),
      );

  // =========================
  // Date / Calendar
  // =========================
  static TextStyle hijriDate(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: _sf(context, 16),
        height: 1.30,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary(context),
      );

  static TextStyle shamsiDate(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: _sf(context, 15),
        height: 1.30,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary(context),
      );

  static TextStyle gregorianDate(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: _sf(context, 13),
        height: 1.25,
        fontWeight: FontWeight.w500,
        color: AppColors.textMuted(context),
      );

  // =========================
  // Cards
  // =========================
  static TextStyle cardTitle(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: _sf(context, 16),
        height: 1.30,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary(context),
      );

  static TextStyle cardValue(BuildContext context) => TextStyle(
        fontFamily: fontFamily,
        fontSize: _sf(context, 24),
        height: 1.10,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary(context),
      );

  static TextStyle badge(BuildContext context, {Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontSize: _sf(context, 12),
        height: 1.20,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.primaryStrong(context),
      );

  // =========================
  // Navigation
  // =========================
  static TextStyle navLabel(BuildContext context, {required bool selected}) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: _sf(context, 11),
        height: 1.20,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected
            ? AppColors.navItemActiveForeground(context)
            : AppColors.navItemInactiveForeground(context),
      );
}
