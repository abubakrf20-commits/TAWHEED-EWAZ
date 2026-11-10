import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/time_theme.dart';

/// Reminders identity color — derived from [TopicHues.reminders], the
/// single source of truth for feature topic colors. Never hardcode the hue
/// here; a new value would drift from the «بیشتر» tile color.
class ReminderColors {
  ReminderColors._();

  static const Color accent = TopicHues.reminders;

  /// Light chip/selected background — the accent washed toward white.
  static final Color accentSoft =
      Color.lerp(accent, Colors.white, 0.85) ?? accent;
}
