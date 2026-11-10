import 'package:flutter/material.dart';
import 'package:tawheeed/core/theme/time_theme.dart';
import 'package:tawheeed/core/theme/theme.dart';

/// Expenses identity color — derived from [TopicHues.expenses];
/// never restate the hue here (it must match the «بیشتر» tile).
const Color expensesAccent = TopicHues.expenses;

/// Washed-out accent for selected chips in light mode.
final Color expensesAccentSoft =
    Color.lerp(expensesAccent, Colors.white, 0.85) ?? expensesAccent;

const Color incomeColor = AppTheme.success;
const Color expenseColor = TopicHues.expenses;

enum ExpenseFilter { all, income, expense, month }
