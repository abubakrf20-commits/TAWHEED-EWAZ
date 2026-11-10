import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/app_colors.dart';
import 'package:tawheeed/core/theme/section_colors.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/features/prayer/domain/prayer_clock.dart';

/// Every colour the redesigned home draws with — the approved mockup's
/// exact hexes in one table. Where a hex IS an existing core token it is
/// aliased, not copied, so the page can never half-drift to a second
/// palette (e.g. [asr] is [PrayerHues.asr], [khatm] is [AppPalette.emerald]).
/// The remaining literals are mockup-only hexes with no core twin; the two
/// `dawn …` notes name per-palette instance fields, which cannot be aliased
/// by a `static const` and therefore stay literal.
///
/// These are the LIGHT-mode truths. Dark mode keeps its existing core
/// tokens (AppTheme/AppColors) at the widget level, as the rest of the app
/// does — the exceptions are the `bool isDark` methods below, for the few
/// surfaces whose light hex would be unreadable ink on the dark card.
abstract final class HomeColors {
  // ── prayer-row duotone accents ──
  static const Color fajr = Color(0xFF5B4BC4);
  static const Color sunrise = Color(0xFFD9822B);
  static const Color dhuhr = Color(0xFFC9922F);
  static const Color asr = PrayerHues.asr;
  static const Color maghrib = Color(0xFFE2552E);
  static const Color isha = Color(0xFF5B4BC4); // mockup reuses the fajr hue

  static Color prayerRow(PrayerId id) => switch (id) {
        PrayerId.fajr => fajr,
        PrayerId.sunrise => sunrise,
        PrayerId.dhuhr => dhuhr,
        PrayerId.asr => asr,
        PrayerId.maghrib => maghrib,
        PrayerId.isha => isha,
      };

  // ── prayer card ──
  static const Color done = Color(0xFF2E8B3D);
  static const Color doneBar = done;

  /// The past-due unlogged prayer's check — the user's red-tick rule: a
  /// closed unlogged window is marked with a filled red check (green is
  /// done), and the row stays tappable to log it late.
  static const Color missed = Color(0xFFC0392B);

  /// The «اکنون» segment of the n/5 bar.
  static const Color nowBar = AppPalette.heroGoldDeep;
  static const Color upcomingBar = Color(0xFFEFE3D0);

  /// Gold border of the «اکنون» row/chip and the timeline's active line.
  static const Color goldLine = Color(0xFFE8C277);

  /// The «اکنون» row gradient — bottom stop, then top. The light creams
  /// wash out on the dark card (the user's 2026-10-17 report: the open
  /// prayer window «با رنگ کرمی رنگی شده»), so dark paints the same gold
  /// wash the badges already use over the dark surface.
  static Color nowRowStart(bool isDark) => isDark
      ? const Color(0x29E8C277)
      : AppColors.currentPrayerTintStart;
  static Color nowRowEnd(bool isDark) =>
      isDark ? const Color(0x0AE8C277) : AppColors.currentPrayerTintEnd;

  /// Ink on the open-window row (time text, «بعدی» badge, timeline name):
  /// deep amber on light paper, the hero gold itself on dark.
  static Color nowRowTime(bool isDark) =>
      isDark ? AppPalette.heroGold : const Color(0xFF7A5410);

  /// Hollow-ring and dashed hairlines (the timeline's upcoming dot, the
  /// rawatib past border): a faint tan stroke on light paper, the faint-box
  /// white on dark. [alpha] multiplies the base strength — the rawatib
  /// dashes pass 0.85, the ring keeps the full base.
  static Color faintBorder(bool isDark, {double alpha = 1}) {
    final base = isDark
        ? Colors.white.withValues(alpha: 0.25)
        : const Color(0xFFD9C7B3);
    return base.withValues(alpha: base.a * alpha);
  }

  // ── rawatib ──
  static const Color witr = SectionHues.calendar;
  static const Color rawatibPastBg = Color(0xFFF8F4EC);

  // ── daily summary ──
  static const Color ringPrayer = done;
  static const Color ringRawatib = dhuhr;
  // Matches the dawn palette's heroTop (a per-palette instance field, so it
  // cannot be aliased here and stays literal).
  static const Color ringAdhkar = Color(0xFF3F5F9C);
  static const Color ringTasbih = witr;

  // ── actions timeline ──
  static const Color timelineLine = goldLine;
  static const Color timelinePastBg = Color(0xFFF6F1E8); // used @80%
  static const Color timelineUpcomingBg = Color(0xFFFBF8F2);
  static const Color timelineUpcomingBorder = upcomingBar;

  // ── reminders ──
  static const Color dua = witr;
  // Mockup-only hex (no static core twin to alias).
  static const Color tilawa = Color(0xFF2B4880);
  static const Color khatm = AppPalette.emerald;

  /// «آداب و فضایل روز جمعه» card — the section's own fixed topic colour.
  static const Color friday = SectionColors.friday;
}
