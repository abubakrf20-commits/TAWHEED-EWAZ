import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/shared/utils/number_format.dart';
import 'package:tawheeed/core/theme/theme.dart';

/// ═══════════════════════════════════════════════════════════════
/// Shared constants for the Pomodoro feature.
///
/// Everything the timer UI needs beyond the screen's engine state
/// lives here so individual widgets never depend on the screen file.
/// ═══════════════════════════════════════════════════════════════

/// Topic color comes from [TopicHues] — never restate the hue here.
const Color pomodoroAccent = TopicHues.pomodoro;
const Color countdownAccent = Color(0xFF7C4DFF);

enum PomodoroMode { classic, countdown }

enum PomodoroPhase { focus, shortBreak, longBreak }

const List<int> cdPresets = [1, 2, 3, 5, 10, 15];

const List<String> focusTypes = ['قرآن', 'حدیث', 'مطالعه', 'کار', 'عمومی'];

/// Fixed per-type color used for the focus chips, breakdown and history
/// rows, so a نوع تمرکز keeps the same identity everywhere on the screen.
Color focusTypeColor(String type) {
  switch (type) {
    case 'قرآن':
      return AppTheme.success;
    case 'حدیث':
      return const Color(0xFF00838F);
    case 'مطالعه':
      return const Color(0xFF1E88E5);
    case 'کار':
      return const Color(0xFFEF6C00);
    default:
      return const Color(0xFF607D8B); // عمومی
  }
}

/// Renders digits (or any string with embedded digits) with Latin digits —
/// delegates to the shared [NumberFormat] (product standard).
String faDigits(Object? n) => NumberFormat.toLatin('$n');
