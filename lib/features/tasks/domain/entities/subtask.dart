/// A checklist item inside a task («زیرکار»).
class Subtask {
  final String id;
  final String taskId;
  final String title;
  final bool isCompleted;
  final int position;

  const Subtask({
    required this.id,
    required this.taskId,
    required this.title,
    this.isCompleted = false,
    this.position = 0,
  });

  Subtask copyWith({
    String? id,
    String? taskId,
    String? title,
    bool? isCompleted,
    int? position,
  }) {
    return Subtask(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      position: position ?? this.position,
    );
  }
}
