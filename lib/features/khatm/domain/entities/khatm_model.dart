enum KhatmType {
  quran,
  book,
  custom,
}

enum KhatmStatus {
  pending,
  active,
  completed,
  cancelled,
}

class KhatmModel {
  final String id;
  final String title;
  final KhatmType type;
  final KhatmStatus status;
  final int totalParts;
  final int completedParts;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? targetDate;
  final List<String> participantIds;
  final String? description;
  final bool isPublic;

  const KhatmModel({
    required this.id,
    required this.title,
    required this.type,
    this.status = KhatmStatus.pending,
    this.totalParts = 30,
    this.completedParts = 0,
    required this.startDate,
    this.endDate,
    this.targetDate,
    this.participantIds = const [],
    this.description,
    this.isPublic = false,
  });

  KhatmModel copyWith({
    String? id,
    String? title,
    KhatmType? type,
    KhatmStatus? status,
    int? totalParts,
    int? completedParts,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? targetDate,
    List<String>? participantIds,
    String? description,
    bool? isPublic,
  }) {
    return KhatmModel(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      status: status ?? this.status,
      totalParts: totalParts ?? this.totalParts,
      completedParts: completedParts ?? this.completedParts,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      targetDate: targetDate ?? this.targetDate,
      participantIds: participantIds ?? this.participantIds,
      description: description ?? this.description,
      isPublic: isPublic ?? this.isPublic,
    );
  }

  double get progress {
    if (totalParts == 0) return 0;
    return (completedParts / totalParts).clamp(0.0, 1.0);
  }
}
