/// One journal item attached to a calendar day: either a [task] (a to-do with
/// a done state) or a [memory] (a free-text یادداشت of that day).
enum DayJournalKind { task, memory }

/// A single «کار / یادداشت روز» entry stored under a Gregorian date key
/// (`YYYY-MM-DD`) by [DayJournalService].
class DayJournalEntry {
  final String id;
  final DayJournalKind kind;
  final String text;
  final bool done;
  final DateTime createdAt;

  const DayJournalEntry({
    required this.id,
    required this.kind,
    required this.text,
    this.done = false,
    required this.createdAt,
  });

  DayJournalEntry copyWith({String? text, bool? done}) => DayJournalEntry(
        id: id,
        kind: kind,
        text: text ?? this.text,
        done: done ?? this.done,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'text': text,
        'done': done,
        'ts': createdAt.millisecondsSinceEpoch,
      };

  static DayJournalEntry? fromJson(Map<String, dynamic> json) {
    try {
      final id = json['id']?.toString() ?? '';
      final text = json['text']?.toString() ?? '';
      if (id.isEmpty || text.isEmpty) return null;
      final kind = json['kind'] == 'memory'
          ? DayJournalKind.memory
          : DayJournalKind.task;
      final ts = json['ts'];
      return DayJournalEntry(
        id: id,
        kind: kind,
        text: text,
        done: json['done'] == true,
        createdAt: ts is int
            ? DateTime.fromMillisecondsSinceEpoch(ts)
            : DateTime.now(),
      );
    } catch (_) {
      // Domain layer keeps its purity: unparsable row degrades to null.
      return null;
    }
  }
}
