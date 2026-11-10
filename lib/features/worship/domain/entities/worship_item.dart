class WorshipItem {
  final String id;
  final String label;
  final int iconCodePoint;
  final String iconFontFamily;
  final int points;
  bool done;

  WorshipItem({
    required this.id,
    required this.label,
    required this.iconCodePoint,
    required this.iconFontFamily,
    this.done = false,
    this.points = 10,
  });

  WorshipItem copyWith({
    String? id,
    String? label,
    int? iconCodePoint,
    String? iconFontFamily,
    bool? done,
    int? points,
  }) {
    return WorshipItem(
      id: id ?? this.id,
      label: label ?? this.label,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      done: done ?? this.done,
      points: points ?? this.points,
    );
  }
}
