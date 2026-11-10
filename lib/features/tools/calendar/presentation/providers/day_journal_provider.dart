import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tawheeed/features/tools/calendar/data/day_journal_service.dart';
import 'package:tawheeed/features/tools/calendar/domain/day_journal_entry.dart';

/// All stored «کارها و یادداشت‌های روز»: Gregorian date key → that day's
/// entries. The whole journal is tiny, so it is kept resident and updated
/// optimistically (state first, persist right after).
final dayJournalProvider = AsyncNotifierProvider<DayJournalNotifier,
    Map<String, List<DayJournalEntry>>>(DayJournalNotifier.new);

class DayJournalNotifier
    extends AsyncNotifier<Map<String, List<DayJournalEntry>>> {
  @override
  Future<Map<String, List<DayJournalEntry>>> build() {
    return DayJournalService.loadAll();
  }

  List<DayJournalEntry> entriesFor(String dateKey) {
    return state.value?[dateKey] ?? const [];
  }

  bool hasEntries(String dateKey) => entriesFor(dateKey).isNotEmpty;

  /// Returns false when the journal has not loaded yet (or failed to load), so
  /// the caller can keep the user's text instead of losing it silently.
  Future<bool> add(String dateKey, DayJournalKind kind, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.value == null) return false;
    final entry = DayJournalEntry(
      // Microseconds: two taps in the same millisecond would otherwise share
      // an id, and toggleDone/remove match by id.
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      kind: kind,
      text: trimmed,
      createdAt: DateTime.now(),
    );
    final updated = {
      ...state.requireValue,
      dateKey: [...entriesFor(dateKey), entry],
    };
    final entries = updated[dateKey] ?? const [];
    state = AsyncData(updated);
    return _persist(dateKey, entries);
  }

  /// Writes one day and flips to `AsyncError` if storage rejects it — without
  /// this the optimistic state above claimed a saved entry.
  Future<bool> _persist(String dateKey, List<DayJournalEntry> entries) async {
    try {
      await DayJournalService.saveDay(dateKey, entries);
      return true;
    } catch (e, st) {
      // Surfaced as AsyncError so the UI can undo its optimistic entry.
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<void> toggleDone(String dateKey, String id) async {
    if (state.value == null) return;
    final list = entriesFor(dateKey);
    final idx = list.indexWhere((e) => e.id == id);
    if (idx < 0 || list[idx].kind != DayJournalKind.task) return;
    final updatedList = [...list]..[idx] =
        list[idx].copyWith(done: !list[idx].done);
    state = AsyncData({...state.requireValue, dateKey: updatedList});
    await _persist(dateKey, updatedList);
  }

  Future<void> remove(String dateKey, String id) async {
    if (state.value == null) return;
    final updatedList = entriesFor(dateKey).where((e) => e.id != id).toList();
    final updated = {...state.requireValue};
    if (updatedList.isEmpty) {
      updated.remove(dateKey);
    } else {
      updated[dateKey] = updatedList;
    }
    state = AsyncData(updated);
    await _persist(dateKey, updatedList);
  }
}
