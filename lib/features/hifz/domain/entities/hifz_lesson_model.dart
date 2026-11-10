import 'package:tawheeed/features/hifz/domain/entities/hifz_review_model.dart';

/// Daily NEW memorization delivered by a hafiz (حفظ جدید).
class HifzLessonModel {
  final String id;
  final String hafizId;
  final DateTime date;
  final int surahFrom;
  final int ayahFrom;
  final int surahTo;
  final int ayahTo;

  /// Number of pages covered (computed from the range, editable).
  final int pages;
  final ReviewQuality quality;
  final String? notes;
  final DateTime createdAt;

  const HifzLessonModel({
    required this.id,
    required this.hafizId,
    required this.date,
    required this.surahFrom,
    required this.ayahFrom,
    required this.surahTo,
    required this.ayahTo,
    required this.pages,
    this.quality = ReviewQuality.excellent,
    this.notes,
    required this.createdAt,
  });

  static const Object _unset = Object();

  HifzLessonModel copyWith({
    String? id,
    String? hafizId,
    DateTime? date,
    int? surahFrom,
    int? ayahFrom,
    int? surahTo,
    int? ayahTo,
    int? pages,
    Object? notes = _unset,
    ReviewQuality? quality,
    DateTime? createdAt,
  }) {
    return HifzLessonModel(
      id: id ?? this.id,
      hafizId: hafizId ?? this.hafizId,
      date: date ?? this.date,
      surahFrom: surahFrom ?? this.surahFrom,
      ayahFrom: ayahFrom ?? this.ayahFrom,
      surahTo: surahTo ?? this.surahTo,
      ayahTo: ayahTo ?? this.ayahTo,
      pages: pages ?? this.pages,
      notes: notes == _unset ? this.notes : notes as String?,
      quality: quality ?? this.quality,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
