import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/section_colors.dart';
import 'package:tawheeed/features/settings/presentation/search/settings_registry.dart';

/// ═══════════════════════════════════════════════════════════════
/// SettingsSectionHues — one identity hue per settings section.
///
/// The settings page is a long scroll of eight sections with identical
/// headers; without a colour the eye has nothing to land on while scrolling
/// back for «واحد پول». Each section gets a 4dp accent bar in its own hue, the
/// same hue the app already uses for that feature elsewhere ([SectionColors]),
/// so the colour is a memory aid rather than decoration.
///
/// Rule: a page opened FROM a section keeps that section's hue for all of its
/// headers. The bar you tapped and the bars on the page you landed on match,
/// and a sub-page never turns into a rainbow of its own.
///
/// These are fixed topic colours, not theme accents — they must not follow the
/// user's palette, or two sections would collapse into one colour on a
/// single-hue theme. [on] lifts them in dark mode so a deep hue
/// (0xFF1B5E20) stays visible on a night background.
/// ═══════════════════════════════════════════════════════════════
abstract final class SettingsSectionHues {
  SettingsSectionHues._();

  // ── Top-level sections of the settings page, in page order ──

  /// «ظاهر برنامه» — violet: the design/appearance hue.
  static const Color appearance = Color(0xFF7A5AF8);

  /// «نماز و اذان» — the prayer identity hue, same as the prayer screens.
  static const Color prayer = SectionColors.prayer;

  /// «صداهای برنامه» — the audio-library hue.
  static const Color sounds = SectionColors.audioLibrary;

  /// «امتیازدهی عبادات» — green: growth and progress.
  static const Color scoring = Color(0xFF2E7D32);

  /// «اعلان‌ها و اذکار» — the reminders hue.
  static const Color notifications = SectionColors.reminders;

  /// «ویجت‌ها» — the planning/tools blue.
  static const Color widgets = SectionColors.tasks;

  /// «واحد پول» — gold, the zakat/money hue.
  static const Color currency = SectionColors.zakat;

  /// «سایر» — the misc hue, for the drawer of everything else.
  static const Color other = SectionColors.misc;

  // ── Pages opened from a section (they inherit its hue) ──

  /// «فونت و نمایش» is opened from «ظاهر برنامه».
  static const Color font = appearance;

  /// «مدیریت فضا» / «حساب و پشتیبان» — blue-grey: storage and account.
  static const Color account = Color(0xFF546E7A);

  /// «درباره برنامه» — its own grey-blue, so it does not read as «سایر».
  static const Color about = Color(0xFF607D8B);

  /// The hue for a search-result group, so a result carries the colour of the
  /// section it lives in. «تنظیمات» results are the main page itself, which has
  /// no single hue — they take [other].
  ///
  /// Exhaustive switch, not a map: a new [SettingsSearchPage] then cannot ship
  /// with an uncoloured group header.
  static Color forPage(SettingsSearchPage page) => switch (page) {
        SettingsSearchPage.main => other,
        SettingsSearchPage.prayer => prayer,
        SettingsSearchPage.notifications => notifications,
        SettingsSearchPage.widgets => widgets,
        SettingsSearchPage.account => account,
        SettingsSearchPage.font => font,
        SettingsSearchPage.about => about,
      };

  /// [hue] adjusted for the current brightness. In dark mode the deep topic
  /// colours (0xFF1B5E20, 0xFF283593) sit too close to the night background to
  /// read as an accent, so they are lifted toward white — enough to separate,
  /// not enough to wash the hue out.
  static Color on(BuildContext context, Color hue) {
    if (Theme.of(context).brightness != Brightness.dark) return hue;
    return Color.lerp(hue, Colors.white, 0.28) ?? hue;
  }
}
