import 'package:flutter/material.dart';

import 'package:tawheeed/core/design_system/components/tokens.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// The four score tiers of the evaluation report and their colors.
/// Spec §REPORT: soft coral for «needs effort», gold for «good», emerald for
/// «excellent»; «قابل قبول» keeps the warning hue between them. The tier
/// words themselves come from `EvaluationStatsCompute.ratingForFraction` —
/// this class only (re)colors them, so the score card, the share report and
/// the badge can never disagree.
class ReportTierColors {
  ReportTierColors._();

  /// Soft coral for the lowest tier (spec §REPORT) — encouraging, not the
  /// alarming error red.
  static const Color softCoral = Color(0xFFE0715C);

  /// Solid fill for the status chip on the hero score card. The hero surface
  /// is a dark gradient in every phase, so the chip uses the on-dark gold /
  /// warning variants.
  static Color chipFill(String tier) => switch (tier) {
        'عالی' => AppPalette.emerald,
        'خوب' => AppPalette.heroGold,
        'قابل قبول' => AppTheme.darkWarning,
        _ => softCoral,
      };

  /// Text/icon ink sitting on [chipFill].
  static Color chipInk(String tier, AppPalette t) =>
      tier == 'عالی' ? AppPalette.cream : t.heroBottom;

  /// Readable hue for the same tier on a regular (light or dark) card
  /// surface — the share report and any text usage.
  static Color ink(BuildContext context, String tier) {
    final base = switch (tier) {
      'عالی' => AppPalette.emerald,
      'خوب' => AppPalette.goldDark,
      'قابل قبول' => Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkWarning
          : AppTheme.lightWarning,
      _ => softCoral,
    };
    return dsContentColor(context, base);
  }
}
