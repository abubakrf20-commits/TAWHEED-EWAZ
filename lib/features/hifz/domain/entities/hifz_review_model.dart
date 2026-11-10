/// Type of a review session.
enum ReviewType {
  sabaq('sabaq', 'سبق'),
  murajaah('murajaah', 'مراجعه');

  final String key;
  final String label;
  const ReviewType(this.key, this.label);

  static ReviewType fromKey(String key) => key == sabaq.key ? sabaq : murajaah;
}

/// Quality rating of a review session.
enum ReviewQuality {
  weak('weak', 'ضعیف'),
  medium('medium', 'متوسط'),
  excellent('excellent', 'عالی');

  final String key;
  final String label;
  const ReviewQuality(this.key, this.label);

  static ReviewQuality fromKey(String key) {
    switch (key) {
      case 'weak':
        return weak;
      case 'medium':
        return medium;
      default:
        return excellent;
    }
  }
}

/// A review session: سَبَق (recent memorization) or مُراجَعَه (distant),
/// each rated ضعیف/متوسط/عالی.
class HifzReviewModel {
  final String id;
  final String hafizId;
  final DateTime date;
  final ReviewType type;
  final int surahFrom;
  final int ayahFrom;
  final int surahTo;
  final int ayahTo;
  final int pages;
  final ReviewQuality quality;
  final String? notes;
  final DateTime createdAt;

  const HifzReviewModel({
    required this.id,
    required this.hafizId,
    required this.date,
    required this.type,
    required this.surahFrom,
    required this.ayahFrom,
    required this.surahTo,
    required this.ayahTo,
    required this.pages,
    required this.quality,
    this.notes,
    required this.createdAt,
  });

  static const Object _unset = Object();

  HifzReviewModel copyWith({
    String? id,
    String? hafizId,
    DateTime? date,
    ReviewType? type,
    int? surahFrom,
    int? ayahFrom,
    int? surahTo,
    int? ayahTo,
    int? pages,
    ReviewQuality? quality,
    Object? notes = _unset,
    DateTime? createdAt,
  }) {
    return HifzReviewModel(
      id: id ?? this.id,
      hafizId: hafizId ?? this.hafizId,
      date: date ?? this.date,
      type: type ?? this.type,
      surahFrom: surahFrom ?? this.surahFrom,
      ayahFrom: ayahFrom ?? this.ayahFrom,
      surahTo: surahTo ?? this.surahTo,
      ayahTo: ayahTo ?? this.ayahTo,
      pages: pages ?? this.pages,
      quality: quality ?? this.quality,
      notes: notes == _unset ? this.notes : notes as String?,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
