import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tawheeed/features/khatm/data/models/khatm_model.dart';
import 'package:tawheeed/features/khatm/data/repositories/khatm_repository_impl.dart';

part 'khatm_provider.g.dart';

final allKhatmsProvider = FutureProvider<List<KhatmModel>>((ref) async {
  final repo = ref.read(khatmRepositoryProvider);
  final list = await repo.getAllKhatms();
  list.sort((a, b) => b.startDate.compareTo(a.startDate));
  return list;
});

@riverpod
class Khatm extends _$Khatm {
  String? _selectedId;

  @override
  Future<KhatmModel?> build() async {
    final repo = ref.read(khatmRepositoryProvider);
    final all = await repo.getAllKhatms();
    if (all.isEmpty) return null;
    all.sort((a, b) => b.startDate.compareTo(a.startDate));

    if (_selectedId != null) {
      final match = all.where((k) => k.id == _selectedId).firstOrNull;
      if (match != null) return match;
    }

    for (final k in all) {
      if (!k.isCompleted) return k;
    }
    return all.first;
  }

  bool get hasActive {
    final cur = state.value;
    return cur != null && !cur.isCompleted;
  }

  Future<List<KhatmModel>> get allKhatms async {
    final repo = ref.read(khatmRepositoryProvider);
    final list = await repo.getAllKhatms();
    list.sort((a, b) => b.startDate.compareTo(a.startDate));
    return list;
  }

  Future<void> selectKhatm(String id) async {
    _selectedId = id;
    final repo = ref.read(khatmRepositoryProvider);
    final khatm = await repo.getKhatm(id);
    if (khatm != null) {
      state = AsyncData(khatm);
    }
  }

  Future<void> startNew({
    required String title,
    required int targetDays,
    List<String>? participantNames,
    List<int>? participantAssignedJuzs,
  }) async {
    final khatm = KhatmModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      startDate: DateTime.now(),
      targetDays: targetDays,
      participantNames: participantNames ?? [],
      participantAssignedJuzs: participantAssignedJuzs ?? [],
    );
    await ref.read(khatmRepositoryProvider).upsertKhatm(khatm);
    _selectedId = khatm.id;
    state = AsyncData(khatm);
    ref.invalidate(allKhatmsProvider);
  }

  Future<void> markPageRange(int startPage, int endPage) async {
    final cur = state.requireValue;
    if (cur == null) return;
    final pages = List<bool>.from(cur.pagesRead);
    var newlyRead = 0;
    for (int i = startPage; i <= endPage; i++) {
      if (i < 1 || i > cur.totalPages) continue;
      if (!pages[i - 1]) newlyRead++;
      pages[i - 1] = true;
    }
    final readPagesCount = pages.where((p) => p).length;
    final completed = readPagesCount == cur.totalPages;

    // Track today's progress: add only the pages that were actually new.
    final daily = Map<String, int>.from(cur.dailyRead);
    if (newlyRead > 0) {
      final today = KhatmModel.dateKeyOf(DateTime.now());
      daily[today] = (daily[today] ?? 0) + newlyRead;
    }

    final updated = cur.copyWith(
      pagesRead: pages,
      dailyRead: daily,
      isCompleted: completed,
    );
    final model =
        completed ? updated.copyWith(endDate: DateTime.now()) : updated;
    await ref.read(khatmRepositoryProvider).upsertKhatm(model);
    state = AsyncData(model);
    ref.invalidate(allKhatmsProvider);
  }

  Future<void> delete(String id) async {
    await ref.read(khatmRepositoryProvider).deleteKhatm(id);
    ref.invalidate(allKhatmsProvider);
    if (state.value?.id == id) {
      _selectedId = null;
      final repo = ref.read(khatmRepositoryProvider);
      final all = await repo.getAllKhatms();
      if (all.isEmpty) {
        state = const AsyncData(null);
      } else {
        all.sort((a, b) => b.startDate.compareTo(a.startDate));
        for (final k in all) {
          if (!k.isCompleted) {
            _selectedId = k.id;
            state = AsyncData(k);
            return;
          }
        }
        _selectedId = all.first.id;
        state = AsyncData(all.first);
      }
    }
  }
}
