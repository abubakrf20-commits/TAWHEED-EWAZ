import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tawheeed/core/database/app_database.dart';
import 'package:tawheeed/features/adhkar/duas/data/daos/dua_dao.dart';
import 'package:tawheeed/features/adhkar/duas/data/hesn_db_service.dart';
import 'package:tawheeed/features/adhkar/duas/domain/entities/dua_model.dart';
import 'package:tawheeed/shared/utils/app_logger.dart';

part 'duas_provider.g.dart';

/// Overridable so tests can inject fixture content without touching the
/// filesystem or bundled assets.
final hesnContentProvider = Provider<HesnDbService>(
  (ref) => HesnDbService(),
);

@riverpod
class Duas extends _$Duas {
  /// Rich content (شرح) joined onto the favorite rows by item id.
  Map<String, HesnItem> _rich = const {};

  /// Maps DB chapter id → real book bab number (ids are offset by the
  /// intro sections, so id ≠ number).
  Map<int, int> _chapterNumberById = const {};

  /// Resolved when the initial sync finishes. The sync rewrites the favorite
  /// rows that exist at that moment, so a toggle made while it was in flight
  /// was applied to a row the sync had not created yet (a silent no-op).
  Completer<void> _ready = Completer<void>();

  @override
  DuasState build() {
    _ready = Completer<void>();
    _init();
    return const DuasState();
  }

  Future<void> _awaitReady() async {
    if (!_ready.isCompleted) await _ready.future;
  }

  static String itemIdOf(HesnItem i) => 'c${i.chapterId}s${i.seq}';

  /// Content version already mirrored into the Drift table in this process.
  /// Rebuilds of the provider (e.g. screen revisits) skip the full upsert
  /// until the bundled حصن المسلم content version actually changes.
  static int? _syncedContentVersion;

  Future<void> _init() async {
    try {
      final hesn = ref.read(hesnContentProvider);
      final chapters = await hesn.getChapters();
      final items = await hesn.getAllItems();
      final sections = await hesn.getSections();
      if (!ref.mounted) return;

      if (items.isEmpty) {
        state = const DuasState(
          error: 'داده‌ای برای حصن المسلم یافت نشد',
          isLoading: false,
        );
        return;
      }

      _rich = {for (final i in items) itemIdOf(i): i};
      _chapterNumberById = {for (final c in chapters) c.id: c.number};

      final chapterById = {for (final c in chapters) c.id: c};
      String titleOf(HesnItem i) => chapterById[i.chapterId]?.title ?? '';

      // Keep the favorites table in sync with the bundled content: rewrite
      // every row from the db asset (preserving favorite flags) and drop
      // rows that no longer exist in the content. The full rewrite runs only
      // when the bundled content version changed (or the table is empty) —
      // reopening the screen must not re-upsert all ~700 rows.
      final dao = ref.read(duaDaoProvider);
      final existingRows = await dao.getAllDuas();
      final contentIds = items.map(itemIdOf).toSet();
      final existingIds = existingRows.map((e) => e.id).toSet();
      final needsResync =
          _syncedContentVersion != HesnDbService.contentVersion ||
              existingRows.isEmpty ||
              existingIds.length != contentIds.length ||
              !existingIds.containsAll(contentIds);
      if (needsResync) {
        final favoriteIds = {
          for (final e in existingRows)
            if (e.isFavorite) e.id,
        };

        await dao.upsertBatch([
          for (final i in items)
            DuaTableData(
              id: itemIdOf(i),
              title: titleOf(i),
              arabicText: i.arabic,
              translation: i.translation,
              reference: i.refs,
              category: titleOf(i),
              isFavorite: favoriteIds.contains(itemIdOf(i)),
            ),
        ]);
        final staleIds =
            existingIds.where((id) => !contentIds.contains(id)).toList();
        if (staleIds.isNotEmpty) {
          for (final id in staleIds) {
            await dao.deleteDua(id);
          }
        }
        _syncedContentVersion = HesnDbService.contentVersion;
      }

      final all = needsResync ? await dao.getAllDuas() : existingRows;
      if (!ref.mounted) return;
      final models = all.map(_toModel).toList()
        ..sort((a, b) {
          final c = a.chapterNo.compareTo(b.chapterNo);
          return c != 0 ? c : a.seq.compareTo(b.seq);
        });

      state = DuasState(duas: models, sections: sections, isLoading: false);
    } catch (e) {
      if (!ref.mounted) return;
      state = const DuasState(
        error: 'خطا در بارگذاری حصن المسلم',
        isLoading: false,
      );
      AppLogger.warning('duas_provider', 'DuasProvider error: $e');
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  DuaModel _toModel(DuaTableData d) {
    final rich = _rich[d.id];
    return DuaModel(
      id: d.id,
      title: d.title,
      arabicText: d.arabicText,
      transliteration: d.transliteration,
      translation: d.translation,
      source: rich?.refs ?? (d.reference ?? ''),
      category: d.category,
      isFavorite: d.isFavorite,
      lead: rich?.lead ?? '',
      words: _lines(rich?.words),
      guidance: _lines(rich?.guidance),
      benefits: _lines(rich?.benefits),
      refs: _lines(rich?.refs),
      seq: rich?.seq ?? 0,
      chapterNo: rich == null
          ? 0
          : (_chapterNumberById[rich.chapterId] ?? rich.chapterId),
    );
  }

  List<String> _lines(String? s) {
    if (s == null || s.trim().isEmpty) return const [];
    return s
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> toggleFavorite(String id) async {
    await _awaitReady();
    if (!ref.mounted) return;
    try {
      final dao = ref.read(duaDaoProvider);
      final existing = await dao.getDua(id);
      if (existing != null) {
        await dao.setFavorite(id, !existing.isFavorite);
        final all = await dao.getAllDuas();
        if (!ref.mounted) return;
        final models = all.map(_toModel).toList()
          ..sort((a, b) {
            final c = a.chapterNo.compareTo(b.chapterNo);
            return c != 0 ? c : a.seq.compareTo(b.seq);
          });
        state = state.copyWith(duas: models);
      }
    } catch (e) {
      AppLogger.warning('duas_provider', 'Duas toggleFavorite error: $e');
    }
  }
}

class DuasState {
  final List<DuaModel> duas;
  final List<HesnSection> sections;
  final bool isLoading;
  final String error;

  const DuasState({
    this.duas = const [],
    this.sections = const [],
    this.isLoading = true,
    this.error = '',
  });

  DuasState copyWith({
    List<DuaModel>? duas,
    List<HesnSection>? sections,
    bool? isLoading,
    String? error,
  }) {
    return DuasState(
      duas: duas ?? this.duas,
      sections: sections ?? this.sections,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  List<DuaModel> get favorites => duas.where((d) => d.isFavorite).toList();

  /// Chapter titles in book order.
  List<String> get categories {
    final seen = <String>{};
    return [
      for (final d in duas)
        if (d.category != null &&
            d.category!.isNotEmpty &&
            seen.add(d.category!))
          d.category!,
    ];
  }

  List<DuaModel> byCategory(String category) =>
      duas.where((d) => d.category == category).toList();
}
