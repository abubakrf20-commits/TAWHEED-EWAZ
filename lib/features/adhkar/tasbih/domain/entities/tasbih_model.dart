class TasbihModel {
  final String id;
  final String name;
  final String targetDhikr;
  final int targetCount;
  final int currentCount;
  final int totalLifetimeCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isCompleted;
  final bool isFavorite;
  final String? color;
  final bool isDefault;
  final bool isEnabled;

  const TasbihModel({
    required this.id,
    required this.name,
    required this.targetDhikr,
    required this.targetCount,
    this.currentCount = 0,
    this.totalLifetimeCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.isCompleted = false,
    this.isFavorite = false,
    this.color,
    this.isDefault = false,
    this.isEnabled = true,
  });

  TasbihModel copyWith({
    String? id,
    String? name,
    String? targetDhikr,
    int? targetCount,
    int? currentCount,
    int? totalLifetimeCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isCompleted,
    bool? isFavorite,
    String? color,
    bool? isDefault,
    bool? isEnabled,
  }) {
    return TasbihModel(
      id: id ?? this.id,
      name: name ?? this.name,
      targetDhikr: targetDhikr ?? this.targetDhikr,
      targetCount: targetCount ?? this.targetCount,
      currentCount: currentCount ?? this.currentCount,
      totalLifetimeCount: totalLifetimeCount ?? this.totalLifetimeCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isCompleted: isCompleted ?? this.isCompleted,
      isFavorite: isFavorite ?? this.isFavorite,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  double get progress {
    if (targetCount == 0) return 0;
    return (currentCount / targetCount).clamp(0.0, 1.0);
  }
}

/// Counting speed for quick (hold-to-count) tasbih mode — how fast the
/// counter repeats while the finger is held on the circle.
enum QuickCountSpeed {
  // 200% slower than the 858/480/258 ms intervals — the quick tasbih still
  // felt too fast, so every option was halved in speed (interval × 2) again.
  slow('آرام', Duration(milliseconds: 1716)),
  normal('عادی', Duration(milliseconds: 960)),
  fast('سریع', Duration(milliseconds: 516));

  const QuickCountSpeed(this.label, this.interval);

  final String label;
  final Duration interval;
}
