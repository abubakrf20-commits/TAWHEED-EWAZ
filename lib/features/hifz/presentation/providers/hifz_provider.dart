import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tawheeed/features/hifz/data/daos/hifz_dao.dart';
import 'package:tawheeed/features/hifz/domain/entities/hafiz_model.dart';
import 'package:tawheeed/features/hifz/domain/entities/hifz_lesson_model.dart';
import 'package:tawheeed/features/hifz/domain/entities/hifz_review_model.dart';
import 'package:tawheeed/features/hifz/domain/hifz_helpers.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

/// Immutable state of the hifz feature.
class HifzState {
  final List<HafizModel> hafizs;
  final Map<String, List<HifzLessonModel>> lessonsByHafiz;
  final Map<String, List<HifzReviewModel>> reviewsByHafiz;
  final String? selectedHafizId;
  final bool loaded;

  const HifzState({
    this.hafizs = const [],
    this.lessonsByHafiz = const {},
    this.reviewsByHafiz = const {},
    this.selectedHafizId,
    this.loaded = false,
  });

  HifzState copyWith({
    List<HafizModel>? hafizs,
    Map<String, List<HifzLessonModel>>? lessonsByHafiz,
    Map<String, List<HifzReviewModel>>? reviewsByHafiz,
    Object? selectedHafizId = _unset,
    bool? loaded,
  }) {
    return HifzState(
      hafizs: hafizs ?? this.hafizs,
      lessonsByHafiz: lessonsByHafiz ?? this.lessonsByHafiz,
      reviewsByHafiz: reviewsByHafiz ?? this.reviewsByHafiz,
      selectedHafizId: selectedHafizId == _unset
          ? this.selectedHafizId
          : selectedHafizId as String?,
      loaded: loaded ?? this.loaded,
    );
  }

  static const Object _unset = Object();

  /// The currently selected hafiz, or the first one when none selected.
  HafizModel? get selectedHafiz {
    if (selectedHafizId != null) {
      for (final h in hafizs) {
        if (h.id == selectedHafizId) return h;
      }
    }
    return hafizs.isEmpty ? null : hafizs.first;
  }

  List<HifzLessonModel> lessonsOf(String hafizId) =>
      lessonsByHafiz[hafizId] ?? const [];

  List<HifzReviewModel> reviewsOf(String hafizId) =>
      reviewsByHafiz[hafizId] ?? const [];

  /// Distinct pages memorized across all lessons of [hafizId]. Repeated
  /// ayahs are counted once.
  int memorizedPagesOf(String hafizId) {
    return uniquePagesOf([
      for (final l in lessonsOf(hafizId))
        (
          sFrom: l.surahFrom,
          aFrom: l.ayahFrom,
          sTo: l.surahTo,
          aTo: l.ayahTo,
        ),
    ]);
  }
}

final hifzProvider =
    NotifierProvider<HifzNotifier, HifzState>(HifzNotifier.new);

class HifzNotifier extends Notifier<HifzState> {
  bool _loaded = false;
  final _rng = Random();

  /// Resolved when the initial read finishes. Mutations await it: the load
  /// assigns the whole snapshot, so an add made while it was in flight was
  /// overwritten by the older DB state.
  Completer<void> _ready = Completer<void>();

  @override
  HifzState build() {
    _loaded = false;
    _ready = Completer<void>();
    _load();
    return const HifzState();
  }

  HifzDao get _dao => ref.read(hifzDaoProvider);

  String _genId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${_rng.nextInt(999999)}';

  Future<void> _awaitReady() async {
    if (!_ready.isCompleted) await _ready.future;
  }

  Future<void> _load() async {
    try {
      final hafizs = await _dao.getAllHafizs();
      final lessons = <String, List<HifzLessonModel>>{};
      final reviews = <String, List<HifzReviewModel>>{};
      for (final h in hafizs) {
        lessons[h.id] = await _dao.getLessons(h.id);
        reviews[h.id] = await _dao.getReviews(h.id);
      }
      if (!_loaded && ref.mounted) {
        _loaded = true;
        state = HifzState(
          hafizs: hafizs,
          lessonsByHafiz: lessons,
          reviewsByHafiz: reviews,
          selectedHafizId: state.selectedHafizId,
          loaded: true,
        );
      }
    } catch (_) {
      AppLogger.warning('hifz_provider', 'operation failed');
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  // ── Hafizs ─────────────────────────────────────────────────────────

  Future<void> addHafiz({
    required String name,
    String colorHex = '#1976D2',
    int sabaqWindowDays = 7,
  }) async {
    await _awaitReady();
    if (!ref.mounted) return;
    final h = HafizModel(
      id: _genId(),
      name: name.trim(),
      colorHex: colorHex,
      sabaqWindowDays: sabaqWindowDays,
      createdAt: DateTime.now(),
    );
    await _dao.upsertHafiz(h);
    await _reload();
    if (state.selectedHafizId == null) {
      state = state.copyWith(selectedHafizId: h.id);
    }
  }

  Future<void> updateHafiz(HafizModel h) async {
    await _awaitReady();
    if (!ref.mounted) return;
    await _dao.upsertHafiz(h);
    await _reload();
  }

  Future<void> deleteHafiz(String id) async {
    await _awaitReady();
    if (!ref.mounted) return;
    await _dao.deleteHafiz(id);
    await _reload();
  }

  void selectHafiz(String id) {
    state = state.copyWith(selectedHafizId: id);
  }

  // ── Lessons (حفظ جدید) ─────────────────────────────────────────────

  Future<void> addLesson({
    required String hafizId,
    required DateTime date,
    required int surahFrom,
    required int ayahFrom,
    required int surahTo,
    required int ayahTo,
    required int pages,
    ReviewQuality quality = ReviewQuality.excellent,
    String? notes,
  }) async {
    await _awaitReady();
    if (!ref.mounted) return;
    final l = HifzLessonModel(
      id: _genId(),
      hafizId: hafizId,
      date: date,
      surahFrom: surahFrom,
      ayahFrom: ayahFrom,
      surahTo: surahTo,
      ayahTo: ayahTo,
      pages: pages,
      quality: quality,
      notes: notes,
      createdAt: DateTime.now(),
    );
    await _dao.upsertLesson(l);
    await _reload();
  }

  Future<void> updateLesson(HifzLessonModel l) async {
    await _awaitReady();
    if (!ref.mounted) return;
    await _dao.upsertLesson(l);
    await _reload();
  }

  Future<void> deleteLesson(String id, String hafizId) async {
    await _awaitReady();
    if (!ref.mounted) return;
    await _dao.deleteLesson(id);
    await _reload();
  }

  // ── Reviews (سبق / مراجعه) ─────────────────────────────────────────

  Future<void> addReview({
    required String hafizId,
    required DateTime date,
    required ReviewType type,
    required int surahFrom,
    required int ayahFrom,
    required int surahTo,
    required int ayahTo,
    required int pages,
    required ReviewQuality quality,
    String? notes,
  }) async {
    await _awaitReady();
    if (!ref.mounted) return;
    final r = HifzReviewModel(
      id: _genId(),
      hafizId: hafizId,
      date: date,
      type: type,
      surahFrom: surahFrom,
      ayahFrom: ayahFrom,
      surahTo: surahTo,
      ayahTo: ayahTo,
      pages: pages,
      quality: quality,
      notes: notes,
      createdAt: DateTime.now(),
    );
    await _dao.upsertReview(r);
    await _reload();
  }

  Future<void> updateReview(HifzReviewModel r) async {
    await _awaitReady();
    if (!ref.mounted) return;
    await _dao.upsertReview(r);
    await _reload();
  }

  Future<void> deleteReview(String id, String hafizId) async {
    await _awaitReady();
    if (!ref.mounted) return;
    await _dao.deleteReview(id);
    await _reload();
  }

  Future<void> _reload() async {
    final hafizs = await _dao.getAllHafizs();
    final lessons = <String, List<HifzLessonModel>>{};
    final reviews = <String, List<HifzReviewModel>>{};
    for (final h in hafizs) {
      lessons[h.id] = await _dao.getLessons(h.id);
      reviews[h.id] = await _dao.getReviews(h.id);
    }
    if (!ref.mounted) return;
    // A reload reads the DB *after* the mutation, so it is newer than the
    // initial load's snapshot; without this flag a slow initial load could
    // land afterwards and revert it.
    _loaded = true;
    state = state.copyWith(
      hafizs: hafizs,
      lessonsByHafiz: lessons,
      reviewsByHafiz: reviews,
      loaded: true,
    );
  }
}
