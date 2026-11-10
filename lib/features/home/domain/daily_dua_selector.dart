import 'package:tawheeed/features/adhkar/duas/data/hesn_db_service.dart';

/// Selects one of the first 60 duas from the same content source used by the
/// Dua section. The sequence is deterministic by local calendar day and
/// starts over after the 60th day.
class DailyDuaSelector {
  static const int cycleLength = 60;

  /// Returns the zero-based position in the 60-day cycle.
  static int cycleIndex(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final epoch = DateTime(1970);
    return day.difference(epoch).inDays % cycleLength;
  }

  /// Selects up to 60 existing Dua-section items, preserving book order.
  static HesnItem? select(List<HesnItem> items, DateTime date) {
    if (items.isEmpty) return null;
    final selected = items.take(cycleLength).toList(growable: false);
    return selected[cycleIndex(date) % selected.length];
  }
}
