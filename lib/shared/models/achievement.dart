class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int points;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final int progress;
  final int targetProgress;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.points = 0,
    this.isUnlocked = false,
    this.unlockedAt,
    this.progress = 0,
    required this.targetProgress,
  });

  Achievement copyWith({
    String? id,
    String? title,
    String? description,
    String? icon,
    int? points,
    bool? isUnlocked,
    DateTime? unlockedAt,
    int? progress,
    int? targetProgress,
  }) {
    return Achievement(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      points: points ?? this.points,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      progress: progress ?? this.progress,
      targetProgress: targetProgress ?? this.targetProgress,
    );
  }

  double get progressPercentage => (progress / targetProgress).clamp(0.0, 1.0);
}
