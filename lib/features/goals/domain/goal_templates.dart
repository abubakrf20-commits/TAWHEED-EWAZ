import 'package:tawheeed/core/database/app_database.dart';

/// A ready-made starting point for a common goal.
///
/// The editor treats it purely as prefill data for a NEW goal — it is never
/// written to the database itself; saving from a template produces a regular
/// [GoalTableData] row with a fresh id. Field names mirror the row's so the
/// editor can read goal/template/unspecified as one fallback chain.
class GoalTemplate {
  final String title;
  final String description;
  final String category;
  final String targetType;
  final int targetNumber;
  final int dailyTarget;

  const GoalTemplate({
    required this.title,
    this.description = '',
    required this.category,
    required this.targetType,
    this.targetNumber = 0,
    this.dailyTarget = 0,
  });
}

/// The «قالب آماده» list. Digits stay Latin (product standard) even inside
/// the Persian titles.
const List<GoalTemplate> goalTemplates = [
  GoalTemplate(
    title: 'حفظ 1 صفحه در روز',
    description: 'یک صفحه قرآن، هر روز',
    category: 'hifz',
    targetType: 'count',
    dailyTarget: 1,
  ),
  GoalTemplate(
    title: 'نماز اول وقت',
    description: 'هر پنج نماز در اول وقت',
    category: 'prayer',
    targetType: 'boolean',
  ),
  GoalTemplate(
    title: 'مطالعه 10 صفحه در روز',
    description: 'کتاب، هر روز 10 صفحه',
    category: 'study',
    targetType: 'count',
    dailyTarget: 10,
  ),
  GoalTemplate(
    title: 'اذکار روزانه',
    description: 'اوراد صبح و شب',
    category: 'ibadat',
    targetType: 'boolean',
  ),
  GoalTemplate(
    title: '30 دقیقه حرکت در روز',
    description: 'پیاده‌روی یا ورزش',
    category: 'health',
    targetType: 'minutes',
    dailyTarget: 30,
  ),
];
