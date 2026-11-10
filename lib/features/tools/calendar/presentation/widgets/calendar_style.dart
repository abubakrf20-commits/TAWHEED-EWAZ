import 'package:flutter/material.dart';

import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/theme/theme.dart';

/// ══════════════════════════════════════════════════════════════
///  The calendar's display table: the Persian week, the three calendar
///  systems' hues, and one style per occasion.
///
///  Everything here is a single copy on purpose. The weekday list used to be
///  written out three times (the screen, the month list, the converter) and an
///  occasion used to print emerald in the selected-day box and pink in the
///  month list, because each widget carried its own `if (label.contains(…))`
///  chain.
/// ══════════════════════════════════════════════════════════════

/// Grid columns and weekday names — the Persian week starts on Saturday.
const List<String> kWeekdayNames = [
  'شنبه',
  'یکشنبه',
  'دوشنبه',
  'سه‌شنبه',
  'چهارشنبه',
  'پنجشنبه',
  'جمعه',
];

/// The one-letter grid header for the same week.
const List<String> kWeekdayLetters = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

/// Saturday-first index (0 = شنبه) of [date] — the grid column and the name
/// list share it, so the header letter always sits over its own column.
int weekdaySlot(DateTime date) => (date.weekday + 1) % 7;

/// The Persian weekday name of [date].
String weekdayName(DateTime date) => kWeekdayNames[weekdaySlot(date)];

/// Fixed identity hue per calendar system — phase-independent, like
/// [SectionHues]. [shamsi] repeats the design's amber (== SectionHues.tasbih)
/// and [gregorian] keeps the blue the converter has always shipped with.
abstract final class CalendarHues {
  static const Color hijri = SectionHues.calendar;
  static const Color shamsi = Color(0xFFBA7517);
  static const Color gregorian = Color(0xFF2E86AB);

  /// Sunnah fasting and the Eids — the app's «done» green.
  static const Color fasting = AppPalette.emerald;

  /// Any occasion with no family of its own.
  static const Color occasion = AppPalette.goldDark;
}

/// An occasion's hue and glyph. [hue] is the raw identity color: fills use it
/// at a low alpha and text/icons go through `dsContentColor(context, hue)`
/// first, exactly like the rest of the kit.
class CalendarOccasionStyle {
  const CalendarOccasionStyle(this.hue, this.icon);

  final Color hue;
  final IconData icon;

  /// Keyword order is the historical one and is load-bearing: «روزه عاشورا
  /// (سنت)» must match the fasting family, not the «سنت» tail.
  factory CalendarOccasionStyle.of(String label) {
    if (label.contains('عید') ||
        label.contains('غدیر') ||
        label.contains('نوروز')) {
      return const CalendarOccasionStyle(CalendarHues.fasting, Icons.event);
    }
    if (label.contains('لیلة')) {
      return const CalendarOccasionStyle(
          Color(0xFF7C4DFF), Icons.nightlight_round);
    }
    if (label.contains('یلدا')) {
      return const CalendarOccasionStyle(AppTheme.error, Icons.nights_stay);
    }
    if (label.contains('عرفه')) {
      return const CalendarOccasionStyle(
          AppTheme.warning, Icons.place_rounded);
    }
    if (label.contains('ولادت')) {
      return const CalendarOccasionStyle(
          Color(0xFFD81B60), Icons.celebration_outlined);
    }
    if (label.contains('مبعث')) {
      return const CalendarOccasionStyle(
          Color(0xFF3949AB), Icons.flash_on_rounded);
    }
    if (label.contains('سده')) {
      return const CalendarOccasionStyle(
          Color(0xFFEF6C00), Icons.local_fire_department);
    }
    if (label.contains('رمضان') || label.contains('فتح')) {
      return const CalendarOccasionStyle(Color(0xFF1565C0), Icons.auto_awesome);
    }
    if (label.contains('رأس السنة')) {
      return const CalendarOccasionStyle(
          Color(0xFF1565C0), Icons.calendar_today_rounded);
    }
    if (label.contains('ایام البیض') ||
        label.contains('ایام تشریق') ||
        label.contains('روزه')) {
      return const CalendarOccasionStyle(
          CalendarHues.fasting, Icons.eco_rounded);
    }
    if (label.contains('سنت') || label.contains('مستحب')) {
      return const CalendarOccasionStyle(
          AppTheme.success, Icons.volunteer_activism);
    }
    return const CalendarOccasionStyle(
        CalendarHues.occasion, Icons.star_rounded);
  }
}
