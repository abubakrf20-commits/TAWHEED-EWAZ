import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/design_system/components/share_card_palette.dart';
import 'package:tawheeed/features/tools/inheritance/domain/inheritance_calculator.dart';

/// The inheritance tool's colour source.
///
/// Thirteen files under `tools/inheritance/` each carried their own copies of
/// the same purple family (`6A1B9A` twenty-one times, `9C4DCC` ten, `4A148C`,
/// `8E44AD`, `8A24AA`…), the same two-stop hero band, the same amber
/// highlight/note pair, and — twice, in two different widgets — the same
/// eleven-colour pie series. A features' chart series and identity colours are
/// not design tokens, so they live here rather than in `AppTheme`; what matters
/// is that there is one source and that a change lands everywhere.
class InheritancePalette {
  InheritancePalette._();

  // ── the section accent ───────────────────────────────────────────────────
  /// The «بیشتر» tile hue, so the tool and its tile cannot drift.
  static const Color accent = TopicHues.inheritance;

  /// The lifted accent for dark palettes (a flat `6A1B9A` goes muddy there).
  static const Color accentDark = Color(0xFF9C4DCC);

  /// The accent for the active brightness.
  static Color accentOn(bool isDark) => isDark ? accentDark : accent;

  // ── the purple family (tiles, chips, the quiz) ───────────────────────────
  static const Color purpleMid = Color(0xFF8E24AA);
  static const Color purpleDeep = Color(0xFF4A148C);

  // ── markers ──────────────────────────────────────────────────────────────
  /// The highlighted answer / «وصیت واجبه» card.
  static const Color highlight = Color(0xFFFFA000);

  /// The note / info gold.
  static const Color note = Color(0xFFB8860B);

  // ── share types (one mapping, used by the tab and the share card) ────────
  /// فرض
  static const Color fard = AppTheme.info;

  /// تعصیب, as the calculator has always drawn it.
  static const Color asaba = AppTheme.success;

  /// رد
  static const Color radd = highlight;

  /// وصیت واجبه
  static const Color mandatoryWill = purpleMid;

  /// عصبهای رنگ کارت اشتراک — it predates this table and uses its own teal;
  /// unifying it with [asaba] is a design decision, not a refactor.
  static const Color asabaInk = Color(0xFF00897B);

  /// ردی که کارت اشتراک میکشد (the tab's «رد» is [radd]).
  static const Color raddInk = Color(0xFF1E88E5);

  /// وصیت واجبه, as the share card draws it.
  static const Color mandatoryWillInk = Color(0xFF5D4037);

  /// حجب
  static const Color hajb = Color(0xFF9E9E9E);

  /// The four madhhabs, one source (the comparison tab declared this map twice).
  static const Map<Madhab, Color> madhabColors = {
    Madhab.jumhur: purpleDeep,
    Madhab.hanafi: fard,
    Madhab.maliki: AppTheme.success,
    Madhab.shafii: accent,
    Madhab.hanbali: AppTheme.warning,
  };

  // ── the share card's paper ───────────────────────────────────────────────
  static const Color cardBg = Color(0xFFFDFDFD);
  static const Color cardBgDark = ShareCardPalette.bgDark;
  static const Color boxBg = Color(0xFFEFEFEF);
  static const Color boxInk = Color(0xFF555555);
  static const Color label = Color(0xFF6E6E6E);
  static const Color track = Color(0xFFDEDEDE);
  static const Color ink = ShareCardPalette.ink;
  static const Color inkMuted = ShareCardPalette.inkSubtle;

  // ── the pie + legend series ──────────────────────────────────────────────
  /// The heir-share series, in slice order: the donut paints slice *i* with
  /// `series[i % series.length]` and the legend repeats the list, so the
  /// ORDER IS LOAD-BEARING — reordering it re-paints every saved screenshot.
  /// The chart and its legend each re-declared the list by hand, so a colour
  /// added to one silently disagreed with the other.
  static const List<Color> series = [
    fard, // آبی 0xFF1565C0
    AppTheme.success, // سبز
    accent, // بنفش 0xFF6A1B9A
    AppTheme.warning, // نارنجی
    asabaInk, // فیروزه‌ای 0xFF00897B
    AppTheme.error, // قرمز
    Color(0xFF4527A0), // بنفش تیره
    Color(0xFFEF6C00), // کهربایی
    Color(0xFF0097A7), // آبی فیروزه‌ای
    Color(0xFF558B2F), // سبز روشن
    Color(0xFFAD1457), // صورتی
    Color(0xFF283593), // نیلی
    Color(0xFF6D4C41), // قهوه‌ای
    Color(0xFF37474F), // خاکستری آبی
  ];
}
