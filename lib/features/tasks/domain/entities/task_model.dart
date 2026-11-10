import 'package:tawheeed/features/tasks/domain/task_recurrence.dart';

class TaskModel {
  final String id;
  final String title;
  final String? description;
  final bool isCompleted;
  final bool isRecurring;
  final String? recurringType;
  final DateTime? dueDate;

  /// One-shot reminder on the due date («یادآوری روز سررسید»).
  final bool remindEnabled;

  /// Local time of the reminder as "HH:mm" (ignored when [remindEnabled] is
  /// false or [dueDate] is null).
  final String? remindAt;

  /// For a completed task this is when it was done; for a pending recurring
  /// task it is kept as the *last* completion time so streaks/stats work.
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int priority;
  final List<String> tags;

  const TaskModel({
    required this.id,
    required this.title,
    this.description,
    this.isCompleted = false,
    this.isRecurring = false,
    this.recurringType,
    this.dueDate,
    this.remindEnabled = false,
    this.remindAt,
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.priority = 0,
    this.tags = const [],
  });

  /// Whether this task repeats (daily/weekly).
  ///
  /// A row that is flagged recurring but carries an unknown/empty type is
  /// treated as one-off on purpose: unknown patterns must never be rolled
  /// forward or silently dropped/duplicated by the scheduler.
  bool get hasRecurrence =>
      isRecurring && TaskRecurrence.isSupported(recurringType);

  static const Object _unset = Object();

  TaskModel copyWith({
    String? id,
    String? title,
    Object? description = _unset,
    bool? isCompleted,
    bool? isRecurring,
    Object? recurringType = _unset,
    Object? dueDate = _unset,
    bool? remindEnabled,
    Object? remindAt = _unset,
    DateTime? createdAt,
    Object? updatedAt = _unset,
    Object? completedAt = _unset,
    int? priority,
    List<String>? tags,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description:
          description == _unset ? this.description : description as String?,
      isCompleted: isCompleted ?? this.isCompleted,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringType: recurringType == _unset
          ? this.recurringType
          : recurringType as String?,
      dueDate: dueDate == _unset ? this.dueDate : dueDate as DateTime?,
      remindEnabled: remindEnabled ?? this.remindEnabled,
      remindAt: remindAt == _unset ? this.remindAt : remindAt as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt == _unset ? this.updatedAt : updatedAt as DateTime?,
      completedAt:
          completedAt == _unset ? this.completedAt : completedAt as DateTime?,
      priority: priority ?? this.priority,
      tags: tags ?? this.tags,
    );
  }
}
