import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:tawheeed/core/constants/date_constants.dart';
import 'package:tawheeed/core/theme/theme.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/shared/utils/shamsi_date_picker.dart';
import 'package:tawheeed/shared/widgets/app_empty_state.dart';
import 'package:tawheeed/features/prayer/presentation/providers/period_provider.dart';
import 'package:tawheeed/features/prayer/presentation/providers/period_session.dart';
import 'package:tawheeed/features/prayer/presentation/widgets/period_report_pdf.dart';
import 'package:tawheeed/features/settings/presentation/providers/settings_selectors.dart';
part 'period_status_chart.dart';
part 'period_overview_sections.dart';
part 'period_day_sheet.dart';
part 'period_input_controls.dart';
part 'period_rulings_history.dart';
part 'period_lock_sections.dart';

/// Period identity color — pink (soft feminine / health-tracking feel).
/// Everything on this screen derives from the fixed [TopicHues.period] so
/// the page never repaints with the theme preset.
Color get periodAccent => TopicHues.period;
Color get periodAccentStrong =>
    Color.lerp(TopicHues.period, Colors.black, 0.22) ?? TopicHues.period;
Color get periodAccentDeep =>
    Color.lerp(TopicHues.period, Colors.black, 0.32) ?? TopicHues.period;
Color get periodAccentLight =>
    Color.lerp(TopicHues.period, Colors.white, 0.38) ?? TopicHues.period;
Color get periodAccentSoft => TopicHues.period.withValues(alpha: 0.12);
const Color statusOnGradient = Colors.white;
const Color statusOnGradientMuted = Color(0xCCFFFFFF);

/// Deep pink derived from the fixed [TopicHues.period]; kept const so the
/// rulings list can be a const literal.
const Color _periodDeepPink = Color(0xFFA12C54);

/// Keeps Latin digits for widget text (dates, counters) — the product
/// standard. Delegates to the shared [NumberFormat] instead of carrying a
/// private copy; accepts any Object for convenient interpolation.
String _num(Object n) => NumberFormat.toLatin('$n');

String _faJalaliDay(DateTime d) {
  final j = Jalali.fromDateTime(d);
  return '${_num(j.year)}/${_num(j.month)}/${_num(j.day)}';
}
