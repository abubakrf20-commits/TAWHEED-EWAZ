import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tawheeed/core/theme/app_colors.dart';

/// WCAG relative luminance for a color (0..1), using the new double channel API.
double _luminance(Color c) {
  double lin(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}

/// Contrast ratio of [c] against pure white (WCAG).
double _contrastOnWhite(Color c) => 1.05 / (_luminance(c) + 0.05);

void main() {
  test('darkenAccentForText darkens the default quran accent', () {
    final strong = AppColors.darkenAccentForText(AppColors.quranAccent);
    expect(strong, isNot(equals(AppColors.quranAccent)));
  });

  test('darkened gold reaches AA (>= 4.5:1) on white', () {
    final strong = AppColors.darkenAccentForText(AppColors.quranAccent);
    expect(_contrastOnWhite(strong), greaterThanOrEqualTo(4.5));
  });

  test('darkenAccentForText is module-aware (improves any accent)', () {
    for (final accent in [
      AppColors.quranAccent,
      AppColors.zakatAccent,
      AppColors.duaAccent,
      AppColors.notesAccent,
    ]) {
      final strong = AppColors.darkenAccentForText(accent);
      expect(_contrastOnWhite(strong), greaterThan(_contrastOnWhite(accent)),
          reason: 'accent $accent should gain contrast');
    }
  });

  test('amount 0 leaves the accent unchanged', () {
    expect(
      AppColors.darkenAccentForText(AppColors.quranAccent, 0),
      AppColors.quranAccent,
    );
  });

  test('strongAccent amount param darkens more for light accents', () {
    // Amber (notes identity) is much lighter than gold; the default 0.3
    // amount only reaches ~4:1 on white, so callers pass 0.45.
    const amber = Color(0xFFF5A623);
    final defaultStrong = AppColors.darkenAccentForText(amber);
    final strong45 = AppColors.darkenAccentForText(amber, 0.45);
    expect(_contrastOnWhite(strong45),
        greaterThan(_contrastOnWhite(defaultStrong)));
    expect(_contrastOnWhite(strong45), greaterThanOrEqualTo(4.5),
        reason: 'amber at 0.45 should hit AA on white');
  });

  test('strongAccent with amount is stronger than default', () {
    const amber = Color(0xFFF5A623);
    final strong = AppColors.darkenAccentForText(amber, 0.45);
    expect(strong, isNot(equals(amber)));
  });

  test('very light prayer yellow reaches AA at amount 0.5', () {
    // Dhuhr yellow (0xFFFDD835) is extremely light; even 0.45 lands at
    // ~4.4:1, so the home prayer rows use 0.5 to clear the 4.5:1 line.
    const dhuhrYellow = Color(0xFFFDD835);
    final strong = AppColors.darkenAccentForText(dhuhrYellow, 0.5);
    expect(_contrastOnWhite(strong), greaterThanOrEqualTo(4.5),
        reason: 'dhuhr yellow at 0.5 should hit AA on white');
  });
}
