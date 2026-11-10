import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/core/database/database_provider.dart';
import 'package:tawheeed/features/hifz/domain/entities/hafiz_model.dart';
import 'package:tawheeed/features/hifz/domain/entities/hifz_lesson_model.dart';
import 'package:tawheeed/features/hifz/domain/entities/hifz_review_model.dart';

final hifzDaoProvider = Provider<HifzDao>((ref) {
  return HifzDao(ref.read(appDatabaseProvider));
});

/// Data access for the hifz (حفظ قرآن) feature: hafizs, lessons (حفظ جدید)
/// and review sessions (سبق / مراجعه).
class HifzDao {
  final AppDatabase db;
  HifzDao(this.db);

  // ── Hafizs ─────────────────────────────────────────────────────────

  Future<List<HafizModel>> getAllHafizs() async {
    final rows = await db.select(db.hafizTable).get();
    return rows.map(_toHafiz).toList();
  }

  Future<HafizModel?> getHafiz(String id) async {
    final row = await (db.select(db.hafizTable)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toHafiz(row);
  }

  Future<void> upsertHafiz(HafizModel h) async {
    await db.into(db.hafizTable).insertOnConflictUpdate(HafizTableData(
          id: h.id,
          name: h.name,
          colorHex: h.colorHex,
          sabaqWindowDays: h.sabaqWindowDays,
          createdAt: h.createdAt,
        ));
  }

  /// Removes the hafiz and all of their lessons/reviews.
  Future<void> deleteHafiz(String id) async {
    await (db.delete(db.hifzLessonTable)..where((t) => t.hafizId.equals(id)))
        .go();
    await (db.delete(db.hifzReviewTable)..where((t) => t.hafizId.equals(id)))
        .go();
    await (db.delete(db.hafizTable)..where((t) => t.id.equals(id))).go();
  }

  // ── Lessons (حفظ جدید) ─────────────────────────────────────────────

  /// Lessons of [hafizId], newest first.
  Future<List<HifzLessonModel>> getLessons(String hafizId) async {
    final rows = await (db.select(db.hifzLessonTable)
          ..where((t) => t.hafizId.equals(hafizId))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
    return rows.map(_toLesson).toList();
  }

  Future<void> upsertLesson(HifzLessonModel l) async {
    await db
        .into(db.hifzLessonTable)
        .insertOnConflictUpdate(HifzLessonTableData(
          id: l.id,
          hafizId: l.hafizId,
          date: l.date,
          surahFrom: l.surahFrom,
          ayahFrom: l.ayahFrom,
          surahTo: l.surahTo,
          ayahTo: l.ayahTo,
          pages: l.pages,
          quality: l.quality.key,
          notes: l.notes,
          createdAt: l.createdAt,
        ));
  }

  Future<void> deleteLesson(String id) async {
    await (db.delete(db.hifzLessonTable)..where((t) => t.id.equals(id))).go();
  }

  // ── Reviews (سبق / مراجعه) ─────────────────────────────────────────

  /// Reviews of [hafizId], newest first.
  Future<List<HifzReviewModel>> getReviews(String hafizId) async {
    final rows = await (db.select(db.hifzReviewTable)
          ..where((t) => t.hafizId.equals(hafizId))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
    return rows.map(_toReview).toList();
  }

  Future<void> upsertReview(HifzReviewModel r) async {
    await db
        .into(db.hifzReviewTable)
        .insertOnConflictUpdate(HifzReviewTableData(
          id: r.id,
          hafizId: r.hafizId,
          date: r.date,
          type: r.type.key,
          surahFrom: r.surahFrom,
          ayahFrom: r.ayahFrom,
          surahTo: r.surahTo,
          ayahTo: r.ayahTo,
          pages: r.pages,
          quality: r.quality.key,
          notes: r.notes,
          createdAt: r.createdAt,
        ));
  }

  Future<void> deleteReview(String id) async {
    await (db.delete(db.hifzReviewTable)..where((t) => t.id.equals(id))).go();
  }

  // ── Mapping ────────────────────────────────────────────────────────

  HafizModel _toHafiz(HafizTableData r) => HafizModel(
        id: r.id,
        name: r.name,
        colorHex: r.colorHex,
        sabaqWindowDays: r.sabaqWindowDays,
        createdAt: r.createdAt,
      );

  HifzLessonModel _toLesson(HifzLessonTableData r) => HifzLessonModel(
        id: r.id,
        hafizId: r.hafizId,
        date: r.date,
        surahFrom: r.surahFrom,
        ayahFrom: r.ayahFrom,
        surahTo: r.surahTo,
        ayahTo: r.ayahTo,
        pages: r.pages,
        quality: ReviewQuality.fromKey(r.quality),
        notes: r.notes,
        createdAt: r.createdAt,
      );

  HifzReviewModel _toReview(HifzReviewTableData r) => HifzReviewModel(
        id: r.id,
        hafizId: r.hafizId,
        date: r.date,
        type: ReviewType.fromKey(r.type),
        surahFrom: r.surahFrom,
        ayahFrom: r.ayahFrom,
        surahTo: r.surahTo,
        ayahTo: r.ayahTo,
        pages: r.pages,
        quality: ReviewQuality.fromKey(r.quality),
        notes: r.notes,
        createdAt: r.createdAt,
      );
}
