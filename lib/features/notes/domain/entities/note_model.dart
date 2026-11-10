class NoteModel {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final bool isDone;
  final int colorIndex;
  final bool isPinned;

  const NoteModel({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
    this.isDone = false,
    this.colorIndex = 0,
    this.isPinned = false,
  });

  NoteModel copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    bool? isDone,
    int? colorIndex,
    bool? isPinned,
  }) {
    return NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      isDone: isDone ?? this.isDone,
      colorIndex: colorIndex ?? this.colorIndex,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}
